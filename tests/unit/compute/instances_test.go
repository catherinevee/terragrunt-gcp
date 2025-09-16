package compute

import (
	"testing"

	"../../testhelpers"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestComputeInstance(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/compute/instances",
		Vars: map[string]interface{}{
			"project_id": config.ProjectID,
			"region":     config.Region,
			"name":       testhelpers.GetTestResourceName("test-instance", config.RandomID),
		},
		NoColor: true,
		Logger:  logger.Default,
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test instance creation
	instanceName := terraform.Output(t, terraformOptions, "instance_name")
	assert.NotEmpty(t, instanceName, "Instance name should not be empty")
}
