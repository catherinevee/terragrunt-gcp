# VPC Network Module
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.45.2"
    }
  }
}

# VPC Network
resource "google_compute_network" "vpc_network" {
  name                    = var.network_name
  description             = var.description
  auto_create_subnetworks = var.auto_create_subnetworks
  routing_mode            = var.routing_mode

  project = var.project_id

  depends_on = [google_project_service.compute_api]
}

# Enable Compute Engine API
resource "google_project_service" "compute_api" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

# Outputs
output "network_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.vpc_network.name
}

output "network_self_link" {
  description = "Self-link of the VPC network"
  value       = google_compute_network.vpc_network.self_link
}

output "network_id" {
  description = "ID of the VPC network"
  value       = google_compute_network.vpc_network.id
}
