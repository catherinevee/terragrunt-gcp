package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"cloud.google.com/go/storage"
	"github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"github.com/terragrunt-gcp/terragrunt-gcp/internal/analysis"
	"github.com/terragrunt-gcp/terragrunt-gcp/internal/core"
	"github.com/terragrunt-gcp/terragrunt-gcp/internal/providers"
	"google.golang.org/api/compute/v1"
	"google.golang.org/api/option"
)

var (
	version   = "1.0.0"
	buildDate = "unknown"
	gitCommit = "unknown"
	logger    = logrus.New()
)

type Config struct {
	Project      string   `mapstructure:"project"`
	Region       string   `mapstructure:"region"`
	Zones        []string `mapstructure:"zones"`
	OutputFormat string   `mapstructure:"output_format"`
	OutputFile   string   `mapstructure:"output_file"`
	LogLevel     string   `mapstructure:"log_level"`
	Credentials  string   `mapstructure:"credentials"`
	MaxWorkers   int      `mapstructure:"max_workers"`
	Timeout      int      `mapstructure:"timeout"`
	Filters      Filters  `mapstructure:"filters"`
	Export       Export   `mapstructure:"export"`
}

type Filters struct {
	ResourceTypes []string          `mapstructure:"resource_types"`
	Labels        map[string]string `mapstructure:"labels"`
	Networks      []string          `mapstructure:"networks"`
	Status        []string          `mapstructure:"status"`
	CreatedAfter  string            `mapstructure:"created_after"`
	CreatedBefore string            `mapstructure:"created_before"`
}

type Export struct {
	Enabled     bool   `mapstructure:"enabled"`
	BucketName  string `mapstructure:"bucket_name"`
	PathPrefix  string `mapstructure:"path_prefix"`
	Format      string `mapstructure:"format"`
	Compression bool   `mapstructure:"compression"`
}

var rootCmd = &cobra.Command{
	Use:   "cloudrecon",
	Short: "Cloud infrastructure reconnaissance and analysis tool",
	Long: `CloudRecon is a comprehensive tool for discovering, analyzing, and reporting
on Google Cloud Platform infrastructure resources. It provides detailed insights
into your cloud resources, their configurations, costs, and security posture.`,
}

var discoverCmd = &cobra.Command{
	Use:   "discover",
	Short: "Discover and analyze GCP resources",
	Long:  `Scan and discover all resources in the specified GCP project and regions`,
	RunE:  runDiscovery,
}

var analyzeCmd = &cobra.Command{
	Use:   "analyze [resource-type]",
	Short: "Analyze specific resource types",
	Long:  `Perform detailed analysis on specific GCP resource types`,
	Args:  cobra.MaximumNArgs(1),
	RunE:  runAnalysis,
}

var costCmd = &cobra.Command{
	Use:   "cost",
	Short: "Analyze resource costs",
	Long:  `Calculate and report on estimated costs for discovered resources`,
	RunE:  runCostAnalysis,
}

var securityCmd = &cobra.Command{
	Use:   "security",
	Short: "Security posture assessment",
	Long:  `Assess security configurations and compliance of GCP resources`,
	RunE:  runSecurityAnalysis,
}

var exportCmd = &cobra.Command{
	Use:   "export",
	Short: "Export discovered resources",
	Long:  `Export discovered resources to various formats and destinations`,
	RunE:  runExport,
}

var reportCmd = &cobra.Command{
	Use:   "report",
	Short: "Generate comprehensive reports",
	Long:  `Generate detailed reports on infrastructure, costs, and compliance`,
	RunE:  runReport,
}

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Display version information",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("CloudRecon %s\n", version)
		fmt.Printf("Build Date: %s\n", buildDate)
		fmt.Printf("Git Commit: %s\n", gitCommit)
		fmt.Printf("Go Version: %s\n", "1.24.0")
	},
}

