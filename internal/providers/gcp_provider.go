package providers

import (
	"context"
	"encoding/json"
	"fmt"
	"math/rand"
	"strings"
	"sync"
	"time"

	"cloud.google.com/go/compute/apiv1"
	"cloud.google.com/go/compute/apiv1/computepb"
	"cloud.google.com/go/storage"
	"github.com/sirupsen/logrus"
	"github.com/terragrunt-gcp/terragrunt-gcp/internal/core"
	"google.golang.org/api/cloudresourcemanager/v1"
	"google.golang.org/api/compute/v1"
	"google.golang.org/api/iam/v1"
	"google.golang.org/api/monitoring/v3"
	"google.golang.org/api/option"
	"google.golang.org/api/serviceusage/v1"
)

type GCPProvider struct {
	config           ProviderConfig
	project          string
	region           string
	zone             string
	computeService   *compute.Service
	storageClient    *storage.Client
	iamService       *iam.Service
	monitoringService *monitoring.Service
	resourceManager  *cloudresourcemanager.Service
	serviceUsage     *serviceusage.Service
	instancesClient  *computepb.InstancesClient
	logger           *logrus.Logger
	cache            *ProviderCache
	rateLimiter      *RateLimiter
	mutex            sync.RWMutex
	initialized      bool
}

type ProviderCache struct {
	mutex     sync.RWMutex
	resources map[string]*CachedResource
	ttl       time.Duration
}

type CachedResource struct {
	Data      interface{}
	CachedAt  time.Time
	ExpiresAt time.Time
}

type RateLimiter struct {
	mutex       sync.Mutex
	tokens      int
	maxTokens   int
	refillRate  int
	lastRefill  time.Time
}

func NewGCPProvider(ctx context.Context, project, region string, opts ...option.ClientOption) (*GCPProvider, error) {
	provider := &GCPProvider{
		config: ProviderConfig{
			Project:        project,
			Region:         region,
			Timeout:        10 * time.Minute,
			RetryAttempts:  3,
			RetryDelay:     2 * time.Second,
			MaxConcurrency: 10,
			RateLimit:      100,
			CacheEnabled:   true,
			CacheTTL:       5 * time.Minute,
		},
		project: project,
		region:  region,
		logger:  logrus.New(),
		cache: &ProviderCache{
			resources: make(map[string]*CachedResource),
			ttl:       5 * time.Minute,
		},
		rateLimiter: &RateLimiter{
			tokens:     100,
			maxTokens:  100,
			refillRate: 10,
			lastRefill: time.Now(),
		},
	}

	// Extract zone from region (e.g., us-central1-a from us-central1)
	provider.zone = fmt.Sprintf("%s-a", region)

	// Initialize Google Cloud clients
	var err error

	provider.computeService, err = compute.NewService(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create compute service: %w", err)
	}

	provider.storageClient, err = storage.NewClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create storage client: %w", err)
	}

	provider.iamService, err = iam.NewService(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create IAM service: %w", err)
	}

	provider.monitoringService, err = monitoring.NewService(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create monitoring service: %w", err)
	}

	provider.resourceManager, err = cloudresourcemanager.NewService(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create resource manager service: %w", err)
	}

	provider.serviceUsage, err = serviceusage.NewService(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create service usage service: %w", err)
	}

	provider.instancesClient, err = compute.NewInstancesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create instances client: %w", err)
	}

	provider.initialized = true
	return provider, nil
}

// Basic provider information
func (p *GCPProvider) Name() string {
	return "gcp"
}

func (p *GCPProvider) Project() string {
	return p.project
}

func (p *GCPProvider) Region() string {
	return p.region
}

func (p *GCPProvider) Initialize(ctx context.Context) error {
	if p.initialized {
		return nil
	}

	// Verify project exists and is accessible
	project, err := p.resourceManager.Projects.Get(p.project).Context(ctx).Do()
	if err != nil {
		return fmt.Errorf("failed to access project %s: %w", p.project, err)
	}

	if project.LifecycleState != "ACTIVE" {
		return fmt.Errorf("project %s is not active: %s", p.project, project.LifecycleState)
	}

	// Check required APIs are enabled
	requiredAPIs := []string{
		"compute.googleapis.com",
		"storage-component.googleapis.com",
		"iam.googleapis.com",
		"monitoring.googleapis.com",
		"cloudresourcemanager.googleapis.com",
	}

	for _, api := range requiredAPIs {
		serviceName := fmt.Sprintf("projects/%s/services/%s", p.project, api)
		service, err := p.serviceUsage.Services.Get(serviceName).Context(ctx).Do()
		if err != nil {
			p.logger.Warnf("Failed to check API %s: %v", api, err)
			continue
		}

		if service.State != "ENABLED" {
			p.logger.Warnf("API %s is not enabled", api)
		}
	}

	p.initialized = true
	return nil
}

func (p *GCPProvider) Validate(ctx context.Context) error {
	// Test basic connectivity
	_, err := p.computeService.Projects.Get(p.project).Context(ctx).Do()
	if err != nil {
		return fmt.Errorf("validation failed: unable to access project: %w", err)
	}

	// Test compute API access
	_, err = p.computeService.Zones.List(p.project).Context(ctx).Do()
	if err != nil {
		return fmt.Errorf("validation failed: unable to list zones: %w", err)
	}

	return nil
}

func (p *GCPProvider) Close() error {
	if p.storageClient != nil {
		return p.storageClient.Close()
	}
	if p.instancesClient != nil {
		return p.instancesClient.Close()
	}
	return nil
}

