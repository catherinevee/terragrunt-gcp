# Secret Manager Module
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.45.2"
    }
  }
}

# Secret Manager Secrets
resource "google_secret_manager_secret" "secrets" {
  for_each = var.secrets

  secret_id = each.value.secret_id
  project   = var.project_id

  replication {
    dynamic "user_managed" {
      for_each = each.value.replication.automatic ? [] : [1]
      content {
        replicas {
          location = "us-central1"
        }
      }
    }
    dynamic "automatic" {
      for_each = each.value.replication.automatic ? [1] : []
      content {}
    }
  }

  depends_on = [google_project_service.secret_manager_api]
}

# Secret Manager Secret Versions
resource "google_secret_manager_secret_version" "secret_versions" {
  for_each = var.secret_versions

  secret      = google_secret_manager_secret.secrets[each.value.secret_key].id
  secret_data = each.value.secret_data
}

# Secret Manager Secret IAM Bindings - Made optional to handle permission issues
resource "google_secret_manager_secret_iam_binding" "secret_iam_bindings" {
  for_each = var.enable_iam_bindings ? var.secret_iam_bindings : {}

  secret_id = google_secret_manager_secret.secrets[each.value.secret_key].id
  role      = each.value.role
  members   = each.value.members
}

# Enable Secret Manager API
resource "google_project_service" "secret_manager_api" {
  project = var.project_id
  service = "secretmanager.googleapis.com"

  disable_on_destroy = false
}

