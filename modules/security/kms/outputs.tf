# KMS Module Outputs

output "keyring_id" {
  description = "The ID of the KMS key ring"
  value       = google_kms_key_ring.keyring.id
}

output "keyring_name" {
  description = "The name of the KMS key ring"
  value       = google_kms_key_ring.keyring.name
}

output "keyring_location" {
  description = "The location of the KMS key ring"
  value       = google_kms_key_ring.keyring.location
}

output "keyring_self_link" {
  description = "The self link of the KMS key ring"
  value       = google_kms_key_ring.keyring.self_link
}

output "key_ids" {
  description = "Map of crypto key names to their IDs"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.id
  }
}

output "key_names" {
  description = "List of created crypto key names"
  value = [
    for key in google_kms_crypto_key.keys : key.name
  ]
}

output "key_self_links" {
  description = "Map of crypto key names to their self links"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.self_link
  }
}

output "key_purposes" {
  description = "Map of crypto key names to their purposes"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.purpose
  }
}

output "key_rotation_periods" {
  description = "Map of crypto key names to their rotation periods"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.rotation_period
  }
}

output "key_algorithms" {
  description = "Map of crypto key names to their version template algorithms"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.version_template[0].algorithm
  }
}

output "key_protection_levels" {
  description = "Map of crypto key names to their protection levels"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.version_template[0].protection_level
  }
}

output "key_version_ids" {
  description = "Map of crypto key version names to their IDs"
  value = {
    for k, v in google_kms_crypto_key_version.versions : k => v.id
  }
}

output "key_version_names" {
  description = "Map of crypto key version names to their resource names"
  value = {
    for k, v in google_kms_crypto_key_version.versions : k => v.name
  }
}

output "key_version_states" {
  description = "Map of crypto key version names to their states"
  value = {
    for k, v in google_kms_crypto_key_version.versions : k => v.state
  }
}

output "key_version_algorithms" {
  description = "Map of crypto key version names to their algorithms"
  value = {
    for k, v in google_kms_crypto_key_version.versions : k => v.algorithm
  }
}

output "key_version_protection_levels" {
  description = "Map of crypto key version names to their protection levels"
  value = {
    for k, v in google_kms_crypto_key_version.versions : k => v.protection_level
  }
}

output "key_version_attestations" {
  description = "Map of crypto key version names to their attestation information"
  value = {
    for k, v in google_kms_crypto_key_version.versions : k => v.attestation
  }
  sensitive = true
}

output "key_version_generate_times" {
  description = "Map of crypto key version names to their generation times"
  value = {
    for k, v in google_kms_crypto_key_version.versions : k => v.generate_time
  }
}

output "key_version_destroy_times" {
  description = "Map of crypto key version names to their scheduled destroy times"
  value = {
    for k, v in google_kms_crypto_key_version.versions : k => v.destroy_scheduled_duration
  }
}

output "import_job_ids" {
  description = "Map of import job names to their IDs"
  value = {
    for k, v in google_kms_key_ring_import_job.import_jobs : k => v.id
  }
}

output "import_job_names" {
  description = "Map of import job names to their resource names"
  value = {
    for k, v in google_kms_key_ring_import_job.import_jobs : k => v.name
  }
}

output "import_job_states" {
  description = "Map of import job names to their states"
  value = {
    for k, v in google_kms_key_ring_import_job.import_jobs : k => v.state
  }
}

output "import_job_import_methods" {
  description = "Map of import job names to their import methods"
  value = {
    for k, v in google_kms_key_ring_import_job.import_jobs : k => v.import_method
  }
}

output "import_job_protection_levels" {
  description = "Map of import job names to their protection levels"
  value = {
    for k, v in google_kms_key_ring_import_job.import_jobs : k => v.protection_level
  }
}

output "import_job_public_keys" {
  description = "Map of import job names to their public key information"
  value = {
    for k, v in google_kms_key_ring_import_job.import_jobs : k => v.public_key
  }
  sensitive = true
}

output "import_job_attestations" {
  description = "Map of import job names to their attestation information"
  value = {
    for k, v in google_kms_key_ring_import_job.import_jobs : k => v.attestation
  }
  sensitive = true
}

output "key_iam_bindings" {
  description = "Map of crypto key IAM bindings"
  value = {
    for k, v in google_kms_crypto_key_iam_binding.bindings : k => {
      crypto_key = v.crypto_key_id
      role       = v.role
      members    = v.members
      condition  = v.condition
    }
  }
}

output "key_iam_members" {
  description = "Map of individual crypto key IAM member bindings"
  value = {
    for k, v in google_kms_crypto_key_iam_member.members : k => {
      crypto_key = v.crypto_key_id
      role       = v.role
      member     = v.member
      condition  = v.condition
    }
  }
}

output "keyring_iam_bindings" {
  description = "Map of key ring IAM bindings"
  value = {
    for k, v in google_kms_key_ring_iam_binding.bindings : k => {
      key_ring  = v.key_ring_id
      role      = v.role
      members   = v.members
      condition = v.condition
    }
  }
}

output "keyring_iam_members" {
  description = "Map of individual key ring IAM member bindings"
  value = {
    for k, v in google_kms_key_ring_iam_member.members : k => {
      key_ring  = v.key_ring_id
      role      = v.role
      member    = v.member
      condition = v.condition
    }
  }
}

output "secret_manager_crypto_keys" {
  description = "Map of Secret Manager crypto key configurations"
  value = {
    for k, v in google_secret_manager_secret.cmek_secrets : k => v.encryption[0].kms_key_name
  }
}

