package testhelpers

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

// TestEnvironment represents a test environment configuration
type TestEnvironment struct {
	ProjectID    string                 `json:"project_id"`
	Region       string                 `json:"region"`
	Environment  string                 `json:"environment"`
	Resources    map[string]interface{} `json:"resources"`
	Dependencies []string               `json:"dependencies"`
	TestData     map[string]interface{} `json:"test_data"`
	Config       map[string]interface{} `json:"config"`
}

// LoadTestEnvironment loads test environment configuration from file
func LoadTestEnvironment(env string) (*TestEnvironment, error) {
	configPath := filepath.Join("fixtures", "environments", env+".json")

	data, err := os.ReadFile(configPath)
	if err != nil {
		return nil, err
	}

	var environment TestEnvironment
	err = json.Unmarshal(data, &environment)
	if err != nil {
		return nil, err
	}

	return &environment, nil
}

// CreateTestResources creates test resources based on configuration
func CreateTestResources(t *testing.T, config *TestConfig) *TestEnvironment {
	environment := &TestEnvironment{
		ProjectID:    config.ProjectID,
		Region:       config.Region,
		Environment:  config.Environment,
		Resources:    make(map[string]interface{}),
		Dependencies: []string{},
		TestData:     make(map[string]interface{}),
		Config:       make(map[string]interface{}),
	}

	// Add default test resources
	environment.Resources["vpc_name"] = "test-vpc-" + config.RandomID
	environment.Resources["subnet_name"] = "test-subnet-" + config.RandomID
	environment.Resources["instance_name"] = "test-instance-" + config.RandomID
	environment.Resources["bucket_name"] = "test-bucket-" + config.RandomID

	// Add default test data
	environment.TestData["sample_data"] = "test-data-" + config.RandomID
	environment.TestData["test_user"] = "test-user-" + config.RandomID

	// Add default configuration
	environment.Config["region"] = config.Region
	environment.Config["zone"] = config.Zone
	environment.Config["project_id"] = config.ProjectID

	return environment
}

// GetTestData retrieves test data by type
func GetTestData(t *testing.T, dataType string) interface{} {
	dataPath := filepath.Join("fixtures", "data", dataType+".json")

	data, err := os.ReadFile(dataPath)
	if err != nil {
		t.Logf("Test data file not found: %s, using default data", dataPath)
		return getDefaultTestData(dataType)
	}

	var testData interface{}
	err = json.Unmarshal(data, &testData)
	if err != nil {
		t.Logf("Failed to parse test data: %v, using default data", err)
		return getDefaultTestData(dataType)
	}

	return testData
}

// getDefaultTestData returns default test data when files are not available
func getDefaultTestData(dataType string) interface{} {
	switch dataType {
	case "vpc":
		return map[string]interface{}{
			"name": "test-vpc",
			"cidr": "10.0.0.0/16",
		}
	case "subnet":
		return map[string]interface{}{
			"name": "test-subnet",
			"cidr": "10.0.1.0/24",
		}
	case "instance":
		return map[string]interface{}{
			"name":         "test-instance",
			"machine_type": "e2-micro",
		}
	case "bucket":
		return map[string]interface{}{
			"name":     "test-bucket",
			"location": "europe-west1",
		}
	default:
		return map[string]interface{}{
			"name": "test-resource",
		}
	}
}

// SaveTestEnvironment saves test environment configuration to file
func SaveTestEnvironment(t *testing.T, environment *TestEnvironment) error {
	configPath := filepath.Join("fixtures", "environments", environment.Environment+".json")

	data, err := json.MarshalIndent(environment, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(configPath, data, 0644)
}

// GetTestResourceName generates a test resource name
func GetTestResourceName(prefix string, randomID string) string {
	return prefix + "-" + randomID
}

// ValidateTestEnvironment validates that a test environment has required fields
func ValidateTestEnvironment(t *testing.T, environment *TestEnvironment) {
	if environment.ProjectID == "" {
		t.Error("Test environment must have a project ID")
	}
	if environment.Region == "" {
		t.Error("Test environment must have a region")
	}
	if environment.Environment == "" {
		t.Error("Test environment must have an environment name")
	}
}
