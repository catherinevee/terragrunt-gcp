# Cloud Spanner Module
# Provides comprehensive Cloud Spanner database management with multi-region support, backup, and monitoring

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
  name_prefix = var.name_prefix != null ? var.name_prefix : "spanner"
  environment = var.environment != null ? var.environment : "dev"

  # Common labels to apply to all resources
  default_labels = merge(var.labels, {
    module      = "spanner"
    environment = local.environment
    managed_by  = "terraform"
  })

  # Instance configuration with defaults
  instance_config = merge({
    name         = "${local.name_prefix}-${local.environment}"
    config       = "regional-us-central1"
    display_name = "Spanner Instance for ${title(local.environment)}"
    num_nodes    = 1
    processing_units = null
    labels       = {}
    force_destroy = false
    edition      = "STANDARD"
  }, var.instance_config)

  # Database configurations with defaults
  database_configs = {
    for db_name, db_config in var.databases : db_name => merge({
      name                     = db_name
      version_retention_period = "1h"
      ddl                     = []
      deletion_protection     = true
      enable_drop_protection  = true
      database_dialect        = "GOOGLE_STANDARD_SQL"
      encryption_config = {
        kms_key_name = null
      }
    }, db_config)
  }

  # Backup configurations with defaults
  backup_configs = {
    for backup_name, backup_config in var.backup_configs : backup_name => merge({
      database_id      = backup_config.database_id
      backup_id       = backup_name
      expire_time     = null
      retention_period = "72h"
      version_time    = null
      encryption_config = {
        encryption_type = "USE_DATABASE_ENCRYPTION"
        kms_key_name   = null
      }
    }, backup_config)
  }

  # IAM policy configurations
  instance_iam_policies = {
    for policy_name, policy in var.instance_iam_policies : policy_name => merge({
      role    = policy.role
      members = policy.members
      condition = null
    }, policy)
  }

  database_iam_policies = {
    for policy_name, policy in var.database_iam_policies : policy_name => merge({
      database = policy.database
      role     = policy.role
      members  = policy.members
      condition = null
    }, policy)
  }
}

# Data sources
data "google_project" "current" {
  project_id = var.project_id
}

data "google_spanner_instance" "existing_instance" {
  count = var.use_existing_instance ? 1 : 0

  project = var.project_id
  name    = var.existing_instance_name
}

# Enable Spanner API
resource "google_project_service" "spanner_api" {
  project = var.project_id
  service = "spanner.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy        = false
}

# Service account for Spanner operations
resource "google_service_account" "spanner" {
  count = var.create_service_account ? 1 : 0

  project      = var.project_id
  account_id   = var.service_account_name != null ? var.service_account_name : "${local.name_prefix}-${local.environment}"
  display_name = "Cloud Spanner Service Account for ${title(local.environment)}"
  description  = "Service account for Cloud Spanner operations in ${local.environment} environment"
}

# IAM role bindings for service account
resource "google_project_iam_member" "spanner_roles" {
  for_each = var.create_service_account && var.grant_service_account_roles ? toset(var.service_account_roles) : toset([])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.spanner[0].email}"

  depends_on = [google_service_account.spanner]
}

# Cloud Spanner Instance
resource "google_spanner_instance" "instance" {
  count = var.use_existing_instance ? 0 : 1

  project      = var.project_id
  name         = local.instance_config.name
  config       = local.instance_config.config
  display_name = local.instance_config.display_name
  num_nodes    = local.instance_config.processing_units == null ? local.instance_config.num_nodes : null
  processing_units = local.instance_config.processing_units
  labels       = merge(local.default_labels, local.instance_config.labels)
  force_destroy = local.instance_config.force_destroy
  edition      = local.instance_config.edition

  depends_on = [google_project_service.spanner_api]

  lifecycle {
    prevent_destroy = true
  }
}

