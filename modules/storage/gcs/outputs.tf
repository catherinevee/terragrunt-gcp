# GCS Bucket Module Outputs

# Bucket Information
output "bucket_name" {
  description = "The name of the bucket"
  value       = google_storage_bucket.bucket.name
}

output "bucket_id" {
  description = "The ID of the bucket"
  value       = google_storage_bucket.bucket.id
}

output "bucket_self_link" {
  description = "The self link of the bucket"
  value       = google_storage_bucket.bucket.self_link
}

output "bucket_url" {
  description = "The base URL of the bucket"
  value       = google_storage_bucket.bucket.url
}

# Location and Storage
output "location" {
  description = "The location of the bucket"
  value       = google_storage_bucket.bucket.location
}

output "storage_class" {
  description = "The storage class of the bucket"
  value       = google_storage_bucket.bucket.storage_class
}

output "project" {
  description = "The project the bucket belongs to"
  value       = google_storage_bucket.bucket.project
}

# Configuration Details
output "uniform_bucket_level_access" {
  description = "Whether uniform bucket level access is enabled"
  value       = google_storage_bucket.bucket.uniform_bucket_level_access
}

output "public_access_prevention" {
  description = "The public access prevention setting"
  value       = google_storage_bucket.bucket.public_access_prevention
}

output "requester_pays" {
  description = "Whether requester pays is enabled"
  value       = google_storage_bucket.bucket.requester_pays
}

output "default_event_based_hold" {
  description = "Whether default event-based hold is enabled"
  value       = google_storage_bucket.bucket.default_event_based_hold
}

# Versioning
output "versioning_enabled" {
  description = "Whether versioning is enabled"
  value       = try(google_storage_bucket.bucket.versioning[0].enabled, false)
}

# Lifecycle Rules
output "lifecycle_rules" {
  description = "The lifecycle rules configured for the bucket"
  value       = google_storage_bucket.bucket.lifecycle_rule
}

output "lifecycle_rules_count" {
  description = "Number of lifecycle rules configured"
  value       = length(google_storage_bucket.bucket.lifecycle_rule)
}

# CORS
output "cors" {
  description = "The CORS configuration for the bucket"
  value       = google_storage_bucket.bucket.cors
}

# Website
output "website" {
  description = "The website configuration for the bucket"
  value       = google_storage_bucket.bucket.website
}

output "website_endpoint" {
  description = "The website endpoint if website hosting is enabled"
  value = try(
    google_storage_bucket.bucket.website[0].main_page_suffix != null ?
    "https://storage.googleapis.com/${google_storage_bucket.bucket.name}/${google_storage_bucket.bucket.website[0].main_page_suffix}" :
    null,
    null
  )
}

# Retention Policy
output "retention_policy" {
  description = "The retention policy configuration"
  value       = google_storage_bucket.bucket.retention_policy
}

output "retention_policy_is_locked" {
  description = "Whether the retention policy is locked"
  value       = try(google_storage_bucket.bucket.retention_policy[0].is_locked, false)
}

output "retention_period_seconds" {
  description = "The retention period in seconds"
  value       = try(google_storage_bucket.bucket.retention_policy[0].retention_period, null)
}

# Encryption
output "encryption" {
  description = "The encryption configuration"
  value       = google_storage_bucket.bucket.encryption
}

output "default_kms_key_name" {
  description = "The default KMS key used for encryption"
  value       = try(google_storage_bucket.bucket.encryption[0].default_kms_key_name, null)
}

# Logging
output "logging" {
  description = "The logging configuration"
  value       = google_storage_bucket.bucket.logging
}

# Autoclass
output "autoclass" {
  description = "The autoclass configuration"
  value       = google_storage_bucket.bucket.autoclass
}

output "autoclass_enabled" {
  description = "Whether autoclass is enabled"
  value       = try(google_storage_bucket.bucket.autoclass[0].enabled, false)
}

# Labels
output "labels" {
  description = "The labels attached to the bucket"
  value       = google_storage_bucket.bucket.labels
}

output "effective_labels" {
  description = "All labels attached to the bucket including system labels"
  value       = google_storage_bucket.bucket.effective_labels
}

