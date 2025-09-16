# Container Registry Module
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.45.2"
    }
  }
}

# Artifact Registry Repositories
resource "google_artifact_registry_repository" "repositories" {
  for_each = var.repositories

  location      = var.region
  repository_id = each.value.repository_id
  description   = each.value.description
  format        = each.value.format
  project       = var.project_id

  depends_on = [google_project_service.artifact_registry_api]
}

# Artifact Registry Repository IAM Bindings - Made optional to handle permission issues
resource "google_artifact_registry_repository_iam_binding" "repository_iam_bindings" {
  for_each = var.enable_iam_bindings ? var.repository_iam_bindings : {}

  location   = var.region
  repository = google_artifact_registry_repository.repositories[each.value.repository_key].name
  role       = each.value.role
  members    = each.value.members
  project    = var.project_id
}

# Enable Artifact Registry API
resource "google_project_service" "artifact_registry_api" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"

  disable_on_destroy = false
}

# Outputs
output "repository_names" {
  description = "Names of the repositories"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.name
  }
}

output "repository_ids" {
  description = "IDs of the repositories"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.id
  }
}
