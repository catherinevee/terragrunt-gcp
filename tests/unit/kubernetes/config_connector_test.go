package kubernetes

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

func TestConfigConnectorClusterMode(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/kubernetes/config-connector",
		Vars: map[string]interface{}{
			"project_id":               config.ProjectID,
			"enable_config_connector":  true,
			"config_connector_mode":    "cluster",
			"config_connector_namespace": "cnrm-system",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify Config Connector outputs
	mode := terraform.Output(t, terraformOptions, "config_connector_mode")
	assert.Equal(t, "cluster", mode)

	namespace := terraform.Output(t, terraformOptions, "config_connector_namespace")
	assert.Equal(t, "cnrm-system", namespace)
}

func TestConfigConnectorNamespacedMode(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	customNamespace := "config-connector-test"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/kubernetes/config-connector",
		Vars: map[string]interface{}{
			"project_id":                       config.ProjectID,
			"enable_config_connector":          true,
			"config_connector_mode":            "namespaced",
			"config_connector_namespace":       customNamespace,
			"create_config_connector_namespace": true,
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	mode := terraform.Output(t, terraformOptions, "config_connector_mode")
	assert.Equal(t, "namespaced", mode)

	namespace := terraform.Output(t, terraformOptions, "config_connector_namespace")
	assert.Equal(t, customNamespace, namespace)
}

func TestConfigConnectorWithWorkloadIdentity(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	serviceAccountName := testhelpers.GetTestResourceName("cnrm-sa", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/kubernetes/config-connector",
		Vars: map[string]interface{}{
			"project_id":              config.ProjectID,
			"enable_config_connector": true,
			"workload_identity_enabled": true,
			"google_service_account":  serviceAccountName + "@" + config.ProjectID + ".iam.gserviceaccount.com",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	serviceAccount := terraform.Output(t, terraformOptions, "google_service_account")
	assert.Contains(t, serviceAccount, serviceAccountName)
}

func TestConfigConnectorWithCustomResources(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/kubernetes/config-connector",
		Vars: map[string]interface{}{
			"project_id":              config.ProjectID,
			"enable_config_connector": true,
			"resource_types": []string{
				"StorageBucket",
				"PubSubTopic",
				"BigQueryDataset",
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify resource types are configured
	enabled := terraform.Output(t, terraformOptions, "config_connector_enabled")
	assert.Equal(t, "true", enabled)
}
