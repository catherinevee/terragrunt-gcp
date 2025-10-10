package networking

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

func TestVPNHAGatewayBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	vpnName := testhelpers.GetTestResourceName("ha-vpn", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/vpn",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"region":      config.Region,
			"environment": "test",
			"ha_vpn_gateways": map[string]interface{}{
				"gateway1": map[string]interface{}{
					"name":    vpnName,
					"network": "default",
				},
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify VPN gateway outputs
	gatewayName := terraform.Output(t, terraformOptions, "ha_vpn_gateway_name")
	assert.Contains(t, gatewayName, vpnName)

	gatewayID := terraform.Output(t, terraformOptions, "ha_vpn_gateway_id")
	assert.NotEmpty(t, gatewayID)
}

func TestVPNTunnelBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	vpnName := testhelpers.GetTestResourceName("vpn-tunnel", config.RandomID)
	routerName := testhelpers.GetTestResourceName("router", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/vpn",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"region":      config.Region,
			"environment": "test",
			"ha_vpn_gateways": map[string]interface{}{
				"gateway1": map[string]interface{}{
					"name":    vpnName,
					"network": "default",
				},
			},
			"vpn_tunnels": []map[string]interface{}{
				{
					"name":                  vpnName + "-tunnel",
					"vpn_gateway":           vpnName,
					"peer_external_gateway": "8.8.8.8",
					"shared_secret":         "test-shared-secret",
					"router":                routerName,
				},
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify tunnel outputs
	tunnelName := terraform.Output(t, terraformOptions, "vpn_tunnel_name")
	assert.Contains(t, tunnelName, "tunnel")
}

func TestVPNWithCloudRouter(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	vpnName := testhelpers.GetTestResourceName("vpn-router", config.RandomID)
	routerName := testhelpers.GetTestResourceName("cloud-router", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/vpn",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"region":      config.Region,
			"environment": "test",
			"ha_vpn_gateways": map[string]interface{}{
				"gateway1": map[string]interface{}{
					"name":    vpnName,
					"network": "default",
				},
			},
			"cloud_routers": map[string]interface{}{
				"router1": map[string]interface{}{
					"name":    routerName,
					"network": "default",
					"bgp": map[string]interface{}{
						"asn": 64512,
					},
				},
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify router outputs
	routerNameOutput := terraform.Output(t, terraformOptions, "router_name")
	assert.Contains(t, routerNameOutput, routerName)
}

func TestVPNSiteToSite(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	vpnName := testhelpers.GetTestResourceName("site2site", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/vpn",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"region":      config.Region,
			"environment": "test",
			"ha_vpn_gateways": map[string]interface{}{
				"gateway1": map[string]interface{}{
					"name":    vpnName + "-gw1",
					"network": "default",
				},
				"gateway2": map[string]interface{}{
					"name":    vpnName + "-gw2",
					"network": "default",
				},
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	gatewayName := terraform.Output(t, terraformOptions, "ha_vpn_gateway_name")
	assert.NotEmpty(t, gatewayName)
}
