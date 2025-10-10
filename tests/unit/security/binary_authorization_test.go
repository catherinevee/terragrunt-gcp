package security

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/your-org/terragrunt-gcp/tests/internal/testhelpers"
)

func TestBinaryAuthorizationPolicyBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	policyName := testhelpers.GetTestResourceName("binauthz-basic", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/security/binary-authorization",
		Vars: map[string]interface{}{
			"project_id":               config.ProjectID,
			"name":                     policyName,
			"admission_whitelist_patterns": []string{
				"gcr.io/google-containers/*",
			},
			"default_admission_rule": map[string]interface{}{
				"evaluation_mode":  "ALWAYS_ALLOW",
				"enforcement_mode": "ENFORCED_BLOCK_AND_AUDIT_LOG",
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	policyID := terraform.Output(t, terraformOptions, "policy_id")
	assert.NotEmpty(t, policyID)

	evaluationMode := terraform.Output(t, terraformOptions, "evaluation_mode")
	assert.Equal(t, "ALWAYS_ALLOW", evaluationMode)
}

func TestBinaryAuthorizationPolicyWithAttestors(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	policyName := testhelpers.GetTestResourceName("binauthz-attestor", config.RandomID)
	attestorName := testhelpers.GetTestResourceName("attestor", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/security/binary-authorization",
		Vars: map[string]interface{}{
			"project_id": config.ProjectID,
			"name":       policyName,
			"default_admission_rule": map[string]interface{}{
				"evaluation_mode":         "REQUIRE_ATTESTATION",
				"enforcement_mode":        "ENFORCED_BLOCK_AND_AUDIT_LOG",
				"require_attestations_by": []string{attestorName},
			},
			"create_attestor":      true,
			"attestor_name":        attestorName,
			"attestor_description": "Test attestor for container image verification",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	policyID := terraform.Output(t, terraformOptions, "policy_id")
	assert.NotEmpty(t, policyID)

	attestorID := terraform.Output(t, terraformOptions, "attestor_id")
	assert.NotEmpty(t, attestorID)

	evaluationMode := terraform.Output(t, terraformOptions, "evaluation_mode")
	assert.Equal(t, "REQUIRE_ATTESTATION", evaluationMode)

	attestorNameOutput := terraform.Output(t, terraformOptions, "attestor_name")
	assert.Contains(t, attestorNameOutput, attestorName)
}

func TestBinaryAuthorizationPolicyWithClusterSpecificRules(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	policyName := testhelpers.GetTestResourceName("binauthz-cluster", config.RandomID)
	clusterName := testhelpers.GetTestResourceName("gke-cluster", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/security/binary-authorization",
		Vars: map[string]interface{}{
			"project_id": config.ProjectID,
			"name":       policyName,
			"default_admission_rule": map[string]interface{}{
				"evaluation_mode":  "ALWAYS_DENY",
				"enforcement_mode": "ENFORCED_BLOCK_AND_AUDIT_LOG",
			},
			"cluster_admission_rules": map[string]interface{}{
				clusterName: map[string]interface{}{
					"evaluation_mode":  "ALWAYS_ALLOW",
					"enforcement_mode": "ENFORCED_BLOCK_AND_AUDIT_LOG",
				},
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	policyID := terraform.Output(t, terraformOptions, "policy_id")
	assert.NotEmpty(t, policyID)

	defaultEvaluationMode := terraform.Output(t, terraformOptions, "default_evaluation_mode")
	assert.Equal(t, "ALWAYS_DENY", defaultEvaluationMode)

	clusterSpecificRules := terraform.OutputMap(t, terraformOptions, "cluster_admission_rules")
	assert.NotEmpty(t, clusterSpecificRules)
}

func TestBinaryAuthorizationPolicyWithDryRun(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	policyName := testhelpers.GetTestResourceName("binauthz-dryrun", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/security/binary-authorization",
		Vars: map[string]interface{}{
			"project_id": config.ProjectID,
			"name":       policyName,
			"default_admission_rule": map[string]interface{}{
				"evaluation_mode":  "REQUIRE_ATTESTATION",
				"enforcement_mode": "DRYRUN_AUDIT_LOG_ONLY",
			},
			"global_policy_evaluation_mode": "ENABLE",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	policyID := terraform.Output(t, terraformOptions, "policy_id")
	assert.NotEmpty(t, policyID)

	enforcementMode := terraform.Output(t, terraformOptions, "enforcement_mode")
	assert.Equal(t, "DRYRUN_AUDIT_LOG_ONLY", enforcementMode)

	globalPolicyEvalMode := terraform.Output(t, terraformOptions, "global_policy_evaluation_mode")
	assert.Equal(t, "ENABLE", globalPolicyEvalMode)
}
