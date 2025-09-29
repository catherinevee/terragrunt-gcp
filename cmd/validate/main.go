package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/terragrunt-gcp/terragrunt-gcp/internal/gcp"
)

type ValidationRequest struct {
	ResourceType string                 `json:"resource_type"`
	Config       map[string]interface{} `json:"config"`
	Rules        []gcp.ValidationRule   `json:"rules,omitempty"`
}

type ValidationResponse struct {
	Valid    bool                   `json:"valid"`
	Errors   []string              `json:"errors,omitempty"`
	Warnings []string              `json:"warnings,omitempty"`
	Details  map[string]interface{} `json:"details,omitempty"`
}

func main() {
	var (
		configFile = flag.String("config", "", "Path to configuration file (JSON)")
		configData = flag.String("config-data", "", "Inline configuration data (JSON)")
		projectID  = flag.String("project", "", "GCP Project ID")
		region     = flag.String("region", "us-central1", "GCP Region")
		zone       = flag.String("zone", "us-central1-a", "GCP Zone")
		timeout    = flag.Duration("timeout", 30*time.Second, "Operation timeout")
		verbose    = flag.Bool("verbose", false, "Enable verbose output")
		format     = flag.String("format", "json", "Output format (json, text)")
	)
	flag.Parse()

	if *configFile == "" && *configData == "" {
		fmt.Fprintf(os.Stderr, "Error: Either -config or -config-data must be specified\n")
		flag.Usage()
		os.Exit(1)
	}

	if *projectID == "" {
		*projectID = os.Getenv("GCP_PROJECT_ID")
		if *projectID == "" {
			fmt.Fprintf(os.Stderr, "Error: Project ID must be specified via -project flag or GCP_PROJECT_ID environment variable\n")
			os.Exit(1)
		}
	}

	// Initialize GCP client
	ctx, cancel := context.WithTimeout(context.Background(), *timeout)
	defer cancel()

	client, err := gcp.NewClient(ctx, &gcp.ClientConfig{
		ProjectID: *projectID,
		Region:    *region,
		Zone:      *zone,
		LogLevel:  getLogLevel(*verbose),
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating GCP client: %v\n", err)
		os.Exit(1)
	}
	defer client.Close()

	utilsService, err := gcp.NewUtilsService(client, &gcp.UtilsConfig{
		CacheEnabled: true,
		CacheTTL:     5 * time.Minute,
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating utils service: %v\n", err)
		os.Exit(1)
	}

	// Parse configuration
	var validationReq ValidationRequest
	var configBytes []byte

	if *configFile != "" {
		configBytes, err = os.ReadFile(*configFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error reading config file: %v\n", err)
			os.Exit(1)
		}
	} else {
		configBytes = []byte(*configData)
	}

	if err := json.Unmarshal(configBytes, &validationReq); err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing configuration: %v\n", err)
		os.Exit(1)
	}

	// Perform validation
	result, err := utilsService.ValidateResource(ctx, validationReq.Config, validationReq.Rules)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error during validation: %v\n", err)
		os.Exit(1)
	}

	// Prepare response
	response := ValidationResponse{
		Valid:    result.Valid,
		Errors:   result.Errors,
		Warnings: result.Warnings,
		Details:  result.Details,
	}

	// Output result
	switch *format {
	case "json":
		output, err := json.MarshalIndent(response, "", "  ")
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error formatting output: %v\n", err)
			os.Exit(1)
		}
		fmt.Println(string(output))
	case "text":
		if response.Valid {
			fmt.Println("✅ Validation passed")
		} else {
			fmt.Println("❌ Validation failed")
		}

		if len(response.Errors) > 0 {
			fmt.Println("\nErrors:")
			for _, err := range response.Errors {
				fmt.Printf("  - %s\n", err)
			}
		}

		if len(response.Warnings) > 0 {
			fmt.Println("\nWarnings:")
			for _, warning := range response.Warnings {
				fmt.Printf("  - %s\n", warning)
			}
		}

		if *verbose && len(response.Details) > 0 {
			fmt.Println("\nDetails:")
			detailsJSON, _ := json.MarshalIndent(response.Details, "  ", "  ")
			fmt.Printf("  %s\n", string(detailsJSON))
		}
	default:
		fmt.Fprintf(os.Stderr, "Error: Unsupported format '%s'\n", *format)
		os.Exit(1)
	}

	// Exit with appropriate code
	if !response.Valid {
		os.Exit(1)
	}
}

func getLogLevel(verbose bool) string {
	if verbose {
		return "debug"
	}
	return "info"
}