# VPN Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for VPN resources"
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
  default     = "vpn"
}

# HA VPN Gateway Configuration
variable "ha_vpn_gateways" {
  description = "Map of HA VPN gateway configurations"
  type = map(object({
    name        = optional(string)
    description = optional(string)
    network     = string
    region      = optional(string)
    stack_type  = optional(string)  # "IPV4_ONLY", "IPV4_IPV6", "IPV6_ONLY"

    vpn_interfaces = optional(list(object({
      id                      = number
      interconnect_attachment = optional(string)
    })))
  }))
  default = {}
}

# Classic VPN Gateway Configuration
variable "classic_vpn_gateways" {
  description = "Map of classic VPN gateway configurations"
  type = map(object({
    name        = optional(string)
    description = optional(string)
    network     = string
    region      = optional(string)
  }))
  default = {}
}

# External VPN Gateway Configuration
variable "external_vpn_gateways" {
  description = "Map of external VPN gateway configurations"
  type = map(object({
    name            = optional(string)
    description     = optional(string)
    redundancy_type = optional(string)  # "SINGLE_IP_INTERNALLY_REDUNDANT", "TWO_IPS_REDUNDANCY", "FOUR_IPS_REDUNDANCY"

    interfaces = optional(list(object({
      id                      = number
      ip_address             = optional(string)
      ipv6_address           = optional(string)
      interconnect_attachment = optional(string)
    })))

    labels = optional(map(string))
  }))
  default = {}
}

# VPN Tunnel Configuration
variable "vpn_tunnels" {
  description = "Map of VPN tunnel configurations"
  type = map(object({
    name        = optional(string)
    description = optional(string)
    region      = optional(string)

    # Gateway references
    vpn_gateway_key                 = optional(string)  # Reference to ha_vpn_gateways or classic_vpn_gateways key
    vpn_gateway_type                = optional(string)  # "HA" or "CLASSIC"
    vpn_gateway                     = optional(string)  # Direct gateway reference
    peer_external_gateway_key       = optional(string)  # Reference to external_vpn_gateways key
    peer_external_gateway           = optional(string)  # Direct external gateway reference
    peer_external_gateway_interface = optional(number)
    peer_gcp_gateway               = optional(string)
    vpn_gateway_interface          = optional(number)

    # Tunnel configuration
    shared_secret           = optional(string)
    generate_shared_secret  = optional(bool)
    ike_version            = optional(number)  # 1 or 2
    peer_ip                = optional(string)
    router_key             = optional(string)  # Reference to routers key
    router                 = optional(string)  # Direct router reference

    # Traffic selectors
    local_traffic_selector  = optional(list(string))
    remote_traffic_selector = optional(list(string))

    labels = optional(map(string))
  }))
  default = {}
}