output "ekm_connection_id" {
  description = "The ID of the EKM connection if configured"
  value       = try(google_kms_ekm_connection.ekm[0].id, "")
}

output "ekm_connection_name" {
  description = "The name of the EKM connection"
  value       = try(google_kms_ekm_connection.ekm[0].name, "")
}

output "ekm_connection_service_resolvers" {
  description = "Service resolver configurations for EKM connection"
  value       = try(google_kms_ekm_connection.ekm[0].service_resolver, [])
}

output "ekm_connection_key_management_mode" {
  description = "Key management mode for EKM connection"
  value       = try(google_kms_ekm_connection.ekm[0].key_management_mode, "")
}

output "ekm_connection_crypto_space_path" {
  description = "Crypto space path for EKM connection"
  value       = try(google_kms_ekm_connection.ekm[0].crypto_space_path, "")
}

output "autokey_config" {
  description = "Autokey configuration details"
  value = try({
    folder      = google_kms_autokey_config.autokey[0].folder
    key_project = google_kms_autokey_config.autokey[0].key_project
    state       = google_kms_autokey_config.autokey[0].state
  }, {})
}

output "key_labels" {
  description = "Map of crypto key names to their labels"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.labels
  }
}

output "key_skip_initial_version_creation" {
  description = "Map of crypto key names to their skip_initial_version_creation setting"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.skip_initial_version_creation
  }
}

output "key_import_only" {
  description = "Map of crypto key names to their import_only setting"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.import_only
  }
}

output "key_destroy_scheduled_duration" {
  description = "Map of crypto key names to their destroy_scheduled_duration"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.destroy_scheduled_duration
  }
}

output "crypto_key_backend_services" {
  description = "Map of crypto keys used by backend services"
  value = {
    for k, v in google_compute_backend_service.encrypted : k => v.cdn_policy[0].cache_key_policy[0].include_named_cookies
  }
}

output "project_id" {
  description = "The project ID where KMS resources are created"
  value       = var.project_id
}

output "kms_service_account" {
  description = "The KMS service account for the project"
  value       = "service-${data.google_project.project.number}@gcp-sa-ekms.iam.gserviceaccount.com"
}

output "kms_crypto_key_encrypter_decrypters" {
  description = "Map of service accounts with encrypt/decrypt permissions"
  value = {
    for k, v in google_kms_crypto_key_iam_binding.crypto_key : k => v.members
    if v.role == "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  }
}

output "kms_admin_members" {
  description = "List of KMS admin members"
  value = distinct(flatten([
    for binding in google_kms_crypto_key_iam_binding.bindings : binding.members
    if binding.role == "roles/cloudkms.admin"
  ]))
}

output "hsm_keys" {
  description = "Map of HSM-backed crypto keys"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.id
    if v.version_template[0].protection_level == "HSM"
  }
}

output "software_keys" {
  description = "Map of software-backed crypto keys"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.id
    if v.version_template[0].protection_level == "SOFTWARE"
  }
}

output "external_keys" {
  description = "Map of external (EKM) crypto keys"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.id
    if v.version_template[0].protection_level == "EXTERNAL"
  }
}

output "external_vpc_keys" {
  description = "Map of external VPC (EKM via VPC) crypto keys"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.id
    if v.version_template[0].protection_level == "EXTERNAL_VPC"
  }
}

output "symmetric_encryption_keys" {
  description = "Map of symmetric encryption keys"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.id
    if v.purpose == "ENCRYPT_DECRYPT"
  }
}

output "asymmetric_signing_keys" {
  description = "Map of asymmetric signing keys"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.id
    if v.purpose == "ASYMMETRIC_SIGN"
  }
}

output "asymmetric_decryption_keys" {
  description = "Map of asymmetric decryption keys"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.id
    if v.purpose == "ASYMMETRIC_DECRYPT"
  }
}

output "mac_signing_keys" {
  description = "Map of MAC signing keys"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.id
    if v.purpose == "MAC"
  }
}

output "raw_encryption_keys" {
  description = "Map of raw encryption keys"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.id
    if v.purpose == "RAW_ENCRYPT_DECRYPT"
  }
}

output "key_creation_times" {
  description = "Map of crypto key names to their creation timestamps"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.create_time
  }
}

output "primary_key_versions" {
  description = "Map of crypto key names to their primary version IDs"
  value = {
    for k, v in data.google_kms_crypto_key.key_data : k => v.primary[0].name
  }
}

output "key_state_summary" {
  description = "Summary of key states across all crypto keys"
  value = {
    total_keys          = length(google_kms_crypto_key.keys)
    total_versions      = length(google_kms_crypto_key_version.versions)
    hsm_protected_keys  = length([for k, v in google_kms_crypto_key.keys : k if v.version_template[0].protection_level == "HSM"])
    external_keys_count = length([for k, v in google_kms_crypto_key.keys : k if v.version_template[0].protection_level == "EXTERNAL"])
    keys_with_rotation  = length([for k, v in google_kms_crypto_key.keys : k if v.rotation_period != null])
  }
}

output "kms_locations" {
  description = "List of all KMS resource locations"
  value = distinct(concat(
    [google_kms_key_ring.keyring.location],
    [for k in google_kms_key_ring.additional_keyrings : k.location]
  ))
}

output "enabled_services" {
  description = "List of GCP services that should be enabled for KMS"
  value = [
    "cloudkms.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com"
  ]
}