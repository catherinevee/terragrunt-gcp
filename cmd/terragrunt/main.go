package main

import (
	"archive/zip"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"github.com/terragrunt-gcp/terragrunt-gcp/internal/config"
	"github.com/terragrunt-gcp/terragrunt-gcp/internal/gcp"
	"github.com/terragrunt-gcp/terragrunt-gcp/internal/terraform"
)

var (
	version   = "2.0.0"
	buildDate = "unknown"
	gitCommit = "unknown"
	logger    = logrus.New()
)

type TerragruntConfig struct {
	TerraformPath   string                 `json:"terraform_path" mapstructure:"terraform_path"`
	WorkingDir      string                 `json:"working_dir" mapstructure:"working_dir"`
	ConfigFile      string                 `json:"config_file" mapstructure:"config_file"`
	AutoInit        bool                   `json:"auto_init" mapstructure:"auto_init"`
	AutoPlan        bool                   `json:"auto_plan" mapstructure:"auto_plan"`
	NonInteractive  bool                   `json:"non_interactive" mapstructure:"non_interactive"`
	Parallelism     int                    `json:"parallelism" mapstructure:"parallelism"`
	RetryAttempts   int                    `json:"retry_attempts" mapstructure:"retry_attempts"`
	RetryDelay      time.Duration          `json:"retry_delay" mapstructure:"retry_delay"`
	LogLevel        string                 `json:"log_level" mapstructure:"log_level"`
	DownloadDir     string                 `json:"download_dir" mapstructure:"download_dir"`
	IamRole         string                 `json:"iam_role" mapstructure:"iam_role"`
	IncludeDirs     []string               `json:"include_dirs" mapstructure:"include_dirs"`
	ExcludeDirs     []string               `json:"exclude_dirs" mapstructure:"exclude_dirs"`
	GCP             GCPConfig              `json:"gcp" mapstructure:"gcp"`
	Backend         BackendConfig          `json:"backend" mapstructure:"backend"`
	Dependencies    []DependencyConfig     `json:"dependencies" mapstructure:"dependencies"`
	Hooks           HooksConfig            `json:"hooks" mapstructure:"hooks"`
	Cache           CacheConfig            `json:"cache" mapstructure:"cache"`
	Variables       map[string]interface{} `json:"variables" mapstructure:"variables"`
	Environment     map[string]string      `json:"environment" mapstructure:"environment"`
	RemoteState     RemoteStateConfig      `json:"remote_state" mapstructure:"remote_state"`
	TerraformBinary TerraformBinaryConfig  `json:"terraform_binary" mapstructure:"terraform_binary"`
	ErrorHandling   ErrorHandlingConfig    `json:"error_handling" mapstructure:"error_handling"`
}

type GCPConfig struct {
	Project                   string            `json:"project" mapstructure:"project"`
	Region                    string            `json:"region" mapstructure:"region"`
	Zone                      string            `json:"zone" mapstructure:"zone"`
	Credentials               string            `json:"credentials" mapstructure:"credentials"`
	ImpersonateServiceAccount string            `json:"impersonate_service_account" mapstructure:"impersonate_service_account"`
	ServiceAccounts           []string          `json:"service_accounts" mapstructure:"service_accounts"`
	EnableAPIs                []string          `json:"enable_apis" mapstructure:"enable_apis"`
	Labels                    map[string]string `json:"labels" mapstructure:"labels"`
}

type BackendConfig struct {
	Type          string                 `json:"type" mapstructure:"type"`
	Bucket        string                 `json:"bucket" mapstructure:"bucket"`
	Prefix        string                 `json:"prefix" mapstructure:"prefix"`
	EncryptionKey string                 `json:"encryption_key" mapstructure:"encryption_key"`
	DynamoDBTable string                 `json:"dynamodb_table" mapstructure:"dynamodb_table"`
	StateFileID   string                 `json:"state_file_id" mapstructure:"state_file_id"`
	CustomConfig  map[string]interface{} `json:"custom_config" mapstructure:"custom_config"`
}

type DependencyConfig struct {
	Name        string                 `json:"name" mapstructure:"name"`
	Path        string                 `json:"path" mapstructure:"path"`
	ConfigPath  string                 `json:"config_path" mapstructure:"config_path"`
	SkipOutputs bool                   `json:"skip_outputs" mapstructure:"skip_outputs"`
	MockOutputs map[string]interface{} `json:"mock_outputs" mapstructure:"mock_outputs"`
	Enabled     bool                   `json:"enabled" mapstructure:"enabled"`
}

type HooksConfig struct {
	BeforeHooks []HookConfig `json:"before_hooks" mapstructure:"before_hooks"`
	AfterHooks  []HookConfig `json:"after_hooks" mapstructure:"after_hooks"`
	ErrorHooks  []HookConfig `json:"error_hooks" mapstructure:"error_hooks"`
}

type HookConfig struct {
	Name       string   `json:"name" mapstructure:"name"`
	Commands   []string `json:"commands" mapstructure:"commands"`
	Execute    []string `json:"execute" mapstructure:"execute"`
	RunOnError bool     `json:"run_on_error" mapstructure:"run_on_error"`
	WorkingDir string   `json:"working_dir" mapstructure:"working_dir"`
}

type CacheConfig struct {
	Enabled        bool          `json:"enabled" mapstructure:"enabled"`
	Dir            string        `json:"dir" mapstructure:"dir"`
	MaxSize        int64         `json:"max_size" mapstructure:"max_size"`
	TTL            time.Duration `json:"ttl" mapstructure:"ttl"`
	CleanupOnStart bool          `json:"cleanup_on_start" mapstructure:"cleanup_on_start"`
}

type RemoteStateConfig struct {
	Backend                       string                 `json:"backend" mapstructure:"backend"`
	DisableDependencyOptimization bool                   `json:"disable_dependency_optimization" mapstructure:"disable_dependency_optimization"`
	DisableInit                   bool                   `json:"disable_init" mapstructure:"disable_init"`
	Generate                      map[string]interface{} `json:"generate" mapstructure:"generate"`
	Config                        map[string]interface{} `json:"config" mapstructure:"config"`
}

type TerraformBinaryConfig struct {
	Path         string            `json:"path" mapstructure:"path"`
	Version      string            `json:"version" mapstructure:"version"`
	DownloadURL  string            `json:"download_url" mapstructure:"download_url"`
	AutoDownload bool              `json:"auto_download" mapstructure:"auto_download"`
	Checksums    map[string]string `json:"checksums" mapstructure:"checksums"`
}

type ErrorHandlingConfig struct {
	RetryableErrors []string      `json:"retryable_errors" mapstructure:"retryable_errors"`
	MaxRetries      int           `json:"max_retries" mapstructure:"max_retries"`
	RetryDelay      time.Duration `json:"retry_delay" mapstructure:"retry_delay"`
	IgnoreErrors    []string      `json:"ignore_errors" mapstructure:"ignore_errors"`
	OnError         string        `json:"on_error" mapstructure:"on_error"`
}

type ExecutionContext struct {
	Config          *TerragruntConfig
	WorkingDir      string
	Command         string
	Args            []string
	Environment     map[string]string
	DryRun          bool
	Force           bool
	TargetModules   []string
	ExcludedModules []string
	Dependencies    map[string]interface{}
	Outputs         map[string]interface{}
	State           map[string]interface{}
	Hooks           []HookConfig
	StartTime       time.Time
	Logger          *logrus.Logger
	mutex           sync.Mutex
	errors          []error
}

var rootCmd = &cobra.Command{
	Use:   "terragrunt",
	Short: "Terragrunt - Infrastructure as Code orchestrator for Terraform",
	Long: `Terragrunt is a thin wrapper for Terraform that provides extra tools for:
- Working with multiple Terraform modules
- Managing remote state
- Managing dependencies between modules
- Keeping your Terraform code DRY`,
}

var initCmd = &cobra.Command{
	Use:   "init",
	Short: "Initialize Terraform working directory",
	Long:  `Initialize a Terraform working directory containing configuration files`,
	RunE:  runInit,
}

var planCmd = &cobra.Command{
	Use:   "plan",
	Short: "Generate and show Terraform execution plan",
	Long:  `Generate an execution plan showing what actions Terraform will take`,
	RunE:  runPlan,
}

