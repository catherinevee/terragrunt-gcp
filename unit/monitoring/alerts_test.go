package monitoring

import (
	"testing"
	"time"

	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestMonitoringAlertPolicy(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/monitoring/alerts",
		Vars: map[string]interface{}{
			"project_id":   config.ProjectID,
			"name":         testhelpers.GetTestResourceName("test-alert", config.RandomID),
			"display_name": "Test Alert Policy",
			"description":  "Test alert policy for unit testing",
			"conditions": []map[string]interface{}{
				{
					"display_name": "CPU Usage Alert",
					"condition_threshold": map[string]interface{}{
						"filter":          "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\"",
						"comparison":      "COMPARISON_GT",
						"threshold_value": 0.8,
						"duration":        "300s",
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

	// Test alert policy creation
	alertPolicyName := terraform.Output(t, terraformOptions, "alert_policy_name")
	assert.NotEmpty(t, alertPolicyName, "Alert policy name should not be empty")
	assert.Contains(t, alertPolicyName, "test-alert-", "Alert policy name should contain test prefix")

	// Test alert policy exists in GCP
	alertPolicy := gcp.GetMonitoringAlertPolicy(t, config.ProjectID, alertPolicyName)
	assert.NotNil(t, alertPolicy, "Alert policy should exist in GCP")
	assert.Equal(t, "Test Alert Policy", alertPolicy.DisplayName, "Alert policy display name should match expected value")
	assert.Equal(t, "Test alert policy for unit testing", alertPolicy.Documentation, "Alert policy description should match expected value")
}

func TestMonitoringAlertPolicyWithNotificationChannels(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/monitoring/alerts",
		Vars: map[string]interface{}{
			"project_id":   config.ProjectID,
			"name":         testhelpers.GetTestResourceName("test-alert", config.RandomID),
			"display_name": "Test Alert Policy with Notifications",
			"description":  "Test alert policy with notification channels",
			"conditions": []map[string]interface{}{
				{
					"display_name": "Memory Usage Alert",
					"condition_threshold": map[string]interface{}{
						"filter":          "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/memory/utilization\"",
						"comparison":      "COMPARISON_GT",
						"threshold_value": 0.9,
						"duration":        "300s",
					},
				},
			},
			"notification_channels": []string{
				"projects/" + config.ProjectID + "/notificationChannels/test-channel-1",
				"projects/" + config.ProjectID + "/notificationChannels/test-channel-2",
			},
		},
		NoColor: true,
		Logger:  terraform.DefaultLogger(t),
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test alert policy creation
	alertPolicyName := terraform.Output(t, terraformOptions, "alert_policy_name")
	assert.NotEmpty(t, alertPolicyName, "Alert policy name should not be empty")

	// Test alert policy exists in GCP
	alertPolicy := gcp.GetMonitoringAlertPolicy(t, config.ProjectID, alertPolicyName)
	assert.NotNil(t, alertPolicy, "Alert policy should exist in GCP")

	// Test notification channels configuration
	notificationChannelCount := terraform.Output(t, terraformOptions, "notification_channel_count")
	assert.Equal(t, "2", notificationChannelCount, "Should have 2 notification channels")
}

func TestMonitoringAlertPolicyWithDocumentation(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	documentation := `# Test Alert Policy

This is a test alert policy for unit testing.

## Conditions
- CPU usage > 80%
- Memory usage > 90%

## Actions
- Send notification to team
- Create incident in ticketing system
`

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/monitoring/alerts",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"name":          testhelpers.GetTestResourceName("test-alert", config.RandomID),
			"display_name":  "Test Alert Policy with Documentation",
			"description":   "Test alert policy with detailed documentation",
			"documentation": documentation,
			"conditions": []map[string]interface{}{
				{
					"display_name": "CPU Usage Alert",
					"condition_threshold": map[string]interface{}{
						"filter":          "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\"",
						"comparison":      "COMPARISON_GT",
						"threshold_value": 0.8,
						"duration":        "300s",
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

	// Test alert policy creation
	alertPolicyName := terraform.Output(t, terraformOptions, "alert_policy_name")
	assert.NotEmpty(t, alertPolicyName, "Alert policy name should not be empty")

	// Test alert policy exists in GCP
	alertPolicy := gcp.GetMonitoringAlertPolicy(t, config.ProjectID, alertPolicyName)
	assert.NotNil(t, alertPolicy, "Alert policy should exist in GCP")

	// Test documentation configuration
	documentationOutput := terraform.Output(t, terraformOptions, "documentation")
	assert.NotEmpty(t, documentationOutput, "Documentation should not be empty")
	assert.Contains(t, documentationOutput, "Test Alert Policy", "Documentation should contain expected content")
}

func TestMonitoringAlertPolicyWithCombiner(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/monitoring/alerts",
		Vars: map[string]interface{}{
			"project_id":   config.ProjectID,
			"name":         testhelpers.GetTestResourceName("test-alert", config.RandomID),
			"display_name": "Test Alert Policy with Combiner",
			"description":  "Test alert policy with combiner logic",
			"combiner":     "OR",
			"conditions": []map[string]interface{}{
				{
					"display_name": "CPU Usage Alert",
					"condition_threshold": map[string]interface{}{
						"filter":          "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\"",
						"comparison":      "COMPARISON_GT",
						"threshold_value": 0.8,
						"duration":        "300s",
					},
				},
				{
					"display_name": "Memory Usage Alert",
					"condition_threshold": map[string]interface{}{
						"filter":          "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/memory/utilization\"",
						"comparison":      "COMPARISON_GT",
						"threshold_value": 0.9,
						"duration":        "300s",
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

	// Test alert policy creation
	alertPolicyName := terraform.Output(t, terraformOptions, "alert_policy_name")
	assert.NotEmpty(t, alertPolicyName, "Alert policy name should not be empty")

	// Test alert policy exists in GCP
	alertPolicy := gcp.GetMonitoringAlertPolicy(t, config.ProjectID, alertPolicyName)
	assert.NotNil(t, alertPolicy, "Alert policy should exist in GCP")

	// Test combiner configuration
	combiner := terraform.Output(t, terraformOptions, "combiner")
	assert.Equal(t, "OR", combiner, "Combiner should be OR")

	// Test conditions count
	conditionCount := terraform.Output(t, terraformOptions, "condition_count")
	assert.Equal(t, "2", conditionCount, "Should have 2 conditions")
}

func TestMonitoringAlertPolicyWithEnabled(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Validate GCP credentials
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/monitoring/alerts",
		Vars: map[string]interface{}{
			"project_id":   config.ProjectID,
			"name":         testhelpers.GetTestResourceName("test-alert", config.RandomID),
			"display_name": "Test Alert Policy (Disabled)",
			"description":  "Test alert policy that is disabled",
			"enabled":      false,
			"conditions": []map[string]interface{}{
				{
					"display_name": "CPU Usage Alert",
					"condition_threshold": map[string]interface{}{
						"filter":          "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\"",
						"comparison":      "COMPARISON_GT",
						"threshold_value": 0.8,
						"duration":        "300s",
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

	// Test alert policy creation
	alertPolicyName := terraform.Output(t, terraformOptions, "alert_policy_name")
	assert.NotEmpty(t, alertPolicyName, "Alert policy name should not be empty")

	// Test alert policy exists in GCP
	alertPolicy := gcp.GetMonitoringAlertPolicy(t, config.ProjectID, alertPolicyName)
	assert.NotNil(t, alertPolicy, "Alert policy should exist in GCP")

	// Test enabled configuration
	enabled := terraform.Output(t, terraformOptions, "enabled")
	assert.Equal(t, "false", enabled, "Alert policy should be disabled")
}

func TestMonitoringAlertPolicyModuleValidation(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Test module structure validation
	modulePath := "../../../infrastructure/modules/monitoring/alerts"
	requiredFiles := []string{"main.tf", "variables.tf", "outputs.tf"}
	testhelpers.ValidateModuleStructure(t, modulePath, requiredFiles)

	// Test Terraform format validation
	testhelpers.ValidateTerraformFormat(t, modulePath)

	// Test Terraform validate
	testhelpers.ValidateTerraformValidate(t, modulePath)
}

func TestMonitoringAlertPolicyModuleTimeout(t *testing.T) {
	config := testhelpers.GetTestConfig(t)

	// Set a shorter timeout for this test
	config.Timeout = 5 * time.Minute

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infrastructure/modules/monitoring/alerts",
		Vars: map[string]interface{}{
			"project_id":   config.ProjectID,
			"name":         testhelpers.GetTestResourceName("test-alert", config.RandomID),
			"display_name": "Test Alert Policy",
			"description":  "Test alert policy for unit testing",
			"conditions": []map[string]interface{}{
				{
					"display_name": "CPU Usage Alert",
					"condition_threshold": map[string]interface{}{
						"filter":          "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\"",
						"comparison":      "COMPARISON_GT",
						"threshold_value": 0.8,
						"duration":        "300s",
					},
				},
			},
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