# Cloud Spanner Databases
resource "google_spanner_database" "databases" {
  for_each = local.database_configs

  project  = var.project_id
  instance = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].name : google_spanner_instance.instance[0].name
  name     = each.value.name

  version_retention_period = each.value.version_retention_period
  ddl                     = each.value.ddl
  deletion_protection     = each.value.deletion_protection
  enable_drop_protection  = each.value.enable_drop_protection
  database_dialect        = each.value.database_dialect

  dynamic "encryption_config" {
    for_each = each.value.encryption_config.kms_key_name != null ? [1] : []
    content {
      kms_key_name = each.value.encryption_config.kms_key_name
    }
  }

  depends_on = [
    google_spanner_instance.instance,
    google_project_service.spanner_api
  ]

  lifecycle {
    prevent_destroy = true
  }
}

# Cloud Spanner Database Backups
resource "google_spanner_backup" "backups" {
  for_each = local.backup_configs

  project     = var.project_id
  instance_id = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].name : google_spanner_instance.instance[0].name
  database_id = each.value.database_id
  backup_id   = each.value.backup_id

  expire_time     = each.value.expire_time
  retention_period = each.value.retention_period
  version_time    = each.value.version_time

  dynamic "encryption_config" {
    for_each = each.value.encryption_config.kms_key_name != null ? [1] : []
    content {
      encryption_type = each.value.encryption_config.encryption_type
      kms_key_name   = each.value.encryption_config.kms_key_name
    }
  }

  depends_on = [google_spanner_database.databases]

  lifecycle {
    prevent_destroy = true
  }
}

# Backup schedules for automated backups
resource "google_spanner_backup_schedule" "backup_schedules" {
  for_each = var.backup_schedules

  project     = var.project_id
  instance_id = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].name : google_spanner_instance.instance[0].name
  database_id = each.value.database_id
  name        = each.key

  retention_duration = each.value.retention_duration

  dynamic "incremental_backup_spec" {
    for_each = each.value.backup_type == "incremental" ? [1] : []
    content {}
  }

  dynamic "full_backup_spec" {
    for_each = each.value.backup_type == "full" ? [1] : []
    content {}
  }

  dynamic "spec" {
    for_each = each.value.cron_spec != null ? [1] : []
    content {
      dynamic "cron_spec" {
        for_each = each.value.cron_spec != null ? [1] : []
        content {
          text      = each.value.cron_spec.text
          time_zone = each.value.cron_spec.time_zone
        }
      }
    }
  }

  dynamic "encryption_config" {
    for_each = each.value.encryption_config != null ? [1] : []
    content {
      encryption_type = each.value.encryption_config.encryption_type
      kms_key_name   = each.value.encryption_config.kms_key_name
    }
  }

  depends_on = [google_spanner_database.databases]
}

# IAM bindings for Spanner instance
resource "google_spanner_instance_iam_binding" "instance_iam" {
  for_each = local.instance_iam_policies

  project  = var.project_id
  instance = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].name : google_spanner_instance.instance[0].name
  role     = each.value.role
  members  = each.value.members

  dynamic "condition" {
    for_each = each.value.condition != null ? [1] : []
    content {
      title       = each.value.condition.title
      description = each.value.condition.description
      expression  = each.value.condition.expression
    }
  }

  depends_on = [google_spanner_instance.instance]
}

# IAM bindings for Spanner databases
resource "google_spanner_database_iam_binding" "database_iam" {
  for_each = local.database_iam_policies

  project  = var.project_id
  instance = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].name : google_spanner_instance.instance[0].name
  database = each.value.database
  role     = each.value.role
  members  = each.value.members

  dynamic "condition" {
    for_each = each.value.condition != null ? [1] : []
    content {
      title       = each.value.condition.title
      description = each.value.condition.description
      expression  = each.value.condition.expression
    }
  }

  depends_on = [google_spanner_database.databases]
}

