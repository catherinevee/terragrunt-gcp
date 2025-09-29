package cost

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"

	billing "cloud.google.com/go/billing/apiv1"
	"cloud.google.com/go/billing/apiv1/billingpb"
	"github.com/terragrunt-gcp/terragrunt-gcp/internal/core"
	"go.uber.org/zap"
	"google.golang.org/api/cloudbilling/v1"
	"google.golang.org/api/iterator"
	"google.golang.org/api/option"
)

// Calculator provides cost analysis functionality
type Calculator struct {
	billingClient  *billing.CloudCatalogClient
	billingService *cloudbilling.APIService
	logger         *zap.Logger
	cache          *PriceCache
	projectID      string
	mu             sync.RWMutex
}

// PriceCache caches pricing information
type PriceCache struct {
	prices     map[string]*PriceInfo
	lastUpdate time.Time
	ttl        time.Duration
	mu         sync.RWMutex
}

// PriceInfo represents pricing information for a resource
type PriceInfo struct {
	SKU          string
	Description  string
	PricePerUnit float64
	Unit         string
	Currency     string
	LastUpdated  time.Time
}

// NewCalculator creates a new cost calculator
func NewCalculator(projectID string, opts ...option.ClientOption) (*Calculator, error) {
	ctx := context.Background()

	// Create billing catalog client
	billingClient, err := billing.NewCloudCatalogClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create billing catalog client: %w", err)
	}

	// Create billing service
	billingService, err := cloudbilling.NewService(ctx, opts...)
	if err != nil {
		billingClient.Close()
		return nil, fmt.Errorf("failed to create billing service: %w", err)
	}

	logger := zap.L().Named("cost-calculator")

	return &Calculator{
		billingClient:  billingClient,
		billingService: billingService,
		logger:         logger,
		projectID:      projectID,
		cache: &PriceCache{
			prices: make(map[string]*PriceInfo),
			ttl:    24 * time.Hour,
		},
	}, nil
}

// CalculateResourceCost calculates the cost for a single resource
func (c *Calculator) CalculateResourceCost(ctx context.Context, resource core.Resource) (float64, error) {
	c.logger.Debug("Calculating cost for resource",
		zap.String("resource_id", resource.ID),
		zap.String("type", resource.Type))

	// Map resource type to GCP service
	service := c.mapResourceTypeToService(resource.Type)
	if service == "" {
		c.logger.Debug("Unknown resource type for cost calculation",
			zap.String("type", resource.Type))
		return 0.0, nil // Return 0 for unknown types instead of error
	}

	// Get pricing information
	priceInfo, err := c.getPricing(ctx, service, resource.Type)
	if err != nil {
		c.logger.Warn("Failed to get pricing",
			zap.String("service", service),
			zap.Error(err))
		return 0.0, err
	}

	// Calculate cost based on resource configuration
	cost := c.calculateCostFromConfig(resource, priceInfo)

	c.logger.Debug("Calculated resource cost",
		zap.String("resource_id", resource.ID),
		zap.Float64("cost", cost),
		zap.String("currency", priceInfo.Currency))

	return cost, nil
}

// CalculateTotalCost calculates the total cost for a list of resources
func (c *Calculator) CalculateTotalCost(ctx context.Context, resources []core.Resource) (float64, error) {
	var totalCost float64
	for _, resource := range resources {
		cost, err := c.CalculateResourceCost(ctx, resource)
		if err != nil {
			continue // Skip resources we can't calculate cost for
		}
		totalCost += cost
	}
	return totalCost, nil
}

// CostReport represents a cost analysis report
type CostReport struct {
	GeneratedAt   time.Time          `json:"generated_at"`
	TotalCost     float64            `json:"total_cost"`
	ResourceCosts map[string]float64 `json:"resource_costs"`
	ByProvider    map[string]float64 `json:"by_provider"`
	ByRegion      map[string]float64 `json:"by_region"`
	ByType        map[string]float64 `json:"by_type"`
}

// GenerateReport generates a comprehensive cost report
func (c *Calculator) GenerateReport(ctx context.Context, resources []core.Resource) (*CostReport, error) {
	report := &CostReport{
		GeneratedAt:   time.Now(),
		ResourceCosts: make(map[string]float64),
		ByProvider:    make(map[string]float64),
		ByRegion:      make(map[string]float64),
		ByType:        make(map[string]float64),
	}

	var totalCost float64
	for _, resource := range resources {
		cost, err := c.CalculateResourceCost(ctx, resource)
		if err != nil {
			continue
		}

		totalCost += cost
		report.ResourceCosts[resource.ID] = cost
		report.ByProvider[resource.Account.Provider] += cost
		report.ByRegion[resource.Region] += cost
		report.ByType[resource.Type] += cost
	}

	report.TotalCost = totalCost
	return report, nil
}

