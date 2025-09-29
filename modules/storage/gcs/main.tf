# Google Cloud Storage Bucket Module
# Creates and manages GCS buckets with comprehensive configuration

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

locals {
  # Bucket name with optional random suffix
  bucket_name = var.name != null ? var.name : "${var.name_prefix}-${random_id.bucket_suffix[0].hex}"

  # Labels with defaults
  labels = merge(
    var.labels,
    {
      managed_by  = "terraform"
      module      = "gcs"
      environment = var.environment
      created_at  = formatdate("YYYY-MM-DD", timestamp())
    }
  )

  # Lifecycle rules with defaults
  lifecycle_rules = concat(
    var.lifecycle_rules,
    var.enable_default_lifecycle_rules ? [
      {
        action = {
          type          = "SetStorageClass"
          storage_class = "NEARLINE"
        }
        condition = {
          age = 30
        }
      },
      {
        action = {
          type          = "SetStorageClass"
          storage_class = "COLDLINE"
        }
        condition = {
          age = 90
        }
      },
      {
        action = {
          type          = "SetStorageClass"
          storage_class = "ARCHIVE"
        }
        condition = {
          age = 365
        }
      }
    ] : []
  )

  # CORS configuration with defaults
  cors = var.cors != null ? var.cors : (
    var.enable_default_cors ? [{
      origin          = ["*"]
      method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
      response_header = ["*"]
      max_age_seconds = 3600
    }] : []
  )

  # Website configuration
  website = var.website != null ? var.website : (
    var.enable_website ? {
      main_page_suffix = var.website_main_page_suffix
      not_found_page   = var.website_not_found_page
    } : null
  )

  # Retention policy
  retention_policy = var.retention_policy != null ? var.retention_policy : (
    var.retention_days != null ? {
      retention_period = var.retention_days * 86400 # Convert days to seconds
      is_locked        = var.retention_policy_is_locked
    } : null
  )

  # Encryption
  encryption = var.encryption != null ? var.encryption : (
    var.kms_key_name != null ? {
      default_kms_key_name = var.kms_key_name
    } : null
  )
}

# Random suffix for bucket naming
resource "random_id" "bucket_suffix" {
  count       = var.name == null ? 1 : 0
  byte_length = 4

  keepers = {
    project_id = var.project_id
    location   = var.location
  }
}

# Main storage bucket
resource "google_storage_bucket" "bucket" {
  provider = google-beta

  project                     = var.project_id
  name                        = local.bucket_name
  location                    = var.location
  storage_class               = var.storage_class
  force_destroy               = var.force_destroy
  uniform_bucket_level_access = var.uniform_bucket_level_access
  public_access_prevention    = var.public_access_prevention
  requester_pays              = var.requester_pays
  default_event_based_hold    = var.default_event_based_hold

  # Versioning configuration
  dynamic "versioning" {
    for_each = var.versioning != null ? [var.versioning] : []
    content {
      enabled = versioning.value
    }
  }

  # Lifecycle rules
  dynamic "lifecycle_rule" {
    for_each = local.lifecycle_rules
    content {
      dynamic "action" {
        for_each = [lifecycle_rule.value.action]
        content {
          type          = action.value.type
          storage_class = lookup(action.value, "storage_class", null)
        }
      }

      dynamic "condition" {
        for_each = [lifecycle_rule.value.condition]
        content {
          age                        = lookup(condition.value, "age", null)
          created_before             = lookup(condition.value, "created_before", null)
          custom_time_before         = lookup(condition.value, "custom_time_before", null)
          days_since_custom_time     = lookup(condition.value, "days_since_custom_time", null)
          days_since_noncurrent_time = lookup(condition.value, "days_since_noncurrent_time", null)
          noncurrent_time_before     = lookup(condition.value, "noncurrent_time_before", null)
          num_newer_versions         = lookup(condition.value, "num_newer_versions", null)
          matches_prefix             = lookup(condition.value, "matches_prefix", null)
          matches_suffix             = lookup(condition.value, "matches_suffix", null)
          matches_storage_class      = lookup(condition.value, "matches_storage_class", null)
          with_state                 = lookup(condition.value, "with_state", null)
        }
      }
    }
  }

  # CORS configuration
  dynamic "cors" {
    for_each = local.cors
    content {
      origin          = cors.value.origin
      method          = cors.value.method
      response_header = lookup(cors.value, "response_header", null)
      max_age_seconds = lookup(cors.value, "max_age_seconds", 3600)
    }
  }

  # Website configuration
  dynamic "website" {
    for_each = local.website != null ? [local.website] : []
    content {
      main_page_suffix = website.value.main_page_suffix
      not_found_page   = lookup(website.value, "not_found_page", null)
    }
  }

  # Retention policy
  dynamic "retention_policy" {
    for_each = local.retention_policy != null ? [local.retention_policy] : []
    content {
      retention_period = retention_policy.value.retention_period
      is_locked        = lookup(retention_policy.value, "is_locked", false)
    }
  }

  # Encryption
  dynamic "encryption" {
    for_each = local.encryption != null ? [local.encryption] : []
    content {
      default_kms_key_name = encryption.value.default_kms_key_name
    }
  }

  # Logging
  dynamic "logging" {
    for_each = var.logging != null ? [var.logging] : []
    content {
      log_bucket        = logging.value.log_bucket
      log_object_prefix = lookup(logging.value, "log_object_prefix", null)
    }
  }

  # Autoclass
  dynamic "autoclass" {
    for_each = var.autoclass != null ? [var.autoclass] : []
    content {
      enabled                = autoclass.value.enabled
      terminal_storage_class = lookup(autoclass.value, "terminal_storage_class", null)
    }
  }

  # Custom placement config
  dynamic "custom_placement_config" {
    for_each = var.custom_placement_config != null ? [var.custom_placement_config] : []
    content {
      data_locations = custom_placement_config.value.data_locations
    }
  }

  labels = local.labels

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }

  depends_on = [var.module_depends_on]
}

