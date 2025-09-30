# DNS Module Outputs

output "zone_id" {
  description = "The unique identifier for the managed zone"
  value       = google_dns_managed_zone.dns_zone.id
}

output "zone_name" {
  description = "The DNS name of the managed zone"
  value       = google_dns_managed_zone.dns_zone.dns_name
}

output "zone_name_servers" {
  description = "The list of name servers for the managed zone"
  value       = google_dns_managed_zone.dns_zone.name_servers
}

output "record_set_ids" {
  description = "Map of record set names to their identifiers"
  value = {
    for k, v in google_dns_record_set.records : k => v.id
  }
}

output "record_set_names" {
  description = "List of all DNS record set names"
  value = [
    for record in google_dns_record_set.records : record.name
  ]
}

output "project_id" {
  description = "The project where the DNS zone is created"
  value       = var.project_id
}