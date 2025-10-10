package storage

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

func TestContainerRegistryBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/storage/container-registry",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"location":    "US",
			"environment": "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify registry outputs
	registryURL := terraform.Output(t, terraformOptions, "registry_url")
	assert.NotEmpty(t, registryURL)
	assert.Contains(t, registryURL, "gcr.io")
}

func TestContainerRegistryWithIAM(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/storage/container-registry",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"location":    "US",
			"environment": "test",
			"iam_bindings": map[string]interface{}{
				"roles/storage.objectViewer": []string{
					"serviceAccount:test@example.com",
				},
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	registryURL := terraform.Output(t, terraformOptions, "registry_url")
	assert.NotEmpty(t, registryURL)
}

func TestContainerRegistryMultiRegional(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/storage/container-registry",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"location":    "EU",
			"environment": "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	registryURL := terraform.Output(t, terraformOptions, "registry_url")
	assert.NotEmpty(t, registryURL)
	assert.Contains(t, registryURL, "eu.gcr.io")
}
