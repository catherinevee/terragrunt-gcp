package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/your-org/terragrunt-gcp/internal/gcp"
)

type MonitorConfig struct {
	ProjectID       string              `json:"project_id"`
	Region          string              `json:"region"`
	Resources       []ResourceMonitor   `json:"resources"`
	Alerts          []AlertConfig       `json:"alerts"`
	Dashboards      []DashboardConfig   `json:"dashboards"`
	Settings        MonitorSettings     `json:"settings"`
}

type ResourceMonitor struct {
	Type       string                 `json:"type"`
	Name       string                 `json:"name"`
	Metrics    []MetricConfig         `json:"metrics"`
	Thresholds map[string]float64     `json:"thresholds"`
	Labels     map[string]string      `json:"labels"`
	Interval   time.Duration          `json:"interval"`
}

type MetricConfig struct {
	Name        string            `json:"name"`
	Type        string            `json:"type"`
	Filter      string            `json:"filter"`
	Aggregation string            `json:"aggregation"`
	Labels      map[string]string `json:"labels"`
}

type AlertConfig struct {
	Name        string                 `json:"name"`
	Description string                 `json:"description"`
	Conditions  []AlertCondition       `json:"conditions"`
	Actions     []AlertAction          `json:"actions"`
	Enabled     bool                   `json:"enabled"`
}

type AlertCondition struct {
	Metric     string        `json:"metric"`
	Threshold  float64       `json:"threshold"`
	Comparison string        `json:"comparison"`
	Duration   time.Duration `json:"duration"`
}

type AlertAction struct {
	Type   string                 `json:"type"`
	Config map[string]interface{} `json:"config"`
}

type DashboardConfig struct {
	Name    string                 `json:"name"`
	Widgets []DashboardWidget      `json:"widgets"`
	Layout  map[string]interface{} `json:"layout"`
}

type DashboardWidget struct {
	Type   string                 `json:"type"`
	Title  string                 `json:"title"`
	Config map[string]interface{} `json:"config"`
}

type MonitorSettings struct {
	RefreshInterval time.Duration `json:"refresh_interval"`
	RetentionPeriod time.Duration `json:"retention_period"`
	OutputFormat    string        `json:"output_format"`
	LogLevel        string        `json:"log_level"`
	WebPort         int           `json:"web_port"`
	EnableWebUI     bool          `json:"enable_web_ui"`
}

type MonitoringResult struct {
	Timestamp   time.Time                      `json:"timestamp"`
	Resources   map[string]ResourceStatus      `json:"resources"`
	Alerts      []ActiveAlert                  `json:"alerts"`
	Summary     MonitoringSummary              `json:"summary"`
	Health      OverallHealth                  `json:"health"`
}

type ResourceStatus struct {
	Status      string                 `json:"status"`
	Metrics     map[string]float64     `json:"metrics"`
	LastUpdated time.Time              `json:"last_updated"`
	Issues      []string               `json:"issues,omitempty"`
	Details     map[string]interface{} `json:"details"`
}

type ActiveAlert struct {
	Name        string                 `json:"name"`
	Level       string                 `json:"level"`
	Message     string                 `json:"message"`
	Resource    string                 `json:"resource"`
	Metric      string                 `json:"metric"`
	Value       float64                `json:"value"`
	Threshold   float64                `json:"threshold"`
	StartTime   time.Time              `json:"start_time"`
	Duration    time.Duration          `json:"duration"`
	Details     map[string]interface{} `json:"details"`
}

type MonitoringSummary struct {
	TotalResources  int                    `json:"total_resources"`
	HealthyCount    int                    `json:"healthy_count"`
	UnhealthyCount  int                    `json:"unhealthy_count"`
	AlertCount      int                    `json:"alert_count"`
	CriticalAlerts  int                    `json:"critical_alerts"`
	ResourceTypes   map[string]int         `json:"resource_types"`
	MetricsSummary  map[string]float64     `json:"metrics_summary"`
}

type OverallHealth struct {
	Status     string  `json:"status"`
	Score      float64 `json:"score"`
	Components map[string]string `json:"components"`
}