var applyCmd = &cobra.Command{
	Use:   "apply",
	Short: "Apply Terraform changes",
	Long:  `Apply the changes required to reach the desired state of the configuration`,
	RunE:  runApply,
}

var destroyCmd = &cobra.Command{
	Use:   "destroy",
	Short: "Destroy Terraform-managed infrastructure",
	Long:  `Destroy all remote objects managed by the Terraform configuration`,
	RunE:  runDestroy,
}

var validateCmd = &cobra.Command{
	Use:   "validate",
	Short: "Validate Terraform configuration",
	Long:  `Validate the configuration files in the directory`,
	RunE:  runValidate,
}

var outputCmd = &cobra.Command{
	Use:   "output",
	Short: "Show Terraform outputs",
	Long:  `Show output values from the Terraform state`,
	RunE:  runOutput,
}

var runAllCmd = &cobra.Command{
	Use:   "run-all",
	Short: "Run Terraform command against multiple modules",
	Long:  `Execute Terraform commands across multiple modules in dependency order`,
}

var planAllCmd = &cobra.Command{
	Use:   "plan",
	Short: "Run terraform plan across all modules",
	RunE:  runPlanAll,
}

var applyAllCmd = &cobra.Command{
	Use:   "apply",
	Short: "Run terraform apply across all modules",
	RunE:  runApplyAll,
}

var destroyAllCmd = &cobra.Command{
	Use:   "destroy",
	Short: "Run terraform destroy across all modules",
	RunE:  runDestroyAll,
}

var hclfmtCmd = &cobra.Command{
	Use:   "hclfmt",
	Short: "Format HCL files",
	Long:  `Format all HCL files in the current directory and subdirectories`,
	RunE:  runHCLFormat,
}

var graphDependenciesCmd = &cobra.Command{
	Use:   "graph-dependencies",
	Short: "Generate dependency graph",
	Long:  `Generate a graph showing dependencies between Terraform modules`,
	RunE:  runGraphDependencies,
}

var renderJsonCmd = &cobra.Command{
	Use:   "render-json",
	Short: "Render terragrunt.hcl as JSON",
	Long:  `Render the terragrunt.hcl configuration file as JSON for debugging`,
	RunE:  runRenderJSON,
}

var awsProviderPatchCmd = &cobra.Command{
	Use:   "aws-provider-patch",
	Short: "Patch AWS provider",
	Long:  `Update AWS provider to handle authentication and region configuration`,
	RunE:  runAWSProviderPatch,
}

var scaffoldCmd = &cobra.Command{
	Use:   "scaffold",
	Short: "Scaffold new module structure",
	Long:  `Create a new Terraform module with Terragrunt configuration`,
	RunE:  runScaffold,
}

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Show version information",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("Terragrunt version %s\n", version)
		fmt.Printf("Build date: %s\n", buildDate)
		fmt.Printf("Git commit: %s\n", gitCommit)
		fmt.Printf("Go version: %s\n", runtime.Version())
		fmt.Printf("OS/Arch: %s/%s\n", runtime.GOOS, runtime.GOARCH)

		// Also show Terraform version
		tfVersion := getTerraformVersion()
		if tfVersion != "" {
			fmt.Printf("Terraform: %s\n", tfVersion)
		}
	},
}

func init() {
	cobra.OnInitialize(initConfig)

	// Global flags
	rootCmd.PersistentFlags().StringP("terragrunt-config", "c", "", "Path to the Terragrunt config file")
	rootCmd.PersistentFlags().StringP("terragrunt-working-dir", "w", "", "Working directory for Terragrunt")
	rootCmd.PersistentFlags().BoolP("terragrunt-non-interactive", "n", false, "Run in non-interactive mode")
	rootCmd.PersistentFlags().BoolP("terragrunt-debug", "d", false, "Enable debug logging")
	rootCmd.PersistentFlags().StringP("terragrunt-log-level", "l", "info", "Set log level")
	rootCmd.PersistentFlags().StringP("terragrunt-iam-role", "", "", "IAM role to assume")
	rootCmd.PersistentFlags().BoolP("terragrunt-no-auto-init", "", false, "Disable automatic terraform init")
	rootCmd.PersistentFlags().BoolP("terragrunt-no-auto-retry", "", false, "Disable automatic retry on errors")
	rootCmd.PersistentFlags().IntP("terragrunt-parallelism", "p", 10, "Limit number of parallel executions")
	rootCmd.PersistentFlags().StringSliceP("terragrunt-include-dir", "", []string{}, "Include directories")
	rootCmd.PersistentFlags().StringSliceP("terragrunt-exclude-dir", "", []string{}, "Exclude directories")
	rootCmd.PersistentFlags().StringP("terragrunt-download-dir", "", "", "Directory for downloading remote configurations")
	rootCmd.PersistentFlags().BoolP("terragrunt-source-update", "", false, "Update module source")
	rootCmd.PersistentFlags().BoolP("terragrunt-ignore-dependency-errors", "", false, "Ignore dependency errors")
	rootCmd.PersistentFlags().BoolP("terragrunt-ignore-dependency-order", "", false, "Ignore dependency order")
	rootCmd.PersistentFlags().BoolP("terragrunt-ignore-external-dependencies", "", false, "Ignore external dependencies")
	rootCmd.PersistentFlags().BoolP("terragrunt-include-external-dependencies", "", false, "Include external dependencies")
	rootCmd.PersistentFlags().BoolP("terragrunt-fail-on-state-bucket-creation", "", false, "Fail if state bucket needs to be created")
	rootCmd.PersistentFlags().BoolP("terragrunt-disable-bucket-update", "", false, "Disable state bucket updates")
	rootCmd.PersistentFlags().StringP("terragrunt-json-out", "", "", "Output JSON to specified file")
	rootCmd.PersistentFlags().BoolP("terragrunt-check", "", false, "Check configuration without running")
	rootCmd.PersistentFlags().BoolP("terragrunt-diff", "", false, "Show diff of changes")
	rootCmd.PersistentFlags().BoolP("terragrunt-hclfmt-file", "", false, "Format specific HCL file")
	rootCmd.PersistentFlags().StringP("terragrunt-source", "", "", "Override module source")
	rootCmd.PersistentFlags().StringP("terragrunt-source-map", "", "", "Map module sources")
	rootCmd.PersistentFlags().BoolP("terragrunt-fetch", "", false, "Fetch remote configurations")
	rootCmd.PersistentFlags().StringSliceP("terragrunt-module-groups", "", []string{}, "Module groups to include")
	rootCmd.PersistentFlags().BoolP("terragrunt-strict-include", "", false, "Use strict include mode")
	rootCmd.PersistentFlags().BoolP("terragrunt-use-partial-parse-config-cache", "", true, "Use configuration cache")

	// Bind flags to viper
	viper.BindPFlag("config_file", rootCmd.PersistentFlags().Lookup("terragrunt-config"))
	viper.BindPFlag("working_dir", rootCmd.PersistentFlags().Lookup("terragrunt-working-dir"))
	viper.BindPFlag("non_interactive", rootCmd.PersistentFlags().Lookup("terragrunt-non-interactive"))
	viper.BindPFlag("log_level", rootCmd.PersistentFlags().Lookup("terragrunt-log-level"))
	viper.BindPFlag("iam_role", rootCmd.PersistentFlags().Lookup("terragrunt-iam-role"))
	viper.BindPFlag("auto_init", rootCmd.PersistentFlags().Lookup("terragrunt-no-auto-init"))
	viper.BindPFlag("parallelism", rootCmd.PersistentFlags().Lookup("terragrunt-parallelism"))
	viper.BindPFlag("include_dirs", rootCmd.PersistentFlags().Lookup("terragrunt-include-dir"))
	viper.BindPFlag("exclude_dirs", rootCmd.PersistentFlags().Lookup("terragrunt-exclude-dir"))
	viper.BindPFlag("download_dir", rootCmd.PersistentFlags().Lookup("terragrunt-download-dir"))

	// Command-specific flags
	initCmd.Flags().BoolP("upgrade", "u", false, "Upgrade modules and plugins")
	initCmd.Flags().Bool("migrate-state", false, "Migrate existing state")
	initCmd.Flags().Bool("reconfigure", false, "Reconfigure backend")

	planCmd.Flags().StringP("out", "o", "", "Path to save plan file")
	planCmd.Flags().Bool("destroy", false, "Generate destroy plan")
	planCmd.Flags().Bool("refresh-only", false, "Only refresh state")
	planCmd.Flags().StringSliceP("target", "t", []string{}, "Resource to target")
	planCmd.Flags().StringSlice("replace", []string{}, "Resources to replace")
	planCmd.Flags().StringSliceP("var", "", []string{}, "Set variable value")
	planCmd.Flags().StringP("var-file", "", "", "Variable file")

	applyCmd.Flags().BoolP("auto-approve", "a", false, "Skip interactive approval")
	applyCmd.Flags().StringP("backup", "", "", "Path to backup state file")
	applyCmd.Flags().Bool("compact-warnings", false, "Compact warning messages")
	applyCmd.Flags().StringSliceP("target", "t", []string{}, "Resource to target")
	applyCmd.Flags().StringSlice("replace", []string{}, "Resources to replace")
	applyCmd.Flags().StringSliceP("var", "", []string{}, "Set variable value")
	applyCmd.Flags().StringP("var-file", "", "", "Variable file")
	applyCmd.Flags().IntP("parallelism", "p", 10, "Limit parallel operations")

	destroyCmd.Flags().BoolP("auto-approve", "a", false, "Skip interactive approval")
	destroyCmd.Flags().StringP("backup", "", "", "Path to backup state file")
	destroyCmd.Flags().StringSliceP("target", "t", []string{}, "Resource to target")
	destroyCmd.Flags().StringSliceP("var", "", []string{}, "Set variable value")
	destroyCmd.Flags().StringP("var-file", "", "", "Variable file")

	outputCmd.Flags().BoolP("json", "j", false, "Output as JSON")
	outputCmd.Flags().BoolP("raw", "r", false, "Output raw value")
	outputCmd.Flags().String("state", "", "Path to state file")

	scaffoldCmd.Flags().StringP("template", "t", "default", "Module template to use")
	scaffoldCmd.Flags().StringP("name", "", "", "Module name")
	scaffoldCmd.Flags().StringP("path", "", "", "Path to create module")
	scaffoldCmd.Flags().Bool("with-examples", false, "Include example configurations")
	scaffoldCmd.Flags().Bool("with-tests", false, "Include test configurations")

	hclfmtCmd.Flags().Bool("check", false, "Check if files are formatted")
	hclfmtCmd.Flags().Bool("diff", false, "Show formatting diff")
	hclfmtCmd.Flags().Bool("write", true, "Write formatted files")

	graphDependenciesCmd.Flags().StringP("output", "o", "", "Output file path")
	graphDependenciesCmd.Flags().StringP("format", "f", "dot", "Output format (dot, json, mermaid)")

	// Add run-all subcommands
	runAllCmd.AddCommand(planAllCmd, applyAllCmd, destroyAllCmd)

	// Build command tree
	rootCmd.AddCommand(
		initCmd,
		planCmd,
		applyCmd,
		destroyCmd,
		validateCmd,
		outputCmd,
		runAllCmd,
		hclfmtCmd,
		graphDependenciesCmd,
		renderJsonCmd,
		awsProviderPatchCmd,
		scaffoldCmd,
		versionCmd,
	)
}

