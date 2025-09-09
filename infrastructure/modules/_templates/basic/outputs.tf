output "id" {
  description = "Resource ID"
  value       = google_${resource_type}.this.id
}

output "name" {
  description = "Resource name"
  value       = google_${resource_type}.this.name
}