func init() {
	cobra.OnInitialize(initConfig)

	rootCmd.PersistentFlags().StringP("project", "p", "", "GCP project ID")
	rootCmd.PersistentFlags().StringP("region", "r", "us-central1", "Default region")
	rootCmd.PersistentFlags().StringSliceP("zones", "z", []string{}, "Specific zones to scan")
	rootCmd.PersistentFlags().StringP("output", "o", "json", "Output format (json, yaml, table)")
	rootCmd.PersistentFlags().StringP("output-file", "f", "", "Output file path")
	rootCmd.PersistentFlags().StringP("log-level", "l", "info", "Log level (debug, info, warn, error)")
	rootCmd.PersistentFlags().StringP("config", "c", "", "Config file path")
	rootCmd.PersistentFlags().StringP("credentials", "", "", "Path to GCP credentials file")
	rootCmd.PersistentFlags().IntP("workers", "w", 10, "Number of concurrent workers")
	rootCmd.PersistentFlags().IntP("timeout", "t", 300, "Operation timeout in seconds")

	viper.BindPFlag("project", rootCmd.PersistentFlags().Lookup("project"))
	viper.BindPFlag("region", rootCmd.PersistentFlags().Lookup("region"))
	viper.BindPFlag("zones", rootCmd.PersistentFlags().Lookup("zones"))
	viper.BindPFlag("output_format", rootCmd.PersistentFlags().Lookup("output"))
	viper.BindPFlag("output_file", rootCmd.PersistentFlags().Lookup("output-file"))
	viper.BindPFlag("log_level", rootCmd.PersistentFlags().Lookup("log-level"))
	viper.BindPFlag("credentials", rootCmd.PersistentFlags().Lookup("credentials"))
	viper.BindPFlag("max_workers", rootCmd.PersistentFlags().Lookup("workers"))
	viper.BindPFlag("timeout", rootCmd.PersistentFlags().Lookup("timeout"))

	discoverCmd.Flags().StringSlice("resource-types", []string{}, "Resource types to discover")
	discoverCmd.Flags().StringToString("labels", map[string]string{}, "Label filters")
	discoverCmd.Flags().Bool("deep-scan", false, "Perform deep resource scanning")
	discoverCmd.Flags().Bool("include-deleted", false, "Include recently deleted resources")

	analyzeCmd.Flags().Bool("detailed", false, "Generate detailed analysis")
	analyzeCmd.Flags().StringSlice("metrics", []string{}, "Specific metrics to analyze")
	analyzeCmd.Flags().String("period", "7d", "Analysis period (e.g., 7d, 30d, 3m)")

	costCmd.Flags().String("billing-account", "", "Billing account ID")
	costCmd.Flags().String("start-date", "", "Start date for cost analysis (YYYY-MM-DD)")
	costCmd.Flags().String("end-date", "", "End date for cost analysis (YYYY-MM-DD)")
	costCmd.Flags().Bool("forecast", false, "Include cost forecast")
	costCmd.Flags().String("group-by", "service", "Group costs by (service, resource, label)")

	securityCmd.Flags().StringSlice("checks", []string{}, "Specific security checks to run")
	securityCmd.Flags().String("compliance", "", "Compliance framework (cis, pci, hipaa)")
	securityCmd.Flags().Bool("remediate", false, "Generate remediation scripts")

	exportCmd.Flags().String("format", "json", "Export format (json, csv, terraform, yaml)")
	exportCmd.Flags().String("destination", "", "Export destination (file, gcs, bq)")
	exportCmd.Flags().String("bucket", "", "GCS bucket name for export")
	exportCmd.Flags().Bool("compress", false, "Compress exported data")

	reportCmd.Flags().String("template", "standard", "Report template (standard, executive, technical)")
	reportCmd.Flags().StringSlice("sections", []string{}, "Report sections to include")
	reportCmd.Flags().String("format", "html", "Report format (html, pdf, markdown)")
	reportCmd.Flags().Bool("include-charts", true, "Include charts and visualizations")

	rootCmd.AddCommand(discoverCmd)
	rootCmd.AddCommand(analyzeCmd)
	rootCmd.AddCommand(costCmd)
	rootCmd.AddCommand(securityCmd)
	rootCmd.AddCommand(exportCmd)
	rootCmd.AddCommand(reportCmd)
	rootCmd.AddCommand(versionCmd)
}

