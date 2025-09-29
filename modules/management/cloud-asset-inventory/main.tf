# Cloud Asset Inventory Module - Main Configuration

# Enable required APIs
resource "google_project_service" "asset_inventory_apis" {
  for_each = var.enable_apis ? toset([
    "cloudasset.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "bigquery.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "securitycenter.googleapis.com"
  ]) : toset([])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# Cloud Asset Inventory feeds for real-time asset changes
resource "google_cloud_asset_project_feed" "asset_feeds" {
  for_each = var.asset_feeds

  project      = var.project_id
  feed_id      = each.key
  content_type = each.value.content_type

  asset_types  = each.value.asset_types
  asset_names  = each.value.asset_names

  feed_output_config {
    pubsub_destination {
      topic = each.value.pubsub_topic
    }
  }

  dynamic "condition" {
    for_each = each.value.condition != null ? [each.value.condition] : []
    content {
      expression  = condition.value.expression
      title       = condition.value.title
      description = condition.value.description
      location    = condition.value.location
    }
  }

  relationship_types = each.value.relationship_types

  depends_on = [
    google_project_service.asset_inventory_apis
  ]
}

# Organization-level asset feeds (if org_id is provided)
resource "google_cloud_asset_organization_feed" "org_asset_feeds" {
  for_each = var.org_id != null ? var.org_asset_feeds : {}

  org_id       = var.org_id
  feed_id      = each.key
  content_type = each.value.content_type

  asset_types  = each.value.asset_types
  asset_names  = each.value.asset_names

  feed_output_config {
    pubsub_destination {
      topic = each.value.pubsub_topic
    }
  }

  dynamic "condition" {
    for_each = each.value.condition != null ? [each.value.condition] : []
    content {
      expression  = condition.value.expression
      title       = condition.value.title
      description = condition.value.description
      location    = condition.value.location
    }
  }

  relationship_types = each.value.relationship_types

  depends_on = [
    google_project_service.asset_inventory_apis
  ]
}

# Folder-level asset feeds
resource "google_cloud_asset_folder_feed" "folder_asset_feeds" {
  for_each = var.folder_asset_feeds

  folder       = each.value.folder_id
  feed_id      = each.key
  content_type = each.value.content_type

  asset_types  = each.value.asset_types
  asset_names  = each.value.asset_names

  feed_output_config {
    pubsub_destination {
      topic = each.value.pubsub_topic
    }
  }

  dynamic "condition" {
    for_each = each.value.condition != null ? [each.value.condition] : []
    content {
      expression  = condition.value.expression
      title       = condition.value.title
      description = condition.value.description
      location    = condition.value.location
    }
  }

  relationship_types = each.value.relationship_types

  depends_on = [
    google_project_service.asset_inventory_apis
  ]
}

# Pub/Sub topics for asset feeds
resource "google_pubsub_topic" "asset_feed_topics" {
  for_each = var.create_pubsub_topics ? var.pubsub_topics : {}

  name    = each.key
  project = var.project_id

  dynamic "message_storage_policy" {
    for_each = each.value.message_storage_policy != null ? [each.value.message_storage_policy] : []
    content {
      allowed_persistence_regions = message_storage_policy.value.allowed_persistence_regions
    }
  }

  message_retention_duration = each.value.message_retention_duration
  kms_key_name              = each.value.kms_key_name

  labels = merge(var.labels, each.value.labels)

  depends_on = [
    google_project_service.asset_inventory_apis
  ]
}

# Pub/Sub subscriptions for asset feeds
resource "google_pubsub_subscription" "asset_feed_subscriptions" {
  for_each = var.create_pubsub_subscriptions ? var.pubsub_subscriptions : {}

  name  = each.key
  topic = google_pubsub_topic.asset_feed_topics[each.value.topic_name].name
  project = var.project_id

  ack_deadline_seconds       = each.value.ack_deadline_seconds
  message_retention_duration = each.value.message_retention_duration
  retain_acked_messages     = each.value.retain_acked_messages
  enable_message_ordering   = each.value.enable_message_ordering

  dynamic "expiration_policy" {
    for_each = each.value.expiration_policy != null ? [each.value.expiration_policy] : []
    content {
      ttl = expiration_policy.value.ttl
    }
  }

  filter = each.value.filter

  dynamic "push_config" {
    for_each = each.value.push_config != null ? [each.value.push_config] : []
    content {
      push_endpoint = push_config.value.push_endpoint
      attributes    = push_config.value.attributes

      dynamic "oidc_token" {
        for_each = push_config.value.oidc_token != null ? [push_config.value.oidc_token] : []
        content {
          service_account_email = oidc_token.value.service_account_email
          audience             = oidc_token.value.audience
        }
      }
    }
  }

  dynamic "retry_policy" {
    for_each = each.value.retry_policy != null ? [each.value.retry_policy] : []
    content {
      minimum_backoff = retry_policy.value.minimum_backoff
      maximum_backoff = retry_policy.value.maximum_backoff
    }
  }

  dynamic "dead_letter_policy" {
    for_each = each.value.dead_letter_policy != null ? [each.value.dead_letter_policy] : []
    content {
      dead_letter_topic     = dead_letter_policy.value.dead_letter_topic
      max_delivery_attempts = dead_letter_policy.value.max_delivery_attempts
    }
  }

  labels = merge(var.labels, each.value.labels)

  depends_on = [
    google_pubsub_topic.asset_feed_topics
  ]
}

# BigQuery dataset for asset inventory exports
resource "google_bigquery_dataset" "asset_inventory_dataset" {
  count = var.enable_bigquery_export ? 1 : 0

  dataset_id  = var.bigquery_dataset_id
  project     = var.project_id
  location    = var.bigquery_location
  description = "Dataset for Cloud Asset Inventory exports and analysis"

  default_table_expiration_ms = var.bigquery_table_expiration_ms
  default_partition_expiration_ms = var.bigquery_partition_expiration_ms

  delete_contents_on_destroy = var.delete_dataset_on_destroy

  dynamic "access" {
    for_each = var.bigquery_dataset_access
    content {
      role          = access.value.role
      user_by_email = access.value.user_by_email
      group_by_email = access.value.group_by_email
      domain        = access.value.domain
      special_group = access.value.special_group

      dynamic "dataset" {
        for_each = access.value.dataset != null ? [access.value.dataset] : []
        content {
          dataset {
            project_id = dataset.value.project_id
            dataset_id = dataset.value.dataset_id
          }
          target_types = dataset.value.target_types
        }
      }

      dynamic "routine" {
        for_each = access.value.routine != null ? [access.value.routine] : []
        content {
          project_id = routine.value.project_id
          dataset_id = routine.value.dataset_id
          routine_id = routine.value.routine_id
        }
      }

      dynamic "view" {
        for_each = access.value.view != null ? [access.value.view] : []
        content {
          project_id = view.value.project_id
          dataset_id = view.value.dataset_id
          table_id   = view.value.table_id
        }
      }
    }
  }

  labels = merge(var.labels, var.bigquery_dataset_labels)

  depends_on = [
    google_project_service.asset_inventory_apis
  ]
}

# BigQuery tables for specific asset types
resource "google_bigquery_table" "asset_tables" {
  for_each = var.enable_bigquery_export ? var.bigquery_tables : {}

  dataset_id = google_bigquery_dataset.asset_inventory_dataset[0].dataset_id
  table_id   = each.key
  project    = var.project_id

  description = each.value.description

  dynamic "time_partitioning" {
    for_each = each.value.time_partitioning != null ? [each.value.time_partitioning] : []
    content {
      type                     = time_partitioning.value.type
      expiration_ms           = time_partitioning.value.expiration_ms
      field                   = time_partitioning.value.field
      require_partition_filter = time_partitioning.value.require_partition_filter
    }
  }

  dynamic "range_partitioning" {
    for_each = each.value.range_partitioning != null ? [each.value.range_partitioning] : []
    content {
      field = range_partitioning.value.field
      range {
        start    = range_partitioning.value.range.start
        end      = range_partitioning.value.range.end
        interval = range_partitioning.value.range.interval
      }
    }
  }

  dynamic "clustering" {
    for_each = each.value.clustering != null ? [each.value.clustering] : []
    content {
      fields = clustering.value.fields
    }
  }

  schema = each.value.schema

  labels = merge(var.labels, each.value.labels)

  depends_on = [
    google_bigquery_dataset.asset_inventory_dataset
  ]
}

# Cloud Storage bucket for asset exports
resource "google_storage_bucket" "asset_export_bucket" {
  count = var.enable_storage_export ? 1 : 0

  name     = var.storage_bucket_name
  location = var.storage_bucket_location
  project  = var.project_id

  force_destroy = var.force_destroy_bucket

  uniform_bucket_level_access = var.uniform_bucket_level_access

  dynamic "versioning" {
    for_each = var.bucket_versioning_enabled ? [1] : []
    content {
      enabled = true
    }
  }

  dynamic "lifecycle_rule" {
    for_each = var.bucket_lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action.type
        storage_class = lifecycle_rule.value.action.storage_class
      }

      condition {
        age                        = lifecycle_rule.value.condition.age
        created_before            = lifecycle_rule.value.condition.created_before
        with_state                = lifecycle_rule.value.condition.with_state
        matches_storage_class     = lifecycle_rule.value.condition.matches_storage_class
        num_newer_versions        = lifecycle_rule.value.condition.num_newer_versions
        custom_time_before        = lifecycle_rule.value.condition.custom_time_before
        days_since_custom_time    = lifecycle_rule.value.condition.days_since_custom_time
        days_since_noncurrent_time = lifecycle_rule.value.condition.days_since_noncurrent_time
        noncurrent_time_before    = lifecycle_rule.value.condition.noncurrent_time_before
      }
    }
  }

  dynamic "retention_policy" {
    for_each = var.bucket_retention_policy != null ? [var.bucket_retention_policy] : []
    content {
      is_locked        = retention_policy.value.is_locked
      retention_period = retention_policy.value.retention_period
    }
  }

  dynamic "encryption" {
    for_each = var.bucket_encryption_key != null ? [1] : []
    content {
      default_kms_key_name = var.bucket_encryption_key
    }
  }

  dynamic "logging" {
    for_each = var.bucket_logging_config != null ? [var.bucket_logging_config] : []
    content {
      log_bucket        = logging.value.log_bucket
      log_object_prefix = logging.value.log_object_prefix
    }
  }

  labels = merge(var.labels, var.storage_bucket_labels)

  depends_on = [
    google_project_service.asset_inventory_apis
  ]
}

