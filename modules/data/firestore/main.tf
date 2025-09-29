# Firestore Module
# Provides comprehensive Firestore database management with security rules, indexes, and monitoring

terraform {
  required_version = ">= 1.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.0"
    }
  }
}

# Local values for resource naming and configuration
locals {
  name_prefix = var.name_prefix != null ? var.name_prefix : "firestore"
  environment = var.environment != null ? var.environment : "dev"

  # Common labels to apply to all resources
  default_labels = merge(var.labels, {
    module      = "firestore"
    environment = local.environment
    managed_by  = "terraform"
  })

  # Database configuration with defaults
  database_config = merge({
    name                              = "${local.name_prefix}-${local.environment}"
    location_id                       = var.region
    type                              = "FIRESTORE_NATIVE"
    concurrency_mode                  = "OPTIMISTIC"
    app_engine_integration_mode       = "DISABLED"
    point_in_time_recovery_enablement = "POINT_IN_TIME_RECOVERY_ENABLED"
    delete_protection_state           = "DELETE_PROTECTION_ENABLED"
  }, var.database_config)

  # Security rules configuration
  security_rules_content = var.security_rules_content != null ? var.security_rules_content : <<-EOT
    rules_version = '2';
    service cloud.firestore {
      match /databases/{database}/documents {
        // Default deny-all rule for security
        match /{document=**} {
          allow read, write: if false;
        }

        // Allow authenticated users to read/write their own data
        match /users/{userId} {
          allow read, write: if request.auth != null && request.auth.uid == userId;
        }

        // Public read access for certain collections
        match /public/{document} {
          allow read: if true;
          allow write: if request.auth != null;
        }

        // Admin access for service accounts
        match /{document=**} {
          allow read, write: if request.auth != null &&
            request.auth.token.email.matches('.*@${var.project_id}.iam.gserviceaccount.com');
        }
      }
    }
  EOT

  # Index configurations with validation
  validated_indexes = [
    for idx in var.indexes : merge({
      collection  = idx.collection
      query_scope = "COLLECTION"
      api_scope   = "ANY_API"
      fields = [
        for field in idx.fields : merge({
          field_path   = field.field_path
          order        = "ASCENDING"
          array_config = null
        }, field)
      ]
    }, idx)
  ]

  # TTL policies configuration
  ttl_policies = [
    for policy in var.ttl_policies : merge({
      collection = policy.collection
      field      = policy.field
      state      = "ACTIVE"
    }, policy)
  ]
}

# Data source for project information
data "google_project" "current" {
  project_id = var.project_id
}

# Create Firestore database
resource "google_firestore_database" "database" {
  provider = google-beta

  project                           = var.project_id
  name                              = local.database_config.name
  location_id                       = local.database_config.location_id
  type                              = local.database_config.type
  concurrency_mode                  = local.database_config.concurrency_mode
  app_engine_integration_mode       = local.database_config.app_engine_integration_mode
  point_in_time_recovery_enablement = local.database_config.point_in_time_recovery_enablement
  delete_protection_state           = local.database_config.delete_protection_state

  depends_on = [
    google_project_service.firestore_api
  ]
}

# Enable Firestore API
resource "google_project_service" "firestore_api" {
  project = var.project_id
  service = "firestore.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

# Service account for Firestore operations
resource "google_service_account" "firestore" {
  count = var.create_service_account ? 1 : 0

  project      = var.project_id
  account_id   = var.service_account_name != null ? var.service_account_name : "${local.name_prefix}-${local.environment}"
  display_name = "Firestore Service Account for ${title(local.environment)}"
  description  = "Service account for Firestore operations in ${local.environment} environment"
}

# IAM role bindings for service account
resource "google_project_iam_member" "firestore_roles" {
  for_each = var.create_service_account && var.grant_service_account_roles ? toset(var.service_account_roles) : toset([])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.firestore[0].email}"

  depends_on = [google_service_account.firestore]
}

# Firestore security rules
resource "google_firestore_ruleset" "rules" {
  count = var.deploy_security_rules ? 1 : 0

  project = var.project_id
  source {
    files {
      content = local.security_rules_content
      name    = "firestore.rules"
    }
  }

  depends_on = [google_firestore_database.database]
}

# Release security rules to the database
resource "google_firestore_release" "rules_release" {
  count = var.deploy_security_rules ? 1 : 0

  project  = var.project_id
  database = google_firestore_database.database.name
  ruleset  = google_firestore_ruleset.rules[0].name

  depends_on = [google_firestore_ruleset.rules]
}

