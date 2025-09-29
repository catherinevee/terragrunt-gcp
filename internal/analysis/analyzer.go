package analysis

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/sirupsen/logrus"
	"github.com/terragrunt-gcp/terragrunt-gcp/internal/core"
	"github.com/terragrunt-gcp/terragrunt-gcp/internal/providers"
)

type Analyzer struct {
	provider providers.Provider
	logger   *logrus.Logger
	config   AnalyzerConfig
	mutex    sync.RWMutex
}

type AnalyzerConfig struct {
	MaxWorkers       int
	Timeout          time.Duration
	DeepAnalysis     bool
	IncludeHistorical bool
	HistoricalDays   int
	MetricsInterval  time.Duration
	Thresholds       Thresholds
}

type Thresholds struct {
	CPUUtilizationHigh    float64
	CPUUtilizationLow     float64
	MemoryUtilizationHigh float64
	MemoryUtilizationLow  float64
	DiskUtilizationHigh   float64
	ErrorRateHigh         float64
	LatencyHigh           float64
	CostIncreasePercent   float64
}

type AnalysisOptions struct {
	ResourceType    string
	ResourceIDs     []string
	Detailed        bool
	Metrics         []string
	Period          time.Duration
	GroupBy         string
	IncludeForecasts bool
	IncludeAnomalies bool
	CompareBaseline  bool
}

type AnalysisResults struct {
	Summary         AnalysisSummary          `json:"summary"`
	Resources       []ResourceAnalysis       `json:"resources"`
	Metrics         map[string]MetricAnalysis `json:"metrics"`
	Trends          []TrendAnalysis          `json:"trends"`
	Anomalies       []Anomaly                `json:"anomalies"`
	Recommendations []AnalysisRecommendation `json:"recommendations"`
	Insights        []Insight                `json:"insights"`
	Timestamp       time.Time                `json:"timestamp"`
}

type AnalysisSummary struct {
	TotalResources      int                    `json:"total_resources"`
	AnalyzedResources   int                    `json:"analyzed_resources"`
	HealthyResources    int                    `json:"healthy_resources"`
	WarningResources    int                    `json:"warning_resources"`
	CriticalResources   int                    `json:"critical_resources"`
	TotalCost          float64                `json:"total_cost"`
	OptimizationPotential float64              `json:"optimization_potential"`
	OverallHealth      string                 `json:"overall_health"`
	KeyMetrics         map[string]interface{} `json:"key_metrics"`
}

