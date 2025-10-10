package kubernetes

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

func TestGKEClusterBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	clusterName := testhelpers.GetTestResourceName("gke-cluster", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/kubernetes/gke",
		Vars: map[string]interface{}{
			"project_id":      config.ProjectID,
			"name":            clusterName,
			"location":        config.Region,
			"environment":     "test",
			"network_name":    "default",
			"subnetwork_name": "default",
			"node_count":      1,
			"machine_type":    "e2-medium",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify cluster outputs
	clusterNameOutput := terraform.Output(t, terraformOptions, "cluster_name")
	assert.Equal(t, clusterName, clusterNameOutput)

	endpoint := terraform.Output(t, terraformOptions, "endpoint")
	assert.NotEmpty(t, endpoint)

	// Verify cluster exists in GCP
	cluster := gcp.GetGKECluster(t, config.ProjectID, config.Region, clusterName)
	assert.Equal(t, clusterName, cluster.Name)
	assert.Equal(t, "RUNNING", cluster.Status)
}

func TestGKEClusterWithAutoscaling(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	clusterName := testhelpers.GetTestResourceName("gke-autoscale", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/kubernetes/gke",
		Vars: map[string]interface{}{
			"project_id":       config.ProjectID,
			"name":             clusterName,
			"location":         config.Region,
			"environment":      "test",
			"network_name":     "default",
			"subnetwork_name":  "default",
			"enable_autoscaling": true,
			"min_node_count":   1,
			"max_node_count":   3,
			"machine_type":     "e2-medium",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify autoscaling configuration
	cluster := gcp.GetGKECluster(t, config.ProjectID, config.Region, clusterName)
	assert.NotNil(t, cluster.Autoscaling)
}

func TestGKEClusterWithPrivateNodes(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	clusterName := testhelpers.GetTestResourceName("gke-private", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/kubernetes/gke",
		Vars: map[string]interface{}{
			"project_id":         config.ProjectID,
			"name":               clusterName,
			"location":           config.Region,
			"environment":        "test",
			"network_name":       "default",
			"subnetwork_name":    "default",
			"enable_private_nodes": true,
			"node_count":         1,
			"machine_type":       "e2-medium",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify private cluster configuration
	cluster := gcp.GetGKECluster(t, config.ProjectID, config.Region, clusterName)
	assert.NotNil(t, cluster.PrivateClusterConfig)
	assert.True(t, cluster.PrivateClusterConfig.EnablePrivateNodes)
}
