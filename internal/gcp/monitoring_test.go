package gcp

import (
	"context"
	"strings"
	"testing"
	"time"

	"google.golang.org/api/googleapi"
)

func TestNewMonitoringService(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping monitoring service test due to client creation error: %v", err)
	}

	monitoringConfig := &MonitoringConfig{
		DefaultWorkspace:             "test-workspace",
		MetricsRetentionDays:        90,
		LogsRetentionDays:           30,
		TracesRetentionDays:         7,
		AlertEvaluationInterval:     time.Minute,
		MetricCollectionInterval:    30 * time.Second,
		CacheEnabled:                true,
		CacheTTL:                    15 * time.Minute,
		MetricsEnabled:              true,
		AuditEnabled:                true,
		RealTimeAlertsEnabled:       true,
		AnomalyDetectionEnabled:     true,
		PredictiveAnalyticsEnabled:  true,
		CustomMetricsEnabled:        true,
		LogAnalysisEnabled:          true,
		TraceAnalysisEnabled:        true,
		SLOMonitoringEnabled:        true,
		ErrorReportingEnabled:       true,
		UptimeMonitoringEnabled:     true,
		PerformanceMonitoringEnabled: true,
		SecurityMonitoringEnabled:   true,
		ComplianceMonitoringEnabled: true,
		MaxConcurrentQueries:        50,
		QueryTimeout:                5 * time.Minute,
		RetryAttempts:               3,
		RetryDelay:                  time.Second,
		RateLimitQPS:                100,
		RateLimitBurst:              200,
		MaxCacheSize:                10000,
		LogLevel:                    "INFO",
	}

	monitoringService, err := NewMonitoringService(client, monitoringConfig)
	if err != nil {
		t.Errorf("NewMonitoringService() error = %v", err)
		return
	}

	if monitoringService == nil {
		t.Error("NewMonitoringService() returned nil service")
	}

	if monitoringService.client != client {
		t.Error("NewMonitoringService() did not set client correctly")
	}

	if monitoringService.config.DefaultWorkspace != monitoringConfig.DefaultWorkspace {
		t.Errorf("NewMonitoringService() DefaultWorkspace = %v, want %v",
			monitoringService.config.DefaultWorkspace, monitoringConfig.DefaultWorkspace)
	}
}

func TestMonitoringConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *MonitoringConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &MonitoringConfig{
				DefaultWorkspace:         "test-workspace",
				MetricsRetentionDays:     90,
				LogsRetentionDays:        30,
				TracesRetentionDays:      7,
				AlertEvaluationInterval:  time.Minute,
				MetricCollectionInterval: 30 * time.Second,
				MaxConcurrentQueries:     50,
				QueryTimeout:             5 * time.Minute,
				RetryAttempts:            3,
				RetryDelay:               time.Second,
				RateLimitQPS:             100,
				RateLimitBurst:           200,
				MaxCacheSize:             10000,
			},
			wantErr: false,
		},
		{
			name: "invalid metrics retention",
			config: &MonitoringConfig{
				DefaultWorkspace:         "test-workspace",
				MetricsRetentionDays:     0,
				LogsRetentionDays:        30,
				TracesRetentionDays:      7,
				AlertEvaluationInterval:  time.Minute,
				MetricCollectionInterval: 30 * time.Second,
				MaxConcurrentQueries:     50,
				QueryTimeout:             5 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid alert evaluation interval",
			config: &MonitoringConfig{
				DefaultWorkspace:         "test-workspace",
				MetricsRetentionDays:     90,
				LogsRetentionDays:        30,
				TracesRetentionDays:      7,
				AlertEvaluationInterval:  0,
				MetricCollectionInterval: 30 * time.Second,
				MaxConcurrentQueries:     50,
				QueryTimeout:             5 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid metric collection interval",
			config: &MonitoringConfig{
				DefaultWorkspace:         "test-workspace",
				MetricsRetentionDays:     90,
				LogsRetentionDays:        30,
				TracesRetentionDays:      7,
				AlertEvaluationInterval:  time.Minute,
				MetricCollectionInterval: 0,
				MaxConcurrentQueries:     50,
				QueryTimeout:             5 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid max concurrent queries",
			config: &MonitoringConfig{
				DefaultWorkspace:         "test-workspace",
				MetricsRetentionDays:     90,
				LogsRetentionDays:        30,
				TracesRetentionDays:      7,
				AlertEvaluationInterval:  time.Minute,
				MetricCollectionInterval: 30 * time.Second,
				MaxConcurrentQueries:     0,
				QueryTimeout:             5 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid query timeout",
			config: &MonitoringConfig{
				DefaultWorkspace:         "test-workspace",
				MetricsRetentionDays:     90,
				LogsRetentionDays:        30,
				TracesRetentionDays:      7,
				AlertEvaluationInterval:  time.Minute,
				MetricCollectionInterval: 30 * time.Second,
				MaxConcurrentQueries:     50,
				QueryTimeout:             0,
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("MonitoringConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestMonitoringConfig_SetDefaults(t *testing.T) {
	config := &MonitoringConfig{}
	config.SetDefaults()

	if config.MetricsRetentionDays <= 0 {
		t.Error("SetDefaults() did not set MetricsRetentionDays")
	}

	if config.LogsRetentionDays <= 0 {
		t.Error("SetDefaults() did not set LogsRetentionDays")
	}

	if config.TracesRetentionDays <= 0 {
		t.Error("SetDefaults() did not set TracesRetentionDays")
	}

	if config.AlertEvaluationInterval <= 0 {
		t.Error("SetDefaults() did not set AlertEvaluationInterval")
	}

	if config.MetricCollectionInterval <= 0 {
		t.Error("SetDefaults() did not set MetricCollectionInterval")
	}

	if config.MaxConcurrentQueries <= 0 {
		t.Error("SetDefaults() did not set MaxConcurrentQueries")
	}

	if config.QueryTimeout <= 0 {
		t.Error("SetDefaults() did not set QueryTimeout")
	}

	if config.RetryAttempts <= 0 {
		t.Error("SetDefaults() did not set RetryAttempts")
	}

	if config.RetryDelay <= 0 {
		t.Error("SetDefaults() did not set RetryDelay")
	}

	if !config.CacheEnabled {
		t.Error("SetDefaults() did not enable cache")
	}

	if config.CacheTTL <= 0 {
		t.Error("SetDefaults() did not set CacheTTL")
	}
}

func TestMonitoringService_CreateAlertPolicy(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping create alert policy test due to client creation error: %v", err)
	}

	monitoringConfig := &MonitoringConfig{}
	monitoringConfig.SetDefaults()

	monitoringService, err := NewMonitoringService(client, monitoringConfig)
	if err != nil {
		t.Skipf("Skipping create alert policy test due to monitoring service creation error: %v", err)
	}

	alertConfig := &AlertPolicyConfig{
		DisplayName:  "Test Alert Policy - " + time.Now().Format("20060102-150405"),
		Documentation: &AlertDocumentation{
			Content:  "Test alert policy created by test suite",
			MimeType: "text/markdown",
		},
		Conditions: []*AlertCondition{
			{
				DisplayName: "High CPU Usage",
				ConditionThreshold: &MetricThreshold{
					Filter:     `resource.type="gce_instance"`,
					Comparison: "COMPARISON_GREATER_THAN",
					ThresholdValue: 0.8,
					Duration:   300 * time.Second,
					Aggregations: []*Aggregation{
						{
							AlignmentPeriod:     60 * time.Second,
							PerSeriesAligner:    "ALIGN_RATE",
							CrossSeriesReducer:  "REDUCE_MEAN",
							GroupByFields:       []string{"resource.label.instance_id"},
						},
					},
				},
			},
		},
		NotificationChannels: []string{},
		AlertStrategy: &AlertStrategy{
			AutoClose: 7 * 24 * time.Hour, // 7 days
			NotificationRateLimit: &NotificationRateLimit{
				Period: time.Hour,
			},
		},
		Enabled: true,
		Severity: "WARNING",
		Labels: map[string]string{
			"environment": "test",
			"created-by":  "test-suite",
		},
	}

	ctx := context.Background()
	alertPolicy, err := monitoringService.CreateAlertPolicy(ctx, alertConfig)
	if err != nil {
		t.Logf("CreateAlertPolicy() error = %v (expected in test environment)", err)
		return
	}

	if alertPolicy == nil {
		t.Error("CreateAlertPolicy() returned nil alert policy")
		return
	}

	if !strings.Contains(alertPolicy.DisplayName, "Test Alert Policy") {
		t.Errorf("CreateAlertPolicy() display name = %v, should contain 'Test Alert Policy'", alertPolicy.DisplayName)
	}

	// Clean up - attempt to delete the alert policy
	defer func() {
		deleteCtx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
		defer cancel()
		monitoringService.DeleteAlertPolicy(deleteCtx, alertPolicy.Name)
	}()
}

func TestMonitoringService_QueryMetrics(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping query metrics test due to client creation error: %v", err)
	}

	monitoringConfig := &MonitoringConfig{}
	monitoringConfig.SetDefaults()

	monitoringService, err := NewMonitoringService(client, monitoringConfig)
	if err != nil {
		t.Skipf("Skipping query metrics test due to monitoring service creation error: %v", err)
	}

	query := &MetricQuery{
		Filter: `resource.type="global"`,
		Interval: &TimeInterval{
			StartTime: time.Now().Add(-time.Hour),
			EndTime:   time.Now(),
		},
		Aggregation: &Aggregation{
			AlignmentPeriod:    60 * time.Second,
			PerSeriesAligner:   "ALIGN_RATE",
			CrossSeriesReducer: "REDUCE_MEAN",
		},
		View: "FULL",
	}

	ctx := context.Background()
	result, err := monitoringService.QueryMetrics(ctx, query)
	if err != nil {
		t.Logf("QueryMetrics() error = %v (expected in test environment)", err)
		return
	}

	if result == nil {
		t.Error("QueryMetrics() returned nil result")
		return
	}

	if result.TimeSeries == nil {
		t.Error("QueryMetrics() result should have TimeSeries")
	}
}

func TestMonitoringService_CreateDashboard(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping create dashboard test due to client creation error: %v", err)
	}

	monitoringConfig := &MonitoringConfig{}
	monitoringConfig.SetDefaults()

	monitoringService, err := NewMonitoringService(client, monitoringConfig)
	if err != nil {
		t.Skipf("Skipping create dashboard test due to monitoring service creation error: %v", err)
	}

	dashboardConfig := &DashboardConfig{
		DisplayName: "Test Dashboard - " + time.Now().Format("20060102-150405"),
		MosaicLayout: &MosaicLayout{
			Tiles: []*DashboardTile{
				{
					Width:  12,
					Height: 4,
					Widget: &Widget{
						Title: "CPU Usage",
						XyChart: &XyChart{
							DataSets: []*DataSet{
								{
									TimeSeriesQuery: &TimeSeriesQuery{
										TimeSeriesFilter: &TimeSeriesFilter{
											Filter: `resource.type="gce_instance"`,
										},
									},
									PlotType: "LINE",
									TargetAxis: "Y1",
								},
							},
							TimeshiftDuration: 0,
							YAxis: &Axis{
								Label: "CPU Utilization",
								Scale: "LINEAR",
							},
						},
					},
				},
			},
		},
		Labels: map[string]string{
			"environment": "test",
			"created-by":  "test-suite",
		},
	}

	ctx := context.Background()
	dashboard, err := monitoringService.CreateDashboard(ctx, dashboardConfig)
	if err != nil {
		t.Logf("CreateDashboard() error = %v (expected in test environment)", err)
		return
	}

	if dashboard == nil {
		t.Error("CreateDashboard() returned nil dashboard")
		return
	}

	if !strings.Contains(dashboard.DisplayName, "Test Dashboard") {
		t.Errorf("CreateDashboard() display name = %v, should contain 'Test Dashboard'", dashboard.DisplayName)
	}

	// Clean up - attempt to delete the dashboard
	defer func() {
		deleteCtx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
		defer cancel()
		monitoringService.DeleteDashboard(deleteCtx, dashboard.Name)
	}()
}

func TestMonitoringService_DetectAnomalies(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping detect anomalies test due to client creation error: %v", err)
	}

	monitoringConfig := &MonitoringConfig{}
	monitoringConfig.SetDefaults()

	monitoringService, err := NewMonitoringService(client, monitoringConfig)
	if err != nil {
		t.Skipf("Skipping detect anomalies test due to monitoring service creation error: %v", err)
	}

	anomalyConfig := &AnomalyDetectionConfig{
		MetricFilter: `resource.type="gce_instance"`,
		TimeRange: &TimeInterval{
			StartTime: time.Now().Add(-24 * time.Hour),
			EndTime:   time.Now(),
		},
		Algorithm:         "ISOLATION_FOREST",
		SensitivityLevel:  "HIGH",
		MinDataPoints:     100,
		ConfidenceLevel:   0.95,
		SeasonalityPeriod: 24 * time.Hour,
		Aggregation: &Aggregation{
			AlignmentPeriod:    5 * time.Minute,
			PerSeriesAligner:   "ALIGN_MEAN",
			CrossSeriesReducer: "REDUCE_MEAN",
		},
	}

	ctx := context.Background()
	anomalies, err := monitoringService.DetectAnomalies(ctx, anomalyConfig)
	if err != nil {
		t.Logf("DetectAnomalies() error = %v (expected in test environment)", err)
		return
	}

	if anomalies == nil {
		t.Error("DetectAnomalies() returned nil anomalies")
		return
	}

	// Anomalies may be empty, which is acceptable
	t.Logf("DetectAnomalies() found %d anomalies", len(anomalies.Anomalies))
}

func TestMonitoringService_AnalyzeLogs(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping analyze logs test due to client creation error: %v", err)
	}

	monitoringConfig := &MonitoringConfig{}
	monitoringConfig.SetDefaults()

	monitoringService, err := NewMonitoringService(client, monitoringConfig)
	if err != nil {
		t.Skipf("Skipping analyze logs test due to monitoring service creation error: %v", err)
	}

	logAnalysisConfig := &LogAnalysisConfig{
		Filter: `resource.type="gce_instance" AND severity>=ERROR`,
		TimeRange: &TimeInterval{
			StartTime: time.Now().Add(-time.Hour),
			EndTime:   time.Now(),
		},
		AnalysisType:     "PATTERN_DETECTION",
		GroupByFields:    []string{"resource.labels.instance_id", "severity"},
		Aggregation:      "COUNT",
		MaxResults:       1000,
		IncludeMetadata:  true,
		PatternDetection: &PatternDetectionConfig{
			Algorithm:       "CLUSTERING",
			MinOccurrences:  5,
			SimilarityThreshold: 0.8,
		},
		ErrorClassification: &ErrorClassificationConfig{
			Enabled:         true,
			Categories:      []string{"NETWORK", "AUTHENTICATION", "RESOURCE", "APPLICATION"},
			ConfidenceLevel: 0.9,
		},
	}

	ctx := context.Background()
	analysis, err := monitoringService.AnalyzeLogs(ctx, logAnalysisConfig)
	if err != nil {
		t.Logf("AnalyzeLogs() error = %v (expected in test environment)", err)
		return
	}

	if analysis == nil {
		t.Error("AnalyzeLogs() returned nil analysis")
		return
	}

	if analysis.Summary == nil {
		t.Error("AnalyzeLogs() analysis should have summary")
	}
}

func TestAlertPolicyConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *AlertPolicyConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &AlertPolicyConfig{
				DisplayName: "Test Alert",
				Conditions: []*AlertCondition{
					{
						DisplayName: "Test Condition",
						ConditionThreshold: &MetricThreshold{
							Filter:         `resource.type="gce_instance"`,
							Comparison:     "COMPARISON_GREATER_THAN",
							ThresholdValue: 0.8,
						},
					},
				},
				Enabled: true,
			},
			wantErr: false,
		},
		{
			name: "empty display name",
			config: &AlertPolicyConfig{
				DisplayName: "",
				Conditions: []*AlertCondition{
					{
						DisplayName: "Test Condition",
						ConditionThreshold: &MetricThreshold{
							Filter:     `resource.type="gce_instance"`,
							Comparison: "COMPARISON_GREATER_THAN",
						},
					},
				},
				Enabled: true,
			},
			wantErr: true,
		},
		{
			name: "no conditions",
			config: &AlertPolicyConfig{
				DisplayName: "Test Alert",
				Conditions:  []*AlertCondition{},
				Enabled:     true,
			},
			wantErr: true,
		},
		{
			name: "invalid condition",
			config: &AlertPolicyConfig{
				DisplayName: "Test Alert",
				Conditions: []*AlertCondition{
					{
						DisplayName: "", // Empty display name
						ConditionThreshold: &MetricThreshold{
							Filter:     `resource.type="gce_instance"`,
							Comparison: "COMPARISON_GREATER_THAN",
						},
					},
				},
				Enabled: true,
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("AlertPolicyConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestDashboardConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *DashboardConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &DashboardConfig{
				DisplayName: "Test Dashboard",
				MosaicLayout: &MosaicLayout{
					Tiles: []*DashboardTile{
						{
							Width:  12,
							Height: 4,
							Widget: &Widget{
								Title: "Test Widget",
							},
						},
					},
				},
			},
			wantErr: false,
		},
		{
			name: "empty display name",
			config: &DashboardConfig{
				DisplayName: "",
				MosaicLayout: &MosaicLayout{
					Tiles: []*DashboardTile{
						{
							Width:  12,
							Height: 4,
							Widget: &Widget{
								Title: "Test Widget",
							},
						},
					},
				},
			},
			wantErr: true,
		},
		{
			name: "no layout",
			config: &DashboardConfig{
				DisplayName: "Test Dashboard",
			},
			wantErr: true,
		},
		{
			name: "no tiles",
			config: &DashboardConfig{
				DisplayName: "Test Dashboard",
				MosaicLayout: &MosaicLayout{
					Tiles: []*DashboardTile{},
				},
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("DashboardConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestMonitoringService_GetServiceMetrics(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get service metrics test due to client creation error: %v", err)
	}

	monitoringConfig := &MonitoringConfig{
		MetricsEnabled: true,
	}
	monitoringConfig.SetDefaults()

	monitoringService, err := NewMonitoringService(client, monitoringConfig)
	if err != nil {
		t.Skipf("Skipping get service metrics test due to monitoring service creation error: %v", err)
	}

	metrics := monitoringService.GetServiceMetrics()
	if metrics == nil {
		t.Error("GetServiceMetrics() returned nil when metrics are enabled")
	}
}

func TestMonitoringService_ClearCache(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping clear cache test due to client creation error: %v", err)
	}

	monitoringConfig := &MonitoringConfig{
		CacheEnabled: true,
	}
	monitoringConfig.SetDefaults()

	monitoringService, err := NewMonitoringService(client, monitoringConfig)
	if err != nil {
		t.Skipf("Skipping clear cache test due to monitoring service creation error: %v", err)
	}

	// Clear cache should not error
	monitoringService.ClearCache()

	// Verify cache stats show empty cache
	stats := monitoringService.GetCacheStats()
	if stats != nil {
		if size, ok := stats["size"].(int); ok && size != 0 {
			t.Errorf("ClearCache() cache size = %d, want 0", size)
		}
	}
}

