# IAM Module
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.45.2"
    }
  }
}

# Service Accounts
resource "google_service_account" "service_accounts" {
  for_each = var.service_accounts

  account_id   = each.value.account_id
  display_name = each.value.display_name
  description  = each.value.description
  project      = var.project_id

  depends_on = [google_project_service.iam_api]
}

# Custom Roles
resource "google_project_iam_custom_role" "custom_roles" {
  for_each = var.custom_roles

  role_id     = each.value.role_id
  title       = each.value.title
  description = each.value.description
  permissions = each.value.permissions
  project     = var.project_id

  depends_on = [google_project_service.iam_api]
}

# Service Account IAM Bindings - Made optional to handle permission issues
resource "google_project_iam_member" "service_account_roles" {
  for_each = var.enable_iam_bindings ? var.service_account_roles : {}

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.service_accounts[each.value.service_account_key].email}"
}

# Project IAM Bindings - Made optional to handle permission issues
resource "google_project_iam_member" "project_iam_bindings" {
  for_each = var.enable_iam_bindings ? var.project_iam_bindings : {}

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}

# Workload Identity Pool
resource "google_iam_workload_identity_pool" "workload_identity_pool" {
  count = var.enable_workload_identity ? 1 : 0

  workload_identity_pool_id = var.workload_identity_pool_id
  display_name              = var.workload_identity_display_name
  description               = var.workload_identity_description
  project                   = var.project_id

  depends_on = [google_project_service.iam_api]
}

# Workload Identity Pool Provider
resource "google_iam_workload_identity_pool_provider" "workload_identity_pool_provider" {
  count = var.enable_workload_identity ? 1 : 0

  workload_identity_pool_id          = google_iam_workload_identity_pool.workload_identity_pool[0].workload_identity_pool_id
  workload_identity_pool_provider_id = var.workload_identity_pool_provider_id
  display_name                       = var.workload_identity_provider_display_name
  description                        = var.workload_identity_provider_description
  project                            = var.project_id

  oidc {
    issuer_uri        = var.oidc_issuer_uri
    allowed_audiences = var.oidc_allowed_audiences
  }
}

# Enable IAM API
resource "google_project_service" "iam_api" {
  project = var.project_id
  service = "iam.googleapis.com"

  disable_on_destroy = false
}

# Outputs
output "service_account_emails" {
  description = "Email addresses of the service accounts"
  value = {
    for k, v in google_service_account.service_accounts : k => v.email
  }
}

output "service_account_names" {
  description = "Names of the service accounts"
  value = {
    for k, v in google_service_account.service_accounts : k => v.name
  }
}

output "workload_identity_pool_id" {
  description = "ID of the workload identity pool"
  value       = var.enable_workload_identity ? google_iam_workload_identity_pool.workload_identity_pool[0].workload_identity_pool_id : null
}

output "workload_identity_pool_provider_id" {
  description = "ID of the workload identity pool provider"
  value       = var.enable_workload_identity ? google_iam_workload_identity_pool_provider.workload_identity_pool_provider[0].workload_identity_pool_provider_id : null
}
