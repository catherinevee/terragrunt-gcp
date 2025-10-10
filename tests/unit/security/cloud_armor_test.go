package security

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

func TestCloudArmorPolicyBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	policyName := testhelpers.GetTestResourceName("armor-policy", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/security/cloud-armor",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"name":        policyName,
			"environment": "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify policy outputs
	policyNameOutput := terraform.Output(t, terraformOptions, "policy_name")
	assert.Equal(t, policyName, policyNameOutput)

	policyID := terraform.Output(t, terraformOptions, "policy_id")
	assert.NotEmpty(t, policyID)
}

func TestCloudArmorPolicyWithRules(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	policyName := testhelpers.GetTestResourceName("armor-rules", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/security/cloud-armor",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"name":        policyName,
			"environment": "test",
			"rules": []map[string]interface{}{
				{
					"action":      "deny(403)",
					"priority":    1000,
					"description": "Block specific IP",
					"match": map[string]interface{}{
						"src_ip_ranges": []string{"192.0.2.0/24"},
					},
				},
				{
					"action":      "allow",
					"priority":    2000,
					"description": "Allow all other traffic",
					"match": map[string]interface{}{
						"src_ip_ranges": []string{"*"},
					},
				},
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	policyNameOutput := terraform.Output(t, terraformOptions, "policy_name")
	assert.Equal(t, policyName, policyNameOutput)
}

func TestCloudArmorPolicyWithRateLimiting(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	policyName := testhelpers.GetTestResourceName("armor-ratelimit", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/security/cloud-armor",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"name":        policyName,
			"environment": "test",
			"rules": []map[string]interface{}{
				{
					"action":      "rate_based_ban",
					"priority":    1000,
					"description": "Rate limit rule",
					"match": map[string]interface{}{
						"src_ip_ranges": []string{"*"},
					},
					"rate_limit_options": map[string]interface{}{
						"conform_action":        "allow",
						"exceed_action":         "deny(429)",
						"enforce_on_key":        "IP",
						"rate_limit_threshold": map[string]interface{}{
							"count":        100,
							"interval_sec": 60,
						},
					},
				},
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	policyNameOutput := terraform.Output(t, terraformOptions, "policy_name")
	assert.Equal(t, policyName, policyNameOutput)
}
