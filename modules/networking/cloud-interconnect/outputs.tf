# Cloud Interconnect Module - Outputs

# Dedicated Interconnect outputs
output "dedicated_interconnect_ids" {
  description = "IDs of Dedicated Interconnects"
  value = {
    for k, v in google_compute_interconnect.dedicated_interconnects : k => v.id
  }
}

output "dedicated_interconnect_names" {
  description = "Names of Dedicated Interconnects"
  value = {
    for k, v in google_compute_interconnect.dedicated_interconnects : k => v.name
  }
}

output "dedicated_interconnect_details" {
  description = "Detailed information about Dedicated Interconnects"
  value = {
    for k, v in google_compute_interconnect.dedicated_interconnects : k => {
      id                     = v.id
      name                   = v.name
      description            = v.description
      location               = v.location
      link_count             = v.requested_link_count
      link_type              = v.link_type
      interconnect_type      = v.interconnect_type
      state                  = v.state
      google_ip_address      = v.google_ip_address
      google_reference_id    = v.google_reference_id
      expected_outages       = v.expected_outages
      circuit_infos          = v.circuit_infos
      provisioned_link_count = v.provisioned_link_count
    }
  }
}

# Partner Interconnect outputs
output "partner_interconnect_ids" {
  description = "IDs of Partner Interconnects"
  value = {
    for k, v in google_compute_interconnect.partner_interconnects : k => v.id
  }
}

output "partner_interconnect_names" {
  description = "Names of Partner Interconnects"
  value = {
    for k, v in google_compute_interconnect.partner_interconnects : k => v.name
  }
}

output "partner_interconnect_details" {
  description = "Detailed information about Partner Interconnects"
  value = {
    for k, v in google_compute_interconnect.partner_interconnects : k => {
      id                  = v.id
      name                = v.name
      description         = v.description
      location            = v.location
      interconnect_type   = v.interconnect_type
      state               = v.state
      google_ip_address   = v.google_ip_address
      google_reference_id = v.google_reference_id
    }
  }
}

# Interconnect Attachment outputs
output "dedicated_attachment_ids" {
  description = "IDs of Dedicated Interconnect Attachments"
  value = {
    for k, v in google_compute_interconnect_attachment.dedicated_attachments : k => v.id
  }
}

output "dedicated_attachment_names" {
  description = "Names of Dedicated Interconnect Attachments"
  value = {
    for k, v in google_compute_interconnect_attachment.dedicated_attachments : k => v.name
  }
}

output "dedicated_attachment_details" {
  description = "Detailed information about Dedicated Interconnect Attachments"
  value = {
    for k, v in google_compute_interconnect_attachment.dedicated_attachments : k => {
      id                         = v.id
      name                       = v.name
      description                = v.description
      interconnect               = v.interconnect
      router                     = v.router
      region                     = v.region
      vlan_tag8021q              = v.vlan_tag8021q
      bandwidth                  = v.bandwidth
      type                       = v.type
      state                      = v.state
      google_reference_id        = v.google_reference_id
      cloud_router_ip_address    = v.cloud_router_ip_address
      customer_router_ip_address = v.customer_router_ip_address
      pairing_key                = v.pairing_key
      partner_asn                = v.partner_asn
      encryption                 = v.encryption
      dataplane_version          = v.dataplane_version
    }
  }
}

output "partner_attachment_ids" {
  description = "IDs of Partner Interconnect Attachments"
  value = {
    for k, v in google_compute_interconnect_attachment.partner_attachments : k => v.id
  }
}

output "partner_attachment_names" {
  description = "Names of Partner Interconnect Attachments"
  value = {
    for k, v in google_compute_interconnect_attachment.partner_attachments : k => v.name
  }
}

output "partner_attachment_details" {
  description = "Detailed information about Partner Interconnect Attachments"
  value = {
    for k, v in google_compute_interconnect_attachment.partner_attachments : k => {
      id                         = v.id
      name                       = v.name
      description                = v.description
      router                     = v.router
      region                     = v.region
      bandwidth                  = v.bandwidth
      type                       = v.type
      state                      = v.state
      google_reference_id        = v.google_reference_id
      cloud_router_ip_address    = v.cloud_router_ip_address
      customer_router_ip_address = v.customer_router_ip_address
      pairing_key                = v.pairing_key
      partner_asn                = v.partner_asn
      encryption                 = v.encryption
      dataplane_version          = v.dataplane_version
    }
  }
}

