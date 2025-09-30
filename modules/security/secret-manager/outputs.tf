# Secret Manager Module Outputs

output "secret_ids" {
  description = "Map of secret names to their IDs"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => v.id
  }
}

output "secret_names" {
  description = "List of created secret names"
  value = [
    for secret in google_secret_manager_secret.secrets : secret.name
  ]
}

output "secret_version_ids" {
  description = "Map of secret version names to their IDs"
  value = {
    for k, v in google_secret_manager_secret_version.secret_versions : k => v.id
  }
}

output "iam_binding_ids" {
  description = "Map of IAM binding keys to their IDs"
  value = {
    for k, v in google_secret_manager_secret_iam_binding.secret_iam_bindings : k => v.id
  }
}

output "project_id" {
  description = "The project where secrets are stored"
  value       = var.project_id
}