func initConfig() {
	// Set config file
	configFile := viper.GetString("config_file")
	if configFile != "" {
		viper.SetConfigFile(configFile)
	} else {
		// Look for terragrunt.hcl in current and parent directories
		viper.SetConfigName("terragrunt")
		viper.SetConfigType("hcl")
		viper.AddConfigPath(".")
		viper.AddConfigPath("..")
		viper.AddConfigPath("../..")
	}

	// Set environment variable prefix
	viper.SetEnvPrefix("TERRAGRUNT")
	viper.AutomaticEnv()
	viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_", "-", "_"))

	// Read config file
	if err := viper.ReadInConfig(); err == nil {
		logger.Infof("Using config file: %s", viper.ConfigFileUsed())
	}

	// Setup logging
	logLevel := viper.GetString("log_level")
	level, err := logrus.ParseLevel(logLevel)
	if err != nil {
		level = logrus.InfoLevel
	}
	logger.SetLevel(level)

	// Set formatter
	logger.SetFormatter(&logrus.TextFormatter{
		FullTimestamp:   true,
		TimestampFormat: "2006-01-02 15:04:05",
		DisableColors:   false,
		ForceColors:     true,
	})

	// Add debug handler
	if viper.GetBool("debug") || level == logrus.DebugLevel {
		logger.SetReportCaller(true)
	}
}

func createExecutionContext(cmd *cobra.Command) (*ExecutionContext, error) {
	config := &TerragruntConfig{
		TerraformPath:  "terraform",
		WorkingDir:     ".",
		AutoInit:       !viper.GetBool("auto_init"),
		NonInteractive: viper.GetBool("non_interactive"),
		Parallelism:    viper.GetInt("parallelism"),
		RetryAttempts:  3,
		RetryDelay:     2 * time.Second,
		LogLevel:       viper.GetString("log_level"),
		DownloadDir:    viper.GetString("download_dir"),
		IamRole:        viper.GetString("iam_role"),
		IncludeDirs:    viper.GetStringSlice("include_dirs"),
		ExcludeDirs:    viper.GetStringSlice("exclude_dirs"),
		Variables:      make(map[string]interface{}),
		Environment:    make(map[string]string),
	}

	// Load configuration from file if exists
	if viper.ConfigFileUsed() != "" {
		if err := loadConfigFile(viper.ConfigFileUsed(), config); err != nil {
			return nil, fmt.Errorf("failed to load config file: %w", err)
		}
	}

	// Override with command-line flags
	if workingDir, _ := cmd.Flags().GetString("terragrunt-working-dir"); workingDir != "" {
		config.WorkingDir = workingDir
	}

	// Resolve working directory
	workingDir, err := filepath.Abs(config.WorkingDir)
	if err != nil {
		return nil, fmt.Errorf("failed to resolve working directory: %w", err)
	}

	ctx := &ExecutionContext{
		Config:       config,
		WorkingDir:   workingDir,
		Command:      cmd.Name(),
		Args:         cmd.Flags().Args(),
		Environment:  mergeEnvironment(os.Environ(), config.Environment),
		StartTime:    time.Now(),
		Logger:       logger,
		Dependencies: make(map[string]interface{}),
		Outputs:      make(map[string]interface{}),
		State:        make(map[string]interface{}),
		errors:       []error{},
	}

	// Check for dry-run mode
	if dryRun, _ := cmd.Flags().GetBool("dry-run"); dryRun {
		ctx.DryRun = true
	}

	// Check for force mode
	if force, _ := cmd.Flags().GetBool("force"); force {
		ctx.Force = true
	}

	return ctx, nil
}

func runInit(cmd *cobra.Command, args []string) error {
	ctx, err := createExecutionContext(cmd)
	if err != nil {
		return err
	}

	logger.Info("Initializing Terraform configuration")

	// Run before hooks
	if err := runHooks(ctx, ctx.Config.Hooks.BeforeHooks, "init"); err != nil {
		logger.Warnf("Before hook failed: %v", err)
	}

	// Check and create backend if needed
	if err := initializeBackend(ctx); err != nil {
		return fmt.Errorf("failed to initialize backend: %w", err)
	}

	// Download dependencies
	if err := downloadDependencies(ctx); err != nil {
		return fmt.Errorf("failed to download dependencies: %w", err)
	}

	// Generate files if needed
	if err := generateFiles(ctx); err != nil {
		return fmt.Errorf("failed to generate files: %w", err)
	}

	// Build terraform init command
	tfArgs := []string{"init"}

	// Add init-specific flags
	if upgrade, _ := cmd.Flags().GetBool("upgrade"); upgrade {
		tfArgs = append(tfArgs, "-upgrade")
	}
	if migrate, _ := cmd.Flags().GetBool("migrate-state"); migrate {
		tfArgs = append(tfArgs, "-migrate-state")
	}
	if reconfigure, _ := cmd.Flags().GetBool("reconfigure"); reconfigure {
		tfArgs = append(tfArgs, "-reconfigure")
	}

	// Add backend config
	if ctx.Config.Backend.Type != "" {
		tfArgs = append(tfArgs, fmt.Sprintf("-backend-config=bucket=%s", ctx.Config.Backend.Bucket))
		tfArgs = append(tfArgs, fmt.Sprintf("-backend-config=prefix=%s", ctx.Config.Backend.Prefix))
	}

	// Execute terraform init
	if err := executeTerraform(ctx, tfArgs...); err != nil {
		// Run error hooks
		runHooks(ctx, ctx.Config.Hooks.ErrorHooks, "init")
		return fmt.Errorf("terraform init failed: %w", err)
	}

	// Run after hooks
	if err := runHooks(ctx, ctx.Config.Hooks.AfterHooks, "init"); err != nil {
		logger.Warnf("After hook failed: %v", err)
	}

	logger.Info("Terraform initialization completed successfully")
	return nil
}