# Service account for asset inventory operations
resource "google_service_account" "asset_inventory_sa" {
  count = var.create_service_account ? 1 : 0

  account_id   = var.service_account_id
  display_name = "Cloud Asset Inventory Service Account"
  description  = "Service account for Cloud Asset Inventory operations and exports"
  project      = var.project_id
}

# IAM roles for the service account
resource "google_project_iam_member" "asset_inventory_sa_roles" {
  for_each = var.create_service_account ? toset(var.service_account_roles) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.asset_inventory_sa[0].email}"

  depends_on = [
    google_service_account.asset_inventory_sa
  ]
}

# Cloud Functions for asset processing (if enabled)
resource "google_cloudfunctions_function" "asset_processor" {
  for_each = var.enable_cloud_functions ? var.cloud_functions : {}

  name        = each.key
  project     = var.project_id
  region      = each.value.region
  description = each.value.description

  runtime             = each.value.runtime
  available_memory_mb = each.value.memory_mb
  timeout             = each.value.timeout
  entry_point         = each.value.entry_point
  service_account_email = var.create_service_account ? google_service_account.asset_inventory_sa[0].email : each.value.service_account_email

  source_archive_bucket = each.value.source_bucket
  source_archive_object = each.value.source_object

  dynamic "event_trigger" {
    for_each = each.value.event_trigger != null ? [each.value.event_trigger] : []
    content {
      event_type = event_trigger.value.event_type
      resource   = event_trigger.value.resource

      dynamic "failure_policy" {
        for_each = event_trigger.value.failure_policy_retry ? [1] : []
        content {
          retry = true
        }
      }
    }
  }

  dynamic "https_trigger" {
    for_each = each.value.https_trigger_enabled ? [1] : []
    content {
      security_level = each.value.https_security_level
    }
  }

  environment_variables = each.value.environment_variables

  labels = merge(var.labels, each.value.labels)

  depends_on = [
    google_project_service.asset_inventory_apis,
    google_service_account.asset_inventory_sa
  ]
}

