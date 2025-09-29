# VPN Module Outputs

# HA VPN Gateway Outputs
output "ha_vpn_gateway_ids" {
  description = "The identifiers for HA VPN gateways"
  value = {
    for k, v in google_compute_ha_vpn_gateway.ha_gateways : k => v.id
  }
}

output "ha_vpn_gateway_names" {
  description = "The names of HA VPN gateways"
  value = {
    for k, v in google_compute_ha_vpn_gateway.ha_gateways : k => v.name
  }
}

output "ha_vpn_gateway_self_links" {
  description = "The self links of HA VPN gateways"
  value = {
    for k, v in google_compute_ha_vpn_gateway.ha_gateways : k => v.self_link
  }
}

output "ha_vpn_gateway_vpn_interfaces" {
  description = "The VPN interfaces of HA VPN gateways"
  value = {
    for k, v in google_compute_ha_vpn_gateway.ha_gateways : k => v.vpn_interfaces
  }
}

# Classic VPN Gateway Outputs
output "classic_vpn_gateway_ids" {
  description = "The identifiers for classic VPN gateways"
  value = {
    for k, v in google_compute_vpn_gateway.classic_gateways : k => v.id
  }
}

output "classic_vpn_gateway_names" {
  description = "The names of classic VPN gateways"
  value = {
    for k, v in google_compute_vpn_gateway.classic_gateways : k => v.name
  }
}

output "classic_vpn_gateway_self_links" {
  description = "The self links of classic VPN gateways"
  value = {
    for k, v in google_compute_vpn_gateway.classic_gateways : k => v.self_link
  }
}

output "classic_vpn_gateway_creation_timestamps" {
  description = "The creation timestamps of classic VPN gateways"
  value = {
    for k, v in google_compute_vpn_gateway.classic_gateways : k => v.creation_timestamp
  }
}

# External VPN Gateway Outputs
output "external_vpn_gateway_ids" {
  description = "The identifiers for external VPN gateways"
  value = {
    for k, v in google_compute_external_vpn_gateway.external_gateways : k => v.id
  }
}

output "external_vpn_gateway_names" {
  description = "The names of external VPN gateways"
  value = {
    for k, v in google_compute_external_vpn_gateway.external_gateways : k => v.name
  }
}

output "external_vpn_gateway_self_links" {
  description = "The self links of external VPN gateways"
  value = {
    for k, v in google_compute_external_vpn_gateway.external_gateways : k => v.self_link
  }
}

output "external_vpn_gateway_redundancy_types" {
  description = "The redundancy types of external VPN gateways"
  value = {
    for k, v in google_compute_external_vpn_gateway.external_gateways : k => v.redundancy_type
  }
}

# VPN Tunnel Outputs
output "vpn_tunnel_ids" {
  description = "The identifiers for VPN tunnels"
  value = {
    for k, v in google_compute_vpn_tunnel.vpn_tunnels : k => v.id
  }
}

output "vpn_tunnel_names" {
  description = "The names of VPN tunnels"
  value = {
    for k, v in google_compute_vpn_tunnel.vpn_tunnels : k => v.name
  }
}

output "vpn_tunnel_self_links" {
  description = "The self links of VPN tunnels"
  value = {
    for k, v in google_compute_vpn_tunnel.vpn_tunnels : k => v.self_link
  }
}

output "vpn_tunnel_creation_timestamps" {
  description = "The creation timestamps of VPN tunnels"
  value = {
    for k, v in google_compute_vpn_tunnel.vpn_tunnels : k => v.creation_timestamp
  }
}

output "vpn_tunnel_tunnel_ids" {
  description = "The tunnel IDs of VPN tunnels"
  value = {
    for k, v in google_compute_vpn_tunnel.vpn_tunnels : k => v.tunnel_id
  }
}

output "vpn_tunnel_gateway_ips" {
  description = "The gateway IP addresses of VPN tunnels"
  value = {
    for k, v in google_compute_vpn_tunnel.vpn_tunnels : k => v.gateway_ip
  }
}

