package core

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/sirupsen/logrus"
)

type Discoverer struct {
	provider Provider
	logger   *logrus.Logger
	options  DiscoveryOptions
	mutex    sync.RWMutex
	cache    *ResourceCache
}

type DiscoveryOptions struct {
	MaxWorkers      int
	Timeout         time.Duration
	ResourceTypes   string
	DeepScan        bool
	Filters         map[string]interface{}
	IncludeCosts    bool
	IncludeMetrics  bool
	IncludeTags     bool
	CacheEnabled    bool
	CacheDuration   time.Duration
	RetryAttempts   int
	RetryDelay      time.Duration
	RateLimit       int
	BatchSize       int
	FollowPageToken bool
}

type DiscoveryResults struct {
	Resources       []Resource              `json:"resources"`
	Summary         DiscoverySummary        `json:"summary"`
	Errors          []DiscoveryError        `json:"errors,omitempty"`
	StartTime       time.Time               `json:"start_time"`
	EndTime         time.Time               `json:"end_time"`
	Duration        time.Duration           `json:"duration"`
	Metadata        map[string]interface{}  `json:"metadata,omitempty"`
}

type DiscoverySummary struct {
	TotalResources     int            `json:"total_resources"`
	ResourcesByType    map[string]int `json:"resources_by_type"`
	ResourcesByRegion  map[string]int `json:"resources_by_region"`
	ResourcesByStatus  map[string]int `json:"resources_by_status"`
	TotalCost          float64        `json:"total_cost,omitempty"`
	EstimatedMonthlyCost float64      `json:"estimated_monthly_cost,omitempty"`
}

type ResourceCache struct {
	mutex     sync.RWMutex
	resources map[string]*CachedResource
	ttl       time.Duration
}

type CachedResource struct {
	Resource  Resource
	CachedAt  time.Time
	ExpiresAt time.Time
}

func NewDiscoverer(provider providers.Provider, logger *logrus.Logger, options DiscoveryOptions) *Discoverer {
	if options.MaxWorkers <= 0 {
		options.MaxWorkers = 10
	}
	if options.Timeout <= 0 {
		options.Timeout = 5 * time.Minute
	}
	if options.RetryAttempts <= 0 {
		options.RetryAttempts = 3
	}
	if options.RetryDelay <= 0 {
		options.RetryDelay = 2 * time.Second
	}
	if options.BatchSize <= 0 {
		options.BatchSize = 100
	}
	if options.RateLimit <= 0 {
		options.RateLimit = 100
	}

	discoverer := &Discoverer{
		provider: provider,
		logger:   logger,
		options:  options,
	}

	if options.CacheEnabled {
		discoverer.cache = &ResourceCache{
			resources: make(map[string]*CachedResource),
			ttl:       options.CacheDuration,
		}
		if discoverer.cache.ttl <= 0 {
			discoverer.cache.ttl = 5 * time.Minute
		}
	}

	return discoverer
}

func (d *Discoverer) Discover(ctx context.Context) (*DiscoveryResults, error) {
	results := &DiscoveryResults{
		StartTime: time.Now(),
		Resources: []Resource{},
		Summary: DiscoverySummary{
			ResourcesByType:   make(map[string]int),
			ResourcesByRegion: make(map[string]int),
			ResourcesByStatus: make(map[string]int),
		},
		Errors:   []DiscoveryError{},
		Metadata: make(map[string]interface{}),
	}

	ctx, cancel := context.WithTimeout(ctx, d.options.Timeout)
	defer cancel()

	resourceTypes := d.getResourceTypes()
	d.logger.Infof("Starting discovery for %d resource types", len(resourceTypes))

	var wg sync.WaitGroup
	resourceChan := make(chan Resource, d.options.BatchSize)
	errorChan := make(chan DiscoveryError, d.options.MaxWorkers)
	semaphore := make(chan struct{}, d.options.MaxWorkers)

	go func() {
		for resource := range resourceChan {
			d.mutex.Lock()
			results.Resources = append(results.Resources, resource)
			results.Summary.TotalResources++
			results.Summary.ResourcesByType[resource.Type]++
			results.Summary.ResourcesByRegion[resource.Region]++
			results.Summary.ResourcesByStatus[resource.Status]++
			if d.options.IncludeCosts && resource.Cost != nil {
				results.Summary.TotalCost += resource.Cost.Actual
				results.Summary.EstimatedMonthlyCost += resource.Cost.Estimated
			}
			d.mutex.Unlock()
		}
	}()

	go func() {
		for err := range errorChan {
			d.mutex.Lock()
			results.Errors = append(results.Errors, err)
			d.mutex.Unlock()
		}
	}()

	for _, resourceType := range resourceTypes {
		wg.Add(1)
		go func(rt string) {
			defer wg.Done()
			semaphore <- struct{}{}
			defer func() { <-semaphore }()

			d.discoverResourceType(ctx, rt, resourceChan, errorChan)
		}(resourceType)
	}

	wg.Wait()
	close(resourceChan)
	close(errorChan)

	results.EndTime = time.Now()
	results.Duration = results.EndTime.Sub(results.StartTime)

	if d.options.DeepScan {
		d.performDeepScan(ctx, results)
	}

	d.enrichResults(ctx, results)

	d.logger.Infof("Discovery completed: %d resources found in %v",
		results.Summary.TotalResources, results.Duration)

	return results, nil
}