type ResourceAnalysis struct {
	ResourceID      string                 `json:"resource_id"`
	ResourceName    string                 `json:"resource_name"`
	ResourceType    string                 `json:"resource_type"`
	Region          string                 `json:"region"`
	Status          string                 `json:"status"`
	Health          string                 `json:"health"`
	HealthScore     int                    `json:"health_score"`
	Utilization     UtilizationAnalysis    `json:"utilization"`
	Performance     PerformanceAnalysis    `json:"performance"`
	Cost            CostAnalysisDetail     `json:"cost"`
	Issues          []AnalysisIssue        `json:"issues"`
	Recommendations []string               `json:"recommendations"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type UtilizationAnalysis struct {
	CPU         UtilizationMetric `json:"cpu"`
	Memory      UtilizationMetric `json:"memory"`
	Disk        UtilizationMetric `json:"disk"`
	Network     UtilizationMetric `json:"network"`
	Overall     float64           `json:"overall"`
	Efficiency  string            `json:"efficiency"`
}

type UtilizationMetric struct {
	Current     float64   `json:"current"`
	Average     float64   `json:"average"`
	Peak        float64   `json:"peak"`
	Minimum     float64   `json:"minimum"`
	Percentile95 float64  `json:"percentile_95"`
	Trend       string    `json:"trend"`
	Status      string    `json:"status"`
	Timestamp   time.Time `json:"timestamp"`
}

type PerformanceAnalysis struct {
	ResponseTime    PerformanceMetric      `json:"response_time"`
	Throughput      PerformanceMetric      `json:"throughput"`
	ErrorRate       PerformanceMetric      `json:"error_rate"`
	Availability    float64                `json:"availability"`
	SLACompliance   bool                   `json:"sla_compliance"`
	PerformanceScore int                   `json:"performance_score"`
	Bottlenecks     []string               `json:"bottlenecks"`
	Optimization    map[string]interface{} `json:"optimization"`
}

type PerformanceMetric struct {
	Value       float64   `json:"value"`
	Unit        string    `json:"unit"`
	Baseline    float64   `json:"baseline"`
	Deviation   float64   `json:"deviation"`
	Status      string    `json:"status"`
	Timestamp   time.Time `json:"timestamp"`
}

type CostAnalysisDetail struct {
	CurrentCost     float64                `json:"current_cost"`
	ProjectedCost   float64                `json:"projected_cost"`
	OptimizedCost   float64                `json:"optimized_cost"`
	SavingsPotential float64               `json:"savings_potential"`
	CostBreakdown   map[string]float64     `json:"cost_breakdown"`
	CostTrend       string                 `json:"cost_trend"`
	Recommendations []CostRecommendation   `json:"recommendations"`
}

type AnalysisIssue struct {
	ID          string    `json:"id"`
	Type        string    `json:"type"`
	Severity    string    `json:"severity"`
	Description string    `json:"description"`
	Impact      string    `json:"impact"`
	Resolution  string    `json:"resolution"`
	DetectedAt  time.Time `json:"detected_at"`
}

type MetricAnalysis struct {
	Name        string                 `json:"name"`
	Value       float64                `json:"value"`
	Unit        string                 `json:"unit"`
	Average     float64                `json:"average"`
	Min         float64                `json:"min"`
	Max         float64                `json:"max"`
	StdDev      float64                `json:"std_dev"`
	Percentiles map[int]float64        `json:"percentiles"`
	Trend       TrendInfo              `json:"trend"`
	Forecast    []ForecastPoint        `json:"forecast,omitempty"`
	Anomalies   []AnomalyPoint         `json:"anomalies,omitempty"`
	Metadata    map[string]interface{} `json:"metadata"`
}

type TrendAnalysis struct {
	Metric      string          `json:"metric"`
	Period      string          `json:"period"`
	Direction   string          `json:"direction"`
	Magnitude   float64         `json:"magnitude"`
	Confidence  float64         `json:"confidence"`
	DataPoints  []DataPoint     `json:"data_points"`
	Prediction  []DataPoint     `json:"prediction,omitempty"`
	Significance string         `json:"significance"`
}

type TrendInfo struct {
	Direction   string  `json:"direction"`
	Slope       float64 `json:"slope"`
	R2          float64 `json:"r2"`
	Confidence  float64 `json:"confidence"`
	Description string  `json:"description"`
}

type DataPoint struct {
	Timestamp time.Time `json:"timestamp"`
	Value     float64   `json:"value"`
	Label     string    `json:"label,omitempty"`
}

type ForecastPoint struct {
	Timestamp       time.Time `json:"timestamp"`
	PredictedValue  float64   `json:"predicted_value"`
	UpperBound      float64   `json:"upper_bound"`
	LowerBound      float64   `json:"lower_bound"`
	ConfidenceLevel float64   `json:"confidence_level"`
}

type Anomaly struct {
	ID           string    `json:"id"`
	Type         string    `json:"type"`
	Severity     string    `json:"severity"`
	Resource     string    `json:"resource"`
	Metric       string    `json:"metric"`
	Value        float64   `json:"value"`
	ExpectedValue float64  `json:"expected_value"`
	Deviation    float64   `json:"deviation"`
	Description  string    `json:"description"`
	DetectedAt   time.Time `json:"detected_at"`
	Duration     string    `json:"duration"`
}

type AnomalyPoint struct {
	Timestamp   time.Time `json:"timestamp"`
	Value       float64   `json:"value"`
	Expected    float64   `json:"expected"`
	Deviation   float64   `json:"deviation"`
	Severity    string    `json:"severity"`
	Description string    `json:"description"`
}

type AnalysisRecommendation struct {
	ID           string                 `json:"id"`
	Category     string                 `json:"category"`
	Priority     string                 `json:"priority"`
	Title        string                 `json:"title"`
	Description  string                 `json:"description"`
	Impact       ImpactAssessment       `json:"impact"`
	Implementation ImplementationGuide  `json:"implementation"`
	Resources    []string               `json:"resources"`
	EstimatedSavings float64            `json:"estimated_savings,omitempty"`
	Confidence   float64                `json:"confidence"`
}

type ImpactAssessment struct {
	Performance  string  `json:"performance"`
	Cost         string  `json:"cost"`
	Reliability  string  `json:"reliability"`
	Security     string  `json:"security"`
	OverallScore float64 `json:"overall_score"`
}

type ImplementationGuide struct {
	Steps       []string `json:"steps"`
	Complexity  string   `json:"complexity"`
	Duration    string   `json:"duration"`
	Risk        string   `json:"risk"`
	Automation  bool     `json:"automation"`
	Script      string   `json:"script,omitempty"`
}

type Insight struct {
	ID          string    `json:"id"`
	Type        string    `json:"type"`
	Category    string    `json:"category"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Evidence    []string  `json:"evidence"`
	Confidence  float64   `json:"confidence"`
	Impact      string    `json:"impact"`
	Action      string    `json:"action"`
	Timestamp   time.Time `json:"timestamp"`
}

type CostRecommendation struct {
	Type        string  `json:"type"`
	Description string  `json:"description"`
	Savings     float64 `json:"savings"`
	Effort      string  `json:"effort"`
	Priority    string  `json:"priority"`
}

