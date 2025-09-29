# Cloud Scheduler Module
# Provides comprehensive Cloud Scheduler job management with multiple target types

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
  name_prefix = var.name_prefix != null ? var.name_prefix : "scheduler"
  environment = var.environment != null ? var.environment : "dev"

  # Common labels to apply to all resources
  default_labels = merge(var.labels, {
    module      = "cloud-scheduler"
    environment = local.environment
    managed_by  = "terraform"
  })

  # Generate job configurations with defaults
  job_configs = {
    for job_name, job_config in var.scheduler_jobs : job_name => merge({
      schedule         = "0 9 * * 1"  # Default: 9 AM every Monday
      time_zone        = "UTC"
      attempt_deadline = "180s"
      retry_config = {
        retry_count          = 3
        max_retry_duration   = "600s"
        min_backoff_duration = "5s"
        max_backoff_duration = "300s"
        max_doublings        = 3
      }
      enabled = true
    }, job_config)
  }

  # HTTP jobs configuration
  http_jobs = {
    for job_name, job_config in local.job_configs : job_name => job_config
    if job_config.target_type == "http"
  }

  # Pub/Sub jobs configuration
  pubsub_jobs = {
    for job_name, job_config in local.job_configs : job_name => job_config
    if job_config.target_type == "pubsub"
  }

  # App Engine jobs configuration
  app_engine_jobs = {
    for job_name, job_config in local.job_configs : job_name => job_config
    if job_config.target_type == "app_engine"
  }

  # Cloud Function jobs configuration
  cloud_function_jobs = {
    for job_name, job_config in local.job_configs : job_name => job_config
    if job_config.target_type == "cloud_function"
  }
}

# Data source for project information
data "google_project" "current" {
  project_id = var.project_id
}

# Service account for Cloud Scheduler jobs
resource "google_service_account" "scheduler" {
  count = var.create_service_account ? 1 : 0

  project      = var.project_id
  account_id   = var.service_account_name != null ? var.service_account_name : "${local.name_prefix}-${local.environment}"
  display_name = "Cloud Scheduler Service Account for ${title(local.environment)}"
  description  = "Service account for Cloud Scheduler jobs in ${local.environment} environment"
}

# IAM role bindings for service account
resource "google_project_iam_member" "scheduler_roles" {
  for_each = var.create_service_account && var.grant_service_account_roles ? toset(var.service_account_roles) : toset([])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.scheduler[0].email}"

  depends_on = [google_service_account.scheduler]
}

# Pub/Sub topics for scheduler jobs (if needed)
resource "google_pubsub_topic" "scheduler_topics" {
  for_each = var.create_pubsub_topics ? toset(var.pubsub_topic_names) : toset([])

  project = var.project_id
  name    = each.key
  labels  = local.default_labels

  dynamic "message_retention_duration" {
    for_each = var.pubsub_message_retention_duration != null ? [1] : []
    content {
      seconds = var.pubsub_message_retention_duration
    }
  }

  dynamic "schema_settings" {
    for_each = var.pubsub_schema_name != null ? [1] : []
    content {
      schema   = var.pubsub_schema_name
      encoding = var.pubsub_schema_encoding
    }
  }
}

# HTTP Target Cloud Scheduler Jobs
resource "google_cloud_scheduler_job" "http_jobs" {
  for_each = local.http_jobs

  project     = var.project_id
  region      = var.region
  name        = "${local.name_prefix}-${each.key}-${local.environment}"
  description = each.value.description != null ? each.value.description : "HTTP scheduler job for ${each.key}"
  schedule    = each.value.schedule
  time_zone   = each.value.time_zone

  paused           = !each.value.enabled
  attempt_deadline = each.value.attempt_deadline

  retry_config {
    retry_count          = each.value.retry_config.retry_count
    max_retry_duration   = each.value.retry_config.max_retry_duration
    min_backoff_duration = each.value.retry_config.min_backoff_duration
    max_backoff_duration = each.value.retry_config.max_backoff_duration
    max_doublings        = each.value.retry_config.max_doublings
  }

  http_target {
    http_method = each.value.http_config.method
    uri         = each.value.http_config.uri
    body        = each.value.http_config.body != null ? base64encode(each.value.http_config.body) : null

    dynamic "headers" {
      for_each = each.value.http_config.headers != null ? each.value.http_config.headers : {}
      content {
        key   = headers.key
        value = headers.value
      }
    }

    dynamic "oauth_token" {
      for_each = each.value.http_config.oauth_token != null ? [1] : []
      content {
        service_account_email = each.value.http_config.oauth_token.service_account_email
        scope                = each.value.http_config.oauth_token.scope
      }
    }

    dynamic "oidc_token" {
      for_each = each.value.http_config.oidc_token != null ? [1] : []
      content {
        service_account_email = each.value.http_config.oidc_token.service_account_email
        audience             = each.value.http_config.oidc_token.audience
      }
    }
  }
}

# Pub/Sub Target Cloud Scheduler Jobs
resource "google_cloud_scheduler_job" "pubsub_jobs" {
  for_each = local.pubsub_jobs

  project     = var.project_id
  region      = var.region
  name        = "${local.name_prefix}-${each.key}-${local.environment}"
  description = each.value.description != null ? each.value.description : "Pub/Sub scheduler job for ${each.key}"
  schedule    = each.value.schedule
  time_zone   = each.value.time_zone

  paused           = !each.value.enabled
  attempt_deadline = each.value.attempt_deadline

  retry_config {
    retry_count          = each.value.retry_config.retry_count
    max_retry_duration   = each.value.retry_config.max_retry_duration
    min_backoff_duration = each.value.retry_config.min_backoff_duration
    max_backoff_duration = each.value.retry_config.max_backoff_duration
    max_doublings        = each.value.retry_config.max_doublings
  }

  pubsub_target {
    topic_name = each.value.pubsub_config.topic_name
    data       = each.value.pubsub_config.data != null ? base64encode(each.value.pubsub_config.data) : null

    dynamic "attributes" {
      for_each = each.value.pubsub_config.attributes != null ? each.value.pubsub_config.attributes : {}
      content {
        key   = attributes.key
        value = attributes.value
      }
    }
  }
}

