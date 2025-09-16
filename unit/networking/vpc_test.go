package networking

import (
	"testing"
	"time"

	"../../testhelpers"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestVPCModule(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/networking/vpc",
		Vars: map[string]interface{}{
			"project_id": config.ProjectID,
			"region":     config.Region,
			"name":       testhelpers.GetTestResourceName("test-vpc", config.RandomID),
			"cidr":       "10.0.0.0/16",
		},
		NoColor: true,
		Logger:  logger.Default,
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test VPC creation
	vpcName := terraform.Output(t, terraformOptions, "vpc_name")
	assert.NotEmpty(t, vpcName, "VPC name should not be empty")
	assert.Contains(t, vpcName, "test-vpc-", "VPC name should contain test prefix")

	// Test VPC properties from Terraform outputs
	vpcCidr := terraform.Output(t, terraformOptions, "vpc_cidr")
	assert.Equal(t, "10.0.0.0/16", vpcCidr, "VPC CIDR should match expected value")

	vpcRoutingMode := terraform.Output(t, terraformOptions, "vpc_routing_mode")
	assert.Equal(t, "GLOBAL", vpcRoutingMode, "VPC routing mode should be GLOBAL")
}

func TestVPCSubnets(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/networking/vpc",
		Vars: map[string]interface{}{
			"project_id": config.ProjectID,
			"region":     config.Region,
			"name":       testhelpers.GetTestResourceName("test-vpc", config.RandomID),
			"cidr":       "10.0.0.0/16",
			"subnets": []map[string]interface{}{
				{
					"name":        "web-subnet",
					"cidr":        "10.0.1.0/24",
					"region":      config.Region,
					"description": "Web tier subnet",
				},
				{
					"name":        "app-subnet",
					"cidr":        "10.0.2.0/24",
					"region":      config.Region,
					"description": "Application tier subnet",
				},
				{
					"name":        "db-subnet",
					"cidr":        "10.0.3.0/24",
					"region":      config.Region,
					"description": "Database tier subnet",
				},
			},
		},
		NoColor: true,
		Logger:  logger.Default,
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test VPC creation
	vpcName := terraform.Output(t, terraformOptions, "vpc_name")
	assert.NotEmpty(t, vpcName, "VPC name should not be empty")

	// Test subnet creation
	subnetNames := terraform.OutputList(t, terraformOptions, "subnet_names")
	assert.Len(t, subnetNames, 3, "Should have 3 subnets")

	// Test each subnet exists
	expectedSubnets := []string{"web-subnet", "app-subnet", "db-subnet"}
	for i, expectedName := range expectedSubnets {
		subnetName := subnetNames[i]
		assert.Contains(t, subnetName, expectedName, "Subnet name should contain expected prefix")

		// Verify subnet properties from Terraform outputs
		subnetCidr := terraform.Output(t, terraformOptions, "subnet_cidrs")
		assert.NotEmpty(t, subnetCidr, "Subnet CIDR should not be empty")
	}
}

func TestVPCFirewallRules(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/networking/vpc",
		Vars: map[string]interface{}{
			"project_id": config.ProjectID,
			"region":     config.Region,
			"name":       testhelpers.GetTestResourceName("test-vpc", config.RandomID),
			"cidr":       "10.0.0.0/16",
			"firewall_rules": []map[string]interface{}{
				{
					"name":          "allow-http",
					"description":   "Allow HTTP traffic",
					"direction":     "INGRESS",
					"priority":      1000,
					"source_ranges": []string{"0.0.0.0/0"},
					"allowed": []map[string]interface{}{
						{
							"protocol": "tcp",
							"ports":    []string{"80"},
						},
					},
				},
				{
					"name":          "allow-https",
					"description":   "Allow HTTPS traffic",
					"direction":     "INGRESS",
					"priority":      1000,
					"source_ranges": []string{"0.0.0.0/0"},
					"allowed": []map[string]interface{}{
						{
							"protocol": "tcp",
							"ports":    []string{"443"},
						},
					},
				},
			},
		},
		NoColor: true,
		Logger:  logger.Default,
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test VPC creation
	vpcName := terraform.Output(t, terraformOptions, "vpc_name")
	assert.NotEmpty(t, vpcName, "VPC name should not be empty")

	// Test firewall rules creation
	firewallRuleNames := terraform.OutputList(t, terraformOptions, "firewall_rule_names")
	assert.Len(t, firewallRuleNames, 2, "Should have 2 firewall rules")

	// Test each firewall rule
	expectedRules := []string{"allow-http", "allow-https"}
	for i, expectedName := range expectedRules {
		ruleName := firewallRuleNames[i]
		assert.Contains(t, ruleName, expectedName, "Firewall rule name should contain expected prefix")

		// Verify firewall rule properties from Terraform outputs
		firewallRules := terraform.Output(t, terraformOptions, "firewall_rules")
		assert.NotEmpty(t, firewallRules, "Firewall rules should not be empty")
	}
}

func TestVPCModuleValidation(t *testing.T) {
	// Test module structure validation
	modulePath := "../../../infrastructure/modules/networking/vpc"
	requiredFiles := []string{"main.tf", "variables.tf", "outputs.tf"}
	testhelpers.ValidateModuleStructure(t, modulePath, requiredFiles)

	// Test Terraform format validation
	testhelpers.ValidateTerraformFormat(t, modulePath)

	// Test Terraform validate
	testhelpers.ValidateTerraformValidate(t, modulePath)
}

func TestVPCModuleTimeout(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Set a shorter timeout for this test
	config.Timeout = 5 * time.Minute

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/networking/vpc",
		Vars: map[string]interface{}{
			"project_id": config.ProjectID,
			"region":     config.Region,
			"name":       testhelpers.GetTestResourceName("test-vpc", config.RandomID),
			"cidr":       "10.0.0.0/16",
		},
		NoColor: true,
		Logger:  logger.Default,
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Test that module deploys within timeout
	start := time.Now()
	terraform.InitAndApply(t, terraformOptions)
	duration := time.Since(start)

	assert.Less(t, duration, config.Timeout, "Module deployment should complete within timeout")
}
