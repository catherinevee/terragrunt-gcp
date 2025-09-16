package main

import (
	"os"
	"testing"
)

func TestBasic(t *testing.T) {
	// Test that we can read environment variables
	projectID := os.Getenv("GCP_PROJECT_ID")
	if projectID == "" {
		t.Log("GCP_PROJECT_ID not set, using default")
		projectID = "acme-ecommerce-platform-dev"
	}

	t.Logf("Using project ID: %s", projectID)

	// Basic test that always passes
	if projectID == "" {
		t.Fatal("Project ID should not be empty")
	}
}