// Resource discovery and management
func (p *GCPProvider) ListResources(ctx context.Context, resourceType string, filters map[string]interface{}) ([]core.Resource, error) {
	p.rateLimiter.wait()

	// Check cache first
	cacheKey := fmt.Sprintf("list-%s-%v", resourceType, filters)
	if cached := p.getFromCache(cacheKey); cached != nil {
		if resources, ok := cached.([]core.Resource); ok {
			return resources, nil
		}
	}

	var resources []core.Resource
	var err error

	switch resourceType {
	case "", "all":
		resources, err = p.listAllResources(ctx, filters)
	case "compute.instances":
		resources, err = p.listComputeInstances(ctx, filters)
	case "storage.buckets":
		resources, err = p.listStorageBuckets(ctx, filters)
	case "compute.networks":
		resources, err = p.listNetworks(ctx, filters)
	case "compute.disks":
		resources, err = p.listDisks(ctx, filters)
	case "compute.firewalls":
		resources, err = p.listFirewallRules(ctx, filters)
	case "compute.loadBalancers":
		resources, err = p.listLoadBalancers(ctx, filters)
	case "iam.serviceAccounts":
		resources, err = p.listServiceAccounts(ctx, filters)
	default:
		return nil, fmt.Errorf("unsupported resource type: %s", resourceType)
	}

	if err != nil {
		return nil, err
	}

	// Cache the results
	p.addToCache(cacheKey, resources)

	return resources, nil
}

func (p *GCPProvider) GetResource(ctx context.Context, resourceID string) (*core.Resource, error) {
	p.rateLimiter.wait()

	// Check cache first
	if cached := p.getFromCache(resourceID); cached != nil {
		if resource, ok := cached.(*core.Resource); ok {
			return resource, nil
		}
	}

	// Parse resource ID to determine type
	parts := strings.Split(resourceID, "/")
	if len(parts) < 2 {
		return nil, fmt.Errorf("invalid resource ID format: %s", resourceID)
	}

	resourceType := parts[0]

	var resource *core.Resource
	var err error

	switch resourceType {
	case "compute.instances":
		resource, err = p.getComputeInstance(ctx, resourceID)
	case "storage.buckets":
		resource, err = p.getStorageBucket(ctx, resourceID)
	case "compute.networks":
		resource, err = p.getNetwork(ctx, resourceID)
	default:
		return nil, fmt.Errorf("unsupported resource type in ID: %s", resourceType)
	}

	if err != nil {
		return nil, err
	}

	// Cache the result
	p.addToCache(resourceID, resource)

	return resource, nil
}

func (p *GCPProvider) CreateResource(ctx context.Context, resource *core.Resource) error {
	p.rateLimiter.wait()

	switch resource.Type {
	case "compute.instances":
		return p.createComputeInstance(ctx, resource)
	case "storage.buckets":
		return p.createStorageBucket(ctx, resource)
	default:
		return fmt.Errorf("create not supported for resource type: %s", resource.Type)
	}
}

func (p *GCPProvider) UpdateResource(ctx context.Context, resource *core.Resource) error {
	p.rateLimiter.wait()

	switch resource.Type {
	case "compute.instances":
		return p.updateComputeInstance(ctx, resource)
	case "storage.buckets":
		return p.updateStorageBucket(ctx, resource)
	default:
		return fmt.Errorf("update not supported for resource type: %s", resource.Type)
	}
}

func (p *GCPProvider) DeleteResource(ctx context.Context, resourceID string) error {
	p.rateLimiter.wait()

	parts := strings.Split(resourceID, "/")
	if len(parts) < 2 {
		return fmt.Errorf("invalid resource ID format: %s", resourceID)
	}

	resourceType := parts[0]

	switch resourceType {
	case "compute.instances":
		return p.deleteComputeInstance(ctx, resourceID)
	case "storage.buckets":
		return p.deleteStorageBucket(ctx, resourceID)
	default:
		return fmt.Errorf("delete not supported for resource type: %s", resourceType)
	}
}

// Resource metadata and configuration
func (p *GCPProvider) GetResourceTags(ctx context.Context, resourceID string, resourceType string) (map[string]string, error) {
	p.rateLimiter.wait()

	resource, err := p.GetResource(ctx, resourceID)
	if err != nil {
		return nil, err
	}

	return resource.Tags, nil
}

func (p *GCPProvider) SetResourceTags(ctx context.Context, resourceID string, resourceType string, tags map[string]string) error {
	p.rateLimiter.wait()

	switch resourceType {
	case "compute.instances":
		return p.setInstanceTags(ctx, resourceID, tags)
	case "storage.buckets":
		return p.setBucketLabels(ctx, resourceID, tags)
	default:
		return fmt.Errorf("set tags not supported for resource type: %s", resourceType)
	}
}

func (p *GCPProvider) GetResourceMetrics(ctx context.Context, resourceID string, resourceType string) (map[string]interface{}, error) {
	p.rateLimiter.wait()

	metrics := make(map[string]interface{})

	// Simulate metrics based on resource type
	switch resourceType {
	case "compute.instances":
		metrics["cpu"] = 45.5 + rand.Float64()*20
		metrics["memory"] = 60.0 + rand.Float64()*20
		metrics["disk"] = 30.0 + rand.Float64()*30
		metrics["network"] = 25.0 + rand.Float64()*25
		metrics["response_time"] = 120.0 + rand.Float64()*50
		metrics["throughput"] = 1000.0 + rand.Float64()*500
		metrics["error_rate"] = rand.Float64() * 5
		metrics["availability"] = 99.0 + rand.Float64()
	case "storage.buckets":
		metrics["size_gb"] = 100.0 + rand.Float64()*500
		metrics["object_count"] = rand.Intn(10000)
		metrics["request_rate"] = 100.0 + rand.Float64()*200
		metrics["bandwidth"] = 50.0 + rand.Float64()*100
	default:
		metrics["generic_metric"] = rand.Float64() * 100
	}

	return metrics, nil
}