func NewAnalyzer(provider providers.Provider, logger *logrus.Logger) *Analyzer {
	return &Analyzer{
		provider: provider,
		logger:   logger,
		config: AnalyzerConfig{
			MaxWorkers:        10,
			Timeout:           5 * time.Minute,
			DeepAnalysis:      true,
			IncludeHistorical: true,
			HistoricalDays:    30,
			MetricsInterval:   5 * time.Minute,
			Thresholds: Thresholds{
				CPUUtilizationHigh:    80.0,
				CPUUtilizationLow:     10.0,
				MemoryUtilizationHigh: 85.0,
				MemoryUtilizationLow:  10.0,
				DiskUtilizationHigh:   90.0,
				ErrorRateHigh:         5.0,
				LatencyHigh:           1000.0,
				CostIncreasePercent:   20.0,
			},
		},
	}
}

func (a *Analyzer) Analyze(ctx context.Context, options AnalysisOptions) (*AnalysisResults, error) {
	a.logger.Info("Starting comprehensive analysis")

	ctx, cancel := context.WithTimeout(ctx, a.config.Timeout)
	defer cancel()

	results := &AnalysisResults{
		Resources:       []ResourceAnalysis{},
		Metrics:         make(map[string]MetricAnalysis),
		Trends:          []TrendAnalysis{},
		Anomalies:       []Anomaly{},
		Recommendations: []AnalysisRecommendation{},
		Insights:        []Insight{},
		Timestamp:       time.Now(),
	}

	resources, err := a.getResourcesToAnalyze(ctx, options)
	if err != nil {
		return nil, fmt.Errorf("failed to get resources: %w", err)
	}

	var wg sync.WaitGroup
	resourceChan := make(chan ResourceAnalysis, len(resources))
	anomalyChan := make(chan Anomaly, a.config.MaxWorkers)
	semaphore := make(chan struct{}, a.config.MaxWorkers)

	for _, resource := range resources {
		wg.Add(1)
		go func(res core.Resource) {
			defer wg.Done()
			semaphore <- struct{}{}
			defer func() { <-semaphore }()

			analysis := a.analyzeResource(ctx, res, options)
			resourceChan <- analysis

			if anomalies := a.detectAnomalies(ctx, res); len(anomalies) > 0 {
				for _, anomaly := range anomalies {
					anomalyChan <- anomaly
				}
			}
		}(resource)
	}

	go func() {
		wg.Wait()
		close(resourceChan)
		close(anomalyChan)
	}()

	for analysis := range resourceChan {
		a.mutex.Lock()
		results.Resources = append(results.Resources, analysis)
		a.updateSummary(&results.Summary, analysis)
		a.mutex.Unlock()
	}

	for anomaly := range anomalyChan {
		a.mutex.Lock()
		results.Anomalies = append(results.Anomalies, anomaly)
		a.mutex.Unlock()
	}

	if options.Detailed {
		results.Metrics = a.analyzeMetrics(ctx, resources, options)
		results.Trends = a.analyzeTrends(ctx, resources, options)
	}

	results.Recommendations = a.generateRecommendations(results)
	results.Insights = a.generateInsights(results)

	a.logger.Infof("Analysis completed: %d resources analyzed, %d anomalies detected",
		len(results.Resources), len(results.Anomalies))

	return results, nil
}

func (a *Analyzer) getResourcesToAnalyze(ctx context.Context, options AnalysisOptions) ([]core.Resource, error) {
	var resources []core.Resource

	if len(options.ResourceIDs) > 0 {
		for _, id := range options.ResourceIDs {
			resource, err := a.provider.GetResource(ctx, id)
			if err != nil {
				a.logger.Warnf("Failed to get resource %s: %v", id, err)
				continue
			}
			resources = append(resources, *resource)
		}
	} else {
		filters := make(map[string]interface{})
		if options.ResourceType != "" {
			filters["type"] = options.ResourceType
		}

		resourceList, err := a.provider.ListResources(ctx, options.ResourceType, filters)
		if err != nil {
			return nil, err
		}
		resources = resourceList
	}

	return resources, nil
}

func (a *Analyzer) analyzeResource(ctx context.Context, resource core.Resource, options AnalysisOptions) ResourceAnalysis {
	analysis := ResourceAnalysis{
		ResourceID:      resource.ID,
		ResourceName:    resource.Name,
		ResourceType:    resource.Type,
		Region:          resource.Region,
		Status:          resource.Status,
		Issues:          []AnalysisIssue{},
		Recommendations: []string{},
		Metadata:        make(map[string]interface{}),
	}

	analysis.Utilization = a.analyzeUtilization(ctx, resource)
	analysis.Performance = a.analyzePerformance(ctx, resource)
	analysis.Cost = a.analyzeCost(ctx, resource)

	analysis.Health, analysis.HealthScore = a.calculateHealth(analysis)

	issues := a.identifyIssues(analysis)
	analysis.Issues = issues

	recommendations := a.generateResourceRecommendations(analysis)
	analysis.Recommendations = recommendations

	return analysis
}