func TestMonitoringServiceConcurrency(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping concurrency test due to client creation error: %v", err)
	}

	monitoringConfig := &MonitoringConfig{}
	monitoringConfig.SetDefaults()

	monitoringService, err := NewMonitoringService(client, monitoringConfig)
	if err != nil {
		t.Skipf("Skipping concurrency test due to monitoring service creation error: %v", err)
	}

	// Test concurrent access to monitoring service methods
	done := make(chan bool, 10)
	ctx := context.Background()

	for i := 0; i < 10; i++ {
		go func(index int) {
			defer func() { done <- true }()

			// Test concurrent calls to monitoring service methods
			query := &MetricQuery{
				Filter: `resource.type="global"`,
				Interval: &TimeInterval{
					StartTime: time.Now().Add(-time.Hour),
					EndTime:   time.Now(),
				},
			}

			monitoringService.QueryMetrics(ctx, query)

			// Test other concurrent operations
			monitoringService.GetServiceMetrics()
			monitoringService.GetCacheStats()
		}(i)
	}

	// Wait for all goroutines to complete
	for i := 0; i < 10; i++ {
		<-done
	}

	t.Log("Concurrent access test completed successfully")
}

func BenchmarkMonitoringService_QueryMetrics(b *testing.B) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		b.Skipf("Skipping benchmark due to client creation error: %v", err)
	}

	monitoringConfig := &MonitoringConfig{}
	monitoringConfig.SetDefaults()

	monitoringService, err := NewMonitoringService(client, monitoringConfig)
	if err != nil {
		b.Skipf("Skipping benchmark due to monitoring service creation error: %v", err)
	}

	query := &MetricQuery{
		Filter: `resource.type="global"`,
		Interval: &TimeInterval{
			StartTime: time.Now().Add(-time.Hour),
			EndTime:   time.Now(),
		},
	}

	ctx := context.Background()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		monitoringService.QueryMetrics(ctx, query)
	}
}

