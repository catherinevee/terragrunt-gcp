package compute

import (
	"testing"
	"time"

	"../../testhelpers"
	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestComputeInstance(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/compute/instances",
		Vars: map[string]interface{}{
			"project_id":   config.ProjectID,
			"region":       config.Region,
			"zone":         config.Zone,
			"name":         testhelpers.GetTestResourceName("test-instance", config.RandomID),
			"machine_type": "e2-micro",
			"image":        "ubuntu-os-cloud/ubuntu-2004-lts",
			"disk_size":    20,
			"disk_type":    "pd-standard",
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test compute instance creation
	instanceName := terraform.Output(t, terraformOptions, "instance_name")
	assert.NotEmpty(t, instanceName, "Instance name should not be empty")
	assert.Contains(t, instanceName, "test-instance-", "Instance name should contain test prefix")

	// Test compute instance exists in GCP
	instance := gcp.GetComputeInstance(t, config.ProjectID, config.Zone, instanceName)
	assert.NotNil(t, instance, "Compute instance should exist in GCP")
	assert.Equal(t, "test-instance-"+config.RandomID, instance.Name, "Instance name should match expected value")
	assert.Equal(t, "e2-micro", instance.MachineType, "Machine type should match expected value")
}

func TestComputeInstanceWithTags(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/compute/instances",
		Vars: map[string]interface{}{
			"project_id":   config.ProjectID,
			"region":       config.Region,
			"zone":         config.Zone,
			"name":         testhelpers.GetTestResourceName("test-instance", config.RandomID),
			"machine_type": "e2-micro",
			"image":        "ubuntu-os-cloud/ubuntu-2004-lts",
			"disk_size":    20,
			"disk_type":    "pd-standard",
			"tags":         []string{"test", "unit-test", "compute"},
			"labels": map[string]string{
				"environment": "test",
				"team":        "platform",
				"project":     "terraform-gcp",
			},
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test compute instance creation
	instanceName := terraform.Output(t, terraformOptions, "instance_name")
	assert.NotEmpty(t, instanceName, "Instance name should not be empty")

	// Test compute instance exists in GCP
	instance := gcp.GetComputeInstance(t, config.ProjectID, config.Zone, instanceName)
	assert.NotNil(t, instance, "Compute instance should exist in GCP")

	// Test tags
	tags := terraform.OutputList(t, terraformOptions, "tags")
	assert.Len(t, tags, 3, "Should have 3 tags")
	assert.Contains(t, tags, "test", "Should contain test tag")
	assert.Contains(t, tags, "unit-test", "Should contain unit-test tag")
	assert.Contains(t, tags, "compute", "Should contain compute tag")

	// Test labels
	labels := terraform.OutputMap(t, terraformOptions, "labels")
	assert.Len(t, labels, 3, "Should have 3 labels")
	assert.Equal(t, "test", labels["environment"], "Environment label should match")
	assert.Equal(t, "platform", labels["team"], "Team label should match")
	assert.Equal(t, "terraform-gcp", labels["project"], "Project label should match")
}

func TestComputeInstanceWithNetwork(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/compute/instances",
		Vars: map[string]interface{}{
			"project_id":   config.ProjectID,
			"region":       config.Region,
			"zone":         config.Zone,
			"name":         testhelpers.GetTestResourceName("test-instance", config.RandomID),
			"machine_type": "e2-micro",
			"image":        "ubuntu-os-cloud/ubuntu-2004-lts",
			"disk_size":    20,
			"disk_type":    "pd-standard",
			"network":      "default",
			"subnetwork":   "default",
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test compute instance creation
	instanceName := terraform.Output(t, terraformOptions, "instance_name")
	assert.NotEmpty(t, instanceName, "Instance name should not be empty")

	// Test compute instance exists in GCP
	instance := gcp.GetComputeInstance(t, config.ProjectID, config.Zone, instanceName)
	assert.NotNil(t, instance, "Compute instance should exist in GCP")

	// Test network configuration
	network := terraform.Output(t, terraformOptions, "network")
	assert.NotEmpty(t, network, "Network should not be empty")

	// Test subnetwork configuration
	subnetwork := terraform.Output(t, terraformOptions, "subnetwork")
	assert.NotEmpty(t, subnetwork, "Subnetwork should not be empty")
}

func TestComputeInstanceWithServiceAccount(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/compute/instances",
		Vars: map[string]interface{}{
			"project_id":            config.ProjectID,
			"region":                config.Region,
			"zone":                  config.Zone,
			"name":                  testhelpers.GetTestResourceName("test-instance", config.RandomID),
			"machine_type":          "e2-micro",
			"image":                 "ubuntu-os-cloud/ubuntu-2004-lts",
			"disk_size":             20,
			"disk_type":             "pd-standard",
			"service_account_email": "test-sa@" + config.ProjectID + ".iam.gserviceaccount.com",
			"service_account_scopes": []string{
				"https://www.googleapis.com/auth/cloud-platform",
				"https://www.googleapis.com/auth/compute",
			},
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test compute instance creation
	instanceName := terraform.Output(t, terraformOptions, "instance_name")
	assert.NotEmpty(t, instanceName, "Instance name should not be empty")

	// Test compute instance exists in GCP
	instance := gcp.GetComputeInstance(t, config.ProjectID, config.Zone, instanceName)
	assert.NotNil(t, instance, "Compute instance should exist in GCP")

	// Test service account configuration
	serviceAccountEmail := terraform.Output(t, terraformOptions, "service_account_email")
	assert.NotEmpty(t, serviceAccountEmail, "Service account email should not be empty")
	assert.Equal(t, "test-sa@"+config.ProjectID+".iam.gserviceaccount.com", serviceAccountEmail, "Service account email should match expected value")

	// Test service account scopes
	serviceAccountScopes := terraform.OutputList(t, terraformOptions, "service_account_scopes")
	assert.Len(t, serviceAccountScopes, 2, "Should have 2 service account scopes")
	assert.Contains(t, serviceAccountScopes, "https://www.googleapis.com/auth/cloud-platform", "Should contain cloud platform scope")
	assert.Contains(t, serviceAccountScopes, "https://www.googleapis.com/auth/compute", "Should contain compute scope")
}

func TestComputeInstanceWithStartupScript(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	startupScript := `#!/bin/bash
echo "Starting test instance"
apt-get update
apt-get install -y nginx
systemctl start nginx
systemctl enable nginx
echo "Test instance ready" > /var/www/html/index.html
`

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/compute/instances",
		Vars: map[string]interface{}{
			"project_id":     config.ProjectID,
			"region":         config.Region,
			"zone":           config.Zone,
			"name":           testhelpers.GetTestResourceName("test-instance", config.RandomID),
			"machine_type":   "e2-micro",
			"image":          "ubuntu-os-cloud/ubuntu-2004-lts",
			"disk_size":      20,
			"disk_type":      "pd-standard",
			"startup_script": startupScript,
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test compute instance creation
	instanceName := terraform.Output(t, terraformOptions, "instance_name")
	assert.NotEmpty(t, instanceName, "Instance name should not be empty")

	// Test compute instance exists in GCP
	instance := gcp.GetComputeInstance(t, config.ProjectID, config.Zone, instanceName)
	assert.NotNil(t, instance, "Compute instance should exist in GCP")

	// Test startup script configuration
	startupScriptOutput := terraform.Output(t, terraformOptions, "startup_script")
	assert.NotEmpty(t, startupScriptOutput, "Startup script should not be empty")
	assert.Contains(t, startupScriptOutput, "Starting test instance", "Startup script should contain expected content")
}

func TestComputeInstanceModuleValidation(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Test module structure validation
	modulePath := "../../../infrastructure/modules/compute/instances"
	requiredFiles := []string{"main.tf", "variables.tf", "outputs.tf"}
	testhelpers.ValidateModuleStructure(t, modulePath, requiredFiles)

	// Test Terraform format validation
	testhelpers.ValidateTerraformFormat(t, modulePath)

	// Test Terraform validate
	testhelpers.ValidateTerraformValidate(t, modulePath)
}

func TestComputeInstanceModuleTimeout(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Set a shorter timeout for this test
	config.Timeout = 5 * time.Minute

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/compute/instances",
		Vars: map[string]interface{}{
			"project_id":   config.ProjectID,
			"region":       config.Region,
			"zone":         config.Zone,
			"name":         testhelpers.GetTestResourceName("test-instance", config.RandomID),
			"machine_type": "e2-micro",
			"image":        "ubuntu-os-cloud/ubuntu-2004-lts",
			"disk_size":    20,
			"disk_type":    "pd-standard",
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
