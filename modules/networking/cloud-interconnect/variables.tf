# Cloud Interconnect Module - Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "enable_apis" {
  description = "Whether to enable required GCP APIs"
  type        = bool
  default     = true
}

variable "create_service_account" {
  description = "Whether to create a service account for Interconnect operations"
  type        = bool
  default     = true
}

variable "service_account_id" {
  description = "The service account ID for Interconnect operations"
  type        = string
  default     = "cloud-interconnect-sa"
}

variable "service_account_roles" {
  description = "Roles to assign to the Interconnect service account"
  type        = list(string)
  default = [
    "roles/compute.networkAdmin",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
    "roles/networkconnectivity.hubAdmin"
  ]
}

# Dedicated Interconnect Configuration
variable "dedicated_interconnects" {
  description = "Configuration for Dedicated Interconnects"
  type = map(object({
    description       = string
    location          = string
    link_count        = number
    link_type         = string
    admin_enabled     = optional(bool, true)
    noc_contact_email = optional(string)
    customer_name     = optional(string)
    expected_outages = optional(list(object({
      name        = string
      description = string
      source      = string
      state       = string
      issue_type  = string
      start_time  = string
      end_time    = string
    })))
  }))
  default = {}
}

# Partner Interconnect Configuration
variable "partner_interconnects" {
  description = "Configuration for Partner Interconnects"
  type = map(object({
    description       = string
    location          = string
    admin_enabled     = optional(bool, true)
    noc_contact_email = optional(string)
    customer_name     = optional(string)
  }))
  default = {}
}

# Dedicated Interconnect Attachments (VLANs)
variable "dedicated_attachments" {
  description = "Configuration for Dedicated Interconnect Attachments"
  type = map(object({
    description              = string
    interconnect_name        = string
    router_name              = string
    region                   = string
    vlan_tag                 = number
    bandwidth                = string
    candidate_subnets        = optional(list(string))
    admin_enabled            = optional(bool, true)
    edge_availability_domain = optional(string)
    encryption               = optional(string, "IPSEC")
    ipsec_internal_addresses = optional(list(string))
  }))
  default = {}
}

# Partner Interconnect Attachments
variable "partner_attachments" {
  description = "Configuration for Partner Interconnect Attachments"
  type = map(object({
    description              = string
    router_name              = string
    region                   = string
    bandwidth                = string
    admin_enabled            = optional(bool, true)
    edge_availability_domain = optional(string)
    pairing_key              = string
    partner_asn              = number
    encryption               = optional(string, "IPSEC")
  }))
  default = {}
}

# Cloud Router Configuration
variable "cloud_routers" {
  description = "Configuration for Cloud Routers"
  type = map(object({
    region            = string
    network           = string
    description       = optional(string)
    bgp_asn           = number
    advertise_mode    = optional(string, "DEFAULT")
    advertised_groups = optional(list(string))
    advertised_ip_ranges = optional(list(object({
      range       = string
      description = optional(string)
    })))
    keepalive_interval            = optional(number, 20)
    encrypted_interconnect_router = optional(bool, false)
  }))
  default = {}
}

# Router Interfaces Configuration
variable "router_interfaces" {
  description = "Configuration for Router Interfaces"
  type = map(object({
    router_name         = string
    region              = string
    ip_range            = optional(string)
    vpn_tunnel          = optional(string)
    attachment_name     = optional(string)
    redundant_interface = optional(string)
    subnetwork          = optional(string)
    private_ip_address  = optional(string)
  }))
  default = {}
}

# BGP Sessions Configuration
variable "bgp_sessions" {
  description = "Configuration for BGP Sessions"
  type = map(object({
    router_name               = string
    region                    = string
    peer_ip_address           = string
    peer_asn                  = number
    advertised_route_priority = optional(number, 100)
    interface_name            = string
    advertise_mode            = optional(string, "DEFAULT")
    advertised_groups         = optional(list(string))
    advertised_ip_ranges = optional(list(object({
      range       = string
      description = optional(string)
    })))
    bfd_config = optional(object({
      session_initialization_mode = string
      min_receive_interval        = number
      min_transmit_interval       = number
      multiplier                  = number
    }))
    enable                    = optional(bool, true)
    router_appliance_instance = optional(string)
  }))
  default = {}
}

