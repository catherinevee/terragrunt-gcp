package data

import (
	"testing"
	"time"

	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestBigQueryDataset(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/data/bigquery",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"dataset_id":  testhelpers.GetTestResourceName("test_dataset", config.RandomID),
			"location":    config.Region,
			"description": "Test BigQuery dataset for unit testing",
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test BigQuery dataset creation
	datasetID := terraform.Output(t, terraformOptions, "dataset_id")
	assert.NotEmpty(t, datasetID, "Dataset ID should not be empty")
	assert.Contains(t, datasetID, "test_dataset-", "Dataset ID should contain test prefix")

	// Test BigQuery dataset exists in GCP
	dataset := gcp.GetBigQueryDataset(t, config.ProjectID, datasetID)
	assert.NotNil(t, dataset, "BigQuery dataset should exist in GCP")
	assert.Equal(t, "test_dataset-"+config.RandomID, dataset.DatasetID, "Dataset ID should match expected value")
	assert.Equal(t, config.Region, dataset.Location, "Dataset location should match expected value")
	assert.Equal(t, "Test BigQuery dataset for unit testing", dataset.Description, "Dataset description should match expected value")
}

func TestBigQueryDatasetWithTables(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/data/bigquery",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"dataset_id":  testhelpers.GetTestResourceName("test_dataset", config.RandomID),
			"location":    config.Region,
			"description": "Test BigQuery dataset with tables",
			"tables": []map[string]interface{}{
				{
					"table_id":    "test_table_1",
					"description": "Test table 1",
					"schema": `[
						{
							"name": "id",
							"type": "INTEGER",
							"mode": "REQUIRED",
							"description": "Primary key"
						},
						{
							"name": "name",
							"type": "STRING",
							"mode": "REQUIRED",
							"description": "Name field"
						},
						{
							"name": "created_at",
							"type": "TIMESTAMP",
							"mode": "REQUIRED",
							"description": "Creation timestamp"
						}
					]`,
				},
				{
					"table_id":    "test_table_2",
					"description": "Test table 2",
					"schema": `[
						{
							"name": "id",
							"type": "INTEGER",
							"mode": "REQUIRED",
							"description": "Primary key"
						},
						{
							"name": "value",
							"type": "FLOAT",
							"mode": "NULLABLE",
							"description": "Value field"
						}
					]`,
				},
			},
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test BigQuery dataset creation
	datasetID := terraform.Output(t, terraformOptions, "dataset_id")
	assert.NotEmpty(t, datasetID, "Dataset ID should not be empty")

	// Test table creation
	tableIDs := terraform.OutputList(t, terraformOptions, "table_ids")
	assert.Len(t, tableIDs, 2, "Should have 2 tables")

	// Test each table exists in GCP
	expectedTables := []string{"test_table_1", "test_table_2"}
	for i, expectedTableID := range expectedTables {
		tableID := tableIDs[i]
		assert.Equal(t, expectedTableID, tableID, "Table ID should match expected value")

		// Verify table exists in GCP
		table := gcp.GetBigQueryTable(t, config.ProjectID, datasetID, tableID)
		assert.NotNil(t, table, "Table should exist in GCP")
		assert.Equal(t, expectedTableID, table.TableID, "Table ID should match expected value")
	}
}

func TestBigQueryDatasetWithAccess(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/data/bigquery",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"dataset_id":  testhelpers.GetTestResourceName("test_dataset", config.RandomID),
			"location":    config.Region,
			"description": "Test BigQuery dataset with access controls",
			"access": []map[string]interface{}{
				{
					"role":          "READER",
					"user_by_email": "test-user@" + config.ProjectID + ".iam.gserviceaccount.com",
				},
				{
					"role":           "WRITER",
					"group_by_email": "test-group@example.com",
				},
				{
					"role":          "OWNER",
					"special_group": "allAuthenticatedUsers",
				},
			},
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test BigQuery dataset creation
	datasetID := terraform.Output(t, terraformOptions, "dataset_id")
	assert.NotEmpty(t, datasetID, "Dataset ID should not be empty")

	// Test BigQuery dataset exists in GCP
	dataset := gcp.GetBigQueryDataset(t, config.ProjectID, datasetID)
	assert.NotNil(t, dataset, "BigQuery dataset should exist in GCP")

	// Test access configuration
	accessCount := terraform.Output(t, terraformOptions, "access_count")
	assert.Equal(t, "3", accessCount, "Should have 3 access entries")
}

func TestBigQueryDatasetWithLabels(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/data/bigquery",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"dataset_id":  testhelpers.GetTestResourceName("test_dataset", config.RandomID),
			"location":    config.Region,
			"description": "Test BigQuery dataset with labels",
			"labels": map[string]string{
				"environment": "test",
				"team":        "platform",
				"project":     "terraform-gcp",
				"cost_center": "engineering",
			},
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test BigQuery dataset creation
	datasetID := terraform.Output(t, terraformOptions, "dataset_id")
	assert.NotEmpty(t, datasetID, "Dataset ID should not be empty")

	// Test BigQuery dataset exists in GCP
	dataset := gcp.GetBigQueryDataset(t, config.ProjectID, datasetID)
	assert.NotNil(t, dataset, "BigQuery dataset should exist in GCP")

	// Test labels configuration
	labels := terraform.OutputMap(t, terraformOptions, "labels")
	assert.Len(t, labels, 4, "Should have 4 labels")
	assert.Equal(t, "test", labels["environment"], "Environment label should match")
	assert.Equal(t, "platform", labels["team"], "Team label should match")
	assert.Equal(t, "terraform-gcp", labels["project"], "Project label should match")
	assert.Equal(t, "engineering", labels["cost_center"], "Cost center label should match")
}

func TestBigQueryDatasetWithDefaultTableExpiration(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/data/bigquery",
		Vars: map[string]interface{}{
			"project_id":                  config.ProjectID,
			"dataset_id":                  testhelpers.GetTestResourceName("test_dataset", config.RandomID),
			"location":                    config.Region,
			"description":                 "Test BigQuery dataset with default table expiration",
			"default_table_expiration_ms": 86400000, // 1 day in milliseconds
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test BigQuery dataset creation
	datasetID := terraform.Output(t, terraformOptions, "dataset_id")
	assert.NotEmpty(t, datasetID, "Dataset ID should not be empty")

	// Test BigQuery dataset exists in GCP
	dataset := gcp.GetBigQueryDataset(t, config.ProjectID, datasetID)
	assert.NotNil(t, dataset, "BigQuery dataset should exist in GCP")

	// Test default table expiration configuration
	defaultTableExpirationMs := terraform.Output(t, terraformOptions, "default_table_expiration_ms")
	assert.Equal(t, "86400000", defaultTableExpirationMs, "Default table expiration should match expected value")
}

func TestBigQueryDatasetModuleValidation(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Test module structure validation
	modulePath := "../../../infrastructure/modules/data/bigquery"
	requiredFiles := []string{"main.tf", "variables.tf", "outputs.tf"}
	testhelpers.ValidateModuleStructure(t, modulePath, requiredFiles)

	// Test Terraform format validation
	testhelpers.ValidateTerraformFormat(t, modulePath)

	// Test Terraform validate
	testhelpers.ValidateTerraformValidate(t, modulePath)
}

func TestBigQueryDatasetModuleTimeout(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Set a shorter timeout for this test
	config.Timeout = 5 * time.Minute

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/data/bigquery",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"dataset_id":  testhelpers.GetTestResourceName("test_dataset", config.RandomID),
			"location":    config.Region,
			"description": "Test BigQuery dataset for unit testing",
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Test that module deploys within timeout
	start := time.Now()
	terraform.InitAndApply(t, terraformOptions)
	duration := time.Since(start)

	assert.Less(t, duration, config.Timeout, "Module deployment should complete within timeout")
}
