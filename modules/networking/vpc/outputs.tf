# VPC Network Module Outputs

output "network_id" {
  description = "The unique identifier for the VPC network"
  value       = google_compute_network.vpc_network.id
}

output "network_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.vpc_network.name
}

output "network_self_link" {
  description = "The URI of the VPC network"
  value       = google_compute_network.vpc_network.self_link
}

output "network_gateway_ipv4" {
  description = "The gateway address for default routing out of the network"
  value       = google_compute_network.vpc_network.gateway_ipv4
}

output "network_project" {
  description = "The project ID of the VPC network"
  value       = google_compute_network.vpc_network.project
}

output "subnet_ids" {
  description = "Map of subnet names to their unique identifiers"
  value = {
    for k, v in google_compute_subnetwork.subnets : k => v.id
  }
}

output "subnet_names" {
  description = "List of names of subnets created"
  value = [
    for subnet in google_compute_subnetwork.subnets : subnet.name
  ]
}

output "subnet_self_links" {
  description = "Map of subnet names to their self links"
  value = {
    for k, v in google_compute_subnetwork.subnets : k => v.self_link
  }
}

output "subnet_ip_cidr_ranges" {
  description = "Map of subnet names to their primary IP CIDR ranges"
  value = {
    for k, v in google_compute_subnetwork.subnets : k => v.ip_cidr_range
  }
}

output "subnet_regions" {
  description = "Map of subnet names to their regions"
  value = {
    for k, v in google_compute_subnetwork.subnets : k => v.region
  }
}

output "subnet_gateway_addresses" {
  description = "Map of subnet names to their gateway addresses"
  value = {
    for k, v in google_compute_subnetwork.subnets : k => v.gateway_address
  }
}

output "subnet_secondary_ranges" {
  description = "Map of subnet names to their secondary IP ranges"
  value = {
    for k, v in google_compute_subnetwork.subnets : k => [
      for range in v.secondary_ip_range : {
        range_name    = range.range_name
        ip_cidr_range = range.ip_cidr_range
      }
    ]
  }
}

output "subnet_private_ip_google_access" {
  description = "Map of subnet names to their private Google access status"
  value = {
    for k, v in google_compute_subnetwork.subnets : k => v.private_ip_google_access
  }
}

output "subnet_private_ipv6_google_access" {
  description = "Map of subnet names to their private IPv6 Google access status"
  value = {
    for k, v in google_compute_subnetwork.subnets : k => v.private_ipv6_google_access
  }
}

output "subnet_flow_logs_enabled" {
  description = "Map of subnet names to their flow logs enablement status"
  value = {
    for k, v in google_compute_subnetwork.subnets : k => length(v.log_config) > 0
  }
}

output "router_ids" {
  description = "Map of router names to their unique identifiers"
  value = {
    for k, v in google_compute_router.routers : k => v.id
  }
}

output "router_names" {
  description = "List of names of routers created"
  value = [
    for router in google_compute_router.routers : router.name
  ]
}

output "router_self_links" {
  description = "Map of router names to their self links"
  value = {
    for k, v in google_compute_router.routers : k => v.self_link
  }
}

output "router_regions" {
  description = "Map of router names to their regions"
  value = {
    for k, v in google_compute_router.routers : k => v.region
  }
}

output "nat_ids" {
  description = "Map of Cloud NAT names to their unique identifiers"
  value = {
    for k, v in google_compute_router_nat.nats : k => v.id
  }
}

output "nat_names" {
  description = "List of names of Cloud NAT gateways created"
  value = [
    for nat in google_compute_router_nat.nats : nat.name
  ]
}

output "nat_ips" {
  description = "Map of Cloud NAT names to their external IP addresses"
  value = {
    for k, v in google_compute_router_nat.nats : k => v.nat_ips
  }
}

output "nat_router_associations" {
  description = "Map of Cloud NAT names to their associated routers"
  value = {
    for k, v in google_compute_router_nat.nats : k => v.router
  }
}

output "firewall_rule_ids" {
  description = "Map of firewall rule names to their unique identifiers"
  value = {
    for k, v in google_compute_firewall.rules : k => v.id
  }
}

output "firewall_rule_names" {
  description = "List of names of firewall rules created"
  value = [
    for rule in google_compute_firewall.rules : rule.name
  ]
}

output "firewall_rule_self_links" {
  description = "Map of firewall rule names to their self links"
  value = {
    for k, v in google_compute_firewall.rules : k => v.self_link
  }
}

output "route_ids" {
  description = "Map of route names to their unique identifiers"
  value = {
    for k, v in google_compute_route.routes : k => v.id
  }
}

output "route_names" {
  description = "List of names of routes created"
  value = [
    for route in google_compute_route.routes : route.name
  ]
}

