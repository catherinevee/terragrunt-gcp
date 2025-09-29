package security

import (
	"testing"
	"time"

	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestIAMServiceAccount(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/security/iam",
		Vars: map[string]interface{}{
			"project_id":   config.ProjectID,
			"name":         testhelpers.GetTestResourceName("test-sa", config.RandomID),
			"display_name": "Test Service Account",
			"description":  "Test service account for unit testing",
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test service account creation
	saEmail := terraform.Output(t, terraformOptions, "service_account_email")
	assert.NotEmpty(t, saEmail, "Service account email should not be empty")
	assert.Contains(t, saEmail, "test-sa-", "Service account email should contain test prefix")

	// Test service account exists in GCP
	sa := gcp.GetServiceAccount(t, config.ProjectID, saEmail)
	assert.NotNil(t, sa, "Service account should exist in GCP")
	assert.Equal(t, "test-sa-"+config.RandomID, sa.DisplayName, "Service account display name should match expected value")
	assert.Equal(t, "Test service account for unit testing", sa.Description, "Service account description should match expected value")
}

func TestIAMCustomRole(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/security/iam",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"role_id":     "test_custom_role_" + config.RandomID,
			"title":       "Test Custom Role",
			"description": "Test custom role for unit testing",
			"permissions": []string{
				"compute.instances.create",
				"compute.instances.delete",
				"compute.instances.get",
				"compute.instances.list",
			},
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test custom role creation
	roleName := terraform.Output(t, terraformOptions, "role_name")
	assert.NotEmpty(t, roleName, "Role name should not be empty")
	assert.Contains(t, roleName, "test_custom_role_", "Role name should contain test prefix")

	// Test custom role exists in GCP
	role := gcp.GetProjectIAMCustomRole(t, config.ProjectID, "test_custom_role_"+config.RandomID)
	assert.NotNil(t, role, "Custom role should exist in GCP")
	assert.Equal(t, "Test Custom Role", role.Title, "Role title should match expected value")
	assert.Equal(t, "Test custom role for unit testing", role.Description, "Role description should match expected value")

	// Test role permissions
	expectedPermissions := []string{
		"compute.instances.create",
		"compute.instances.delete",
		"compute.instances.get",
		"compute.instances.list",
	}
	for _, permission := range expectedPermissions {
		assert.Contains(t, role.IncludedPermissions, permission, "Role should include permission: %s", permission)
	}
}

func TestIAMWorkloadIdentity(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/security/iam",
		Vars: map[string]interface{}{
			"project_id":                    config.ProjectID,
			"workload_identity_pool_id":     "test-pool-" + config.RandomID,
			"workload_identity_provider_id": "test-provider-" + config.RandomID,
			"display_name":                  "Test Workload Identity Pool",
			"description":                   "Test workload identity pool for unit testing",
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test workload identity pool creation
	poolName := terraform.Output(t, terraformOptions, "workload_identity_pool_name")
	assert.NotEmpty(t, poolName, "Workload identity pool name should not be empty")
	assert.Contains(t, poolName, "test-pool-", "Pool name should contain test prefix")

	// Test workload identity provider creation
	providerName := terraform.Output(t, terraformOptions, "workload_identity_provider_name")
	assert.NotEmpty(t, providerName, "Workload identity provider name should not be empty")
	assert.Contains(t, providerName, "test-provider-", "Provider name should contain test prefix")
}

func TestIAMBindings(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/security/iam",
		Vars: map[string]interface{}{
			"project_id":            config.ProjectID,
			"service_account_email": "test-sa@" + config.ProjectID + ".iam.gserviceaccount.com",
			"iam_bindings": []map[string]interface{}{
				{
					"role": "roles/storage.objectViewer",
					"members": []string{
						"serviceAccount:test-sa@" + config.ProjectID + ".iam.gserviceaccount.com",
					},
				},
				{
					"role": "roles/compute.instanceAdmin",
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

	// Test IAM bindings creation
	bindingCount := terraform.Output(t, terraformOptions, "binding_count")
	assert.NotEmpty(t, bindingCount, "Binding count should not be empty")
	assert.Equal(t, "2", bindingCount, "Should have 2 IAM bindings")

	// Test IAM bindings exist in GCP
	policy := gcp.GetProjectIAMPolicy(t, config.ProjectID)
	assert.NotNil(t, policy, "IAM policy should exist in GCP")

	// Verify specific bindings exist
	saEmail := "test-sa@" + config.ProjectID + ".iam.gserviceaccount.com"

	// Check storage object viewer role
	storageBinding := gcp.GetIAMPolicyBinding(t, policy, "roles/storage.objectViewer")
	assert.NotNil(t, storageBinding, "Storage object viewer binding should exist")
	assert.Contains(t, storageBinding.Members, "serviceAccount:"+saEmail, "Service account should have storage object viewer role")

	// Check compute instance admin role
	computeBinding := gcp.GetIAMPolicyBinding(t, policy, "roles/compute.instanceAdmin")
	assert.NotNil(t, computeBinding, "Compute instance admin binding should exist")
	assert.Contains(t, computeBinding.Members, "serviceAccount:"+saEmail, "Service account should have compute instance admin role")
}

func TestIAMModuleValidation(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Test module structure validation
	modulePath := "../../../infrastructure/modules/security/iam"
	requiredFiles := []string{"main.tf", "variables.tf", "outputs.tf"}
	testhelpers.ValidateModuleStructure(t, modulePath, requiredFiles)

	// Test Terraform format validation
	testhelpers.ValidateTerraformFormat(t, modulePath)

	// Test Terraform validate
	testhelpers.ValidateTerraformValidate(t, modulePath)
}

func TestIAMModuleTimeout(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Set a shorter timeout for this test
	config.Timeout = 5 * time.Minute

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/security/iam",
		Vars: map[string]interface{}{
			"project_id":   config.ProjectID,
			"name":         testhelpers.GetTestResourceName("test-sa", config.RandomID),
			"display_name": "Test Service Account",
			"description":  "Test service account for unit testing",
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