# Objects
output "objects" {
  description = "Map of created objects in the bucket"
  value = {
    for k, v in google_storage_bucket_object.objects :
    k => {
      name          = v.name
      self_link     = v.self_link
      media_link    = v.media_link
      crc32c        = v.crc32c
      md5hash       = v.md5hash
      storage_class = v.storage_class
      size          = v.output_name
    }
  }
}

output "object_count" {
  description = "Number of objects created by this module"
  value       = length(google_storage_bucket_object.objects)
}

# IAM
output "iam_policy_etag" {
  description = "The etag of the IAM policy"
  value       = try(google_storage_bucket_iam_policy.policy[0].etag, null)
}

output "iam_bindings" {
  description = "The IAM bindings configured"
  value       = var.iam_bindings
}

output "iam_members" {
  description = "The individual IAM members configured"
  value = {
    for k, v in google_storage_bucket_iam_member.members :
    k => {
      role   = v.role
      member = v.member
      bucket = v.bucket
    }
  }
}

# ACLs
output "acl" {
  description = "The bucket ACL if configured"
  value       = try(google_storage_bucket_acl.acl[0], null)
}

output "default_object_acl" {
  description = "The default object ACL if configured"
  value       = try(google_storage_default_object_acl.default_acl[0], null)
}

# Notifications
output "notifications" {
  description = "Map of notification configurations"
  value = {
    for k, v in google_storage_notification.notifications :
    k => {
      id                 = v.id
      self_link          = v.self_link
      topic              = v.topic
      payload_format     = v.payload_format
      event_types        = v.event_types
      custom_attributes  = v.custom_attributes
      object_name_prefix = v.object_name_prefix
    }
  }
}

# Access URLs
output "console_url" {
  description = "Google Cloud Console URL for the bucket"
  value       = "https://console.cloud.google.com/storage/browser/${google_storage_bucket.bucket.name}?project=${var.project_id}"
}

output "gsutil_url" {
  description = "gsutil URL for the bucket"
  value       = "gs://${google_storage_bucket.bucket.name}"
}

output "api_endpoint" {
  description = "REST API endpoint for the bucket"
  value       = "https://storage.googleapis.com/storage/v1/b/${google_storage_bucket.bucket.name}"
}

# gsutil Commands
output "gsutil_commands" {
  description = "Useful gsutil commands for the bucket"
  value = {
    list_objects = "gsutil ls gs://${google_storage_bucket.bucket.name}"

    copy_to_bucket = "gsutil cp [LOCAL_FILE] gs://${google_storage_bucket.bucket.name}/"

    copy_from_bucket = "gsutil cp gs://${google_storage_bucket.bucket.name}/[OBJECT] [LOCAL_PATH]"

    sync_to_bucket = "gsutil -m rsync -r [LOCAL_DIR] gs://${google_storage_bucket.bucket.name}/"

    sync_from_bucket = "gsutil -m rsync -r gs://${google_storage_bucket.bucket.name}/ [LOCAL_DIR]"

    bucket_info = "gsutil ls -L -b gs://${google_storage_bucket.bucket.name}"

    set_public = "gsutil iam ch allUsers:objectViewer gs://${google_storage_bucket.bucket.name}"

    enable_versioning = "gsutil versioning set on gs://${google_storage_bucket.bucket.name}"

    enable_lifecycle = "gsutil lifecycle set [CONFIG_FILE] gs://${google_storage_bucket.bucket.name}"
  }
}

# Terraform Import Commands
output "import_commands" {
  description = "Terraform import commands for this bucket"
  value = {
    bucket = "terraform import google_storage_bucket.bucket ${var.project_id}/${google_storage_bucket.bucket.name}"

    iam_policy = var.iam_policy != null ? "terraform import google_storage_bucket_iam_policy.policy ${google_storage_bucket.bucket.name}" : null

    iam_binding = length(var.iam_bindings) > 0 ? "terraform import 'google_storage_bucket_iam_binding.bindings[\\\"ROLE\\\"]' '${google_storage_bucket.bucket.name} ROLE'" : null
  }
}