output "vpn_tunnel_peer_ips" {
  description = "The peer IP addresses of VPN tunnels"
  value = {
    for k, v in google_compute_vpn_tunnel.vpn_tunnels : k => v.peer_ip
  }
}

output "vpn_tunnel_ike_versions" {
  description = "The IKE versions of VPN tunnels"
  value = {
    for k, v in google_compute_vpn_tunnel.vpn_tunnels : k => v.ike_version
  }
}

output "vpn_tunnel_detailed_statuses" {
  description = "The detailed statuses of VPN tunnels"
  value = {
    for k, v in google_compute_vpn_tunnel.vpn_tunnels : k => v.detailed_status
  }
}

output "vpn_tunnel_shared_secret_hashes" {
  description = "The shared secret hashes of VPN tunnels"
  value = {
    for k, v in google_compute_vpn_tunnel.vpn_tunnels : k => v.shared_secret_hash
  }
}

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

output "router_interface_ip_ranges" {
  description = "The IP ranges of router interfaces"
  value = {
    for k, v in google_compute_router_interface.interfaces : k => v.ip_range
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

output "bgp_peer_peer_ip_addresses" {
  description = "The peer IP addresses of BGP peers"
  value = {
    for k, v in google_compute_router_peer.bgp_peers : k => v.peer_ip_address
  }
}

output "bgp_peer_peer_asns" {
  description = "The peer ASNs of BGP peers"
  value = {
    for k, v in google_compute_router_peer.bgp_peers : k => v.peer_asn
  }
}

output "bgp_peer_management_types" {
  description = "The management types of BGP peers"
  value = {
    for k, v in google_compute_router_peer.bgp_peers : k => v.management_type
  }
}

# Static Route Outputs
output "static_route_ids" {
  description = "The identifiers for static routes"
  value = {
    for k, v in google_compute_route.vpn_routes : k => v.id
  }
}

output "static_route_names" {
  description = "The names of static routes"
  value = {
    for k, v in google_compute_route.vpn_routes : k => v.name
  }
}

output "static_route_self_links" {
  description = "The self links of static routes"
  value = {
    for k, v in google_compute_route.vpn_routes : k => v.self_link
  }
}

output "static_route_dest_ranges" {
  description = "The destination ranges of static routes"
  value = {
    for k, v in google_compute_route.vpn_routes : k => v.dest_range
  }
}

output "static_route_next_hop_vpn_tunnels" {
  description = "The next hop VPN tunnels of static routes"
  value = {
    for k, v in google_compute_route.vpn_routes : k => v.next_hop_vpn_tunnel
  }
}

# Firewall Rule Outputs
output "firewall_rule_ids" {
  description = "The identifiers for firewall rules"
  value = {
    for k, v in google_compute_firewall.vpn_firewall_rules : k => v.id
  }
}

output "firewall_rule_names" {
  description = "The names of firewall rules"
  value = {
    for k, v in google_compute_firewall.vpn_firewall_rules : k => v.name
  }
}

output "firewall_rule_self_links" {
  description = "The self links of firewall rules"
  value = {
    for k, v in google_compute_firewall.vpn_firewall_rules : k => v.self_link
  }
}

output "firewall_rule_creation_timestamps" {
  description = "The creation timestamps of firewall rules"
  value = {
    for k, v in google_compute_firewall.vpn_firewall_rules : k => v.creation_timestamp
  }
}

# Reserved IP Address Outputs
output "reserved_ip_addresses" {
  description = "The reserved IP addresses"
  value = {
    for k, v in google_compute_address.vpn_gateway_ips : k => v.address
  }
}

output "reserved_ip_ids" {
  description = "The identifiers for reserved IP addresses"
  value = {
    for k, v in google_compute_address.vpn_gateway_ips : k => v.id
  }
}

output "reserved_ip_names" {
  description = "The names of reserved IP addresses"
  value = {
    for k, v in google_compute_address.vpn_gateway_ips : k => v.name
  }
}

output "reserved_ip_self_links" {
  description = "The self links of reserved IP addresses"
  value = {
    for k, v in google_compute_address.vpn_gateway_ips : k => v.self_link
  }
}

output "reserved_ip_users" {
  description = "The resources using reserved IP addresses"
  value = {
    for k, v in google_compute_address.vpn_gateway_ips : k => v.users
    if length(v.users) > 0
  }
}

# Service Account Outputs
output "service_account_email" {
  description = "The email of the created service account"
  value       = var.create_service_account ? google_service_account.vpn[0].email : null
}

output "service_account_id" {
  description = "The unique id of the service account"
  value       = var.create_service_account ? google_service_account.vpn[0].unique_id : null
}

output "service_account_name" {
  description = "The fully-qualified name of the service account"
  value       = var.create_service_account ? google_service_account.vpn[0].name : null
}

output "service_account_member" {
  description = "The IAM member format for the service account"
  value       = var.create_service_account ? "serviceAccount:${google_service_account.vpn[0].email}" : null
}

# Monitoring Outputs
output "monitoring_alert_policy_ids" {
  description = "IDs of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.vpn_alerts : k => v.id
  }
}

output "monitoring_alert_policy_names" {
  description = "Names of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.vpn_alerts : k => v.name
  }
}

