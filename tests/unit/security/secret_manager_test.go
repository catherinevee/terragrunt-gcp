package security

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

func TestSecretManagerBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	secretName := testhelpers.GetTestResourceName("secret", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/security/secret-manager",
		Vars: map[string]interface{}{
			"project_id":   config.ProjectID,
			"secret_id":    secretName,
			"secret_data":  "test-secret-value",
			"environment":  "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify secret outputs
	secretIDOutput := terraform.Output(t, terraformOptions, "secret_id")
	assert.Contains(t, secretIDOutput, secretName)

	secretName := terraform.Output(t, terraformOptions, "secret_name")
	assert.NotEmpty(t, secretName)
}

func TestSecretManagerWithLabels(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	secretName := testhelpers.GetTestResourceName("secret-labels", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/security/secret-manager",
		Vars: map[string]interface{}{
			"project_id":   config.ProjectID,
			"secret_id":    secretName,
			"secret_data":  "test-secret-value",
			"environment":  "test",
			"labels": map[string]string{
				"app":         "test-app",
				"environment": "test",
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	secretIDOutput := terraform.Output(t, terraformOptions, "secret_id")
	assert.NotEmpty(t, secretIDOutput)
}

func TestSecretManagerWithReplication(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	secretName := testhelpers.GetTestResourceName("secret-repl", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/security/secret-manager",
		Vars: map[string]interface{}{
			"project_id":   config.ProjectID,
			"secret_id":    secretName,
			"secret_data":  "test-secret-value",
			"environment":  "test",
			"replication": map[string]interface{}{
				"automatic": true,
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	secretIDOutput := terraform.Output(t, terraformOptions, "secret_id")
	assert.NotEmpty(t, secretIDOutput)
}

func TestSecretManagerWithIAMBinding(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	secretName := testhelpers.GetTestResourceName("secret-iam", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/security/secret-manager",
		Vars: map[string]interface{}{
			"project_id":   config.ProjectID,
			"secret_id":    secretName,
			"secret_data":  "test-secret-value",
			"environment":  "test",
			"iam_bindings": map[string]interface{}{
				"roles/secretmanager.secretAccessor": []string{
					"serviceAccount:test@example.com",
				},
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	secretIDOutput := terraform.Output(t, terraformOptions, "secret_id")
	assert.NotEmpty(t, secretIDOutput)
}