# Firestore indexes
resource "google_firestore_index" "indexes" {
  for_each = { for idx, config in local.validated_indexes : idx => config }

  project     = var.project_id
  database    = google_firestore_database.database.name
  collection  = each.value.collection
  query_scope = each.value.query_scope
  api_scope   = each.value.api_scope

  dynamic "fields" {
    for_each = each.value.fields
    content {
      field_path   = fields.value.field_path
      order        = fields.value.order
      array_config = fields.value.array_config
    }
  }

  depends_on = [google_firestore_database.database]
}

# Firestore TTL policies
resource "google_firestore_field" "ttl_fields" {
  for_each = { for idx, policy in local.ttl_policies : idx => policy }

  project    = var.project_id
  database   = google_firestore_database.database.name
  collection = each.value.collection
  field      = each.value.field

  ttl_config {
    state = each.value.state
  }

  depends_on = [google_firestore_database.database]
}

# Backup schedules for Firestore
resource "google_firestore_backup_schedule" "backup_schedules" {
  for_each = var.enable_backups ? var.backup_schedules : {}

  project  = var.project_id
  database = google_firestore_database.database.name

  retention = each.value.retention

  dynamic "daily_recurrence" {
    for_each = each.value.schedule_type == "daily" ? [1] : []
    content {}
  }

  dynamic "weekly_recurrence" {
    for_each = each.value.schedule_type == "weekly" ? [1] : []
    content {
      day = each.value.day_of_week
    }
  }

  depends_on = [google_firestore_database.database]
}

# IAM bindings for Firestore database
resource "google_firestore_database_iam_member" "database_iam" {
  for_each = var.database_iam_bindings

  project  = var.project_id
  database = google_firestore_database.database.name
  role     = each.value.role
  member   = each.value.member

  depends_on = [google_firestore_database.database]
}

# Document creation for initial data (optional)
resource "google_firestore_document" "initial_documents" {
  for_each = var.create_initial_documents ? var.initial_documents : {}

  project     = var.project_id
  database    = google_firestore_database.database.name
  collection  = each.value.collection
  document_id = each.key
  fields      = jsonencode(each.value.fields)

  depends_on = [google_firestore_database.database]
}

# Monitoring alert policies for Firestore
resource "google_monitoring_alert_policy" "firestore_alerts" {
  for_each = var.create_monitoring_alerts ? var.monitoring_alerts : {}

  project      = var.project_id
  display_name = each.value.display_name
  enabled      = each.value.enabled != null ? each.value.enabled : true
  combiner     = each.value.combiner != null ? each.value.combiner : "OR"

  conditions {
    display_name = each.value.condition_display_name

    condition_threshold {
      filter          = each.value.filter
      duration        = each.value.duration != null ? each.value.duration : "300s"
      comparison      = each.value.comparison != null ? each.value.comparison : "COMPARISON_GREATER_THAN"
      threshold_value = each.value.threshold_value

      aggregations {
        alignment_period     = each.value.alignment_period != null ? each.value.alignment_period : "300s"
        per_series_aligner   = each.value.per_series_aligner != null ? each.value.per_series_aligner : "ALIGN_RATE"
        cross_series_reducer = each.value.cross_series_reducer != null ? each.value.cross_series_reducer : "REDUCE_SUM"
        group_by_fields      = each.value.group_by_fields
      }

      dynamic "trigger" {
        for_each = each.value.trigger_count != null || each.value.trigger_percent != null ? [1] : []
        content {
          count   = each.value.trigger_count
          percent = each.value.trigger_percent
        }
      }
    }
  }

  dynamic "notification_channels" {
    for_each = each.value.notification_channels != null ? [1] : []
    content {
      notification_channels = each.value.notification_channels
    }
  }

  auto_close = each.value.auto_close != null ? each.value.auto_close : "86400s"

  dynamic "alert_strategy" {
    for_each = each.value.rate_limit != null ? [1] : []
    content {
      notification_rate_limit {
        period = each.value.rate_limit.period
      }
    }
  }

  dynamic "documentation" {
    for_each = each.value.documentation_content != null ? [1] : []
    content {
      content   = each.value.documentation_content
      mime_type = each.value.documentation_mime_type != null ? each.value.documentation_mime_type : "text/markdown"
      subject   = each.value.documentation_subject
    }
  }

  user_labels = merge(local.default_labels, each.value.labels != null ? each.value.labels : {})
}

