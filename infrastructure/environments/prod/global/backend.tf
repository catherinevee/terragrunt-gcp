# Backend configuration for production environment
# This configures where Terraform state will be stored with enhanced security

terraform {
  backend "gcs" {
    bucket = "acme-prod-terraform-state"
    prefix = "global/terraform.tfstate"

    # Enable versioning and encryption
    enable_bucket_policy_only = true
  }
}

# Enable required APIs for production environment
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "pubsub.googleapis.com",
    "cloudsql.googleapis.com",
    "cloudkms.googleapis.com",
    "secretmanager.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "iam.googleapis.com",
    "dns.googleapis.com",
    "servicenetworking.googleapis.com",
    "vpcaccess.googleapis.com",
    "redis.googleapis.com",
    "memcache.googleapis.com",
    "dataflow.googleapis.com",
    "dataproc.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudrun.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudtasks.googleapis.com",
    "firestore.googleapis.com",
    "composer.googleapis.com",
    "spanner.googleapis.com",
    "artifactregistry.googleapis.com",
    "binaryauthorization.googleapis.com",
    "containeranalysis.googleapis.com",
    "appengine.googleapis.com",
    "apigateway.googleapis.com",
    "servicecontrol.googleapis.com",
    "servicemanagement.googleapis.com",
    "cloudbuild.googleapis.com",
    "sourcerepo.googleapis.com",
    "cloudarmor.googleapis.com",
    "websecurityscanner.googleapis.com",
    "dlp.googleapis.com",
    "cloudprofiler.googleapis.com",
    "cloudtrace.googleapis.com",
    "clouddebugger.googleapis.com",
    "clouderrorreporting.googleapis.com"
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy         = false
  disable_dependent_services = false
}

# State bucket for production environment with enhanced security
resource "google_storage_bucket" "terraform_state" {
  project  = var.project_id
  name     = "acme-prod-terraform-state"
  location = "US" # Multi-region for high availability

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 30 # Keep more versions in production
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 90 # Longer retention in production
    }
    action {
      type = "Delete"
    }
  }

  # Enable CMEK encryption
  encryption {
    default_kms_key_name = google_kms_crypto_key.terraform_state_key.id
  }

  # Retention policy to prevent accidental deletion
  retention_policy {
    retention_period = 7776000 # 90 days in seconds
    is_locked        = true
  }

  labels = {
    environment = "production"
    purpose     = "terraform-state"
    managed_by  = "terraform"
    criticality = "critical"
  }
}

# KMS key for state encryption
resource "google_kms_key_ring" "terraform_state" {
  project  = var.project_id
  name     = "terraform-state-keyring"
  location = "us"
}

resource "google_kms_crypto_key" "terraform_state_key" {
  name     = "terraform-state-key"
  key_ring = google_kms_key_ring.terraform_state.id

  rotation_period = "2592000s" # 30 days

  lifecycle {
    prevent_destroy = true
  }

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "HSM" # Hardware security module for production
  }

  labels = {
    environment = "production"
    purpose     = "state-encryption"
  }
}

# State bucket logging
resource "google_storage_bucket" "state_logs" {
  project  = var.project_id
  name     = "acme-prod-terraform-state-logs"
  location = "US"

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  lifecycle_rule {
    condition {
      age = 365 # Keep logs for 1 year in production
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    environment = "production"
    purpose     = "state-logs"
    managed_by  = "terraform"
  }
}

# Configure state bucket logging
resource "google_storage_bucket_iam_member" "state_logs_writer" {
  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectCreator"
  member = "group:cloud-storage-analytics@google.com"
}

# Logging configuration for state access
resource "google_logging_project_bucket_config" "state_bucket_logs" {
  project   = var.project_id
  bucket_id = "terraform-state-logs-prod"
  location  = "us"

  retention_days = 365 # 1 year retention for production
  description    = "Audit logs for Terraform state bucket access in production"

  # Lock the retention policy
  locked = true
}

# VPC-SC perimeter for state bucket (optional but recommended)
resource "google_access_context_manager_service_perimeter" "terraform_state" {
  count = var.enable_vpc_sc ? 1 : 0

  parent = "accessPolicies/${var.access_policy_id}"
  name   = "accessPolicies/${var.access_policy_id}/servicePerimeters/terraform_state_prod"
  title  = "Terraform State Production Perimeter"

  status {
    resources = [
      "projects/${var.project_number}"
    ]

    restricted_services = [
      "storage.googleapis.com",
      "cloudkms.googleapis.com"
    ]

    access_levels = [var.access_level_id]

    vpc_accessible_services {
      enable_restriction = true
      allowed_services = [
        "storage.googleapis.com",
        "cloudkms.googleapis.com"
      ]
    }
  }
}