# Cloud Scheduler jobs for periodic asset exports
resource "google_cloud_scheduler_job" "asset_export_jobs" {
  for_each = var.enable_scheduled_exports ? var.scheduled_export_jobs : {}

  name     = each.key
  project  = var.project_id
  region   = each.value.region
  schedule = each.value.schedule
  time_zone = each.value.time_zone
  description = each.value.description

  dynamic "pubsub_target" {
    for_each = each.value.pubsub_target != null ? [each.value.pubsub_target] : []
    content {
      topic_name = pubsub_target.value.topic_name
      data       = pubsub_target.value.data
      attributes = pubsub_target.value.attributes
    }
  }

  dynamic "http_target" {
    for_each = each.value.http_target != null ? [each.value.http_target] : []
    content {
      uri         = http_target.value.uri
      http_method = http_target.value.http_method
      body        = http_target.value.body
      headers     = http_target.value.headers

      dynamic "oauth_token" {
        for_each = http_target.value.oauth_token != null ? [http_target.value.oauth_token] : []
        content {
          service_account_email = oauth_token.value.service_account_email
          scope                = oauth_token.value.scope
        }
      }

      dynamic "oidc_token" {
        for_each = http_target.value.oidc_token != null ? [http_target.value.oidc_token] : []
        content {
          service_account_email = oidc_token.value.service_account_email
          audience             = oidc_token.value.audience
        }
      }
    }
  }

  dynamic "retry_config" {
    for_each = each.value.retry_config != null ? [each.value.retry_config] : []
    content {
      retry_count          = retry_config.value.retry_count
      max_retry_duration   = retry_config.value.max_retry_duration
      min_backoff_duration = retry_config.value.min_backoff_duration
      max_backoff_duration = retry_config.value.max_backoff_duration
      max_doublings        = retry_config.value.max_doublings
    }
  }

  depends_on = [
    google_project_service.asset_inventory_apis
  ]
}