func (a *Analyzer) analyzeUtilization(ctx context.Context, resource core.Resource) UtilizationAnalysis {
	metrics, err := a.provider.GetResourceMetrics(ctx, resource.ID, resource.Type)
	if err != nil {
		a.logger.Warnf("Failed to get metrics for %s: %v", resource.ID, err)
		return UtilizationAnalysis{}
	}

	utilization := UtilizationAnalysis{
		CPU:     a.analyzeUtilizationMetric(metrics, "cpu"),
		Memory:  a.analyzeUtilizationMetric(metrics, "memory"),
		Disk:    a.analyzeUtilizationMetric(metrics, "disk"),
		Network: a.analyzeUtilizationMetric(metrics, "network"),
	}

	utilization.Overall = (utilization.CPU.Average + utilization.Memory.Average +
		utilization.Disk.Average + utilization.Network.Average) / 4

	if utilization.Overall < 20 {
		utilization.Efficiency = "UNDERUTILIZED"
	} else if utilization.Overall > 80 {
		utilization.Efficiency = "OVERUTILIZED"
	} else {
		utilization.Efficiency = "OPTIMAL"
	}

	return utilization
}

func (a *Analyzer) analyzeUtilizationMetric(metrics map[string]interface{}, metricName string) UtilizationMetric {
	metric := UtilizationMetric{
		Timestamp: time.Now(),
	}

	if data, ok := metrics[metricName].(map[string]interface{}); ok {
		if current, ok := data["current"].(float64); ok {
			metric.Current = current
		}
		if average, ok := data["average"].(float64); ok {
			metric.Average = average
		}
		if peak, ok := data["peak"].(float64); ok {
			metric.Peak = peak
		}
		if minimum, ok := data["minimum"].(float64); ok {
			metric.Minimum = minimum
		}
		if p95, ok := data["percentile_95"].(float64); ok {
			metric.Percentile95 = p95
		}
	}

	if metric.Average < a.config.Thresholds.CPUUtilizationLow {
		metric.Status = "LOW"
		metric.Trend = "STABLE"
	} else if metric.Average > a.config.Thresholds.CPUUtilizationHigh {
		metric.Status = "HIGH"
		metric.Trend = "INCREASING"
	} else {
		metric.Status = "NORMAL"
		metric.Trend = "STABLE"
	}

	return metric
}

func (a *Analyzer) analyzePerformance(ctx context.Context, resource core.Resource) PerformanceAnalysis {
	performance := PerformanceAnalysis{
		PerformanceScore: 100,
		Bottlenecks:      []string{},
		Optimization:     make(map[string]interface{}),
	}

	metrics, err := a.provider.GetResourceMetrics(ctx, resource.ID, resource.Type)
	if err != nil {
		return performance
	}

	if responseTime, ok := metrics["response_time"].(float64); ok {
		performance.ResponseTime = PerformanceMetric{
			Value:     responseTime,
			Unit:      "ms",
			Baseline:  100,
			Deviation: responseTime - 100,
			Status:    a.getPerformanceStatus(responseTime, a.config.Thresholds.LatencyHigh),
			Timestamp: time.Now(),
		}
	}

	if throughput, ok := metrics["throughput"].(float64); ok {
		performance.Throughput = PerformanceMetric{
			Value:     throughput,
			Unit:      "req/s",
			Baseline:  1000,
			Deviation: throughput - 1000,
			Status:    "NORMAL",
			Timestamp: time.Now(),
		}
	}

	if errorRate, ok := metrics["error_rate"].(float64); ok {
		performance.ErrorRate = PerformanceMetric{
			Value:     errorRate,
			Unit:      "%",
			Baseline:  1.0,
			Deviation: errorRate - 1.0,
			Status:    a.getPerformanceStatus(errorRate, a.config.Thresholds.ErrorRateHigh),
			Timestamp: time.Now(),
		}

		if errorRate > a.config.Thresholds.ErrorRateHigh {
			performance.PerformanceScore -= 20
			performance.Bottlenecks = append(performance.Bottlenecks, "High error rate detected")
		}
	}

	if availability, ok := metrics["availability"].(float64); ok {
		performance.Availability = availability
		performance.SLACompliance = availability >= 99.9
		if !performance.SLACompliance {
			performance.PerformanceScore -= 30
		}
	}

	return performance
}