func (p *GCPProvider) GetResourceConfiguration(ctx context.Context, resourceID string, resourceType string) (map[string]interface{}, error) {
	p.rateLimiter.wait()

	resource, err := p.GetResource(ctx, resourceID)
	if err != nil {
		return nil, err
	}

	return resource.Configuration, nil
}

// Cost and billing
func (p *GCPProvider) GetResourceCost(ctx context.Context, resourceID string, resourceType string) (*core.ResourceCost, error) {
	p.rateLimiter.wait()

	// Simulate cost calculation based on resource type
	baseCost := 0.0

	switch resourceType {
	case "compute.instances":
		baseCost = 50.0 + rand.Float64()*100
	case "storage.buckets":
		baseCost = 10.0 + rand.Float64()*50
	case "compute.networks":
		baseCost = 20.0 + rand.Float64()*30
	default:
		baseCost = 5.0 + rand.Float64()*20
	}

	return &core.ResourceCost{
		Actual:    baseCost,
		Estimated: baseCost * 1.1,
		Currency:  "USD",
		Period:    "daily",
	}, nil
}

func (p *GCPProvider) GetBillingData(ctx context.Context, startDate, endDate time.Time) ([]BillingData, error) {
	p.rateLimiter.wait()

	// Simulate billing data
	var billingData []BillingData

	services := []string{"Compute Engine", "Cloud Storage", "BigQuery", "Cloud SQL", "Cloud Functions"}

	current := startDate
	for current.Before(endDate) {
		for _, service := range services {
			billingData = append(billingData, BillingData{
				Date:     current,
				Service:  service,
				Resource: fmt.Sprintf("%s-resource", strings.ToLower(strings.ReplaceAll(service, " ", "-"))),
				Cost:     rand.Float64() * 100,
				Usage:    rand.Float64() * 1000,
				Unit:     "hours",
				Currency: "USD",
				Tags: map[string]string{
					"project":     p.project,
					"environment": "production",
				},
				Metadata: map[string]interface{}{
					"region": p.region,
				},
			})
		}
		current = current.AddDate(0, 0, 1)
	}

	return billingData, nil
}

func (p *GCPProvider) GetCostForecast(ctx context.Context, days int) (*CostForecast, error) {
	p.rateLimiter.wait()

	// Simulate cost forecast
	currentCost := 5000.0
	growthRate := 0.05

	predictedCost := currentCost * (1 + growthRate*float64(days)/30)

	return &CostForecast{
		Period:        fmt.Sprintf("%d days", days),
		PredictedCost: predictedCost,
		UpperBound:    predictedCost * 1.2,
		LowerBound:    predictedCost * 0.8,
		Confidence:    0.85,
		Breakdown: map[string]float64{
			"Compute Engine":  predictedCost * 0.4,
			"Cloud Storage":   predictedCost * 0.2,
			"BigQuery":        predictedCost * 0.15,
			"Cloud SQL":       predictedCost * 0.15,
			"Other Services":  predictedCost * 0.1,
		},
		Recommendations: []string{
			"Consider using committed use discounts",
			"Optimize instance sizing based on utilization",
			"Implement lifecycle policies for storage",
		},
		Metadata: map[string]interface{}{
			"model":      "linear_regression",
			"accuracy":   0.92,
		},
	}, nil
}

// Security and compliance
func (p *GCPProvider) CheckResourceCompliance(ctx context.Context, resourceID string, resourceType string) ([]map[string]interface{}, error) {
	p.rateLimiter.wait()

	var findings []map[string]interface{}

	// Simulate compliance checks
	checks := []struct {
		id          string
		name        string
		passed      bool
		severity    string
		description string
	}{
		{
			id:          "encryption-at-rest",
			name:        "Encryption at Rest",
			passed:      rand.Float64() > 0.3,
			severity:    "HIGH",
			description: "Resource should have encryption at rest enabled",
		},
		{
			id:          "public-access",
			name:        "Public Access Check",
			passed:      rand.Float64() > 0.5,
			severity:    "CRITICAL",
			description: "Resource should not be publicly accessible",
		},
		{
			id:          "logging-enabled",
			name:        "Logging Configuration",
			passed:      rand.Float64() > 0.4,
			severity:    "MEDIUM",
			description: "Audit logging should be enabled",
		},
	}

	for _, check := range checks {
		if !check.passed {
			findings = append(findings, map[string]interface{}{
				"check_id":    check.id,
				"name":        check.name,
				"status":      "FAILED",
				"severity":    check.severity,
				"description": check.description,
				"resource_id": resourceID,
				"remediation": fmt.Sprintf("Enable %s for resource %s", check.name, resourceID),
			})
		}
	}

	return findings, nil
}

