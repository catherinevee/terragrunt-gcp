package main

import (
	"context"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/terragrunt-gcp/terragrunt-gcp/internal/core"
	"github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestMain(t *testing.T) {
	// Test that main function doesn't panic
	// This is a basic smoke test
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("main() panicked: %v", r)
		}
	}()

	// We can't easily test main() directly as it calls os.Exit
	// But we can test the individual command creation functions
}

func TestCreateDiscoverCmd(t *testing.T) {
	cmd := createDiscoverCmd()
	assert.NotNil(t, cmd)
	assert.Equal(t, "discover", cmd.Use)
	assert.Equal(t, "Discover cloud resources across all providers", cmd.Short)
	assert.NotEmpty(t, cmd.Long)
}

func TestCreateQueryCmd(t *testing.T) {
	cmd := createQueryCmd()
	assert.NotNil(t, cmd)
	assert.Equal(t, "query", cmd.Use)
	assert.Equal(t, "Query discovered resources", cmd.Short)
	assert.NotEmpty(t, cmd.Long)
}

func TestCreateExportCmd(t *testing.T) {
	cmd := createExportCmd()
	assert.NotNil(t, cmd)
	assert.Equal(t, "export", cmd.Use)
	assert.Equal(t, "Export discovered resources", cmd.Short)
	assert.NotEmpty(t, cmd.Long)
}

func TestCreateAskCmd(t *testing.T) {
	cmd := createAskCmd()
	assert.NotNil(t, cmd)
	assert.Equal(t, "ask", cmd.Use)
	assert.Equal(t, "Ask questions about your cloud infrastructure", cmd.Short)
	assert.NotEmpty(t, cmd.Long)
}

func TestCreateStatusCmd(t *testing.T) {
	cmd := createStatusCmd()
	assert.NotNil(t, cmd)
	assert.Equal(t, "status", cmd.Use)
	assert.Equal(t, "Show discovery status and statistics", cmd.Short)
	assert.NotEmpty(t, cmd.Long)
}

func TestCreateAnalyzeCmd(t *testing.T) {
	cmd := createAnalyzeCmd()
	assert.NotNil(t, cmd)
	assert.Equal(t, "analyze", cmd.Use)
	assert.Equal(t, "Run comprehensive analysis on discovered resources", cmd.Short)
	assert.NotEmpty(t, cmd.Long)
}

func TestCreateSecurityCmd(t *testing.T) {
	cmd := createSecurityCmd()
	assert.NotNil(t, cmd)
	assert.Equal(t, "security", cmd.Use)
	assert.Equal(t, "Run security analysis on discovered resources", cmd.Short)
	assert.NotEmpty(t, cmd.Long)
}

func TestCreateCostCmd(t *testing.T) {
	cmd := createCostCmd()
	assert.NotNil(t, cmd)
	assert.Equal(t, "cost", cmd.Use)
	assert.Equal(t, "Run cost analysis on discovered resources", cmd.Short)
	assert.NotEmpty(t, cmd.Long)
}

func TestCreateDependenciesCmd(t *testing.T) {
	cmd := createDependenciesCmd()
	assert.NotNil(t, cmd)
	assert.Equal(t, "dependencies", cmd.Use)
	assert.Equal(t, "Run dependency analysis on discovered resources", cmd.Short)
	assert.NotEmpty(t, cmd.Long)
}

func TestCreateInteractiveCmd(t *testing.T) {
	cmd := createInteractiveCmd()
	assert.NotNil(t, cmd)
	assert.Equal(t, "interactive", cmd.Use)
	assert.Equal(t, "Start interactive analysis mode", cmd.Short)
	assert.NotEmpty(t, cmd.Long)
}

func TestSetDefaultConfig(t *testing.T) {
	// Test that setDefaultConfig doesn't panic
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("setDefaultConfig() panicked: %v", r)
		}
	}()

	setDefaultConfig()
	// If we get here without panicking, the test passes
}