func (a *Analyzer) analyzeCost(ctx context.Context, resource core.Resource) CostAnalysisDetail {
	cost := CostAnalysisDetail{
		CostBreakdown:   make(map[string]float64),
		Recommendations: []CostRecommendation{},
	}

	if resource.Cost != nil {
		cost.CurrentCost = resource.Cost.Actual
		cost.ProjectedCost = resource.Cost.Estimated

		utilization := a.analyzeUtilization(ctx, resource)
		if utilization.Efficiency == "UNDERUTILIZED" {
			cost.OptimizedCost = cost.CurrentCost * 0.6
			cost.SavingsPotential = cost.CurrentCost - cost.OptimizedCost

			cost.Recommendations = append(cost.Recommendations, CostRecommendation{
				Type:        "RIGHTSIZING",
				Description: "Resource is underutilized. Consider downsizing.",
				Savings:     cost.SavingsPotential,
				Effort:      "LOW",
				Priority:    "HIGH",
			})
		}

		if cost.ProjectedCost > cost.CurrentCost*1.2 {
			cost.CostTrend = "INCREASING"
		} else if cost.ProjectedCost < cost.CurrentCost*0.8 {
			cost.CostTrend = "DECREASING"
		} else {
			cost.CostTrend = "STABLE"
		}
	}

	return cost
}

func (a *Analyzer) calculateHealth(analysis ResourceAnalysis) (string, int) {
	score := 100

	if analysis.Utilization.Efficiency == "OVERUTILIZED" {
		score -= 20
	} else if analysis.Utilization.Efficiency == "UNDERUTILIZED" {
		score -= 10
	}

	if analysis.Performance.ErrorRate.Value > a.config.Thresholds.ErrorRateHigh {
		score -= 25
	}

	if !analysis.Performance.SLACompliance {
		score -= 15
	}

	if len(analysis.Issues) > 0 {
		for _, issue := range analysis.Issues {
			switch issue.Severity {
			case "CRITICAL":
				score -= 20
			case "HIGH":
				score -= 10
			case "MEDIUM":
				score -= 5
			}
		}
	}

	var health string
	switch {
	case score >= 90:
		health = "HEALTHY"
	case score >= 70:
		health = "WARNING"
	case score >= 50:
		health = "DEGRADED"
	default:
		health = "CRITICAL"
	}

	if score < 0 {
		score = 0
	}

	return health, score
}

func (a *Analyzer) identifyIssues(analysis ResourceAnalysis) []AnalysisIssue {
	issues := []AnalysisIssue{}

	if analysis.Utilization.CPU.Average > a.config.Thresholds.CPUUtilizationHigh {
		issues = append(issues, AnalysisIssue{
			ID:          fmt.Sprintf("cpu-high-%s", analysis.ResourceID),
			Type:        "PERFORMANCE",
			Severity:    "HIGH",
			Description: fmt.Sprintf("CPU utilization is high: %.2f%%", analysis.Utilization.CPU.Average),
			Impact:      "Performance degradation and potential service disruption",
			Resolution:  "Consider scaling up or optimizing workload",
			DetectedAt:  time.Now(),
		})
	}

	if analysis.Utilization.Memory.Average > a.config.Thresholds.MemoryUtilizationHigh {
		issues = append(issues, AnalysisIssue{
			ID:          fmt.Sprintf("mem-high-%s", analysis.ResourceID),
			Type:        "PERFORMANCE",
			Severity:    "HIGH",
			Description: fmt.Sprintf("Memory utilization is high: %.2f%%", analysis.Utilization.Memory.Average),
			Impact:      "Risk of out-of-memory errors and application crashes",
			Resolution:  "Increase memory allocation or optimize memory usage",
			DetectedAt:  time.Now(),
		})
	}

	if analysis.Performance.ErrorRate.Value > a.config.Thresholds.ErrorRateHigh {
		issues = append(issues, AnalysisIssue{
			ID:          fmt.Sprintf("error-rate-%s", analysis.ResourceID),
			Type:        "RELIABILITY",
			Severity:    "CRITICAL",
			Description: fmt.Sprintf("Error rate exceeds threshold: %.2f%%", analysis.Performance.ErrorRate.Value),
			Impact:      "Service reliability compromised, user experience affected",
			Resolution:  "Investigate error logs and implement fixes",
			DetectedAt:  time.Now(),
		})
	}

	if analysis.Cost.SavingsPotential > 100 {
		issues = append(issues, AnalysisIssue{
			ID:          fmt.Sprintf("cost-opt-%s", analysis.ResourceID),
			Type:        "COST",
			Severity:    "MEDIUM",
			Description: fmt.Sprintf("Cost optimization opportunity: $%.2f potential savings", analysis.Cost.SavingsPotential),
			Impact:      "Unnecessary spending on underutilized resources",
			Resolution:  "Implement cost optimization recommendations",
			DetectedAt:  time.Now(),
		})
	}

	return issues
}

