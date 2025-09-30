# Simple test bucket for dev environment
# Minimal configuration with no dependencies

terraform {
  source = "${get_repo_root()}/modules/storage/gcs"
}

# Include root configuration
include "root" {
  path = find_in_parent_folders()
}

locals {
  project_id  = "acme-ecommerce-platform-dev"
  environment = "dev"
  region      = "us-central1"
}

# Module inputs
inputs = {
  # Project configuration
  project_id = local.project_id

  # Bucket name must be globally unique
  name     = "acme-ecommerce-dev-test-${local.project_id}"
  location = local.region

  # Storage class
  storage_class = "STANDARD"

  # Versioning
  versioning = true

  # Lifecycle rules
  lifecycle_rules = [
    {
      action = {
        type = "Delete"
      }
      condition = {
        age                   = 30
        with_state            = "ANY"
        matches_prefix        = []
        matches_suffix        = []
        matches_storage_class = []
      }
    }
  ]

  # Access control
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Labels
  labels = {
    environment         = local.environment
    managed_by          = "terragrunt"
    purpose            = "testing"
    cost_center        = "development"
    data_classification = "internal"
  }

  # Force destroy (allow deletion even with objects)
  force_destroy = true
}