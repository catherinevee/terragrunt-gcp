package monitoring

import (
	"testing"

	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestMonitoringAlert(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/monitoring/cloud-monitoring",
		Vars: map[string]interface{}{
			"project_id": config.ProjectID,
			"name":       testhelpers.GetTestResourceName("test-alert", config.RandomID),
		},
		NoColor: true,
		Logger:  logger.Default,
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test alert creation
	alertName := terraform.Output(t, terraformOptions, "alert_policy_name")
	assert.NotEmpty(t, alertName, "Alert policy name should not be empty")
}
