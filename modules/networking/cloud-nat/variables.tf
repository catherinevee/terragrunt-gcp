# Cloud NAT Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for Cloud NAT resources"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
  default     = "nat"
}

# Cloud Router Configuration
variable "cloud_routers" {
  description = "Map of Cloud Router configurations"
  type = map(object({
    name        = optional(string)
    description = optional(string)
    network     = string
    region      = optional(string)

    bgp_config = optional(object({
      asn                = number
      advertise_mode     = optional(string) # "DEFAULT", "CUSTOM"
      advertised_groups  = optional(list(string))
      keepalive_interval = optional(number)

      advertised_ip_ranges = optional(list(object({
        range       = string
        description = optional(string)
      })))

      identifier_range = optional(string)
    }))

    encrypted_interconnect_router = optional(bool)
  }))
  default = {}
}

# NAT Gateway Configuration
variable "nat_gateways" {
  description = "Map of Cloud NAT gateway configurations"
  type = map(object({
    name          = optional(string)
    router_name   = optional(string)
    router_key    = optional(string) # Reference to cloud_routers key
    region        = optional(string)
    create_router = optional(bool)

    # NAT IP allocation
    nat_ip_allocate_option = optional(string)       # "AUTO_ONLY", "MANUAL_ONLY"
    nat_ip_keys            = optional(list(string)) # References to nat_ip_addresses keys
    drain_nat_ips          = optional(list(string))

    # Source subnet configuration
    source_subnetwork_ip_ranges_to_nat = optional(string) # "ALL_SUBNETWORKS_ALL_IP_RANGES", "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES", "LIST_OF_SUBNETWORKS"

    subnetworks = optional(list(object({
      name                     = string
      source_ip_ranges_to_nat  = optional(list(string)) # ["ALL_IP_RANGES", "PRIMARY_IP_RANGE", "LIST_OF_SECONDARY_IP_RANGES"]
      secondary_ip_range_names = optional(list(string))
    })))

    # Port allocation
    min_ports_per_vm                    = optional(number)
    max_ports_per_vm                    = optional(number)
    enable_dynamic_port_allocation      = optional(bool)
    enable_endpoint_independent_mapping = optional(bool)

    # Timeout configuration (in seconds)
    icmp_idle_timeout_sec            = optional(number)
    tcp_established_idle_timeout_sec = optional(number)
    tcp_transitory_idle_timeout_sec  = optional(number)
    tcp_time_wait_timeout_sec        = optional(number)
    udp_idle_timeout_sec             = optional(number)

    # Logging
    enable_logging = optional(bool)
    log_filter     = optional(string) # "ALL", "ERRORS_ONLY", "TRANSLATIONS_ONLY"

    # Rules configuration
    rules = optional(list(object({
      rule_number = number
      description = optional(string)
      match       = string # CEL expression

      action = optional(object({
        source_nat_active_ip_keys = optional(list(string)) # References to nat_ip_addresses keys
        source_nat_drain_ip_keys  = optional(list(string)) # References to nat_ip_addresses keys
        source_nat_active_ranges  = optional(list(string))
        source_nat_drain_ranges   = optional(list(string))
      }))
    })))
  }))
  default = {}
}

# NAT IP Addresses
variable "nat_ip_addresses" {
  description = "Map of external IP addresses for NAT"
  type = map(object({
    name         = optional(string)
    description  = optional(string)
    region       = optional(string)
    network_tier = optional(string) # "PREMIUM", "STANDARD"
    purpose      = optional(string)
    labels       = optional(map(string))
  }))
  default = {}
}

# Router Interfaces (for VPN/Interconnect)
variable "router_interfaces" {
  description = "Map of Cloud Router interface configurations"
  type = map(object({
    name        = optional(string)
    description = optional(string)
    router_name = string
    region      = optional(string)

    ip_range                = optional(string)
    vpn_tunnel              = optional(string)
    interconnect_attachment = optional(string)
    subnetwork              = optional(string)
    private_ip_address      = optional(string)
    redundant_interface     = optional(string)
  }))
  default = {}
}

# BGP Peers
variable "bgp_peers" {
  description = "Map of BGP peer configurations"
  type = map(object({
    name                      = optional(string)
    router_name               = string
    region                    = optional(string)
    interface_name            = string
    peer_ip_address           = string
    peer_asn                  = number
    advertised_route_priority = optional(number)
    advertise_mode            = optional(string) # "DEFAULT", "CUSTOM"
    advertised_groups         = optional(list(string))

    advertised_ip_ranges = optional(list(object({
      range       = string
      description = optional(string)
    })))

    bfd_config = optional(object({
      min_receive_interval        = optional(number)
      min_transmit_interval       = optional(number)
      multiplier                  = optional(number)
      session_initialization_mode = optional(string) # "ACTIVE", "PASSIVE", "DISABLED"
    }))

    enable                    = optional(bool)
    enable_ipv6               = optional(bool)
    ipv6_nexthop_address      = optional(string)
    peer_ipv6_nexthop_address = optional(string)
    router_appliance_instance = optional(string)
  }))
  default = {}
}