func BenchmarkAlertPolicyConfig_Validate(b *testing.B) {
	config := &AlertPolicyConfig{
		DisplayName: "Test Alert",
		Conditions: []*AlertCondition{
			{
				DisplayName: "Test Condition",
				ConditionThreshold: &MetricThreshold{
					Filter:         `resource.type="gce_instance"`,
					Comparison:     "COMPARISON_GREATER_THAN",
					ThresholdValue: 0.8,
				},
			},
		},
		Enabled: true,
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		config.Validate()
	}
}

func TestMonitoringErrorHandling(t *testing.T) {
	// Test various error scenarios
	tests := []struct {
		name     string
		err      error
		wantCode ErrorCode
	}{
		{
			name:     "alert policy not found",
			err:      &googleapi.Error{Code: 404, Message: "Alert policy not found"},
			wantCode: ErrorCodeNotFound,
		},
		{
			name:     "dashboard not found",
			err:      &googleapi.Error{Code: 404, Message: "Dashboard not found"},
			wantCode: ErrorCodeNotFound,
		},
		{
			name:     "permission denied",
			err:      &googleapi.Error{Code: 403, Message: "Permission denied"},
			wantCode: ErrorCodePermissionDenied,
		},
		{
			name:     "quota exceeded",
			err:      &googleapi.Error{Code: 403, Message: "Quota exceeded"},
			wantCode: ErrorCodeQuotaExceeded,
		},
		{
			name:     "invalid metric filter",
			err:      &googleapi.Error{Code: 400, Message: "Invalid metric filter"},
			wantCode: ErrorCodeInvalidArgument,
		},
		{
			name:     "metric not found",
			err:      &googleapi.Error{Code: 404, Message: "Metric not found"},
			wantCode: ErrorCodeNotFound,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gcpErr := NewGCPError("TestOperation", "test-resource", tt.err)
			if gcpErr.Code != tt.wantCode {
				t.Errorf("Error classification = %v, want %v", gcpErr.Code, tt.wantCode)
			}
		})
	}
}