func runPlan(cmd *cobra.Command, args []string) error {
	ctx, err := createExecutionContext(cmd)
	if err != nil {
		return err
	}

	logger.Info("Generating Terraform plan")

	// Auto-init if needed
	if ctx.Config.AutoInit {
		if err := autoInit(ctx); err != nil {
			return fmt.Errorf("auto-init failed: %w", err)
		}
	}

	// Run before hooks
	if err := runHooks(ctx, ctx.Config.Hooks.BeforeHooks, "plan"); err != nil {
		logger.Warnf("Before hook failed: %v", err)
	}

	// Load dependency outputs
	if err := loadDependencyOutputs(ctx); err != nil {
		return fmt.Errorf("failed to load dependency outputs: %w", err)
	}

	// Build terraform plan command
	tfArgs := []string{"plan"}

	// Add plan-specific flags
	if out, _ := cmd.Flags().GetString("out"); out != "" {
		tfArgs = append(tfArgs, fmt.Sprintf("-out=%s", out))
	}
	if destroy, _ := cmd.Flags().GetBool("destroy"); destroy {
		tfArgs = append(tfArgs, "-destroy")
	}
	if refresh, _ := cmd.Flags().GetBool("refresh-only"); refresh {
		tfArgs = append(tfArgs, "-refresh-only")
	}

	// Add targets
	if targets, _ := cmd.Flags().GetStringSlice("target"); len(targets) > 0 {
		for _, target := range targets {
			tfArgs = append(tfArgs, fmt.Sprintf("-target=%s", target))
		}
	}

	// Add replacements
	if replacements, _ := cmd.Flags().GetStringSlice("replace"); len(replacements) > 0 {
		for _, replace := range replacements {
			tfArgs = append(tfArgs, fmt.Sprintf("-replace=%s", replace))
		}
	}

	// Add variables
	if vars, _ := cmd.Flags().GetStringSlice("var"); len(vars) > 0 {
		for _, v := range vars {
			tfArgs = append(tfArgs, fmt.Sprintf("-var=%s", v))
		}
	}

	// Add var-file
	if varFile, _ := cmd.Flags().GetString("var-file"); varFile != "" {
		tfArgs = append(tfArgs, fmt.Sprintf("-var-file=%s", varFile))
	}

	// Add terragrunt variables
	for key, value := range ctx.Config.Variables {
		tfArgs = append(tfArgs, fmt.Sprintf("-var=%s=%v", key, value))
	}

	// Execute terraform plan
	if err := executeTerraform(ctx, tfArgs...); err != nil {
		// Run error hooks
		runHooks(ctx, ctx.Config.Hooks.ErrorHooks, "plan")
		return fmt.Errorf("terraform plan failed: %w", err)
	}

	// Run after hooks
	if err := runHooks(ctx, ctx.Config.Hooks.AfterHooks, "plan"); err != nil {
		logger.Warnf("After hook failed: %v", err)
	}

	logger.Info("Terraform plan completed successfully")
	return nil
}

func runApply(cmd *cobra.Command, args []string) error {
	ctx, err := createExecutionContext(cmd)
	if err != nil {
		return err
	}

	logger.Info("Applying Terraform configuration")

	// Auto-init if needed
	if ctx.Config.AutoInit {
		if err := autoInit(ctx); err != nil {
			return fmt.Errorf("auto-init failed: %w", err)
		}
	}

	// Run before hooks
	if err := runHooks(ctx, ctx.Config.Hooks.BeforeHooks, "apply"); err != nil {
		logger.Warnf("Before hook failed: %v", err)
	}

	// Load dependency outputs
	if err := loadDependencyOutputs(ctx); err != nil {
		return fmt.Errorf("failed to load dependency outputs: %w", err)
	}

	// Build terraform apply command
	tfArgs := []string{"apply"}

	// Add auto-approve flag
	if autoApprove, _ := cmd.Flags().GetBool("auto-approve"); autoApprove || ctx.Config.NonInteractive {
		tfArgs = append(tfArgs, "-auto-approve")
	}

	// Add backup path
	if backup, _ := cmd.Flags().GetString("backup"); backup != "" {
		tfArgs = append(tfArgs, fmt.Sprintf("-backup=%s", backup))
	}

	// Add compact-warnings
	if compact, _ := cmd.Flags().GetBool("compact-warnings"); compact {
		tfArgs = append(tfArgs, "-compact-warnings")
	}

	// Add parallelism
	if parallelism, _ := cmd.Flags().GetInt("parallelism"); parallelism > 0 {
		tfArgs = append(tfArgs, fmt.Sprintf("-parallelism=%d", parallelism))
	}

	// Add targets
	if targets, _ := cmd.Flags().GetStringSlice("target"); len(targets) > 0 {
		for _, target := range targets {
			tfArgs = append(tfArgs, fmt.Sprintf("-target=%s", target))
		}
	}

	// Add replacements
	if replacements, _ := cmd.Flags().GetStringSlice("replace"); len(replacements) > 0 {
		for _, replace := range replacements {
			tfArgs = append(tfArgs, fmt.Sprintf("-replace=%s", replace))
		}
	}

	// Add variables
	if vars, _ := cmd.Flags().GetStringSlice("var"); len(vars) > 0 {
		for _, v := range vars {
			tfArgs = append(tfArgs, fmt.Sprintf("-var=%s", v))
		}
	}

	// Add var-file
	if varFile, _ := cmd.Flags().GetString("var-file"); varFile != "" {
		tfArgs = append(tfArgs, fmt.Sprintf("-var-file=%s", varFile))
	}

	// Add terragrunt variables
	for key, value := range ctx.Config.Variables {
		tfArgs = append(tfArgs, fmt.Sprintf("-var=%s=%v", key, value))
	}

	// Check if we have a plan file
	if len(args) > 0 {
		tfArgs = append(tfArgs, args[0])
	}

	// Execute terraform apply
	if err := executeTerraform(ctx, tfArgs...); err != nil {
		// Run error hooks
		runHooks(ctx, ctx.Config.Hooks.ErrorHooks, "apply")
		return fmt.Errorf("terraform apply failed: %w", err)
	}

	// Save outputs for dependencies
	if err := saveOutputs(ctx); err != nil {
		logger.Warnf("Failed to save outputs: %v", err)
	}

	// Run after hooks
	if err := runHooks(ctx, ctx.Config.Hooks.AfterHooks, "apply"); err != nil {
		logger.Warnf("After hook failed: %v", err)
	}

	logger.Info("Terraform apply completed successfully")
	return nil
}

