# Load Balancer Module
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.45.2"
    }
  }
}

# Global IP Address
resource "google_compute_global_address" "global_ip" {
  name = var.global_ip_name
  project = var.project_id
}

# Health Check
resource "google_compute_health_check" "health_check" {
  name = var.health_check_name
  project = var.project_id

  http_health_check {
    port         = var.health_check_config.port
    request_path = var.health_check_config.request_path
  }

  check_interval_sec  = var.health_check_config.check_interval_sec
  timeout_sec         = var.health_check_config.timeout_sec
  healthy_threshold   = var.health_check_config.healthy_threshold
  unhealthy_threshold = var.health_check_config.unhealthy_threshold
}

# Backend Service
resource "google_compute_backend_service" "backend_service" {
  name = var.backend_service_name
  project = var.project_id

  health_checks = [google_compute_health_check.health_check.id]
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol = "HTTP"

  # Add backend regions
  dynamic "backend" {
    for_each = var.backend_regions
    content {
      group = "projects/${var.project_id}/regions/${backend.value}/instanceGroups/placeholder"
    }
  }
}

# URL Map
resource "google_compute_url_map" "url_map" {
  name = var.url_map_name
  project = var.project_id

  default_service = google_compute_backend_service.backend_service.id
}

# HTTP Proxy
resource "google_compute_target_http_proxy" "http_proxy" {
  name = "${var.forwarding_rule_name}-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.url_map.id
}

# Forwarding Rule
resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name = var.forwarding_rule_name
  project = var.project_id
  target = google_compute_target_http_proxy.http_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.global_ip.address
}

# Outputs
output "global_ip_address" {
  description = "Global IP address of the load balancer"
  value       = google_compute_global_address.global_ip.address
}

output "health_check_id" {
  description = "ID of the health check"
  value       = google_compute_health_check.health_check.id
}

output "backend_service_id" {
  description = "ID of the backend service"
  value       = google_compute_backend_service.backend_service.id
}
