# Cloud NAT Module Outputs

# Cloud Router Outputs
output "router_ids" {
  description = "The identifiers for Cloud Routers"
  value = {
    for k, v in google_compute_router.routers : k => v.id
  }
}

output "router_names" {
  description = "The names of Cloud Routers"
  value = {
    for k, v in google_compute_router.routers : k => v.name
  }
}

output "router_self_links" {
  description = "The self links of Cloud Routers"
  value = {
    for k, v in google_compute_router.routers : k => v.self_link
  }
}

output "router_creation_timestamps" {
  description = "The creation timestamps of Cloud Routers"
  value = {
    for k, v in google_compute_router.routers : k => v.creation_timestamp
  }
}

# NAT Gateway Outputs
output "nat_gateway_ids" {
  description = "The identifiers for NAT gateways"
  value = {
    for k, v in google_compute_router_nat.nat_gateways : k => v.id
  }
}

output "nat_gateway_names" {
  description = "The names of NAT gateways"
  value = {
    for k, v in google_compute_router_nat.nat_gateways : k => v.name
  }
}

# NAT IP Address Outputs
output "nat_ip_addresses" {
  description = "The external IP addresses for NAT"
  value = {
    for k, v in google_compute_address.nat_ips : k => v.address
  }
}

output "nat_ip_ids" {
  description = "The identifiers for NAT IP addresses"
  value = {
    for k, v in google_compute_address.nat_ips : k => v.id
  }
}

output "nat_ip_names" {
  description = "The names of NAT IP addresses"
  value = {
    for k, v in google_compute_address.nat_ips : k => v.name
  }
}

output "nat_ip_self_links" {
  description = "The self links of NAT IP addresses"
  value = {
    for k, v in google_compute_address.nat_ips : k => v.self_link
  }
}

output "nat_ip_users" {
  description = "The resources using NAT IP addresses"
  value = {
    for k, v in google_compute_address.nat_ips : k => v.users
    if length(v.users) > 0
  }
}

output "nat_ip_network_tiers" {
  description = "The network tiers of NAT IP addresses"
  value = {
    for k, v in google_compute_address.nat_ips : k => v.network_tier
  }
}

output "nat_ip_creation_timestamps" {
  description = "The creation timestamps of NAT IP addresses"
  value = {
    for k, v in google_compute_address.nat_ips : k => v.creation_timestamp
  }
}

# Router Interface Outputs
output "router_interface_ids" {
  description = "The identifiers for router interfaces"
  value = {
    for k, v in google_compute_router_interface.interfaces : k => v.id
  }
}

output "router_interface_names" {
  description = "The names of router interfaces"
  value = {
    for k, v in google_compute_router_interface.interfaces : k => v.name
  }
}

# BGP Peer Outputs
output "bgp_peer_ids" {
  description = "The identifiers for BGP peers"
  value = {
    for k, v in google_compute_router_peer.bgp_peers : k => v.id
  }
}

output "bgp_peer_names" {
  description = "The names of BGP peers"
  value = {
    for k, v in google_compute_router_peer.bgp_peers : k => v.name
  }
}

output "bgp_peer_ip_addresses" {
  description = "The IP addresses of BGP peers"
  value = {
    for k, v in google_compute_router_peer.bgp_peers : k => v.ip_address
  }
}

output "bgp_peer_management_types" {
  description = "The management types of BGP peers"
  value = {
    for k, v in google_compute_router_peer.bgp_peers : k => v.management_type
  }
}

# Custom Route Outputs
output "custom_route_ids" {
  description = "The identifiers for custom routes"
  value = {
    for k, v in google_compute_route.custom_routes : k => v.id
  }
}

output "custom_route_names" {
  description = "The names of custom routes"
  value = {
    for k, v in google_compute_route.custom_routes : k => v.name
  }
}

output "custom_route_self_links" {
  description = "The self links of custom routes"
  value = {
    for k, v in google_compute_route.custom_routes : k => v.self_link
  }
}

