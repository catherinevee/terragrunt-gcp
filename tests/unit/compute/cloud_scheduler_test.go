package compute

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

func TestCloudSchedulerJobBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	jobName := testhelpers.GetTestResourceName("scheduler-job", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/compute/cloud-scheduler",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"region":      config.Region,
			"name":        jobName,
			"schedule":    "0 0 * * *", // Daily at midnight
			"time_zone":   "America/New_York",
			"environment": "test",
			"http_target": map[string]interface{}{
				"uri":         "https://example.com/endpoint",
				"http_method": "POST",
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify job outputs
	jobNameOutput := terraform.Output(t, terraformOptions, "job_name")
	assert.Equal(t, jobName, jobNameOutput)

	jobID := terraform.Output(t, terraformOptions, "job_id")
	assert.NotEmpty(t, jobID)
}

func TestCloudSchedulerWithPubSubTarget(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	jobName := testhelpers.GetTestResourceName("scheduler-pubsub", config.RandomID)
	topicName := testhelpers.GetTestResourceName("topic", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/compute/cloud-scheduler",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"region":      config.Region,
			"name":        jobName,
			"schedule":    "*/5 * * * *", // Every 5 minutes
			"time_zone":   "UTC",
			"environment": "test",
			"pubsub_target": map[string]interface{}{
				"topic_name": topicName,
				"data":       "SGVsbG8gV29ybGQ=", // Base64 encoded "Hello World"
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	jobNameOutput := terraform.Output(t, terraformOptions, "job_name")
	assert.Equal(t, jobName, jobNameOutput)
}

func TestCloudSchedulerWithAppEngineTarget(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	jobName := testhelpers.GetTestResourceName("scheduler-appeng", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/compute/cloud-scheduler",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"region":      config.Region,
			"name":        jobName,
			"schedule":    "0 2 * * *", // Daily at 2am
			"time_zone":   "America/Los_Angeles",
			"environment": "test",
			"app_engine_http_target": map[string]interface{}{
				"http_method":          "GET",
				"relative_uri":         "/tasks/cleanup",
				"app_engine_routing": map[string]interface{}{
					"service": "default",
				},
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	jobNameOutput := terraform.Output(t, terraformOptions, "job_name")
	assert.Equal(t, jobName, jobNameOutput)
}

func TestCloudSchedulerWithRetryConfig(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	jobName := testhelpers.GetTestResourceName("scheduler-retry", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/compute/cloud-scheduler",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"region":      config.Region,
			"name":        jobName,
			"schedule":    "0 * * * *", // Hourly
			"time_zone":   "UTC",
			"environment": "test",
			"http_target": map[string]interface{}{
				"uri":         "https://example.com/task",
				"http_method": "POST",
			},
			"retry_config": map[string]interface{}{
				"retry_count":          3,
				"max_retry_duration":   "600s",
				"min_backoff_duration": "5s",
				"max_backoff_duration": "3600s",
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	jobNameOutput := terraform.Output(t, terraformOptions, "job_name")
	assert.Equal(t, jobName, jobNameOutput)
}