# Cloud Router Configuration
variable "routers" {
  description = "Map of Cloud Router configurations"
  type = map(object({
    name        = optional(string)
    description = optional(string)
    network     = string
    region      = optional(string)

    bgp_config = optional(object({
      asn               = number
      advertise_mode    = optional(string)  # "DEFAULT", "CUSTOM"
      advertised_groups = optional(list(string))
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

# Router Interface Configuration
variable "router_interfaces" {
  description = "Map of router interface configurations"
  type = map(object({
    name                    = optional(string)
    router_key             = optional(string)  # Reference to routers key
    router                 = optional(string)  # Direct router name
    region                 = optional(string)
    ip_range               = optional(string)
    vpn_tunnel_key         = optional(string)  # Reference to vpn_tunnels key
    vpn_tunnel             = optional(string)  # Direct VPN tunnel name
    interconnect_attachment = optional(string)
    subnetwork             = optional(string)
    private_ip_address     = optional(string)
    redundant_interface    = optional(string)
  }))
  default = {}
}

# BGP Peer Configuration
variable "bgp_peers" {
  description = "Map of BGP peer configurations"
  type = map(object({
    name                      = optional(string)
    router_key               = optional(string)  # Reference to routers key
    router                   = optional(string)  # Direct router name
    region                   = optional(string)
    interface_key            = optional(string)  # Reference to router_interfaces key
    interface                = optional(string)  # Direct interface name
    peer_ip_address          = string
    peer_asn                 = number
    advertised_route_priority = optional(number)
    advertise_mode           = optional(string)  # "DEFAULT", "CUSTOM"
    advertised_groups        = optional(list(string))

    advertised_ip_ranges = optional(list(object({
      range       = string
      description = optional(string)
    })))

    bfd_config = optional(object({
      min_receive_interval        = optional(number)
      min_transmit_interval       = optional(number)
      multiplier                  = optional(number)
      session_initialization_mode = optional(string)  # "ACTIVE", "PASSIVE", "DISABLED"
    }))

    md5_authentication_key = optional(object({
      name = string
      key  = string
    }))

    enable                     = optional(bool)
    enable_ipv6               = optional(bool)
    ipv6_nexthop_address      = optional(string)
    peer_ipv6_nexthop_address = optional(string)
    router_appliance_instance = optional(string)
    ip_address               = optional(string)
    management_type          = optional(string)
  }))
  default = {}
}

# Static Routes Configuration
variable "static_routes" {
  description = "Map of static route configurations for VPN"
  type = map(object({
    name                      = optional(string)
    description              = optional(string)
    network                  = string
    dest_range               = string
    next_hop_vpn_tunnel_key  = optional(string)  # Reference to vpn_tunnels key
    next_hop_vpn_tunnel      = optional(string)  # Direct VPN tunnel reference
    priority                 = optional(number)
    tags                     = optional(list(string))
  }))
  default = {}
}

# Firewall Rules Configuration
variable "firewall_rules" {
  description = "Map of firewall rule configurations for VPN"
  type = map(object({
    name        = optional(string)
    description = optional(string)
    network     = string
    priority    = optional(number)
    direction   = optional(string)  # "INGRESS", "EGRESS"

    source_ranges      = optional(list(string))
    destination_ranges = optional(list(string))
    source_tags        = optional(list(string))
    target_tags        = optional(list(string))
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
    log_metadata   = optional(string)  # "EXCLUDE_ALL_METADATA", "INCLUDE_ALL_METADATA"
    disabled       = optional(bool)
  }))
  default = {}
}

# Reserved IP Addresses Configuration
variable "reserved_ip_addresses" {
  description = "Map of reserved IP address configurations for VPN gateways"
  type = map(object({
    name         = optional(string)
    description  = optional(string)
    region       = optional(string)
    network_tier = optional(string)  # "PREMIUM", "STANDARD"
    purpose      = optional(string)
    labels       = optional(map(string))
  }))
  default = {}
}

# Service Account Configuration
variable "create_service_account" {
  description = "Whether to create a service account for VPN operations"
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

# Shared Secret Configuration
variable "shared_secret_length" {
  description = "Length of generated shared secrets"
  type        = number
  default     = 32
}

variable "store_secrets_in_secret_manager" {
  description = "Whether to store VPN shared secrets in Secret Manager"
  type        = bool
  default     = false
}

variable "secret_replication_regions" {
  description = "Regions for Secret Manager replication"
  type        = list(string)
  default     = null
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
    filter                = string
    threshold_value       = number
    combiner              = optional(string)
    enabled               = optional(bool)
    duration              = optional(string)
    comparison            = optional(string)
    alignment_period      = optional(string)
    per_series_aligner    = optional(string)
    cross_series_reducer  = optional(string)
    group_by_fields       = optional(list(string))
    trigger_count         = optional(number)
    trigger_percent       = optional(number)
    notification_channels = optional(list(string))
    auto_close           = optional(string)
    rate_limit = optional(object({
      period = string
    }))
    documentation_content   = optional(string)
    documentation_mime_type = optional(string)
    documentation_subject   = optional(string)
    labels                 = optional(map(string))
  }))
  default = {}
}

variable "create_monitoring_dashboard" {
  description = "Whether to create a monitoring dashboard"
  type        = bool
  default     = false
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
    name        = optional(string)
    description = optional(string)
    filter      = string
    label_extractors = optional(map(string))

    metric_descriptor = optional(object({
      metric_kind  = string  # "GAUGE", "DELTA", "CUMULATIVE"
      value_type   = string  # "BOOL", "INT64", "DOUBLE", "STRING", "DISTRIBUTION"
      unit         = optional(string)
      display_name = optional(string)
      labels = optional(list(object({
        key         = string
        value_type  = string
        description = optional(string)
      })))
    }))

    value_extractor = optional(string)
  }))
  default = {}
}

# High Availability Configuration
variable "ha_vpn_config" {
  description = "High availability VPN configuration"
  type = object({
    enable_ha                = optional(bool)
    ha_vpn_interfaces_count  = optional(number)
    enable_auto_failover     = optional(bool)
    failover_timeout_seconds = optional(number)
    enable_path_mtu_discovery = optional(bool)
    mtu_size                = optional(number)
  })
  default = {
    enable_ha               = true
    ha_vpn_interfaces_count = 2
    enable_auto_failover    = true
    failover_timeout_seconds = 30
    enable_path_mtu_discovery = true
    mtu_size               = 1460
  }
}

# Performance Configuration
variable "performance_config" {
  description = "Performance configuration for VPN"
  type = object({
    enable_accelerated_networking = optional(bool)
    enable_tcp_optimization      = optional(bool)
    tcp_mss_clamping            = optional(number)
    enable_jumbo_frames         = optional(bool)
    jumbo_frame_size           = optional(number)
    enable_qos                 = optional(bool)
    qos_bandwidth_mbps         = optional(number)
  })
  default = {
    enable_accelerated_networking = true
    enable_tcp_optimization      = true
    tcp_mss_clamping            = 1420
    enable_jumbo_frames         = false
    jumbo_frame_size           = 1500
    enable_qos                 = false
  }
}

# Security Configuration
variable "security_config" {
  description = "Security configuration for VPN"
  type = object({
    enable_perfect_forward_secrecy = optional(bool)
    pfs_group                     = optional(string)  # "GROUP14", "GROUP15", "GROUP16"
    enable_replay_protection       = optional(bool)
    enable_anti_ddos              = optional(bool)
    ddos_threshold_pps            = optional(number)
    enable_ipsec_encryption        = optional(bool)
    ipsec_encryption_algorithm     = optional(string)  # "AES128", "AES192", "AES256"
    ipsec_integrity_algorithm      = optional(string)  # "SHA1", "SHA256", "SHA384", "SHA512"
    ipsec_lifetime_seconds        = optional(number)
    enable_certificate_auth       = optional(bool)
    ca_certificate               = optional(string)
  })
  default = {
    enable_perfect_forward_secrecy = true
    pfs_group                    = "GROUP14"
    enable_replay_protection      = true
    enable_anti_ddos             = true
    ddos_threshold_pps           = 100000
    enable_ipsec_encryption       = true
    ipsec_encryption_algorithm    = "AES256"
    ipsec_integrity_algorithm     = "SHA256"
    ipsec_lifetime_seconds       = 3600
    enable_certificate_auth      = false
  }
}

# Compliance Configuration
variable "compliance_config" {
  description = "Compliance configuration for VPN"
  type = object({
    enforce_fips_compliance    = optional(bool)
    require_ipsec_encryption   = optional(bool)
    audit_logging_enabled      = optional(bool)
    compliance_report_bucket   = optional(string)
    data_residency_regions     = optional(list(string))
    enable_connection_logging  = optional(bool)
    log_retention_days        = optional(number)
  })
  default = {
    enforce_fips_compliance  = false
    require_ipsec_encryption = true
    audit_logging_enabled    = true
    enable_connection_logging = true
    log_retention_days      = 90
  }
}

# Disaster Recovery Configuration
variable "dr_config" {
  description = "Disaster recovery configuration for VPN"
  type = object({
    enable_backup_tunnels        = optional(bool)
    backup_tunnel_priority      = optional(number)
    enable_automatic_switchover  = optional(bool)
    switchover_threshold_seconds = optional(number)
    enable_tunnel_monitoring     = optional(bool)
    monitoring_interval_seconds  = optional(number)
  })
  default = {
    enable_backup_tunnels       = true
    backup_tunnel_priority     = 2000
    enable_automatic_switchover = true
    switchover_threshold_seconds = 60
    enable_tunnel_monitoring    = true
    monitoring_interval_seconds = 30
  }
}

# Labels
variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}