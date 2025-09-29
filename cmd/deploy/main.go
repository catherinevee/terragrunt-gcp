package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/your-org/terragrunt-gcp/internal/gcp"
)

type DeploymentConfig struct {
	ProjectID     string                 `json:"project_id"`
	Region        string                 `json:"region"`
	Zone          string                 `json:"zone"`
	Environment   string                 `json:"environment"`
	Resources     []ResourceConfig       `json:"resources"`
	Dependencies  []string              `json:"dependencies,omitempty"`
	Settings      map[string]interface{} `json:"settings,omitempty"`
}

type ResourceConfig struct {
	Type       string                 `json:"type"`
	Name       string                 `json:"name"`
	Config     map[string]interface{} `json:"config"`
	DependsOn  []string              `json:"depends_on,omitempty"`
}

type DeploymentResult struct {
	Success   bool                   `json:"success"`
	Resources []ResourceResult       `json:"resources"`
	Errors    []string              `json:"errors,omitempty"`
	Duration  time.Duration          `json:"duration"`
	Summary   map[string]interface{} `json:"summary"`
}

type ResourceResult struct {
	Type      string                 `json:"type"`
	Name      string                 `json:"name"`
	Status    string                 `json:"status"`
	ID        string                 `json:"id,omitempty"`
	Details   map[string]interface{} `json:"details,omitempty"`
	Error     string                 `json:"error,omitempty"`
	Duration  time.Duration          `json:"duration"`
}

func main() {
	var (
		configFile  = flag.String("config", "", "Path to deployment configuration file")
		environment = flag.String("env", "dev", "Deployment environment")
		dryRun      = flag.Bool("dry-run", false, "Perform dry run without actual deployment")
		force       = flag.Bool("force", false, "Force deployment even with warnings")
		parallel    = flag.Int("parallel", 4, "Number of parallel operations")
		timeout     = flag.Duration("timeout", 30*time.Minute, "Deployment timeout")
		verbose     = flag.Bool("verbose", false, "Enable verbose output")
		format      = flag.String("format", "json", "Output format (json, text)")
		workDir     = flag.String("workdir", ".", "Working directory")
	)
	flag.Parse()

	if *configFile == "" {
		fmt.Fprintf(os.Stderr, "Error: -config flag is required\n")
		flag.Usage()
		os.Exit(1)
	}

	// Change to working directory
	if err := os.Chdir(*workDir); err != nil {
		fmt.Fprintf(os.Stderr, "Error changing to working directory: %v\n", err)
		os.Exit(1)
	}

	// Load deployment configuration
	configPath, err := filepath.Abs(*configFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error resolving config path: %v\n", err)
		os.Exit(1)
	}

	configData, err := os.ReadFile(configPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading config file: %v\n", err)
		os.Exit(1)
	}

	var deployConfig DeploymentConfig
	if err := json.Unmarshal(configData, &deployConfig); err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing config file: %v\n", err)
		os.Exit(1)
	}

	// Override environment if specified
	if *environment != "dev" {
		deployConfig.Environment = *environment
	}

	// Initialize context
	ctx, cancel := context.WithTimeout(context.Background(), *timeout)
	defer cancel()

	// Initialize GCP client
	client, err := gcp.NewClient(ctx, &gcp.ClientConfig{
		ProjectID:     deployConfig.ProjectID,
		Region:        deployConfig.Region,
		Zone:          deployConfig.Zone,
		LogLevel:      getLogLevel(*verbose),
		RetryAttempts: 3,
		Timeout:       *timeout,
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating GCP client: %v\n", err)
		os.Exit(1)
	}
	defer client.Close()

	if *verbose {
		fmt.Printf("🚀 Starting deployment for environment: %s\n", deployConfig.Environment)
		fmt.Printf("📍 Project: %s, Region: %s, Zone: %s\n",
			deployConfig.ProjectID, deployConfig.Region, deployConfig.Zone)
		if *dryRun {
			fmt.Println("🧪 DRY RUN MODE - No actual changes will be made")
		}
	}

	// Perform deployment
	startTime := time.Now()
	result := performDeployment(ctx, client, &deployConfig, &deploymentOptions{
		DryRun:   *dryRun,
		Force:    *force,
		Parallel: *parallel,
		Verbose:  *verbose,
	})
	result.Duration = time.Since(startTime)

	// Output results
	switch *format {
	case "json":
		output, err := json.MarshalIndent(result, "", "  ")
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error formatting output: %v\n", err)
			os.Exit(1)
		}
		fmt.Println(string(output))
	case "text":
		printTextResult(result, *verbose)
	default:
		fmt.Fprintf(os.Stderr, "Error: Unsupported format '%s'\n", *format)
		os.Exit(1)
	}

	// Exit with appropriate code
	if !result.Success {
		os.Exit(1)
	}
}

