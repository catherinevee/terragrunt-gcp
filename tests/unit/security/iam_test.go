package security

import (
	"testing"

	"../../testhelpers"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestIAMServiceAccount(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/security/iam",
		Vars: map[string]interface{}{
			"project_id": config.ProjectID,
			"name":       testhelpers.GetTestResourceName("test-sa", config.RandomID),
		},
		NoColor: true,
		Logger:  logger.Default,
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test service account creation
	saName := terraform.Output(t, terraformOptions, "service_account_name")
	assert.NotEmpty(t, saName, "Service account name should not be empty")
}