# Cloud Router outputs
output "router_ids" {
  description = "IDs of Cloud Routers"
  value = {
    for k, v in google_compute_router.interconnect_routers : k => v.id
  }
}

output "router_names" {
  description = "Names of Cloud Routers"
  value = {
    for k, v in google_compute_router.interconnect_routers : k => v.name
  }
}

output "router_details" {
  description = "Detailed information about Cloud Routers"
  value = {
    for k, v in google_compute_router.interconnect_routers : k => {
      id                            = v.id
      name                          = v.name
      description                   = v.description
      region                        = v.region
      network                       = v.network
      bgp_asn                       = v.bgp[0].asn
      bgp_advertise_mode            = v.bgp[0].advertise_mode
      bgp_advertised_groups         = v.bgp[0].advertised_groups
      bgp_advertised_ip_ranges      = v.bgp[0].advertised_ip_ranges
      encrypted_interconnect_router = v.encrypted_interconnect_router
    }
  }
}

# Router Interface outputs
output "router_interface_names" {
  description = "Names of Router Interfaces"
  value = {
    for k, v in google_compute_router_interface.interconnect_interfaces : k => v.name
  }
}

output "router_interface_details" {
  description = "Detailed information about Router Interfaces"
  value = {
    for k, v in google_compute_router_interface.interconnect_interfaces : k => {
      name                    = v.name
      router                  = v.router
      region                  = v.region
      ip_range                = v.ip_range
      vpn_tunnel              = v.vpn_tunnel
      interconnect_attachment = v.interconnect_attachment
      redundant_interface     = v.redundant_interface
      subnetwork              = v.subnetwork
      private_ip_address      = v.private_ip_address
    }
  }
}

# BGP Session outputs
output "bgp_session_names" {
  description = "Names of BGP Sessions"
  value = {
    for k, v in google_compute_router_peer.interconnect_bgp_peers : k => v.name
  }
}

output "bgp_session_details" {
  description = "Detailed information about BGP Sessions"
  value = {
    for k, v in google_compute_router_peer.interconnect_bgp_peers : k => {
      name                      = v.name
      router                    = v.router
      region                    = v.region
      peer_ip_address           = v.peer_ip_address
      peer_asn                  = v.peer_asn
      advertised_route_priority = v.advertised_route_priority
      interface                 = v.interface
      advertise_mode            = v.advertise_mode
      advertised_groups         = v.advertised_groups
      advertised_ip_ranges      = v.advertised_ip_ranges
      enable                    = v.enable
      router_appliance_instance = v.router_appliance_instance
      management_type           = v.management_type
    }
  }
}

# Network Connectivity Center outputs
output "connectivity_hub_id" {
  description = "ID of the Network Connectivity Center hub"
  value       = var.enable_network_connectivity_center ? google_network_connectivity_hub.connectivity_hub[0].id : null
}

output "connectivity_hub_name" {
  description = "Name of the Network Connectivity Center hub"
  value       = var.enable_network_connectivity_center ? google_network_connectivity_hub.connectivity_hub[0].name : null
}

output "connectivity_hub_details" {
  description = "Detailed information about the Network Connectivity Center hub"
  value = var.enable_network_connectivity_center ? {
    id          = google_network_connectivity_hub.connectivity_hub[0].id
    name        = google_network_connectivity_hub.connectivity_hub[0].name
    description = google_network_connectivity_hub.connectivity_hub[0].description
    state       = google_network_connectivity_hub.connectivity_hub[0].state
    create_time = google_network_connectivity_hub.connectivity_hub[0].create_time
    update_time = google_network_connectivity_hub.connectivity_hub[0].update_time
    unique_id   = google_network_connectivity_hub.connectivity_hub[0].unique_id
  } : null
}

output "connectivity_spoke_ids" {
  description = "IDs of Network Connectivity Center spokes"
  value = {
    for k, v in google_network_connectivity_spoke.interconnect_spokes : k => v.id
  }
}