# Monitoring dashboard for Firestore
resource "google_monitoring_dashboard" "firestore" {
  count = var.create_monitoring_dashboard ? 1 : 0

  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "Firestore - ${title(local.environment)}"
    mosaicLayout = {
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Document Reads/Writes"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"firestore_database\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"firestore.googleapis.com/api/request_count\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.labels.op_type"]
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          widget = {
            title = "Database Size"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"firestore_database\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"firestore.googleapis.com/database/document_count\""
                    aggregation = {
                      alignmentPeriod    = "300s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
                plotType = "STACKED_AREA"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          yPos   = 4
          widget = {
            title = "Request Latency"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"firestore_database\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"firestore.googleapis.com/api/request_latencies\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_DELTA"
                      crossSeriesReducer = "REDUCE_PERCENTILE_95"
                      groupByFields      = ["metric.labels.op_type"]
                    }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          yPos   = 4
          widget = {
            title = "Security Rule Evaluations"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"firestore_database\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"firestore.googleapis.com/rules/request_count\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.labels.result"]
                    }
                  }
                }
                plotType = "STACKED_BAR"
              }]
            }
          }
        }
      ]
    }
  })
}

# Log-based metrics for custom monitoring
resource "google_logging_metric" "firestore_metrics" {
  for_each = var.create_log_metrics ? var.log_metrics : {}

  project = var.project_id
  name    = each.key
  filter  = each.value.filter

  dynamic "label_extractors" {
    for_each = each.value.label_extractors != null ? each.value.label_extractors : {}
    content {
      key   = label_extractors.key
      value = label_extractors.value
    }
  }

  dynamic "metric_descriptor" {
    for_each = each.value.metric_descriptor != null ? [1] : []
    content {
      metric_kind  = each.value.metric_descriptor.metric_kind
      value_type   = each.value.metric_descriptor.value_type
      unit         = each.value.metric_descriptor.unit
      display_name = each.value.metric_descriptor.display_name

      dynamic "labels" {
        for_each = each.value.metric_descriptor.labels != null ? each.value.metric_descriptor.labels : []
        content {
          key         = labels.value.key
          value_type  = labels.value.value_type
          description = labels.value.description
        }
      }
    }
  }

  dynamic "bucket_options" {
    for_each = each.value.bucket_options != null ? [1] : []
    content {
      dynamic "linear_buckets" {
        for_each = each.value.bucket_options.linear_buckets != null ? [1] : []
        content {
          num_finite_buckets = each.value.bucket_options.linear_buckets.num_finite_buckets
          width              = each.value.bucket_options.linear_buckets.width
          offset             = each.value.bucket_options.linear_buckets.offset
        }
      }

      dynamic "exponential_buckets" {
        for_each = each.value.bucket_options.exponential_buckets != null ? [1] : []
        content {
          num_finite_buckets = each.value.bucket_options.exponential_buckets.num_finite_buckets
          growth_factor      = each.value.bucket_options.exponential_buckets.growth_factor
          scale              = each.value.bucket_options.exponential_buckets.scale
        }
      }
    }
  }
}

# Data export configurations
resource "google_bigquery_dataset" "firestore_export" {
  count = var.enable_bigquery_export ? 1 : 0

  project    = var.project_id
  dataset_id = "${local.name_prefix}_export_${local.environment}"
  location   = var.bigquery_export_location

  description                     = "BigQuery dataset for Firestore exports"
  default_table_expiration_ms     = var.bigquery_table_expiration_ms
  delete_contents_on_destroy      = false
  default_partition_expiration_ms = var.bigquery_partition_expiration_ms

  labels = local.default_labels

  dynamic "access" {
    for_each = var.bigquery_access_config
    content {
      role           = access.value.role
      user_by_email  = access.value.user_by_email
      group_by_email = access.value.group_by_email
      special_group  = access.value.special_group
    }
  }
}

# Cloud Function for data processing (optional)
resource "google_cloudfunctions_function" "data_processor" {
  for_each = var.create_data_processors ? var.data_processors : {}

  project = var.project_id
  region  = var.region
  name    = "${local.name_prefix}-${each.key}-processor-${local.environment}"

  runtime               = each.value.runtime
  entry_point           = each.value.entry_point
  source_archive_bucket = each.value.source_bucket
  source_archive_object = each.value.source_object

  event_trigger {
    event_type = "providers/cloud.firestore/eventTypes/document.write"
    resource   = "projects/${var.project_id}/databases/${google_firestore_database.database.name}/documents/${each.value.trigger_path}"
  }

  environment_variables = merge(
    each.value.environment_variables,
    {
      FIRESTORE_DATABASE = google_firestore_database.database.name
      PROJECT_ID         = var.project_id
    }
  )

  available_memory_mb = each.value.memory_mb
  timeout             = each.value.timeout_seconds

  labels = merge(local.default_labels, each.value.labels != null ? each.value.labels : {})

  depends_on = [google_firestore_database.database]
}