# Monitoring alert policies for Spanner
resource "google_monitoring_alert_policy" "spanner_alerts" {
  for_each = var.create_monitoring_alerts ? var.monitoring_alerts : {}

  project      = var.project_id
  display_name = each.value.display_name
  enabled      = each.value.enabled != null ? each.value.enabled : true
  combiner     = each.value.combiner != null ? each.value.combiner : "OR"

  conditions {
    display_name = each.value.condition_display_name

    condition_threshold {
      filter         = each.value.filter
      duration       = each.value.duration != null ? each.value.duration : "300s"
      comparison     = each.value.comparison != null ? each.value.comparison : "COMPARISON_GREATER_THAN"
      threshold_value = each.value.threshold_value

      aggregations {
        alignment_period     = each.value.alignment_period != null ? each.value.alignment_period : "300s"
        per_series_aligner   = each.value.per_series_aligner != null ? each.value.per_series_aligner : "ALIGN_RATE"
        cross_series_reducer = each.value.cross_series_reducer != null ? each.value.cross_series_reducer : "REDUCE_MEAN"
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

# Monitoring dashboard for Spanner
resource "google_monitoring_dashboard" "spanner" {
  count = var.create_monitoring_dashboard ? 1 : 0

  project        = var.project_id
  dashboard_json = jsonencode({
    displayName = "Cloud Spanner - ${title(local.environment)}"
    mosaicLayout = {
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "CPU Utilization"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"spanner_instance\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"spanner.googleapis.com/instance/cpu/utilization\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_MEAN"
                      groupByFields      = ["resource.labels.instance_id"]
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
          widget = {
            title = "Storage Utilization"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"spanner_instance\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"spanner.googleapis.com/instance/storage/utilization\""
                    aggregation = {
                      alignmentPeriod    = "300s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_MEAN"
                      groupByFields      = ["resource.labels.instance_id"]
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
          yPos   = 4
          widget = {
            title = "Query Count"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"spanner_instance\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"spanner.googleapis.com/api/request_count\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.labels.method"]
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
          xPos   = 6
          yPos   = 4
          widget = {
            title = "Query Latency"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"spanner_instance\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"spanner.googleapis.com/api/request_latencies\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_DELTA"
                      crossSeriesReducer = "REDUCE_PERCENTILE_95"
                      groupByFields      = ["metric.labels.method"]
                    }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          width  = 12
          height = 4
          yPos   = 8
          widget = {
            title = "Node Count"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"spanner_instance\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"spanner.googleapis.com/instance/node_count\""
                    aggregation = {
                      alignmentPeriod    = "300s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_MEAN"
                      groupByFields      = ["resource.labels.instance_id"]
                    }
                  }
                }
                plotType = "STACKED_AREA"
              }]
            }
          }
        }
      ]
    }
  })
}

# Log-based metrics for custom monitoring
resource "google_logging_metric" "spanner_metrics" {
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
      metric_kind = each.value.metric_descriptor.metric_kind
      value_type  = each.value.metric_descriptor.value_type
      unit        = each.value.metric_descriptor.unit
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

# Cloud Function for Spanner operations (optional)
resource "google_cloudfunctions_function" "spanner_operations" {
  for_each = var.create_operation_functions ? var.operation_functions : {}

  project = var.project_id
  region  = var.region
  name    = "${local.name_prefix}-${each.key}-operation-${local.environment}"

  runtime     = each.value.runtime
  entry_point = each.value.entry_point
  source_archive_bucket = each.value.source_bucket
  source_archive_object = each.value.source_object

  dynamic "event_trigger" {
    for_each = each.value.trigger_type != "http" ? [1] : []
    content {
      event_type = each.value.event_type
      resource   = each.value.trigger_resource
    }
  }

  dynamic "https_trigger" {
    for_each = each.value.trigger_type == "http" ? [1] : []
    content {
      url = null
    }
  }

  environment_variables = merge(
    each.value.environment_variables,
    {
      SPANNER_INSTANCE = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].name : google_spanner_instance.instance[0].name
      PROJECT_ID       = var.project_id
    }
  )

  available_memory_mb = each.value.memory_mb
  timeout            = each.value.timeout_seconds

  labels = merge(local.default_labels, each.value.labels != null ? each.value.labels : {})

  depends_on = [
    google_spanner_instance.instance,
    google_spanner_database.databases
  ]
}