func initConfig() {
	configFile := viper.GetString("config")
	if configFile != "" {
		viper.SetConfigFile(configFile)
	} else {
		home, err := os.UserHomeDir()
		if err == nil {
			viper.AddConfigPath(home)
			viper.AddConfigPath(filepath.Join(home, ".cloudrecon"))
		}
		viper.AddConfigPath(".")
		viper.SetConfigName(".cloudrecon")
		viper.SetConfigType("yaml")
	}

	viper.SetEnvPrefix("CLOUDRECON")
	viper.AutomaticEnv()
	viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))

	if err := viper.ReadInConfig(); err == nil {
		logger.Infof("Using config file: %s", viper.ConfigFileUsed())
	}

	logLevel := viper.GetString("log_level")
	level, err := logrus.ParseLevel(logLevel)
	if err != nil {
		level = logrus.InfoLevel
	}
	logger.SetLevel(level)
	logger.SetFormatter(&logrus.TextFormatter{
		FullTimestamp:   true,
		TimestampFormat: "2006-01-02 15:04:05",
	})
}

func runDiscovery(cmd *cobra.Command, args []string) error {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-sigChan
		logger.Info("Received interrupt signal, shutting down...")
		cancel()
	}()

	config, err := loadConfig()
	if err != nil {
		return fmt.Errorf("failed to load configuration: %w", err)
	}

	provider, err := createProvider(ctx, config)
	if err != nil {
		return fmt.Errorf("failed to create provider: %w", err)
	}

	discoverer := core.NewDiscoverer(provider, logger, core.DiscoveryOptions{
		MaxWorkers:    config.MaxWorkers,
		Timeout:       time.Duration(config.Timeout) * time.Second,
		ResourceTypes: cmd.Flag("resource-types").Value.String(),
		DeepScan:      cmd.Flag("deep-scan").Value.String() == "true",
		Filters:       convertFilters(config.Filters),
	})

	logger.Info("Starting resource discovery...")
	startTime := time.Now()

	results, err := discoverer.Discover(ctx)
	if err != nil {
		return fmt.Errorf("discovery failed: %w", err)
	}

	duration := time.Since(startTime)
	logger.Infof("Discovery completed in %s", duration)
	logger.Infof("Found %d resources", len(results.Resources))

	if err := outputResults(results, config); err != nil {
		return fmt.Errorf("failed to output results: %w", err)
	}

	if config.Export.Enabled {
		if err := exportResults(ctx, results, config); err != nil {
			logger.Errorf("Export failed: %v", err)
		}
	}

	return nil
}

func runAnalysis(cmd *cobra.Command, args []string) error {
	ctx := context.Background()
	config, err := loadConfig()
	if err != nil {
		return fmt.Errorf("failed to load configuration: %w", err)
	}

	provider, err := createProvider(ctx, config)
	if err != nil {
		return fmt.Errorf("failed to create provider: %w", err)
	}

	analyzer := analysis.NewAnalyzer(provider, logger)

	resourceType := ""
	if len(args) > 0 {
		resourceType = args[0]
	}

	detailed, _ := cmd.Flags().GetBool("detailed")
	metrics, _ := cmd.Flags().GetStringSlice("metrics")
	period, _ := cmd.Flags().GetString("period")

	options := analysis.AnalysisOptions{
		ResourceType: resourceType,
		Detailed:     detailed,
		Metrics:      metrics,
		Period:       parsePeriod(period),
	}

	logger.Info("Starting resource analysis...")
	results, err := analyzer.Analyze(ctx, options)
	if err != nil {
		return fmt.Errorf("analysis failed: %w", err)
	}

	return outputResults(results, config)
}

