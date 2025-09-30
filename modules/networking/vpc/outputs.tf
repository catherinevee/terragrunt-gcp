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

output "project_id" {
  description = "The project ID of the VPC network"
  value       = var.project_id
}

output "auto_create_subnetworks" {
  description = "Whether auto-create subnetworks is enabled"
  value       = google_compute_network.vpc_network.auto_create_subnetworks
}

output "routing_mode" {
  description = "The network-wide routing mode"
  value       = google_compute_network.vpc_network.routing_mode
}