# Data export jobs to BigQuery (optional)
resource "google_bigquery_dataset" "spanner_export" {
  count = var.enable_bigquery_export ? 1 : 0

  project    = var.project_id
  dataset_id = "${local.name_prefix}_export_${local.environment}"
  location   = var.bigquery_export_location

  description                     = "BigQuery dataset for Spanner exports"
  default_table_expiration_ms    = var.bigquery_table_expiration_ms
  delete_contents_on_destroy     = false
  default_partition_expiration_ms = var.bigquery_partition_expiration_ms

  labels = merge(local.default_labels, {
    purpose = "spanner-export"
  })

  dynamic "access" {
    for_each = var.bigquery_access_config
    content {
      role          = access.value.role
      user_by_email = access.value.user_by_email
      group_by_email = access.value.group_by_email
      special_group = access.value.special_group
    }
  }
}

# Dataflow job for Spanner to BigQuery export (optional)
resource "google_dataflow_job" "spanner_to_bigquery" {
  count = var.enable_dataflow_export ? 1 : 0

  project           = var.project_id
  region           = var.region
  name             = "${local.name_prefix}-to-bigquery-${local.environment}"
  template_gcs_path = var.dataflow_template_path
  temp_gcs_location = var.dataflow_temp_location

  parameters = merge(
    var.dataflow_parameters,
    {
      spannerInstanceId = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].name : google_spanner_instance.instance[0].name
      spannerDatabaseId = var.dataflow_source_database
      outputTableSpec  = "${var.project_id}:${google_bigquery_dataset.spanner_export[0].dataset_id}.${var.dataflow_output_table}"
    }
  )

  labels = merge(local.default_labels, {
    purpose = "spanner-export"
  })

  depends_on = [
    google_spanner_database.databases,
    google_bigquery_dataset.spanner_export
  ]
}

# Pub/Sub topic for Spanner change streams (optional)
resource "google_pubsub_topic" "spanner_change_streams" {
  for_each = var.enable_change_streams ? var.change_stream_topics : {}

  project = var.project_id
  name    = each.key
  labels  = local.default_labels

  dynamic "message_retention_duration" {
    for_each = each.value.message_retention_duration != null ? [1] : []
    content {
      seconds = each.value.message_retention_duration
    }
  }

  dynamic "schema_settings" {
    for_each = each.value.schema_name != null ? [1] : []
    content {
      schema   = each.value.schema_name
      encoding = each.value.schema_encoding
    }
  }

  depends_on = [google_spanner_database.databases]
}

# Cloud Scheduler jobs for maintenance tasks (optional)
resource "google_cloud_scheduler_job" "spanner_maintenance" {
  for_each = var.enable_maintenance_jobs ? var.maintenance_jobs : {}

  project     = var.project_id
  region      = var.region
  name        = "${local.name_prefix}-${each.key}-${local.environment}"
  description = each.value.description
  schedule    = each.value.schedule
  time_zone   = each.value.time_zone

  http_target {
    http_method = "POST"
    uri         = each.value.target_url
    body        = base64encode(jsonencode(each.value.payload))

    headers = {
      "Content-Type" = "application/json"
    }

    dynamic "oidc_token" {
      for_each = each.value.service_account_email != null ? [1] : []
      content {
        service_account_email = each.value.service_account_email
        audience             = each.value.target_url
      }
    }
  }

  retry_config {
    retry_count          = 3
    max_retry_duration   = "600s"
    min_backoff_duration = "5s"
    max_backoff_duration = "300s"
    max_doublings        = 3
  }

  depends_on = [google_spanner_database.databases]
}