# Custom Routes
variable "custom_routes" {
  description = "Map of custom route configurations"
  type = map(object({
    name                = optional(string)
    description         = optional(string)
    dest_range          = string
    network             = string
    next_hop_gateway    = optional(string)
    next_hop_instance   = optional(string)
    next_hop_ip         = optional(string)
    next_hop_vpn_tunnel = optional(string)
    next_hop_ilb        = optional(string)
    priority            = optional(number)
    tags                = optional(list(string))
  }))
  default = {}
}

# Firewall Rules
variable "firewall_rules" {
  description = "Map of firewall rule configurations for NAT"
  type = map(object({
    name        = optional(string)
    description = optional(string)
    network     = string
    priority    = optional(number)
    direction   = optional(string) # "INGRESS", "EGRESS"

    source_ranges           = optional(list(string))
    destination_ranges      = optional(list(string))
    source_tags             = optional(list(string))
    target_tags             = optional(list(string))
    source_service_accounts = optional(list(string))
    target_service_accounts = optional(list(string))

    allow = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })))

    deny = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })))

    enable_logging = optional(bool)
    log_metadata   = optional(string) # "EXCLUDE_ALL_METADATA", "INCLUDE_ALL_METADATA"
    disabled       = optional(bool)
  }))
  default = {}
}

# Service Account Configuration
variable "create_service_account" {
  description = "Whether to create a service account for NAT operations"
  type        = bool
  default     = false
}

variable "service_account_name" {
  description = "Name of the service account"
  type        = string
  default     = null
}

variable "grant_service_account_roles" {
  description = "Whether to grant roles to the service account"
  type        = bool
  default     = false
}

variable "service_account_roles" {
  description = "Roles to grant to the service account"
  type        = list(string)
  default = [
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter"
  ]
}

# Monitoring Configuration
variable "create_monitoring_alerts" {
  description = "Whether to create monitoring alert policies"
  type        = bool
  default     = false
}

variable "monitoring_alerts" {
  description = "Monitoring alert policies configuration"
  type = map(object({
    display_name           = string
    condition_display_name = string
    filter                 = string
    threshold_value        = number
    combiner               = optional(string)
    enabled                = optional(bool)
    duration               = optional(string)
    comparison             = optional(string)
    alignment_period       = optional(string)
    per_series_aligner     = optional(string)
    cross_series_reducer   = optional(string)
    group_by_fields        = optional(list(string))
    trigger_count          = optional(number)
    trigger_percent        = optional(number)
    notification_channels  = optional(list(string))
    auto_close             = optional(string)
    rate_limit = optional(object({
      period = string
    }))
    documentation_content   = optional(string)
    documentation_mime_type = optional(string)
    documentation_subject   = optional(string)
    labels                  = optional(map(string))
  }))
  default = {}
}

variable "create_monitoring_dashboard" {
  description = "Whether to create a monitoring dashboard"
  type        = bool
  default     = false
}

# Logging Configuration
variable "enable_log_export" {
  description = "Whether to export NAT logs"
  type        = bool
  default     = false
}

variable "log_export_destination" {
  description = "Destination for log export (e.g., BigQuery dataset)"
  type        = string
  default     = null
}

variable "log_export_filter" {
  description = "Filter for log export"
  type        = string
  default     = null
}

variable "log_export_use_partitioned_tables" {
  description = "Use partitioned tables for BigQuery log export"
  type        = bool
  default     = true
}

# Log Metrics Configuration
variable "create_log_metrics" {
  description = "Whether to create log-based metrics"
  type        = bool
  default     = false
}

variable "log_metrics" {
  description = "Log-based metrics configuration"
  type = map(object({
    name             = optional(string)
    description      = optional(string)
    filter           = string
    label_extractors = optional(map(string))

    metric_descriptor = optional(object({
      metric_kind  = string # "GAUGE", "DELTA", "CUMULATIVE"
      value_type   = string # "BOOL", "INT64", "DOUBLE", "STRING", "DISTRIBUTION"
      unit         = optional(string)
      display_name = optional(string)
      labels = optional(list(object({
        key         = string
        value_type  = string
        description = optional(string)
      })))
    }))

    bucket_options = optional(object({
      linear_buckets = optional(object({
        num_finite_buckets = number
        width              = number
        offset             = number
      }))

      exponential_buckets = optional(object({
        num_finite_buckets = number
        growth_factor      = number
        scale              = number
      }))
    }))

    value_extractor = optional(string)
  }))
  default = {}
}

# Labels
variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}