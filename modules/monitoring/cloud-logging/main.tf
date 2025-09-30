# Cloud Logging Module
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.45.2"
    }
  }
}

# Log Sinks
resource "google_logging_project_sink" "log_sinks" {
  for_each = var.log_sinks

  name        = each.value.name
  destination = each.value.destination
  filter      = each.value.filter
  project     = var.project_id

  depends_on = [google_project_service.logging_api]
}

# Log Exclusions
resource "google_logging_project_exclusion" "log_exclusions" {
  for_each = var.log_exclusions

  name        = each.value.name
  description = each.value.description
  filter      = each.value.filter
  project     = var.project_id

  depends_on = [google_project_service.logging_api]
}

# Enable Logging API
resource "google_project_service" "logging_api" {
  project = var.project_id
  service = "logging.googleapis.com"

  disable_on_destroy = false
}

