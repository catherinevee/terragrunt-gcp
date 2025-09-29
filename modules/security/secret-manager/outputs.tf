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

output "secret_resource_names" {
  description = "Map of secret names to their full resource names"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => v.name
  }
}

output "secret_project" {
  description = "The project where secrets are stored"
  value       = var.project_id
}

output "secret_labels" {
  description = "Map of secret names to their labels"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => v.labels
  }
}

output "secret_topics" {
  description = "Map of secret names to their Pub/Sub topics"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => [
      for topic in v.topics : topic.name
    ]
  }
}

output "secret_rotation_periods" {
  description = "Map of secret names to their rotation periods"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => try(v.rotation[0].rotation_period, null)
  }
}

output "secret_next_rotation_times" {
  description = "Map of secret names to their next rotation times"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => try(v.rotation[0].next_rotation_time, null)
  }
}

output "secret_expiration_times" {
  description = "Map of secret names to their expiration timestamps"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => v.expire_time
  }
}

output "secret_ttls" {
  description = "Map of secret names to their TTL durations"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => v.ttl
  }
}

output "secret_version_aliases" {
  description = "Map of secret names to their version aliases"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => v.version_aliases
  }
}

output "secret_annotations" {
  description = "Map of secret names to their annotations"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => v.annotations
  }
}

output "secret_replication_policies" {
  description = "Map of secret names to their replication policies"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => {
      automatic = try(v.replication[0].automatic, false)
      user_managed = try([
        for r in v.replication[0].user_managed[0].replicas : {
          location                    = r.location
          customer_managed_encryption = r.customer_managed_encryption
        }
      ], [])
    }
  }
}

output "secret_version_ids" {
  description = "Map of secret version names to their IDs"
  value = {
    for k, v in google_secret_manager_secret_version.versions : k => v.id
  }
}

output "secret_version_names" {
  description = "Map of secret version names to their resource names"
  value = {
    for k, v in google_secret_manager_secret_version.versions : k => v.name
  }
}

output "secret_version_create_times" {
  description = "Map of secret version names to their creation times"
  value = {
    for k, v in google_secret_manager_secret_version.versions : k => v.create_time
  }
}

output "secret_version_destroy_times" {
  description = "Map of secret version names to their destroy times"
  value = {
    for k, v in google_secret_manager_secret_version.versions : k => v.destroy_time
  }
}

output "secret_version_states" {
  description = "Map of secret version names to their states"
  value = {
    for k, v in data.google_secret_manager_secret_version.current : k => v.version
  }
}

output "secret_version_enabled_states" {
  description = "Map of secret version names to their enabled status"
  value = {
    for k, v in google_secret_manager_secret_version.versions : k => v.enabled
  }
}

output "secret_data" {
  description = "Map of secret names to their current data values"
  value = {
    for k, v in data.google_secret_manager_secret_version.current : k => v.secret_data
  }
  sensitive = true
}

output "secret_iam_bindings" {
  description = "Map of secret IAM bindings"
  value = {
    for k, v in google_secret_manager_secret_iam_binding.bindings : k => {
      secret_id = v.secret_id
      role      = v.role
      members   = v.members
      condition = v.condition
    }
  }
}

output "secret_iam_members" {
  description = "Map of individual secret IAM member bindings"
  value = {
    for k, v in google_secret_manager_secret_iam_member.members : k => {
      secret_id = v.secret_id
      role      = v.role
      member    = v.member
      condition = v.condition
    }
  }
}

output "secret_accessors" {
  description = "Map of secrets to their accessor members"
  value = {
    for k, v in google_secret_manager_secret_iam_binding.bindings : k => v.members
    if v.role == "roles/secretmanager.secretAccessor"
  }
}

output "secret_version_managers" {
  description = "Map of secrets to their version manager members"
  value = {
    for k, v in google_secret_manager_secret_iam_binding.bindings : k => v.members
    if v.role == "roles/secretmanager.secretVersionManager"
  }
}

output "secret_admins" {
  description = "Map of secrets to their admin members"
  value = {
    for k, v in google_secret_manager_secret_iam_binding.bindings : k => v.members
    if v.role == "roles/secretmanager.admin"
  }
}

output "cmek_encrypted_secrets" {
  description = "Map of CMEK-encrypted secrets to their KMS key names"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => v.encryption[0].kms_key_name
    if length(v.encryption) > 0
  }
}

output "automatic_replication_secrets" {
  description = "List of secrets with automatic replication"
  value = [
    for k, v in google_secret_manager_secret.secrets : k
    if try(v.replication[0].automatic, false)
  ]
}

output "user_managed_replication_secrets" {
  description = "Map of secrets with user-managed replication to their locations"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => [
      for r in try(v.replication[0].user_managed[0].replicas, []) : r.location
    ]
    if length(try(v.replication[0].user_managed, [])) > 0
  }
}

output "rotating_secrets" {
  description = "List of secrets with rotation configured"
  value = [
    for k, v in google_secret_manager_secret.secrets : k
    if length(v.rotation) > 0
  ]
}

output "expiring_secrets" {
  description = "Map of expiring secrets to their expire times"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => v.expire_time
    if v.expire_time != null
  }
}

output "ttl_secrets" {
  description = "Map of TTL-enabled secrets to their TTL durations"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => v.ttl
    if v.ttl != null
  }
}

output "pubsub_notification_topics" {
  description = "Map of secrets to their Pub/Sub notification topics"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => [
      for topic in v.topics : {
        name = topic.name
      }
    ]
    if length(v.topics) > 0
  }
}

