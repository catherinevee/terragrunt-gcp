package compute

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

func TestCloudFunctionBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	functionName := testhelpers.GetTestResourceName("cf-basic", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/compute/cloud-functions",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"region":        config.Region,
			"name":          functionName,
			"runtime":       "python39",
			"entry_point":   "hello_world",
			"source_bucket": "test-source-bucket",
			"source_object": "function-source.zip",
			"environment":   "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify function outputs
	functionNameOutput := terraform.Output(t, terraformOptions, "function_name")
	assert.Equal(t, functionName, functionNameOutput)

	httpsTriggerURL := terraform.Output(t, terraformOptions, "https_trigger_url")
	assert.NotEmpty(t, httpsTriggerURL)
	assert.Contains(t, httpsTriggerURL, "cloudfunctions.net")
}

func TestCloudFunctionWithPubSubTrigger(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	functionName := testhelpers.GetTestResourceName("cf-pubsub", config.RandomID)
	topicName := testhelpers.GetTestResourceName("topic", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/compute/cloud-functions",
		Vars: map[string]interface{}{
			"project_id":      config.ProjectID,
			"region":          config.Region,
			"name":            functionName,
			"runtime":         "python39",
			"entry_point":     "process_pubsub",
			"source_bucket":   "test-source-bucket",
			"source_object":   "function-source.zip",
			"environment":     "test",
			"trigger_type":    "pubsub",
			"pubsub_topic":    topicName,
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	functionNameOutput := terraform.Output(t, terraformOptions, "function_name")
	assert.Equal(t, functionName, functionNameOutput)
}

func TestCloudFunctionWithEnvironmentVariables(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	functionName := testhelpers.GetTestResourceName("cf-env", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/compute/cloud-functions",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"region":        config.Region,
			"name":          functionName,
			"runtime":       "python39",
			"entry_point":   "hello_world",
			"source_bucket": "test-source-bucket",
			"source_object": "function-source.zip",
			"environment":   "test",
			"environment_variables": map[string]string{
				"API_KEY":     "test-key",
				"ENVIRONMENT": "test",
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	functionNameOutput := terraform.Output(t, terraformOptions, "function_name")
	assert.Equal(t, functionName, functionNameOutput)
}
