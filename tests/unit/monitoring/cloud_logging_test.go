package monitoring

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

func TestCloudLoggingSinkBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	sinkName := testhelpers.GetTestResourceName("log-sink", config.RandomID)
	bucketName := testhelpers.GetTestResourceName("log-bucket", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/monitoring/cloud-logging",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"name":          sinkName,
			"destination":   "storage.googleapis.com/" + bucketName,
			"filter":        "resource.type = gce_instance",
			"environment":   "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify sink outputs
	sinkNameOutput := terraform.Output(t, terraformOptions, "sink_name")
	assert.Equal(t, sinkName, sinkNameOutput)

	writerIdentity := terraform.Output(t, terraformOptions, "writer_identity")
	assert.NotEmpty(t, writerIdentity)
}

func TestCloudLoggingSinkToBigQuery(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	sinkName := testhelpers.GetTestResourceName("log-sink-bq", config.RandomID)
	datasetName := testhelpers.GetTestResourceName("logs_dataset", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/monitoring/cloud-logging",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"name":        sinkName,
			"destination": "bigquery.googleapis.com/projects/" + config.ProjectID + "/datasets/" + datasetName,
			"filter":      "severity >= ERROR",
			"environment": "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	sinkNameOutput := terraform.Output(t, terraformOptions, "sink_name")
	assert.Equal(t, sinkName, sinkNameOutput)
}

func TestCloudLoggingSinkToPubSub(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	sinkName := testhelpers.GetTestResourceName("log-sink-ps", config.RandomID)
	topicName := testhelpers.GetTestResourceName("log-topic", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/monitoring/cloud-logging",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"name":        sinkName,
			"destination": "pubsub.googleapis.com/projects/" + config.ProjectID + "/topics/" + topicName,
			"filter":      "resource.type = cloud_function",
			"environment": "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	sinkNameOutput := terraform.Output(t, terraformOptions, "sink_name")
	assert.Equal(t, sinkName, sinkNameOutput)
}

func TestCloudLoggingExclusion(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	exclusionName := testhelpers.GetTestResourceName("log-exclusion", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/monitoring/cloud-logging",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"exclusions": []map[string]interface{}{
				{
					"name":        exclusionName,
					"description": "Exclude debug logs",
					"filter":      "severity < WARNING",
				},
			},
			"environment": "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	exclusionNameOutput := terraform.Output(t, terraformOptions, "exclusion_name")
	assert.Equal(t, exclusionName, exclusionNameOutput)
}
