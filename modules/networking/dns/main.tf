# DNS Module
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.45.2"
    }
  }
}

# DNS Zone
resource "google_dns_managed_zone" "dns_zone" {
  name     = var.zone_name
  dns_name = var.dns_name
  project  = var.project_id

  depends_on = [google_project_service.dns_api]
}

# Enable DNS API
resource "google_project_service" "dns_api" {
  project = var.project_id
  service = "dns.googleapis.com"

  disable_on_destroy = false
}

# DNS Records
resource "google_dns_record_set" "records" {
  for_each = var.records

  name = "${each.value.name}.${google_dns_managed_zone.dns_zone.dns_name}"
  type = each.value.type
  ttl  = each.value.ttl

  managed_zone = google_dns_managed_zone.dns_zone.name
  project      = var.project_id

  rrdatas = [var.load_balancer_ip]
}