func runCostAnalysis(cmd *cobra.Command, args []string) error {
	ctx := context.Background()
	config, err := loadConfig()
	if err != nil {
		return fmt.Errorf("failed to load configuration: %w", err)
	}

	provider, err := createProvider(ctx, config)
	if err != nil {
		return fmt.Errorf("failed to create provider: %w", err)
	}

	billingAccount, _ := cmd.Flags().GetString("billing-account")
	startDate, _ := cmd.Flags().GetString("start-date")
	endDate, _ := cmd.Flags().GetString("end-date")
	forecast, _ := cmd.Flags().GetBool("forecast")
	groupBy, _ := cmd.Flags().GetString("group-by")

	costAnalyzer := analysis.NewCostAnalyzer(provider, logger)

	options := analysis.CostAnalysisOptions{
		BillingAccount: billingAccount,
		StartDate:      parseDate(startDate),
		EndDate:        parseDate(endDate),
		IncludeForecast: forecast,
		GroupBy:        groupBy,
	}

	logger.Info("Analyzing resource costs...")
	results, err := costAnalyzer.AnalyzeCosts(ctx, options)
	if err != nil {
		return fmt.Errorf("cost analysis failed: %w", err)
	}

	return outputResults(results, config)
}

func runSecurityAnalysis(cmd *cobra.Command, args []string) error {
	ctx := context.Background()
	config, err := loadConfig()
	if err != nil {
		return fmt.Errorf("failed to load configuration: %w", err)
	}

	provider, err := createProvider(ctx, config)
	if err != nil {
		return fmt.Errorf("failed to create provider: %w", err)
	}

	checks, _ := cmd.Flags().GetStringSlice("checks")
	compliance, _ := cmd.Flags().GetString("compliance")
	remediate, _ := cmd.Flags().GetBool("remediate")

	securityAnalyzer := analysis.NewSecurityAnalyzer(provider, logger)

	options := analysis.SecurityOptions{
		Checks:             checks,
		ComplianceFramework: compliance,
		GenerateRemediation: remediate,
	}

	logger.Info("Running security analysis...")
	results, err := securityAnalyzer.AnalyzeSecurity(ctx, options)
	if err != nil {
		return fmt.Errorf("security analysis failed: %w", err)
	}

	if remediate && len(results.Remediations) > 0 {
		if err := saveRemediationScripts(results.Remediations); err != nil {
			logger.Errorf("Failed to save remediation scripts: %v", err)
		}
	}

	return outputResults(results, config)
}

func runExport(cmd *cobra.Command, args []string) error {
	ctx := context.Background()
	config, err := loadConfig()
	if err != nil {
		return fmt.Errorf("failed to load configuration: %w", err)
	}

	format, _ := cmd.Flags().GetString("format")
	destination, _ := cmd.Flags().GetString("destination")
	bucket, _ := cmd.Flags().GetString("bucket")
	compress, _ := cmd.Flags().GetBool("compress")

	provider, err := createProvider(ctx, config)
	if err != nil {
		return fmt.Errorf("failed to create provider: %w", err)
	}

	discoverer := core.NewDiscoverer(provider, logger, core.DiscoveryOptions{
		MaxWorkers: config.MaxWorkers,
		Timeout:    time.Duration(config.Timeout) * time.Second,
	})

	results, err := discoverer.Discover(ctx)
	if err != nil {
		return fmt.Errorf("discovery failed: %w", err)
	}

	exporter := core.NewExporter(logger)
	exportOptions := core.ExportOptions{
		Format:      format,
		Destination: destination,
		Bucket:      bucket,
		Compress:    compress,
	}

	logger.Infof("Exporting %d resources to %s", len(results.Resources), destination)
	if err := exporter.Export(ctx, results, exportOptions); err != nil {
		return fmt.Errorf("export failed: %w", err)
	}

	logger.Info("Export completed successfully")
	return nil
}