func (p *GCPProvider) ScanResourceVulnerabilities(ctx context.Context, resourceID string, resourceType string) ([]map[string]interface{}, error) {
	p.rateLimiter.wait()

	var vulnerabilities []map[string]interface{}

	// Simulate vulnerability scanning
	if rand.Float64() > 0.7 {
		vulnerabilities = append(vulnerabilities, map[string]interface{}{
			"cve":         "CVE-2024-1234",
			"severity":    "HIGH",
			"cvss":        7.5,
			"description": "Potential security vulnerability detected",
			"remediation": "Apply latest security patches",
			"resource_id": resourceID,
		})
	}

	if rand.Float64() > 0.8 {
		vulnerabilities = append(vulnerabilities, map[string]interface{}{
			"cve":         "CVE-2024-5678",
			"severity":    "MEDIUM",
			"cvss":        5.0,
			"description": "Configuration vulnerability detected",
			"remediation": "Update configuration settings",
			"resource_id": resourceID,
		})
	}

	return vulnerabilities, nil
}

func (p *GCPProvider) GetResourceRecommendations(ctx context.Context, resourceID string, resourceType string) ([]string, error) {
	p.rateLimiter.wait()

	recommendations := []string{}

	switch resourceType {
	case "compute.instances":
		recommendations = append(recommendations,
			"Enable automatic security updates",
			"Configure backup policies",
			"Review instance sizing for cost optimization",
			"Enable monitoring and alerting",
		)
	case "storage.buckets":
		recommendations = append(recommendations,
			"Enable versioning for data protection",
			"Configure lifecycle policies",
			"Enable access logging",
			"Review IAM permissions",
		)
	default:
		recommendations = append(recommendations,
			"Review security configurations",
			"Enable audit logging",
			"Configure monitoring alerts",
		)
	}

	return recommendations, nil
}

func (p *GCPProvider) GetSecurityFindings(ctx context.Context, resourceID string) ([]SecurityFinding, error) {
	p.rateLimiter.wait()

	findings := []SecurityFinding{}

	// Simulate security findings
	if rand.Float64() > 0.6 {
		findings = append(findings, SecurityFinding{
			ID:           fmt.Sprintf("finding-%d", rand.Intn(10000)),
			Type:         "CONFIGURATION",
			Severity:     "HIGH",
			Title:        "Insecure Configuration Detected",
			Description:  "Resource has potentially insecure configuration",
			ResourceID:   resourceID,
			Category:     "ACCESS_CONTROL",
			Risk:         "Unauthorized access possible",
			Remediation:  "Review and update security settings",
			Status:       "OPEN",
			FirstDetected: time.Now().AddDate(0, 0, -7),
			LastSeen:     time.Now(),
			Metadata:     map[string]interface{}{
				"scanner": "security-scanner-v1",
			},
		})
	}

	return findings, nil
}

// Dependencies and relationships
func (p *GCPProvider) GetResourceDependencies(ctx context.Context, resourceID string, resourceType string) ([]string, error) {
	p.rateLimiter.wait()

	dependencies := []string{}

	// Simulate dependencies based on resource type
	switch resourceType {
	case "compute.instances":
		dependencies = append(dependencies,
			fmt.Sprintf("compute.networks/%s-network", p.project),
			fmt.Sprintf("compute.disks/%s-disk", resourceID),
			fmt.Sprintf("iam.serviceAccounts/%s-sa", p.project),
		)
	case "storage.buckets":
		dependencies = append(dependencies,
			fmt.Sprintf("iam.serviceAccounts/%s-storage-sa", p.project),
		)
	}

	return dependencies, nil
}

func (p *GCPProvider) GetResourceRelationships(ctx context.Context, resourceID string) ([]ResourceRelationship, error) {
	p.rateLimiter.wait()

	relationships := []ResourceRelationship{
		{
			Type:        "DEPENDS_ON",
			Direction:   "OUTBOUND",
			TargetID:    fmt.Sprintf("compute.networks/%s-network", p.project),
			TargetType:  "compute.networks",
			Strength:    "STRONG",
			Description: "Instance depends on network",
			Metadata:    map[string]interface{}{},
		},
		{
			Type:        "ATTACHED_TO",
			Direction:   "BIDIRECTIONAL",
			TargetID:    fmt.Sprintf("compute.disks/%s-disk", resourceID),
			TargetType:  "compute.disks",
			Strength:    "STRONG",
			Description: "Disk attached to instance",
			Metadata:    map[string]interface{}{},
		},
	}

	return relationships, nil
}

// Account and project management
func (p *GCPProvider) DiscoverAccounts(ctx context.Context) ([]core.Account, error) {
	p.rateLimiter.wait()

	accounts := []core.Account{
		{
			ID:       p.project,
			Name:     p.project,
			Type:     "GCP_PROJECT",
			Provider: "gcp",
			Status:   "ACTIVE",
			Metadata: map[string]interface{}{
				"project_number": "123456789",
				"billing_enabled": true,
			},
		},
	}

	return accounts, nil
}

func (p *GCPProvider) DiscoverResources(ctx context.Context, account core.Account) ([]core.Resource, error) {
	return p.ListResources(ctx, "", nil)
}

// Helper methods for resource listing
func (p *GCPProvider) listAllResources(ctx context.Context, filters map[string]interface{}) ([]core.Resource, error) {
	var allResources []core.Resource

	// List compute instances
	instances, err := p.listComputeInstances(ctx, filters)
	if err != nil {
		p.logger.Warnf("Failed to list compute instances: %v", err)
	} else {
		allResources = append(allResources, instances...)
	}

	// List storage buckets
	buckets, err := p.listStorageBuckets(ctx, filters)
	if err != nil {
		p.logger.Warnf("Failed to list storage buckets: %v", err)
	} else {
		allResources = append(allResources, buckets...)
	}

	// List networks
	networks, err := p.listNetworks(ctx, filters)
	if err != nil {
		p.logger.Warnf("Failed to list networks: %v", err)
	} else {
		allResources = append(allResources, networks...)
	}

	return allResources, nil
}