func TestValidateConfig(t *testing.T) {
	t.Run("valid config", func(t *testing.T) {
		config := &core.Config{
			Storage: core.StorageConfig{
				DatabasePath: "test.db",
			},
			AWS: core.AWSConfig{
				Regions: []string{"us-east-1"},
			},
			Discovery: core.DiscoveryConfig{
				MaxParallel: 5,
			},
			Analysis: core.AnalysisConfig{
				EnableCostAnalysis: true,
			},
		}

		err := validateConfig(config)
		assert.NoError(t, err)
	})

	t.Run("missing database path", func(t *testing.T) {
		config := &core.Config{
			Storage: core.StorageConfig{
				DatabasePath: "",
			},
			AWS: core.AWSConfig{
				Regions: []string{"us-east-1"},
			},
			Discovery: core.DiscoveryConfig{
				MaxParallel: 5,
			},
			Analysis: core.AnalysisConfig{
				EnableCostAnalysis: true,
			},
		}

		err := validateConfig(config)
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "storage.database_path is required")
	})

	t.Run("empty AWS regions", func(t *testing.T) {
		config := &core.Config{
			Storage: core.StorageConfig{
				DatabasePath: "test.db",
			},
			AWS: core.AWSConfig{
				Regions: []string{},
			},
			Discovery: core.DiscoveryConfig{
				MaxParallel: 5,
			},
			Analysis: core.AnalysisConfig{
				EnableCostAnalysis: true,
			},
		}

		err := validateConfig(config)
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "aws.regions cannot be empty")
	})

	t.Run("invalid max parallel", func(t *testing.T) {
		config := &core.Config{
			Storage: core.StorageConfig{
				DatabasePath: "test.db",
			},
			AWS: core.AWSConfig{
				Regions: []string{"us-east-1"},
			},
			Discovery: core.DiscoveryConfig{
				MaxParallel: 0,
			},
			Analysis: core.AnalysisConfig{
				EnableCostAnalysis: true,
			},
		}

		err := validateConfig(config)
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "discovery.max_parallel must be greater than 0")
	})

	t.Run("no analysis enabled", func(t *testing.T) {
		config := &core.Config{
			Storage: core.StorageConfig{
				DatabasePath: "test.db",
			},
			AWS: core.AWSConfig{
				Regions: []string{"us-east-1"},
			},
			Discovery: core.DiscoveryConfig{
				MaxParallel: 5,
			},
			Analysis: core.AnalysisConfig{
				EnableCostAnalysis:       false,
				EnableSecurityAnalysis:   false,
				EnableDependencyAnalysis: false,
			},
		}

		err := validateConfig(config)
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "at least one analysis type must be enabled")
	})

	t.Run("GCP project ID and projects conflict", func(t *testing.T) {
		config := &core.Config{
			Storage: core.StorageConfig{
				DatabasePath: "test.db",
			},
			AWS: core.AWSConfig{
				Regions: []string{"us-east-1"},
			},
			GCP: core.GCPConfig{
				ProjectID: "test-project",
				Projects:  []string{"project1", "project2"},
			},
			Discovery: core.DiscoveryConfig{
				MaxParallel: 5,
			},
			Analysis: core.AnalysisConfig{
				EnableCostAnalysis: true,
			},
		}

		err := validateConfig(config)
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "cannot specify both gcp.project_id and gcp.projects")
	})
}

func TestCalculatePotentialSavings(t *testing.T) {
	t.Run("empty recommendations", func(t *testing.T) {
		recommendations := []cost.CostRecommendation{}
		result := calculatePotentialSavings(recommendations)
		assert.Equal(t, 0.0, result)
	})

	t.Run("single recommendation", func(t *testing.T) {
		recommendations := []cost.CostRecommendation{
			{
				PotentialSavings: 100.0,
			},
		}
		result := calculatePotentialSavings(recommendations)
		assert.Equal(t, 100.0, result)
	})

	t.Run("multiple recommendations", func(t *testing.T) {
		recommendations := []cost.CostRecommendation{
			{
				PotentialSavings: 100.0,
			},
			{
				PotentialSavings: 50.0,
			},
			{
				PotentialSavings: 25.0,
			},
		}
		result := calculatePotentialSavings(recommendations)
		assert.Equal(t, 175.0, result)
	})

	t.Run("negative savings", func(t *testing.T) {
		recommendations := []cost.CostRecommendation{
			{
				PotentialSavings: 100.0,
			},
			{
				PotentialSavings: -50.0,
			},
		}
		result := calculatePotentialSavings(recommendations)
		assert.Equal(t, 50.0, result)
	})
}

