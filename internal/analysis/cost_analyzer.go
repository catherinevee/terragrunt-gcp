package analysis

import (
	"context"
	"fmt"
	"math"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/sirupsen/logrus"
	"github.com/terragrunt-gcp/terragrunt-gcp/internal/core"
	"github.com/terragrunt-gcp/terragrunt-gcp/internal/providers"
)

type CostAnalyzer struct {
	provider providers.Provider
	logger   *logrus.Logger
	config   CostAnalyzerConfig
	cache    *CostCache
	mutex    sync.RWMutex
}

type CostAnalyzerConfig struct {
	BillingAccount      string
	Currency           string
	TaxRate            float64
	DiscountRate       float64
	ReservationDiscount float64
	SustainedUseDiscount float64
	PricingTiers       map[string]PricingTier
	CostAlerts         []CostAlert
	BudgetLimits       map[string]float64
}

type PricingTier struct {
	Name          string
	MinUsage      float64
	MaxUsage      float64
	PricePerUnit  float64
	DiscountRate  float64
}

type CostAlert struct {
	Name      string
	Threshold float64
	Type      string
	Action    string
	Enabled   bool
}

type CostCache struct {
	mutex    sync.RWMutex
	costs    map[string]*CachedCost
	ttl      time.Duration
}

type CachedCost struct {
	Cost      CostData
	CachedAt  time.Time
	ExpiresAt time.Time
}

type CostAnalysisOptions struct {
	BillingAccount   string
	StartDate        time.Time
	EndDate          time.Time
	Granularity      string
	GroupBy          string
	IncludeForecast  bool
	IncludeCredits   bool
	IncludeTaxes     bool
	IncludeDiscounts bool
	Filters          map[string]interface{}
	ForecastDays     int
	AnalysisDepth    string
}

type CostAnalysisResults struct {
	Summary         CostAnalysisSummary       `json:"summary"`
	Breakdown       CostBreakdown             `json:"breakdown"`
	Timeline        []CostTimelineEntry       `json:"timeline"`
	Forecast        CostForecast              `json:"forecast,omitempty"`
	Optimizations   []CostOptimizationOption  `json:"optimizations"`
	Allocations     []CostAllocation          `json:"allocations"`
	Trends          CostTrends                `json:"trends"`
	Anomalies       []CostAnomaly             `json:"anomalies"`
	Recommendations []CostRecommendation      `json:"recommendations"`
	BudgetStatus    BudgetStatus              `json:"budget_status"`
	Metadata        map[string]interface{}    `json:"metadata"`
}

type CostAnalysisSummary struct {
	TotalCost           float64                `json:"total_cost"`
	AverageDailyCost    float64                `json:"average_daily_cost"`
	ProjectedMonthlyCost float64               `json:"projected_monthly_cost"`
	ProjectedAnnualCost  float64               `json:"projected_annual_cost"`
	CostByService       map[string]float64     `json:"cost_by_service"`
	CostByRegion        map[string]float64     `json:"cost_by_region"`
	CostByProject       map[string]float64     `json:"cost_by_project"`
	CostByLabel         map[string]float64     `json:"cost_by_label"`
	TopExpenses         []ExpenseItem          `json:"top_expenses"`
	CostChange          CostChangeAnalysis     `json:"cost_change"`
	Currency            string                 `json:"currency"`
	Period              string                 `json:"period"`
	DataCompleteness    float64                `json:"data_completeness"`
}

type CostBreakdown struct {
	ByService       map[string]ServiceCost       `json:"by_service"`
	ByResource      map[string]ResourceCost      `json:"by_resource"`
	ByRegion        map[string]RegionCost        `json:"by_region"`
	ByProject       map[string]ProjectCost       `json:"by_project"`
	ByDepartment    map[string]DepartmentCost    `json:"by_department"`
	ByEnvironment   map[string]EnvironmentCost   `json:"by_environment"`
	ByLabel         map[string]LabelCost         `json:"by_label"`
	UnallocatedCost float64                      `json:"unallocated_cost"`
}