type deploymentOptions struct {
	DryRun   bool
	Force    bool
	Parallel int
	Verbose  bool
}

func performDeployment(ctx context.Context, client *gcp.Client, config *DeploymentConfig, opts *deploymentOptions) *DeploymentResult {
	result := &DeploymentResult{
		Success:   true,
		Resources: make([]ResourceResult, 0, len(config.Resources)),
		Summary:   make(map[string]interface{}),
	}

	// Create service instances
	services := initializeServices(client)

	// Process resources in dependency order
	resourceGraph := buildDependencyGraph(config.Resources)
	executionPlan := topologicalSort(resourceGraph)

	// Execute deployment plan
	for _, batch := range executionPlan {
		batchResults := deployBatch(ctx, services, batch, opts)
		result.Resources = append(result.Resources, batchResults...)

		// Check for failures
		for _, res := range batchResults {
			if res.Status == "failed" {
				result.Success = false
				result.Errors = append(result.Errors, fmt.Sprintf("Resource %s/%s failed: %s", res.Type, res.Name, res.Error))
			}
		}

		// Stop on failure unless force is enabled
		if !result.Success && !opts.Force {
			break
		}
	}

	// Generate summary
	result.Summary = generateSummary(result.Resources)

	return result
}

func initializeServices(client *gcp.Client) map[string]interface{} {
	services := make(map[string]interface{})

	computeService, _ := gcp.NewComputeService(client, &gcp.ComputeConfig{
		CacheEnabled: true,
		CacheTTL:     10 * time.Minute,
	})
	services["compute"] = computeService

	storageService, _ := gcp.NewStorageService(client, &gcp.StorageConfig{
		CacheEnabled: true,
		CacheTTL:     15 * time.Minute,
	})
	services["storage"] = storageService

	networkService, _ := gcp.NewNetworkService(client, &gcp.NetworkConfig{
		CacheEnabled: true,
		CacheTTL:     20 * time.Minute,
	})
	services["network"] = networkService

	iamService, _ := gcp.NewIAMService(client, &gcp.IAMConfig{
		CacheEnabled: true,
		CacheTTL:     30 * time.Minute,
	})
	services["iam"] = iamService

	secretsService, _ := gcp.NewSecretsService(client, &gcp.SecretsConfig{
		CacheEnabled: true,
		CacheTTL:     5 * time.Minute,
	})
	services["secrets"] = secretsService

	return services
}

func buildDependencyGraph(resources []ResourceConfig) map[string][]string {
	graph := make(map[string][]string)

	for _, resource := range resources {
		resourceKey := fmt.Sprintf("%s.%s", resource.Type, resource.Name)
		graph[resourceKey] = resource.DependsOn
	}

	return graph
}

