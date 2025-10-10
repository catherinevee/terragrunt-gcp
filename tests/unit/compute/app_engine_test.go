package compute

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

func TestAppEngineApplicationBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/compute/app-engine",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"location_id":   config.Region,
			"environment":   "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify App Engine application outputs
	appID := terraform.Output(t, terraformOptions, "app_id")
	assert.NotEmpty(t, appID)

	defaultHostname := terraform.Output(t, terraformOptions, "default_hostname")
	assert.NotEmpty(t, defaultHostname)
	assert.Contains(t, defaultHostname, "appspot.com")
}

func TestAppEngineServiceBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	serviceName := testhelpers.GetTestResourceName("app-service", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/compute/app-engine",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"location_id": config.Region,
			"environment": "test",
			"services": []map[string]interface{}{
				{
					"service":  serviceName,
					"runtime":  "python39",
					"instance_class": "F1",
				},
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	serviceID := terraform.Output(t, terraformOptions, "service_id")
	assert.NotEmpty(t, serviceID)
}

func TestAppEngineWithAutomaticScaling(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	serviceName := testhelpers.GetTestResourceName("app-autoscale", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/compute/app-engine",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"location_id": config.Region,
			"environment": "test",
			"services": []map[string]interface{}{
				{
					"service": serviceName,
					"runtime": "python39",
					"automatic_scaling": map[string]interface{}{
						"max_instances": 10,
						"min_instances": 1,
					},
				},
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	serviceID := terraform.Output(t, terraformOptions, "service_id")
	assert.NotEmpty(t, serviceID)
}

func TestAppEngineWithVPC(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	serviceName := testhelpers.GetTestResourceName("app-vpc", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/compute/app-engine",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"location_id": config.Region,
			"environment": "test",
			"services": []map[string]interface{}{
				{
					"service": serviceName,
					"runtime": "python39",
					"vpc_access_connector": map[string]interface{}{
						"name": "default-connector",
					},
				},
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	serviceID := terraform.Output(t, terraformOptions, "service_id")
	assert.NotEmpty(t, serviceID)
}