func (d *Discoverer) discoverResourceType(ctx context.Context, resourceType string,
	resourceChan chan<- Resource, errorChan chan<- DiscoveryError) {

	d.logger.Debugf("Discovering resources of type: %s", resourceType)

	if d.cache != nil {
		if cachedResources := d.getCachedResources(resourceType); len(cachedResources) > 0 {
			d.logger.Debugf("Using %d cached resources for type %s", len(cachedResources), resourceType)
			for _, resource := range cachedResources {
				select {
				case resourceChan <- resource:
				case <-ctx.Done():
					return
				}
			}
			return
		}
	}

	var lastErr error
	for attempt := 0; attempt <= d.options.RetryAttempts; attempt++ {
		if attempt > 0 {
			select {
			case <-ctx.Done():
				return
			case <-time.After(d.options.RetryDelay * time.Duration(attempt)):
			}
		}

		resources, err := d.provider.ListResources(ctx, resourceType, d.options.Filters)
		if err == nil {
			for _, resource := range resources {
				if d.shouldIncludeResource(resource) {
					if d.options.DeepScan {
						d.enrichResource(ctx, &resource)
					}

					if d.cache != nil {
						d.cacheResource(resource)
					}

					select {
					case resourceChan <- resource:
					case <-ctx.Done():
						return
					}
				}
			}
			return
		}

		lastErr = err
		if !d.isRetryableError(err) {
			break
		}
	}

	if lastErr != nil {
		errorChan <- DiscoveryError{
			ResourceType: resourceType,
			Error:        lastErr.Error(),
			Timestamp:    time.Now(),
			Retryable:    d.isRetryableError(lastErr),
		}
	}
}

