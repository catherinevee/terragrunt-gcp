locals {
  subnets_map = { for subnet in var.subnets : subnet.name => subnet }
}

resource "google_compute_subnetwork" "subnet" {
  for_each = local.subnets_map

  name                     = each.value.name
  project                  = var.project_id
  region                   = coalesce(each.value.region, var.region)
  network                  = var.network_name
  ip_cidr_range           = each.value.ip_cidr_range
  description             = each.value.description
  private_ip_google_access = each.value.private_ip_google_access
  
  # Optional fields for special purpose subnets
  purpose = each.value.purpose
  role    = each.value.role

  # Flow logs configuration
  dynamic "log_config" {
    for_each = each.value.flow_logs ? [each.value.log_config != null ? each.value.log_config : {}] : []
    content {
      aggregation_interval = lookup(log_config.value, "aggregation_interval", "INTERVAL_5_SEC")
      flow_sampling       = lookup(log_config.value, "flow_sampling", 0.5)
      metadata           = lookup(log_config.value, "metadata", "INCLUDE_ALL_METADATA")
    }
  }

  # Secondary IP ranges (useful for GKE pods and services)
  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ip_ranges
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }

  # Ensure the subnet is created in the correct project
  lifecycle {
    create_before_destroy = true
  }
}

# Create Cloud Router for NAT (if needed)
resource "google_compute_router" "router" {
  count = length([for s in var.subnets : s if s.private_ip_google_access == true]) > 0 ? 1 : 0

  name    = "${var.network_name}-router"
  project = var.project_id
  region  = var.region
  network = var.network_name

  bgp {
    asn = 64514
  }
}

# Firewall rule to allow IAP for SSH (useful for private subnets)
resource "google_compute_firewall" "iap_ssh" {
  count = length([for s in var.subnets : s if s.private_ip_google_access == true]) > 0 ? 1 : 0

  name    = "${var.network_name}-allow-iap-ssh"
  project = var.project_id
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]  # IAP IP range

  target_tags = ["iap-ssh"]
}