func runDestroy(cmd *cobra.Command, args []string) error {
	ctx, err := createExecutionContext(cmd)
	if err != nil {
		return err
	}

	logger.Info("Destroying Terraform-managed infrastructure")

	// Auto-init if needed
	if ctx.Config.AutoInit {
		if err := autoInit(ctx); err != nil {
			return fmt.Errorf("auto-init failed: %w", err)
		}
	}

	// Run before hooks
	if err := runHooks(ctx, ctx.Config.Hooks.BeforeHooks, "destroy"); err != nil {
		logger.Warnf("Before hook failed: %v", err)
	}

	// Build terraform destroy command
	tfArgs := []string{"destroy"}

	// Add auto-approve flag
	if autoApprove, _ := cmd.Flags().GetBool("auto-approve"); autoApprove || ctx.Config.NonInteractive {
		tfArgs = append(tfArgs, "-auto-approve")
	}

	// Add backup path
	if backup, _ := cmd.Flags().GetString("backup"); backup != "" {
		tfArgs = append(tfArgs, fmt.Sprintf("-backup=%s", backup))
	}

	// Add targets
	if targets, _ := cmd.Flags().GetStringSlice("target"); len(targets) > 0 {
		for _, target := range targets {
			tfArgs = append(tfArgs, fmt.Sprintf("-target=%s", target))
		}
	}

	// Add variables
	if vars, _ := cmd.Flags().GetStringSlice("var"); len(vars) > 0 {
		for _, v := range vars {
			tfArgs = append(tfArgs, fmt.Sprintf("-var=%s", v))
		}
	}

	// Add var-file
	if varFile, _ := cmd.Flags().GetString("var-file"); varFile != "" {
		tfArgs = append(tfArgs, fmt.Sprintf("-var-file=%s", varFile))
	}

	// Add terragrunt variables
	for key, value := range ctx.Config.Variables {
		tfArgs = append(tfArgs, fmt.Sprintf("-var=%s=%v", key, value))
	}

	// Execute terraform destroy
	if err := executeTerraform(ctx, tfArgs...); err != nil {
		// Run error hooks
		runHooks(ctx, ctx.Config.Hooks.ErrorHooks, "destroy")
		return fmt.Errorf("terraform destroy failed: %w", err)
	}

	// Clean up outputs
	if err := cleanupOutputs(ctx); err != nil {
		logger.Warnf("Failed to cleanup outputs: %v", err)
	}

	// Run after hooks
	if err := runHooks(ctx, ctx.Config.Hooks.AfterHooks, "destroy"); err != nil {
		logger.Warnf("After hook failed: %v", err)
	}

	logger.Info("Terraform destroy completed successfully")
	return nil
}

func runValidate(cmd *cobra.Command, args []string) error {
	ctx, err := createExecutionContext(cmd)
	if err != nil {
		return err
	}

	logger.Info("Validating Terraform configuration")

	// Auto-init if needed
	if ctx.Config.AutoInit {
		if err := autoInit(ctx); err != nil {
			return fmt.Errorf("auto-init failed: %w", err)
		}
	}

	// Execute terraform validate
	if err := executeTerraform(ctx, "validate"); err != nil {
		return fmt.Errorf("terraform validate failed: %w", err)
	}

	logger.Info("Terraform configuration is valid")
	return nil
}

func runOutput(cmd *cobra.Command, args []string) error {
	ctx, err := createExecutionContext(cmd)
	if err != nil {
		return err
	}

	// Build terraform output command
	tfArgs := []string{"output"}

	// Add JSON flag
	if jsonOutput, _ := cmd.Flags().GetBool("json"); jsonOutput {
		tfArgs = append(tfArgs, "-json")
	}

	// Add raw flag
	if raw, _ := cmd.Flags().GetBool("raw"); raw {
		tfArgs = append(tfArgs, "-raw")
	}

	// Add state file
	if stateFile, _ := cmd.Flags().GetString("state"); stateFile != "" {
		tfArgs = append(tfArgs, fmt.Sprintf("-state=%s", stateFile))
	}

	// Add specific output name if provided
	if len(args) > 0 {
		tfArgs = append(tfArgs, args[0])
	}

	// Execute terraform output
	if err := executeTerraform(ctx, tfArgs...); err != nil {
		return fmt.Errorf("terraform output failed: %w", err)
	}

	return nil
}

func runPlanAll(cmd *cobra.Command, args []string) error {
	return runAllCommand(cmd, args, "plan")
}

func runApplyAll(cmd *cobra.Command, args []string) error {
	return runAllCommand(cmd, args, "apply")
}

func runDestroyAll(cmd *cobra.Command, args []string) error {
	return runAllCommand(cmd, args, "destroy")
}

func runAllCommand(cmd *cobra.Command, args []string, command string) error {
	ctx, err := createExecutionContext(cmd)
	if err != nil {
		return err
	}

	logger.Infof("Running %s on all modules", command)

	// Find all modules with terragrunt.hcl files
	modules, err := findModules(ctx)
	if err != nil {
		return fmt.Errorf("failed to find modules: %w", err)
	}

	logger.Infof("Found %d modules", len(modules))

	// Build dependency graph
	graph, err := buildDependencyGraph(ctx, modules)
	if err != nil {
		return fmt.Errorf("failed to build dependency graph: %w", err)
	}

	// Get execution order
	executionOrder, err := topologicalSort(graph)
	if err != nil {
		return fmt.Errorf("failed to determine execution order: %w", err)
	}

	// Execute command on each module
	var wg sync.WaitGroup
	semaphore := make(chan struct{}, ctx.Config.Parallelism)
	errorChan := make(chan error, len(executionOrder))

	for _, module := range executionOrder {
		wg.Add(1)
		go func(mod string) {
			defer wg.Done()
			semaphore <- struct{}{}
			defer func() { <-semaphore }()

			logger.Infof("Running %s on module: %s", command, mod)

			// Change to module directory
			moduleCtx := *ctx
			moduleCtx.WorkingDir = mod

			// Execute command
			var err error
			switch command {
			case "plan":
				err = executeTerraform(&moduleCtx, "plan")
			case "apply":
				err = executeTerraform(&moduleCtx, "apply", "-auto-approve")
			case "destroy":
				err = executeTerraform(&moduleCtx, "destroy", "-auto-approve")
			default:
				err = fmt.Errorf("unsupported command: %s", command)
			}

			if err != nil {
				errorChan <- fmt.Errorf("module %s: %w", mod, err)
			}
		}(module)
	}

	wg.Wait()
	close(errorChan)

	// Collect errors
	var errors []error
	for err := range errorChan {
		errors = append(errors, err)
	}

	if len(errors) > 0 {
		for _, err := range errors {
			logger.Error(err)
		}
		return fmt.Errorf("%d modules failed", len(errors))
	}

	logger.Infof("Successfully ran %s on all modules", command)
	return nil
}

func runHCLFormat(cmd *cobra.Command, args []string) error {
	ctx, err := createExecutionContext(cmd)
	if err != nil {
		return err
	}

	logger.Info("Formatting HCL files")

	check, _ := cmd.Flags().GetBool("check")
	diff, _ := cmd.Flags().GetBool("diff")
	write, _ := cmd.Flags().GetBool("write")

	// Find all HCL files
	files, err := findHCLFiles(ctx.WorkingDir)
	if err != nil {
		return fmt.Errorf("failed to find HCL files: %w", err)
	}

	logger.Infof("Found %d HCL files", len(files))

	// Format each file
	needsFormatting := false
	for _, file := range files {
		formatted, changed, err := formatHCLFile(file, check, diff, write)
		if err != nil {
			logger.Errorf("Failed to format %s: %v", file, err)
			continue
		}

		if changed {
			needsFormatting = true
			if check {
				logger.Warnf("File needs formatting: %s", file)
			} else if write {
				logger.Infof("Formatted: %s", file)
			}

			if diff {
				fmt.Println(formatted)
			}
		}
	}

	if check && needsFormatting {
		return fmt.Errorf("HCL files need formatting")
	}

	logger.Info("HCL formatting completed")
	return nil
}

func runGraphDependencies(cmd *cobra.Command, args []string) error {
	ctx, err := createExecutionContext(cmd)
	if err != nil {
		return err
	}

	logger.Info("Generating dependency graph")

	// Find all modules
	modules, err := findModules(ctx)
	if err != nil {
		return fmt.Errorf("failed to find modules: %w", err)
	}

	// Build dependency graph
	graph, err := buildDependencyGraph(ctx, modules)
	if err != nil {
		return fmt.Errorf("failed to build dependency graph: %w", err)
	}

	// Get output format
	format, _ := cmd.Flags().GetString("format")
	output, _ := cmd.Flags().GetString("output")

	// Generate graph representation
	var result string
	switch format {
	case "dot":
		result = generateDotGraph(graph)
	case "json":
		data, err := json.MarshalIndent(graph, "", "  ")
		if err != nil {
			return fmt.Errorf("failed to marshal graph: %w", err)
		}
		result = string(data)
	case "mermaid":
		result = generateMermaidGraph(graph)
	default:
		return fmt.Errorf("unsupported format: %s", format)
	}

	// Write output
	if output != "" {
		if err := os.WriteFile(output, []byte(result), 0644); err != nil {
			return fmt.Errorf("failed to write output: %w", err)
		}
		logger.Infof("Graph written to %s", output)
	} else {
		fmt.Println(result)
	}

	return nil
}

