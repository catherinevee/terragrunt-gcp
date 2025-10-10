package data

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

func TestDataprocClusterBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	clusterName := testhelpers.GetTestResourceName("dataproc-cluster", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/data/dataproc",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"region":      config.Region,
			"name":        clusterName,
			"environment": "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify cluster outputs
	clusterNameOutput := terraform.Output(t, terraformOptions, "cluster_name")
	assert.Equal(t, clusterName, clusterNameOutput)

	clusterID := terraform.Output(t, terraformOptions, "cluster_id")
	assert.NotEmpty(t, clusterID)
}

func TestDataprocClusterWithAutoscaling(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	clusterName := testhelpers.GetTestResourceName("dataproc-autoscale", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/data/dataproc",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"region":      config.Region,
			"name":        clusterName,
			"environment": "test",
			"autoscaling_policy": map[string]interface{}{
				"max_instances": 10,
				"min_instances": 2,
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	clusterNameOutput := terraform.Output(t, terraformOptions, "cluster_name")
	assert.Equal(t, clusterName, clusterNameOutput)
}

func TestDataprocClusterWithCustomImage(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	clusterName := testhelpers.GetTestResourceName("dataproc-custom", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/data/dataproc",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"region":      config.Region,
			"name":        clusterName,
			"environment": "test",
			"software_config": map[string]interface{}{
				"image_version": "2.0-debian10",
				"optional_components": []string{
					"JUPYTER",
					"ZEPPELIN",
				},
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	clusterNameOutput := terraform.Output(t, terraformOptions, "cluster_name")
	assert.Equal(t, clusterName, clusterNameOutput)
}
