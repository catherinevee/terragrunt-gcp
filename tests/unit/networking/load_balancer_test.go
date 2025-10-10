package networking

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

func TestLoadBalancerHTTP(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	lbName := testhelpers.GetTestResourceName("lb-http", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/load-balancer",
		Vars: map[string]interface{}{
			"project_id":   config.ProjectID,
			"name":         lbName,
			"environment":  "test",
			"load_balancer_type": "HTTP",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify load balancer outputs
	lbIPAddress := terraform.Output(t, terraformOptions, "ip_address")
	assert.NotEmpty(t, lbIPAddress)

	lbName := terraform.Output(t, terraformOptions, "name")
	assert.Contains(t, lbName, "lb-http")
}

func TestLoadBalancerHTTPS(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	lbName := testhelpers.GetTestResourceName("lb-https", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/load-balancer",
		Vars: map[string]interface{}{
			"project_id":           config.ProjectID,
			"name":                 lbName,
			"environment":          "test",
			"load_balancer_type":   "HTTPS",
			"ssl_certificates":     []string{"test-cert"},
			"enable_ssl":           true,
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	lbIPAddress := terraform.Output(t, terraformOptions, "ip_address")
	assert.NotEmpty(t, lbIPAddress)
}

func TestLoadBalancerWithCDN(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	lbName := testhelpers.GetTestResourceName("lb-cdn", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/load-balancer",
		Vars: map[string]interface{}{
			"project_id":           config.ProjectID,
			"name":                 lbName,
			"environment":          "test",
			"load_balancer_type":   "HTTP",
			"enable_cdn":           true,
			"cdn_cache_mode":       "CACHE_ALL_STATIC",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	lbName := terraform.Output(t, terraformOptions, "name")
	assert.Contains(t, lbName, "lb-cdn")
}

func TestLoadBalancerTCP(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	lbName := testhelpers.GetTestResourceName("lb-tcp", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/load-balancer",
		Vars: map[string]interface{}{
			"project_id":           config.ProjectID,
			"region":               config.Region,
			"name":                 lbName,
			"environment":          "test",
			"load_balancer_type":   "TCP",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	lbIPAddress := terraform.Output(t, terraformOptions, "ip_address")
	assert.NotEmpty(t, lbIPAddress)
}