// mapResourceTypeToService maps Terraform resource types to GCP services
func (c *Calculator) mapResourceTypeToService(resourceType string) string {
	// Map common Terraform resource types to GCP service names
	serviceMap := map[string]string{
		"google_compute_instance":        "services/6F81-5844-456A", // Compute Engine
		"google_compute_disk":            "services/6F81-5844-456A",
		"google_container_cluster":       "services/E564-E2C8-02F0", // GKE
		"google_container_node_pool":     "services/E564-E2C8-02F0",
		"google_sql_database_instance":   "services/9662-B51E-5089", // Cloud SQL
		"google_storage_bucket":          "services/95FF-2EF5-5EA1", // Cloud Storage
		"google_bigquery_dataset":        "services/24E6-581D-38E5", // BigQuery
		"google_bigquery_table":          "services/24E6-581D-38E5",
		"google_pubsub_topic":            "services/8D81-FB63-78C6", // Pub/Sub
		"google_pubsub_subscription":     "services/8D81-FB63-78C6",
		"google_cloud_run_service":       "services/E1C0-CF45-9748", // Cloud Run
		"google_cloudfunctions_function": "services/AEF0-B304-5726", // Cloud Functions
		"google_redis_instance":          "services/655E-AA13-8DDC", // Memorystore
		"google_app_engine_application":  "services/F852-5D37-41C4", // App Engine
	}

	// Check for exact match
	if service, ok := serviceMap[resourceType]; ok {
		return service
	}

	// Check for prefix match
	for prefix, service := range serviceMap {
		if strings.HasPrefix(resourceType, prefix) {
			return service
		}
	}

	return ""
}

// getPricing retrieves pricing information from GCP Billing API with caching
func (c *Calculator) getPricing(ctx context.Context, service string, resourceType string) (*PriceInfo, error) {
	cacheKey := fmt.Sprintf("%s:%s", service, resourceType)

	// Check cache first
	c.cache.mu.RLock()
	if info, ok := c.cache.prices[cacheKey]; ok {
		if time.Since(info.LastUpdated) < c.cache.ttl {
			c.cache.mu.RUnlock()
			c.logger.Debug("Using cached pricing", zap.String("key", cacheKey))
			return info, nil
		}
	}
	c.cache.mu.RUnlock()

	// Fetch from API
	c.logger.Debug("Fetching pricing from API", zap.String("service", service))

	req := &billingpb.ListSkusRequest{
		Parent: service,
	}

	it := c.billingClient.ListSkus(ctx, req)

	// Get first SKU (simplified - in production, you'd filter by region, etc.)
	sku, err := it.Next()
	if err == iterator.Done {
		return nil, fmt.Errorf("no SKUs found for service: %s", service)
	}
	if err != nil {
		return nil, fmt.Errorf("listing SKUs: %w", err)
	}

	// Extract pricing information
	priceInfo := &PriceInfo{
		SKU:         sku.Name,
		Description: sku.Description,
		Currency:    "USD",
		LastUpdated: time.Now(),
	}

	// Get price from pricing info
	if len(sku.PricingInfo) > 0 {
		pricingInfo := sku.PricingInfo[0]
		if pricingInfo.PricingExpression != nil {
			if len(pricingInfo.PricingExpression.TieredRates) > 0 {
				rate := pricingInfo.PricingExpression.TieredRates[0]
				if rate.UnitPrice != nil {
					// Convert to float (units + nanos)
					priceInfo.PricePerUnit = float64(rate.UnitPrice.Units) + float64(rate.UnitPrice.Nanos)/1e9
				}
			}
			priceInfo.Unit = pricingInfo.PricingExpression.UsageUnit
		}
	}

	// Cache the result
	c.cache.mu.Lock()
	c.cache.prices[cacheKey] = priceInfo
	c.cache.lastUpdate = time.Now()
	c.cache.mu.Unlock()

	return priceInfo, nil
}

// calculateCostFromConfig calculates cost based on resource configuration
func (c *Calculator) calculateCostFromConfig(resource core.Resource, priceInfo *PriceInfo) float64 {
	// Base cost estimation
	baseCost := priceInfo.PricePerUnit

	// Multiply by usage estimates based on resource type
	switch {
	case strings.Contains(resource.Type, "compute_instance"):
		// Estimate 730 hours per month (24/7 operation)
		return baseCost * 730

	case strings.Contains(resource.Type, "storage_bucket"):
		// Estimate 100GB storage per month
		return baseCost * 100

	case strings.Contains(resource.Type, "sql_database"):
		// Estimate 730 hours per month for instance
		return baseCost * 730

	case strings.Contains(resource.Type, "container_cluster"),
		strings.Contains(resource.Type, "container_node_pool"):
		// Estimate based on node count (default 3 nodes)
		return baseCost * 730 * 3

	case strings.Contains(resource.Type, "bigquery"):
		// Estimate 1TB query processing per month
		return baseCost * 1000

	case strings.Contains(resource.Type, "cloud_run"):
		// Estimate 1M requests per month
		return baseCost * 1000000

	case strings.Contains(resource.Type, "cloudfunctions"):
		// Estimate 1M invocations per month
		return baseCost * 1000000

	case strings.Contains(resource.Type, "pubsub"):
		// Estimate 100GB data per month
		return baseCost * 100

	default:
		// Default monthly estimate
		return baseCost * 730
	}
}

// GetCurrentBillingInfo retrieves current billing information for the project
func (c *Calculator) GetCurrentBillingInfo(ctx context.Context) (*cloudbilling.ProjectBillingInfo, error) {
	projectName := fmt.Sprintf("projects/%s", c.projectID)

	billingInfo, err := c.billingService.Projects.GetBillingInfo(projectName).Context(ctx).Do()
	if err != nil {
		return nil, fmt.Errorf("getting billing info: %w", err)
	}

	return billingInfo, nil
}

// Close closes the calculator and releases resources
func (c *Calculator) Close() error {
	if c.billingClient != nil {
		return c.billingClient.Close()
	}
	return nil
}
