package data

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/your-org/terragrunt-gcp/tests/internal/testhelpers"
)

func TestDataflowJobBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	jobName := testhelpers.GetTestResourceName("dataflow-basic", config.RandomID)
	bucketName := testhelpers.GetTestResourceName("df-bucket", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/data/dataflow",
		Vars: map[string]interface{}{
			"project_id":           config.ProjectID,
			"name":                 jobName,
			"region":               config.Region,
			"temp_gcs_location":    fmt.Sprintf("gs://%s/temp", bucketName),
			"template_gcs_path":    "gs://dataflow-templates/latest/Word_Count",
			"zone":                 config.Zone,
			"max_workers":          2,
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	jobID := terraform.Output(t, terraformOptions, "job_id")
	assert.NotEmpty(t, jobID)

	jobState := terraform.Output(t, terraformOptions, "job_state")
	assert.Contains(t, []string{"JOB_STATE_RUNNING", "JOB_STATE_DONE", "JOB_STATE_PENDING"}, jobState)
}

func TestDataflowJobWithStreaming(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	jobName := testhelpers.GetTestResourceName("dataflow-stream", config.RandomID)
	bucketName := testhelpers.GetTestResourceName("df-stream-bucket", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/data/dataflow",
		Vars: map[string]interface{}{
			"project_id":           config.ProjectID,
			"name":                 jobName,
			"region":               config.Region,
			"temp_gcs_location":    fmt.Sprintf("gs://%s/temp", bucketName),
			"template_gcs_path":    "gs://dataflow-templates/latest/PubSub_to_BigQuery",
			"zone":                 config.Zone,
			"max_workers":          4,
			"enable_streaming_engine": true,
			"parameters": map[string]string{
				"inputTopic":      "projects/project-id/topics/input-topic",
				"outputTableSpec": "project-id:dataset.table",
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	jobID := terraform.Output(t, terraformOptions, "job_id")
	assert.NotEmpty(t, jobID)

	streamingEngineEnabled := terraform.Output(t, terraformOptions, "streaming_engine_enabled")
	assert.Equal(t, "true", streamingEngineEnabled)
}

func TestDataflowJobWithAutoscaling(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	jobName := testhelpers.GetTestResourceName("dataflow-autoscale", config.RandomID)
	bucketName := testhelpers.GetTestResourceName("df-autoscale-bucket", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/data/dataflow",
		Vars: map[string]interface{}{
			"project_id":           config.ProjectID,
			"name":                 jobName,
			"region":               config.Region,
			"temp_gcs_location":    fmt.Sprintf("gs://%s/temp", bucketName),
			"template_gcs_path":    "gs://dataflow-templates/latest/Word_Count",
			"zone":                 config.Zone,
			"max_workers":          10,
			"num_workers":          2,
			"autoscaling_algorithm": "THROUGHPUT_BASED",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	jobID := terraform.Output(t, terraformOptions, "job_id")
	assert.NotEmpty(t, jobID)

	autoscalingAlgorithm := terraform.Output(t, terraformOptions, "autoscaling_algorithm")
	assert.Equal(t, "THROUGHPUT_BASED", autoscalingAlgorithm)

	maxWorkers := terraform.Output(t, terraformOptions, "max_workers")
	assert.Equal(t, "10", maxWorkers)
}

func TestDataflowJobWithCustomNetwork(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	jobName := testhelpers.GetTestResourceName("dataflow-network", config.RandomID)
	bucketName := testhelpers.GetTestResourceName("df-network-bucket", config.RandomID)
	networkName := testhelpers.GetTestResourceName("df-vpc", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/data/dataflow",
		Vars: map[string]interface{}{
			"project_id":           config.ProjectID,
			"name":                 jobName,
			"region":               config.Region,
			"temp_gcs_location":    fmt.Sprintf("gs://%s/temp", bucketName),
			"template_gcs_path":    "gs://dataflow-templates/latest/Word_Count",
			"zone":                 config.Zone,
			"max_workers":          2,
			"network":              networkName,
			"subnetwork":           fmt.Sprintf("regions/%s/subnetworks/%s-subnet", config.Region, networkName),
			"ip_configuration":     "WORKER_IP_PRIVATE",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	jobID := terraform.Output(t, terraformOptions, "job_id")
	assert.NotEmpty(t, jobID)

	ipConfiguration := terraform.Output(t, terraformOptions, "ip_configuration")
	assert.Equal(t, "WORKER_IP_PRIVATE", ipConfiguration)

	network := terraform.Output(t, terraformOptions, "network")
	assert.Contains(t, network, networkName)
}