output "custom_route_next_hop_networks" {
  description = "The next hop networks of custom routes"
  value = {
    for k, v in google_compute_route.custom_routes : k => v.next_hop_network
  }
}

# Firewall Rule Outputs
output "firewall_rule_ids" {
  description = "The identifiers for firewall rules"
  value = {
    for k, v in google_compute_firewall.nat_firewall_rules : k => v.id
  }
}

output "firewall_rule_names" {
  description = "The names of firewall rules"
  value = {
    for k, v in google_compute_firewall.nat_firewall_rules : k => v.name
  }
}

output "firewall_rule_self_links" {
  description = "The self links of firewall rules"
  value = {
    for k, v in google_compute_firewall.nat_firewall_rules : k => v.self_link
  }
}

output "firewall_rule_creation_timestamps" {
  description = "The creation timestamps of firewall rules"
  value = {
    for k, v in google_compute_firewall.nat_firewall_rules : k => v.creation_timestamp
  }
}

# Service Account Outputs
output "service_account_email" {
  description = "The email of the created service account"
  value       = var.create_service_account ? google_service_account.nat[0].email : null
}

output "service_account_id" {
  description = "The unique id of the service account"
  value       = var.create_service_account ? google_service_account.nat[0].unique_id : null
}

output "service_account_name" {
  description = "The fully-qualified name of the service account"
  value       = var.create_service_account ? google_service_account.nat[0].name : null
}

output "service_account_member" {
  description = "The IAM member format for the service account"
  value       = var.create_service_account ? "serviceAccount:${google_service_account.nat[0].email}" : null
}

# Monitoring Outputs
output "monitoring_alert_policy_ids" {
  description = "IDs of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.nat_alerts : k => v.id
  }
}

output "monitoring_alert_policy_names" {
  description = "Names of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.nat_alerts : k => v.name
  }
}

output "monitoring_dashboard_id" {
  description = "ID of the monitoring dashboard"
  value       = var.create_monitoring_dashboard ? google_monitoring_dashboard.nat_dashboard[0].id : null
}

# Log Sink Outputs
output "log_sink_id" {
  description = "ID of the log sink"
  value       = var.enable_log_export ? google_logging_project_sink.nat_logs[0].id : null
}

output "log_sink_destination" {
  description = "Destination of the log sink"
  value       = var.enable_log_export ? google_logging_project_sink.nat_logs[0].destination : null
}

output "log_sink_writer_identity" {
  description = "Writer identity for the log sink"
  value       = var.enable_log_export ? google_logging_project_sink.nat_logs[0].writer_identity : null
}

# Log Metrics Outputs
output "log_metric_ids" {
  description = "IDs of created log-based metrics"
  value = {
    for k, v in google_logging_metric.nat_metrics : k => v.id
  }
}

output "log_metric_names" {
  description = "Names of created log-based metrics"
  value = {
    for k, v in google_logging_metric.nat_metrics : k => v.name
  }
}

# NAT Configuration Summary
output "nat_configuration_summary" {
  description = "Summary of NAT configuration"
  value = {
    total_routers      = length(local.cloud_routers)
    total_nat_gateways = length(local.nat_gateways)
    total_nat_ips      = length(local.nat_ips)
    total_interfaces   = length(local.router_interfaces)
    total_bgp_peers    = length(local.bgp_peers)

    nat_gateways_by_type = {
      auto_ip   = length([for k, v in local.nat_gateways : k if v.nat_ip_allocate_option == "AUTO_ONLY" || v.nat_ip_allocate_option == null])
      manual_ip = length([for k, v in local.nat_gateways : k if v.nat_ip_allocate_option == "MANUAL_ONLY"])
    }

    nat_gateways_by_subnet_config = {
      all_subnets = length([
        for k, v in local.nat_gateways : k
        if v.source_subnetwork_ip_ranges_to_nat == "ALL_SUBNETWORKS_ALL_IP_RANGES" || v.source_subnetwork_ip_ranges_to_nat == null
      ])
      all_primary = length([
        for k, v in local.nat_gateways : k
        if v.source_subnetwork_ip_ranges_to_nat == "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES"
      ])
      specific_subnets = length([
        for k, v in local.nat_gateways : k
        if v.source_subnetwork_ip_ranges_to_nat == "LIST_OF_SUBNETWORKS"
      ])
    }

    logging_enabled         = length([for k, v in local.nat_gateways : k if v.enable_logging != false])
    dynamic_port_allocation = length([for k, v in local.nat_gateways : k if v.enable_dynamic_port_allocation == true])
  }
}