# App Engine Target Cloud Scheduler Jobs
resource "google_cloud_scheduler_job" "app_engine_jobs" {
  for_each = local.app_engine_jobs

  project     = var.project_id
  region      = var.region
  name        = "${local.name_prefix}-${each.key}-${local.environment}"
  description = each.value.description != null ? each.value.description : "App Engine scheduler job for ${each.key}"
  schedule    = each.value.schedule
  time_zone   = each.value.time_zone

  paused           = !each.value.enabled
  attempt_deadline = each.value.attempt_deadline

  retry_config {
    retry_count          = each.value.retry_config.retry_count
    max_retry_duration   = each.value.retry_config.max_retry_duration
    min_backoff_duration = each.value.retry_config.min_backoff_duration
    max_backoff_duration = each.value.retry_config.max_backoff_duration
    max_doublings        = each.value.retry_config.max_doublings
  }

  app_engine_http_target {
    http_method = each.value.app_engine_config.method

    dynamic "app_engine_routing" {
      for_each = each.value.app_engine_config.routing != null ? [1] : []
      content {
        service  = each.value.app_engine_config.routing.service
        version  = each.value.app_engine_config.routing.version
        instance = each.value.app_engine_config.routing.instance
      }
    }

    relative_uri = each.value.app_engine_config.relative_uri
    body         = each.value.app_engine_config.body != null ? base64encode(each.value.app_engine_config.body) : null

    dynamic "headers" {
      for_each = each.value.app_engine_config.headers != null ? each.value.app_engine_config.headers : {}
      content {
        key   = headers.key
        value = headers.value
      }
    }
  }
}

# Cloud Function Target Cloud Scheduler Jobs (using HTTP targets)
resource "google_cloud_scheduler_job" "cloud_function_jobs" {
  for_each = local.cloud_function_jobs

  project     = var.project_id
  region      = var.region
  name        = "${local.name_prefix}-${each.key}-${local.environment}"
  description = each.value.description != null ? each.value.description : "Cloud Function scheduler job for ${each.key}"
  schedule    = each.value.schedule
  time_zone   = each.value.time_zone

  paused           = !each.value.enabled
  attempt_deadline = each.value.attempt_deadline

  retry_config {
    retry_count          = each.value.retry_config.retry_count
    max_retry_duration   = each.value.retry_config.max_retry_duration
    min_backoff_duration = each.value.retry_config.min_backoff_duration
    max_backoff_duration = each.value.retry_config.max_backoff_duration
    max_doublings        = each.value.retry_config.max_doublings
  }

  http_target {
    http_method = "POST"
    uri         = each.value.cloud_function_config.function_url
    body        = each.value.cloud_function_config.data != null ? base64encode(each.value.cloud_function_config.data) : null

    dynamic "headers" {
      for_each = each.value.cloud_function_config.headers != null ? each.value.cloud_function_config.headers : {}
      content {
        key   = headers.key
        value = headers.value
      }
    }

    dynamic "oidc_token" {
      for_each = each.value.cloud_function_config.oidc_token != null ? [1] : []
      content {
        service_account_email = each.value.cloud_function_config.oidc_token.service_account_email
        audience             = each.value.cloud_function_config.oidc_token.audience
      }
    }
  }
}

# IAM bindings for scheduler jobs
resource "google_cloud_scheduler_job_iam_member" "job_iam" {
  for_each = var.job_iam_bindings

  project  = var.project_id
  region   = var.region
  job      = google_cloud_scheduler_job.http_jobs[each.value.job_name].name
  role     = each.value.role
  member   = each.value.member

  depends_on = [
    google_cloud_scheduler_job.http_jobs,
    google_cloud_scheduler_job.pubsub_jobs,
    google_cloud_scheduler_job.app_engine_jobs,
    google_cloud_scheduler_job.cloud_function_jobs
  ]
}

# Monitoring alert policies for scheduler jobs
resource "google_monitoring_alert_policy" "scheduler_alerts" {
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

# Monitoring dashboard for Cloud Scheduler
resource "google_monitoring_dashboard" "scheduler" {
  count = var.create_monitoring_dashboard ? 1 : 0

  project        = var.project_id
  dashboard_json = jsonencode({
    displayName = "Cloud Scheduler - ${title(local.environment)}"
    mosaicLayout = {
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Job Execution Rate"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_scheduler_job\" resource.labels.project_id=\"${var.project_id}\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.labels.job_id"]
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
            title = "Job Success Rate"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_scheduler_job\" resource.labels.project_id=\"${var.project_id}\" metric.labels.response_code!~\"^[45].*\""
                    aggregation = {
                      alignmentPeriod    = "300s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
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
          yPos   = 4
          widget = {
            title = "Job Execution Latency"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_scheduler_job\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"appengine.googleapis.com/http/server/response_latencies\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_DELTA"
                      crossSeriesReducer = "REDUCE_PERCENTILE_95"
                      groupByFields      = ["resource.labels.job_id"]
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
resource "google_logging_metric" "scheduler_metrics" {
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