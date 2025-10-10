package compute

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

func TestCloudRunServiceBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	serviceName := testhelpers.GetTestResourceName("cloud-run-svc", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/compute/cloud-run",
		Vars: map[string]interface{}{
			"project_id":   config.ProjectID,
			"name":         serviceName,
			"location":     config.Region,
			"image":        "gcr.io/cloudrun/hello",
			"environment":  "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify service outputs
	serviceNameOutput := terraform.Output(t, terraformOptions, "service_name")
	assert.Equal(t, serviceName, serviceNameOutput)

	serviceURL := terraform.Output(t, terraformOptions, "service_url")
	assert.NotEmpty(t, serviceURL)
	assert.Contains(t, serviceURL, "run.app")
}

func TestCloudRunServiceWithCustomResources(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	serviceName := testhelpers.GetTestResourceName("cloud-run-custom", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/compute/cloud-run",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"name":          serviceName,
			"location":      config.Region,
			"image":         "gcr.io/cloudrun/hello",
			"environment":   "test",
			"cpu":           "2",
			"memory":        "1Gi",
			"max_instances": 10,
			"min_instances": 1,
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify resource configuration
	serviceURL := terraform.Output(t, terraformOptions, "service_url")
	assert.NotEmpty(t, serviceURL)
}

func TestCloudRunServiceWithEnvironmentVariables(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	serviceName := testhelpers.GetTestResourceName("cloud-run-env", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/compute/cloud-run",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"name":        serviceName,
			"location":    config.Region,
			"image":       "gcr.io/cloudrun/hello",
			"environment": "test",
			"env_vars": map[string]string{
				"APP_ENV":     "test",
				"API_VERSION": "v1",
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	serviceNameOutput := terraform.Output(t, terraformOptions, "service_name")
	assert.Equal(t, serviceName, serviceNameOutput)
}

func TestCloudRunServiceWithVPCConnector(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	serviceName := testhelpers.GetTestResourceName("cloud-run-vpc", config.RandomID)
	vpcConnector := fmt.Sprintf("projects/%s/locations/%s/connectors/default", config.ProjectID, config.Region)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/compute/cloud-run",
		Vars: map[string]interface{}{
			"project_id":     config.ProjectID,
			"name":           serviceName,
			"location":       config.Region,
			"image":          "gcr.io/cloudrun/hello",
			"environment":    "test",
			"vpc_connector":  vpcConnector,
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	serviceURL := terraform.Output(t, terraformOptions, "service_url")
	assert.NotEmpty(t, serviceURL)
}
