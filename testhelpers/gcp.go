package testhelpers

import (
	"os"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/random"
)

// TestConfig represents the configuration for test execution
type TestConfig struct {
	ProjectID   string
	Region      string
	Zone        string
	Environment string
	RandomID    string
	Timeout     time.Duration
}

// GetTestConfig retrieves test configuration from environment variables
func GetTestConfig(t *testing.T) *TestConfig {
	projectID := os.Getenv("GCP_PROJECT_ID")
	if projectID == "" {
		t.Fatal("GCP_PROJECT_ID environment variable is required")
	}

	region := os.Getenv("GCP_REGION")
	if region == "" {
		region = "europe-west1"
	}

	zone := os.Getenv("GCP_ZONE")
	if zone == "" {
		zone = "europe-west1-a"
	}

	environment := os.Getenv("TEST_ENVIRONMENT")
	if environment == "" {
		environment = "test"
	}

	timeoutStr := os.Getenv("TEST_TIMEOUT")
	timeout := 30 * time.Minute
	if timeoutStr != "" {
		if parsedTimeout, err := time.ParseDuration(timeoutStr); err == nil {
			timeout = parsedTimeout
		}
	}

	return &TestConfig{
		ProjectID:   projectID,
		Region:      region,
		Zone:        zone,
		Environment: environment,
		RandomID:    random.UniqueId(),
		Timeout:     timeout,
	}
}

// CleanupTestResources cleans up test resources
func CleanupTestResources(t *testing.T, projectID string, resources []string) {
	t.Logf("Cleaning up test resources in project: %s", projectID)

	for _, resource := range resources {
		t.Logf("Cleaning up resource: %s", resource)
		// Add specific cleanup logic based on resource type
		// This is a placeholder for actual cleanup implementation
	}
}

// CreateTestProject creates a test GCP project (if needed)
func CreateTestProject(t *testing.T, projectID string) string {
	// For now, return the provided project ID
	// In a real implementation, this would create a test project
	return projectID
}

// ValidateGCPCredentials validates that GCP credentials are properly configured
func ValidateGCPCredentials(t *testing.T) {
	// Check if gcloud is authenticated
	if !gcp.IsGcloudInstalled() {
		t.Fatal("gcloud CLI is not installed")
	}

	// Check if we can list projects (basic auth test)
	_, err := gcp.GetAllProjectsE(t)
	if err != nil {
		t.Fatalf("Failed to authenticate with GCP: %v", err)
	}
}

// GetTestResourceName generates a unique resource name for testing
func GetTestResourceName(prefix string, randomID string) string {
	return prefix + "-" + randomID
}

// WaitForResourceCreation waits for a resource to be created
func WaitForResourceCreation(t *testing.T, checkFunc func() bool, timeout time.Duration) bool {
	deadline := time.Now().Add(timeout)
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			if checkFunc() {
				return true
			}
		case <-time.After(time.Until(deadline)):
			return false
		}
	}
}