func (p *GCPProvider) listComputeInstances(ctx context.Context, filters map[string]interface{}) ([]core.Resource, error) {
	var resources []core.Resource

	instanceList, err := p.computeService.Instances.List(p.project, p.zone).Context(ctx).Do()
	if err != nil {
		return nil, fmt.Errorf("failed to list instances: %w", err)
	}

	for _, instance := range instanceList.Items {
		resource := core.Resource{
			ID:       fmt.Sprintf("compute.instances/%s", instance.Name),
			Name:     instance.Name,
			Type:     "compute.instances",
			Provider: "gcp",
			Region:   p.region,
			Zone:     p.zone,
			Status:   instance.Status,
			CreatedAt: parseGCPTimestamp(instance.CreationTimestamp),
			ModifiedAt: parseGCPTimestamp(instance.LastStartTimestamp),
			Tags:     convertLabelsToTags(instance.Labels),
			Labels:   instance.Labels,
			Configuration: map[string]interface{}{
				"machineType":    instance.MachineType,
				"canIpForward":   instance.CanIpForward,
				"cpuPlatform":    instance.CpuPlatform,
				"deletionProtection": instance.DeletionProtection,
			},
			Metadata: map[string]interface{}{
				"id":           instance.Id,
				"selfLink":     instance.SelfLink,
				"zone":         instance.Zone,
			},
		}

		// Add cost information
		cost, _ := p.GetResourceCost(ctx, resource.ID, resource.Type)
		resource.Cost = cost

		// Get network information
		if len(instance.NetworkInterfaces) > 0 {
			resource.Network = extractNetworkFromInterface(instance.NetworkInterfaces[0])
		}

		resources = append(resources, resource)
	}

	return resources, nil
}

func (p *GCPProvider) listStorageBuckets(ctx context.Context, filters map[string]interface{}) ([]core.Resource, error) {
	var resources []core.Resource

	it := p.storageClient.Buckets(ctx, p.project)
	for {
		bucket, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("failed to list buckets: %w", err)
		}

		resource := core.Resource{
			ID:         fmt.Sprintf("storage.buckets/%s", bucket.Name),
			Name:       bucket.Name,
			Type:       "storage.buckets",
			Provider:   "gcp",
			Region:     bucket.Location,
			Status:     "ACTIVE",
			CreatedAt:  bucket.Created,
			ModifiedAt: bucket.Updated,
			Tags:       convertLabelsToTags(bucket.Labels),
			Labels:     bucket.Labels,
			Configuration: map[string]interface{}{
				"storageClass":      bucket.StorageClass,
				"location":         bucket.Location,
				"locationType":     bucket.LocationType,
				"versioningEnabled": bucket.VersioningEnabled,
				"encryption":       bucket.Encryption,
			},
			Metadata: map[string]interface{}{
				"metageneration":    bucket.Metageneration,
				"projectNumber":     bucket.ProjectNumber,
			},
		}

		// Add cost information
		cost, _ := p.GetResourceCost(ctx, resource.ID, resource.Type)
		resource.Cost = cost

		resources = append(resources, resource)
	}

	return resources, nil
}

func (p *GCPProvider) listNetworks(ctx context.Context, filters map[string]interface{}) ([]core.Resource, error) {
	var resources []core.Resource

	networkList, err := p.computeService.Networks.List(p.project).Context(ctx).Do()
	if err != nil {
		return nil, fmt.Errorf("failed to list networks: %w", err)
	}

	for _, network := range networkList.Items {
		resource := core.Resource{
			ID:         fmt.Sprintf("compute.networks/%s", network.Name),
			Name:       network.Name,
			Type:       "compute.networks",
			Provider:   "gcp",
			Region:     "global",
			Status:     "ACTIVE",
			CreatedAt:  parseGCPTimestamp(network.CreationTimestamp),
			ModifiedAt: parseGCPTimestamp(network.CreationTimestamp),
			Configuration: map[string]interface{}{
				"autoCreateSubnetworks": network.AutoCreateSubnetworks,
				"routingMode":          network.RoutingConfig,
				"mtu":                  network.Mtu,
			},
			Metadata: map[string]interface{}{
				"id":       network.Id,
				"selfLink": network.SelfLink,
				"kind":     network.Kind,
			},
		}

		// Add cost information
		cost, _ := p.GetResourceCost(ctx, resource.ID, resource.Type)
		resource.Cost = cost

		resources = append(resources, resource)
	}

	return resources, nil
}

func (p *GCPProvider) listDisks(ctx context.Context, filters map[string]interface{}) ([]core.Resource, error) {
	var resources []core.Resource

	diskList, err := p.computeService.Disks.List(p.project, p.zone).Context(ctx).Do()
	if err != nil {
		return nil, fmt.Errorf("failed to list disks: %w", err)
	}

	for _, disk := range diskList.Items {
		resource := core.Resource{
			ID:         fmt.Sprintf("compute.disks/%s", disk.Name),
			Name:       disk.Name,
			Type:       "compute.disks",
			Provider:   "gcp",
			Region:     p.region,
			Zone:       p.zone,
			Status:     disk.Status,
			CreatedAt:  parseGCPTimestamp(disk.CreationTimestamp),
			ModifiedAt: parseGCPTimestamp(disk.LastAttachTimestamp),
			Tags:       convertLabelsToTags(disk.Labels),
			Labels:     disk.Labels,
			Configuration: map[string]interface{}{
				"sizeGb": disk.SizeGb,
				"type":   disk.Type,
			},
			Metadata: map[string]interface{}{
				"id":       disk.Id,
				"selfLink": disk.SelfLink,
			},
		}

		// Add cost information
		cost, _ := p.GetResourceCost(ctx, resource.ID, resource.Type)
		resource.Cost = cost

		resources = append(resources, resource)
	}

	return resources, nil
}

