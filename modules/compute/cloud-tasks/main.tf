# Cloud Tasks Module
# Provides comprehensive Cloud Tasks queue management with multiple target types

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
  name_prefix = var.name_prefix != null ? var.name_prefix : "tasks"
  environment = var.environment != null ? var.environment : "dev"

  # Common labels to apply to all resources
  default_labels = merge(var.labels, {
    module      = "cloud-tasks"
    environment = local.environment
    managed_by  = "terraform"
  })

  # Generate queue configurations with defaults
  queue_configs = {
    for queue_name, queue_config in var.task_queues : queue_name => merge({
      location = var.region
      retry_config = {
        max_attempts       = 100
        max_retry_duration = "86400s"  # 24 hours
        max_backoff        = "3600s"   # 1 hour
        min_backoff        = "0.100s"  # 100ms
        max_doublings      = 16
      }
      rate_limits = {
        max_dispatches_per_second = 500
        max_burst_size           = 100
        max_concurrent_dispatches = 1000
      }
      state = "RUNNING"
    }, queue_config)
  }

  # HTTP target queues
  http_queues = {
    for queue_name, queue_config in local.queue_configs : queue_name => queue_config
    if queue_config.target_type == "http"
  }

  # App Engine target queues
  app_engine_queues = {
    for queue_name, queue_config in local.queue_configs : queue_name => queue_config
    if queue_config.target_type == "app_engine"
  }

  # Pull queues (for manual task consumption)
  pull_queues = {
    for queue_name, queue_config in local.queue_configs : queue_name => queue_config
    if queue_config.target_type == "pull"
  }
}

# Data source for project information
data "google_project" "current" {
  project_id = var.project_id
}

# Service account for Cloud Tasks
resource "google_service_account" "tasks" {
  count = var.create_service_account ? 1 : 0

  project      = var.project_id
  account_id   = var.service_account_name != null ? var.service_account_name : "${local.name_prefix}-${local.environment}"
  display_name = "Cloud Tasks Service Account for ${title(local.environment)}"
  description  = "Service account for Cloud Tasks queues in ${local.environment} environment"
}

# IAM role bindings for service account
resource "google_project_iam_member" "tasks_roles" {
  for_each = var.create_service_account && var.grant_service_account_roles ? toset(var.service_account_roles) : toset([])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.tasks[0].email}"

  depends_on = [google_service_account.tasks]
}

# HTTP Target Task Queues
resource "google_cloud_tasks_queue" "http_queues" {
  for_each = local.http_queues

  project  = var.project_id
  location = each.value.location
  name     = "${local.name_prefix}-${each.key}-${local.environment}"

  app_engine_routing_override {
    service  = each.value.http_target.app_engine_routing.service
    version  = each.value.http_target.app_engine_routing.version
    instance = each.value.http_target.app_engine_routing.instance
  }

  rate_limits {
    max_dispatches_per_second = each.value.rate_limits.max_dispatches_per_second
    max_burst_size           = each.value.rate_limits.max_burst_size
    max_concurrent_dispatches = each.value.rate_limits.max_concurrent_dispatches
  }

  retry_config {
    max_attempts       = each.value.retry_config.max_attempts
    max_retry_duration = each.value.retry_config.max_retry_duration
    max_backoff        = each.value.retry_config.max_backoff
    min_backoff        = each.value.retry_config.min_backoff
    max_doublings      = each.value.retry_config.max_doublings
  }

  stackdriver_logging_config {
    sampling_ratio = each.value.logging_config != null ? each.value.logging_config.sampling_ratio : 1.0
  }

  state = each.value.state
}

# App Engine Target Task Queues
resource "google_cloud_tasks_queue" "app_engine_queues" {
  for_each = local.app_engine_queues

  project  = var.project_id
  location = each.value.location
  name     = "${local.name_prefix}-${each.key}-${local.environment}"

  app_engine_routing_override {
    service  = each.value.app_engine_target.routing.service
    version  = each.value.app_engine_target.routing.version
    instance = each.value.app_engine_target.routing.instance
  }

  rate_limits {
    max_dispatches_per_second = each.value.rate_limits.max_dispatches_per_second
    max_burst_size           = each.value.rate_limits.max_burst_size
    max_concurrent_dispatches = each.value.rate_limits.max_concurrent_dispatches
  }

  retry_config {
    max_attempts       = each.value.retry_config.max_attempts
    max_retry_duration = each.value.retry_config.max_retry_duration
    max_backoff        = each.value.retry_config.max_backoff
    min_backoff        = each.value.retry_config.min_backoff
    max_doublings      = each.value.retry_config.max_doublings
  }

  stackdriver_logging_config {
    sampling_ratio = each.value.logging_config != null ? each.value.logging_config.sampling_ratio : 1.0
  }

  state = each.value.state
}

# Pull Target Task Queues (for manual task consumption)
resource "google_cloud_tasks_queue" "pull_queues" {
  for_each = local.pull_queues

  project  = var.project_id
  location = each.value.location
  name     = "${local.name_prefix}-${each.key}-${local.environment}"

  rate_limits {
    max_dispatches_per_second = each.value.rate_limits.max_dispatches_per_second
    max_burst_size           = each.value.rate_limits.max_burst_size
    max_concurrent_dispatches = each.value.rate_limits.max_concurrent_dispatches
  }

  retry_config {
    max_attempts       = each.value.retry_config.max_attempts
    max_retry_duration = each.value.retry_config.max_retry_duration
    max_backoff        = each.value.retry_config.max_backoff
    min_backoff        = each.value.retry_config.min_backoff
    max_doublings      = each.value.retry_config.max_doublings
  }

  stackdriver_logging_config {
    sampling_ratio = each.value.logging_config != null ? each.value.logging_config.sampling_ratio : 1.0
  }

  state = each.value.state
}