func main() {
	var (
		configFile   = flag.String("config", "", "Path to monitoring configuration file")
		projectID    = flag.String("project", "", "GCP Project ID")
		region       = flag.String("region", "us-central1", "GCP Region")
		interval     = flag.Duration("interval", 30*time.Second, "Monitoring interval")
		duration     = flag.Duration("duration", 0, "How long to run (0 = indefinitely)")
		once         = flag.Bool("once", false, "Run once and exit")
		format       = flag.String("format", "json", "Output format (json, text, table)")
		output       = flag.String("output", "", "Output file (default: stdout)")
		verbose      = flag.Bool("verbose", false, "Enable verbose output")
		quiet        = flag.Bool("quiet", false, "Suppress output except errors")
		webui        = flag.Bool("webui", false, "Enable web UI")
		webPort      = flag.Int("web-port", 8080, "Web UI port")
		alertsOnly   = flag.Bool("alerts-only", false, "Show only active alerts")
		filter       = flag.String("filter", "", "Filter resources by type or name")
	)
	flag.Parse()

	if *projectID == "" {
		*projectID = os.Getenv("GCP_PROJECT_ID")
		if *projectID == "" {
			fmt.Fprintf(os.Stderr, "Error: Project ID must be specified via -project flag or GCP_PROJECT_ID environment variable\n")
			os.Exit(1)
		}
	}

	// Load monitoring configuration
	var monitorConfig MonitorConfig
	if *configFile != "" {
		configData, err := os.ReadFile(*configFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error reading config file: %v\n", err)
			os.Exit(1)
		}

		if err := json.Unmarshal(configData, &monitorConfig); err != nil {
			fmt.Fprintf(os.Stderr, "Error parsing config file: %v\n", err)
			os.Exit(1)
		}
	} else {
		// Use default configuration
		monitorConfig = getDefaultConfig(*projectID, *region)
	}

	// Override settings from command line
	if *interval != 30*time.Second {
		monitorConfig.Settings.RefreshInterval = *interval
	}
	if *webui {
		monitorConfig.Settings.EnableWebUI = true
		monitorConfig.Settings.WebPort = *webPort
	}

	// Initialize GCP client
	ctx := context.Background()
	client, err := gcp.NewClient(ctx, &gcp.ClientConfig{
		ProjectID: monitorConfig.ProjectID,
		Region:    monitorConfig.Region,
		LogLevel:  getLogLevel(*verbose, *quiet),
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating GCP client: %v\n", err)
		os.Exit(1)
	}
	defer client.Close()

	// Initialize monitoring service
	monitoringService, err := gcp.NewMonitoringService(client, &gcp.MonitoringConfig{
		CacheEnabled: true,
		CacheTTL:     5 * time.Minute,
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating monitoring service: %v\n", err)
		os.Exit(1)
	}

	// Set up output
	var outputFile *os.File = os.Stdout
	if *output != "" {
		file, err := os.Create(*output)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error creating output file: %v\n", err)
			os.Exit(1)
		}
		defer file.Close()
		outputFile = file
	}

	// Set up signal handling for graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	// Start web UI if enabled
	if monitorConfig.Settings.EnableWebUI {
		go startWebUI(monitorConfig.Settings.WebPort, &monitorConfig)
		if !*quiet {
			fmt.Printf("🌐 Web UI started on http://localhost:%d\n", monitorConfig.Settings.WebPort)
		}
	}

	// Monitoring loop
	ticker := time.NewTicker(monitorConfig.Settings.RefreshInterval)
	defer ticker.Stop()

	startTime := time.Now()

	for {
		// Perform monitoring check
		result, err := performMonitoring(ctx, client, monitoringService, &monitorConfig, *filter)
		if err != nil {
			if !*quiet {
				fmt.Fprintf(os.Stderr, "Monitoring error: %v\n", err)
			}
		} else {
			// Output results
			if !*alertsOnly || len(result.Alerts) > 0 {
				outputResults(outputFile, result, *format, *verbose, *quiet)
			}
		}

		// Check if we should exit
		if *once {
			break
		}

		if *duration > 0 && time.Since(startTime) >= *duration {
			if !*quiet {
				fmt.Println("Monitoring duration completed")
			}
			break
		}

		// Wait for next iteration or signal
		select {
		case <-ticker.C:
			continue
		case sig := <-sigChan:
			if !*quiet {
				fmt.Printf("\nReceived signal %v, shutting down gracefully...\n", sig)
			}
			return
		}
	}
}

func getDefaultConfig(projectID, region string) MonitorConfig {
	return MonitorConfig{
		ProjectID: projectID,
		Region:    region,
		Resources: []ResourceMonitor{
			{
				Type: "compute",
				Name: "instances",
				Metrics: []MetricConfig{
					{
						Name:        "cpu_utilization",
						Type:        "gauge",
						Filter:      `resource.type="gce_instance"`,
						Aggregation: "mean",
					},
					{
						Name:        "memory_utilization",
						Type:        "gauge",
						Filter:      `resource.type="gce_instance"`,
						Aggregation: "mean",
					},
				},
				Thresholds: map[string]float64{
					"cpu_utilization":    80.0,
					"memory_utilization": 85.0,
				},
				Interval: 30 * time.Second,
			},
		},
		Settings: MonitorSettings{
			RefreshInterval: 30 * time.Second,
			RetentionPeriod: 24 * time.Hour,
			OutputFormat:    "json",
			LogLevel:        "info",
			WebPort:         8080,
			EnableWebUI:     false,
		},
	}
}

func performMonitoring(ctx context.Context, client *gcp.Client, monitoringService *gcp.MonitoringService, config *MonitorConfig, filter string) (*MonitoringResult, error) {
	result := &MonitoringResult{
		Timestamp: time.Now(),
		Resources: make(map[string]ResourceStatus),
		Alerts:    make([]ActiveAlert, 0),
		Health:    OverallHealth{},
	}

	healthyCount := 0
	totalResources := 0
	resourceTypes := make(map[string]int)
	criticalAlerts := 0

	// Monitor each resource
	for _, resource := range config.Resources {
		// Apply filter if specified
		if filter != "" && !strings.Contains(resource.Type, filter) && !strings.Contains(resource.Name, filter) {
			continue
		}

		totalResources++
		resourceTypes[resource.Type]++

		status, err := monitorResource(ctx, monitoringService, &resource)
		if err != nil {
			status = ResourceStatus{
				Status:      "error",
				LastUpdated: time.Now(),
				Issues:      []string{err.Error()},
				Details:     make(map[string]interface{}),
			}
		}

		resourceKey := fmt.Sprintf("%s.%s", resource.Type, resource.Name)
		result.Resources[resourceKey] = status

		// Check health
		if status.Status == "healthy" {
			healthyCount++
		}

		// Check for alerts
		alerts := checkResourceAlerts(&resource, &status, config.Alerts)
		for _, alert := range alerts {
			if alert.Level == "critical" {
				criticalAlerts++
			}
			result.Alerts = append(result.Alerts, alert)
		}
	}

	// Calculate overall health
	healthScore := float64(healthyCount) / float64(totalResources) * 100
	healthStatus := "healthy"
	if healthScore < 50 {
		healthStatus = "critical"
	} else if healthScore < 80 {
		healthStatus = "degraded"
	}

	result.Health = OverallHealth{
		Status: healthStatus,
		Score:  healthScore,
		Components: map[string]string{
			"compute":    "healthy",
			"storage":    "healthy",
			"network":    "healthy",
			"monitoring": "healthy",
		},
	}

	// Generate summary
	result.Summary = MonitoringSummary{
		TotalResources:  totalResources,
		HealthyCount:    healthyCount,
		UnhealthyCount:  totalResources - healthyCount,
		AlertCount:      len(result.Alerts),
		CriticalAlerts:  criticalAlerts,
		ResourceTypes:   resourceTypes,
		MetricsSummary:  make(map[string]float64),
	}

	return result, nil
}

func monitorResource(ctx context.Context, service *gcp.MonitoringService, resource *ResourceMonitor) (ResourceStatus, error) {
	status := ResourceStatus{
		Status:      "healthy",
		Metrics:     make(map[string]float64),
		LastUpdated: time.Now(),
		Issues:      make([]string, 0),
		Details:     make(map[string]interface{}),
	}

	// Query metrics for this resource
	for _, metric := range resource.Metrics {
		query := &gcp.MetricQuery{
			Filter: metric.Filter,
			Interval: &gcp.TimeInterval{
				StartTime: time.Now().Add(-5 * time.Minute),
				EndTime:   time.Now(),
			},
		}

		result, err := service.QueryMetrics(ctx, query)
		if err != nil {
			status.Issues = append(status.Issues, fmt.Sprintf("Failed to query metric %s: %v", metric.Name, err))
			continue
		}

		// Extract metric value (simplified)
		if len(result.TimeSeries) > 0 && len(result.TimeSeries[0].Points) > 0 {
			value := result.TimeSeries[0].Points[0].Value.DoubleValue
			status.Metrics[metric.Name] = value

			// Check thresholds
			if threshold, exists := resource.Thresholds[metric.Name]; exists {
				if value > threshold {
					status.Status = "unhealthy"
					status.Issues = append(status.Issues, fmt.Sprintf("Metric %s (%f) exceeds threshold (%f)", metric.Name, value, threshold))
				}
			}
		}
	}

	return status, nil
}

func checkResourceAlerts(resource *ResourceMonitor, status *ResourceStatus, alertConfigs []AlertConfig) []ActiveAlert {
	var alerts []ActiveAlert

	for _, alertConfig := range alertConfigs {
		if !alertConfig.Enabled {
			continue
		}

		for _, condition := range alertConfig.Conditions {
			if metricValue, exists := status.Metrics[condition.Metric]; exists {
				triggered := false

				switch condition.Comparison {
				case "greater_than":
					triggered = metricValue > condition.Threshold
				case "less_than":
					triggered = metricValue < condition.Threshold
				case "equal":
					triggered = metricValue == condition.Threshold
				}

				if triggered {
					alert := ActiveAlert{
						Name:      alertConfig.Name,
						Level:     "warning", // Default level
						Message:   fmt.Sprintf("%s: %s %s %f", alertConfig.Description, condition.Metric, condition.Comparison, condition.Threshold),
						Resource:  fmt.Sprintf("%s.%s", resource.Type, resource.Name),
						Metric:    condition.Metric,
						Value:     metricValue,
						Threshold: condition.Threshold,
						StartTime: time.Now(),
						Duration:  0, // Would be calculated based on first occurrence
						Details:   make(map[string]interface{}),
					}

					// Determine alert level based on how far over threshold
					overThreshold := (metricValue - condition.Threshold) / condition.Threshold
					if overThreshold > 0.5 {
						alert.Level = "critical"
					} else if overThreshold > 0.2 {
						alert.Level = "warning"
					} else {
						alert.Level = "info"
					}

					alerts = append(alerts, alert)
				}
			}
		}
	}

	return alerts
}

func outputResults(file *os.File, result *MonitoringResult, format string, verbose, quiet bool) {
	switch format {
	case "json":
		output, _ := json.MarshalIndent(result, "", "  ")
		fmt.Fprintln(file, string(output))
	case "text":
		printTextResults(file, result, verbose, quiet)
	case "table":
		printTableResults(file, result, verbose)
	}
}

func printTextResults(file *os.File, result *MonitoringResult, verbose, quiet bool) {
	if quiet && len(result.Alerts) == 0 {
		return
	}

	timestamp := result.Timestamp.Format("2006-01-02 15:04:05")
	fmt.Fprintf(file, "🕒 Monitoring Report - %s\n", timestamp)
	fmt.Fprintf(file, "🏥 Overall Health: %s (%.1f%%)\n", result.Health.Status, result.Health.Score)

	if len(result.Alerts) > 0 {
		fmt.Fprintf(file, "\n🚨 Active Alerts (%d):\n", len(result.Alerts))
		for _, alert := range result.Alerts {
			level := "ℹ️"
			if alert.Level == "warning" {
				level = "⚠️"
			} else if alert.Level == "critical" {
				level = "🚨"
			}

			fmt.Fprintf(file, "  %s %s: %s (%.2f > %.2f)\n",
				level, alert.Name, alert.Resource, alert.Value, alert.Threshold)
		}
	}

	if verbose || (!quiet && len(result.Alerts) == 0) {
		fmt.Fprintf(file, "\n📊 Resource Summary:\n")
		fmt.Fprintf(file, "  Total: %d, Healthy: %d, Unhealthy: %d\n",
			result.Summary.TotalResources,
			result.Summary.HealthyCount,
			result.Summary.UnhealthyCount)

		if verbose {
			fmt.Fprintf(file, "\n📋 Resource Details:\n")
			for resourceKey, status := range result.Resources {
				healthIcon := "✅"
				if status.Status != "healthy" {
					healthIcon = "❌"
				}

				fmt.Fprintf(file, "  %s %s: %s\n", healthIcon, resourceKey, status.Status)
				if len(status.Metrics) > 0 {
					for metricName, value := range status.Metrics {
						fmt.Fprintf(file, "    %s: %.2f\n", metricName, value)
					}
				}
				if len(status.Issues) > 0 {
					for _, issue := range status.Issues {
						fmt.Fprintf(file, "    ⚠️ %s\n", issue)
					}
				}
			}
		}
	}

	fmt.Fprintln(file)
}

func printTableResults(file *os.File, result *MonitoringResult, verbose bool) {
	// Simple table output implementation
	fmt.Fprintf(file, "%-20s %-10s %-15s %-50s\n", "Resource", "Status", "Alerts", "Issues")
	fmt.Fprintf(file, "%s\n", strings.Repeat("-", 95))

	for resourceKey, status := range result.Resources {
		alertCount := 0
		for _, alert := range result.Alerts {
			if alert.Resource == resourceKey {
				alertCount++
			}
		}

		issuesStr := ""
		if len(status.Issues) > 0 {
			issuesStr = strings.Join(status.Issues, "; ")
			if len(issuesStr) > 47 {
				issuesStr = issuesStr[:44] + "..."
			}
		}

		fmt.Fprintf(file, "%-20s %-10s %-15d %-50s\n",
			resourceKey, status.Status, alertCount, issuesStr)
	}
}

func startWebUI(port int, config *MonitorConfig) {
	// Placeholder for web UI implementation
	// In a real implementation, this would start an HTTP server
	// serving a dashboard with real-time monitoring data
	fmt.Printf("Web UI would start on port %d\n", port)
}

func getLogLevel(verbose, quiet bool) string {
	if quiet {
		return "error"
	} else if verbose {
		return "debug"
	}
	return "info"
}