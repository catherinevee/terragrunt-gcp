package networking

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

func TestDNSManagedZoneBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	zoneName := testhelpers.GetTestResourceName("dns-zone", config.RandomID)
	dnsName := zoneName + ".example.com."

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/dns",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"name":        zoneName,
			"dns_name":    dnsName,
			"environment": "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify DNS zone outputs
	zoneNameOutput := terraform.Output(t, terraformOptions, "zone_name")
	assert.Equal(t, zoneName, zoneNameOutput)

	nameServers := terraform.OutputList(t, terraformOptions, "name_servers")
	assert.NotEmpty(t, nameServers)
	assert.GreaterOrEqual(t, len(nameServers), 2)
}

func TestDNSManagedZonePrivate(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	zoneName := testhelpers.GetTestResourceName("dns-private", config.RandomID)
	dnsName := zoneName + ".internal."

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/dns",
		Vars: map[string]interface{}{
			"project_id":      config.ProjectID,
			"name":            zoneName,
			"dns_name":        dnsName,
			"environment":     "test",
			"visibility":      "private",
			"private_networks": []string{"default"},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	zoneNameOutput := terraform.Output(t, terraformOptions, "zone_name")
	assert.Equal(t, zoneName, zoneNameOutput)
}

func TestDNSRecordSetA(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	zoneName := testhelpers.GetTestResourceName("dns-zone", config.RandomID)
	dnsName := zoneName + ".example.com."

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/dns",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"name":        zoneName,
			"dns_name":    dnsName,
			"environment": "test",
			"record_sets": []map[string]interface{}{
				{
					"name":    "test." + dnsName,
					"type":    "A",
					"ttl":     300,
					"rrdatas": []string{"1.2.3.4"},
				},
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	zoneNameOutput := terraform.Output(t, terraformOptions, "zone_name")
	assert.Equal(t, zoneName, zoneNameOutput)
}

func TestDNSRecordSetCNAME(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	zoneName := testhelpers.GetTestResourceName("dns-zone", config.RandomID)
	dnsName := zoneName + ".example.com."

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/dns",
		Vars: map[string]interface{}{
			"project_id":  config.ProjectID,
			"name":        zoneName,
			"dns_name":    dnsName,
			"environment": "test",
			"record_sets": []map[string]interface{}{
				{
					"name":    "www." + dnsName,
					"type":    "CNAME",
					"ttl":     300,
					"rrdatas": []string{dnsName},
				},
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	zoneNameOutput := terraform.Output(t, terraformOptions, "zone_name")
	assert.Equal(t, zoneName, zoneNameOutput)
}
