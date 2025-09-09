# IAM Module Outputs

output "service_accounts" {
  description = "Map of service account names to their details"
  value = {
    for k, v in google_service_account.service_accounts : k => {
      email       = v.email
      name        = v.name
      unique_id   = v.unique_id
      account_id  = v.account_id
      project     = v.project
    }
  }
}

output "service_account_emails" {
  description = "Map of service account IDs to email addresses"
  value = {
    for k, v in google_service_account.service_accounts : k => v.email
  }
}

output "service_account_keys" {
  description = "Map of service account keys (base64 encoded)"
  value = {
    for k, v in google_service_account_key.keys : k => v.private_key
  }
  sensitive = true
}

output "secret_manager_secret_ids" {
  description = "Map of Secret Manager secret IDs for service account keys"
  value = {
    for k, v in google_secret_manager_secret.sa_keys : k => v.secret_id
  }
}

output "custom_role_ids" {
  description = "Map of custom role IDs"
  value = {
    for k, v in google_project_iam_custom_role.custom_roles : k => v.id
  }
}

output "workload_identity_bindings" {
  description = "Map of Workload Identity bindings"
  value = var.workload_identity_bindings
}