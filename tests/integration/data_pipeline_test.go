package integration

import (
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

// TestDataPipelineStack tests a complete data processing pipeline with:
// - Cloud Storage for data ingestion
// - Pub/Sub for event streaming
// - Dataproc for batch processing
// - BigQuery for analytics
// - Cloud Functions for orchestration
func TestDataPipelineStack(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	pipelineName := testhelpers.GetTestResourceName("data-pipeline", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../fixtures/data-pipeline",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"region":        config.Region,
			"pipeline_name": pipelineName,
			"environment":   "test",
		},
		NoColor:      true,
		Logger:       logger.Discard,
		RetryableTerraformErrors: map[string]string{
			".*timeout while waiting.*": "Resource creation timeout",
		},
		MaxRetries:         3,
		TimeBetweenRetries: 10 * time.Second,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify Cloud Storage bucket for ingestion
	ingestBucket := terraform.Output(t, terraformOptions, "ingest_bucket_name")
	assert.NotEmpty(t, ingestBucket)
	assert.Contains(t, ingestBucket, pipelineName)

	// Verify Pub/Sub topic
	pubsubTopic := terraform.Output(t, terraformOptions, "pubsub_topic_name")
	assert.NotEmpty(t, pubsubTopic)

	// Verify Dataproc cluster
	dataprocCluster := terraform.Output(t, terraformOptions, "dataproc_cluster_name")
	assert.NotEmpty(t, dataprocCluster)

	// Verify BigQuery dataset
	bqDataset := terraform.Output(t, terraformOptions, "bigquery_dataset_id")
	assert.NotEmpty(t, bqDataset)

	// Verify Cloud Function
	functionURL := terraform.Output(t, terraformOptions, "function_url")
	assert.NotEmpty(t, functionURL)
}

// TestMLWorkloadStack tests a machine learning workload with:
// - GKE cluster for model training
// - Cloud Storage for model artifacts
// - Vertex AI integration
// - Cloud Build for CI/CD
func TestMLWorkloadStack(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	workloadName := testhelpers.GetTestResourceName("ml-workload", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../fixtures/ml-workload",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"region":        config.Region,
			"workload_name": workloadName,
			"environment":   "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify GKE cluster
	gkeCluster := terraform.Output(t, terraformOptions, "gke_cluster_name")
	assert.NotEmpty(t, gkeCluster)

	// Verify model artifacts bucket
	artifactsBucket := terraform.Output(t, terraformOptions, "artifacts_bucket_name")
	assert.NotEmpty(t, artifactsBucket)

	// Verify service account
	serviceAccount := terraform.Output(t, terraformOptions, "ml_service_account")
	assert.NotEmpty(t, serviceAccount)
}

// TestEventDrivenArchitecture tests an event-driven microservices architecture with:
// - Cloud Run services
// - Pub/Sub for event bus
// - Cloud Scheduler for cron jobs
// - Firestore for state management
// - Cloud Tasks for async processing
func TestEventDrivenArchitecture(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	archName := testhelpers.GetTestResourceName("event-driven", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../fixtures/event-driven-arch",
		Vars: map[string]interface{}{
			"project_id":        config.ProjectID,
			"region":            config.Region,
			"architecture_name": archName,
			"environment":       "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify Cloud Run services
	services := terraform.OutputList(t, terraformOptions, "cloud_run_services")
	assert.GreaterOrEqual(t, len(services), 2)

	// Verify Pub/Sub topics
	topics := terraform.OutputList(t, terraformOptions, "pubsub_topics")
	assert.GreaterOrEqual(t, len(topics), 1)

	// Verify Cloud Scheduler jobs
	schedulerJobs := terraform.OutputList(t, terraformOptions, "scheduler_jobs")
	assert.GreaterOrEqual(t, len(schedulerJobs), 1)

	// Verify Firestore database
	firestoreDB := terraform.Output(t, terraformOptions, "firestore_database")
	assert.NotEmpty(t, firestoreDB)
}

// TestDisasterRecoverySetup tests a DR configuration with:
// - Multi-region deployment
// - Cloud Spanner for globally distributed data
// - Cross-region replication
// - Load balancing across regions
func TestDisasterRecoverySetup(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	drName := testhelpers.GetTestResourceName("dr-setup", config.RandomID)
	primaryRegion := "us-central1"
	secondaryRegion := "us-east1"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../fixtures/disaster-recovery",
		Vars: map[string]interface{}{
			"project_id":       config.ProjectID,
			"dr_name":          drName,
			"primary_region":   primaryRegion,
			"secondary_region": secondaryRegion,
			"environment":      "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify Spanner instance
	spannerInstance := terraform.Output(t, terraformOptions, "spanner_instance")
	assert.NotEmpty(t, spannerInstance)

	// Verify regional VPCs
	primaryVPC := terraform.Output(t, terraformOptions, "primary_vpc")
	assert.NotEmpty(t, primaryVPC)

	secondaryVPC := terraform.Output(t, terraformOptions, "secondary_vpc")
	assert.NotEmpty(t, secondaryVPC)

	// Verify global load balancer
	lbIPAddress := terraform.Output(t, terraformOptions, "lb_ip_address")
	assert.NotEmpty(t, lbIPAddress)
}
