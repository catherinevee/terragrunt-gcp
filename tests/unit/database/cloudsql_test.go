package database

import (
	"testing"

	"../../testhelpers"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestCloudSQLInstance(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/database/cloud-sql",
		Vars: map[string]interface{}{
			"project_id": config.ProjectID,
			"region":     config.Region,
			"name":       testhelpers.GetTestResourceName("test-db", config.RandomID),
		},
		NoColor: true,
		Logger:  logger.Default,
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test database creation
	dbName := terraform.Output(t, terraformOptions, "instance_name")
	assert.NotEmpty(t, dbName, "Database name should not be empty")
}
