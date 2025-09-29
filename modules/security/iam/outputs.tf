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
  description = "Map of service account names to their key information"
  value = {
    for k, v in google_service_account_key.keys : k => {
      id               = v.id
      name            = v.name
      public_key_type = v.public_key_type
      valid_after     = v.valid_after
      valid_before    = v.valid_before
      key_algorithm   = v.key_algorithm
    }
  }
  sensitive = true
}

output "service_account_private_keys" {
  description = "Map of service account names to their private keys (base64 encoded)"
  value = {
    for k, v in google_service_account_key.keys : k => v.private_key
  }
  sensitive = true
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
  description = "Map of IAM role bindings at the project level"
  value = {
    for k, v in google_project_iam_binding.project_bindings : k => {
      role    = v.role
      members = v.members
      project = v.project
    }
  }
}

output "project_iam_members" {
  description = "Map of individual IAM member bindings at the project level"
  value = {
    for k, v in google_project_iam_member.project_members : k => {
      role    = v.role
      member  = v.member
      project = v.project
    }
  }
}

output "folder_iam_bindings" {
  description = "Map of IAM role bindings at the folder level"
  value = {
    for k, v in google_folder_iam_binding.folder_bindings : k => {
      role    = v.role
      members = v.members
      folder  = v.folder
    }
  }
}

output "organization_iam_bindings" {
  description = "Map of IAM role bindings at the organization level"
  value = {
    for k, v in google_organization_iam_binding.org_bindings : k => {
      role    = v.role
      members = v.members
      org_id  = v.org_id
    }
  }
}

output "workload_identity_pool_id" {
  description = "The ID of the workload identity pool"
  value       = try(google_iam_workload_identity_pool.pool[0].id, "")
}

output "workload_identity_pool_name" {
  description = "The resource name of the workload identity pool"
  value       = try(google_iam_workload_identity_pool.pool[0].name, "")
}

output "workload_identity_pool_state" {
  description = "The state of the workload identity pool"
  value       = try(google_iam_workload_identity_pool.pool[0].state, "")
}

output "workload_identity_pool_providers" {
  description = "Map of workload identity pool provider details"
  value = {
    for k, v in google_iam_workload_identity_pool_provider.providers : k => {
      id                        = v.id
      name                     = v.name
      state                    = v.state
      attribute_mapping        = v.attribute_mapping
      attribute_condition      = v.attribute_condition
      disabled                 = v.disabled
    }
  }
}

output "workforce_identity_pool_id" {
  description = "The ID of the workforce identity pool"
  value       = try(google_iam_workforce_pool.workforce_pool[0].id, "")
}

output "workforce_identity_pool_name" {
  description = "The resource name of the workforce identity pool"
  value       = try(google_iam_workforce_pool.workforce_pool[0].name, "")
}

output "workforce_identity_pool_state" {
  description = "The state of the workforce identity pool"
  value       = try(google_iam_workforce_pool.workforce_pool[0].state, "")
}

output "workforce_identity_pool_providers" {
  description = "Map of workforce identity pool provider details"
  value = {
    for k, v in google_iam_workforce_pool_provider.workforce_providers : k => {
      id                   = v.id
      name                = v.name
      state               = v.state
      attribute_mapping   = v.attribute_mapping
      attribute_condition = v.attribute_condition
      disabled           = v.disabled
    }
  }
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
  description = "Map of conditional IAM bindings"
  value = {
    for k, v in google_project_iam_binding.conditional_bindings : k => {
      role      = v.role
      members   = v.members
      condition = v.condition
    }
  }
}

output "audit_config" {
  description = "IAM audit configuration for the project"
  value = {
    for k, v in google_project_iam_audit_config.audit_configs : k => {
      service          = v.service
      audit_log_configs = v.audit_log_config
    }
  }
}

output "iam_policy_data" {
  description = "The complete IAM policy data for the project"
  value       = try(data.google_iam_policy.project_policy.policy_data, "")
  sensitive   = true
}

output "deny_policies" {
  description = "Map of IAM deny policies"
  value = {
    for k, v in google_iam_deny_policy.deny_policies : k => {
      id           = v.id
      name         = v.name
      parent       = v.parent
      display_name = v.display_name
      rules        = v.rules
    }
  }
}

output "access_approval_settings" {
  description = "Access approval settings for the project"
  value = try({
    name                      = google_project_access_approval_settings.settings[0].name
    notification_emails       = google_project_access_approval_settings.settings[0].notification_emails
    enrolled_services         = google_project_access_approval_settings.settings[0].enrolled_services
    active_key_version       = google_project_access_approval_settings.settings[0].active_key_version
    ancestor_has_active_key_version = google_project_access_approval_settings.settings[0].ancestor_has_active_key_version
    enrolled_ancestor        = google_project_access_approval_settings.settings[0].enrolled_ancestor
    invalid_key_version      = google_project_access_approval_settings.settings[0].invalid_key_version
  }, {})
}

output "essential_contacts" {
  description = "Map of essential contacts configured"
  value = {
    for k, v in google_essential_contacts_contact.contacts : k => {
      name                          = v.name
      email                        = v.email
      notification_category_subscriptions = v.notification_category_subscriptions
      language_tag                 = v.language_tag
      validation_state             = v.validation_state
      validation_time              = v.validate_time
    }
  }
}

output "binary_authorization_policy" {
  description = "Binary authorization policy details"
  value = try({
    id                         = google_binary_authorization_policy.policy[0].id
    global_policy_evaluation_mode = google_binary_authorization_policy.policy[0].global_policy_evaluation_mode
    admission_whitelist_patterns = google_binary_authorization_policy.policy[0].admission_whitelist_patterns
    cluster_admission_rules      = google_binary_authorization_policy.policy[0].cluster_admission_rules
  }, {})
}

output "org_policy_constraints" {
  description = "Map of organization policy constraints"
  value = {
    for k, v in google_org_policy_policy.policies : k => {
      name   = v.name
      parent = v.parent
      spec   = v.spec
    }
  }
}

output "iam_conditions_summary" {
  description = "Summary of IAM conditions applied"
  value = {
    total_conditions = length([for k, v in google_project_iam_binding.conditional_bindings : v.condition if v.condition != null])
    condition_types = distinct([for k, v in google_project_iam_binding.conditional_bindings : v.condition[0].title if v.condition != null])
  }
}

output "service_accounts_summary" {
  description = "Summary of service accounts created"
  value = {
    total_accounts = length(google_service_account.service_accounts)
    with_keys     = length(google_service_account_key.keys)
    accounts_list = [for k, v in google_service_account.service_accounts : v.email]
  }
}

output "custom_roles_summary" {
  description = "Summary of custom roles created"
  value = {
    total_roles        = length(google_project_iam_custom_role.custom_roles)
    total_permissions  = length(distinct(flatten([for k, v in google_project_iam_custom_role.custom_roles : v.permissions])))
    roles_list        = [for k, v in google_project_iam_custom_role.custom_roles : v.role_id]
  }
}