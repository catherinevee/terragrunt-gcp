package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestVPCModule(t *testing.T) {
	t.Parallel()

	// Define test cases for different configurations
	testCases := []struct {
		name        string
		vpcName     string
		region      string
		enableNAT   bool
		subnetsCount int
	}{
		{
			name:        "BasicVPC",
			vpcName:     fmt.Sprintf("test-vpc-%s", strings.ToLower(random.UniqueId())),
			region:      "us-central1",
			enableNAT:   false,
			subnetsCount: 1,
		},
		{
			name:        "VPCWithNAT",
			vpcName:     fmt.Sprintf("test-vpc-nat-%s", strings.ToLower(random.UniqueId())),
			region:      "us-central1",
			enableNAT:   true,
			subnetsCount: 2,
		},
	}

	for _, tc := range testCases {
		tc := tc // Capture range variable
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			// Get GCP project ID from environment
			projectID := gcp.GetGoogleProjectIDFromEnvVar(t)

			// Create test folder
			testFolder := test_structure.CopyTerraformFolderToTemp(t, "../", "infrastructure/modules/networking/vpc")
			
			// Define Terraform options
			terraformOptions := &terraform.Options{
				TerraformDir: testFolder,
				Vars: map[string]interface{}{
					"name":             tc.vpcName,
					"project_id":       projectID,
					"region":           tc.region,
					"enable_cloud_nat": tc.enableNAT,
					"subnets": generateTestSubnets(tc.subnetsCount, tc.region),
					"labels": map[string]string{
						"environment": "test",
						"test_id":     tc.name,
						"managed_by":  "terratest",
					},
				},
				NoColor: true,
			}

			// Clean up resources at the end
			defer terraform.Destroy(t, terraformOptions)

			// Deploy the VPC
			terraform.InitAndApply(t, terraformOptions)

			// Validate outputs
			validateVPCOutputs(t, terraformOptions, tc)

			// Validate the VPC exists in GCP
			validateVPCInGCP(t, projectID, tc.vpcName)
		})
	}
}

func generateTestSubnets(count int, region string) []map[string]interface{} {
	subnets := make([]map[string]interface{}, count)
	for i := 0; i < count; i++ {
		subnets[i] = map[string]interface{}{
			"subnet_name":           fmt.Sprintf("test-subnet-%d", i+1),
			"subnet_ip":            fmt.Sprintf("10.%d.0.0/24", i),
			"subnet_region":        region,
			"subnet_private_access": true,
			"subnet_flow_logs":     true,
			"description":          fmt.Sprintf("Test subnet %d", i+1),
		}
	}
	return subnets
}

func validateVPCOutputs(t *testing.T, terraformOptions *terraform.Options, tc struct {
	name        string
	vpcName     string
	region      string
	enableNAT   bool
	subnetsCount int
}) {
	// Validate VPC ID output
	vpcID := terraform.Output(t, terraformOptions, "network_id")
	require.NotEmpty(t, vpcID, "VPC ID should not be empty")

	// Validate VPC name output
	vpcName := terraform.Output(t, terraformOptions, "network_name")
	assert.Equal(t, tc.vpcName, vpcName, "VPC name should match input")

	// Validate VPC self link
	vpcSelfLink := terraform.Output(t, terraformOptions, "network_self_link")
	require.NotEmpty(t, vpcSelfLink, "VPC self link should not be empty")
	assert.Contains(t, vpcSelfLink, tc.vpcName, "VPC self link should contain VPC name")
}

func validateVPCInGCP(t *testing.T, projectID, vpcName string) {
	// Use GCP API to verify VPC exists
	vpc := gcp.GetVpc(t, projectID, vpcName)
	
	require.NotNil(t, vpc, "VPC should exist in GCP")
	assert.Equal(t, vpcName, vpc.Name, "VPC name should match")
	assert.False(t, vpc.AutoCreateSubnetworks, "Auto-create subnetworks should be disabled")
}

func TestVPCModuleWithInvalidInputs(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name        string
		vpcName     string
		projectID   string
		expectError bool
		errorMsg    string
	}{
		{
			name:        "InvalidVPCName",
			vpcName:     "INVALID-VPC-NAME", // Uppercase not allowed
			projectID:   "test-project",
			expectError: true,
			errorMsg:    "VPC name must start with a lowercase letter",
		},
		{
			name:        "InvalidProjectID",
			vpcName:     "valid-vpc-name",
			projectID:   "a", // Too short
			expectError: true,
			errorMsg:    "Project ID must be 6-30 characters",
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			testFolder := test_structure.CopyTerraformFolderToTemp(t, "../", "infrastructure/modules/networking/vpc")

			terraformOptions := &terraform.Options{
				TerraformDir: testFolder,
				Vars: map[string]interface{}{
					"name":       tc.vpcName,
					"project_id": tc.projectID,
					"region":     "us-central1",
				},
				NoColor: true,
			}

			// Clean up even if validation fails
			defer terraform.Destroy(t, terraformOptions)

			// Attempt to plan - should fail for invalid inputs
			_, err := terraform.InitAndPlanE(t, terraformOptions)

			if tc.expectError {
				require.Error(t, err, "Should return an error for invalid inputs")
				assert.Contains(t, err.Error(), tc.errorMsg, "Error message should contain expected text")
			} else {
				require.NoError(t, err, "Should not return an error for valid inputs")
			}
		})
	}
}

func TestVPCModuleIdempotency(t *testing.T) {
	t.Parallel()

	projectID := gcp.GetGoogleProjectIDFromEnvVar(t)
	vpcName := fmt.Sprintf("test-vpc-idempotent-%s", strings.ToLower(random.UniqueId()))

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "../", "infrastructure/modules/networking/vpc")

	terraformOptions := &terraform.Options{
		TerraformDir: testFolder,
		Vars: map[string]interface{}{
			"name":       vpcName,
			"project_id": projectID,
			"region":     "us-central1",
			"labels": map[string]string{
				"test": "idempotency",
			},
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)

	// First apply
	terraform.InitAndApply(t, terraformOptions)
	firstVPCID := terraform.Output(t, terraformOptions, "network_id")

	// Second apply - should not create any changes
	planOutput := terraform.Plan(t, terraformOptions)
	assert.Contains(t, planOutput, "No changes", "Second plan should show no changes (idempotent)")

	// Third apply - verify outputs remain the same
	terraform.Apply(t, terraformOptions)
	secondVPCID := terraform.Output(t, terraformOptions, "network_id")

	assert.Equal(t, firstVPCID, secondVPCID, "VPC ID should remain the same after multiple applies")
}