output "regional_secret_ids" {
  description = "Map of regional secret names to their IDs"
  value = {
    for k, v in google_secret_manager_regional_secret.regional_secrets : k => v.id
  }
}

output "regional_secret_names" {
  description = "List of regional secret names"
  value = [
    for secret in google_secret_manager_regional_secret.regional_secrets : secret.secret_id
  ]
}

output "regional_secret_locations" {
  description = "Map of regional secrets to their locations"
  value = {
    for k, v in google_secret_manager_regional_secret.regional_secrets : k => v.location
  }
}

output "regional_secret_customer_managed_encryption" {
  description = "Map of regional secrets to their CMEK configurations"
  value = {
    for k, v in google_secret_manager_regional_secret.regional_secrets : k => v.customer_managed_encryption
  }
}

output "secret_version_count" {
  description = "Map of secrets to their version counts"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => length(data.google_secret_manager_secret_version_list.versions[k].versions)
  }
}

output "latest_secret_versions" {
  description = "Map of secrets to their latest version numbers"
  value = {
    for k, v in data.google_secret_manager_secret_version.latest : k => v.version
  }
}

output "enabled_secret_versions" {
  description = "Map of secrets to their enabled version numbers"
  value = {
    for k, v in data.google_secret_manager_secret_version_list.versions : k => [
      for version in v.versions : version.version
      if version.state == "ENABLED"
    ]
  }
}

output "destroyed_secret_versions" {
  description = "Map of secrets to their destroyed version numbers"
  value = {
    for k, v in data.google_secret_manager_secret_version_list.versions : k => [
      for version in v.versions : version.version
      if version.state == "DESTROYED"
    ]
  }
}

output "secret_metadata" {
  description = "Map of secrets to their metadata"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => {
      create_time = v.create_time
      labels      = v.labels
      annotations = v.annotations
      topics      = [for t in v.topics : t.name]
    }
  }
}

output "secret_access_policies" {
  description = "Map of secrets to their IAM policies"
  value = {
    for k, v in data.google_secret_manager_secret_iam_policy.policies : k => v.policy_data
  }
  sensitive = true
}

output "secret_manager_service_account" {
  description = "The Secret Manager service account for the project"
  value       = "service-${data.google_project.project.number}@gcp-sa-secretmanager.iam.gserviceaccount.com"
}

output "secret_manager_api_enabled" {
  description = "Whether the Secret Manager API is enabled"
  value       = true
}

output "total_secrets_count" {
  description = "Total number of secrets created"
  value       = length(google_secret_manager_secret.secrets)
}

output "total_secret_versions_count" {
  description = "Total number of secret versions created"
  value       = length(google_secret_manager_secret_version.versions)
}

output "total_regional_secrets_count" {
  description = "Total number of regional secrets created"
  value       = length(google_secret_manager_regional_secret.regional_secrets)
}

output "secrets_by_state" {
  description = "Summary of secrets grouped by their state"
  value = {
    active   = length([for k, v in google_secret_manager_secret.secrets : k if v.state == "ACTIVE"])
    disabled = length([for k, v in google_secret_manager_secret.secrets : k if v.state == "DISABLED"])
  }
}

output "secrets_summary" {
  description = "Summary of secret configurations"
  value = {
    total_secrets                  = length(google_secret_manager_secret.secrets)
    cmek_encrypted_count           = length([for k, v in google_secret_manager_secret.secrets : k if length(v.encryption) > 0])
    automatic_replication_count    = length([for k, v in google_secret_manager_secret.secrets : k if try(v.replication[0].automatic, false)])
    user_managed_replication_count = length([for k, v in google_secret_manager_secret.secrets : k if length(try(v.replication[0].user_managed, [])) > 0])
    rotating_secrets_count         = length([for k, v in google_secret_manager_secret.secrets : k if length(v.rotation) > 0])
    expiring_secrets_count         = length([for k, v in google_secret_manager_secret.secrets : k if v.expire_time != null])
    with_pubsub_topics_count       = length([for k, v in google_secret_manager_secret.secrets : k if length(v.topics) > 0])
  }
}

output "secret_locations" {
  description = "List of all unique locations where secrets are replicated"
  value = distinct(flatten([
    for k, v in google_secret_manager_secret.secrets : [
      for r in try(v.replication[0].user_managed[0].replicas, []) : r.location
    ]
  ]))
}

output "secret_kms_keys" {
  description = "List of all unique KMS keys used for secret encryption"
  value = distinct([
    for k, v in google_secret_manager_secret.secrets : v.encryption[0].kms_key_name
    if length(v.encryption) > 0
  ])
}

output "secret_pubsub_topics" {
  description = "List of all unique Pub/Sub topics used for secret notifications"
  value = distinct(flatten([
    for k, v in google_secret_manager_secret.secrets : [
      for topic in v.topics : topic.name
    ]
  ]))
}

output "secrets_with_conditions" {
  description = "Map of secrets that have conditional IAM bindings"
  value = {
    for k, v in google_secret_manager_secret_iam_binding.bindings : k => v.condition
    if v.condition != null
  }
}

output "secret_version_aliases_map" {
  description = "Map of all version aliases across secrets"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => {
      for alias, version in v.version_aliases : alias => version
    }
    if length(v.version_aliases) > 0
  }
}

output "secret_rotation_lambda_functions" {
  description = "Map of secrets to their rotation Lambda/Cloud Function configurations"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => try(v.rotation[0].rotation_lambda, null)
    if length(v.rotation) > 0 && try(v.rotation[0].rotation_lambda, null) != null
  }
}