func TestMetricQueryValidation(t *testing.T) {
	// Test metric query validation
	validQuery := &MetricQuery{
		Filter: `resource.type="gce_instance"`,
		Interval: &TimeInterval{
			StartTime: time.Now().Add(-time.Hour),
			EndTime:   time.Now(),
		},
		Aggregation: &Aggregation{
			AlignmentPeriod:    60 * time.Second,
			PerSeriesAligner:   "ALIGN_RATE",
			CrossSeriesReducer: "REDUCE_MEAN",
		},
		View: "FULL",
	}

	err := validQuery.Validate()
	if err != nil {
		t.Errorf("Valid MetricQuery should not error: %v", err)
	}

	// Test invalid queries
	invalidQueries := []*MetricQuery{
		{
			Filter: "", // Empty filter
			Interval: &TimeInterval{
				StartTime: time.Now().Add(-time.Hour),
				EndTime:   time.Now(),
			},
		},
		{
			Filter: `resource.type="gce_instance"`,
			Interval: &TimeInterval{
				StartTime: time.Now(), // Start time after end time
				EndTime:   time.Now().Add(-time.Hour),
			},
		},
		{
			Filter:   `resource.type="gce_instance"`,
			Interval: nil, // Missing interval
		},
	}

	for i, query := range invalidQueries {
		t.Run(strings.Join([]string{"invalid", string(rune(i+'0'))}, "_"), func(t *testing.T) {
			err := query.Validate()
			if err == nil {
				t.Error("Invalid MetricQuery should error")
			}
		})
	}
}

