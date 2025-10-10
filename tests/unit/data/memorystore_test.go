package data

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

func TestMemorystoreRedisBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	instanceName := testhelpers.GetTestResourceName("redis-basic", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/data/memorystore",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"name":          instanceName,
			"region":        config.Region,
			"tier":          "BASIC",
			"memory_size_gb": 1,
			"environment":   "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify instance outputs
	instanceNameOutput := terraform.Output(t, terraformOptions, "instance_name")
	assert.Equal(t, instanceName, instanceNameOutput)

	host := terraform.Output(t, terraformOptions, "host")
	assert.NotEmpty(t, host)

	port := terraform.Output(t, terraformOptions, "port")
	assert.Equal(t, "6379", port)
}

func TestMemorystoreRedisStandardHA(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	instanceName := testhelpers.GetTestResourceName("redis-ha", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/data/memorystore",
		Vars: map[string]interface{}{
			"project_id":       config.ProjectID,
			"name":             instanceName,
			"region":           config.Region,
			"tier":             "STANDARD_HA",
			"memory_size_gb":   5,
			"environment":      "test",
			"redis_version":    "REDIS_6_X",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	instanceNameOutput := terraform.Output(t, terraformOptions, "instance_name")
	assert.Equal(t, instanceName, instanceNameOutput)

	replicaHost := terraform.Output(t, terraformOptions, "read_replica_host")
	assert.NotEmpty(t, replicaHost)
}

func TestMemorystoreRedisWithAuthEnabled(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	instanceName := testhelpers.GetTestResourceName("redis-auth", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/data/memorystore",
		Vars: map[string]interface{}{
			"project_id":       config.ProjectID,
			"name":             instanceName,
			"region":           config.Region,
			"tier":             "BASIC",
			"memory_size_gb":   1,
			"environment":      "test",
			"auth_enabled":     true,
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	authString := terraform.Output(t, terraformOptions, "auth_string")
	assert.NotEmpty(t, authString)
}
