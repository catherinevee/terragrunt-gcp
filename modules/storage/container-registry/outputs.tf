# Container Registry Module Outputs

output "repository_ids" {
  description = "Map of repository names to their IDs"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.id
  }
}

output "repository_names" {
  description = "List of created repository names"
  value = [
    for repo in google_artifact_registry_repository.repositories : repo.name
  ]
}

output "repository_locations" {
  description = "Map of repository names to their locations"
  value = {
    for k, v in google_artifact_registry_repository.repositories : k => v.location
  }
}

output "iam_binding_ids" {
  description = "Map of IAM binding keys to their IDs"
  value = {
    for k, v in google_artifact_registry_repository_iam_binding.repository_iam_bindings : k => v.id
  }
}

output "project_id" {
  description = "The project ID where repositories are created"
  value       = var.project_id
}