func (a *Analyzer) generateResourceRecommendations(analysis ResourceAnalysis) []string {
	recommendations := []string{}

	if analysis.Utilization.Efficiency == "UNDERUTILIZED" {
		recommendations = append(recommendations,
			"Consider downsizing this resource to reduce costs",
			"Enable auto-scaling to match resource capacity with demand",
			"Consolidate workloads to improve resource utilization")
	}

	if analysis.Utilization.Efficiency == "OVERUTILIZED" {
		recommendations = append(recommendations,
			"Upgrade to a larger instance type to handle the workload",
			"Implement horizontal scaling to distribute the load",
			"Optimize application code to reduce resource consumption")
	}

	if analysis.Performance.ErrorRate.Value > a.config.Thresholds.ErrorRateHigh {
		recommendations = append(recommendations,
			"Implement comprehensive error handling and retry logic",
			"Add monitoring and alerting for critical errors",
			"Review recent deployments for potential issues")
	}

	if !analysis.Performance.SLACompliance {
		recommendations = append(recommendations,
			"Implement redundancy and failover mechanisms",
			"Optimize database queries and indexes",
			"Consider using a CDN to improve response times")
	}

	return recommendations
}

func (a *Analyzer) detectAnomalies(ctx context.Context, resource core.Resource) []Anomaly {
	anomalies := []Anomaly{}

	metrics, err := a.provider.GetResourceMetrics(ctx, resource.ID, resource.Type)
	if err != nil {
		return anomalies
	}

	for metricName, value := range metrics {
		if metricValue, ok := value.(float64); ok {
			historical := a.getHistoricalAverage(ctx, resource.ID, metricName)
			deviation := metricValue - historical

			if deviation > historical*0.5 || deviation < -historical*0.5 {
				anomalies = append(anomalies, Anomaly{
					ID:            fmt.Sprintf("anomaly-%s-%s", resource.ID, metricName),
					Type:          "METRIC_DEVIATION",
					Severity:      a.getAnomalySeverity(deviation, historical),
					Resource:      resource.ID,
					Metric:        metricName,
					Value:         metricValue,
					ExpectedValue: historical,
					Deviation:     deviation,
					Description:   fmt.Sprintf("Unusual %s detected: %.2f (expected: %.2f)", metricName, metricValue, historical),
					DetectedAt:    time.Now(),
				})
			}
		}
	}

	return anomalies
}

func (a *Analyzer) analyzeMetrics(ctx context.Context, resources []core.Resource, options AnalysisOptions) map[string]MetricAnalysis {
	metricsMap := make(map[string]MetricAnalysis)

	metricNames := options.Metrics
	if len(metricNames) == 0 {
		metricNames = []string{"cpu", "memory", "disk", "network", "cost"}
	}

	for _, metricName := range metricNames {
		values := []float64{}
		for _, resource := range resources {
			metrics, err := a.provider.GetResourceMetrics(ctx, resource.ID, resource.Type)
			if err != nil {
				continue
			}

			if value, ok := metrics[metricName].(float64); ok {
				values = append(values, value)
			}
		}

		if len(values) > 0 {
			analysis := a.calculateMetricStatistics(metricName, values)

			if options.IncludeForecasts {
				analysis.Forecast = a.generateForecast(values, 7)
			}

			if options.IncludeAnomalies {
				analysis.Anomalies = a.findAnomalyPoints(values)
			}

			metricsMap[metricName] = analysis
		}
	}

	return metricsMap
}

func (a *Analyzer) analyzeTrends(ctx context.Context, resources []core.Resource, options AnalysisOptions) []TrendAnalysis {
	trends := []TrendAnalysis{}

	for _, metricName := range []string{"cpu", "memory", "cost"} {
		dataPoints := []DataPoint{}

		for _, resource := range resources {
			metrics, err := a.provider.GetResourceMetrics(ctx, resource.ID, resource.Type)
			if err != nil {
				continue
			}

			if value, ok := metrics[metricName].(float64); ok {
				dataPoints = append(dataPoints, DataPoint{
					Timestamp: time.Now(),
					Value:     value,
					Label:     resource.Name,
				})
			}
		}

		if len(dataPoints) > 0 {
			trend := a.calculateTrend(metricName, dataPoints)
			trends = append(trends, trend)
		}
	}

	return trends
}

func (a *Analyzer) updateSummary(summary *AnalysisSummary, analysis ResourceAnalysis) {
	summary.TotalResources++
	summary.AnalyzedResources++

	switch analysis.Health {
	case "HEALTHY":
		summary.HealthyResources++
	case "WARNING":
		summary.WarningResources++
	case "CRITICAL", "DEGRADED":
		summary.CriticalResources++
	}

	summary.TotalCost += analysis.Cost.CurrentCost
	summary.OptimizationPotential += analysis.Cost.SavingsPotential

	if summary.HealthyResources > summary.CriticalResources*2 {
		summary.OverallHealth = "GOOD"
	} else if summary.CriticalResources > summary.HealthyResources {
		summary.OverallHealth = "CRITICAL"
	} else {
		summary.OverallHealth = "WARNING"
	}
}