# Monitoring dashboard for asset inventory
resource "google_monitoring_dashboard" "asset_inventory_dashboard" {
  count = var.enable_monitoring && var.create_dashboard ? 1 : 0

  dashboard_json = jsonencode({
    displayName = var.dashboard_display_name
    mosaicLayout = {
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Asset Feed Messages"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"pubsub_topic\" AND metric.type=\"pubsub.googleapis.com/topic/send_message_operation_count\""
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Messages/sec"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "BigQuery Export Jobs"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"bigquery_project\" AND metric.type=\"bigquery.googleapis.com/job/num_in_flight\""
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Jobs"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Storage Bucket Operations"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"gcs_bucket\" AND metric.type=\"storage.googleapis.com/api/request_count\""
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Requests/sec"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Cloud Function Executions"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_function\" AND metric.type=\"cloudfunctions.googleapis.com/function/execution_count\""
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Executions/sec"
                scale = "LINEAR"
              }
            }
          }
        }
      ]
    }
  })

  project = var.project_id

  depends_on = [
    google_project_service.asset_inventory_apis
  ]
}

# Alert policies for asset inventory monitoring
resource "google_monitoring_alert_policy" "asset_inventory_alerts" {
  for_each = var.enable_monitoring ? var.alert_policies : {}

  display_name = each.value.display_name
  combiner     = each.value.combiner
  enabled      = each.value.enabled

  documentation {
    content   = each.value.documentation
    mime_type = "text/markdown"
  }

  conditions {
    display_name = each.value.condition_display_name

    condition_threshold {
      filter          = each.value.filter
      duration        = each.value.duration
      comparison      = each.value.comparison
      threshold_value = each.value.threshold_value

      aggregations {
        alignment_period   = each.value.alignment_period
        per_series_aligner = each.value.per_series_aligner
        cross_series_reducer = each.value.cross_series_reducer
        group_by_fields    = each.value.group_by_fields
      }

      dynamic "trigger" {
        for_each = each.value.trigger_count != null ? [1] : []
        content {
          count = each.value.trigger_count
        }
      }

      dynamic "trigger" {
        for_each = each.value.trigger_percent != null ? [1] : []
        content {
          percent = each.value.trigger_percent
        }
      }
    }
  }

  notification_channels = concat(
    var.notification_channels,
    each.value.notification_channels
  )

  alert_strategy {
    auto_close = each.value.auto_close_duration

    dynamic "notification_rate_limit" {
      for_each = each.value.rate_limit != null ? [1] : []
      content {
        period = each.value.rate_limit
      }
    }
  }

  project = var.project_id

  depends_on = [
    google_project_service.asset_inventory_apis
  ]
}

# IAM bindings for asset inventory resources
resource "google_bigquery_dataset_iam_binding" "dataset_bindings" {
  for_each = var.enable_bigquery_export ? var.bigquery_dataset_iam_bindings : {}

  dataset_id = google_bigquery_dataset.asset_inventory_dataset[0].dataset_id
  role       = each.value.role
  members    = each.value.members
  project    = var.project_id

  depends_on = [
    google_bigquery_dataset.asset_inventory_dataset
  ]
}

resource "google_storage_bucket_iam_binding" "bucket_bindings" {
  for_each = var.enable_storage_export ? var.storage_bucket_iam_bindings : {}

  bucket  = google_storage_bucket.asset_export_bucket[0].name
  role    = each.value.role
  members = each.value.members

  depends_on = [
    google_storage_bucket.asset_export_bucket
  ]
}

