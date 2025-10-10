package cicd

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/your-org/terragrunt-gcp/tests/internal/testhelpers"
)

func TestCloudBuildTriggerBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	triggerName := testhelpers.GetTestResourceName("build-trigger", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/ci-cd/cloud-build",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"name":          triggerName,
			"description":   "Test build trigger",
			"trigger_type":  "github",
			"repo_owner":    "test-owner",
			"repo_name":     "test-repo",
			"branch_regex":  "^main$",
			"filename":      "cloudbuild.yaml",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	triggerID := terraform.Output(t, terraformOptions, "trigger_id")
	assert.NotEmpty(t, triggerID)

	triggerNameOutput := terraform.Output(t, terraformOptions, "trigger_name")
	assert.Contains(t, triggerNameOutput, triggerName)
}

func TestCloudBuildTriggerWithInlineBuildConfig(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	triggerName := testhelpers.GetTestResourceName("build-inline", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/ci-cd/cloud-build",
		Vars: map[string]interface{}{
			"project_id":   config.ProjectID,
			"name":         triggerName,
			"description":  "Test build trigger with inline config",
			"trigger_type": "github",
			"repo_owner":   "test-owner",
			"repo_name":    "test-repo",
			"branch_regex": "^main$",
			"build_config": map[string]interface{}{
				"steps": []map[string]interface{}{
					{
						"name": "gcr.io/cloud-builders/docker",
						"args": []string{"build", "-t", "gcr.io/$PROJECT_ID/app:$SHORT_SHA", "."},
					},
					{
						"name": "gcr.io/cloud-builders/docker",
						"args": []string{"push", "gcr.io/$PROJECT_ID/app:$SHORT_SHA"},
					},
				},
				"images": []string{"gcr.io/$PROJECT_ID/app:$SHORT_SHA"},
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	triggerID := terraform.Output(t, terraformOptions, "trigger_id")
	assert.NotEmpty(t, triggerID)

	buildSteps := terraform.Output(t, terraformOptions, "build_steps_count")
	assert.Equal(t, "2", buildSteps)
}

func TestCloudBuildTriggerWithSubstitutions(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	triggerName := testhelpers.GetTestResourceName("build-subs", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/ci-cd/cloud-build",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"name":          triggerName,
			"description":   "Test build trigger with substitutions",
			"trigger_type":  "github",
			"repo_owner":    "test-owner",
			"repo_name":     "test-repo",
			"branch_regex":  "^main$",
			"filename":      "cloudbuild.yaml",
			"substitutions": map[string]string{
				"_ENVIRONMENT":    "production",
				"_REGION":         config.Region,
				"_DEPLOY_TIMEOUT": "600s",
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	triggerID := terraform.Output(t, terraformOptions, "trigger_id")
	assert.NotEmpty(t, triggerID)

	substitutions := terraform.OutputMap(t, terraformOptions, "substitutions")
	assert.Equal(t, "production", substitutions["_ENVIRONMENT"])
	assert.Equal(t, config.Region, substitutions["_REGION"])
	assert.Equal(t, "600s", substitutions["_DEPLOY_TIMEOUT"])
}

func TestCloudBuildTriggerWithServiceAccount(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	triggerName := testhelpers.GetTestResourceName("build-sa", config.RandomID)
	saName := testhelpers.GetTestResourceName("cloudbuild-sa", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/ci-cd/cloud-build",
		Vars: map[string]interface{}{
			"project_id":         config.ProjectID,
			"name":               triggerName,
			"description":        "Test build trigger with service account",
			"trigger_type":       "github",
			"repo_owner":         "test-owner",
			"repo_name":          "test-repo",
			"branch_regex":       "^main$",
			"filename":           "cloudbuild.yaml",
			"service_account":    fmt.Sprintf("%s@%s.iam.gserviceaccount.com", saName, config.ProjectID),
			"logs_bucket":        fmt.Sprintf("gs://%s-logs", triggerName),
			"timeout":            "1800s",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	triggerID := terraform.Output(t, terraformOptions, "trigger_id")
	assert.NotEmpty(t, triggerID)

	serviceAccount := terraform.Output(t, terraformOptions, "service_account")
	assert.Contains(t, serviceAccount, saName)

	timeout := terraform.Output(t, terraformOptions, "timeout")
	assert.Equal(t, "1800s", timeout)
}