func (a *Analyzer) generateRecommendations(results *AnalysisResults) []AnalysisRecommendation {
	recommendations := []AnalysisRecommendation{}

	if results.Summary.OptimizationPotential > 1000 {
		recommendations = append(recommendations, AnalysisRecommendation{
			ID:          "cost-opt-001",
			Category:    "COST",
			Priority:    "HIGH",
			Title:       "Significant Cost Optimization Opportunity",
			Description: fmt.Sprintf("You can save $%.2f by implementing resource optimization", results.Summary.OptimizationPotential),
			Impact: ImpactAssessment{
				Cost:         "HIGH",
				Performance:  "NONE",
				Reliability:  "NONE",
				Security:     "NONE",
				OverallScore: 8.5,
			},
			EstimatedSavings: results.Summary.OptimizationPotential,
			Confidence:       0.85,
		})
	}

	underutilized := 0
	overutilized := 0
	for _, resource := range results.Resources {
		if resource.Utilization.Efficiency == "UNDERUTILIZED" {
			underutilized++
		} else if resource.Utilization.Efficiency == "OVERUTILIZED" {
			overutilized++
		}
	}

	if underutilized > len(results.Resources)/4 {
		recommendations = append(recommendations, AnalysisRecommendation{
			ID:          "rightsize-001",
			Category:    "OPTIMIZATION",
			Priority:    "MEDIUM",
			Title:       "Multiple Underutilized Resources Detected",
			Description: fmt.Sprintf("%d resources are underutilized and can be rightsized", underutilized),
			Impact: ImpactAssessment{
				Cost:         "HIGH",
				Performance:  "LOW",
				Reliability:  "NONE",
				Security:     "NONE",
				OverallScore: 7.0,
			},
			Confidence: 0.75,
		})
	}

	if overutilized > 0 {
		recommendations = append(recommendations, AnalysisRecommendation{
			ID:          "scale-001",
			Category:    "PERFORMANCE",
			Priority:    "HIGH",
			Title:       "Resources Require Scaling",
			Description: fmt.Sprintf("%d resources are overutilized and need scaling", overutilized),
			Impact: ImpactAssessment{
				Cost:         "MEDIUM",
				Performance:  "HIGH",
				Reliability:  "HIGH",
				Security:     "LOW",
				OverallScore: 8.0,
			},
			Implementation: ImplementationGuide{
				Steps: []string{
					"Identify overutilized resources",
					"Determine appropriate scaling strategy",
					"Implement auto-scaling policies",
					"Monitor performance improvements",
				},
				Complexity: "MEDIUM",
				Duration:   "2-4 hours",
				Risk:       "LOW",
				Automation: true,
			},
			Confidence: 0.90,
		})
	}

	return recommendations
}

func (a *Analyzer) generateInsights(results *AnalysisResults) []Insight {
	insights := []Insight{}

	if len(results.Anomalies) > 5 {
		insights = append(insights, Insight{
			ID:          "insight-001",
			Type:        "ANOMALY_PATTERN",
			Category:    "MONITORING",
			Title:       "Unusual Activity Pattern Detected",
			Description: fmt.Sprintf("Detected %d anomalies across resources", len(results.Anomalies)),
			Evidence:    a.getAnomalyEvidence(results.Anomalies),
			Confidence:  0.8,
			Impact:      "MEDIUM",
			Action:      "Review anomalies and investigate root causes",
			Timestamp:   time.Now(),
		})
	}

	costTrend := a.analyzeCostTrend(results)
	if costTrend > 20 {
		insights = append(insights, Insight{
			ID:          "insight-002",
			Type:        "COST_TREND",
			Category:    "FINANCIAL",
			Title:       "Significant Cost Increase Detected",
			Description: fmt.Sprintf("Costs have increased by %.1f%% recently", costTrend),
			Evidence:    []string{"Historical cost analysis", "Resource growth patterns"},
			Confidence:  0.9,
			Impact:      "HIGH",
			Action:      "Review recent resource deployments and implement cost controls",
			Timestamp:   time.Now(),
		})
	}

	return insights
}

func (a *Analyzer) calculateMetricStatistics(name string, values []float64) MetricAnalysis {
	if len(values) == 0 {
		return MetricAnalysis{Name: name}
	}

	sort.Float64s(values)

	sum := 0.0
	for _, v := range values {
		sum += v
	}
	average := sum / float64(len(values))

	variance := 0.0
	for _, v := range values {
		variance += (v - average) * (v - average)
	}
	stdDev := 0.0
	if len(values) > 1 {
		stdDev = variance / float64(len(values)-1)
	}

	percentiles := make(map[int]float64)
	percentiles[50] = values[len(values)/2]
	percentiles[95] = values[int(float64(len(values))*0.95)]
	percentiles[99] = values[int(float64(len(values))*0.99)]

	return MetricAnalysis{
		Name:        name,
		Value:       values[len(values)-1],
		Average:     average,
		Min:         values[0],
		Max:         values[len(values)-1],
		StdDev:      stdDev,
		Percentiles: percentiles,
		Trend: TrendInfo{
			Direction:   a.getTrendDirection(values),
			Confidence:  0.75,
			Description: "Based on recent data points",
		},
	}
}

