# Create static IPs if manual allocation is selected
resource "google_compute_address" "nat_ip" {
  count = var.nat_ip_allocate_option == "MANUAL_ONLY" && length(var.nat_ips) == 0 ? 1 : 0

  name         = "${var.name}-nat-ip-${count.index}"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"

  lifecycle {
    create_before_destroy = true
  }
}

# Cloud NAT configuration
resource "google_compute_router_nat" "nat" {
  name                               = var.name
  project                            = var.project_id
  router                             = var.router_name
  region                             = var.region
  nat_ip_allocate_option            = var.nat_ip_allocate_option
  source_subnetwork_ip_ranges_to_nat = var.source_subnetwork_ip_ranges_to_nat

  # Use provided IPs or the ones we created
  nat_ips = var.nat_ip_allocate_option == "MANUAL_ONLY" ? (
    length(var.nat_ips) > 0 ? var.nat_ips : google_compute_address.nat_ip[*].self_link
  ) : []

  # Port allocation
  min_ports_per_vm                    = var.min_ports_per_vm
  max_ports_per_vm                    = var.max_ports_per_vm
  enable_endpoint_independent_mapping = var.enable_endpoint_independent_mapping
  enable_dynamic_port_allocation      = var.enable_dynamic_port_allocation

  # Timeouts
  icmp_idle_timeout_sec            = var.icmp_idle_timeout_sec
  tcp_established_idle_timeout_sec = var.tcp_established_idle_timeout_sec
  tcp_transitory_idle_timeout_sec  = var.tcp_transitory_idle_timeout_sec
  tcp_time_wait_timeout_sec        = var.tcp_time_wait_timeout_sec
  udp_idle_timeout_sec             = var.udp_idle_timeout_sec

  # Subnetwork configuration for LIST_OF_SUBNETWORKS mode
  dynamic "subnetwork" {
    for_each = var.source_subnetwork_ip_ranges_to_nat == "LIST_OF_SUBNETWORKS" ? var.subnetworks : []
    content {
      name                    = subnetwork.value.name
      source_ip_ranges_to_nat = subnetwork.value.source_ip_ranges_to_nat

      dynamic "secondary_ip_range_names" {
        for_each = length(subnetwork.value.secondary_ip_range_names) > 0 ? [1] : []
        content {
          secondary_ip_range_names = subnetwork.value.secondary_ip_range_names
        }
      }
    }
  }

  # Logging configuration
  dynamic "log_config" {
    for_each = var.log_config.enable ? [var.log_config] : []
    content {
      enable = log_config.value.enable
      filter = log_config.value.filter
    }
  }

  depends_on = [google_compute_address.nat_ip]
}