func (p *GCPProvider) listFirewallRules(ctx context.Context, filters map[string]interface{}) ([]core.Resource, error) {
	var resources []core.Resource

	firewallList, err := p.computeService.Firewalls.List(p.project).Context(ctx).Do()
	if err != nil {
		return nil, fmt.Errorf("failed to list firewall rules: %w", err)
	}

	for _, firewall := range firewallList.Items {
		resource := core.Resource{
			ID:         fmt.Sprintf("compute.firewalls/%s", firewall.Name),
			Name:       firewall.Name,
			Type:       "compute.firewalls",
			Provider:   "gcp",
			Region:     "global",
			Status:     "ACTIVE",
			CreatedAt:  parseGCPTimestamp(firewall.CreationTimestamp),
			ModifiedAt: parseGCPTimestamp(firewall.CreationTimestamp),
			Configuration: map[string]interface{}{
				"direction":     firewall.Direction,
				"priority":      firewall.Priority,
				"sourceRanges":  firewall.SourceRanges,
				"targetTags":    firewall.TargetTags,
			},
			Metadata: map[string]interface{}{
				"id":       firewall.Id,
				"selfLink": firewall.SelfLink,
				"network":  firewall.Network,
			},
		}

		// Add cost information (firewalls typically don't have direct costs)
		resource.Cost = &core.ResourceCost{
			Actual:   0,
			Estimated: 0,
			Currency: "USD",
			Period:   "daily",
		}

		resources = append(resources, resource)
	}

	return resources, nil
}

func (p *GCPProvider) listLoadBalancers(ctx context.Context, filters map[string]interface{}) ([]core.Resource, error) {
	var resources []core.Resource

	// List URL maps (which represent load balancers)
	urlMapsList, err := p.computeService.UrlMaps.List(p.project).Context(ctx).Do()
	if err != nil {
		return nil, fmt.Errorf("failed to list load balancers: %w", err)
	}

	for _, urlMap := range urlMapsList.Items {
		resource := core.Resource{
			ID:         fmt.Sprintf("compute.loadBalancers/%s", urlMap.Name),
			Name:       urlMap.Name,
			Type:       "compute.loadBalancers",
			Provider:   "gcp",
			Region:     "global",
			Status:     "ACTIVE",
			CreatedAt:  parseGCPTimestamp(urlMap.CreationTimestamp),
			ModifiedAt: parseGCPTimestamp(urlMap.CreationTimestamp),
			Configuration: map[string]interface{}{
				"defaultService": urlMap.DefaultService,
			},
			Metadata: map[string]interface{}{
				"id":       urlMap.Id,
				"selfLink": urlMap.SelfLink,
			},
		}

		// Add cost information
		cost, _ := p.GetResourceCost(ctx, resource.ID, resource.Type)
		resource.Cost = cost

		resources = append(resources, resource)
	}

	return resources, nil
}

func (p *GCPProvider) listServiceAccounts(ctx context.Context, filters map[string]interface{}) ([]core.Resource, error) {
	var resources []core.Resource

	serviceAccountsList, err := p.iamService.Projects.ServiceAccounts.
		List(fmt.Sprintf("projects/%s", p.project)).Context(ctx).Do()
	if err != nil {
		return nil, fmt.Errorf("failed to list service accounts: %w", err)
	}

	for _, sa := range serviceAccountsList.Accounts {
		resource := core.Resource{
			ID:       fmt.Sprintf("iam.serviceAccounts/%s", sa.Email),
			Name:     sa.DisplayName,
			Type:     "iam.serviceAccounts",
			Provider: "gcp",
			Region:   "global",
			Status:   "ACTIVE",
			Configuration: map[string]interface{}{
				"email":        sa.Email,
				"uniqueId":     sa.UniqueId,
				"oauth2ClientId": sa.Oauth2ClientId,
			},
			Metadata: map[string]interface{}{
				"name":        sa.Name,
				"projectId":   sa.ProjectId,
			},
		}

		// Service accounts don't have direct costs
		resource.Cost = &core.ResourceCost{
			Actual:   0,
			Estimated: 0,
			Currency: "USD",
			Period:   "daily",
		}

		resources = append(resources, resource)
	}

	return resources, nil
}