resource "google_pubsub_topic_iam_binding" "topic_bindings" {
  for_each = var.create_pubsub_topics ? var.pubsub_topic_iam_bindings : {}

  topic   = google_pubsub_topic.asset_feed_topics[each.value.topic_name].name
  role    = each.value.role
  members = each.value.members
  project = var.project_id

  depends_on = [
    google_pubsub_topic.asset_feed_topics
  ]
}

# Log sink for asset inventory audit logs
resource "google_logging_project_sink" "asset_audit_sink" {
  count = var.enable_audit_logging ? 1 : 0

  name        = var.audit_log_sink_name
  destination = var.audit_log_destination

  filter = join(" OR ", [
    "protoPayload.serviceName=\"cloudasset.googleapis.com\"",
    "protoPayload.methodName:\"ExportAssets\"",
    "protoPayload.methodName:\"BatchGetAssetsHistory\"",
    "protoPayload.methodName:\"SearchAllResources\"",
    "protoPayload.methodName:\"SearchAllIamPolicies\""
  ])

  unique_writer_identity = true
  project               = var.project_id

  depends_on = [
    google_project_service.asset_inventory_apis
  ]
}

# Security Command Center findings integration
resource "google_security_center_source" "asset_inventory_source" {
  count = var.enable_security_center_integration ? 1 : 0

  display_name = var.security_center_source_name
  description  = "Security findings from Cloud Asset Inventory analysis"
  organization = var.org_id

  depends_on = [
    google_project_service.asset_inventory_apis
  ]
}

# Local values for data processing
locals {
  # Combine all feed types for unified processing
  all_feeds = merge(
    var.asset_feeds,
    var.org_asset_feeds,
    var.folder_asset_feeds
  )

  # Create mapping of feed to topic
  feed_topic_map = {
    for feed_name, feed_config in local.all_feeds : feed_name => feed_config.pubsub_topic
  }

  # Asset types commonly used across feeds
  common_asset_types = [
    "compute.googleapis.com/Instance",
    "compute.googleapis.com/Disk",
    "storage.googleapis.com/Bucket",
    "bigquery.googleapis.com/Dataset",
    "cloudsql.googleapis.com/DatabaseInstance",
    "container.googleapis.com/Cluster",
    "appengine.googleapis.com/Application",
    "cloudkms.googleapis.com/CryptoKey",
    "iam.googleapis.com/ServiceAccount",
    "cloudresourcemanager.googleapis.com/Project"
  ]

  # Default BigQuery schema for asset tables
  default_asset_schema = jsonencode([
    {
      name = "name"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "asset_type"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "resource"
      type = "RECORD"
      mode = "NULLABLE"
      fields = [
        {
          name = "version"
          type = "STRING"
          mode = "NULLABLE"
        },
        {
          name = "discovery_document_uri"
          type = "STRING"
          mode = "NULLABLE"
        },
        {
          name = "discovery_name"
          type = "STRING"
          mode = "NULLABLE"
        },
        {
          name = "resource_url"
          type = "STRING"
          mode = "NULLABLE"
        },
        {
          name = "parent"
          type = "STRING"
          mode = "NULLABLE"
        },
        {
          name = "data"
          type = "JSON"
          mode = "NULLABLE"
        }
      ]
    },
    {
      name = "iam_policy"
      type = "RECORD"
      mode = "NULLABLE"
      fields = [
        {
          name = "version"
          type = "INTEGER"
          mode = "NULLABLE"
        },
        {
          name = "bindings"
          type = "RECORD"
          mode = "REPEATED"
          fields = [
            {
              name = "role"
              type = "STRING"
              mode = "NULLABLE"
            },
            {
              name = "members"
              type = "STRING"
              mode = "REPEATED"
            }
          ]
        }
      ]
    },
    {
      name = "org_policy"
      type = "RECORD"
      mode = "REPEATED"
      fields = [
        {
          name = "constraint"
          type = "STRING"
          mode = "NULLABLE"
        }
      ]
    },
    {
      name = "access_policy"
      type = "RECORD"
      mode = "NULLABLE"
      fields = [
        {
          name = "name"
          type = "STRING"
          mode = "NULLABLE"
        },
        {
          name = "parent"
          type = "STRING"
          mode = "NULLABLE"
        },
        {
          name = "title"
          type = "STRING"
          mode = "NULLABLE"
        }
      ]
    },
    {
      name = "update_time"
      type = "TIMESTAMP"
      mode = "NULLABLE"
    }
  ])
}