func runRenderJSON(cmd *cobra.Command, args []string) error {
	ctx, err := createExecutionContext(cmd)
	if err != nil {
		return err
	}

	logger.Info("Rendering configuration as JSON")

	// Marshal configuration to JSON
	data, err := json.MarshalIndent(ctx.Config, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal configuration: %w", err)
	}

	fmt.Println(string(data))
	return nil
}

func runAWSProviderPatch(cmd *cobra.Command, args []string) error {
	// This would patch AWS provider configuration
	logger.Info("AWS provider patch not implemented in GCP-focused version")
	return nil
}

func runScaffold(cmd *cobra.Command, args []string) error {
	ctx, err := createExecutionContext(cmd)
	if err != nil {
		return err
	}

	template, _ := cmd.Flags().GetString("template")
	name, _ := cmd.Flags().GetString("name")
	path, _ := cmd.Flags().GetString("path")
	withExamples, _ := cmd.Flags().GetBool("with-examples")
	withTests, _ := cmd.Flags().GetBool("with-tests")

	if name == "" {
		return fmt.Errorf("module name is required")
	}

	if path == "" {
		path = filepath.Join(ctx.WorkingDir, name)
	}

	logger.Infof("Scaffolding new module: %s", name)

	// Create module directory
	if err := os.MkdirAll(path, 0755); err != nil {
		return fmt.Errorf("failed to create module directory: %w", err)
	}

	// Generate main.tf
	mainTF := generateMainTF(template, name)
	if err := os.WriteFile(filepath.Join(path, "main.tf"), []byte(mainTF), 0644); err != nil {
		return fmt.Errorf("failed to write main.tf: %w", err)
	}

	// Generate variables.tf
	variablesTF := generateVariablesTF(template, name)
	if err := os.WriteFile(filepath.Join(path, "variables.tf"), []byte(variablesTF), 0644); err != nil {
		return fmt.Errorf("failed to write variables.tf: %w", err)
	}

	// Generate outputs.tf
	outputsTF := generateOutputsTF(template, name)
	if err := os.WriteFile(filepath.Join(path, "outputs.tf"), []byte(outputsTF), 0644); err != nil {
		return fmt.Errorf("failed to write outputs.tf: %w", err)
	}

	// Generate terragrunt.hcl
	terragruntHCL := generateTerragruntHCL(template, name)
	if err := os.WriteFile(filepath.Join(path, "terragrunt.hcl"), []byte(terragruntHCL), 0644); err != nil {
		return fmt.Errorf("failed to write terragrunt.hcl: %w", err)
	}

	// Generate README.md
	readme := generateREADME(name)
	if err := os.WriteFile(filepath.Join(path, "README.md"), []byte(readme), 0644); err != nil {
		return fmt.Errorf("failed to write README.md: %w", err)
	}

	// Generate examples if requested
	if withExamples {
		examplesDir := filepath.Join(path, "examples")
		if err := os.MkdirAll(examplesDir, 0755); err != nil {
			return fmt.Errorf("failed to create examples directory: %w", err)
		}

		exampleTF := generateExampleTF(name)
		if err := os.WriteFile(filepath.Join(examplesDir, "main.tf"), []byte(exampleTF), 0644); err != nil {
			return fmt.Errorf("failed to write example: %w", err)
		}
	}

	// Generate tests if requested
	if withTests {
		testsDir := filepath.Join(path, "tests")
		if err := os.MkdirAll(testsDir, 0755); err != nil {
			return fmt.Errorf("failed to create tests directory: %w", err)
		}

		testGo := generateTestGo(name)
		if err := os.WriteFile(filepath.Join(testsDir, "main_test.go"), []byte(testGo), 0644); err != nil {
			return fmt.Errorf("failed to write test: %w", err)
		}
	}

	logger.Infof("Module scaffolded successfully at %s", path)
	return nil
}

// Helper functions

func executeTerraform(ctx *ExecutionContext, args ...string) error {
	// Find terraform binary
	terraformPath := ctx.Config.TerraformPath
	if terraformPath == "" {
		terraformPath = "terraform"
	}

	// Check if terraform exists
	if _, err := exec.LookPath(terraformPath); err != nil {
		// Try to download terraform if configured
		if ctx.Config.TerraformBinary.AutoDownload {
			if err := downloadTerraform(ctx); err != nil {
				return fmt.Errorf("failed to download terraform: %w", err)
			}
		} else {
			return fmt.Errorf("terraform not found: %w", err)
		}
	}

	// Build command
	cmd := exec.CommandContext(context.Background(), terraformPath, args...)
	cmd.Dir = ctx.WorkingDir
	cmd.Env = envToSlice(ctx.Environment)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	// Execute with retry logic
	var lastErr error
	for attempt := 0; attempt <= ctx.Config.RetryAttempts; attempt++ {
		if attempt > 0 {
			logger.Infof("Retrying terraform command (attempt %d/%d)", attempt, ctx.Config.RetryAttempts)
			time.Sleep(ctx.Config.RetryDelay * time.Duration(attempt))
		}

		if ctx.DryRun {
			logger.Infof("DRY RUN: would execute: %s %s", terraformPath, strings.Join(args, " "))
			return nil
		}

		err := cmd.Run()
		if err == nil {
			return nil
		}

		lastErr = err

		// Check if error is retryable
		if !isRetryableError(err, ctx.Config.ErrorHandling.RetryableErrors) {
			return err
		}
	}

	return fmt.Errorf("terraform command failed after %d attempts: %w", ctx.Config.RetryAttempts, lastErr)
}

func autoInit(ctx *ExecutionContext) error {
	// Check if .terraform directory exists
	terraformDir := filepath.Join(ctx.WorkingDir, ".terraform")
	if _, err := os.Stat(terraformDir); os.IsNotExist(err) {
		logger.Info("Running terraform init (auto-init)")
		return executeTerraform(ctx, "init", "-input=false")
	}
	return nil
}

func runHooks(ctx *ExecutionContext, hooks []HookConfig, command string) error {
	for _, hook := range hooks {
		// Check if hook should run for this command
		shouldRun := false
		for _, cmd := range hook.Commands {
			if cmd == command || cmd == "all" {
				shouldRun = true
				break
			}
		}

		if !shouldRun {
			continue
		}

		logger.Infof("Running hook: %s", hook.Name)

		for _, execute := range hook.Execute {
			parts := strings.Fields(execute)
			if len(parts) == 0 {
				continue
			}

			cmd := exec.Command(parts[0], parts[1:]...)
			cmd.Dir = hook.WorkingDir
			if cmd.Dir == "" {
				cmd.Dir = ctx.WorkingDir
			}
			cmd.Env = envToSlice(ctx.Environment)
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr

			if err := cmd.Run(); err != nil {
				if !hook.RunOnError {
					return fmt.Errorf("hook %s failed: %w", hook.Name, err)
				}
				logger.Warnf("Hook %s failed but continuing: %v", hook.Name, err)
			}
		}
	}

	return nil
}

func loadConfigFile(path string, config *TerragruntConfig) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	// Parse HCL or JSON based on extension
	if strings.HasSuffix(path, ".json") {
		return json.Unmarshal(data, config)
	}

	// For HCL parsing, we would use hcl package
	// This is simplified for now
	return nil
}

func initializeBackend(ctx *ExecutionContext) error {
	if ctx.Config.Backend.Type == "" {
		return nil
	}

	switch ctx.Config.Backend.Type {
	case "gcs":
		return gcp.CreateBucketIfNotExists(ctx.Config.Backend.Bucket, ctx.Config.GCP.Project)
	default:
		return fmt.Errorf("unsupported backend type: %s", ctx.Config.Backend.Type)
	}
}

func downloadDependencies(ctx *ExecutionContext) error {
	for _, dep := range ctx.Config.Dependencies {
		if !dep.Enabled {
			continue
		}

		logger.Infof("Downloading dependency: %s", dep.Name)

		// Implementation would download remote configurations
		// For now, this is a stub
	}
	return nil
}

func generateFiles(ctx *ExecutionContext) error {
	// Generate backend.tf if needed
	if ctx.Config.RemoteState.Generate != nil {
		backendTF := generateBackendTF(ctx.Config)
		if err := os.WriteFile(filepath.Join(ctx.WorkingDir, "backend.tf"), []byte(backendTF), 0644); err != nil {
			return fmt.Errorf("failed to generate backend.tf: %w", err)
		}
	}
	return nil
}