# MACsec Configuration
variable "macsec_configs" {
  description = "MACsec configuration for Dedicated Interconnects"
  type = map(object({
    interconnect_name = string
    pre_shared_keys = list(object({
      name       = string
      cak        = string
      ckn        = string
      start_time = optional(string)
    }))
  }))
  default = {}
}

# Network Connectivity Center Configuration
variable "enable_network_connectivity_center" {
  description = "Whether to enable Network Connectivity Center"
  type        = bool
  default     = false
}

variable "connectivity_hub_name" {
  description = "Name of the Network Connectivity Center hub"
  type        = string
  default     = "interconnect-hub"
}

variable "connectivity_hub_description" {
  description = "Description of the Network Connectivity Center hub"
  type        = string
  default     = "Hub for Cloud Interconnect connectivity"
}

variable "connectivity_spokes" {
  description = "Configuration for Network Connectivity Center spokes"
  type = map(object({
    description = string
    location    = string
    linked_vpn_tunnels = optional(object({
      uris                       = list(string)
      site_to_site_data_transfer = optional(bool, false)
    }))
    linked_interconnect_attachments = optional(object({
      uris                       = list(string)
      site_to_site_data_transfer = optional(bool, false)
    }))
    linked_router_appliance_instances = optional(object({
      instances = list(object({
        virtual_machine = string
        ip_address      = string
      }))
      site_to_site_data_transfer = optional(bool, false)
    }))
    linked_vpc_network = optional(object({
      uri                   = string
      exclude_export_ranges = optional(list(string))
    }))
  }))
  default = {}
}

# Monitoring Configuration
variable "enable_monitoring" {
  description = "Whether to enable monitoring for Interconnect"
  type        = bool
  default     = true
}

variable "create_dashboard" {
  description = "Whether to create a monitoring dashboard"
  type        = bool
  default     = true
}

variable "dashboard_display_name" {
  description = "Display name for the monitoring dashboard"
  type        = string
  default     = "Cloud Interconnect Dashboard"
}

variable "notification_channels" {
  description = "List of notification channel IDs for alerts"
  type        = list(string)
  default     = []
}

variable "alert_policies" {
  description = "Alert policies configuration"
  type = map(object({
    display_name           = string
    combiner               = optional(string, "OR")
    enabled                = optional(bool, true)
    documentation          = optional(string)
    condition_display_name = string
    filter                 = string
    duration               = string
    comparison             = string
    threshold_value        = number
    alignment_period       = optional(string, "60s")
    per_series_aligner     = optional(string, "ALIGN_RATE")
    cross_series_reducer   = optional(string, "REDUCE_SUM")
    group_by_fields        = optional(list(string), [])
    trigger_count          = optional(number)
    trigger_percent        = optional(number)
    notification_channels  = optional(list(string), [])
    auto_close_duration    = optional(string, "86400s")
    rate_limit             = optional(string)
  }))
  default = {}
}

# IAM Configuration
variable "interconnect_iam_bindings" {
  description = "IAM bindings for Interconnect resources"
  type = map(object({
    interconnect_name = string
    role              = string
    members           = list(string)
  }))
  default = {}
}

variable "router_iam_bindings" {
  description = "IAM bindings for Cloud Router resources"
  type = map(object({
    router_name = string
    region      = string
    role        = string
    members     = list(string)
  }))
  default = {}
}

variable "hub_iam_bindings" {
  description = "IAM bindings for Network Connectivity Center hub"
  type = map(object({
    role    = string
    members = list(string)
  }))
  default = {}
}

# Logging Configuration
variable "enable_audit_logging" {
  description = "Whether to enable audit logging for Interconnect"
  type        = bool
  default     = true
}

variable "audit_log_sink_name" {
  description = "Name of the audit log sink"
  type        = string
  default     = "interconnect-audit-sink"
}