output "connectivity_spoke_names" {
  description = "Names of Network Connectivity Center spokes"
  value = {
    for k, v in google_network_connectivity_spoke.interconnect_spokes : k => v.name
  }
}

output "connectivity_spoke_details" {
  description = "Detailed information about Network Connectivity Center spokes"
  value = {
    for k, v in google_network_connectivity_spoke.interconnect_spokes : k => {
      id          = v.id
      name        = v.name
      description = v.description
      location    = v.location
      hub         = v.hub
      state       = v.state
      create_time = v.create_time
      update_time = v.update_time
      unique_id   = v.unique_id
    }
  }
}

# MACsec outputs
output "macsec_config_names" {
  description = "Names of MACsec configurations"
  value = {
    for k, v in google_compute_interconnect_macsec_config.macsec_configs : k => v.name
  }
}

output "macsec_config_details" {
  description = "Detailed information about MACsec configurations"
  value = {
    for k, v in google_compute_interconnect_macsec_config.macsec_configs : k => {
      name            = v.name
      interconnect    = v.interconnect
      pre_shared_keys = v.pre_shared_keys
    }
  }
  sensitive = true
}

# Service Account outputs
output "service_account_email" {
  description = "Email of the Interconnect service account"
  value       = var.create_service_account ? google_service_account.interconnect_sa[0].email : null
}

output "service_account_id" {
  description = "ID of the Interconnect service account"
  value       = var.create_service_account ? google_service_account.interconnect_sa[0].account_id : null
}

output "service_account_unique_id" {
  description = "Unique ID of the Interconnect service account"
  value       = var.create_service_account ? google_service_account.interconnect_sa[0].unique_id : null
}

# Monitoring outputs
output "monitoring_dashboard_id" {
  description = "ID of the Interconnect monitoring dashboard"
  value       = var.enable_monitoring && var.create_dashboard ? google_monitoring_dashboard.interconnect_dashboard[0].id : null
}

output "monitoring_dashboard_url" {
  description = "URL to the Interconnect monitoring dashboard"
  value = var.enable_monitoring && var.create_dashboard ? (
    "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.interconnect_dashboard[0].id}?project=${var.project_id}"
  ) : null
}

output "alert_policy_ids" {
  description = "IDs of created alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.interconnect_alerts : k => v.id
  }
}

output "alert_policy_names" {
  description = "Names of created alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.interconnect_alerts : k => v.display_name
  }
}

# Configuration metadata
output "configuration_metadata" {
  description = "Metadata about the Interconnect configuration"
  value = {
    project_id                    = var.project_id
    dedicated_interconnects_count = length(google_compute_interconnect.dedicated_interconnects)
    partner_interconnects_count   = length(google_compute_interconnect.partner_interconnects)
    dedicated_attachments_count   = length(google_compute_interconnect_attachment.dedicated_attachments)
    partner_attachments_count     = length(google_compute_interconnect_attachment.partner_attachments)
    cloud_routers_count           = length(google_compute_router.interconnect_routers)
    bgp_sessions_count            = length(google_compute_router_peer.interconnect_bgp_peers)
    router_interfaces_count       = length(google_compute_router_interface.interconnect_interfaces)
    macsec_configs_count          = length(google_compute_interconnect_macsec_config.macsec_configs)
    connectivity_center_enabled   = var.enable_network_connectivity_center
    connectivity_spokes_count     = length(google_network_connectivity_spoke.interconnect_spokes)
    monitoring_enabled            = var.enable_monitoring
    audit_logging_enabled         = var.enable_audit_logging
    cloud_armor_enabled           = var.enable_cloud_armor
    total_alert_policies          = length(google_monitoring_alert_policy.interconnect_alerts)
  }
}

# Connectivity summary
output "connectivity_summary" {
  description = "Summary of connectivity configuration"
  value = {
    interconnect_types = {
      dedicated = length(google_compute_interconnect.dedicated_interconnects)
      partner   = length(google_compute_interconnect.partner_interconnects)
    }
    attachment_types = {
      dedicated = length(google_compute_interconnect_attachment.dedicated_attachments)
      partner   = length(google_compute_interconnect_attachment.partner_attachments)
    }
    regions_covered = toset([
      for router in google_compute_router.interconnect_routers : router.region
    ])
    total_bandwidth = {
      dedicated_attachments = {
        for k, v in google_compute_interconnect_attachment.dedicated_attachments : k => v.bandwidth
      }
      partner_attachments = {
        for k, v in google_compute_interconnect_attachment.partner_attachments : k => v.bandwidth
      }
    }
    redundancy_enabled          = var.enable_redundancy
    traffic_engineering_enabled = var.enable_traffic_engineering
  }
}