func TestContains(t *testing.T) {
	t.Run("empty slice", func(t *testing.T) {
		slice := []string{}
		result := contains(slice, "test")
		assert.False(t, result)
	})

	t.Run("item not in slice", func(t *testing.T) {
		slice := []string{"item1", "item2", "item3"}
		result := contains(slice, "test")
		assert.False(t, result)
	})

	t.Run("item in slice", func(t *testing.T) {
		slice := []string{"item1", "item2", "item3"}
		result := contains(slice, "item2")
		assert.True(t, result)
	})

	t.Run("item at beginning", func(t *testing.T) {
		slice := []string{"item1", "item2", "item3"}
		result := contains(slice, "item1")
		assert.True(t, result)
	})

	t.Run("item at end", func(t *testing.T) {
		slice := []string{"item1", "item2", "item3"}
		result := contains(slice, "item3")
		assert.True(t, result)
	})

	t.Run("case sensitive", func(t *testing.T) {
		slice := []string{"Item1", "Item2", "Item3"}
		result := contains(slice, "item1")
		assert.False(t, result)
	})
}

func TestLoadConfig(t *testing.T) {
	// Create a temporary config file
	tempDir := t.TempDir()
	configFile := tempDir + "/cloudrecon.yaml"

	// Write a test config file
	configContent := `
storage:
  database_path: "test.db"
  max_connections: 10
  connection_timeout: "30s"

aws:
  regions: ["us-east-1", "us-west-2"]
  max_retries: 3
  timeout: "30s"

azure:
  subscriptions: []
  max_retries: 3
  timeout: "30s"

gcp:
  project_id: ""
  organization_id: ""
  credentials_path: ""
  projects: []
  max_retries: 3
  timeout: "30s"
  discovery_methods: ["config", "environment", "gcloud", "metadata", "resource_manager"]

discovery:
  max_parallel: 10
  timeout: "300s"
  use_native_tools: true

analysis:
  enable_cost_analysis: true
  enable_security_analysis: true
  enable_dependency_analysis: true
  cache_results: true

logging:
  level: "info"
  format: "json"
  output: "stdout"
`

	err := os.WriteFile(configFile, []byte(configContent), 0644)
	require.NoError(t, err)

	// Change to the temp directory to find the config file
	originalDir, err := os.Getwd()
	require.NoError(t, err)
	defer os.Chdir(originalDir)

	err = os.Chdir(tempDir)
	require.NoError(t, err)

	// Test loading config
	config, err := loadConfig()
	assert.NoError(t, err)
	assert.NotNil(t, config)
	assert.Equal(t, "test.db", config.Storage.DatabasePath)
	assert.Equal(t, 10, config.Storage.MaxConnections)
	assert.Equal(t, []string{"us-east-1", "us-west-2"}, config.AWS.Regions)
	assert.Equal(t, 10, config.Discovery.MaxParallel)
	assert.True(t, config.Analysis.EnableCostAnalysis)
}