variable "audit_log_destination" {
  description = "Destination for audit logs (e.g., Cloud Storage bucket, BigQuery dataset)"
  type        = string
  default     = ""
}

# Security Configuration
variable "enable_cloud_armor" {
  description = "Whether to enable Cloud Armor for Interconnect traffic"
  type        = bool
  default     = false
}

variable "security_policy_name" {
  description = "Name of the Cloud Armor security policy"
  type        = string
  default     = "interconnect-security-policy"
}

variable "security_policy_rules" {
  description = "Cloud Armor security policy rules"
  type = list(object({
    action         = string
    priority       = number
    versioned_expr = string
    src_ip_ranges  = list(string)
    description    = string
  }))
  default = []
}

variable "enable_adaptive_protection" {
  description = "Whether to enable adaptive protection in Cloud Armor"
  type        = bool
  default     = false
}

variable "adaptive_protection_rule_visibility" {
  description = "Rule visibility for adaptive protection"
  type        = string
  default     = "STANDARD"
}

# Advanced Configuration
variable "enable_redundancy" {
  description = "Whether to enable redundancy configurations"
  type        = bool
  default     = true
}

variable "redundancy_config" {
  description = "Redundancy configuration for high availability"
  type = object({
    enable_dual_interconnects      = bool
    enable_cross_region_redundancy = bool
    failover_threshold             = optional(number, 5)
    health_check_interval          = optional(number, 10)
    preferred_interconnect         = optional(string)
    backup_interconnect            = optional(string)
  })
  default = {
    enable_dual_interconnects      = true
    enable_cross_region_redundancy = false
  }
}

variable "enable_traffic_engineering" {
  description = "Whether to enable traffic engineering features"
  type        = bool
  default     = false
}

variable "traffic_engineering_config" {
  description = "Traffic engineering configuration"
  type = object({
    enable_load_balancing           = bool
    load_balancing_algorithm        = optional(string, "ECMP")
    bandwidth_utilization_threshold = optional(number, 80)
    enable_path_selection           = optional(bool, false)
    preferred_paths                 = optional(list(string))
    backup_paths                    = optional(list(string))
  })
  default = {
    enable_load_balancing = true
  }
}

variable "enable_performance_monitoring" {
  description = "Whether to enable performance monitoring"
  type        = bool
  default     = true
}

variable "performance_monitoring_config" {
  description = "Performance monitoring configuration"
  type = object({
    enable_latency_monitoring     = bool
    enable_throughput_monitoring  = bool
    enable_packet_loss_monitoring = bool
    monitoring_interval           = optional(number, 60)
    alert_thresholds = optional(object({
      latency_threshold_ms          = optional(number, 100)
      throughput_threshold_mbps     = optional(number, 1000)
      packet_loss_threshold_percent = optional(number, 1)
    }))
  })
  default = {
    enable_latency_monitoring     = true
    enable_throughput_monitoring  = true
    enable_packet_loss_monitoring = true
  }
}

variable "enable_capacity_planning" {
  description = "Whether to enable capacity planning features"
  type        = bool
  default     = false
}

variable "capacity_planning_config" {
  description = "Capacity planning configuration"
  type = object({
    enable_usage_forecasting   = bool
    forecasting_period_days    = optional(number, 90)
    capacity_threshold_percent = optional(number, 80)
    auto_scaling_enabled       = optional(bool, false)
    scaling_policies = optional(list(object({
      metric_name     = string
      threshold_value = number
      scaling_action  = string
    })))
  })
  default = {
    enable_usage_forecasting = true
  }
}

variable "enable_cost_optimization" {
  description = "Whether to enable cost optimization features"
  type        = bool
  default     = false
}

variable "cost_optimization_config" {
  description = "Cost optimization configuration"
  type = object({
    enable_commitment_analysis = bool
    enable_right_sizing        = bool
    usage_efficiency_threshold = optional(number, 70)
    commitment_recommendations = optional(bool, true)
    idle_resource_detection    = optional(bool, true)
  })
  default = {
    enable_commitment_analysis = true
    enable_right_sizing        = true
  }
}