func (d *Discoverer) shouldIncludeResource(resource Resource) bool {
	if d.options.Filters == nil {
		return true
	}

	if labels, ok := d.options.Filters["labels"].(map[string]string); ok {
		for key, value := range labels {
			if resourceValue, exists := resource.Labels[key]; !exists || resourceValue != value {
				return false
			}
		}
	}

	if status, ok := d.options.Filters["status"].([]string); ok && len(status) > 0 {
		found := false
		for _, s := range status {
			if resource.Status == s {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}

	if networks, ok := d.options.Filters["networks"].([]string); ok && len(networks) > 0 {
		if resource.Network == "" {
			return false
		}
		found := false
		for _, n := range networks {
			if resource.Network == n {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}

	if createdAfter, ok := d.options.Filters["created_after"].(string); ok && createdAfter != "" {
		afterTime, err := time.Parse(time.RFC3339, createdAfter)
		if err == nil && resource.CreatedAt.Before(afterTime) {
			return false
		}
	}

	if createdBefore, ok := d.options.Filters["created_before"].(string); ok && createdBefore != "" {
		beforeTime, err := time.Parse(time.RFC3339, createdBefore)
		if err == nil && resource.CreatedAt.After(beforeTime) {
			return false
		}
	}

	return true
}

func (d *Discoverer) enrichResource(ctx context.Context, resource *Resource) {
	if d.options.IncludeTags {
		tags, err := d.provider.GetResourceTags(ctx, resource.ID, resource.Type)
		if err == nil {
			resource.Tags = tags
		}
	}

	if d.options.IncludeMetrics {
		metrics, err := d.provider.GetResourceMetrics(ctx, resource.ID, resource.Type)
		if err == nil {
			resource.Metrics = metrics
		}
	}

	if d.options.IncludeCosts {
		cost, err := d.provider.GetResourceCost(ctx, resource.ID, resource.Type)
		if err == nil {
			resource.Cost = cost
		}
	}

	dependencies, err := d.provider.GetResourceDependencies(ctx, resource.ID, resource.Type)
	if err == nil {
		resource.Dependencies = dependencies
	}

	config, err := d.provider.GetResourceConfiguration(ctx, resource.ID, resource.Type)
	if err == nil {
		resource.Configuration = config
	}
}

func (d *Discoverer) performDeepScan(ctx context.Context, results *DiscoveryResults) {
	d.logger.Info("Performing deep scan on discovered resources")

	var wg sync.WaitGroup
	semaphore := make(chan struct{}, d.options.MaxWorkers)

	for i := range results.Resources {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			semaphore <- struct{}{}
			defer func() { <-semaphore }()

			resource := &results.Resources[idx]

			compliance, err := d.provider.CheckResourceCompliance(ctx, resource.ID, resource.Type)
			if err == nil {
				resource.Compliance = compliance
			}

			vulnerabilities, err := d.provider.ScanResourceVulnerabilities(ctx, resource.ID, resource.Type)
			if err == nil {
				resource.Vulnerabilities = vulnerabilities
			}

			recommendations, err := d.provider.GetResourceRecommendations(ctx, resource.ID, resource.Type)
			if err == nil {
				resource.Recommendations = recommendations
			}
		}(i)
	}

	wg.Wait()
}

func (d *Discoverer) enrichResults(ctx context.Context, results *DiscoveryResults) {
	results.Metadata["provider"] = d.provider.Name()
	results.Metadata["project"] = d.provider.Project()
	results.Metadata["region"] = d.provider.Region()
	results.Metadata["discovery_options"] = d.options

	if len(results.Resources) > 0 {
		results.Metadata["first_resource_discovered"] = results.Resources[0].CreatedAt
		results.Metadata["last_resource_discovered"] = results.Resources[len(results.Resources)-1].CreatedAt
	}

	results.Metadata["error_rate"] = float64(len(results.Errors)) / float64(len(results.Resources)+len(results.Errors))

	if d.options.IncludeCosts {
		results.Metadata["cost_analysis"] = map[string]interface{}{
			"total_actual_cost":     results.Summary.TotalCost,
			"estimated_monthly":     results.Summary.EstimatedMonthlyCost,
			"estimated_annual":      results.Summary.EstimatedMonthlyCost * 12,
			"currency":             "USD",
		}
	}
}

func (d *Discoverer) getResourceTypes() []string {
	if d.options.ResourceTypes != "" {
		return []string{d.options.ResourceTypes}
	}

	return []string{
		"compute.instances",
		"compute.disks",
		"compute.networks",
		"compute.subnetworks",
		"compute.firewalls",
		"compute.loadBalancers",
		"compute.backendServices",
		"compute.healthChecks",
		"storage.buckets",
		"storage.objects",
		"sql.instances",
		"sql.databases",
		"bigquery.datasets",
		"bigquery.tables",
		"pubsub.topics",
		"pubsub.subscriptions",
		"cloudrun.services",
		"cloudfunctions.functions",
		"appengine.services",
		"kubernetes.clusters",
		"kubernetes.nodePools",
		"iam.serviceAccounts",
		"iam.roles",
		"iam.policies",
		"monitoring.alertPolicies",
		"monitoring.dashboards",
		"logging.sinks",
		"logging.metrics",
		"secretmanager.secrets",
		"kms.keyRings",
		"kms.cryptoKeys",
	}
}

func (d *Discoverer) isRetryableError(err error) bool {
	if err == nil {
		return false
	}

	errorStr := err.Error()
	retryablePatterns := []string{
		"timeout",
		"deadline exceeded",
		"rate limit",
		"throttle",
		"429",
		"503",
		"504",
		"connection reset",
		"connection refused",
		"temporary failure",
	}

	for _, pattern := range retryablePatterns {
		if containsIgnoreCase(errorStr, pattern) {
			return true
		}
	}

	return false
}

func (d *Discoverer) getCachedResources(resourceType string) []Resource {
	if d.cache == nil {
		return nil
	}

	d.cache.mutex.RLock()
	defer d.cache.mutex.RUnlock()

	var resources []Resource
	now := time.Now()

	for key, cached := range d.cache.resources {
		if cached.Resource.Type == resourceType && cached.ExpiresAt.After(now) {
			resources = append(resources, cached.Resource)
		} else if cached.ExpiresAt.Before(now) {
			delete(d.cache.resources, key)
		}
	}

	return resources
}

func (d *Discoverer) cacheResource(resource Resource) {
	if d.cache == nil {
		return
	}

	d.cache.mutex.Lock()
	defer d.cache.mutex.Unlock()

	now := time.Now()
	d.cache.resources[resource.ID] = &CachedResource{
		Resource:  resource,
		CachedAt:  now,
		ExpiresAt: now.Add(d.cache.ttl),
	}
}

func containsIgnoreCase(s, substr string) bool {
	if len(s) < len(substr) {
		return false
	}

	for i := 0; i <= len(s)-len(substr); i++ {
		match := true
		for j := 0; j < len(substr); j++ {
			if toLower(s[i+j]) != toLower(substr[j]) {
				match = false
				break
			}
		}
		if match {
			return true
		}
	}

	return false
}

func toLower(c byte) byte {
	if c >= 'A' && c <= 'Z' {
		return c + 32
	}
	return c
}