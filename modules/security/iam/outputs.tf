# IAM Module Outputs

output "service_account_ids" {
  description = "Map of service account names to their unique identifiers"
  value = {
    for k, v in google_service_account.service_accounts : k => v.id
  }
}

output "service_account_emails" {
  description = "Map of service account names to their email addresses"
  value = {
    for k, v in google_service_account.service_accounts : k => v.email
  }
}

output "service_account_names" {
  description = "Map of service account names to their display names"
  value = {
    for k, v in google_service_account.service_accounts : k => v.display_name
  }
}

output "service_account_unique_ids" {
  description = "Map of service account names to their unique IDs"
  value = {
    for k, v in google_service_account.service_accounts : k => v.unique_id
  }
}

output "service_account_members" {
  description = "Map of service account names to their IAM member strings"
  value = {
    for k, v in google_service_account.service_accounts : k => "serviceAccount:${v.email}"
  }
}

output "service_account_keys" {
  description = "Map of service account names to their key information (empty - keys not managed by this module)"
  value       = {}
  sensitive   = true
}

output "service_account_private_keys" {
  description = "Map of service account names to their private keys (empty - keys not managed by this module)"
  value       = {}
  sensitive   = true
}

output "custom_role_ids" {
  description = "Map of custom role names to their IDs"
  value = {
    for k, v in google_project_iam_custom_role.custom_roles : k => v.id
  }
}

output "custom_role_names" {
  description = "Map of custom role names to their full role IDs"
  value = {
    for k, v in google_project_iam_custom_role.custom_roles : k => v.name
  }
}

output "custom_role_titles" {
  description = "Map of custom role names to their titles"
  value = {
    for k, v in google_project_iam_custom_role.custom_roles : k => v.title
  }
}

output "custom_role_permissions" {
  description = "Map of custom role names to their permissions"
  value = {
    for k, v in google_project_iam_custom_role.custom_roles : k => v.permissions
  }
}

output "project_iam_bindings" {
  description = "Map of IAM role bindings at the project level (empty - using IAM members instead)"
  value       = {}
}

output "project_iam_members" {
  description = "Map of individual IAM member bindings at the project level"
  value = {
    for k, v in google_project_iam_member.service_account_roles : k => {
      role    = v.role
      member  = v.member
      project = v.project
    }
  }
}

output "folder_iam_bindings" {
  description = "Map of IAM role bindings at the folder level (empty - not managed by this module)"
  value       = {}
}

output "organization_iam_bindings" {
  description = "Map of IAM role bindings at the organization level (empty - not managed by this module)"
  value       = {}
}

output "workload_identity_pool_id" {
  description = "The ID of the workload identity pool"
  value       = try(google_iam_workload_identity_pool.workload_identity_pool[0].id, "")
}

output "workload_identity_pool_name" {
  description = "The resource name of the workload identity pool"
  value       = try(google_iam_workload_identity_pool.workload_identity_pool[0].name, "")
}

output "workload_identity_pool_state" {
  description = "The state of the workload identity pool"
  value       = try(google_iam_workload_identity_pool.workload_identity_pool[0].state, "")
}

output "workload_identity_pool_providers" {
  description = "Map of workload identity pool provider details (empty - not managed by this module)"
  value       = {}
}

output "workforce_identity_pool_id" {
  description = "The ID of the workforce identity pool (empty - not managed by this module)"
  value       = ""
}

output "workforce_identity_pool_name" {
  description = "The resource name of the workforce identity pool (empty - not managed by this module)"
  value       = ""
}

output "workforce_identity_pool_state" {
  description = "The state of the workforce identity pool (empty - not managed by this module)"
  value       = ""
}

output "workforce_identity_pool_providers" {
  description = "Map of workforce identity pool provider details (empty - not managed by this module)"
  value       = {}
}

output "iam_policy_project_id" {
  description = "The project ID where IAM policies are applied"
  value       = var.project_id
}

output "iam_policy_folder_id" {
  description = "The folder ID where IAM policies are applied"
  value       = var.folder_id
}

output "iam_policy_organization_id" {
  description = "The organization ID where IAM policies are applied"
  value       = var.organization_id
}

output "conditional_bindings" {
  description = "Map of conditional IAM bindings (empty - not managed by this module)"
  value       = {}
}

output "audit_config" {
  description = "IAM audit configuration for the project (empty - not managed by this module)"
  value       = {}
}

output "iam_policy_data" {
  description = "The complete IAM policy data for the project"
  value       = ""
  sensitive   = true
}

output "deny_policies" {
  description = "Map of IAM deny policies (empty - not managed by this module)"
  value       = {}
}

output "access_approval_settings" {
  description = "Access approval settings for the project (empty - not managed by this module)"
  value       = {}
}

output "essential_contacts" {
  description = "Map of essential contacts configured (empty - not managed by this module)"
  value       = {}
}

output "binary_authorization_policy" {
  description = "Binary authorization policy details (empty - not managed by this module)"
  value       = {}
}

output "org_policy_constraints" {
  description = "Map of organization policy constraints (empty - not managed by this module)"
  value       = {}
}

output "iam_conditions_summary" {
  description = "Summary of IAM conditions applied"
  value = {
    total_conditions = 0
    condition_types  = []
  }
}

output "service_accounts_summary" {
  description = "Summary of service accounts created"
  value = {
    total_accounts = length(google_service_account.service_accounts)
    with_keys      = 0
    accounts_list  = [for k, v in google_service_account.service_accounts : v.email]
  }
}

output "custom_roles_summary" {
  description = "Summary of custom roles created"
  value = {
    total_roles       = length(google_project_iam_custom_role.custom_roles)
    total_permissions = length(distinct(flatten([for k, v in google_project_iam_custom_role.custom_roles : v.permissions])))
    roles_list        = [for k, v in google_project_iam_custom_role.custom_roles : v.role_id]
  }
}
