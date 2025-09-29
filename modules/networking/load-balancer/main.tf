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
  name    = var.global_ip_name
  project = var.project_id
}

# Health Check
resource "google_compute_health_check" "health_check" {
  name    = var.health_check_name
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

# Managed Instance Groups (auto-created if enabled)
resource "google_compute_region_instance_group_manager" "backend_groups" {
  for_each = var.auto_create_instance_groups ? toset(var.backend_regions) : toset([])

  name    = "${var.environment}-backend-group-${each.value}"
  project = var.project_id
  region  = each.value

  base_instance_name = var.instance_group_config.base_instance_name
  target_size        = var.instance_group_config.target_size

  version {
    instance_template = var.instance_group_config.instance_template != "" ? var.instance_group_config.instance_template : google_compute_instance_template.backend_template[0].id
  }

  dynamic "update_policy" {
    for_each = var.instance_group_config.instance_template != "" ? [1] : []
    content {
      type                  = "PROACTIVE"
      minimal_action        = "REPLACE"
      max_unavailable_fixed = 1
    }
  }

  distribution_policy_zones = var.instance_group_config.zone_distribution_policy != null ? var.instance_group_config.zone_distribution_policy.zones : null
  distribution_policy_target_shape = var.instance_group_config.zone_distribution_policy != null ? var.instance_group_config.zone_distribution_policy.target_shape : null

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_compute_instance_template.backend_template]
}

# Default instance template (created only if auto_create_instance_groups is true and no template is provided)
resource "google_compute_instance_template" "backend_template" {
  count = var.auto_create_instance_groups && var.instance_group_config.instance_template == "" ? 1 : 0

  name_prefix = "${var.environment}-backend-template-"
  project     = var.project_id

  machine_type = "e2-micro"
  region       = var.backend_regions[0]

  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
    disk_type    = "pd-standard"
    disk_size_gb = 10
  }

  network_interface {
    network = "default"
    access_config {
      # Ephemeral public IP
    }
  }

  metadata = {
    startup-script = "#!/bin/bash\napt-get update\napt-get install -y nginx\nsystemctl start nginx\nsystemctl enable nginx"
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = ["http-server", "${var.environment}-backend"]
}

# Data source to get existing instance groups by name
data "google_compute_instance_group" "existing_groups" {
  for_each = {
    for region, group_name in var.backend_instance_groups :
    region => group_name
    if !can(regex("^projects/.+/regions/.+/instanceGroups/.+$", group_name))
  }

  name    = each.value
  project = var.project_id
  zone    = "${each.key}-a" # Default to first zone in region
}

# Local values for backend group references
locals {
  # Determine the correct instance group URL for each region
  backend_groups = merge(
    # Auto-created managed instance groups
    {
      for region in var.backend_regions :
      region => google_compute_region_instance_group_manager.backend_groups[region].instance_group
      if var.auto_create_instance_groups && contains(keys(google_compute_region_instance_group_manager.backend_groups), region)
    },
    # Explicitly provided full URLs
    {
      for region, group_ref in var.backend_instance_groups :
      region => group_ref
      if can(regex("^projects/.+/regions/.+/instanceGroups/.+$", group_ref))
    },
    # Instance groups referenced by name (looked up via data source)
    {
      for region, group_name in var.backend_instance_groups :
      region => data.google_compute_instance_group.existing_groups[region].self_link
      if !can(regex("^projects/.+/regions/.+/instanceGroups/.+$", group_name)) && contains(keys(data.google_compute_instance_group.existing_groups), region)
    }
  )

  # Fallback: create placeholder URLs for regions without instance groups
  placeholder_groups = {
    for region in var.backend_regions :
    region => "projects/${var.project_id}/regions/${region}/instanceGroups/backend-group-${region}"
    if !contains(keys(local.backend_groups), region)
  }

  # Final backend group mapping
  final_backend_groups = merge(local.backend_groups, local.placeholder_groups)
}

# Backend Service
resource "google_compute_backend_service" "backend_service" {
  name    = var.backend_service_name
  project = var.project_id

  health_checks         = [google_compute_health_check.health_check.id]
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTP"

  # Timeout and connection settings
  timeout_sec                     = 30
  connection_draining_timeout_sec = 10

  # Load balancing configuration
  locality_lb_policy = "ROUND_ROBIN"

  session_affinity = "NONE"

  # Add backend groups dynamically
  dynamic "backend" {
    for_each = var.backend_regions
    content {
      group                        = local.final_backend_groups[backend.value]
      balancing_mode               = "UTILIZATION"
      capacity_scaler              = 1.0
      max_utilization              = 0.8
      max_connections              = null
      max_connections_per_instance = null
      max_connections_per_endpoint = null
      max_rate                     = null
      max_rate_per_instance        = null
      max_rate_per_endpoint        = null
    }
  }

  # Circuit breaker settings
  outlier_detection {
    consecutive_errors = 5
    interval {
      seconds = 10
    }
    base_ejection_time {
      seconds = 30
    }
    max_ejection_percent = 50
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    google_compute_region_instance_group_manager.backend_groups,
    data.google_compute_instance_group.existing_groups
  ]
}

# URL Map
resource "google_compute_url_map" "url_map" {
  name    = var.url_map_name
  project = var.project_id

  default_service = google_compute_backend_service.backend_service.id
}

# HTTP Proxy
resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "${var.forwarding_rule_name}-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.url_map.id
}

# Forwarding Rule
resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name       = var.forwarding_rule_name
  project    = var.project_id
  target     = google_compute_target_http_proxy.http_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.global_ip.address
}

