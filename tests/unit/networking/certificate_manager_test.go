package networking

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/your-org/terragrunt-gcp/tests/internal/testhelpers"
)

func TestCertificateManagerBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	certName := testhelpers.GetTestResourceName("cert-basic", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/certificate-manager",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"name":          certName,
			"location":      config.Region,
			"domains":       []string{fmt.Sprintf("%s.example.com", certName)},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	certificateID := terraform.Output(t, terraformOptions, "certificate_id")
	assert.NotEmpty(t, certificateID)

	certificateName := terraform.Output(t, terraformOptions, "certificate_name")
	assert.Contains(t, certificateName, certName)
}

func TestCertificateManagerWithDNSAuthorization(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	certName := testhelpers.GetTestResourceName("cert-dns", config.RandomID)
	domain := fmt.Sprintf("%s.example.com", certName)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/certificate-manager",
		Vars: map[string]interface{}{
			"project_id":           config.ProjectID,
			"name":                 certName,
			"location":             config.Region,
			"domains":              []string{domain},
			"dns_authorizations":   true,
			"dns_authorization_domain": domain,
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	certificateID := terraform.Output(t, terraformOptions, "certificate_id")
	assert.NotEmpty(t, certificateID)

	dnsAuthorizationID := terraform.Output(t, terraformOptions, "dns_authorization_id")
	assert.NotEmpty(t, dnsAuthorizationID)

	dnsResourceRecord := terraform.Output(t, terraformOptions, "dns_resource_record")
	assert.NotEmpty(t, dnsResourceRecord)
}

func TestCertificateManagerWithCertificateMap(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	certName := testhelpers.GetTestResourceName("cert-map", config.RandomID)
	mapName := testhelpers.GetTestResourceName("cert-map", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/certificate-manager",
		Vars: map[string]interface{}{
			"project_id":           config.ProjectID,
			"name":                 certName,
			"location":             config.Region,
			"domains":              []string{fmt.Sprintf("%s.example.com", certName)},
			"create_certificate_map": true,
			"certificate_map_name": mapName,
			"certificate_map_entries": map[string]interface{}{
				"primary": map[string]string{
					"hostname":     fmt.Sprintf("%s.example.com", certName),
					"certificates": certName,
				},
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	certificateID := terraform.Output(t, terraformOptions, "certificate_id")
	assert.NotEmpty(t, certificateID)

	certificateMapID := terraform.Output(t, terraformOptions, "certificate_map_id")
	assert.NotEmpty(t, certificateMapID)

	certificateMapName := terraform.Output(t, terraformOptions, "certificate_map_name")
	assert.Contains(t, certificateMapName, mapName)
}

func TestCertificateManagerWithMultipleDomains(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	certName := testhelpers.GetTestResourceName("cert-multi", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/certificate-manager",
		Vars: map[string]interface{}{
			"project_id": config.ProjectID,
			"name":       certName,
			"location":   config.Region,
			"domains": []string{
				fmt.Sprintf("%s.example.com", certName),
				fmt.Sprintf("www.%s.example.com", certName),
				fmt.Sprintf("api.%s.example.com", certName),
			},
			"labels": map[string]string{
				"environment": "test",
				"managed-by":  "terraform",
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	certificateID := terraform.Output(t, terraformOptions, "certificate_id")
	assert.NotEmpty(t, certificateID)

	domains := terraform.OutputList(t, terraformOptions, "domains")
	assert.Len(t, domains, 3)
	assert.Contains(t, domains, fmt.Sprintf("%s.example.com", certName))
	assert.Contains(t, domains, fmt.Sprintf("www.%s.example.com", certName))
	assert.Contains(t, domains, fmt.Sprintf("api.%s.example.com", certName))
}