output "monitoring_dashboard_id" {
  description = "ID of the monitoring dashboard"
  value       = var.create_monitoring_dashboard ? google_monitoring_dashboard.vpn_dashboard[0].id : null
}

# Log Metrics Outputs
output "log_metric_ids" {
  description = "IDs of created log-based metrics"
  value = {
    for k, v in google_logging_metric.vpn_metrics : k => v.id
  }
}

output "log_metric_names" {
  description = "Names of created log-based metrics"
  value = {
    for k, v in google_logging_metric.vpn_metrics : k => v.name
  }
}

# Secret Manager Outputs (for shared secrets)
output "vpn_secret_ids" {
  description = "IDs of VPN secrets in Secret Manager"
  value = {
    for k, v in google_secret_manager_secret.vpn_secrets : k => v.id
  }
  sensitive = true
}

output "vpn_secret_names" {
  description = "Names of VPN secrets in Secret Manager"
  value = {
    for k, v in google_secret_manager_secret.vpn_secrets : k => v.secret_id
  }
}

# VPN Configuration Summary
output "vpn_configuration_summary" {
  description = "Summary of VPN configuration"
  value = {
    total_ha_gateways       = length(local.ha_vpn_gateways)
    total_classic_gateways  = length(local.classic_vpn_gateways)
    total_external_gateways = length(local.external_vpn_gateways)
    total_vpn_tunnels       = length(local.vpn_tunnels)
    total_routers           = length(local.routers)
    total_bgp_peers         = length(local.bgp_peers)

    gateways_by_type = {
      ha_vpn   = length(local.ha_vpn_gateways)
      classic  = length(local.classic_vpn_gateways)
      external = length(local.external_vpn_gateways)
    }

    tunnels_by_ike_version = {
      ikev1 = length([for k, v in local.vpn_tunnels : k if v.ike_version == 1])
      ikev2 = length([for k, v in local.vpn_tunnels : k if v.ike_version == 2 || v.ike_version == null])
    }

    tunnels_with_bgp = length([for k, v in local.vpn_tunnels : k if v.router != null || v.router_key != null])
  }
}

# Router Configuration Summary
output "router_configuration_summary" {
  description = "Summary of router configuration"
  value = {
    total_routers    = length(local.routers)
    total_interfaces = length(local.router_interfaces)
    total_bgp_peers  = length(local.bgp_peers)

    routers_with_bgp = length([for k, v in local.routers : k if v.bgp_config != null])

    routers_by_region = {
      for region in distinct([for v in local.routers : v.region != null ? v.region : var.region]) :
      region => length([
        for k, v in local.routers : k
        if(v.region != null ? v.region : var.region) == region
      ])
    }

    bgp_peers_enabled  = length([for k, v in local.bgp_peers : k if v.enable != false])
    bgp_peers_with_bfd = length([for k, v in local.bgp_peers : k if v.bfd_config != null])
    bgp_peers_with_md5 = length([for k, v in local.bgp_peers : k if v.md5_authentication_key != null])
  }
}