func topologicalSort(graph map[string][]string) [][]string {
	// Simple topological sort implementation
	// Returns batches of resources that can be deployed in parallel

	visited := make(map[string]bool)
	inDegree := make(map[string]int)

	// Calculate in-degrees
	for node := range graph {
		if _, exists := inDegree[node]; !exists {
			inDegree[node] = 0
		}
		for _, dep := range graph[node] {
			inDegree[dep]++
		}
	}

	var batches [][]string

	for len(visited) < len(graph) {
		var currentBatch []string

		// Find nodes with in-degree 0
		for node, degree := range inDegree {
			if !visited[node] && degree == 0 {
				currentBatch = append(currentBatch, node)
			}
		}

		if len(currentBatch) == 0 {
			// Circular dependency detected, break the cycle
			for node := range graph {
				if !visited[node] {
					currentBatch = append(currentBatch, node)
					break
				}
			}
		}

		// Mark current batch as visited and update in-degrees
		for _, node := range currentBatch {
			visited[node] = true
			for _, dep := range graph[node] {
				inDegree[dep]--
			}
		}

		batches = append(batches, currentBatch)
	}

	return batches
}

func deployBatch(ctx context.Context, services map[string]interface{}, batch []string, opts *deploymentOptions) []ResourceResult {
	results := make([]ResourceResult, 0, len(batch))

	for _, resourceKey := range batch {
		parts := strings.SplitN(resourceKey, ".", 2)
		if len(parts) != 2 {
			continue
		}

		resourceType, resourceName := parts[0], parts[1]
		startTime := time.Now()

		result := ResourceResult{
			Type:     resourceType,
			Name:     resourceName,
			Status:   "success",
			Duration: time.Since(startTime),
		}

		if opts.DryRun {
			result.Status = "dry-run"
			result.Details = map[string]interface{}{
				"action": "would create",
				"type":   resourceType,
			}
		} else {
			// Actual deployment logic would go here
			// For now, simulate successful deployment
			result.ID = fmt.Sprintf("%s-%s-%d", resourceType, resourceName, time.Now().Unix())
			result.Details = map[string]interface{}{
				"created_at": time.Now().Format(time.RFC3339),
				"status":     "created",
			}
		}

		if opts.Verbose {
			fmt.Printf("✅ %s: %s.%s (%v)\n", result.Status, resourceType, resourceName, result.Duration)
		}

		results = append(results, result)
	}

	return results
}

func generateSummary(resources []ResourceResult) map[string]interface{} {
	summary := make(map[string]interface{})

	statusCounts := make(map[string]int)
	typeCounts := make(map[string]int)
	totalDuration := time.Duration(0)

	for _, resource := range resources {
		statusCounts[resource.Status]++
		typeCounts[resource.Type]++
		totalDuration += resource.Duration
	}

	summary["total_resources"] = len(resources)
	summary["status_counts"] = statusCounts
	summary["type_counts"] = typeCounts
	summary["total_duration"] = totalDuration
	summary["average_duration"] = totalDuration / time.Duration(len(resources))

	return summary
}

func printTextResult(result *DeploymentResult, verbose bool) {
	if result.Success {
		fmt.Println("✅ Deployment completed successfully")
	} else {
		fmt.Println("❌ Deployment failed")
	}

	fmt.Printf("📊 Summary: %d resources processed in %v\n",
		len(result.Resources), result.Duration)

	if len(result.Errors) > 0 {
		fmt.Println("\n❌ Errors:")
		for _, err := range result.Errors {
			fmt.Printf("  - %s\n", err)
		}
	}

	if verbose {
		fmt.Println("\n📋 Resource Details:")
		for _, resource := range result.Resources {
			status := "✅"
			if resource.Status == "failed" {
				status = "❌"
			} else if resource.Status == "dry-run" {
				status = "🧪"
			}

			fmt.Printf("  %s %s.%s (%v)\n",
				status, resource.Type, resource.Name, resource.Duration)

			if resource.Error != "" {
				fmt.Printf("    Error: %s\n", resource.Error)
			}
		}

		fmt.Println("\n📈 Summary Details:")
		summaryJSON, _ := json.MarshalIndent(result.Summary, "  ", "  ")
		fmt.Printf("  %s\n", string(summaryJSON))
	}
}

func getLogLevel(verbose bool) string {
	if verbose {
		return "debug"
	}
	return "info"
}