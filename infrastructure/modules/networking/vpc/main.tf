# VPC Network Module

resource "google_compute_network" "vpc" {
  name                            = var.name
  project                         = var.project_id
  auto_create_subnetworks         = var.auto_create_subnetworks
  routing_mode                    = var.routing_mode
  mtu                            = var.mtu
  delete_default_routes_on_create = var.delete_default_routes_on_create
  description                     = var.description
}

# Subnets
resource "google_compute_subnetwork" "subnets" {
  for_each = { for subnet in var.subnets : subnet.subnet_name => subnet }

  name                     = each.value.subnet_name
  project                  = var.project_id
  network                  = google_compute_network.vpc.self_link
  region                   = each.value.subnet_region
  ip_cidr_range           = each.value.subnet_ip
  private_ip_google_access = lookup(each.value, "subnet_private_access", false)
  description             = lookup(each.value, "description", null)
  
  dynamic "log_config" {
    for_each = lookup(each.value, "subnet_flow_logs", false) ? [1] : []
    content {
      aggregation_interval = lookup(each.value, "subnet_flow_logs_interval", "INTERVAL_5_SEC")
      flow_sampling       = lookup(each.value, "subnet_flow_logs_sampling", 0.5)
      metadata            = lookup(each.value, "subnet_flow_logs_metadata", "INCLUDE_ALL_METADATA")
    }
  }

  dynamic "secondary_ip_range" {
    for_each = lookup(var.secondary_ranges, each.value.subnet_name, [])
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }
}

# Firewall Rules
resource "google_compute_firewall" "rules" {
  for_each = { for rule in var.firewall_rules : rule.name => rule }

  name        = each.value.name
  project     = var.project_id
  network     = google_compute_network.vpc.self_link
  description = lookup(each.value, "description", null)
  direction   = lookup(each.value, "direction", "INGRESS")
  priority    = lookup(each.value, "priority", 1000)

  source_ranges      = lookup(each.value, "source_ranges", null)
  destination_ranges = lookup(each.value, "destination_ranges", null)
  source_tags       = lookup(each.value, "source_tags", null)
  target_tags       = lookup(each.value, "target_tags", null)

  dynamic "allow" {
    for_each = lookup(each.value, "allow", [])
    content {
      protocol = allow.value.protocol
      ports    = lookup(allow.value, "ports", null)
    }
  }

  dynamic "deny" {
    for_each = lookup(each.value, "deny", [])
    content {
      protocol = deny.value.protocol
      ports    = lookup(deny.value, "ports", null)
    }
  }

  dynamic "log_config" {
    for_each = lookup(each.value, "enable_logging", false) ? [1] : []
    content {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }
}

# Cloud Router (for NAT)
resource "google_compute_router" "router" {
  count = var.enable_cloud_nat ? 1 : 0

  name    = "${var.name}-router"
  project = var.project_id
  network = google_compute_network.vpc.self_link
  region  = var.region

  bgp {
    asn = 64514
  }
}

# Cloud NAT
resource "google_compute_router_nat" "nat" {
  count = var.enable_cloud_nat ? 1 : 0

  name                               = var.nat_config.name
  project                            = var.project_id
  router                             = google_compute_router.router[0].name
  region                             = var.region
  nat_ip_allocate_option            = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = var.nat_config.source_subnetwork_ip_ranges_to_nat

  min_ports_per_vm                    = lookup(var.nat_config, "min_ports_per_vm", 64)
  max_ports_per_vm                    = lookup(var.nat_config, "max_ports_per_vm", 2048)
  tcp_established_idle_timeout_sec    = lookup(var.nat_config, "tcp_established_idle_timeout_sec", 1200)
  tcp_transitory_idle_timeout_sec     = lookup(var.nat_config, "tcp_transitory_idle_timeout_sec", 30)
  enable_endpoint_independent_mapping = lookup(var.nat_config, "enable_endpoint_independent_mapping", false)

  log_config {
    enable = true
    filter = "ALL"
  }
}

# VPC Connector for Serverless
resource "google_vpc_access_connector" "connector" {
  count = var.enable_vpc_connector ? 1 : 0

  name          = var.vpc_connector_config.name
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.vpc.self_link
  ip_cidr_range = var.vpc_connector_config.ip_cidr_range
  
  min_instances = lookup(var.vpc_connector_config, "min_instances", 2)
  max_instances = lookup(var.vpc_connector_config, "max_instances", 3)
  
  machine_type = lookup(var.vpc_connector_config, "machine_type", "f1-micro")
}

# Private Service Connection (for managed services like Cloud SQL)
resource "google_compute_global_address" "private_service_connection" {
  count = var.enable_private_service_connection ? 1 : 0

  name          = "${var.name}-private-service-connection"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.self_link
}

resource "google_service_networking_connection" "private_service_connection" {
  count = var.enable_private_service_connection ? 1 : 0

  network                 = google_compute_network.vpc.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_connection[0].name]
}