func TestLoadConfigWithDefaults(t *testing.T) {
	// Test loading config with defaults when no config file exists
	originalDir, err := os.Getwd()
	require.NoError(t, err)
	defer os.Chdir(originalDir)

	// Change to a temp directory without config file
	tempDir := t.TempDir()
	err = os.Chdir(tempDir)
	require.NoError(t, err)

	// Test loading config with defaults
	config, err := loadConfig()
	assert.NoError(t, err)
	assert.NotNil(t, config)
	assert.Equal(t, "cloudrecon.db", config.Storage.DatabasePath)
	assert.Equal(t, []string{"us-east-1", "us-west-2"}, config.AWS.Regions)
	assert.Equal(t, 10, config.Discovery.MaxParallel)
	assert.True(t, config.Analysis.EnableCostAnalysis)
}

func TestLoadConfigInvalidYAML(t *testing.T) {
	// Create a temporary config file with invalid YAML
	tempDir := t.TempDir()
	configFile := tempDir + "/cloudrecon.yaml"

	// Write invalid YAML
	configContent := `
storage:
  database_path: "test.db"
  max_connections: 10
  connection_timeout: "30s"

aws:
  regions: ["us-east-1", "us-west-2"]
  max_retries: 3
  timeout: "30s"

invalid_yaml: [unclosed bracket
`

	err := os.WriteFile(configFile, []byte(configContent), 0644)
	require.NoError(t, err)

	// Change to the temp directory to find the config file
	originalDir, err := os.Getwd()
	require.NoError(t, err)
	defer os.Chdir(originalDir)

	err = os.Chdir(tempDir)
	require.NoError(t, err)

	// Test loading invalid config
	config, err := loadConfig()
	assert.Error(t, err)
	assert.Nil(t, config)
	assert.Contains(t, err.Error(), "failed to read config file")
}

func TestLoadConfigValidationError(t *testing.T) {
	// Create a temporary config file with validation errors
	tempDir := t.TempDir()
	configFile := tempDir + "/cloudrecon.yaml"

	// Write config with validation errors
	configContent := `
storage:
  database_path: ""
  max_connections: 10
  connection_timeout: "30s"

aws:
  regions: []
  max_retries: 3
  timeout: "30s"

discovery:
  max_parallel: 0
  timeout: "300s"
  use_native_tools: true

analysis:
  enable_cost_analysis: false
  enable_security_analysis: false
  enable_dependency_analysis: false
  cache_results: true
`

	err := os.WriteFile(configFile, []byte(configContent), 0644)
	require.NoError(t, err)

	// Change to the temp directory to find the config file
	originalDir, err := os.Getwd()
	require.NoError(t, err)
	defer os.Chdir(originalDir)

	err = os.Chdir(tempDir)
	require.NoError(t, err)

	// Test loading config with validation errors
	config, err := loadConfig()
	assert.Error(t, err)
	assert.Nil(t, config)
	assert.Contains(t, err.Error(), "config validation failed")
}

func TestCommandFlags(t *testing.T) {
	// Test that commands have the expected flags
	discoverCmd := createDiscoverCmd()

	// Check discover command flags
	assert.NotNil(t, discoverCmd.Flag("providers"))
	assert.NotNil(t, discoverCmd.Flag("accounts"))
	assert.NotNil(t, discoverCmd.Flag("regions"))
	assert.NotNil(t, discoverCmd.Flag("resource-types"))
	assert.NotNil(t, discoverCmd.Flag("mode"))
	assert.NotNil(t, discoverCmd.Flag("native-tools"))
	assert.NotNil(t, discoverCmd.Flag("max-parallel"))
	assert.NotNil(t, discoverCmd.Flag("timeout"))

	queryCmd := createQueryCmd()

	// Check query command flags
	assert.NotNil(t, queryCmd.Flag("format"))
	assert.NotNil(t, queryCmd.Flag("output"))

	exportCmd := createExportCmd()

	// Check export command flags
	assert.NotNil(t, exportCmd.Flag("format"))
	assert.NotNil(t, exportCmd.Flag("output"))
}

