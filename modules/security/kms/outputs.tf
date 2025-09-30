# KMS Module Outputs

output "keyring_id" {
  description = "The ID of the KMS key ring"
  value       = google_kms_key_ring.key_ring.id
}

output "keyring_name" {
  description = "The name of the KMS key ring"
  value       = google_kms_key_ring.key_ring.name
}

output "keyring_location" {
  description = "The location of the KMS key ring"
  value       = google_kms_key_ring.key_ring.location
}

output "keyring_self_link" {
  description = "The self link of the KMS key ring"
  value       = google_kms_key_ring.key_ring.id
}

output "key_ids" {
  description = "Map of crypto key names to their IDs"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => v.id
  }
}

output "key_names" {
  description = "List of created crypto key names"
  value = [
    for key in google_kms_crypto_key.crypto_keys : key.name
  ]
}

output "key_self_links" {
  description = "Map of crypto key names to their IDs (self links not available)"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => v.id
  }
}

output "key_purposes" {
  description = "Map of crypto key names to their purposes"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => v.purpose
  }
}

output "key_rotation_periods" {
  description = "Map of crypto key names to their rotation periods"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => try(v.rotation_period, "")
  }
}

output "key_algorithms" {
  description = "Map of crypto key names to their version template algorithms"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => try(v.version_template[0].algorithm, "")
  }
}

output "key_protection_levels" {
  description = "Map of crypto key names to their protection levels"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => try(v.version_template[0].protection_level, "SOFTWARE")
  }
}

output "key_iam_bindings" {
  description = "Map of crypto key IAM bindings"
  value = {
    for k, v in google_kms_crypto_key_iam_binding.crypto_key_iam_bindings : k => {
      crypto_key = v.crypto_key_id
      role       = v.role
      members    = v.members
      condition  = try(v.condition, null)
    }
  }
}

output "project_id" {
  description = "The project ID where KMS resources are created"
  value       = var.project_id
}

output "key_labels" {
  description = "Map of crypto key names to their labels"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => try(v.labels, {})
  }
}

output "key_skip_initial_version_creation" {
  description = "Map of crypto key names to their skip_initial_version_creation setting"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => try(v.skip_initial_version_creation, false)
  }
}

output "key_import_only" {
  description = "Map of crypto key names to their import_only setting"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => try(v.import_only, false)
  }
}

output "key_destroy_scheduled_duration" {
  description = "Map of crypto key names to their destroy_scheduled_duration"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => try(v.destroy_scheduled_duration, "")
  }
}

output "symmetric_encryption_keys" {
  description = "Map of symmetric encryption keys"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => v.id
    if v.purpose == "ENCRYPT_DECRYPT"
  }
}

output "asymmetric_signing_keys" {
  description = "Map of asymmetric signing keys"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => v.id
    if v.purpose == "ASYMMETRIC_SIGN"
  }
}

output "asymmetric_decryption_keys" {
  description = "Map of asymmetric decryption keys"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => v.id
    if v.purpose == "ASYMMETRIC_DECRYPT"
  }
}

output "mac_signing_keys" {
  description = "Map of MAC signing keys"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => v.id
    if v.purpose == "MAC"
  }
}

output "raw_encryption_keys" {
  description = "Map of raw encryption keys"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => v.id
    if v.purpose == "RAW_ENCRYPT_DECRYPT"
  }
}

output "hsm_keys" {
  description = "Map of HSM-backed crypto keys"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => v.id
    if try(v.version_template[0].protection_level, "SOFTWARE") == "HSM"
  }
}

output "software_keys" {
  description = "Map of software-backed crypto keys"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => v.id
    if try(v.version_template[0].protection_level, "SOFTWARE") == "SOFTWARE"
  }
}

output "external_keys" {
  description = "Map of external (EKM) crypto keys"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => v.id
    if try(v.version_template[0].protection_level, "SOFTWARE") == "EXTERNAL"
  }
}

output "external_vpc_keys" {
  description = "Map of external VPC (EKM via VPC) crypto keys"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => v.id
    if try(v.version_template[0].protection_level, "SOFTWARE") == "EXTERNAL_VPC"
  }
}

output "key_creation_times" {
  description = "Map of crypto key names to their creation timestamps"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => try(v.create_time, "")
  }
}

output "key_state_summary" {
  description = "Summary of key states across all crypto keys"
  value = {
    total_keys             = length(google_kms_crypto_key.crypto_keys)
    hsm_protected_keys     = length([for k, v in google_kms_crypto_key.crypto_keys : k if try(v.version_template[0].protection_level, "SOFTWARE") == "HSM"])
    external_keys_count    = length([for k, v in google_kms_crypto_key.crypto_keys : k if try(v.version_template[0].protection_level, "SOFTWARE") == "EXTERNAL"])
    keys_with_rotation     = length([for k, v in google_kms_crypto_key.crypto_keys : k if try(v.rotation_period, "") != ""])
  }
}

output "kms_locations" {
  description = "List of all KMS resource locations"
  value       = [google_kms_key_ring.key_ring.location]
}

output "enabled_services" {
  description = "List of GCP services that should be enabled for KMS"
  value = [
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com"
  ]
}
