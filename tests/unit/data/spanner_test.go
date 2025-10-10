package data

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

func TestSpannerInstanceBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	instanceName := testhelpers.GetTestResourceName("spanner-inst", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/data/spanner",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"name":        instanceName,
			"config":      "regional-" + config.Region,
			"node_count":  1,
			"environment": "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify instance outputs
	instanceNameOutput := terraform.Output(t, terraformOptions, "instance_name")
	assert.Equal(t, instanceName, instanceNameOutput)

	instanceID := terraform.Output(t, terraformOptions, "instance_id")
	assert.NotEmpty(t, instanceID)
}

func TestSpannerDatabaseBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	instanceName := testhelpers.GetTestResourceName("spanner-inst", config.RandomID)
	databaseName := testhelpers.GetTestResourceName("database", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/data/spanner",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"name":          instanceName,
			"config":        "regional-" + config.Region,
			"node_count":    1,
			"environment":   "test",
			"database_name": databaseName,
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify database outputs
	dbNameOutput := terraform.Output(t, terraformOptions, "database_name")
	assert.Equal(t, databaseName, dbNameOutput)

	dbID := terraform.Output(t, terraformOptions, "database_id")
	assert.NotEmpty(t, dbID)
}

func TestSpannerMultiRegionalInstance(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	instanceName := testhelpers.GetTestResourceName("spanner-multi", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/data/spanner",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"name":        instanceName,
			"config":      "nam3", // North America multi-region
			"node_count":  2,
			"environment": "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	instanceNameOutput := terraform.Output(t, terraformOptions, "instance_name")
	assert.Equal(t, instanceName, instanceNameOutput)
}

func TestSpannerWithIAM(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	instanceName := testhelpers.GetTestResourceName("spanner-iam", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/data/spanner",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"name":        instanceName,
			"config":      "regional-" + config.Region,
			"node_count":  1,
			"environment": "test",
			"iam_bindings": map[string]interface{}{
				"roles/spanner.databaseReader": []string{
					"serviceAccount:test@example.com",
				},
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	instanceNameOutput := terraform.Output(t, terraformOptions, "instance_name")
	assert.Equal(t, instanceName, instanceNameOutput)
}
