output "subnet_ids" {
  description = "Map of subnet names to their IDs"
  value       = { for k, v in google_compute_subnetwork.subnet : k => v.id }
}

output "subnet_self_links" {
  description = "Map of subnet names to their self links"
  value       = { for k, v in google_compute_subnetwork.subnet : k => v.self_link }
}

output "subnet_names" {
  description = "List of all subnet names"
  value       = [for subnet in google_compute_subnetwork.subnet : subnet.name]
}

output "subnet_ip_ranges" {
  description = "Map of subnet names to their primary IP ranges"
  value       = { for k, v in google_compute_subnetwork.subnet : k => v.ip_cidr_range }
}

output "subnet_secondary_ranges" {
  description = "Map of subnet names to their secondary IP ranges"
  value = {
    for k, v in google_compute_subnetwork.subnet : k => [
      for range in v.secondary_ip_range : {
        range_name    = range.range_name
        ip_cidr_range = range.ip_cidr_range
      }
    ]
  }
}

output "subnet_regions" {
  description = "Map of subnet names to their regions"
  value       = { for k, v in google_compute_subnetwork.subnet : k => v.region }
}

output "router_id" {
  description = "The ID of the Cloud Router (if created)"
  value       = try(google_compute_router.router[0].id, null)
}

output "router_self_link" {
  description = "The self link of the Cloud Router (if created)"
  value       = try(google_compute_router.router[0].self_link, null)
}

output "private_subnets" {
  description = "Map of private subnet names to their details"
  value = {
    for k, v in google_compute_subnetwork.subnet : k => {
      id            = v.id
      self_link     = v.self_link
      ip_cidr_range = v.ip_cidr_range
      region        = v.region
    } if v.private_ip_google_access == true
  }
}

output "public_subnets" {
  description = "Map of public subnet names to their details"
  value = {
    for k, v in google_compute_subnetwork.subnet : k => {
      id            = v.id
      self_link     = v.self_link
      ip_cidr_range = v.ip_cidr_range
      region        = v.region
    } if v.private_ip_google_access == false
  }
}