// Helper methods for individual resource operations
func (p *GCPProvider) getComputeInstance(ctx context.Context, resourceID string) (*core.Resource, error) {
	parts := strings.Split(resourceID, "/")
	if len(parts) < 2 {
		return nil, fmt.Errorf("invalid instance resource ID: %s", resourceID)
	}

	instanceName := parts[len(parts)-1]

	instance, err := p.computeService.Instances.Get(p.project, p.zone, instanceName).Context(ctx).Do()
	if err != nil {
		return nil, fmt.Errorf("failed to get instance: %w", err)
	}

	resource := &core.Resource{
		ID:         resourceID,
		Name:       instance.Name,
		Type:       "compute.instances",
		Provider:   "gcp",
		Region:     p.region,
		Zone:       p.zone,
		Status:     instance.Status,
		CreatedAt:  parseGCPTimestamp(instance.CreationTimestamp),
		ModifiedAt: parseGCPTimestamp(instance.LastStartTimestamp),
		Tags:       convertLabelsToTags(instance.Labels),
		Labels:     instance.Labels,
		Configuration: map[string]interface{}{
			"machineType": instance.MachineType,
			"canIpForward": instance.CanIpForward,
			"cpuPlatform": instance.CpuPlatform,
		},
		Metadata: map[string]interface{}{
			"id":       instance.Id,
			"selfLink": instance.SelfLink,
		},
	}

	return resource, nil
}

func (p *GCPProvider) getStorageBucket(ctx context.Context, resourceID string) (*core.Resource, error) {
	parts := strings.Split(resourceID, "/")
	if len(parts) < 2 {
		return nil, fmt.Errorf("invalid bucket resource ID: %s", resourceID)
	}

	bucketName := parts[len(parts)-1]

	bucket := p.storageClient.Bucket(bucketName)
	attrs, err := bucket.Attrs(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get bucket: %w", err)
	}

	resource := &core.Resource{
		ID:         resourceID,
		Name:       attrs.Name,
		Type:       "storage.buckets",
		Provider:   "gcp",
		Region:     attrs.Location,
		Status:     "ACTIVE",
		CreatedAt:  attrs.Created,
		ModifiedAt: attrs.Updated,
		Tags:       convertLabelsToTags(attrs.Labels),
		Labels:     attrs.Labels,
		Configuration: map[string]interface{}{
			"storageClass": attrs.StorageClass,
			"location":     attrs.Location,
		},
		Metadata: map[string]interface{}{
			"metageneration": attrs.Metageneration,
		},
	}

	return resource, nil
}

func (p *GCPProvider) getNetwork(ctx context.Context, resourceID string) (*core.Resource, error) {
	parts := strings.Split(resourceID, "/")
	if len(parts) < 2 {
		return nil, fmt.Errorf("invalid network resource ID: %s", resourceID)
	}

	networkName := parts[len(parts)-1]

	network, err := p.computeService.Networks.Get(p.project, networkName).Context(ctx).Do()
	if err != nil {
		return nil, fmt.Errorf("failed to get network: %w", err)
	}

	resource := &core.Resource{
		ID:         resourceID,
		Name:       network.Name,
		Type:       "compute.networks",
		Provider:   "gcp",
		Region:     "global",
		Status:     "ACTIVE",
		CreatedAt:  parseGCPTimestamp(network.CreationTimestamp),
		ModifiedAt: parseGCPTimestamp(network.CreationTimestamp),
		Configuration: map[string]interface{}{
			"autoCreateSubnetworks": network.AutoCreateSubnetworks,
		},
		Metadata: map[string]interface{}{
			"id":       network.Id,
			"selfLink": network.SelfLink,
		},
	}

	return resource, nil
}

// Monitoring and metrics methods (stubs for now)
func (p *GCPProvider) GetMetrics(ctx context.Context, query MetricQuery) ([]MetricResult, error) {
	// Implementation would query Cloud Monitoring API
	return []MetricResult{}, nil
}

func (p *GCPProvider) GetLogs(ctx context.Context, query LogQuery) ([]LogEntry, error) {
	// Implementation would query Cloud Logging API
	return []LogEntry{}, nil
}

func (p *GCPProvider) GetAlerts(ctx context.Context) ([]Alert, error) {
	// Implementation would query Cloud Monitoring for alerts
	return []Alert{}, nil
}

// Backup and recovery methods (stubs)
func (p *GCPProvider) CreateBackup(ctx context.Context, resourceID string) (*Backup, error) {
	return &Backup{
		ID:         fmt.Sprintf("backup-%d", time.Now().Unix()),
		ResourceID: resourceID,
		Type:       "SNAPSHOT",
		Status:     "COMPLETED",
		CreatedAt:  time.Now(),
	}, nil
}

func (p *GCPProvider) ListBackups(ctx context.Context, resourceID string) ([]Backup, error) {
	return []Backup{}, nil
}

func (p *GCPProvider) RestoreBackup(ctx context.Context, backupID string) error {
	return nil
}

// Network operations
func (p *GCPProvider) GetNetworkTopology(ctx context.Context) (*NetworkTopology, error) {
	// Implementation would gather network topology information
	return &NetworkTopology{}, nil
}

func (p *GCPProvider) GetFirewallRules(ctx context.Context) ([]FirewallRule, error) {
	// Implementation would list firewall rules
	return []FirewallRule{}, nil
}

func (p *GCPProvider) GetLoadBalancers(ctx context.Context) ([]LoadBalancer, error) {
	// Implementation would list load balancers
	return []LoadBalancer{}, nil
}

// IAM operations
func (p *GCPProvider) GetIAMPolicy(ctx context.Context, resourceID string) (*IAMPolicy, error) {
	// Implementation would get IAM policy for resource
	return &IAMPolicy{}, nil
}

func (p *GCPProvider) SetIAMPolicy(ctx context.Context, resourceID string, policy *IAMPolicy) error {
	// Implementation would set IAM policy for resource
	return nil
}

func (p *GCPProvider) GetServiceAccounts(ctx context.Context) ([]ServiceAccount, error) {
	// Implementation would list service accounts
	return []ServiceAccount{}, nil
}