# Bucket IAM Policy
resource "google_storage_bucket_iam_policy" "policy" {
  count = var.iam_policy != null ? 1 : 0

  bucket      = google_storage_bucket.bucket.name
  policy_data = var.iam_policy

  depends_on = [google_storage_bucket.bucket]
}

# Bucket IAM Bindings
resource "google_storage_bucket_iam_binding" "bindings" {
  for_each = var.iam_bindings

  bucket  = google_storage_bucket.bucket.name
  role    = each.key
  members = each.value

  dynamic "condition" {
    for_each = var.iam_binding_conditions[each.key] != null ? [var.iam_binding_conditions[each.key]] : []
    content {
      title       = condition.value.title
      description = lookup(condition.value, "description", null)
      expression  = condition.value.expression
    }
  }

  depends_on = [google_storage_bucket.bucket]
}

# Bucket IAM Members
resource "google_storage_bucket_iam_member" "members" {
  for_each = var.iam_members

  bucket = google_storage_bucket.bucket.name
  role   = each.value.role
  member = each.value.member

  dynamic "condition" {
    for_each = lookup(each.value, "condition", null) != null ? [each.value.condition] : []
    content {
      title       = condition.value.title
      description = lookup(condition.value, "description", null)
      expression  = condition.value.expression
    }
  }

  depends_on = [google_storage_bucket.bucket]
}

# Bucket ACLs (if not using uniform bucket level access)
resource "google_storage_bucket_acl" "acl" {
  count = !var.uniform_bucket_level_access && var.predefined_acl != null ? 1 : 0

  bucket         = google_storage_bucket.bucket.name
  predefined_acl = var.predefined_acl

  dynamic "role_entity" {
    for_each = var.role_entities
    content {
      role   = role_entity.value.role
      entity = role_entity.value.entity
    }
  }

  depends_on = [google_storage_bucket.bucket]
}

# Default Object ACL
resource "google_storage_default_object_acl" "default_acl" {
  count = !var.uniform_bucket_level_access && var.default_acl != null ? 1 : 0

  bucket = google_storage_bucket.bucket.name

  dynamic "role_entity" {
    for_each = var.default_acl
    content {
      role   = role_entity.value.role
      entity = role_entity.value.entity
    }
  }

  depends_on = [google_storage_bucket.bucket]
}

# Bucket Objects (optional)
resource "google_storage_bucket_object" "objects" {
  for_each = var.objects

  bucket        = google_storage_bucket.bucket.name
  name          = each.key
  source        = lookup(each.value, "source", null)
  content       = lookup(each.value, "content", null)
  content_type  = lookup(each.value, "content_type", null)
  storage_class = lookup(each.value, "storage_class", null)

  cache_control       = lookup(each.value, "cache_control", null)
  content_disposition = lookup(each.value, "content_disposition", null)
  content_encoding    = lookup(each.value, "content_encoding", null)
  content_language    = lookup(each.value, "content_language", null)

  event_based_hold = lookup(each.value, "event_based_hold", null)
  temporary_hold   = lookup(each.value, "temporary_hold", null)

  kms_key_name = lookup(each.value, "kms_key_name", null)

  metadata = lookup(each.value, "metadata", null)

  depends_on = [google_storage_bucket.bucket]
}

# Notification Configuration
resource "google_storage_notification" "notifications" {
  for_each = var.notifications

  bucket             = google_storage_bucket.bucket.name
  payload_format     = lookup(each.value, "payload_format", "JSON_API_V1")
  topic              = each.value.topic
  event_types        = lookup(each.value, "event_types", null)
  custom_attributes  = lookup(each.value, "custom_attributes", null)
  object_name_prefix = lookup(each.value, "object_name_prefix", null)

  depends_on = [google_storage_bucket.bucket]
}