func (a *Analyzer) calculateTrend(metricName string, dataPoints []DataPoint) TrendAnalysis {
	if len(dataPoints) < 2 {
		return TrendAnalysis{Metric: metricName}
	}

	sort.Slice(dataPoints, func(i, j int) bool {
		return dataPoints[i].Timestamp.Before(dataPoints[j].Timestamp)
	})

	firstValue := dataPoints[0].Value
	lastValue := dataPoints[len(dataPoints)-1].Value
	change := lastValue - firstValue
	percentChange := (change / firstValue) * 100

	direction := "STABLE"
	if percentChange > 10 {
		direction = "INCREASING"
	} else if percentChange < -10 {
		direction = "DECREASING"
	}

	significance := "LOW"
	if percentChange > 50 || percentChange < -50 {
		significance = "HIGH"
	} else if percentChange > 25 || percentChange < -25 {
		significance = "MEDIUM"
	}

	return TrendAnalysis{
		Metric:       metricName,
		Period:       "30d",
		Direction:    direction,
		Magnitude:    percentChange,
		Confidence:   0.8,
		DataPoints:   dataPoints,
		Significance: significance,
	}
}

func (a *Analyzer) generateForecast(values []float64, days int) []ForecastPoint {
	if len(values) < 3 {
		return []ForecastPoint{}
	}

	average := 0.0
	for _, v := range values {
		average += v
	}
	average /= float64(len(values))

	trend := (values[len(values)-1] - values[0]) / float64(len(values))

	forecast := []ForecastPoint{}
	for i := 1; i <= days; i++ {
		predictedValue := average + (trend * float64(i))
		forecast = append(forecast, ForecastPoint{
			Timestamp:       time.Now().AddDate(0, 0, i),
			PredictedValue:  predictedValue,
			UpperBound:      predictedValue * 1.2,
			LowerBound:      predictedValue * 0.8,
			ConfidenceLevel: 0.7 - (float64(i) * 0.05),
		})
	}

	return forecast
}

func (a *Analyzer) findAnomalyPoints(values []float64) []AnomalyPoint {
	if len(values) < 3 {
		return []AnomalyPoint{}
	}

	anomalies := []AnomalyPoint{}

	average := 0.0
	for _, v := range values {
		average += v
	}
	average /= float64(len(values))

	for i, value := range values {
		deviation := value - average
		if deviation > average*0.5 || deviation < -average*0.5 {
			anomalies = append(anomalies, AnomalyPoint{
				Timestamp:   time.Now().Add(time.Duration(i) * time.Hour),
				Value:       value,
				Expected:    average,
				Deviation:   deviation,
				Severity:    a.getAnomalySeverity(deviation, average),
				Description: fmt.Sprintf("Value deviates %.1f%% from average", (deviation/average)*100),
			})
		}
	}

	return anomalies
}

func (a *Analyzer) getHistoricalAverage(ctx context.Context, resourceID, metricName string) float64 {
	return 50.0
}

func (a *Analyzer) getPerformanceStatus(value, threshold float64) string {
	if value > threshold {
		return "CRITICAL"
	} else if value > threshold*0.8 {
		return "WARNING"
	}
	return "NORMAL"
}

func (a *Analyzer) getAnomalySeverity(deviation, baseline float64) string {
	percentage := (deviation / baseline) * 100
	if percentage > 100 || percentage < -100 {
		return "CRITICAL"
	} else if percentage > 50 || percentage < -50 {
		return "HIGH"
	} else if percentage > 25 || percentage < -25 {
		return "MEDIUM"
	}
	return "LOW"
}

func (a *Analyzer) getTrendDirection(values []float64) string {
	if len(values) < 2 {
		return "UNKNOWN"
	}

	increasing := 0
	decreasing := 0

	for i := 1; i < len(values); i++ {
		if values[i] > values[i-1] {
			increasing++
		} else if values[i] < values[i-1] {
			decreasing++
		}
	}

	if increasing > decreasing*2 {
		return "INCREASING"
	} else if decreasing > increasing*2 {
		return "DECREASING"
	}
	return "STABLE"
}

func (a *Analyzer) getAnomalyEvidence(anomalies []Anomaly) []string {
	evidence := []string{}
	for i, anomaly := range anomalies {
		if i >= 3 {
			break
		}
		evidence = append(evidence,
			fmt.Sprintf("%s: %s deviation of %.2f", anomaly.Resource, anomaly.Metric, anomaly.Deviation))
	}
	return evidence
}

func (a *Analyzer) analyzeCostTrend(results *AnalysisResults) float64 {
	if len(results.Resources) == 0 {
		return 0
	}

	totalCurrent := 0.0
	totalProjected := 0.0

	for _, resource := range results.Resources {
		totalCurrent += resource.Cost.CurrentCost
		totalProjected += resource.Cost.ProjectedCost
	}

	if totalCurrent == 0 {
		return 0
	}

	return ((totalProjected - totalCurrent) / totalCurrent) * 100
}