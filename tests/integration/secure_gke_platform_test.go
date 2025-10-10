package integration

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/your-org/terragrunt-gcp/tests/internal/testhelpers"
)

// TestSecureGKEPlatform tests a complete secure GKE platform deployment including:
// - Private GKE cluster with Workload Identity
// - VPC with private subnets and Cloud NAT
// - Binary Authorization policy
// - Cloud Armor security policy
// - Secret Manager for credentials
// - KMS for encryption
// - Cloud Logging and Monitoring
func TestSecureGKEPlatform(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	platformName := testhelpers.GetTestResourceName("secure-gke", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../fixtures/secure-gke-platform",
		Vars: map[string]interface{}{
			"project_id":     config.ProjectID,
			"name":           platformName,
			"region":         config.Region,
			"zones":          []string{config.Zone},
			"network_name":   fmt.Sprintf("%s-vpc", platformName),
			"subnet_cidr":    "10.0.0.0/20",
			"pod_cidr":       "10.4.0.0/14",
			"service_cidr":   "10.8.0.0/20",
			"master_cidr":    "172.16.0.0/28",
			"enable_private_nodes":    true,
			"enable_private_endpoint": false,
			"enable_workload_identity": true,
			"enable_binary_authz":     true,
			"enable_cloud_armor":      true,
			"enable_pod_security_policy": true,
			"enable_network_policy":   true,
			"node_pools": []map[string]interface{}{
				{
					"name":         "default-pool",
					"machine_type": "e2-medium",
					"min_count":    1,
					"max_count":    3,
					"disk_size_gb": 50,
					"disk_type":    "pd-standard",
				},
			},
		},
		NoColor:      true,
		Logger:       logger.Discard,
		MaxRetries:   3,
		TimeBetweenRetries: 10 * time.Second,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify VPC and networking
	networkName := terraform.Output(t, terraformOptions, "network_name")
	assert.Contains(t, networkName, platformName)

	subnetName := terraform.Output(t, terraformOptions, "subnet_name")
	assert.NotEmpty(t, subnetName)

	// Verify Cloud NAT
	natGatewayName := terraform.Output(t, terraformOptions, "nat_gateway_name")
	assert.NotEmpty(t, natGatewayName)

	// Verify GKE cluster
	clusterName := terraform.Output(t, terraformOptions, "cluster_name")
	assert.Contains(t, clusterName, platformName)

	cluster := gcp.FetchGKECluster(t, config.ProjectID, config.Region, clusterName)
	assert.NotNil(t, cluster)
	assert.True(t, cluster.PrivateClusterConfig.EnablePrivateNodes)
	assert.True(t, cluster.WorkloadIdentityConfig != nil)

	// Verify Binary Authorization is enabled
	binaryAuthzEnabled := terraform.Output(t, terraformOptions, "binary_authorization_enabled")
	assert.Equal(t, "true", binaryAuthzEnabled)

	// Verify encryption
	kmsKeyRingName := terraform.Output(t, terraformOptions, "kms_keyring_name")
	assert.NotEmpty(t, kmsKeyRingName)

	kmsCryptoKeyName := terraform.Output(t, terraformOptions, "kms_crypto_key_name")
	assert.NotEmpty(t, kmsCryptoKeyName)

	// Verify Secret Manager
	secretName := terraform.Output(t, terraformOptions, "secret_name")
	assert.NotEmpty(t, secretName)

	// Verify Cloud Armor policy
	armorPolicyName := terraform.Output(t, terraformOptions, "cloud_armor_policy_name")
	assert.NotEmpty(t, armorPolicyName)

	// Verify logging sink
	loggingSinkName := terraform.Output(t, terraformOptions, "logging_sink_name")
	assert.NotEmpty(t, loggingSinkName)

	// Wait for cluster to be ready
	maxRetries := 20
	sleepBetweenRetries := 30 * time.Second
	retry.DoWithRetry(t, "Wait for GKE cluster to be ready", maxRetries, sleepBetweenRetries, func() (string, error) {
		cluster := gcp.FetchGKECluster(t, config.ProjectID, config.Region, clusterName)
		if cluster.Status != "RUNNING" {
			return "", fmt.Errorf("Cluster status is %s, expected RUNNING", cluster.Status)
		}
		return "Cluster is ready", nil
	})
}

// TestMultiRegionGKEWithDR tests a disaster recovery setup with:
// - GKE clusters in multiple regions
// - Multi-regional GCS buckets for backups
// - Cloud Spanner for global database
// - Global load balancer
// - Cross-region VPC peering
func TestMultiRegionGKEWithDR(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	platformName := testhelpers.GetTestResourceName("multi-region-gke", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../fixtures/multi-region-gke-dr",
		Vars: map[string]interface{}{
			"project_id":      config.ProjectID,
			"name":            platformName,
			"primary_region":  "us-central1",
			"secondary_region": "us-east1",
			"tertiary_region": "europe-west1",
			"enable_multi_cluster_ingress": true,
			"enable_config_sync": true,
			"enable_backup":      true,
			"backup_schedule":    "0 2 * * *",
			"spanner_config":     "nam-eur-asia1",
		},
		NoColor:      true,
		Logger:       logger.Discard,
		MaxRetries:   3,
		TimeBetweenRetries: 10 * time.Second,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify primary cluster
	primaryClusterName := terraform.Output(t, terraformOptions, "primary_cluster_name")
	assert.Contains(t, primaryClusterName, platformName)

	// Verify secondary cluster
	secondaryClusterName := terraform.Output(t, terraformOptions, "secondary_cluster_name")
	assert.Contains(t, secondaryClusterName, platformName)

	// Verify tertiary cluster
	tertiaryClusterName := terraform.Output(t, terraformOptions, "tertiary_cluster_name")
	assert.Contains(t, tertiaryClusterName, platformName)

	// Verify Spanner instance
	spannerInstanceName := terraform.Output(t, terraformOptions, "spanner_instance_name")
	assert.NotEmpty(t, spannerInstanceName)

	// Verify backup bucket
	backupBucketName := terraform.Output(t, terraformOptions, "backup_bucket_name")
	assert.NotEmpty(t, backupBucketName)

	// Verify global load balancer
	globalLBName := terraform.Output(t, terraformOptions, "global_lb_name")
	assert.NotEmpty(t, globalLBName)

	globalLBIP := terraform.Output(t, terraformOptions, "global_lb_ip")
	assert.NotEmpty(t, globalLBIP)
}

// TestServerlessMLPlatform tests a serverless ML platform with:
// - Cloud Run for model serving
// - Cloud Functions for preprocessing
// - Pub/Sub for event streaming
// - GCS for model and data storage
// - Firestore for metadata
// - Cloud Scheduler for batch jobs
func TestServerlessMLPlatform(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	platformName := testhelpers.GetTestResourceName("ml-platform", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../fixtures/serverless-ml-platform",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"name":          platformName,
			"region":        config.Region,
			"model_bucket":  fmt.Sprintf("%s-models", platformName),
			"data_bucket":   fmt.Sprintf("%s-data", platformName),
			"cloud_run_services": []map[string]interface{}{
				{
					"name":           "model-serving",
					"image":          "gcr.io/cloudrun/hello",
					"max_instances":  10,
					"memory":         "2Gi",
					"cpu":            2,
					"timeout":        300,
				},
			},
			"cloud_functions": []map[string]interface{}{
				{
					"name":           "data-preprocessing",
					"runtime":        "python39",
					"entry_point":    "preprocess",
					"memory":         512,
					"timeout":        540,
				},
			},
			"enable_firestore":   true,
			"firestore_location": "nam5",
			"batch_schedules": []map[string]interface{}{
				{
					"name":     "daily-training",
					"schedule": "0 2 * * *",
					"timezone": "America/New_York",
				},
			},
		},
		NoColor:      true,
		Logger:       logger.Discard,
		MaxRetries:   3,
		TimeBetweenRetries: 10 * time.Second,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify Cloud Run service
	cloudRunServiceName := terraform.Output(t, terraformOptions, "cloud_run_service_name")
	assert.Contains(t, cloudRunServiceName, "model-serving")

	cloudRunURL := terraform.Output(t, terraformOptions, "cloud_run_url")
	assert.NotEmpty(t, cloudRunURL)

	// Verify Cloud Function
	cloudFunctionName := terraform.Output(t, terraformOptions, "cloud_function_name")
	assert.Contains(t, cloudFunctionName, "data-preprocessing")

	// Verify Pub/Sub topic
	pubsubTopicName := terraform.Output(t, terraformOptions, "pubsub_topic_name")
	assert.NotEmpty(t, pubsubTopicName)

	// Verify GCS buckets
	modelBucketName := terraform.Output(t, terraformOptions, "model_bucket_name")
	assert.Contains(t, modelBucketName, "models")

	dataBucketName := terraform.Output(t, terraformOptions, "data_bucket_name")
	assert.Contains(t, dataBucketName, "data")

	// Verify Firestore
	firestoreDatabaseName := terraform.Output(t, terraformOptions, "firestore_database_name")
	assert.NotEmpty(t, firestoreDatabaseName)

	// Verify Cloud Scheduler job
	schedulerJobName := terraform.Output(t, terraformOptions, "scheduler_job_name")
	assert.Contains(t, schedulerJobName, "daily-training")
}
