package data

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terragrunt-gcp/terragrunt-gcp/testhelpers"
)

func TestFirestoreDatabaseBasic(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	databaseName := testhelpers.GetTestResourceName("firestore-db", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/data/firestore",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"name":          databaseName,
			"location_id":   config.Region,
			"environment":   "test",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify database outputs
	dbNameOutput := terraform.Output(t, terraformOptions, "database_name")
	assert.Equal(t, databaseName, dbNameOutput)

	dbID := terraform.Output(t, terraformOptions, "database_id")
	assert.NotEmpty(t, dbID)
}

func TestFirestoreDatabaseNativeMode(t *testing.T) {
	t.Parallel()

	config := testhelpers.GetTestConfig(t)
	testhelpers.ValidateGCPCredentials(t)

	databaseName := testhelpers.GetTestResourceName("firestore-native", config.RandomID)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/data/firestore",
		Vars: map[string]interface{}{
			"project_id":    config.ProjectID,
			"name":          databaseName,
			"location_id":   config.Region,
			"environment":   "test",
			"database_type": "FIRESTORE_NATIVE",
		},
		NoColor: true,
		Logger:  logger.Discard,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	dbNameOutput := terraform.Output(t, terraformOptions, "database_name")
	assert.Equal(t, databaseName, dbNameOutput)
}