func loadDependencyOutputs(ctx *ExecutionContext) error {
	for _, dep := range ctx.Config.Dependencies {
		if !dep.Enabled || dep.SkipOutputs {
			continue
		}

		if dep.MockOutputs != nil {
			// Use mock outputs
			for key, value := range dep.MockOutputs {
				ctx.Dependencies[fmt.Sprintf("%s.%s", dep.Name, key)] = value
			}
			continue
		}

		// Load real outputs from dependency
		// This would execute terraform output -json in the dependency directory
		// For now, this is a stub
	}
	return nil
}

func saveOutputs(ctx *ExecutionContext) error {
	// Execute terraform output -json
	cmd := exec.Command(ctx.Config.TerraformPath, "output", "-json")
	cmd.Dir = ctx.WorkingDir
	output, err := cmd.Output()
	if err != nil {
		return err
	}

	// Parse outputs
	var outputs map[string]interface{}
	if err := json.Unmarshal(output, &outputs); err != nil {
		return err
	}

	ctx.Outputs = outputs

	// Save to cache if enabled
	if ctx.Config.Cache.Enabled {
		cacheFile := filepath.Join(ctx.Config.Cache.Dir, fmt.Sprintf("%s-outputs.json", ctx.WorkingDir))
		if err := os.WriteFile(cacheFile, output, 0644); err != nil {
			logger.Warnf("Failed to cache outputs: %v", err)
		}
	}

	return nil
}

func cleanupOutputs(ctx *ExecutionContext) error {
	if ctx.Config.Cache.Enabled {
		cacheFile := filepath.Join(ctx.Config.Cache.Dir, fmt.Sprintf("%s-outputs.json", ctx.WorkingDir))
		if err := os.Remove(cacheFile); err != nil && !os.IsNotExist(err) {
			return err
		}
	}
	return nil
}

func findModules(ctx *ExecutionContext) ([]string, error) {
	var modules []string

	err := filepath.Walk(ctx.WorkingDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		// Skip if in exclude list
		for _, exclude := range ctx.Config.ExcludeDirs {
			if strings.Contains(path, exclude) {
				return filepath.SkipDir
			}
		}

		// Check if terragrunt.hcl exists
		if info.Name() == "terragrunt.hcl" {
			dir := filepath.Dir(path)

			// Check if in include list (if specified)
			if len(ctx.Config.IncludeDirs) > 0 {
				included := false
				for _, include := range ctx.Config.IncludeDirs {
					if strings.Contains(dir, include) {
						included = true
						break
					}
				}
				if !included {
					return nil
				}
			}

			modules = append(modules, dir)
		}

		return nil
	})

	return modules, err
}

func buildDependencyGraph(ctx *ExecutionContext, modules []string) (map[string][]string, error) {
	graph := make(map[string][]string)

	for _, module := range modules {
		// Parse terragrunt.hcl to find dependencies
		// This is simplified - real implementation would parse HCL
		graph[module] = []string{}
	}

	return graph, nil
}

func topologicalSort(graph map[string][]string) ([]string, error) {
	// Simplified topological sort
	var result []string
	visited := make(map[string]bool)

	var visit func(string) error
	visit = func(node string) error {
		if visited[node] {
			return nil
		}
		visited[node] = true

		for _, dep := range graph[node] {
			if err := visit(dep); err != nil {
				return err
			}
		}

		result = append(result, node)
		return nil
	}

	for node := range graph {
		if err := visit(node); err != nil {
			return nil, err
		}
	}

	// Reverse for correct execution order
	for i, j := 0, len(result)-1; i < j; i, j = i+1, j-1 {
		result[i], result[j] = result[j], result[i]
	}

	return result, nil
}

func findHCLFiles(dir string) ([]string, error) {
	var files []string

	err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if strings.HasSuffix(path, ".hcl") || strings.HasSuffix(path, ".tf") {
			files = append(files, path)
		}

		return nil
	})

	return files, err
}

func formatHCLFile(path string, check, diff, write bool) (string, bool, error) {
	// This would use hcl formatter
	// For now, return stub
	return "", false, nil
}

func generateDotGraph(graph map[string][]string) string {
	var result strings.Builder
	result.WriteString("digraph dependencies {\n")
	result.WriteString("  rankdir=TB;\n")
	result.WriteString("  node [shape=box];\n")

	for node, deps := range graph {
		nodeName := filepath.Base(node)
		for _, dep := range deps {
			depName := filepath.Base(dep)
			result.WriteString(fmt.Sprintf("  \"%s\" -> \"%s\";\n", nodeName, depName))
		}
	}

	result.WriteString("}\n")
	return result.String()
}

func generateMermaidGraph(graph map[string][]string) string {
	var result strings.Builder
	result.WriteString("graph TD\n")

	for node, deps := range graph {
		nodeName := filepath.Base(node)
		for _, dep := range deps {
			depName := filepath.Base(dep)
			result.WriteString(fmt.Sprintf("  %s --> %s\n", nodeName, depName))
		}
	}

	return result.String()
}

func downloadTerraform(ctx *ExecutionContext) error {
	ctx.Logger.Info("Downloading Terraform binary")

	// Determine required version from config or use latest
	version := "latest"
	if ctx.Config != nil && ctx.Config.TerraformVersion != "" {
		version = ctx.Config.TerraformVersion
	}

	// Detect OS and architecture
	goos := runtime.GOOS
	goarch := runtime.GOARCH

	// Map architecture names to Terraform's naming
	arch := goarch
	if goarch == "amd64" {
		arch = "amd64"
	} else if goarch == "arm64" {
		arch = "arm64"
	} else if goarch == "386" {
		arch = "386"
	}

	// If version is "latest", fetch it from HashiCorp releases API
	if version == "latest" {
		latestVersion, err := getLatestTerraformVersion()
		if err != nil {
			return fmt.Errorf("failed to get latest terraform version: %w", err)
		}
		version = latestVersion
	}

	// Construct download URL
	filename := fmt.Sprintf("terraform_%s_%s_%s.zip", version, goos, arch)
	downloadURL := fmt.Sprintf("https://releases.hashicorp.com/terraform/%s/%s", version, filename)

	ctx.Logger.Infof("Downloading Terraform %s for %s/%s", version, goos, arch)

	// Create temporary directory for download
	tmpDir, err := os.MkdirTemp("", "terraform-download-*")
	if err != nil {
		return fmt.Errorf("failed to create temp directory: %w", err)
	}
	defer os.RemoveAll(tmpDir)

	// Download the zip file
	zipPath := filepath.Join(tmpDir, filename)
	if err := downloadFile(downloadURL, zipPath); err != nil {
		return fmt.Errorf("failed to download terraform: %w", err)
	}

	ctx.Logger.Info("Extracting Terraform binary")

	// Extract the binary
	if err := extractZip(zipPath, tmpDir); err != nil {
		return fmt.Errorf("failed to extract terraform: %w", err)
	}

	// Determine installation directory
	installDir := filepath.Join(os.Getenv("HOME"), ".terragrunt", "terraform", version)
	if err := os.MkdirAll(installDir, 0755); err != nil {
		return fmt.Errorf("failed to create install directory: %w", err)
	}

	// Move binary to installation directory
	srcBinary := filepath.Join(tmpDir, "terraform")
	if runtime.GOOS == "windows" {
		srcBinary += ".exe"
	}

	dstBinary := filepath.Join(installDir, filepath.Base(srcBinary))
	if err := os.Rename(srcBinary, dstBinary); err != nil {
		// Try copying if rename fails (cross-device link)
		if err := copyFile(srcBinary, dstBinary); err != nil {
			return fmt.Errorf("failed to install terraform: %w", err)
		}
	}

	// Make binary executable
	if err := os.Chmod(dstBinary, 0755); err != nil {
		return fmt.Errorf("failed to make terraform executable: %w", err)
	}

	ctx.Logger.Infof("Terraform %s installed successfully to %s", version, dstBinary)

	// Update PATH in context if needed
	if ctx.Environment == nil {
		ctx.Environment = make(map[string]string)
	}
	ctx.Environment["PATH"] = fmt.Sprintf("%s%c%s", installDir, os.PathListSeparator, os.Getenv("PATH"))

	return nil
}