# Redundancy Configuration Summary
output "redundancy_configuration_summary" {
  description = "Summary of redundancy configuration"
  value = {
    ha_vpn_interfaces = {
      for k, v in google_compute_ha_vpn_gateway.ha_gateways : k => length(v.vpn_interfaces)
    }

    external_gateway_redundancy = {
      for k, v in local.external_vpn_gateways : k => v.redundancy_type != null ? v.redundancy_type : "SINGLE_IP_INTERNALLY_REDUNDANT"
    }

    tunnel_pairs = length([
      for k, v in local.vpn_tunnels : k
      if v.vpn_gateway_interface != null && v.peer_external_gateway_interface != null
    ])
  }
}

# Network Configuration Summary
output "network_configuration_summary" {
  description = "Summary of network configuration"
  value = {
    total_static_routes  = length(var.static_routes)
    total_firewall_rules = length(var.firewall_rules)
    total_reserved_ips   = length(var.reserved_ip_addresses)

    firewall_rules_by_direction = {
      ingress = length([for k, v in var.firewall_rules : k if v.direction == "INGRESS" || v.direction == null])
      egress  = length([for k, v in var.firewall_rules : k if v.direction == "EGRESS"])
    }

    firewall_rules_enabled      = length([for k, v in var.firewall_rules : k if v.disabled != true])
    firewall_rules_with_logging = length([for k, v in var.firewall_rules : k if v.enable_logging != false])

    reserved_ips_by_tier = {
      premium  = length([for k, v in var.reserved_ip_addresses : k if v.network_tier == "PREMIUM" || v.network_tier == null])
      standard = length([for k, v in var.reserved_ip_addresses : k if v.network_tier == "STANDARD"])
    }
  }
}

# High Availability Summary
output "ha_configuration_summary" {
  description = "Summary of high availability configuration"
  value = {
    ha_enabled               = var.ha_vpn_config.enable_ha
    ha_interfaces_count      = var.ha_vpn_config.ha_vpn_interfaces_count
    auto_failover_enabled    = var.ha_vpn_config.enable_auto_failover
    failover_timeout_seconds = var.ha_vpn_config.failover_timeout_seconds
    path_mtu_discovery       = var.ha_vpn_config.enable_path_mtu_discovery
    mtu_size                 = var.ha_vpn_config.mtu_size
  }
}

# Performance Configuration Summary
output "performance_configuration_summary" {
  description = "Summary of performance configuration"
  value = {
    accelerated_networking = var.performance_config.enable_accelerated_networking
    tcp_optimization       = var.performance_config.enable_tcp_optimization
    tcp_mss_clamping       = var.performance_config.tcp_mss_clamping
    jumbo_frames_enabled   = var.performance_config.enable_jumbo_frames
    jumbo_frame_size       = var.performance_config.jumbo_frame_size
    qos_enabled            = var.performance_config.enable_qos
    qos_bandwidth_mbps     = var.performance_config.qos_bandwidth_mbps
  }
}

# Security Configuration Summary
output "security_configuration_summary" {
  description = "Summary of security configuration"
  value = {
    service_account_created = var.create_service_account
    service_account_roles   = var.create_service_account ? var.service_account_roles : []

    perfect_forward_secrecy = var.security_config.enable_perfect_forward_secrecy
    pfs_group               = var.security_config.pfs_group
    replay_protection       = var.security_config.enable_replay_protection
    anti_ddos_enabled       = var.security_config.enable_anti_ddos
    ddos_threshold_pps      = var.security_config.ddos_threshold_pps
    ipsec_encryption        = var.security_config.enable_ipsec_encryption
    ipsec_encryption_algo   = var.security_config.ipsec_encryption_algorithm
    ipsec_integrity_algo    = var.security_config.ipsec_integrity_algorithm
    certificate_auth        = var.security_config.enable_certificate_auth

    secrets_in_secret_manager = var.store_secrets_in_secret_manager
  }
}

