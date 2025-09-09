output "nat_id" {
  description = "The ID of the Cloud NAT"
  value       = google_compute_router_nat.nat.id
}

output "nat_name" {
  description = "The name of the Cloud NAT"
  value       = google_compute_router_nat.nat.name
}

output "nat_ip_addresses" {
  description = "The external IP addresses used by the NAT"
  value = var.nat_ip_allocate_option == "MANUAL_ONLY" ? (
    length(var.nat_ips) > 0 ? var.nat_ips : google_compute_address.nat_ip[*].address
  ) : []
}

output "nat_ip_self_links" {
  description = "The self links of external IP addresses used by the NAT"
  value = var.nat_ip_allocate_option == "MANUAL_ONLY" ? (
    length(var.nat_ips) > 0 ? var.nat_ips : google_compute_address.nat_ip[*].self_link
  ) : []
}

output "router_name" {
  description = "The name of the router to which the NAT is attached"
  value       = var.router_name
}

output "region" {
  description = "The region of the NAT"
  value       = var.region
}