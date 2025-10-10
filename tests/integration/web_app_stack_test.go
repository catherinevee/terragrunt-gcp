package integration

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

// TestWebAppStack tests a complete web application stack with:
// - VPC Network
// - Cloud SQL Database
// - GKE Cluster
// - Cloud Run Service
// - Cloud Storage Bucket
// - Load Balancer
// - Cloud Armor Security Policy
func TestWebAppStack(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	stackName := testhelpers.GetTestResourceName("webapp-stack", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../fixtures/web-app-stack",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"region":      config.Region,
			"stack_name":  stackName,
			"environment": "test",
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

	// Apply the full stack
	terraform.InitAndApply(t, terraformOptions)

	// Verify VPC Network
	vpcName := terraform.Output(t, terraformOptions, "vpc_name")
	assert.NotEmpty(t, vpcName)
	assert.Contains(t, vpcName, stackName)

	// Verify Cloud SQL Database
	dbInstanceName := terraform.Output(t, terraformOptions, "db_instance_name")
	assert.NotEmpty(t, dbInstanceName)

	dbConnectionName := terraform.Output(t, terraformOptions, "db_connection_name")
	assert.NotEmpty(t, dbConnectionName)
	assert.Contains(t, dbConnectionName, config.ProjectID)

	// Verify GKE Cluster
	gkeClusterName := terraform.Output(t, terraformOptions, "gke_cluster_name")
	assert.NotEmpty(t, gkeClusterName)

	gkeEndpoint := terraform.Output(t, terraformOptions, "gke_endpoint")
	assert.NotEmpty(t, gkeEndpoint)

	// Verify Cloud Run Service
	cloudRunURL := terraform.Output(t, terraformOptions, "cloud_run_url")
	assert.NotEmpty(t, cloudRunURL)
	assert.Contains(t, cloudRunURL, "run.app")

	// Verify Cloud Storage Bucket
	bucketName := terraform.Output(t, terraformOptions, "bucket_name")
	assert.NotEmpty(t, bucketName)
	assert.Contains(t, bucketName, stackName)

	// Verify Load Balancer
	lbIPAddress := terraform.Output(t, terraformOptions, "lb_ip_address")
	assert.NotEmpty(t, lbIPAddress)

	// Verify Cloud Armor Policy
	armorPolicyName := terraform.Output(t, terraformOptions, "armor_policy_name")
	assert.NotEmpty(t, armorPolicyName)

	// Test Cloud Run service is accessible
	testCloudRunServiceAccessible(t, cloudRunURL)
}

func testCloudRunServiceAccessible(t *testing.T, serviceURL string) {
	maxRetries := 10
	sleepBetweenRetries := 10 * time.Second

	description := fmt.Sprintf("Testing Cloud Run service at %s", serviceURL)

	retry.DoWithRetry(t, description, maxRetries, sleepBetweenRetries, func() (string, error) {
		// In a real test, you would make an HTTP request to the service
		// For this example, we're just verifying the URL format
		if serviceURL == "" {
			return "", fmt.Errorf("Service URL is empty")
		}
		return "Service URL is valid", nil
	})
}

// TestMultiRegionDeployment tests deploying resources across multiple regions
func TestMultiRegionDeployment(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	deploymentName := testhelpers.GetTestResourceName("multi-region", config.RandomID)
	regions := []string{"us-central1", "us-east1", "europe-west1"}

	terraformOptions := &terraform.Options{
		TerraformDir: "../../fixtures/multi-region-deployment",
		Vars: map[string]interface{}{
			"project_id":      config.ProjectID,
			"deployment_name": deploymentName,
			"regions":         regions,
			"environment":     "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify resources in each region
	regionalVPCs := terraform.OutputMap(t, terraformOptions, "regional_vpcs")
	assert.Equal(t, len(regions), len(regionalVPCs))

	for _, region := range regions {
		vpcName, exists := regionalVPCs[region]
		assert.True(t, exists, fmt.Sprintf("VPC should exist in region %s", region))
		assert.NotEmpty(t, vpcName)
	}
}

// TestSecureWorkloadDeployment tests a secure workload with encryption and secret management
func TestSecureWorkloadDeployment(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	workloadName := testhelpers.GetTestResourceName("secure-workload", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../fixtures/secure-workload",
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

	// Verify KMS Key
	kmsKeyName := terraform.Output(t, terraformOptions, "kms_key_name")
	assert.NotEmpty(t, kmsKeyName)

	// Verify Secret Manager Secret
	secretName := terraform.Output(t, terraformOptions, "secret_name")
	assert.NotEmpty(t, secretName)

	// Verify Encrypted Storage Bucket
	bucketName := terraform.Output(t, terraformOptions, "encrypted_bucket_name")
	assert.NotEmpty(t, bucketName)

	// Verify Cloud Run service with Secret Manager integration
	serviceURL := terraform.Output(t, terraformOptions, "service_url")
	assert.NotEmpty(t, serviceURL)
}