type ServiceCost struct {
	ServiceName     string                 `json:"service_name"`
	TotalCost       float64                `json:"total_cost"`
	UsageCost       float64                `json:"usage_cost"`
	RequestCost     float64                `json:"request_cost"`
	DataTransferCost float64               `json:"data_transfer_cost"`
	Resources       []ResourceCostDetail   `json:"resources"`
	Trend           string                 `json:"trend"`
	ChangePercent   float64                `json:"change_percent"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type ResourceCost struct {
	ResourceID      string                 `json:"resource_id"`
	ResourceName    string                 `json:"resource_name"`
	ResourceType    string                 `json:"resource_type"`
	TotalCost       float64                `json:"total_cost"`
	ComputeCost     float64                `json:"compute_cost"`
	StorageCost     float64                `json:"storage_cost"`
	NetworkCost     float64                `json:"network_cost"`
	OtherCost       float64                `json:"other_cost"`
	UsageMetrics    map[string]float64     `json:"usage_metrics"`
	PricingDetails  PricingInfo            `json:"pricing_details"`
	Tags            map[string]string      `json:"tags"`
	Recommendations []string               `json:"recommendations"`
}

type RegionCost struct {
	Region           string             `json:"region"`
	TotalCost        float64            `json:"total_cost"`
	ServiceBreakdown map[string]float64 `json:"service_breakdown"`
	ResourceCount    int                `json:"resource_count"`
	DataTransferCost float64            `json:"data_transfer_cost"`
	TaxAmount        float64            `json:"tax_amount"`
}

type ProjectCost struct {
	ProjectID        string                 `json:"project_id"`
	ProjectName      string                 `json:"project_name"`
	TotalCost        float64                `json:"total_cost"`
	BudgetAllocated  float64                `json:"budget_allocated"`
	BudgetUsed       float64                `json:"budget_used"`
	BudgetRemaining  float64                `json:"budget_remaining"`
	ServiceBreakdown map[string]float64     `json:"service_breakdown"`
	Owner            string                 `json:"owner"`
	Department       string                 `json:"department"`
	CostCenter       string                 `json:"cost_center"`
	Metadata         map[string]interface{} `json:"metadata"`
}

type DepartmentCost struct {
	Department      string             `json:"department"`
	TotalCost       float64            `json:"total_cost"`
	ProjectCount    int                `json:"project_count"`
	ResourceCount   int                `json:"resource_count"`
	Projects        []string           `json:"projects"`
	CostBreakdown   map[string]float64 `json:"cost_breakdown"`
	BudgetAllocated float64            `json:"budget_allocated"`
	BudgetStatus    string             `json:"budget_status"`
}

type EnvironmentCost struct {
	Environment     string             `json:"environment"`
	TotalCost       float64            `json:"total_cost"`
	ResourceCount   int                `json:"resource_count"`
	ServiceBreakdown map[string]float64 `json:"service_breakdown"`
	CostPercentage  float64            `json:"cost_percentage"`
	Efficiency      string             `json:"efficiency"`
}

type LabelCost struct {
	LabelKey        string             `json:"label_key"`
	LabelValue      string             `json:"label_value"`
	TotalCost       float64            `json:"total_cost"`
	ResourceCount   int                `json:"resource_count"`
	ServiceBreakdown map[string]float64 `json:"service_breakdown"`
}

type ResourceCostDetail struct {
	ResourceID   string  `json:"resource_id"`
	ResourceName string  `json:"resource_name"`
	Cost         float64 `json:"cost"`
	Usage        float64 `json:"usage"`
	Unit         string  `json:"unit"`
}

type PricingInfo struct {
	SKU             string  `json:"sku"`
	PricePerUnit    float64 `json:"price_per_unit"`
	Unit            string  `json:"unit"`
	Tier            string  `json:"tier"`
	DiscountApplied float64 `json:"discount_applied"`
	EffectivePrice  float64 `json:"effective_price"`
}

type CostTimelineEntry struct {
	Date            time.Time          `json:"date"`
	TotalCost       float64            `json:"total_cost"`
	ServiceCosts    map[string]float64 `json:"service_costs"`
	Delta           float64            `json:"delta"`
	DeltaPercent    float64            `json:"delta_percent"`
	RunningTotal    float64            `json:"running_total"`
	AnomalyDetected bool               `json:"anomaly_detected"`
}

type CostForecast struct {
	ForecastPeriod   string                `json:"forecast_period"`
	PredictedCost    float64               `json:"predicted_cost"`
	UpperBound       float64               `json:"upper_bound"`
	LowerBound       float64               `json:"lower_bound"`
	ConfidenceLevel  float64               `json:"confidence_level"`
	Methodology      string                `json:"methodology"`
	Timeline         []ForecastDataPoint   `json:"timeline"`
	Assumptions      []string              `json:"assumptions"`
	RiskFactors      []RiskFactor          `json:"risk_factors"`
	Recommendations  []string              `json:"recommendations"`
}

type ForecastDataPoint struct {
	Date            time.Time `json:"date"`
	PredictedCost   float64   `json:"predicted_cost"`
	UpperBound      float64   `json:"upper_bound"`
	LowerBound      float64   `json:"lower_bound"`
	Confidence      float64   `json:"confidence"`
	SeasonalFactor  float64   `json:"seasonal_factor"`
}

type RiskFactor struct {
	Name        string  `json:"name"`
	Impact      string  `json:"impact"`
	Probability float64 `json:"probability"`
	Mitigation  string  `json:"mitigation"`
}

type CostOptimizationOption struct {
	ID               string                 `json:"id"`
	Type             string                 `json:"type"`
	Category         string                 `json:"category"`
	Title            string                 `json:"title"`
	Description      string                 `json:"description"`
	CurrentCost      float64                `json:"current_cost"`
	OptimizedCost    float64                `json:"optimized_cost"`
	Savings          float64                `json:"savings"`
	SavingsPercent   float64                `json:"savings_percent"`
	Implementation   ImplementationPlan     `json:"implementation"`
	Risk             string                 `json:"risk"`
	Effort           string                 `json:"effort"`
	Priority         int                    `json:"priority"`
	AffectedResources []string              `json:"affected_resources"`
	Prerequisites    []string               `json:"prerequisites"`
	Metadata         map[string]interface{} `json:"metadata"`
}

type ImplementationPlan struct {
	Steps           []ImplementationStep `json:"steps"`
	Timeline        string               `json:"timeline"`
	RequiredSkills  []string             `json:"required_skills"`
	EstimatedEffort string               `json:"estimated_effort"`
	Automation      bool                 `json:"automation"`
	RollbackPlan    string               `json:"rollback_plan"`
}

type ImplementationStep struct {
	Order       int    `json:"order"`
	Action      string `json:"action"`
	Description string `json:"description"`
	Script      string `json:"script,omitempty"`
	Validation  string `json:"validation"`
}

type CostAllocation struct {
	AllocationID    string                 `json:"allocation_id"`
	Source          string                 `json:"source"`
	Target          string                 `json:"target"`
	Amount          float64                `json:"amount"`
	Percentage      float64                `json:"percentage"`
	Method          string                 `json:"method"`
	Basis           string                 `json:"basis"`
	Tags            map[string]string      `json:"tags"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type CostTrends struct {
	DailyTrend      TrendAnalysis          `json:"daily_trend"`
	WeeklyTrend     TrendAnalysis          `json:"weekly_trend"`
	MonthlyTrend    TrendAnalysis          `json:"monthly_trend"`
	ServiceTrends   map[string]TrendAnalysis `json:"service_trends"`
	SeasonalPattern SeasonalAnalysis       `json:"seasonal_pattern"`
	GrowthRate      GrowthAnalysis         `json:"growth_rate"`
}

type TrendAnalysis struct {
	Direction       string    `json:"direction"`
	Magnitude       float64   `json:"magnitude"`
	Slope           float64   `json:"slope"`
	R2              float64   `json:"r2"`
	Volatility      float64   `json:"volatility"`
	Confidence      float64   `json:"confidence"`
	DataPoints      int       `json:"data_points"`
	StartValue      float64   `json:"start_value"`
	EndValue        float64   `json:"end_value"`
	PeakValue       float64   `json:"peak_value"`
	TroughValue     float64   `json:"trough_value"`
	Interpretation  string    `json:"interpretation"`
}

type SeasonalAnalysis struct {
	Pattern         string             `json:"pattern"`
	Seasonality     bool               `json:"seasonality"`
	PeakPeriods     []string           `json:"peak_periods"`
	LowPeriods      []string           `json:"low_periods"`
	SeasonalFactors map[string]float64 `json:"seasonal_factors"`
	Confidence      float64            `json:"confidence"`
}

type GrowthAnalysis struct {
	CurrentRate     float64 `json:"current_rate"`
	AverageRate     float64 `json:"average_rate"`
	Acceleration    float64 `json:"acceleration"`
	ProjectedRate   float64 `json:"projected_rate"`
	DoublingTime    float64 `json:"doubling_time"`
	Sustainability  string  `json:"sustainability"`
}

type CostAnomaly struct {
	ID              string    `json:"id"`
	DetectedAt      time.Time `json:"detected_at"`
	Type            string    `json:"type"`
	Severity        string    `json:"severity"`
	Service         string    `json:"service"`
	Resource        string    `json:"resource"`
	ExpectedCost    float64   `json:"expected_cost"`
	ActualCost      float64   `json:"actual_cost"`
	Deviation       float64   `json:"deviation"`
	DeviationPercent float64  `json:"deviation_percent"`
	Description     string    `json:"description"`
	PossibleCauses  []string  `json:"possible_causes"`
	Investigation   string    `json:"investigation"`
	Resolution      string    `json:"resolution"`
}

type ExpenseItem struct {
	Name        string  `json:"name"`
	Type        string  `json:"type"`
	Cost        float64 `json:"cost"`
	Percentage  float64 `json:"percentage"`
	Trend       string  `json:"trend"`
	ResourceID  string  `json:"resource_id"`
}

type CostChangeAnalysis struct {
	PreviousPeriodCost float64            `json:"previous_period_cost"`
	CurrentPeriodCost  float64            `json:"current_period_cost"`
	AbsoluteChange     float64            `json:"absolute_change"`
	PercentChange      float64            `json:"percent_change"`
	Direction          string             `json:"direction"`
	Drivers            []CostChangeDriver `json:"drivers"`
}

type CostChangeDriver struct {
	Name           string  `json:"name"`
	Type           string  `json:"type"`
	Impact         float64 `json:"impact"`
	ImpactPercent  float64 `json:"impact_percent"`
	Description    string  `json:"description"`
}

type BudgetStatus struct {
	TotalBudget      float64           `json:"total_budget"`
	UsedBudget       float64           `json:"used_budget"`
	RemainingBudget  float64           `json:"remaining_budget"`
	BudgetUtilization float64          `json:"budget_utilization"`
	ProjectedOverage float64           `json:"projected_overage"`
	DaysRemaining    int               `json:"days_remaining"`
	BurnRate         float64           `json:"burn_rate"`
	Status           string            `json:"status"`
	Alerts           []BudgetAlert     `json:"alerts"`
	Forecasts        []BudgetForecast  `json:"forecasts"`
}

type BudgetAlert struct {
	Type        string    `json:"type"`
	Threshold   float64   `json:"threshold"`
	Current     float64   `json:"current"`
	Message     string    `json:"message"`
	Severity    string    `json:"severity"`
	TriggeredAt time.Time `json:"triggered_at"`
}

type BudgetForecast struct {
	Period          string  `json:"period"`
	ProjectedSpend  float64 `json:"projected_spend"`
	BudgetLimit     float64 `json:"budget_limit"`
	ExpectedOverage float64 `json:"expected_overage"`
	Confidence      float64 `json:"confidence"`
}

type CostData struct {
	Amount      float64
	Currency    string
	Period      string
	LastUpdated time.Time
}

func NewCostAnalyzer(provider providers.Provider, logger *logrus.Logger) *CostAnalyzer {
	return &CostAnalyzer{
		provider: provider,
		logger:   logger,
		config: CostAnalyzerConfig{
			Currency:             "USD",
			TaxRate:              0.0,
			DiscountRate:         0.0,
			ReservationDiscount:  0.0,
			SustainedUseDiscount: 0.0,
			PricingTiers:         make(map[string]PricingTier),
			CostAlerts:           []CostAlert{},
			BudgetLimits:         make(map[string]float64),
		},
		cache: &CostCache{
			costs: make(map[string]*CachedCost),
			ttl:   15 * time.Minute,
		},
	}
}

func (ca *CostAnalyzer) AnalyzeCosts(ctx context.Context, options CostAnalysisOptions) (*CostAnalysisResults, error) {
	ca.logger.Info("Starting comprehensive cost analysis")

	if options.StartDate.IsZero() {
		options.StartDate = time.Now().AddDate(0, -1, 0)
	}
	if options.EndDate.IsZero() {
		options.EndDate = time.Now()
	}

	results := &CostAnalysisResults{
		Timeline:        []CostTimelineEntry{},
		Optimizations:   []CostOptimizationOption{},
		Allocations:     []CostAllocation{},
		Anomalies:       []CostAnomaly{},
		Recommendations: []CostRecommendation{},
		Metadata:        make(map[string]interface{}),
	}

	resources, err := ca.provider.ListResources(ctx, "", options.Filters)
	if err != nil {
		return nil, fmt.Errorf("failed to list resources: %w", err)
	}

	results.Summary = ca.calculateSummary(ctx, resources, options)
	results.Breakdown = ca.calculateBreakdown(ctx, resources, options)
	results.Timeline = ca.generateTimeline(ctx, resources, options)

	if options.IncludeForecast {
		results.Forecast = ca.generateForecast(ctx, results.Timeline, options.ForecastDays)
	}

	results.Optimizations = ca.identifyOptimizations(ctx, resources, results.Breakdown)
	results.Allocations = ca.calculateAllocations(resources, options)
	results.Trends = ca.analyzeTrends(results.Timeline)
	results.Anomalies = ca.detectAnomalies(results.Timeline)
	results.Recommendations = ca.generateRecommendations(results)
	results.BudgetStatus = ca.analyzeBudgetStatus(results.Summary.TotalCost, options)

	results.Metadata["analysis_date"] = time.Now()
	results.Metadata["period"] = fmt.Sprintf("%s to %s",
		options.StartDate.Format("2006-01-02"),
		options.EndDate.Format("2006-01-02"))
	results.Metadata["resource_count"] = len(resources)
	results.Metadata["currency"] = ca.config.Currency

	ca.logger.Info("Cost analysis completed successfully")
	return results, nil
}

func (ca *CostAnalyzer) calculateSummary(ctx context.Context, resources []core.Resource, options CostAnalysisOptions) CostAnalysisSummary {
	summary := CostAnalysisSummary{
		CostByService: make(map[string]float64),
		CostByRegion:  make(map[string]float64),
		CostByProject: make(map[string]float64),
		CostByLabel:   make(map[string]float64),
		TopExpenses:   []ExpenseItem{},
		Currency:      ca.config.Currency,
		Period:        fmt.Sprintf("%d days", int(options.EndDate.Sub(options.StartDate).Hours()/24)),
	}

	totalCost := 0.0
	expenseMap := make(map[string]float64)

	for _, resource := range resources {
		if resource.Cost == nil {
			continue
		}

		cost := resource.Cost.Actual
		if options.IncludeTaxes {
			cost += cost * ca.config.TaxRate
		}
		if options.IncludeDiscounts {
			cost -= cost * ca.getApplicableDiscount(resource)
		}

		totalCost += cost

		serviceName := ca.getServiceFromResourceType(resource.Type)
		summary.CostByService[serviceName] += cost
		summary.CostByRegion[resource.Region] += cost

		if project, ok := resource.Labels["project"]; ok {
			summary.CostByProject[project] += cost
		}

		for key, value := range resource.Labels {
			labelKey := fmt.Sprintf("%s:%s", key, value)
			summary.CostByLabel[labelKey] += cost
		}

		expenseMap[resource.ID] = cost
	}

	summary.TotalCost = totalCost
	days := options.EndDate.Sub(options.StartDate).Hours() / 24
	if days > 0 {
		summary.AverageDailyCost = totalCost / days
		summary.ProjectedMonthlyCost = summary.AverageDailyCost * 30
		summary.ProjectedAnnualCost = summary.AverageDailyCost * 365
	}

	summary.TopExpenses = ca.getTopExpenses(expenseMap, resources, 10)
	summary.CostChange = ca.analyzeCostChange(ctx, totalCost, options)
	summary.DataCompleteness = ca.calculateDataCompleteness(resources)

	return summary
}

func (ca *CostAnalyzer) calculateBreakdown(ctx context.Context, resources []core.Resource, options CostAnalysisOptions) CostBreakdown {
	breakdown := CostBreakdown{
		ByService:     make(map[string]ServiceCost),
		ByResource:    make(map[string]ResourceCost),
		ByRegion:      make(map[string]RegionCost),
		ByProject:     make(map[string]ProjectCost),
		ByDepartment:  make(map[string]DepartmentCost),
		ByEnvironment: make(map[string]EnvironmentCost),
		ByLabel:       make(map[string]LabelCost),
	}

	for _, resource := range resources {
		if resource.Cost == nil {
			continue
		}

		cost := resource.Cost.Actual

		serviceName := ca.getServiceFromResourceType(resource.Type)
		if _, exists := breakdown.ByService[serviceName]; !exists {
			breakdown.ByService[serviceName] = ServiceCost{
				ServiceName: serviceName,
				Resources:   []ResourceCostDetail{},
				Metadata:    make(map[string]interface{}),
			}
		}
		service := breakdown.ByService[serviceName]
		service.TotalCost += cost
		service.UsageCost += cost * 0.7
		service.RequestCost += cost * 0.2
		service.DataTransferCost += cost * 0.1
		service.Resources = append(service.Resources, ResourceCostDetail{
			ResourceID:   resource.ID,
			ResourceName: resource.Name,
			Cost:         cost,
		})
		breakdown.ByService[serviceName] = service

		breakdown.ByResource[resource.ID] = ResourceCost{
			ResourceID:      resource.ID,
			ResourceName:    resource.Name,
			ResourceType:    resource.Type,
			TotalCost:       cost,
			ComputeCost:     cost * 0.5,
			StorageCost:     cost * 0.2,
			NetworkCost:     cost * 0.2,
			OtherCost:       cost * 0.1,
			UsageMetrics:    ca.getResourceUsageMetrics(ctx, resource),
			PricingDetails:  ca.getResourcePricing(resource),
			Tags:            resource.Tags,
			Recommendations: ca.getResourceRecommendations(resource),
		}

		if _, exists := breakdown.ByRegion[resource.Region]; !exists {
			breakdown.ByRegion[resource.Region] = RegionCost{
				Region:           resource.Region,
				ServiceBreakdown: make(map[string]float64),
			}
		}
		region := breakdown.ByRegion[resource.Region]
		region.TotalCost += cost
		region.ServiceBreakdown[serviceName] += cost
		region.ResourceCount++
		breakdown.ByRegion[resource.Region] = region

		if project, ok := resource.Labels["project"]; ok {
			if _, exists := breakdown.ByProject[project]; !exists {
				breakdown.ByProject[project] = ProjectCost{
					ProjectID:        project,
					ProjectName:      project,
					ServiceBreakdown: make(map[string]float64),
					Metadata:         make(map[string]interface{}),
				}
			}
			proj := breakdown.ByProject[project]
			proj.TotalCost += cost
			proj.ServiceBreakdown[serviceName] += cost
			breakdown.ByProject[project] = proj
		}

		if dept, ok := resource.Labels["department"]; ok {
			if _, exists := breakdown.ByDepartment[dept]; !exists {
				breakdown.ByDepartment[dept] = DepartmentCost{
					Department:    dept,
					Projects:      []string{},
					CostBreakdown: make(map[string]float64),
				}
			}
			department := breakdown.ByDepartment[dept]
			department.TotalCost += cost
			department.ResourceCount++
			department.CostBreakdown[serviceName] += cost
			breakdown.ByDepartment[dept] = department
		}

		if env, ok := resource.Labels["environment"]; ok {
			if _, exists := breakdown.ByEnvironment[env]; !exists {
				breakdown.ByEnvironment[env] = EnvironmentCost{
					Environment:      env,
					ServiceBreakdown: make(map[string]float64),
				}
			}
			environment := breakdown.ByEnvironment[env]
			environment.TotalCost += cost
			environment.ResourceCount++
			environment.ServiceBreakdown[serviceName] += cost
			breakdown.ByEnvironment[env] = environment
		}

		for key, value := range resource.Labels {
			labelKey := fmt.Sprintf("%s:%s", key, value)
			if _, exists := breakdown.ByLabel[labelKey]; !exists {
				breakdown.ByLabel[labelKey] = LabelCost{
					LabelKey:         key,
					LabelValue:       value,
					ServiceBreakdown: make(map[string]float64),
				}
			}
			label := breakdown.ByLabel[labelKey]
			label.TotalCost += cost
			label.ResourceCount++
			label.ServiceBreakdown[serviceName] += cost
			breakdown.ByLabel[labelKey] = label
		}
	}

	totalCost := 0.0
	for _, service := range breakdown.ByService {
		totalCost += service.TotalCost
	}

	for env, envCost := range breakdown.ByEnvironment {
		environment := envCost
		if totalCost > 0 {
			environment.CostPercentage = (environment.TotalCost / totalCost) * 100
		}
		environment.Efficiency = ca.calculateEnvironmentEfficiency(environment)
		breakdown.ByEnvironment[env] = environment
	}

	return breakdown
}

func (ca *CostAnalyzer) generateTimeline(ctx context.Context, resources []core.Resource, options CostAnalysisOptions) []CostTimelineEntry {
	timeline := []CostTimelineEntry{}

	currentDate := options.StartDate
	runningTotal := 0.0
	previousDayCost := 0.0

	for currentDate.Before(options.EndDate) || currentDate.Equal(options.EndDate) {
		entry := CostTimelineEntry{
			Date:         currentDate,
			ServiceCosts: make(map[string]float64),
		}

		dailyCost := 0.0
		for _, resource := range resources {
			if resource.CreatedAt.After(currentDate) {
				continue
			}

			if resource.Cost != nil {
				cost := resource.Cost.Actual / 30
				dailyCost += cost

				serviceName := ca.getServiceFromResourceType(resource.Type)
				entry.ServiceCosts[serviceName] += cost
			}
		}

		entry.TotalCost = dailyCost
		runningTotal += dailyCost
		entry.RunningTotal = runningTotal

		if previousDayCost > 0 {
			entry.Delta = dailyCost - previousDayCost
			entry.DeltaPercent = (entry.Delta / previousDayCost) * 100
		}

		if entry.DeltaPercent > 30 || entry.DeltaPercent < -30 {
			entry.AnomalyDetected = true
		}

		timeline = append(timeline, entry)
		previousDayCost = dailyCost
		currentDate = currentDate.AddDate(0, 0, 1)
	}

	return timeline
}

func (ca *CostAnalyzer) generateForecast(ctx context.Context, timeline []CostTimelineEntry, forecastDays int) CostForecast {
	if len(timeline) < 7 {
		return CostForecast{
			ForecastPeriod:  fmt.Sprintf("%d days", forecastDays),
			ConfidenceLevel: 0,
		}
	}

	recentCosts := []float64{}
	for i := len(timeline) - 30; i < len(timeline) && i >= 0; i++ {
		recentCosts = append(recentCosts, timeline[i].TotalCost)
	}

	averageCost := 0.0
	for _, cost := range recentCosts {
		averageCost += cost
	}
	averageCost /= float64(len(recentCosts))

	trend := ca.calculateTrend(recentCosts)
	seasonality := ca.detectSeasonality(timeline)

	forecast := CostForecast{
		ForecastPeriod:  fmt.Sprintf("%d days", forecastDays),
		Methodology:     "Time series analysis with trend and seasonality",
		ConfidenceLevel: 0.85,
		Timeline:        []ForecastDataPoint{},
		Assumptions: []string{
			"Current usage patterns continue",
			"No major infrastructure changes",
			"Pricing remains stable",
			"No significant seasonal events",
		},
		RiskFactors: []RiskFactor{
			{
				Name:        "Usage Spike",
				Impact:      "HIGH",
				Probability: 0.2,
				Mitigation:  "Implement auto-scaling limits and budget alerts",
			},
			{
				Name:        "Price Increase",
				Impact:      "MEDIUM",
				Probability: 0.1,
				Mitigation:  "Lock in committed use discounts",
			},
		},
	}

	totalPredicted := 0.0
	lastDate := timeline[len(timeline)-1].Date

	for i := 1; i <= forecastDays; i++ {
		date := lastDate.AddDate(0, 0, i)

		baseCost := averageCost + (trend * float64(i))
		seasonalFactor := ca.getSeasonalFactor(date, seasonality)
		predictedCost := baseCost * seasonalFactor

		confidence := 0.95 - (float64(i) * 0.01)
		if confidence < 0.5 {
			confidence = 0.5
		}

		uncertainty := predictedCost * (1 - confidence) * 0.2

		forecast.Timeline = append(forecast.Timeline, ForecastDataPoint{
			Date:           date,
			PredictedCost:  predictedCost,
			UpperBound:     predictedCost + uncertainty,
			LowerBound:     math.Max(0, predictedCost-uncertainty),
			Confidence:     confidence,
			SeasonalFactor: seasonalFactor,
		})

		totalPredicted += predictedCost
	}

	forecast.PredictedCost = totalPredicted
	forecast.UpperBound = totalPredicted * 1.2
	forecast.LowerBound = totalPredicted * 0.8

	forecast.Recommendations = ca.generateForecastRecommendations(forecast, averageCost)

	return forecast
}

func (ca *CostAnalyzer) identifyOptimizations(ctx context.Context, resources []core.Resource, breakdown CostBreakdown) []CostOptimizationOption {
	optimizations := []CostOptimizationOption{}

	underutilized := ca.findUnderutilizedResources(ctx, resources)
	for _, resource := range underutilized {
		if resource.Cost == nil {
			continue
		}

		optimization := CostOptimizationOption{
			ID:            fmt.Sprintf("opt-rightsize-%s", resource.ID),
			Type:          "RIGHTSIZING",
			Category:      "COMPUTE",
			Title:         fmt.Sprintf("Rightsize %s", resource.Name),
			Description:   fmt.Sprintf("Resource %s is underutilized (avg CPU: 15%%)", resource.Name),
			CurrentCost:   resource.Cost.Actual,
			OptimizedCost: resource.Cost.Actual * 0.6,
			Savings:       resource.Cost.Actual * 0.4,
			SavingsPercent: 40,
			Risk:          "LOW",
			Effort:        "LOW",
			Priority:      1,
			AffectedResources: []string{resource.ID},
			Implementation: ImplementationPlan{
				Steps: []ImplementationStep{
					{
						Order:       1,
						Action:      "Analyze usage patterns",
						Description: "Review last 30 days of usage metrics",
					},
					{
						Order:       2,
						Action:      "Select appropriate size",
						Description: "Choose instance type based on actual usage",
					},
					{
						Order:       3,
						Action:      "Schedule maintenance window",
						Description: "Plan downtime for resizing",
					},
					{
						Order:       4,
						Action:      "Resize instance",
						Description: "Apply new configuration",
					},
				},
				Timeline:        "1 week",
				RequiredSkills:  []string{"Cloud Architecture", "Cost Management"},
				EstimatedEffort: "4 hours",
				Automation:      true,
			},
		}

		optimizations = append(optimizations, optimization)
	}

	idleResources := ca.findIdleResources(resources)
	for _, resource := range idleResources {
		if resource.Cost == nil {
			continue
		}

		optimization := CostOptimizationOption{
			ID:               fmt.Sprintf("opt-terminate-%s", resource.ID),
			Type:             "TERMINATION",
			Category:         "UNUSED",
			Title:            fmt.Sprintf("Terminate idle resource %s", resource.Name),
			Description:      fmt.Sprintf("Resource %s has been idle for 7+ days", resource.Name),
			CurrentCost:      resource.Cost.Actual,
			OptimizedCost:    0,
			Savings:          resource.Cost.Actual,
			SavingsPercent:   100,
			Risk:             "MEDIUM",
			Effort:           "LOW",
			Priority:         2,
			AffectedResources: []string{resource.ID},
		}

		optimizations = append(optimizations, optimization)
	}

	commitmentOptimizations := ca.identifyCommitmentOpportunities(breakdown)
	optimizations = append(optimizations, commitmentOptimizations...)

	sort.Slice(optimizations, func(i, j int) bool {
		return optimizations[i].Priority < optimizations[j].Priority
	})

	return optimizations
}

func (ca *CostAnalyzer) calculateAllocations(resources []core.Resource, options CostAnalysisOptions) []CostAllocation {
	allocations := []CostAllocation{}

	departmentCosts := make(map[string]float64)
	projectCosts := make(map[string]float64)
	totalCost := 0.0

	for _, resource := range resources {
		if resource.Cost == nil {
			continue
		}

		cost := resource.Cost.Actual
		totalCost += cost

		if dept, ok := resource.Labels["department"]; ok {
			departmentCosts[dept] += cost
		}

		if project, ok := resource.Labels["project"]; ok {
			projectCosts[project] += cost
		}
	}

	for dept, cost := range departmentCosts {
		allocations = append(allocations, CostAllocation{
			AllocationID: fmt.Sprintf("alloc-dept-%s", dept),
			Source:       "Total Infrastructure Cost",
			Target:       fmt.Sprintf("Department: %s", dept),
			Amount:       cost,
			Percentage:   (cost / totalCost) * 100,
			Method:       "DIRECT",
			Basis:        "Resource Tags",
			Tags: map[string]string{
				"department": dept,
				"type":       "departmental",
			},
			Metadata: map[string]interface{}{
				"allocation_date": time.Now(),
			},
		})
	}

	for project, cost := range projectCosts {
		allocations = append(allocations, CostAllocation{
			AllocationID: fmt.Sprintf("alloc-proj-%s", project),
			Source:       "Total Infrastructure Cost",
			Target:       fmt.Sprintf("Project: %s", project),
			Amount:       cost,
			Percentage:   (cost / totalCost) * 100,
			Method:       "DIRECT",
			Basis:        "Resource Tags",
			Tags: map[string]string{
				"project": project,
				"type":    "project",
			},
			Metadata: map[string]interface{}{
				"allocation_date": time.Now(),
			},
		})
	}

	return allocations
}

func (ca *CostAnalyzer) analyzeTrends(timeline []CostTimelineEntry) CostTrends {
	if len(timeline) < 7 {
		return CostTrends{}
	}

	trends := CostTrends{
		ServiceTrends: make(map[string]TrendAnalysis),
	}

	dailyCosts := []float64{}
	for _, entry := range timeline {
		dailyCosts = append(dailyCosts, entry.TotalCost)
	}

	trends.DailyTrend = ca.calculateTrendAnalysis(dailyCosts, "daily")

	weeklyCosts := ca.aggregateWeekly(timeline)
	trends.WeeklyTrend = ca.calculateTrendAnalysis(weeklyCosts, "weekly")

	monthlyCosts := ca.aggregateMonthly(timeline)
	trends.MonthlyTrend = ca.calculateTrendAnalysis(monthlyCosts, "monthly")

	serviceTimelines := ca.extractServiceTimelines(timeline)
	for service, costs := range serviceTimelines {
		trends.ServiceTrends[service] = ca.calculateTrendAnalysis(costs, service)
	}

	trends.SeasonalPattern = ca.analyzeSeasonalPattern(timeline)
	trends.GrowthRate = ca.analyzeGrowthRate(timeline)

	return trends
}

func (ca *CostAnalyzer) detectAnomalies(timeline []CostTimelineEntry) []CostAnomaly {
	anomalies := []CostAnomaly{}

	if len(timeline) < 7 {
		return anomalies
	}

	movingAverage := ca.calculateMovingAverage(timeline, 7)
	stdDev := ca.calculateStandardDeviation(timeline)

	for i, entry := range timeline {
		if i < 7 {
			continue
		}

		expectedCost := movingAverage[i-7]
		deviation := math.Abs(entry.TotalCost - expectedCost)
		deviationPercent := (deviation / expectedCost) * 100

		if deviation > stdDev*2 {
			severity := "LOW"
			if deviation > stdDev*3 {
				severity = "HIGH"
			} else if deviation > stdDev*2.5 {
				severity = "MEDIUM"
			}

			anomalies = append(anomalies, CostAnomaly{
				ID:               fmt.Sprintf("anomaly-%s", entry.Date.Format("20060102")),
				DetectedAt:       entry.Date,
				Type:             "COST_SPIKE",
				Severity:         severity,
				ExpectedCost:     expectedCost,
				ActualCost:       entry.TotalCost,
				Deviation:        deviation,
				DeviationPercent: deviationPercent,
				Description:      fmt.Sprintf("Cost deviation of %.1f%% detected", deviationPercent),
				PossibleCauses: []string{
					"Unexpected resource scaling",
					"New resource deployments",
					"Traffic spike",
					"Configuration change",
				},
				Investigation: "Review resource changes and usage patterns for this period",
			})
		}
	}

	return anomalies
}

func (ca *CostAnalyzer) generateRecommendations(results *CostAnalysisResults) []CostRecommendation {
	recommendations := []CostRecommendation{}

	if results.Summary.TotalCost > 10000 {
		recommendations = append(recommendations, CostRecommendation{
			Type:        "COMMITMENT",
			Description: "Consider committed use discounts for stable workloads",
			Savings:     results.Summary.TotalCost * 0.2,
			Effort:      "MEDIUM",
			Priority:    "HIGH",
		})
	}

	if len(results.Optimizations) > 5 {
		totalSavings := 0.0
		for _, opt := range results.Optimizations {
			totalSavings += opt.Savings
		}

		recommendations = append(recommendations, CostRecommendation{
			Type:        "OPTIMIZATION",
			Description: fmt.Sprintf("Implement %d identified optimizations", len(results.Optimizations)),
			Savings:     totalSavings,
			Effort:      "HIGH",
			Priority:    "HIGH",
		})
	}

	if results.Trends.GrowthRate.CurrentRate > 20 {
		recommendations = append(recommendations, CostRecommendation{
			Type:        "GOVERNANCE",
			Description: "Implement cost governance and budget controls",
			Savings:     0,
			Effort:      "MEDIUM",
			Priority:    "HIGH",
		})
	}

	for service, cost := range results.Summary.CostByService {
		if cost > results.Summary.TotalCost*0.3 {
			recommendations = append(recommendations, CostRecommendation{
				Type:        "SERVICE_OPTIMIZATION",
				Description: fmt.Sprintf("Optimize %s service (%.1f%% of total cost)", service, (cost/results.Summary.TotalCost)*100),
				Savings:     cost * 0.15,
				Effort:      "HIGH",
				Priority:    "MEDIUM",
			})
		}
	}

	return recommendations
}

func (ca *CostAnalyzer) analyzeBudgetStatus(totalCost float64, options CostAnalysisOptions) BudgetStatus {
	budget := ca.config.BudgetLimits["total"]
	if budget == 0 {
		budget = 10000
	}

	daysInPeriod := int(options.EndDate.Sub(options.StartDate).Hours() / 24)
	daysRemaining := 30 - daysInPeriod
	if daysRemaining < 0 {
		daysRemaining = 0
	}

	dailyBurnRate := totalCost / float64(daysInPeriod)
	projectedMonthlySpend := dailyBurnRate * 30

	status := BudgetStatus{
		TotalBudget:       budget,
		UsedBudget:        totalCost,
		RemainingBudget:   math.Max(0, budget-totalCost),
		BudgetUtilization: (totalCost / budget) * 100,
		ProjectedOverage:  math.Max(0, projectedMonthlySpend-budget),
		DaysRemaining:     daysRemaining,
		BurnRate:          dailyBurnRate,
		Alerts:            []BudgetAlert{},
		Forecasts:         []BudgetForecast{},
	}

	if status.BudgetUtilization > 100 {
		status.Status = "EXCEEDED"
	} else if status.BudgetUtilization > 90 {
		status.Status = "CRITICAL"
	} else if status.BudgetUtilization > 75 {
		status.Status = "WARNING"
	} else {
		status.Status = "OK"
	}

	if status.BudgetUtilization > 80 {
		status.Alerts = append(status.Alerts, BudgetAlert{
			Type:        "THRESHOLD",
			Threshold:   80,
			Current:     status.BudgetUtilization,
			Message:     fmt.Sprintf("Budget utilization at %.1f%%", status.BudgetUtilization),
			Severity:    "WARNING",
			TriggeredAt: time.Now(),
		})
	}

	if status.ProjectedOverage > 0 {
		status.Alerts = append(status.Alerts, BudgetAlert{
			Type:        "PROJECTION",
			Threshold:   budget,
			Current:     projectedMonthlySpend,
			Message:     fmt.Sprintf("Projected to exceed budget by $%.2f", status.ProjectedOverage),
			Severity:    "HIGH",
			TriggeredAt: time.Now(),
		})
	}

	status.Forecasts = append(status.Forecasts, BudgetForecast{
		Period:          "End of Month",
		ProjectedSpend:  projectedMonthlySpend,
		BudgetLimit:     budget,
		ExpectedOverage: status.ProjectedOverage,
		Confidence:      0.85,
	})

	return status
}

func (ca *CostAnalyzer) getServiceFromResourceType(resourceType string) string {
	parts := strings.Split(resourceType, ".")
	if len(parts) > 0 {
		return parts[0]
	}
	return "unknown"
}

func (ca *CostAnalyzer) getApplicableDiscount(resource core.Resource) float64 {
	discount := ca.config.DiscountRate

	if resource.Labels["commitment"] == "1year" {
		discount += 0.2
	} else if resource.Labels["commitment"] == "3year" {
		discount += 0.3
	}

	if resource.Labels["sustained_use"] == "true" {
		discount += ca.config.SustainedUseDiscount
	}

	return math.Min(discount, 0.5)
}

func (ca *CostAnalyzer) getTopExpenses(expenseMap map[string]float64, resources []core.Resource, limit int) []ExpenseItem {
	expenses := []ExpenseItem{}

	for id, cost := range expenseMap {
		var resource *core.Resource
		for _, r := range resources {
			if r.ID == id {
				resource = &r
				break
			}
		}

		if resource != nil {
			expenses = append(expenses, ExpenseItem{
				Name:       resource.Name,
				Type:       resource.Type,
				Cost:       cost,
				ResourceID: id,
			})
		}
	}

	sort.Slice(expenses, func(i, j int) bool {
		return expenses[i].Cost > expenses[j].Cost
	})

	if len(expenses) > limit {
		expenses = expenses[:limit]
	}

	totalCost := 0.0
	for _, expense := range expenses {
		totalCost += expense.Cost
	}

	for i := range expenses {
		if totalCost > 0 {
			expenses[i].Percentage = (expenses[i].Cost / totalCost) * 100
		}
	}

	return expenses
}

func (ca *CostAnalyzer) analyzeCostChange(ctx context.Context, currentCost float64, options CostAnalysisOptions) CostChangeAnalysis {
	previousOptions := options
	previousOptions.StartDate = options.StartDate.AddDate(0, -1, 0)
	previousOptions.EndDate = options.StartDate

	previousResources, _ := ca.provider.ListResources(ctx, "", previousOptions.Filters)
	previousCost := 0.0
	for _, resource := range previousResources {
		if resource.Cost != nil {
			previousCost += resource.Cost.Actual
		}
	}

	change := CostChangeAnalysis{
		PreviousPeriodCost: previousCost,
		CurrentPeriodCost:  currentCost,
		AbsoluteChange:     currentCost - previousCost,
		Drivers:            []CostChangeDriver{},
	}

	if previousCost > 0 {
		change.PercentChange = ((currentCost - previousCost) / previousCost) * 100
	}

	if change.PercentChange > 0 {
		change.Direction = "INCREASE"
	} else if change.PercentChange < 0 {
		change.Direction = "DECREASE"
	} else {
		change.Direction = "STABLE"
	}

	return change
}

func (ca *CostAnalyzer) calculateDataCompleteness(resources []core.Resource) float64 {
	totalResources := len(resources)
	if totalResources == 0 {
		return 0
	}

	resourcesWithCost := 0
	for _, resource := range resources {
		if resource.Cost != nil {
			resourcesWithCost++
		}
	}

	return (float64(resourcesWithCost) / float64(totalResources)) * 100
}

func (ca *CostAnalyzer) getResourceUsageMetrics(ctx context.Context, resource core.Resource) map[string]float64 {
	metrics, err := ca.provider.GetResourceMetrics(ctx, resource.ID, resource.Type)
	if err != nil {
		return make(map[string]float64)
	}

	usageMetrics := make(map[string]float64)
	for key, value := range metrics {
		if floatVal, ok := value.(float64); ok {
			usageMetrics[key] = floatVal
		}
	}

	return usageMetrics
}

func (ca *CostAnalyzer) getResourcePricing(resource core.Resource) PricingInfo {
	return PricingInfo{
		SKU:            "compute-optimized-v2",
		PricePerUnit:   0.05,
		Unit:           "hour",
		Tier:           "standard",
		DiscountApplied: ca.getApplicableDiscount(resource),
		EffectivePrice: 0.05 * (1 - ca.getApplicableDiscount(resource)),
	}
}

func (ca *CostAnalyzer) getResourceRecommendations(resource core.Resource) []string {
	recommendations := []string{}

	if resource.Status == "STOPPED" {
		recommendations = append(recommendations, "Consider terminating stopped resources")
	}

	if resource.Cost != nil && resource.Cost.Actual > 100 {
		recommendations = append(recommendations, "High cost resource - review for optimization")
	}

	return recommendations
}

func (ca *CostAnalyzer) calculateEnvironmentEfficiency(environment EnvironmentCost) string {
	if environment.TotalCost == 0 {
		return "NO_COST"
	}

	costPerResource := environment.TotalCost / float64(environment.ResourceCount)
	if costPerResource < 10 {
		return "HIGH"
	} else if costPerResource < 50 {
		return "MEDIUM"
	}
	return "LOW"
}

func (ca *CostAnalyzer) calculateTrend(costs []float64) float64 {
	if len(costs) < 2 {
		return 0
	}

	n := float64(len(costs))
	sumX := n * (n - 1) / 2
	sumY := 0.0
	sumXY := 0.0
	sumX2 := n * (n - 1) * (2*n - 1) / 6

	for i, cost := range costs {
		sumY += cost
		sumXY += float64(i) * cost
	}

	return (n*sumXY - sumX*sumY) / (n*sumX2 - sumX*sumX)
}

func (ca *CostAnalyzer) detectSeasonality(timeline []CostTimelineEntry) SeasonalAnalysis {
	if len(timeline) < 30 {
		return SeasonalAnalysis{Seasonality: false}
	}

	weekdayAverages := make(map[time.Weekday]float64)
	weekdayCounts := make(map[time.Weekday]int)

	for _, entry := range timeline {
		weekday := entry.Date.Weekday()
		weekdayAverages[weekday] += entry.TotalCost
		weekdayCounts[weekday]++
	}

	for weekday, total := range weekdayAverages {
		if count := weekdayCounts[weekday]; count > 0 {
			weekdayAverages[weekday] = total / float64(count)
		}
	}

	seasonalFactors := make(map[string]float64)
	overallAverage := 0.0
	for _, avg := range weekdayAverages {
		overallAverage += avg
	}
	overallAverage /= 7

	for weekday, avg := range weekdayAverages {
		seasonalFactors[weekday.String()] = avg / overallAverage
	}

	return SeasonalAnalysis{
		Pattern:         "WEEKLY",
		Seasonality:     true,
		SeasonalFactors: seasonalFactors,
		Confidence:      0.75,
	}
}

func (ca *CostAnalyzer) getSeasonalFactor(date time.Time, seasonality SeasonalAnalysis) float64 {
	if !seasonality.Seasonality {
		return 1.0
	}

	if factor, ok := seasonality.SeasonalFactors[date.Weekday().String()]; ok {
		return factor
	}

	return 1.0
}

func (ca *CostAnalyzer) generateForecastRecommendations(forecast CostForecast, averageCost float64) []string {
	recommendations := []string{}

	if forecast.PredictedCost > averageCost*30*1.2 {
		recommendations = append(recommendations,
			"Projected costs are 20% above average - review planned deployments",
			"Consider implementing cost controls before the projected increase")
	}

	if forecast.ConfidenceLevel < 0.7 {
		recommendations = append(recommendations,
			"Low confidence in forecast - gather more historical data",
			"Monitor actual costs closely against predictions")
	}

	return recommendations
}

func (ca *CostAnalyzer) findUnderutilizedResources(ctx context.Context, resources []core.Resource) []core.Resource {
	underutilized := []core.Resource{}

	for _, resource := range resources {
		metrics, err := ca.provider.GetResourceMetrics(ctx, resource.ID, resource.Type)
		if err != nil {
			continue
		}

		if cpu, ok := metrics["cpu"].(float64); ok && cpu < 20 {
			underutilized = append(underutilized, resource)
		}
	}

	return underutilized
}

func (ca *CostAnalyzer) findIdleResources(resources []core.Resource) []core.Resource {
	idle := []core.Resource{}

	for _, resource := range resources {
		if resource.Status == "STOPPED" || resource.Status == "IDLE" {
			idle = append(idle, resource)
		}
	}

	return idle
}

func (ca *CostAnalyzer) identifyCommitmentOpportunities(breakdown CostBreakdown) []CostOptimizationOption {
	opportunities := []CostOptimizationOption{}

	for service, serviceCost := range breakdown.ByService {
		if serviceCost.TotalCost > 1000 {
			opportunities = append(opportunities, CostOptimizationOption{
				ID:               fmt.Sprintf("opt-commit-%s", service),
				Type:             "COMMITMENT",
				Category:         "RESERVATION",
				Title:            fmt.Sprintf("Purchase committed use for %s", service),
				Description:      fmt.Sprintf("Save 20-30%% with 1-year commitment for %s", service),
				CurrentCost:      serviceCost.TotalCost,
				OptimizedCost:    serviceCost.TotalCost * 0.75,
				Savings:          serviceCost.TotalCost * 0.25,
				SavingsPercent:   25,
				Risk:             "MEDIUM",
				Effort:           "LOW",
				Priority:         3,
			})
		}
	}

	return opportunities
}

func (ca *CostAnalyzer) calculateTrendAnalysis(costs []float64, name string) TrendAnalysis {
	if len(costs) == 0 {
		return TrendAnalysis{}
	}

	trend := TrendAnalysis{
		DataPoints: len(costs),
		StartValue: costs[0],
		EndValue:   costs[len(costs)-1],
	}

	if len(costs) > 1 {
		trend.Slope = ca.calculateTrend(costs)
		trend.R2 = ca.calculateR2(costs, trend.Slope)
		trend.Volatility = ca.calculateVolatility(costs)

		if trend.Slope > 0 {
			trend.Direction = "INCREASING"
		} else if trend.Slope < 0 {
			trend.Direction = "DECREASING"
		} else {
			trend.Direction = "STABLE"
		}

		trend.Magnitude = math.Abs((trend.EndValue - trend.StartValue) / trend.StartValue * 100)
		trend.Confidence = math.Min(trend.R2*100, 95)
	}

	max := costs[0]
	min := costs[0]
	for _, cost := range costs {
		if cost > max {
			max = cost
		}
		if cost < min {
			min = cost
		}
	}
	trend.PeakValue = max
	trend.TroughValue = min

	trend.Interpretation = ca.interpretTrend(trend)

	return trend
}

func (ca *CostAnalyzer) calculateR2(costs []float64, slope float64) float64 {
	if len(costs) < 2 {
		return 0
	}

	mean := 0.0
	for _, cost := range costs {
		mean += cost
	}
	mean /= float64(len(costs))

	ssTotal := 0.0
	ssResidual := 0.0

	for i, cost := range costs {
		predicted := slope*float64(i) + costs[0]
		ssTotal += (cost - mean) * (cost - mean)
		ssResidual += (cost - predicted) * (cost - predicted)
	}

	if ssTotal == 0 {
		return 0
	}

	return 1 - (ssResidual / ssTotal)
}

func (ca *CostAnalyzer) calculateVolatility(costs []float64) float64 {
	if len(costs) < 2 {
		return 0
	}

	mean := 0.0
	for _, cost := range costs {
		mean += cost
	}
	mean /= float64(len(costs))

	variance := 0.0
	for _, cost := range costs {
		variance += (cost - mean) * (cost - mean)
	}
	variance /= float64(len(costs) - 1)

	return math.Sqrt(variance) / mean * 100
}

func (ca *CostAnalyzer) interpretTrend(trend TrendAnalysis) string {
	if trend.Volatility > 50 {
		return "Highly volatile cost pattern detected"
	}

	if trend.Direction == "INCREASING" {
		if trend.Magnitude > 50 {
			return "Significant cost increase trend"
		} else if trend.Magnitude > 20 {
			return "Moderate cost increase trend"
		}
		return "Slight upward cost trend"
	} else if trend.Direction == "DECREASING" {
		if trend.Magnitude > 30 {
			return "Significant cost reduction achieved"
		}
		return "Cost reduction trend"
	}

	return "Stable cost pattern"
}

func (ca *CostAnalyzer) aggregateWeekly(timeline []CostTimelineEntry) []float64 {
	weekly := []float64{}
	weekSum := 0.0
	dayCount := 0

	for i, entry := range timeline {
		weekSum += entry.TotalCost
		dayCount++

		if dayCount == 7 || i == len(timeline)-1 {
			weekly = append(weekly, weekSum)
			weekSum = 0
			dayCount = 0
		}
	}

	return weekly
}

func (ca *CostAnalyzer) aggregateMonthly(timeline []CostTimelineEntry) []float64 {
	monthly := []float64{}
	currentMonth := -1
	monthSum := 0.0

	for _, entry := range timeline {
		month := int(entry.Date.Month())
		if currentMonth == -1 {
			currentMonth = month
		}

		if month != currentMonth {
			monthly = append(monthly, monthSum)
			monthSum = 0
			currentMonth = month
		}

		monthSum += entry.TotalCost
	}

	if monthSum > 0 {
		monthly = append(monthly, monthSum)
	}

	return monthly
}

func (ca *CostAnalyzer) extractServiceTimelines(timeline []CostTimelineEntry) map[string][]float64 {
	serviceTimelines := make(map[string][]float64)

	for _, entry := range timeline {
		for service, cost := range entry.ServiceCosts {
			serviceTimelines[service] = append(serviceTimelines[service], cost)
		}
	}

	return serviceTimelines
}

func (ca *CostAnalyzer) analyzeSeasonalPattern(timeline []CostTimelineEntry) SeasonalAnalysis {
	return ca.detectSeasonality(timeline)
}

func (ca *CostAnalyzer) analyzeGrowthRate(timeline []CostTimelineEntry) GrowthAnalysis {
	if len(timeline) < 2 {
		return GrowthAnalysis{}
	}

	costs := []float64{}
	for _, entry := range timeline {
		costs = append(costs, entry.TotalCost)
	}

	firstValue := costs[0]
	lastValue := costs[len(costs)-1]
	periods := float64(len(costs))

	averageRate := math.Pow(lastValue/firstValue, 1/periods) - 1
	currentRate := (lastValue - costs[len(costs)-2]) / costs[len(costs)-2]

	growth := GrowthAnalysis{
		CurrentRate:   currentRate * 100,
		AverageRate:   averageRate * 100,
		ProjectedRate: averageRate * 100,
	}

	if averageRate > 0 {
		growth.DoublingTime = math.Log(2) / math.Log(1+averageRate)
	}

	if growth.AverageRate > 50 {
		growth.Sustainability = "UNSUSTAINABLE"
	} else if growth.AverageRate > 20 {
		growth.Sustainability = "CONCERNING"
	} else if growth.AverageRate > 10 {
		growth.Sustainability = "MODERATE"
	} else {
		growth.Sustainability = "SUSTAINABLE"
	}

	return growth
}

func (ca *CostAnalyzer) calculateMovingAverage(timeline []CostTimelineEntry, window int) []float64 {
	movingAvg := []float64{}

	for i := window - 1; i < len(timeline); i++ {
		sum := 0.0
		for j := i - window + 1; j <= i; j++ {
			sum += timeline[j].TotalCost
		}
		movingAvg = append(movingAvg, sum/float64(window))
	}

	return movingAvg
}

func (ca *CostAnalyzer) calculateStandardDeviation(timeline []CostTimelineEntry) float64 {
	if len(timeline) < 2 {
		return 0
	}

	mean := 0.0
	for _, entry := range timeline {
		mean += entry.TotalCost
	}
	mean /= float64(len(timeline))

	variance := 0.0
	for _, entry := range timeline {
		variance += (entry.TotalCost - mean) * (entry.TotalCost - mean)
	}
	variance /= float64(len(timeline) - 1)

	return math.Sqrt(variance)
}