# Router Configuration Summary
output "router_configuration_summary" {
  description = "Summary of router configuration"
  value = {
    routers_with_bgp = length([for k, v in local.cloud_routers : k if v.bgp_config != null])
    routers_by_region = {
      for region in distinct([for v in local.cloud_routers : v.region]) :
      region => length([
        for k, v in local.cloud_routers : k
        if v.region == region
      ])
    }
    encrypted_interconnect_routers = length([for k, v in local.cloud_routers : k if v.encrypted_interconnect_router == true])
  }
}

# BGP Configuration Summary
output "bgp_configuration_summary" {
  description = "Summary of BGP configuration"
  value = {
    total_bgp_peers     = length(local.bgp_peers)
    bgp_peers_enabled   = length([for k, v in local.bgp_peers : k if v.enable != false])
    bgp_peers_with_bfd  = length([for k, v in local.bgp_peers : k if v.bfd_config != null])
    bgp_peers_with_ipv6 = length([for k, v in local.bgp_peers : k if v.enable_ipv6 == true])
  }
}

# Network Configuration Summary
output "network_configuration_summary" {
  description = "Summary of network configuration"
  value = {
    total_custom_routes  = length(var.custom_routes)
    total_firewall_rules = length(var.firewall_rules)

    firewall_rules_by_direction = {
      ingress = length([for k, v in var.firewall_rules : k if v.direction == "INGRESS" || v.direction == null])
      egress  = length([for k, v in var.firewall_rules : k if v.direction == "EGRESS"])
    }

    firewall_rules_enabled      = length([for k, v in var.firewall_rules : k if v.disabled != true])
    firewall_rules_with_logging = length([for k, v in var.firewall_rules : k if v.enable_logging != false])
  }
}

# IP Address Summary
output "ip_address_summary" {
  description = "Summary of IP address allocation"
  value = {
    total_nat_ips = length(local.nat_ips)

    ips_by_network_tier = {
      premium  = length([for k, v in local.nat_ips : k if v.network_tier == "PREMIUM" || v.network_tier == null])
      standard = length([for k, v in local.nat_ips : k if v.network_tier == "STANDARD"])
    }

    ips_by_region = {
      for region in distinct([for v in local.nat_ips : v.region != null ? v.region : var.region]) :
      region => length([
        for k, v in local.nat_ips : k
        if(v.region != null ? v.region : var.region) == region
      ])
    }
  }
}

# Port Allocation Summary
output "port_allocation_summary" {
  description = "Summary of port allocation configuration"
  value = {
    for k, v in local.nat_gateways : k => {
      min_ports_per_vm             = v.min_ports_per_vm != null ? v.min_ports_per_vm : 64
      max_ports_per_vm             = v.max_ports_per_vm
      dynamic_port_allocation      = v.enable_dynamic_port_allocation
      endpoint_independent_mapping = v.enable_endpoint_independent_mapping != null ? v.enable_endpoint_independent_mapping : true
    }
  }
}

