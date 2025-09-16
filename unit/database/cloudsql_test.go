package database

import (
	"testing"
	"time"

	"../../testhelpers"
	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestCloudSQLInstance(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/database/cloudsql",
		Vars: map[string]interface{}{
			"project_id":        config.ProjectID,
			"region":            config.Region,
			"name":              testhelpers.GetTestResourceName("test-sql", config.RandomID),
			"database_version":  "POSTGRES_14",
			"tier":              "db-f1-micro",
			"disk_size":         10,
			"disk_type":         "PD_SSD",
			"backup_enabled":    true,
			"backup_start_time": "03:00",
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test Cloud SQL instance creation
	instanceName := terraform.Output(t, terraformOptions, "instance_name")
	assert.NotEmpty(t, instanceName, "Instance name should not be empty")
	assert.Contains(t, instanceName, "test-sql-", "Instance name should contain test prefix")

	// Test Cloud SQL instance exists in GCP
	instance := gcp.GetCloudSQLInstance(t, config.ProjectID, instanceName)
	assert.NotNil(t, instance, "Cloud SQL instance should exist in GCP")
	assert.Equal(t, "test-sql-"+config.RandomID, instance.Name, "Instance name should match expected value")
	assert.Equal(t, "POSTGRES_14", instance.DatabaseVersion, "Database version should match expected value")
	assert.Equal(t, "db-f1-micro", instance.Settings.Tier, "Instance tier should match expected value")
}

func TestCloudSQLDatabase(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/database/cloudsql",
		Vars: map[string]interface{}{
			"project_id":       config.ProjectID,
			"region":           config.Region,
			"name":             testhelpers.GetTestResourceName("test-sql", config.RandomID),
			"database_version": "POSTGRES_14",
			"tier":             "db-f1-micro",
			"disk_size":        10,
			"disk_type":        "PD_SSD",
			"databases": []map[string]interface{}{
				{
					"name":      "test_database",
					"charset":   "UTF8",
					"collation": "en_US.UTF8",
				},
				{
					"name":      "test_database_2",
					"charset":   "UTF8",
					"collation": "en_US.UTF8",
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

	// Test Cloud SQL instance creation
	instanceName := terraform.Output(t, terraformOptions, "instance_name")
	assert.NotEmpty(t, instanceName, "Instance name should not be empty")

	// Test database creation
	databaseNames := terraform.OutputList(t, terraformOptions, "database_names")
	assert.Len(t, databaseNames, 2, "Should have 2 databases")

	// Test each database exists in GCP
	expectedDatabases := []string{"test_database", "test_database_2"}
	for i, expectedName := range expectedDatabases {
		databaseName := databaseNames[i]
		assert.Equal(t, expectedName, databaseName, "Database name should match expected value")

		// Verify database exists in GCP
		database := gcp.GetCloudSQLDatabase(t, config.ProjectID, instanceName, databaseName)
		assert.NotNil(t, database, "Database should exist in GCP")
		assert.Equal(t, expectedName, database.Name, "Database name should match expected value")
	}
}

func TestCloudSQLUsers(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/database/cloudsql",
		Vars: map[string]interface{}{
			"project_id":       config.ProjectID,
			"region":           config.Region,
			"name":             testhelpers.GetTestResourceName("test-sql", config.RandomID),
			"database_version": "POSTGRES_14",
			"tier":             "db-f1-micro",
			"disk_size":        10,
			"disk_type":        "PD_SSD",
			"users": []map[string]interface{}{
				{
					"name":     "test_user",
					"password": "test_password_123",
				},
				{
					"name":     "test_user_2",
					"password": "test_password_456",
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

	// Test Cloud SQL instance creation
	instanceName := terraform.Output(t, terraformOptions, "instance_name")
	assert.NotEmpty(t, instanceName, "Instance name should not be empty")

	// Test user creation
	userNames := terraform.OutputList(t, terraformOptions, "user_names")
	assert.Len(t, userNames, 2, "Should have 2 users")

	// Test each user exists in GCP
	expectedUsers := []string{"test_user", "test_user_2"}
	for i, expectedName := range expectedUsers {
		userName := userNames[i]
		assert.Equal(t, expectedName, userName, "User name should match expected value")

		// Verify user exists in GCP
		user := gcp.GetCloudSQLUser(t, config.ProjectID, instanceName, userName)
		assert.NotNil(t, user, "User should exist in GCP")
		assert.Equal(t, expectedName, user.Name, "User name should match expected value")
	}
}

func TestCloudSQLBackup(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/database/cloudsql",
		Vars: map[string]interface{}{
			"project_id":            config.ProjectID,
			"region":                config.Region,
			"name":                  testhelpers.GetTestResourceName("test-sql", config.RandomID),
			"database_version":      "POSTGRES_14",
			"tier":                  "db-f1-micro",
			"disk_size":             10,
			"disk_type":             "PD_SSD",
			"backup_enabled":        true,
			"backup_start_time":     "03:00",
			"backup_retention_days": 7,
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test Cloud SQL instance creation
	instanceName := terraform.Output(t, terraformOptions, "instance_name")
	assert.NotEmpty(t, instanceName, "Instance name should not be empty")

	// Test backup configuration
	backupEnabled := terraform.Output(t, terraformOptions, "backup_enabled")
	assert.Equal(t, "true", backupEnabled, "Backup should be enabled")

	// Test backup start time
	backupStartTime := terraform.Output(t, terraformOptions, "backup_start_time")
	assert.Equal(t, "03:00", backupStartTime, "Backup start time should match expected value")

	// Test backup retention days
	backupRetentionDays := terraform.Output(t, terraformOptions, "backup_retention_days")
	assert.Equal(t, "7", backupRetentionDays, "Backup retention days should match expected value")
}

func TestCloudSQLEncryption(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/database/cloudsql",
		Vars: map[string]interface{}{
			"project_id":          config.ProjectID,
			"region":              config.Region,
			"name":                testhelpers.GetTestResourceName("test-sql", config.RandomID),
			"database_version":    "POSTGRES_14",
			"tier":                "db-f1-micro",
			"disk_size":           10,
			"disk_type":           "PD_SSD",
			"encryption_key_name": "projects/" + config.ProjectID + "/locations/" + config.Region + "/keyRings/test-keyring/cryptoKeys/test-key",
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test Cloud SQL instance creation
	instanceName := terraform.Output(t, terraformOptions, "instance_name")
	assert.NotEmpty(t, instanceName, "Instance name should not be empty")

	// Test encryption configuration
	encryptionKeyName := terraform.Output(t, terraformOptions, "encryption_key_name")
	assert.NotEmpty(t, encryptionKeyName, "Encryption key name should not be empty")
	assert.Contains(t, encryptionKeyName, "test-key", "Encryption key name should contain test key")
}

func TestCloudSQLModuleValidation(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Test module structure validation
	modulePath := "../../../infrastructure/modules/database/cloudsql"
	requiredFiles := []string{"main.tf", "variables.tf", "outputs.tf"}
	testhelpers.ValidateModuleStructure(t, modulePath, requiredFiles)

	// Test Terraform format validation
	testhelpers.ValidateTerraformFormat(t, modulePath)

	// Test Terraform validate
	testhelpers.ValidateTerraformValidate(t, modulePath)
}

func TestCloudSQLModuleTimeout(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Set a longer timeout for database tests
	config.Timeout = 10 * time.Minute

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/database/cloudsql",
		Vars: map[string]interface{}{
			"project_id":       config.ProjectID,
			"region":           config.Region,
			"name":             testhelpers.GetTestResourceName("test-sql", config.RandomID),
			"database_version": "POSTGRES_14",
			"tier":             "db-f1-micro",
			"disk_size":        10,
			"disk_type":        "PD_SSD",
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