variable "enable_compliance_monitoring" {
  description = "Whether to enable compliance monitoring"
  type        = bool
  default     = false
}

variable "compliance_config" {
  description = "Compliance monitoring configuration"
  type = object({
    compliance_standards   = list(string)
    audit_frequency        = optional(string, "DAILY")
    compliance_reporting   = optional(bool, true)
    violation_alerts       = optional(bool, true)
    remediation_automation = optional(bool, false)
  })
  default = {
    compliance_standards = ["SOC2", "PCI_DSS"]
  }
}

variable "enable_disaster_recovery" {
  description = "Whether to enable disaster recovery configurations"
  type        = bool
  default     = false
}

variable "disaster_recovery_config" {
  description = "Disaster recovery configuration"
  type = object({
    enable_automated_failover   = bool
    failover_timeout_seconds    = optional(number, 300)
    enable_health_checks        = optional(bool, true)
    health_check_frequency      = optional(number, 30)
    backup_interconnect_regions = optional(list(string))
    recovery_time_objective     = optional(number, 3600)
    recovery_point_objective    = optional(number, 900)
  })
  default = {
    enable_automated_failover = true
  }
}

variable "network_telemetry_config" {
  description = "Network telemetry configuration"
  type = object({
    enable_flow_logs        = bool
    enable_packet_mirroring = optional(bool, false)
    flow_sampling_rate      = optional(number, 0.1)
    log_format              = optional(string, "JSON")
    retention_period_days   = optional(number, 30)
    export_destinations     = optional(list(string))
  })
  default = {
    enable_flow_logs = true
  }
}

variable "quality_of_service_config" {
  description = "Quality of Service (QoS) configuration"
  type = object({
    enable_traffic_prioritization = bool
    traffic_classes = optional(list(object({
      name              = string
      priority          = number
      bandwidth_percent = number
      dscp_marking      = optional(string)
    })))
    enable_bandwidth_guarantees = optional(bool, false)
    congestion_control          = optional(string, "BBR")
  })
  default = {
    enable_traffic_prioritization = false
  }
}

variable "peering_config" {
  description = "Peering configuration for Interconnect"
  type = object({
    enable_private_peering   = bool
    enable_microsoft_peering = optional(bool, false)
    enable_exchange_peering  = optional(bool, false)
    peering_locations        = optional(list(string))
    asn_requirements = optional(object({
      customer_asn = number
      google_asn   = number
    }))
  })
  default = {
    enable_private_peering = true
  }
}

variable "maintenance_config" {
  description = "Maintenance configuration"
  type = object({
    maintenance_window = optional(object({
      day_of_week = string
      start_time  = string
      duration    = string
    }))
    enable_automated_maintenance  = optional(bool, true)
    maintenance_notifications     = optional(bool, true)
    emergency_maintenance_contact = optional(string)
  })
  default = {}
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Network tags to apply to resources"
  type        = list(string)
  default     = []
}

# Environment-specific configurations
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "region_configs" {
  description = "Region-specific configurations"
  type = map(object({
    primary_region            = bool
    backup_region             = bool
    bandwidth_tier            = string
    latency_requirements      = optional(number)
    availability_requirements = optional(string)
  }))
  default = {}
}

variable "custom_route_advertisements" {
  description = "Custom route advertisements for BGP"
  type = map(object({
    router_name = string
    routes = list(object({
      prefix      = string
      description = optional(string)
      priority    = optional(number)
    }))
  }))
  default = {}
}

variable "enable_cross_cloud_connectivity" {
  description = "Whether to enable cross-cloud connectivity features"
  type        = bool
  default     = false
}

variable "cross_cloud_config" {
  description = "Cross-cloud connectivity configuration"
  type = object({
    aws_direct_connect = optional(object({
      enabled            = bool
      virtual_interfaces = list(string)
      bgp_configuration = object({
        asn     = number
        md5_key = optional(string)
      })
    }))
    azure_express_route = optional(object({
      enabled  = bool
      circuits = list(string)
      peering_config = object({
        asn              = number
        primary_subnet   = string
        secondary_subnet = string
      })
    }))
  })
  default = {}
}