func runReport(cmd *cobra.Command, args []string) error {
	ctx := context.Background()
	config, err := loadConfig()
	if err != nil {
		return fmt.Errorf("failed to load configuration: %w", err)
	}

	template, _ := cmd.Flags().GetString("template")
	sections, _ := cmd.Flags().GetStringSlice("sections")
	format, _ := cmd.Flags().GetString("format")
	includeCharts, _ := cmd.Flags().GetBool("include-charts")

	provider, err := createProvider(ctx, config)
	if err != nil {
		return fmt.Errorf("failed to create provider: %w", err)
	}

	reporter := core.NewReporter(provider, logger)

	reportOptions := core.ReportOptions{
		Template:      template,
		Sections:      sections,
		Format:        format,
		IncludeCharts: includeCharts,
		Project:       config.Project,
		Region:        config.Region,
	}

	logger.Info("Generating infrastructure report...")
	report, err := reporter.GenerateReport(ctx, reportOptions)
	if err != nil {
		return fmt.Errorf("report generation failed: %w", err)
	}

	outputFile := fmt.Sprintf("cloudrecon-report-%s.%s",
		time.Now().Format("20060102-150405"), format)

	if err := saveReport(report, outputFile, format); err != nil {
		return fmt.Errorf("failed to save report: %w", err)
	}

	logger.Infof("Report saved to %s", outputFile)
	return nil
}

func loadConfig() (*Config, error) {
	var config Config
	if err := viper.Unmarshal(&config); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	if config.Project == "" {
		return nil, fmt.Errorf("GCP project ID is required")
	}

	if config.MaxWorkers <= 0 {
		config.MaxWorkers = 10
	}

	if config.Timeout <= 0 {
		config.Timeout = 300
	}

	return &config, nil
}

func createProvider(ctx context.Context, config *Config) (providers.Provider, error) {
	var opts []option.ClientOption

	if config.Credentials != "" {
		opts = append(opts, option.WithCredentialsFile(config.Credentials))
	}

	return providers.NewGCPProvider(ctx, config.Project, config.Region, opts...)
}

func convertFilters(filters Filters) map[string]interface{} {
	result := make(map[string]interface{})

	if len(filters.ResourceTypes) > 0 {
		result["resource_types"] = filters.ResourceTypes
	}
	if len(filters.Labels) > 0 {
		result["labels"] = filters.Labels
	}
	if len(filters.Networks) > 0 {
		result["networks"] = filters.Networks
	}
	if len(filters.Status) > 0 {
		result["status"] = filters.Status
	}
	if filters.CreatedAfter != "" {
		result["created_after"] = filters.CreatedAfter
	}
	if filters.CreatedBefore != "" {
		result["created_before"] = filters.CreatedBefore
	}

	return result
}

func outputResults(results interface{}, config *Config) error {
	var output []byte
	var err error

	switch config.OutputFormat {
	case "json":
		output, err = json.MarshalIndent(results, "", "  ")
	case "yaml":
		output, err = marshalYAML(results)
	case "table":
		return printTable(results)
	default:
		output, err = json.MarshalIndent(results, "", "  ")
	}

	if err != nil {
		return fmt.Errorf("failed to marshal results: %w", err)
	}

	if config.OutputFile != "" {
		return os.WriteFile(config.OutputFile, output, 0644)
	}

	fmt.Println(string(output))
	return nil
}