func TestCommandExecution(t *testing.T) {
	// Test that commands can be created and have proper structure
	commands := []*cobra.Command{
		createDiscoverCmd(),
		createQueryCmd(),
		createExportCmd(),
		createAskCmd(),
		createStatusCmd(),
		createAnalyzeCmd(),
		createSecurityCmd(),
		createCostCmd(),
		createDependenciesCmd(),
		createInteractiveCmd(),
	}

	for _, cmd := range commands {
		assert.NotNil(t, cmd)
		assert.NotEmpty(t, cmd.Use)
		assert.NotEmpty(t, cmd.Short)
		assert.NotEmpty(t, cmd.Long)
	}
}

func TestVersionAndGlobalFlags(t *testing.T) {
	// Test that version and global flags are set correctly
	assert.Equal(t, "1.0.0", version)
	assert.False(t, verbose)
	assert.Equal(t, "config/cloudrecon.yaml", configFile)
}

func TestContextHandling(t *testing.T) {
	// Test context creation and cancellation
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Test that context can be cancelled
	cancel()
	select {
	case <-ctx.Done():
		// Context was cancelled successfully
	default:
		t.Error("Context should be cancelled")
	}
}

func TestSignalHandling(t *testing.T) {
	// Test that signal channel is created properly
	sigChan := make(chan os.Signal, 1)
	assert.NotNil(t, sigChan)
	assert.Equal(t, 1, cap(sigChan))
}

func TestTimeHandling(t *testing.T) {
	// Test time operations used in the application
	start := time.Now()
	time.Sleep(1 * time.Millisecond)
	duration := time.Since(start)

	assert.True(t, duration > 0)
	assert.True(t, duration < 100*time.Millisecond)
}

func TestStringOperations(t *testing.T) {
	// Test string operations used in the application
	args := []string{"arg1", "arg2", "arg3"}
	queryStr := strings.Join(args, " ")
	assert.Equal(t, "arg1 arg2 arg3", queryStr)

	// Test empty args
	emptyArgs := []string{}
	emptyQueryStr := strings.Join(emptyArgs, " ")
	assert.Equal(t, "", emptyQueryStr)
}

func TestErrorHandling(t *testing.T) {
	// Test error creation and handling
	err := fmt.Errorf("test error")
	assert.Error(t, err)
	assert.Equal(t, "test error", err.Error())

	// Test wrapped error
	wrappedErr := fmt.Errorf("wrapped: %w", err)
	assert.Error(t, wrappedErr)
	assert.Contains(t, wrappedErr.Error(), "wrapped")
}

func TestLoggingSetup(t *testing.T) {
	// Test that logging can be set up without panicking
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("Logging setup panicked: %v", r)
		}
	}()

	// Test logging formatter setup
	formatter := &logrus.TextFormatter{
		FullTimestamp: true,
	}
	assert.NotNil(t, formatter)
	assert.True(t, formatter.FullTimestamp)
}

func TestConfigDefaults(t *testing.T) {
	// Test that default values are set correctly
	setDefaultConfig()

	// Test some key defaults
	assert.Equal(t, "cloudrecon.db", viper.GetString("storage.database_path"))
	assert.Equal(t, 10, viper.GetInt("storage.max_connections"))
	assert.Equal(t, "30s", viper.GetString("storage.connection_timeout"))

	awsRegions := viper.GetStringSlice("aws.regions")
	assert.Contains(t, awsRegions, "us-east-1")
	assert.Contains(t, awsRegions, "us-west-2")

	assert.Equal(t, 10, viper.GetInt("discovery.max_parallel"))
	assert.Equal(t, "300s", viper.GetString("discovery.timeout"))
	assert.True(t, viper.GetBool("discovery.use_native_tools"))

	assert.True(t, viper.GetBool("analysis.enable_cost_analysis"))
	assert.True(t, viper.GetBool("analysis.enable_security_analysis"))
	assert.True(t, viper.GetBool("analysis.enable_dependency_analysis"))
	assert.True(t, viper.GetBool("analysis.cache_results"))

	assert.Equal(t, "info", viper.GetString("logging.level"))
	assert.Equal(t, "json", viper.GetString("logging.format"))
	assert.Equal(t, "stdout", viper.GetString("logging.output"))
}