output "route_next_hops" {
  description = "Map of route names to their next hop information"
  value = {
    for k, v in google_compute_route.routes : k => {
      next_hop_gateway   = v.next_hop_gateway
      next_hop_instance  = v.next_hop_instance
      next_hop_ip        = v.next_hop_ip
      next_hop_vpn_tunnel = v.next_hop_vpn_tunnel
      next_hop_ilb       = v.next_hop_ilb
    }
  }
}

output "peering_connections" {
  description = "List of VPC Network Peering connections"
  value = [
    for peering in google_compute_network_peering.peerings : {
      name                                = peering.name
      peer_network                        = peering.peer_network
      state                               = peering.state
      state_details                       = peering.state_details
      auto_create_routes                  = peering.export_custom_routes
      export_custom_routes                = peering.export_custom_routes
      import_custom_routes                = peering.import_custom_routes
      export_subnet_routes_with_public_ip = peering.export_subnet_routes_with_public_ip
      import_subnet_routes_with_public_ip = peering.import_subnet_routes_with_public_ip
    }
  ]
}

output "shared_vpc_host_project" {
  description = "Shared VPC host project ID if configured"
  value       = var.shared_vpc_host ? var.project_id : ""
}

output "shared_vpc_service_projects" {
  description = "List of service projects attached to the Shared VPC"
  value       = var.shared_vpc_service_projects
}

output "private_service_connection" {
  description = "Private Service Connection details"
  value = {
    network                = try(google_compute_global_address.private_service_connection[0].network, "")
    address                = try(google_compute_global_address.private_service_connection[0].address, "")
    prefix_length          = try(google_compute_global_address.private_service_connection[0].prefix_length, 0)
    peering                = try(google_service_networking_connection.private_service_connection[0].peering, "")
    reserved_peering_ranges = try(google_service_networking_connection.private_service_connection[0].reserved_peering_ranges, [])
  }
}

output "network_attachment_ids" {
  description = "Map of network attachment names to their IDs"
  value = {
    for k, v in google_compute_network_attachment.attachments : k => v.id
  }
}

output "interconnect_attachments" {
  description = "Map of interconnect attachment details"
  value = {
    for k, v in google_compute_interconnect_attachment.attachments : k => {
      id                   = v.id
      self_link            = v.self_link
      cloud_router_ip_address = v.cloud_router_ip_address
      customer_router_ip_address = v.customer_router_ip_address
      pairing_key          = v.pairing_key
      partner_asn          = v.partner_asn
      state                = v.state
      vlan_tag8021q        = v.vlan_tag8021q
    }
  }
}

output "vpn_gateway_ids" {
  description = "Map of VPN gateway names to their IDs"
  value = {
    for k, v in google_compute_vpn_gateway.gateways : k => v.id
  }
}

output "vpn_tunnel_ids" {
  description = "Map of VPN tunnel names to their IDs"
  value = {
    for k, v in google_compute_vpn_tunnel.tunnels : k => v.id
  }
}

output "network_connectivity_hub_id" {
  description = "Network Connectivity Center hub ID if configured"
  value       = try(google_network_connectivity_hub.hub[0].id, "")
}

output "network_connectivity_spokes" {
  description = "Map of Network Connectivity Center spoke details"
  value = {
    for k, v in google_network_connectivity_spoke.spokes : k => {
      id          = v.id
      hub         = v.hub
      location    = v.location
      state       = v.state
      unique_id   = v.unique_id
    }
  }
}

output "dns_policies" {
  description = "Map of DNS policy details for the network"
  value = {
    for k, v in google_dns_policy.policies : k => {
      id                            = v.id
      enable_inbound_forwarding     = v.enable_inbound_forwarding
      enable_logging                = v.enable_logging
    }
  }
}

output "network_tags" {
  description = "Network tags used for firewall rules"
  value       = var.network_tags
}

output "auto_create_subnetworks" {
  description = "Whether auto-create subnetworks is enabled"
  value       = google_compute_network.vpc_network.auto_create_subnetworks
}

output "routing_mode" {
  description = "The network-wide routing mode"
  value       = google_compute_network.vpc_network.routing_mode
}

output "mtu" {
  description = "Maximum transmission unit in bytes"
  value       = google_compute_network.vpc_network.mtu
}

output "delete_default_routes" {
  description = "Whether default routes were deleted on network creation"
  value       = google_compute_network.vpc_network.delete_default_routes_on_create
}

output "enable_ula_internal_ipv6" {
  description = "Whether ULA internal IPv6 is enabled on the network"
  value       = google_compute_network.vpc_network.enable_ula_internal_ipv6
}

output "internal_ipv6_range" {
  description = "ULA internal IPv6 range assigned to the network"
  value       = google_compute_network.vpc_network.internal_ipv6_range
}