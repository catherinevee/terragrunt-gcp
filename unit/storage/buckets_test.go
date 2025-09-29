package storage

import (
	"testing"
	"time"

	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestStorageBucket(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/storage/buckets",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"name":          testhelpers.GetTestResourceName("test-bucket", config.RandomID),
			"location":      config.Region,
			"storage_class": "STANDARD",
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test storage bucket creation
	bucketName := terraform.Output(t, terraformOptions, "bucket_name")
	assert.NotEmpty(t, bucketName, "Bucket name should not be empty")
	assert.Contains(t, bucketName, "test-bucket-", "Bucket name should contain test prefix")

	// Test storage bucket exists in GCP
	bucket := gcp.GetStorageBucket(t, bucketName)
	assert.NotNil(t, bucket, "Storage bucket should exist in GCP")
	assert.Equal(t, "test-bucket-"+config.RandomID, bucket.Name, "Bucket name should match expected value")
	assert.Equal(t, config.Region, bucket.Location, "Bucket location should match expected value")
	assert.Equal(t, "STANDARD", bucket.StorageClass, "Storage class should match expected value")
}

func TestStorageBucketWithVersioning(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/storage/buckets",
		Vars: map[string]interface{}{
			"project_id":         config.ProjectID,
			"name":               testhelpers.GetTestResourceName("test-bucket", config.RandomID),
			"location":           config.Region,
			"storage_class":      "STANDARD",
			"versioning_enabled": true,
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test storage bucket creation
	bucketName := terraform.Output(t, terraformOptions, "bucket_name")
	assert.NotEmpty(t, bucketName, "Bucket name should not be empty")

	// Test storage bucket exists in GCP
	bucket := gcp.GetStorageBucket(t, bucketName)
	assert.NotNil(t, bucket, "Storage bucket should exist in GCP")

	// Test versioning configuration
	versioningEnabled := terraform.Output(t, terraformOptions, "versioning_enabled")
	assert.Equal(t, "true", versioningEnabled, "Versioning should be enabled")
}

func TestStorageBucketWithLifecycle(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/storage/buckets",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"name":          testhelpers.GetTestResourceName("test-bucket", config.RandomID),
			"location":      config.Region,
			"storage_class": "STANDARD",
			"lifecycle_rules": []map[string]interface{}{
				{
					"action": map[string]interface{}{
						"type": "Delete",
					},
					"condition": map[string]interface{}{
						"age": 30,
					},
				},
				{
					"action": map[string]interface{}{
						"type":          "SetStorageClass",
						"storage_class": "NEARLINE",
					},
					"condition": map[string]interface{}{
						"age": 7,
					},
				},
			},
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test storage bucket creation
	bucketName := terraform.Output(t, terraformOptions, "bucket_name")
	assert.NotEmpty(t, bucketName, "Bucket name should not be empty")

	// Test storage bucket exists in GCP
	bucket := gcp.GetStorageBucket(t, bucketName)
	assert.NotNil(t, bucket, "Storage bucket should exist in GCP")

	// Test lifecycle rules configuration
	lifecycleRuleCount := terraform.Output(t, terraformOptions, "lifecycle_rule_count")
	assert.Equal(t, "2", lifecycleRuleCount, "Should have 2 lifecycle rules")
}

func TestStorageBucketWithEncryption(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/storage/buckets",
		Vars: map[string]interface{}{
			"project_id":          config.ProjectID,
			"name":                testhelpers.GetTestResourceName("test-bucket", config.RandomID),
			"location":            config.Region,
			"storage_class":       "STANDARD",
			"encryption_key_name": "projects/" + config.ProjectID + "/locations/" + config.Region + "/keyRings/test-keyring/cryptoKeys/test-key",
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test storage bucket creation
	bucketName := terraform.Output(t, terraformOptions, "bucket_name")
	assert.NotEmpty(t, bucketName, "Bucket name should not be empty")

	// Test storage bucket exists in GCP
	bucket := gcp.GetStorageBucket(t, bucketName)
	assert.NotNil(t, bucket, "Storage bucket should exist in GCP")

	// Test encryption configuration
	encryptionKeyName := terraform.Output(t, terraformOptions, "encryption_key_name")
	assert.NotEmpty(t, encryptionKeyName, "Encryption key name should not be empty")
	assert.Contains(t, encryptionKeyName, "test-key", "Encryption key name should contain test key")
}

func TestStorageBucketWithIAM(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/storage/buckets",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"name":          testhelpers.GetTestResourceName("test-bucket", config.RandomID),
			"location":      config.Region,
			"storage_class": "STANDARD",
			"iam_bindings": []map[string]interface{}{
				{
					"role": "roles/storage.objectViewer",
					"members": []string{
						"serviceAccount:test-sa@" + config.ProjectID + ".iam.gserviceaccount.com",
					},
				},
				{
					"role": "roles/storage.objectCreator",
					"members": []string{
						"serviceAccount:test-sa@" + config.ProjectID + ".iam.gserviceaccount.com",
					},
				},
			},
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test storage bucket creation
	bucketName := terraform.Output(t, terraformOptions, "bucket_name")
	assert.NotEmpty(t, bucketName, "Bucket name should not be empty")

	// Test storage bucket exists in GCP
	bucket := gcp.GetStorageBucket(t, bucketName)
	assert.NotNil(t, bucket, "Storage bucket should exist in GCP")

	// Test IAM bindings configuration
	iamBindingCount := terraform.Output(t, terraformOptions, "iam_binding_count")
	assert.Equal(t, "2", iamBindingCount, "Should have 2 IAM bindings")
}

func TestStorageBucketWithCORS(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/storage/buckets",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"name":          testhelpers.GetTestResourceName("test-bucket", config.RandomID),
			"location":      config.Region,
			"storage_class": "STANDARD",
			"cors": []map[string]interface{}{
				{
					"origin":          []string{"*"},
					"method":          []string{"GET", "POST", "PUT", "DELETE"},
					"response_header": []string{"*"},
					"max_age_seconds": 3600,
				},
			},
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test storage bucket creation
	bucketName := terraform.Output(t, terraformOptions, "bucket_name")
	assert.NotEmpty(t, bucketName, "Bucket name should not be empty")

	// Test storage bucket exists in GCP
	bucket := gcp.GetStorageBucket(t, bucketName)
	assert.NotNil(t, bucket, "Storage bucket should exist in GCP")

	// Test CORS configuration
	corsRuleCount := terraform.Output(t, terraformOptions, "cors_rule_count")
	assert.Equal(t, "1", corsRuleCount, "Should have 1 CORS rule")
}

func TestStorageBucketModuleValidation(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Test module structure validation
	modulePath := "../../../infrastructure/modules/storage/buckets"
	requiredFiles := []string{"main.tf", "variables.tf", "outputs.tf"}
	testhelpers.ValidateModuleStructure(t, modulePath, requiredFiles)

	// Test Terraform format validation
	testhelpers.ValidateTerraformFormat(t, modulePath)

	// Test Terraform validate
	testhelpers.ValidateTerraformValidate(t, modulePath)
}

func TestStorageBucketModuleTimeout(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Set a shorter timeout for this test
	config.Timeout = 5 * time.Minute

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/storage/buckets",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"name":          testhelpers.GetTestResourceName("test-bucket", config.RandomID),
			"location":      config.Region,
			"storage_class": "STANDARD",
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Test that module deploys within timeout
	start := time.Now()
	terraform.InitAndApply(t, terraformOptions)
	duration := time.Since(start)

	assert.Less(t, duration, config.Timeout, "Module deployment should complete within timeout")
}