# IAM bindings for task queues
resource "google_cloud_tasks_queue_iam_member" "queue_iam" {
  for_each = var.queue_iam_bindings

  project  = var.project_id
  location = var.region
  name     = "${local.name_prefix}-${each.value.queue_name}-${local.environment}"
  role     = each.value.role
  member   = each.value.member

  depends_on = [
    google_cloud_tasks_queue.http_queues,
    google_cloud_tasks_queue.app_engine_queues,
    google_cloud_tasks_queue.pull_queues
  ]
}

# Create sample tasks for testing (optional)
resource "google_cloud_tasks_task" "sample_tasks" {
  for_each = var.create_sample_tasks ? var.sample_tasks : {}

  project  = var.project_id
  location = var.region
  queue    = google_cloud_tasks_queue.http_queues[each.value.queue_name].name

  dynamic "http_request" {
    for_each = each.value.http_request != null ? [1] : []
    content {
      http_method = each.value.http_request.method
      url         = each.value.http_request.url
      body        = each.value.http_request.body != null ? base64encode(each.value.http_request.body) : null

      dynamic "headers" {
        for_each = each.value.http_request.headers != null ? each.value.http_request.headers : {}
        content {
          key   = headers.key
          value = headers.value
        }
      }

      dynamic "oauth_token" {
        for_each = each.value.http_request.oauth_token != null ? [1] : []
        content {
          service_account_email = each.value.http_request.oauth_token.service_account_email
          scope                = each.value.http_request.oauth_token.scope
        }
      }

      dynamic "oidc_token" {
        for_each = each.value.http_request.oidc_token != null ? [1] : []
        content {
          service_account_email = each.value.http_request.oidc_token.service_account_email
          audience             = each.value.http_request.oidc_token.audience
        }
      }
    }
  }

  dynamic "app_engine_http_request" {
    for_each = each.value.app_engine_request != null ? [1] : []
    content {
      http_method  = each.value.app_engine_request.method
      relative_uri = each.value.app_engine_request.relative_uri
      body         = each.value.app_engine_request.body != null ? base64encode(each.value.app_engine_request.body) : null

      dynamic "headers" {
        for_each = each.value.app_engine_request.headers != null ? each.value.app_engine_request.headers : {}
        content {
          key   = headers.key
          value = headers.value
        }
      }

      dynamic "app_engine_routing" {
        for_each = each.value.app_engine_request.routing != null ? [1] : []
        content {
          service  = each.value.app_engine_request.routing.service
          version  = each.value.app_engine_request.routing.version
          instance = each.value.app_engine_request.routing.instance
        }
      }
    }
  }

  schedule_time = each.value.schedule_time != null ? each.value.schedule_time : null

  depends_on = [
    google_cloud_tasks_queue.http_queues,
    google_cloud_tasks_queue.app_engine_queues
  ]
}

# Monitoring alert policies for task queues
resource "google_monitoring_alert_policy" "tasks_alerts" {
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

# Monitoring dashboard for Cloud Tasks
resource "google_monitoring_dashboard" "tasks" {
  count = var.create_monitoring_dashboard ? 1 : 0

  project        = var.project_id
  dashboard_json = jsonencode({
    displayName = "Cloud Tasks - ${title(local.environment)}"
    mosaicLayout = {
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Task Execution Rate"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"gce_instance\" resource.labels.project_id=\"${var.project_id}\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.labels.queue_name"]
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
            title = "Queue Depth"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"gce_instance\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"cloudtasks.googleapis.com/queue/depth\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.labels.queue_name"]
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
            title = "Task Success Rate"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"gce_instance\" resource.labels.project_id=\"${var.project_id}\" metric.labels.response_code!~\"^[45].*\""
                    aggregation = {
                      alignmentPeriod    = "300s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.labels.queue_name"]
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
            title = "Task Latency"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"gce_instance\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"cloudtasks.googleapis.com/task/attempt_delay\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_DELTA"
                      crossSeriesReducer = "REDUCE_PERCENTILE_95"
                      groupByFields      = ["resource.labels.queue_name"]
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
resource "google_logging_metric" "tasks_metrics" {
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

# Cloud Function integration for task processing (optional)
resource "google_cloudfunctions_function" "task_processor" {
  for_each = var.create_task_processors ? var.task_processors : {}

  project = var.project_id
  region  = var.region
  name    = "${local.name_prefix}-${each.key}-processor-${local.environment}"

  runtime     = each.value.runtime
  entry_point = each.value.entry_point
  source_archive_bucket = each.value.source_bucket
  source_archive_object = each.value.source_object

  dynamic "event_trigger" {
    for_each = each.value.trigger_type == "http" ? [] : [1]
    content {
      event_type = "providers/cloud.firestore/eventTypes/document.write"
      resource   = each.value.trigger_resource
    }
  }

  dynamic "https_trigger" {
    for_each = each.value.trigger_type == "http" ? [1] : []
    content {
      url = null
    }
  }

  environment_variables = each.value.environment_variables

  available_memory_mb = each.value.memory_mb
  timeout            = each.value.timeout_seconds

  labels = merge(local.default_labels, each.value.labels != null ? each.value.labels : {})
}