// getLatestTerraformVersion fetches the latest Terraform version from HashiCorp's API
func getLatestTerraformVersion() (string, error) {
	resp, err := http.Get("https://checkpoint-api.hashicorp.com/v1/check/terraform")
	if err != nil {
		return "", fmt.Errorf("failed to fetch version info: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var result struct {
		CurrentVersion string `json:"current_version"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", fmt.Errorf("failed to parse version info: %w", err)
	}

	return result.CurrentVersion, nil
}

// downloadFile downloads a file from URL to destination
func downloadFile(url string, dest string) error {
	resp, err := http.Get(url)
	if err != nil {
		return fmt.Errorf("failed to download: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("download failed with status: %d", resp.StatusCode)
	}

	out, err := os.Create(dest)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}
	defer out.Close()

	if _, err := io.Copy(out, resp.Body); err != nil {
		return fmt.Errorf("failed to write file: %w", err)
	}

	return nil
}

// extractZip extracts a zip file to destination directory
func extractZip(src string, dest string) error {
	r, err := zip.OpenReader(src)
	if err != nil {
		return fmt.Errorf("failed to open zip: %w", err)
	}
	defer r.Close()

	for _, f := range r.File {
		fpath := filepath.Join(dest, f.Name)

		// Check for ZipSlip vulnerability
		if !strings.HasPrefix(fpath, filepath.Clean(dest)+string(os.PathSeparator)) {
			return fmt.Errorf("illegal file path: %s", fpath)
		}

		if f.FileInfo().IsDir() {
			os.MkdirAll(fpath, os.ModePerm)
			continue
		}

		if err := os.MkdirAll(filepath.Dir(fpath), os.ModePerm); err != nil {
			return fmt.Errorf("failed to create directory: %w", err)
		}

		outFile, err := os.OpenFile(fpath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, f.Mode())
		if err != nil {
			return fmt.Errorf("failed to create file: %w", err)
		}

		rc, err := f.Open()
		if err != nil {
			outFile.Close()
			return fmt.Errorf("failed to open zip entry: %w", err)
		}

		if _, err := io.Copy(outFile, rc); err != nil {
			outFile.Close()
			rc.Close()
			return fmt.Errorf("failed to extract file: %w", err)
		}

		outFile.Close()
		rc.Close()
	}

	return nil
}

// copyFile copies a file from src to dst
func copyFile(src string, dst string) error {
	sourceFile, err := os.Open(src)
	if err != nil {
		return fmt.Errorf("failed to open source: %w", err)
	}
	defer sourceFile.Close()

	destFile, err := os.Create(dst)
	if err != nil {
		return fmt.Errorf("failed to create destination: %w", err)
	}
	defer destFile.Close()

	if _, err := io.Copy(destFile, sourceFile); err != nil {
		return fmt.Errorf("failed to copy: %w", err)
	}

	// Copy file permissions
	sourceInfo, err := os.Stat(src)
	if err != nil {
		return fmt.Errorf("failed to get source info: %w", err)
	}

	if err := os.Chmod(dst, sourceInfo.Mode()); err != nil {
		return fmt.Errorf("failed to set permissions: %w", err)
	}

	return nil
}

func getTerraformVersion() string {
	cmd := exec.Command("terraform", "version", "-json")
	output, err := cmd.Output()
	if err != nil {
		return ""
	}

	var version struct {
		TerraformVersion string `json:"terraform_version"`
	}
	if err := json.Unmarshal(output, &version); err != nil {
		return ""
	}

	return version.TerraformVersion
}

func isRetryableError(err error, patterns []string) bool {
	errStr := err.Error()
	for _, pattern := range patterns {
		if strings.Contains(errStr, pattern) {
			return true
		}
	}
	return false
}

func mergeEnvironment(base []string, override map[string]string) map[string]string {
	env := make(map[string]string)

	// Parse base environment
	for _, e := range base {
		parts := strings.SplitN(e, "=", 2)
		if len(parts) == 2 {
			env[parts[0]] = parts[1]
		}
	}

	// Apply overrides
	for key, value := range override {
		env[key] = value
	}

	return env
}

func envToSlice(env map[string]string) []string {
	var result []string
	for key, value := range env {
		result = append(result, fmt.Sprintf("%s=%s", key, value))
	}
	return result
}

// Template generation functions

func generateBackendTF(config *TerragruntConfig) string {
	return fmt.Sprintf(`terraform {
  backend "%s" {
    bucket = "%s"
    prefix = "%s"
  }
}
`, config.Backend.Type, config.Backend.Bucket, config.Backend.Prefix)
}

func generateMainTF(template, name string) string {
	return fmt.Sprintf(`# %s module

resource "google_compute_instance" "example" {
  name         = "%s-instance"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.boot_image
    }
  }

  network_interface {
    network = var.network
    access_config {
      // Ephemeral public IP
    }
  }

  tags = var.tags

  labels = var.labels
}
`, name, name)
}

func generateVariablesTF(template, name string) string {
	return `variable "machine_type" {
  description = "The machine type for the instance"
  type        = string
  default     = "e2-micro"
}

variable "zone" {
  description = "The zone for the instance"
  type        = string
}

variable "boot_image" {
  description = "The boot disk image"
  type        = string
  default     = "debian-cloud/debian-11"
}

variable "network" {
  description = "The network to attach the instance to"
  type        = string
  default     = "default"
}

variable "tags" {
  description = "Network tags for the instance"
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Labels for the instance"
  type        = map(string)
  default     = {}
}
`
}

func generateOutputsTF(template, name string) string {
	return fmt.Sprintf(`output "instance_id" {
  description = "The ID of the instance"
  value       = google_compute_instance.example.id
}

output "instance_name" {
  description = "The name of the instance"
  value       = google_compute_instance.example.name
}

output "instance_self_link" {
  description = "The self link of the instance"
  value       = google_compute_instance.example.self_link
}

output "instance_network_ip" {
  description = "The internal IP of the instance"
  value       = google_compute_instance.example.network_interface[0].network_ip
}
`)
}

func generateTerragruntHCL(template, name string) string {
	return `include "root" {
  path = find_in_parent_folders()
}

locals {
  environment = "dev"
  project_id  = "my-project"
}

inputs = {
  zone = "us-central1-a"

  tags = [
    local.environment,
    "managed-by-terragrunt"
  ]

  labels = {
    environment = local.environment
    project     = local.project_id
    managed_by  = "terragrunt"
  }
}
`
}

func generateREADME(name string) string {
	return fmt.Sprintf(`# %s Module

This module manages [describe what this module does].

## Usage

%s%s%s

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| machine_type | The machine type for the instance | string | e2-micro | no |
| zone | The zone for the instance | string | - | yes |
| boot_image | The boot disk image | string | debian-cloud/debian-11 | no |
| network | The network to attach the instance to | string | default | no |
| tags | Network tags for the instance | list(string) | [] | no |
| labels | Labels for the instance | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | The ID of the instance |
| instance_name | The name of the instance |
| instance_self_link | The self link of the instance |
| instance_network_ip | The internal IP of the instance |
`, name, "```hcl\n", "module \""+name+"\" {\n  source = \"./"+name+"\"\n  \n  zone = \"us-central1-a\"\n}\n", "```\n")
}

func generateExampleTF(name string) string {
	return fmt.Sprintf(`module "%s_example" {
  source = "../"

  zone = "us-central1-a"

  tags = ["example", "test"]

  labels = {
    environment = "test"
    example     = "true"
  }
}

output "example_instance_id" {
  value = module.%s_example.instance_id
}
`, name, name)
}

func generateTestGo(name string) string {
	return fmt.Sprintf(`package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformModule(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../examples",

		Vars: map[string]interface{}{
			"zone": "us-central1-a",
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	instanceID := terraform.Output(t, terraformOptions, "example_instance_id")
	assert.NotEmpty(t, instanceID)
}
`, name)
}

func handleSignals() {
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	go func() {
		<-sigChan
		logger.Info("Received interrupt signal, cleaning up...")
		os.Exit(1)
	}()
}

func main() {
	handleSignals()

	if err := rootCmd.Execute(); err != nil {
		logger.Error(err)
		os.Exit(1)
	}
}
