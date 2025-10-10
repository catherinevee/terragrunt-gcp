package security

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

func TestKMSKeyRingBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	keyRingName := testhelpers.GetTestResourceName("kms-keyring", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/security/kms",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"location":      config.Region,
			"keyring_name":  keyRingName,
			"environment":   "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify keyring outputs
	keyRingNameOutput := terraform.Output(t, terraformOptions, "keyring_name")
	assert.Equal(t, keyRingName, keyRingNameOutput)

	keyRingID := terraform.Output(t, terraformOptions, "keyring_id")
	assert.NotEmpty(t, keyRingID)
	assert.Contains(t, keyRingID, keyRingName)
}

func TestKMSCryptoKeyBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	keyRingName := testhelpers.GetTestResourceName("kms-keyring", config.RandomID)
	cryptoKeyName := testhelpers.GetTestResourceName("crypto-key", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/security/kms",
		Vars: map[string]interface{}{
			"project_id":      config.ProjectID,
			"location":        config.Region,
			"keyring_name":    keyRingName,
			"crypto_key_name": cryptoKeyName,
			"environment":     "test",
			"rotation_period": "7776000s", // 90 days
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify crypto key outputs
	cryptoKeyNameOutput := terraform.Output(t, terraformOptions, "crypto_key_name")
	assert.Equal(t, cryptoKeyName, cryptoKeyNameOutput)

	cryptoKeyID := terraform.Output(t, terraformOptions, "crypto_key_id")
	assert.NotEmpty(t, cryptoKeyID)
	assert.Contains(t, cryptoKeyID, cryptoKeyName)
}

func TestKMSCryptoKeyWithIAMBinding(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	keyRingName := testhelpers.GetTestResourceName("kms-keyring", config.RandomID)
	cryptoKeyName := testhelpers.GetTestResourceName("crypto-key", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/security/kms",
		Vars: map[string]interface{}{
			"project_id":      config.ProjectID,
			"location":        config.Region,
			"keyring_name":    keyRingName,
			"crypto_key_name": cryptoKeyName,
			"environment":     "test",
			"iam_bindings": map[string]interface{}{
				"roles/cloudkms.cryptoKeyEncrypterDecrypter": []string{
					"serviceAccount:test@example.com",
				},
			},
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	cryptoKeyID := terraform.Output(t, terraformOptions, "crypto_key_id")
	assert.NotEmpty(t, cryptoKeyID)
}

func TestKMSCryptoKeyWithDestroyScheduleDuration(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	keyRingName := testhelpers.GetTestResourceName("kms-keyring", config.RandomID)
	cryptoKeyName := testhelpers.GetTestResourceName("crypto-key", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/security/kms",
		Vars: map[string]interface{}{
			"project_id":                 config.ProjectID,
			"location":                   config.Region,
			"keyring_name":               keyRingName,
			"crypto_key_name":            cryptoKeyName,
			"environment":                "test",
			"destroy_scheduled_duration": "86400s", // 24 hours
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	cryptoKeyID := terraform.Output(t, terraformOptions, "crypto_key_id")
	assert.NotEmpty(t, cryptoKeyID)
}