# Security configuration
output "security_configuration" {
  description = "Security configuration details"
  value = {
    macsec_enabled = length(google_compute_interconnect_macsec_config.macsec_configs) > 0
    encryption_enabled = {
      for k, v in merge(
        google_compute_interconnect_attachment.dedicated_attachments,
        google_compute_interconnect_attachment.partner_attachments
      ) : k => v.encryption
    }
    cloud_armor_enabled   = var.enable_cloud_armor
    audit_logging_enabled = var.enable_audit_logging
    iam_bindings_configured = {
      interconnect_bindings = length(var.interconnect_iam_bindings)
      router_bindings       = length(var.router_iam_bindings)
      hub_bindings          = length(var.hub_iam_bindings)
    }
  }
}

# Operational status
output "operational_status" {
  description = "Operational status and health information"
  value = {
    interconnect_states = merge(
      {
        for k, v in google_compute_interconnect.dedicated_interconnects : k => v.state
      },
      {
        for k, v in google_compute_interconnect.partner_interconnects : k => v.state
      }
    )
    attachment_states = merge(
      {
        for k, v in google_compute_interconnect_attachment.dedicated_attachments : k => v.state
      },
      {
        for k, v in google_compute_interconnect_attachment.partner_attachments : k => v.state
      }
    )
    monitoring_enabled             = var.enable_monitoring
    performance_monitoring_enabled = var.enable_performance_monitoring
    disaster_recovery_enabled      = var.enable_disaster_recovery
    maintenance_configured         = var.maintenance_config != {}
  }
}

# BGP configuration summary
output "bgp_configuration" {
  description = "BGP configuration summary"
  value = {
    router_asns = {
      for k, v in google_compute_router.interconnect_routers : k => v.bgp[0].asn
    }
    bgp_sessions = {
      for k, v in google_compute_router_peer.interconnect_bgp_peers : k => {
        peer_asn                  = v.peer_asn
        peer_ip_address           = v.peer_ip_address
        advertised_route_priority = v.advertised_route_priority
        advertise_mode            = v.advertise_mode
        enabled                   = v.enable
      }
    }
    advertised_routes = {
      for k, v in google_compute_router.interconnect_routers : k => {
        advertise_mode       = v.bgp[0].advertise_mode
        advertised_groups    = v.bgp[0].advertised_groups
        advertised_ip_ranges = v.bgp[0].advertised_ip_ranges
      }
    }
  }
}

# Network telemetry information
output "network_telemetry" {
  description = "Network telemetry configuration"
  value = {
    flow_logs_enabled        = var.network_telemetry_config.enable_flow_logs
    packet_mirroring_enabled = var.network_telemetry_config.enable_packet_mirroring
    flow_sampling_rate       = var.network_telemetry_config.flow_sampling_rate
    log_format               = var.network_telemetry_config.log_format
    retention_period         = var.network_telemetry_config.retention_period_days
    export_destinations      = var.network_telemetry_config.export_destinations
  }
}

# Cost optimization information
output "cost_optimization" {
  description = "Cost optimization configuration"
  value = {
    optimization_enabled        = var.enable_cost_optimization
    commitment_analysis_enabled = var.cost_optimization_config.enable_commitment_analysis
    right_sizing_enabled        = var.cost_optimization_config.enable_right_sizing
    usage_efficiency_threshold  = var.cost_optimization_config.usage_efficiency_threshold
    idle_resource_detection     = var.cost_optimization_config.idle_resource_detection
  }
}

# Compliance information
output "compliance_status" {
  description = "Compliance monitoring status"
  value = {
    compliance_monitoring_enabled = var.enable_compliance_monitoring
    compliance_standards          = var.compliance_config.compliance_standards
    audit_frequency               = var.compliance_config.audit_frequency
    compliance_reporting          = var.compliance_config.compliance_reporting
    violation_alerts              = var.compliance_config.violation_alerts
    remediation_automation        = var.compliance_config.remediation_automation
  }
}

