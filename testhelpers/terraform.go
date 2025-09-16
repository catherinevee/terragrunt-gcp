package testhelpers

import (
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// DeployModule deploys a Terraform module for testing
func DeployModule(t *testing.T, modulePath string, vars map[string]interface{}) *terraform.Options {
	terraformOptions := &terraform.Options{
		TerraformDir: modulePath,
		Vars:         vars,
		NoColor:      true,
		Logger:       terraform.DefaultLogger(t),
	}

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)
	return terraformOptions
}

// ValidateOutputs validates that Terraform outputs match expected values
func ValidateOutputs(t *testing.T, options *terraform.Options, expected map[string]string) {
	for key, expectedValue := range expected {
		actualValue := terraform.Output(t, options, key)
		assert.Equal(t, expectedValue, actualValue, "Output %s should match expected value", key)
	}
}

// DestroyModule destroys a Terraform module
func DestroyModule(t *testing.T, options *terraform.Options) {
	terraform.Destroy(t, options)
}

// GetOutputValue retrieves a Terraform output value
func GetOutputValue(t *testing.T, options *terraform.Options, outputName string) string {
	return terraform.Output(t, options, outputName)
}

// ValidateModuleStructure validates that a module has the required structure
func ValidateModuleStructure(t *testing.T, modulePath string, requiredFiles []string) {
	for _, file := range requiredFiles {
		fullPath := modulePath + "/" + file
		if !terraform.FileExists(t, fullPath) {
			t.Errorf("Required file %s not found in module %s", file, modulePath)
		}
	}
}

// WaitForTerraformApply waits for Terraform apply to complete
func WaitForTerraformApply(t *testing.T, options *terraform.Options, timeout time.Duration) {
	deadline := time.Now().Add(timeout)
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			// Check if Terraform state exists and is valid
			if terraform.IsTerraformDir(t, options.TerraformDir) {
				return
			}
		case <-time.After(time.Until(deadline)):
			t.Fatal("Terraform apply did not complete within timeout")
		}
	}
}

// ValidateTerraformFormat validates that Terraform files are properly formatted
func ValidateTerraformFormat(t *testing.T, terraformDir string) {
	// Run terraform fmt -check
	terraform.RunTerraformCommand(t, &terraform.Options{
		TerraformDir: terraformDir,
	}, "fmt", "-check")
}

// ValidateTerraformValidate validates that Terraform configuration is valid
func ValidateTerraformValidate(t *testing.T, terraformDir string) {
	// Run terraform validate
	terraform.RunTerraformCommand(t, &terraform.Options{
		TerraformDir: terraformDir,
	}, "validate")
}

// GetTerraformPlan retrieves a Terraform plan
func GetTerraformPlan(t *testing.T, options *terraform.Options) string {
	plan := terraform.Plan(t, options)
	return plan
}

// ValidateTerraformPlan validates that a Terraform plan contains expected resources
func ValidateTerraformPlan(t *testing.T, plan string, expectedResources []string) {
	for _, resource := range expectedResources {
		assert.Contains(t, plan, resource, "Plan should contain resource: %s", resource)
	}
}