# Compliance Configuration Summary
output "compliance_configuration_summary" {
  description = "Summary of compliance configuration"
  value = {
    fips_compliance_enforced   = var.compliance_config.enforce_fips_compliance
    ipsec_encryption_required  = var.compliance_config.require_ipsec_encryption
    audit_logging_enabled      = var.compliance_config.audit_logging_enabled
    connection_logging_enabled = var.compliance_config.enable_connection_logging
    log_retention_days         = var.compliance_config.log_retention_days
    data_residency_regions     = var.compliance_config.data_residency_regions
  }
}

# Disaster Recovery Configuration Summary
output "dr_configuration_summary" {
  description = "Summary of disaster recovery configuration"
  value = {
    backup_tunnels_enabled       = var.dr_config.enable_backup_tunnels
    backup_tunnel_priority       = var.dr_config.backup_tunnel_priority
    automatic_switchover         = var.dr_config.enable_automatic_switchover
    switchover_threshold_seconds = var.dr_config.switchover_threshold_seconds
    tunnel_monitoring_enabled    = var.dr_config.enable_tunnel_monitoring
    monitoring_interval_seconds  = var.dr_config.monitoring_interval_seconds
  }
}

# Monitoring Configuration Summary
output "monitoring_configuration_summary" {
  description = "Summary of monitoring configuration"
  value = {
    alerts_enabled      = var.create_monitoring_alerts
    dashboard_enabled   = var.create_monitoring_dashboard
    log_metrics_enabled = var.create_log_metrics

    alert_policies_count = var.create_monitoring_alerts ? length(var.monitoring_alerts) : 0
    log_metrics_count    = var.create_log_metrics ? length(var.log_metrics) : 0
  }
}

# Connection Information
output "connection_info" {
  description = "Connection information for VPN resources"
  value = {
    project_id = var.project_id
    region     = var.region

    ha_gateways = {
      for k, v in google_compute_ha_vpn_gateway.ha_gateways : k => {
        id         = v.id
        name       = v.name
        network    = v.network
        region     = v.region
        interfaces = v.vpn_interfaces
      }
    }

    vpn_tunnels = {
      for k, v in google_compute_vpn_tunnel.vpn_tunnels : k => {
        id          = v.id
        name        = v.name
        tunnel_id   = v.tunnel_id
        gateway_ip  = v.gateway_ip
        peer_ip     = v.peer_ip
        ike_version = v.ike_version
        status      = v.detailed_status
      }
    }

    bgp_sessions = {
      for k, v in google_compute_router_peer.bgp_peers : k => {
        name            = v.name
        router          = v.router
        peer_ip_address = v.peer_ip_address
        peer_asn        = v.peer_asn
        ip_address      = v.ip_address
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
    secrets_managed         = var.store_secrets_in_secret_manager
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
    ha_vpn_gateways       = length(var.ha_vpn_gateways)
    classic_vpn_gateways  = length(var.classic_vpn_gateways)
    external_vpn_gateways = length(var.external_vpn_gateways)
    vpn_tunnels           = length(var.vpn_tunnels)
    routers               = length(var.routers)
    router_interfaces     = length(var.router_interfaces)
    bgp_peers             = length(var.bgp_peers)
    static_routes         = length(var.static_routes)
    firewall_rules        = length(var.firewall_rules)
    reserved_ips          = length(var.reserved_ip_addresses)
    service_accounts      = var.create_service_account ? 1 : 0
    alert_policies        = var.create_monitoring_alerts ? length(var.monitoring_alerts) : 0
    dashboards            = var.create_monitoring_dashboard ? 1 : 0
    log_metrics           = var.create_log_metrics ? length(var.log_metrics) : 0
    secrets               = var.store_secrets_in_secret_manager ? length(local.vpn_tunnels) : 0
  }
}