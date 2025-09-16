package data

import (
	"testing"

	"../../testhelpers"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestBigQueryDataset(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/data",
		Vars: map[string]interface{}{
			"project_id": config.ProjectID,
			"name":       testhelpers.GetTestResourceName("test-dataset", config.RandomID),
		},
		NoColor: true,
		Logger:  logger.Default,
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test dataset creation
	datasetName := terraform.Output(t, terraformOptions, "dataset_name")
	assert.NotEmpty(t, datasetName, "Dataset name should not be empty")
}
