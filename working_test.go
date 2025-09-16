package tests

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformModule(t *testing.T) {
	// Get project ID from environment
	projectID := os.Getenv("GCP_PROJECT_ID")
	if projectID == "" {
		projectID = "acme-ecommerce-platform-dev"
	}

	region := os.Getenv("GCP_REGION")
	if region == "" {
		region = "europe-west1"
	}

	terraformOptions := &terraform.Options{
		TerraformDir: "../infrastructure/modules/networking/vpc",
		Vars: map[string]interface{}{
			"project_id": projectID,
			"region":     region,
			"name":       "test-vpc-working",
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
	assert.Contains(t, vpcName, "test-vpc-working", "VPC name should contain test prefix")
}