# Timeout Configuration Summary
output "timeout_configuration_summary" {
  description = "Summary of NAT timeout configuration"
  value = {
    for k, v in local.nat_gateways : k => {
      icmp_idle_timeout_sec            = v.icmp_idle_timeout_sec != null ? v.icmp_idle_timeout_sec : 30
      tcp_established_idle_timeout_sec = v.tcp_established_idle_timeout_sec != null ? v.tcp_established_idle_timeout_sec : 1200
      tcp_transitory_idle_timeout_sec  = v.tcp_transitory_idle_timeout_sec != null ? v.tcp_transitory_idle_timeout_sec : 30
      tcp_time_wait_timeout_sec        = v.tcp_time_wait_timeout_sec != null ? v.tcp_time_wait_timeout_sec : 120
      udp_idle_timeout_sec             = v.udp_idle_timeout_sec != null ? v.udp_idle_timeout_sec : 30
    }
  }
}

# Security Configuration Summary
output "security_configuration_summary" {
  description = "Summary of security configuration"
  value = {
    service_account_created = var.create_service_account
    service_account_roles   = var.create_service_account ? var.service_account_roles : []

    firewall_rules_count = length(var.firewall_rules)
    firewall_allow_rules = length([for k, v in var.firewall_rules : k if v.allow != null])
    firewall_deny_rules  = length([for k, v in var.firewall_rules : k if v.deny != null])
  }
}

# Monitoring Configuration Summary
output "monitoring_configuration_summary" {
  description = "Summary of monitoring configuration"
  value = {
    alerts_enabled      = var.create_monitoring_alerts
    dashboard_enabled   = var.create_monitoring_dashboard
    log_export_enabled  = var.enable_log_export
    log_metrics_enabled = var.create_log_metrics

    alert_policies_count = var.create_monitoring_alerts ? length(var.monitoring_alerts) : 0
    log_metrics_count    = var.create_log_metrics ? length(var.log_metrics) : 0

    nat_gateways_with_logging = length([for k, v in local.nat_gateways : k if v.enable_logging != false])
  }
}

# Connection Information
output "connection_info" {
  description = "Connection information for NAT resources"
  value = {
    project_id = var.project_id
    region     = var.region

    routers = {
      for k, v in google_compute_router.routers : k => {
        id        = v.id
        name      = v.name
        network   = v.network
        region    = v.region
        self_link = v.self_link
      }
    }

    nat_gateways = {
      for k, v in google_compute_router_nat.nat_gateways : k => {
        id     = v.id
        name   = v.name
        router = v.router
        region = v.region
      }
    }

    nat_ips = {
      for k, v in google_compute_address.nat_ips : k => {
        address      = v.address
        name         = v.name
        network_tier = v.network_tier
        self_link    = v.self_link
      }
    }
  }
  sensitive = false
}

# Module Metadata
output "module_configuration" {
  description = "Module configuration summary"
  value = {
    project_id              = var.project_id
    region                  = var.region
    environment             = local.environment
    name_prefix             = local.name_prefix
    service_account_created = var.create_service_account
    monitoring_enabled      = var.create_monitoring_alerts
    dashboard_created       = var.create_monitoring_dashboard
    log_export_enabled      = var.enable_log_export
  }
}

# Labels
output "applied_labels" {
  description = "Labels applied to resources"
  value       = local.default_labels
}

# Resource Counts
output "resource_counts" {
  description = "Count of each resource type created"
  value = {
    cloud_routers     = length(var.cloud_routers)
    nat_gateways      = length(var.nat_gateways)
    nat_ip_addresses  = length(var.nat_ip_addresses)
    router_interfaces = length(var.router_interfaces)
    bgp_peers         = length(var.bgp_peers)
    custom_routes     = length(var.custom_routes)
    firewall_rules    = length(var.firewall_rules)
    service_accounts  = var.create_service_account ? 1 : 0
    alert_policies    = var.create_monitoring_alerts ? length(var.monitoring_alerts) : 0
    dashboards        = var.create_monitoring_dashboard ? 1 : 0
    log_sinks         = var.enable_log_export ? 1 : 0
    log_metrics       = var.create_log_metrics ? length(var.log_metrics) : 0
  }
}