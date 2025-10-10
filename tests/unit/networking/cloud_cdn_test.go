package networking

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/your-org/terragrunt-gcp/tests/internal/testhelpers"
)

func TestCloudCDNBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	cdnName := testhelpers.GetTestResourceName("cdn-basic", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/cloud-cdn",
		Vars: map[string]interface{}{
			"project_id":   config.ProjectID,
			"name":         cdnName,
			"enable_cdn":   true,
			"backend_type": "COMPUTE_RO_BUCKET",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	cdnEnabled := terraform.Output(t, terraformOptions, "cdn_enabled")
	assert.Equal(t, "true", cdnEnabled)

	backendServiceName := terraform.Output(t, terraformOptions, "backend_service_name")
	assert.Contains(t, backendServiceName, cdnName)
}

func TestCloudCDNWithCustomCacheSettings(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	cdnName := testhelpers.GetTestResourceName("cdn-cache", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/cloud-cdn",
		Vars: map[string]interface{}{
			"project_id":          config.ProjectID,
			"name":                cdnName,
			"enable_cdn":          true,
			"cache_mode":          "CACHE_ALL_STATIC",
			"default_ttl":         3600,
			"max_ttl":             86400,
			"client_ttl":          7200,
			"negative_caching":    true,
			"serve_while_stale":   86400,
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	cdnEnabled := terraform.Output(t, terraformOptions, "cdn_enabled")
	assert.Equal(t, "true", cdnEnabled)

	cacheMode := terraform.Output(t, terraformOptions, "cache_mode")
	assert.Equal(t, "CACHE_ALL_STATIC", cacheMode)

	defaultTTL := terraform.Output(t, terraformOptions, "default_ttl")
	assert.Equal(t, "3600", defaultTTL)
}

func TestCloudCDNWithSignedURLs(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	cdnName := testhelpers.GetTestResourceName("cdn-signed", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/cloud-cdn",
		Vars: map[string]interface{}{
			"project_id":              config.ProjectID,
			"name":                    cdnName,
			"enable_cdn":              true,
			"enable_signed_urls":      true,
			"signed_url_cache_max_age": 3600,
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	cdnEnabled := terraform.Output(t, terraformOptions, "cdn_enabled")
	assert.Equal(t, "true", cdnEnabled)

	signedURLsEnabled := terraform.Output(t, terraformOptions, "signed_urls_enabled")
	assert.Equal(t, "true", signedURLsEnabled)

	signedURLCacheMaxAge := terraform.Output(t, terraformOptions, "signed_url_cache_max_age")
	assert.Equal(t, "3600", signedURLCacheMaxAge)
}

func TestCloudCDNWithCacheInvalidation(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	cdnName := testhelpers.GetTestResourceName("cdn-invalidate", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/networking/cloud-cdn",
		Vars: map[string]interface{}{
			"project_id":                  config.ProjectID,
			"name":                        cdnName,
			"enable_cdn":                  true,
			"enable_cache_key_policy":     true,
			"include_host":                true,
			"include_protocol":            true,
			"include_query_string":        true,
			"query_string_whitelist":      []string{"key1", "key2"},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	cdnEnabled := terraform.Output(t, terraformOptions, "cdn_enabled")
	assert.Equal(t, "true", cdnEnabled)

	cacheKeyPolicyEnabled := terraform.Output(t, terraformOptions, "cache_key_policy_enabled")
	assert.Equal(t, "true", cacheKeyPolicyEnabled)

	includeHost := terraform.Output(t, terraformOptions, "include_host")
	assert.Equal(t, "true", includeHost)

	includeProtocol := terraform.Output(t, terraformOptions, "include_protocol")
	assert.Equal(t, "true", includeProtocol)
}
