# VPC Module Outputs

output "network_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.vpc.id
}

output "network_self_link" {
  description = "The URI of the VPC network"
  value       = google_compute_network.vpc.self_link
}

output "network_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.vpc.name
}

output "subnets" {
  description = "Map of subnet names to subnet objects"
  value       = google_compute_subnetwork.subnets
}

output "subnet_ids" {
  description = "Map of subnet names to subnet IDs"
  value = {
    for k, v in google_compute_subnetwork.subnets : k => v.id
  }
}

output "subnet_self_links" {
  description = "Map of subnet names to subnet self links"
  value = {
    for k, v in google_compute_subnetwork.subnets : k => v.self_link
  }
}

output "subnet_ips" {
  description = "Map of subnet names to subnet IP ranges"
  value = {
    for k, v in google_compute_subnetwork.subnets : k => v.ip_cidr_range
  }
}

output "subnet_regions" {
  description = "Map of subnet names to regions"
  value = {
    for k, v in google_compute_subnetwork.subnets : k => v.region
  }
}

output "subnet_secondary_ranges" {
  description = "Map of subnet names to secondary ranges"
  value = {
    for k, v in google_compute_subnetwork.subnets : k => v.secondary_ip_range
  }
}

output "router_id" {
  description = "The ID of the Cloud Router"
  value       = var.enable_cloud_nat ? google_compute_router.router[0].id : null
}

output "router_self_link" {
  description = "The URI of the Cloud Router"
  value       = var.enable_cloud_nat ? google_compute_router.router[0].self_link : null
}

output "nat_id" {
  description = "The ID of the Cloud NAT"
  value       = var.enable_cloud_nat ? google_compute_router_nat.nat[0].id : null
}

output "vpc_connector_id" {
  description = "The ID of the VPC connector"
  value       = var.enable_vpc_connector ? google_vpc_access_connector.connector[0].id : null
}

output "vpc_connector_self_link" {
  description = "The URI of the VPC connector"
  value       = var.enable_vpc_connector ? google_vpc_access_connector.connector[0].self_link : null
}

output "private_service_connection_ip" {
  description = "The IP address of the private service connection"
  value       = var.enable_private_service_connection ? google_compute_global_address.private_service_connection[0].address : null
}

output "firewall_rules" {
  description = "Map of firewall rule names to firewall rule objects"
  value       = google_compute_firewall.rules
}