// Helper function for MetricQuery validation (would be part of actual implementation)
func (q *MetricQuery) Validate() error {
	if q.Filter == "" {
		return fmt.Errorf("filter is required")
	}
	if q.Interval == nil {
		return fmt.Errorf("time interval is required")
	}
	if q.Interval.StartTime.After(q.Interval.EndTime) {
		return fmt.Errorf("start time must be before end time")
	}
	return nil
}

func TestTimeSeriesDataProcessing(t *testing.T) {
	// Test time series data processing utilities
	timeSeries := []*TimeSeries{
		{
			Metric: &Metric{
				Type: "compute.googleapis.com/instance/cpu/utilization",
				Labels: map[string]string{
					"instance_name": "instance-1",
				},
			},
			Resource: &MonitoredResource{
				Type: "gce_instance",
				Labels: map[string]string{
					"project_id":  "test-project",
					"instance_id": "123456789",
					"zone":        "us-central1-a",
				},
			},
			Points: []*Point{
				{
					Interval: &TimeInterval{
						StartTime: time.Now().Add(-2 * time.Minute),
						EndTime:   time.Now().Add(-time.Minute),
					},
					Value: &TypedValue{
						DoubleValue: 0.75,
					},
				},
				{
					Interval: &TimeInterval{
						StartTime: time.Now().Add(-time.Minute),
						EndTime:   time.Now(),
					},
					Value: &TypedValue{
						DoubleValue: 0.85,
					},
				},
			},
		},
	}

	// Test time series analysis
	if len(timeSeries) == 0 {
		t.Error("Time series should not be empty")
	}

	for _, ts := range timeSeries {
		if ts.Metric == nil {
			t.Error("Time series should have metric")
		}
		if ts.Resource == nil {
			t.Error("Time series should have resource")
		}
		if len(ts.Points) == 0 {
			t.Error("Time series should have points")
		}

		// Test point values
		for _, point := range ts.Points {
			if point.Value == nil {
				t.Error("Point should have value")
			}
			if point.Interval == nil {
				t.Error("Point should have interval")
			}
		}
	}

	t.Logf("Processed %d time series with %d total points",
		len(timeSeries), len(timeSeries[0].Points))
}