func exportResults(ctx context.Context, results *core.DiscoveryResults, config *Config) error {
	if !config.Export.Enabled || config.Export.BucketName == "" {
		return nil
	}

	client, err := storage.NewClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create storage client: %w", err)
	}
	defer client.Close()

	bucket := client.Bucket(config.Export.BucketName)

	data, err := json.MarshalIndent(results, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal results: %w", err)
	}

	filename := fmt.Sprintf("%s/cloudrecon-%s.json",
		config.Export.PathPrefix,
		time.Now().Format("20060102-150405"))

	if config.Export.Compression {
		data, err = compressData(data)
		if err != nil {
			return fmt.Errorf("failed to compress data: %w", err)
		}
		filename += ".gz"
	}

	obj := bucket.Object(filename)
	writer := obj.NewWriter(ctx)
	defer writer.Close()

	if _, err := writer.Write(data); err != nil {
		return fmt.Errorf("failed to write to GCS: %w", err)
	}

	logger.Infof("Results exported to gs://%s/%s", config.Export.BucketName, filename)
	return nil
}

func saveRemediationScripts(remediations []analysis.Remediation) error {
	dir := "remediations"
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create remediations directory: %w", err)
	}

	for i, remediation := range remediations {
		filename := filepath.Join(dir, fmt.Sprintf("remediation-%03d-%s.sh", i+1, remediation.Type))
		if err := os.WriteFile(filename, []byte(remediation.Script), 0755); err != nil {
			return fmt.Errorf("failed to save remediation script: %w", err)
		}
		logger.Infof("Saved remediation script: %s", filename)
	}

	return nil
}

func saveReport(report *core.Report, filename, format string) error {
	var data []byte
	var err error

	switch format {
	case "html":
		data, err = report.ToHTML()
	case "pdf":
		data, err = report.ToPDF()
	case "markdown":
		data, err = report.ToMarkdown()
	default:
		data, err = json.MarshalIndent(report, "", "  ")
	}

	if err != nil {
		return fmt.Errorf("failed to format report: %w", err)
	}

	return os.WriteFile(filename, data, 0644)
}

func parsePeriod(period string) time.Duration {
	if period == "" {
		return 7 * 24 * time.Hour
	}

	unit := period[len(period)-1:]
	value := period[:len(period)-1]

	var duration time.Duration
	var multiplier int
	fmt.Sscanf(value, "%d", &multiplier)

	switch unit {
	case "h":
		duration = time.Duration(multiplier) * time.Hour
	case "d":
		duration = time.Duration(multiplier) * 24 * time.Hour
	case "w":
		duration = time.Duration(multiplier) * 7 * 24 * time.Hour
	case "m":
		duration = time.Duration(multiplier) * 30 * 24 * time.Hour
	default:
		duration = 7 * 24 * time.Hour
	}

	return duration
}

func parseDate(dateStr string) time.Time {
	if dateStr == "" {
		return time.Now()
	}

	t, err := time.Parse("2006-01-02", dateStr)
	if err != nil {
		logger.Warnf("Failed to parse date %s, using current date", dateStr)
		return time.Now()
	}

	return t
}

func marshalYAML(v interface{}) ([]byte, error) {
	jsonData, err := json.Marshal(v)
	if err != nil {
		return nil, err
	}

	var data interface{}
	if err := json.Unmarshal(jsonData, &data); err != nil {
		return nil, err
	}

	return []byte(fmt.Sprintf("%v", data)), nil
}

func printTable(results interface{}) error {
	fmt.Printf("%-20s %-15s %-30s %-15s\n", "Resource", "Type", "Name", "Status")
	fmt.Println(strings.Repeat("-", 80))

	if dr, ok := results.(*core.DiscoveryResults); ok {
		for _, resource := range dr.Resources {
			fmt.Printf("%-20s %-15s %-30s %-15s\n",
				resource.ID,
				resource.Type,
				resource.Name,
				resource.Status)
		}
		fmt.Printf("\nTotal Resources: %d\n", len(dr.Resources))
	}

	return nil
}

func compressData(data []byte) ([]byte, error) {
	return data, nil
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		logger.Error(err)
		os.Exit(1)
	}
}