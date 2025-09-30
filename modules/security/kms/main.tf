# KMS Module
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.45.2"
    }
  }
}

# KMS Key Ring - Handle existing resources
resource "google_kms_key_ring" "key_ring" {
  name     = var.key_ring_name
  location = var.region
  project  = var.project_id

  depends_on = [google_project_service.kms_api]

  lifecycle {
    ignore_changes  = [name, location, project]
    prevent_destroy = true
  }
}

# KMS Crypto Keys
resource "google_kms_crypto_key" "crypto_keys" {
  for_each = var.crypto_keys

  name     = each.value.name
  key_ring = google_kms_key_ring.key_ring.id
  purpose  = each.value.purpose

  version_template {
    algorithm = each.value.algorithm
  }

  rotation_period = each.value.rotation_period != null && each.value.rotation_period != "" && each.value.rotation_period != "0s" ? each.value.rotation_period : null

  lifecycle {
    prevent_destroy = true
  }
}

# KMS Crypto Key IAM Bindings
resource "google_kms_crypto_key_iam_binding" "crypto_key_iam_bindings" {
  for_each = var.enable_iam_bindings ? var.crypto_key_iam_bindings : {}

  crypto_key_id = google_kms_crypto_key.crypto_keys[each.value.crypto_key_key].id
  role          = each.value.role
  members       = each.value.members
}

# Enable KMS API
resource "google_project_service" "kms_api" {
  project = var.project_id
  service = "cloudkms.googleapis.com"

  disable_on_destroy = false
}

# Outputs
output "key_ring_name" {
  description = "Name of the KMS key ring"
  value       = google_kms_key_ring.key_ring.name
}

output "key_ring_id" {
  description = "ID of the KMS key ring"
  value       = google_kms_key_ring.key_ring.id
}

output "crypto_key_names" {
  description = "Names and purposes of crypto keys"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => {
      name    = v.name
      purpose = v.purpose
    }
  }
}

output "crypto_key_ids" {
  description = "IDs of crypto keys"
  value = {
    for k, v in google_kms_crypto_key.crypto_keys : k => v.id
  }
}