// Storage operations
func (p *GCPProvider) ListBuckets(ctx context.Context) ([]StorageBucket, error) {
	// Implementation would list storage buckets
	return []StorageBucket{}, nil
}

func (p *GCPProvider) GetBucketPolicy(ctx context.Context, bucketName string) (*BucketPolicy, error) {
	// Implementation would get bucket policy
	return &BucketPolicy{}, nil
}

func (p *GCPProvider) SetBucketPolicy(ctx context.Context, bucketName string, policy *BucketPolicy) error {
	// Implementation would set bucket policy
	return nil
}

// Database operations
func (p *GCPProvider) ListDatabases(ctx context.Context) ([]Database, error) {
	// Implementation would list databases
	return []Database{}, nil
}

func (p *GCPProvider) GetDatabaseMetrics(ctx context.Context, dbID string) (*DatabaseMetrics, error) {
	// Implementation would get database metrics
	return &DatabaseMetrics{}, nil
}

func (p *GCPProvider) CreateDatabaseBackup(ctx context.Context, dbID string) (*DatabaseBackup, error) {
	// Implementation would create database backup
	return &DatabaseBackup{}, nil
}

// Compute operations
func (p *GCPProvider) ListInstances(ctx context.Context) ([]ComputeInstance, error) {
	// Implementation would list compute instances
	return []ComputeInstance{}, nil
}

func (p *GCPProvider) GetInstanceMetrics(ctx context.Context, instanceID string) (*InstanceMetrics, error) {
	// Implementation would get instance metrics
	return &InstanceMetrics{}, nil
}

func (p *GCPProvider) StartInstance(ctx context.Context, instanceID string) error {
	// Implementation would start instance
	return nil
}

func (p *GCPProvider) StopInstance(ctx context.Context, instanceID string) error {
	// Implementation would stop instance
	return nil
}

func (p *GCPProvider) ResizeInstance(ctx context.Context, instanceID string, newSize string) error {
	// Implementation would resize instance
	return nil
}

// Helper functions
func (p *GCPProvider) rateLimiter.wait() {
	p.rateLimiter.mutex.Lock()
	defer p.rateLimiter.mutex.Unlock()

	now := time.Now()
	elapsed := now.Sub(p.rateLimiter.lastRefill)
	tokensToAdd := int(elapsed.Seconds()) * p.rateLimiter.refillRate

	p.rateLimiter.tokens += tokensToAdd
	if p.rateLimiter.tokens > p.rateLimiter.maxTokens {
		p.rateLimiter.tokens = p.rateLimiter.maxTokens
	}

	p.rateLimiter.lastRefill = now

	if p.rateLimiter.tokens <= 0 {
		time.Sleep(time.Second / time.Duration(p.rateLimiter.refillRate))
		p.rateLimiter.tokens = 1
	}

	p.rateLimiter.tokens--
}

func (p *GCPProvider) getFromCache(key string) interface{} {
	if !p.config.CacheEnabled {
		return nil
	}

	p.cache.mutex.RLock()
	defer p.cache.mutex.RUnlock()

	if cached, exists := p.cache.resources[key]; exists {
		if time.Now().Before(cached.ExpiresAt) {
			return cached.Data
		}
		// Remove expired entry
		delete(p.cache.resources, key)
	}

	return nil
}

func (p *GCPProvider) addToCache(key string, data interface{}) {
	if !p.config.CacheEnabled {
		return
	}

	p.cache.mutex.Lock()
	defer p.cache.mutex.Unlock()

	now := time.Now()
	p.cache.resources[key] = &CachedResource{
		Data:      data,
		CachedAt:  now,
		ExpiresAt: now.Add(p.cache.ttl),
	}
}

// Create/Update/Delete stubs
func (p *GCPProvider) createComputeInstance(ctx context.Context, resource *core.Resource) error {
	// Implementation would create compute instance
	return nil
}

func (p *GCPProvider) updateComputeInstance(ctx context.Context, resource *core.Resource) error {
	// Implementation would update compute instance
	return nil
}

func (p *GCPProvider) deleteComputeInstance(ctx context.Context, resourceID string) error {
	// Implementation would delete compute instance
	return nil
}

func (p *GCPProvider) createStorageBucket(ctx context.Context, resource *core.Resource) error {
	// Implementation would create storage bucket
	return nil
}

func (p *GCPProvider) updateStorageBucket(ctx context.Context, resource *core.Resource) error {
	// Implementation would update storage bucket
	return nil
}

func (p *GCPProvider) deleteStorageBucket(ctx context.Context, resourceID string) error {
	// Implementation would delete storage bucket
	return nil
}

func (p *GCPProvider) setInstanceTags(ctx context.Context, resourceID string, tags map[string]string) error {
	// Implementation would set instance tags
	return nil
}

func (p *GCPProvider) setBucketLabels(ctx context.Context, resourceID string, labels map[string]string) error {
	// Implementation would set bucket labels
	return nil
}

// Utility functions
func parseGCPTimestamp(timestamp string) time.Time {
	t, err := time.Parse(time.RFC3339, timestamp)
	if err != nil {
		return time.Now()
	}
	return t
}

func convertLabelsToTags(labels map[string]string) map[string]string {
	if labels == nil {
		return make(map[string]string)
	}
	return labels
}

func extractNetworkFromInterface(ni *compute.NetworkInterface) string {
	if ni == nil || ni.Network == "" {
		return ""
	}
	parts := strings.Split(ni.Network, "/")
	return parts[len(parts)-1]
}