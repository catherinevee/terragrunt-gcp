package networking

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

func TestCloudNATBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	natName := testhelpers.GetTestResourceName("cloud-nat", config.RandomID)
	routerName := testhelpers.GetTestResourceName("router", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/cloud-nat",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"region":        config.Region,
			"name":          natName,
			"router_name":   routerName,
			"network_name":  "default",
			"environment":   "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify NAT outputs
	natNameOutput := terraform.Output(t, terraformOptions, "nat_name")
	assert.Equal(t, natName, natNameOutput)

	natID := terraform.Output(t, terraformOptions, "nat_id")
	assert.NotEmpty(t, natID)
}

func TestCloudNATWithStaticIPs(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	natName := testhelpers.GetTestResourceName("cloud-nat-static", config.RandomID)
	routerName := testhelpers.GetTestResourceName("router", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/cloud-nat",
		Vars: map[string]interface{}{
			"project_id":           config.ProjectID,
			"region":               config.Region,
			"name":                 natName,
			"router_name":          routerName,
			"network_name":         "default",
			"environment":          "test",
			"nat_ip_allocate_option": "MANUAL_ONLY",
			"nat_ips_count":        2,
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	natIPs := terraform.OutputList(t, terraformOptions, "nat_ips")
	assert.GreaterOrEqual(t, len(natIPs), 2)
}

func TestCloudNATWithLogging(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	natName := testhelpers.GetTestResourceName("cloud-nat-log", config.RandomID)
	routerName := testhelpers.GetTestResourceName("router", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/cloud-nat",
		Vars: map[string]interface{}{
			"project_id":          config.ProjectID,
			"region":              config.Region,
			"name":                natName,
			"router_name":         routerName,
			"network_name":        "default",
			"environment":         "test",
			"enable_logging":      true,
			"log_config_filter":   "ERRORS_ONLY",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	natNameOutput := terraform.Output(t, terraformOptions, "nat_name")
	assert.Equal(t, natName, natNameOutput)
}
