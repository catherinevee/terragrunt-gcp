# IAM Module for Service Accounts and Role Bindings

# Service Accounts
resource "google_service_account" "service_accounts" {
  for_each = var.service_accounts
  
  account_id   = each.key
  project      = var.project_id
  display_name = each.value.display_name
  description  = each.value.description
}

# Service Account Keys (optional)
resource "google_service_account_key" "keys" {
  for_each = {
    for k, v in var.service_accounts : k => v
    if lookup(v, "create_key", false)
  }
  
  service_account_id = google_service_account.service_accounts[each.key].name
  key_algorithm      = "KEY_ALG_RSA_2048"
  private_key_type   = "TYPE_GOOGLE_CREDENTIALS_FILE"
}

# Project IAM Bindings
resource "google_project_iam_binding" "project_bindings" {
  for_each = var.project_iam_bindings
  
  project = var.project_id
  role    = each.value.role
  members = each.value.members
  
  condition {
    title       = lookup(each.value, "condition_title", null)
    description = lookup(each.value, "condition_description", null)
    expression  = lookup(each.value, "condition_expression", null)
  }
}

# Service Account IAM Bindings
resource "google_service_account_iam_binding" "sa_bindings" {
  for_each = var.service_account_iam_bindings
  
  service_account_id = google_service_account.service_accounts[each.value.service_account].name
  role               = each.value.role
  members            = each.value.members
}

# Workload Identity Bindings for GKE
resource "google_service_account_iam_binding" "workload_identity" {
  for_each = var.workload_identity_bindings
  
  service_account_id = google_service_account.service_accounts[each.value.service_account].name
  role               = "roles/iam.workloadIdentityUser"
  
  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${each.value.namespace}/${each.value.ksa_name}]"
  ]
}

# Custom IAM Roles
resource "google_project_iam_custom_role" "custom_roles" {
  for_each = var.custom_roles
  
  role_id     = each.key
  project     = var.project_id
  title       = each.value.title
  description = each.value.description
  permissions = each.value.permissions
  stage       = lookup(each.value, "stage", "GA")
}

# Folder IAM Bindings (if using folders)
resource "google_folder_iam_binding" "folder_bindings" {
  for_each = var.folder_iam_bindings
  
  folder  = each.value.folder
  role    = each.value.role
  members = each.value.members
}

# Organization IAM Bindings (if using organization)
resource "google_organization_iam_binding" "org_bindings" {
  for_each = var.organization_iam_bindings
  
  org_id  = var.org_id
  role    = each.value.role
  members = each.value.members
}

# Store service account keys in Secret Manager
resource "google_secret_manager_secret" "sa_keys" {
  for_each = {
    for k, v in var.service_accounts : k => v
    if lookup(v, "create_key", false) && lookup(v, "store_key_in_secret_manager", true)
  }
  
  secret_id = "${each.key}-key"
  project   = var.project_id
  
  labels = merge(
    var.labels,
    {
      service_account = each.key
      managed_by      = "terraform"
    }
  )
  
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "sa_keys" {
  for_each = {
    for k, v in var.service_accounts : k => v
    if lookup(v, "create_key", false) && lookup(v, "store_key_in_secret_manager", true)
  }
  
  secret      = google_secret_manager_secret.sa_keys[each.key].id
  secret_data = base64decode(google_service_account_key.keys[each.key].private_key)
}

# IAM Audit Config
resource "google_project_iam_audit_config" "audit" {
  for_each = var.audit_configs
  
  project = var.project_id
  service = each.key
  
  dynamic "audit_log_config" {
    for_each = each.value.audit_log_configs
    content {
      log_type         = audit_log_config.value.log_type
      exempted_members = lookup(audit_log_config.value, "exempted_members", [])
    }
  }
}