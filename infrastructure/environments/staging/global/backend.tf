# Backend configuration for staging environment
# This configures where Terraform state will be stored

terraform {
  backend "gcs" {
    bucket = "acme-staging-terraform-state"
    prefix = "global/terraform.tfstate"
  }
}

# Enable required APIs for staging environment
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
    "sourcerepo.googleapis.com"
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
  disable_dependent_services = false
}

# State bucket for staging environment
resource "google_storage_bucket" "terraform_state" {
  project  = var.project_id
  name     = "acme-staging-terraform-state"
  location = var.default_region

  uniform_bucket_level_access = true
  public_access_prevention   = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 10
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 30
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    environment = "staging"
    purpose     = "terraform-state"
    managed_by  = "terraform"
  }
}

# Enable state bucket logging
resource "google_storage_bucket" "state_logs" {
  project  = var.project_id
  name     = "acme-staging-terraform-state-logs"
  location = var.default_region

  uniform_bucket_level_access = true
  public_access_prevention   = "enforced"

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    environment = "staging"
    purpose     = "state-logs"
    managed_by  = "terraform"
  }
}

resource "google_storage_bucket_iam_member" "state_logs_writer" {
  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectCreator"
  member = "group:cloud-storage-analytics@google.com"
}

# Configure logging for state bucket
resource "google_logging_project_bucket_config" "state_bucket_logs" {
  project  = var.project_id
  bucket_id = "terraform-state-logs"
  location = var.default_region

  retention_days = 30
  description    = "Logs for Terraform state bucket access in staging"
}