# Management URLs
output "management_urls" {
  description = "URLs for managing Cloud Interconnect resources"
  value = {
    interconnect_console         = "https://console.cloud.google.com/hybrid/interconnect?project=${var.project_id}"
    network_connectivity_console = var.enable_network_connectivity_center ? "https://console.cloud.google.com/networking/networkconnectivity?project=${var.project_id}" : null
    cloud_router_console         = "https://console.cloud.google.com/networking/routers?project=${var.project_id}"
    monitoring_console           = var.enable_monitoring ? "https://console.cloud.google.com/monitoring?project=${var.project_id}" : null
    logs_console                 = "https://console.cloud.google.com/logs/query?project=${var.project_id}"
    network_topology_console     = "https://console.cloud.google.com/networking/topology?project=${var.project_id}"
  }
}

# Resource identifiers for integration
output "resource_identifiers" {
  description = "Resource identifiers for integration with other modules"
  value = {
    dedicated_interconnect_resources = {
      for k, v in google_compute_interconnect.dedicated_interconnects : k => v.id
    }
    partner_interconnect_resources = {
      for k, v in google_compute_interconnect.partner_interconnects : k => v.id
    }
    attachment_resources = merge(
      {
        for k, v in google_compute_interconnect_attachment.dedicated_attachments : k => v.id
      },
      {
        for k, v in google_compute_interconnect_attachment.partner_attachments : k => v.id
      }
    )
    router_resources = {
      for k, v in google_compute_router.interconnect_routers : k => v.id
    }
    connectivity_hub_resource = var.enable_network_connectivity_center ? google_network_connectivity_hub.connectivity_hub[0].id : null
    service_account_resource  = var.create_service_account ? google_service_account.interconnect_sa[0].id : null
  }
}

# Bandwidth utilization summary
output "bandwidth_summary" {
  description = "Bandwidth allocation and utilization summary"
  value = {
    dedicated_interconnect_capacity = {
      for k, v in google_compute_interconnect.dedicated_interconnects : k => {
        link_count     = v.requested_link_count
        link_type      = v.link_type
        total_capacity = "${v.requested_link_count}x${v.link_type}"
      }
    }
    attachment_bandwidth_allocation = merge(
      {
        for k, v in google_compute_interconnect_attachment.dedicated_attachments : k => v.bandwidth
      },
      {
        for k, v in google_compute_interconnect_attachment.partner_attachments : k => v.bandwidth
      }
    )
    utilization_monitoring    = var.enable_performance_monitoring
    capacity_planning_enabled = var.enable_capacity_planning
  }
}

# Pairing keys for Partner Interconnects (sensitive)
output "partner_attachment_pairing_keys" {
  description = "Pairing keys for Partner Interconnect Attachments"
  value = {
    for k, v in google_compute_interconnect_attachment.partner_attachments : k => v.pairing_key
  }
  sensitive = true
}

# Connection status information
output "connection_status" {
  description = "Connection status and health metrics"
  value = {
    interconnect_operational_status = merge(
      {
        for k, v in google_compute_interconnect.dedicated_interconnects : k => {
          state               = v.state
          google_ip_address   = v.google_ip_address
          google_reference_id = v.google_reference_id
        }
      },
      {
        for k, v in google_compute_interconnect.partner_interconnects : k => {
          state               = v.state
          google_ip_address   = v.google_ip_address
          google_reference_id = v.google_reference_id
        }
      }
    )
    attachment_ip_addresses = merge(
      {
        for k, v in google_compute_interconnect_attachment.dedicated_attachments : k => {
          cloud_router_ip    = v.cloud_router_ip_address
          customer_router_ip = v.customer_router_ip_address
        }
      },
      {
        for k, v in google_compute_interconnect_attachment.partner_attachments : k => {
          cloud_router_ip    = v.cloud_router_ip_address
          customer_router_ip = v.customer_router_ip_address
        }
      }
    )
    health_monitoring_enabled    = var.enable_performance_monitoring
    disaster_recovery_configured = var.enable_disaster_recovery
  }
}