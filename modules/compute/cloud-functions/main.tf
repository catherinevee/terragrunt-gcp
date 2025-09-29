# Cloud Functions Module - Main Configuration

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }
}

# Local variables
locals {
  function_name = var.function_name != null ? var.function_name : "${var.name_prefix}-${var.environment}"

  labels = merge(
    {
      environment = var.environment
      managed_by  = "terraform"
      function    = local.function_name
      runtime     = var.runtime
    },
    var.labels
  )

  service_account_email = var.create_service_account ? (
    google_service_account.function_sa[0].email
  ) : var.service_account_email

  source_archive_bucket = var.create_source_bucket ? (
    google_storage_bucket.source_bucket[0].name
  ) : var.source_archive_bucket

  source_archive_object = var.create_source_archive ? (
    google_storage_bucket_object.source_archive[0].name
  ) : var.source_archive_object

  vpc_connector_name = var.create_vpc_connector ? (
    google_vpc_access_connector.connector[0].name
  ) : var.vpc_connector

  ingress_settings = var.generation == 2 ? (
    var.ingress_settings_v2
  ) : var.ingress_settings_v1

  env_vars = merge(
    {
      FUNCTION_NAME = local.function_name
      ENVIRONMENT   = var.environment
      PROJECT_ID    = var.project_id
    },
    var.generation == 2 ? {} : {
      FUNCTION_REGION = var.region
    },
    var.environment_variables
  )

  secret_env_vars = var.generation == 2 ? var.secret_environment_variables : {}

  event_trigger = var.event_trigger_config != null ? {
    trigger_region        = try(var.event_trigger_config.trigger_region, var.region)
    event_type           = var.event_trigger_config.event_type
    resource             = try(var.event_trigger_config.resource, null)
    service              = try(var.event_trigger_config.service, null)
    failure_policy_retry = try(var.event_trigger_config.retry_policy, false)
  } : null

  event_trigger_v2 = var.event_trigger_v2_config != null ? {
    trigger_region          = try(var.event_trigger_v2_config.trigger_region, var.region)
    event_type             = var.event_trigger_v2_config.event_type
    pubsub_topic           = try(var.event_trigger_v2_config.pubsub_topic, null)
    service_account_email  = try(var.event_trigger_v2_config.service_account_email, local.service_account_email)
    retry_policy           = try(var.event_trigger_v2_config.retry_policy, "RETRY_POLICY_DO_NOT_RETRY")
  } : null

  timeout = var.generation == 2 ? min(var.timeout, 3600) : min(var.timeout, 540)
}

# Service Account for Cloud Function
resource "google_service_account" "function_sa" {
  count = var.create_service_account ? 1 : 0

  project      = var.project_id
  account_id   = var.service_account_name != null ? var.service_account_name : "${local.function_name}-sa"
  display_name = "Service Account for Cloud Function ${local.function_name}"
  description  = "Service account for Cloud Function ${local.function_name}"
}

# Service Account Key
resource "google_service_account_key" "function_sa_key" {
  count = var.create_service_account && var.create_service_account_key ? 1 : 0

  service_account_id = google_service_account.function_sa[0].name
  key_algorithm     = "KEY_ALG_RSA_2048"
}

# IAM Roles for Service Account
resource "google_project_iam_member" "function_sa_roles" {
  for_each = var.create_service_account && var.grant_service_account_roles ? toset(var.service_account_roles) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.function_sa[0].email}"
}

# Source Bucket
resource "google_storage_bucket" "source_bucket" {
  count = var.create_source_bucket ? 1 : 0

  project       = var.project_id
  name          = var.source_bucket_name != null ? var.source_bucket_name : "${var.project_id}-${local.function_name}-source"
  location      = var.source_bucket_location
  storage_class = var.source_bucket_storage_class

  uniform_bucket_level_access = true
  force_destroy              = var.source_bucket_force_destroy

  versioning {
    enabled = var.source_bucket_versioning
  }

  dynamic "lifecycle_rule" {
    for_each = var.source_bucket_lifecycle_days > 0 ? [1] : []
    content {
      condition {
        age = var.source_bucket_lifecycle_days
      }
      action {
        type = "Delete"
      }
    }
  }

  labels = local.labels
}

# Source Archive from Local Directory
data "archive_file" "source" {
  count = var.create_source_archive && var.source_directory != null ? 1 : 0

  type        = "zip"
  source_dir  = var.source_directory
  output_path = "${path.module}/${local.function_name}-source.zip"

  excludes = var.source_archive_excludes
}

# Upload Source Archive
resource "google_storage_bucket_object" "source_archive" {
  count = var.create_source_archive ? 1 : 0

  name   = var.source_archive_object != null ? var.source_archive_object : "${local.function_name}-${data.archive_file.source[0].output_sha}.zip"
  bucket = local.source_archive_bucket
  source = var.source_archive_path != null ? var.source_archive_path : data.archive_file.source[0].output_path
}

# VPC Connector for Private IP Access
resource "google_vpc_access_connector" "connector" {
  count = var.create_vpc_connector ? 1 : 0

  project        = var.project_id
  name           = var.vpc_connector_name != null ? var.vpc_connector_name : "${local.function_name}-connector"
  region         = var.region
  network        = var.vpc_connector_network
  ip_cidr_range  = var.vpc_connector_ip_range
  min_instances  = var.vpc_connector_min_instances
  max_instances  = var.vpc_connector_max_instances
  min_throughput = var.vpc_connector_min_throughput
  max_throughput = var.vpc_connector_max_throughput
}

# Cloud Function v1 (First Generation)
resource "google_cloudfunctions_function" "function_v1" {
  count = var.generation == 1 && var.deploy_function ? 1 : 0

  project = var.project_id
  name    = local.function_name
  region  = var.region

  description = var.description
  runtime     = var.runtime

  available_memory_mb   = var.available_memory_mb
  timeout              = local.timeout
  entry_point          = var.entry_point
  max_instances        = var.max_instances_v1
  min_instances        = var.min_instances_v1

  source_archive_bucket = local.source_archive_bucket
  source_archive_object = local.source_archive_object

  # Build configuration
  docker_registry = var.docker_registry
  docker_repository = var.docker_repository
  build_environment_variables = var.build_environment_variables
  build_worker_pool = var.build_worker_pool

  # Trigger configuration
  trigger_http = var.trigger_http && local.event_trigger == null

  dynamic "event_trigger" {
    for_each = local.event_trigger != null ? [local.event_trigger] : []
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

  # Network configuration
  vpc_connector                  = local.vpc_connector_name
  vpc_connector_egress_settings  = var.vpc_connector_egress_settings
  ingress_settings              = local.ingress_settings

  # Security
  service_account_email = local.service_account_email
  kms_key_name         = var.kms_key_name

  # Environment variables
  environment_variables = local.env_vars

  # Secret environment variables
  dynamic "secret_environment_variables" {
    for_each = var.secret_environment_variables
    content {
      key        = secret_environment_variables.key
      project_id = try(secret_environment_variables.value.project_id, var.project_id)
      secret     = secret_environment_variables.value.secret
      version    = secret_environment_variables.value.version
    }
  }

  # Secret volumes
  dynamic "secret_volumes" {
    for_each = var.secret_volumes
    content {
      mount_path = secret_volumes.value.mount_path
      project_id = try(secret_volumes.value.project_id, var.project_id)
      secret     = secret_volumes.value.secret

      dynamic "versions" {
        for_each = try(secret_volumes.value.versions, [])
        content {
          path    = versions.value.path
          version = versions.value.version
        }
      }
    }
  }

  labels = local.labels

  lifecycle {
    ignore_changes        = var.ignore_function_changes
    create_before_destroy = var.create_before_destroy
  }
}

# Cloud Function v1 IAM Member for Public Access
resource "google_cloudfunctions_function_iam_member" "invoker_v1" {
  count = var.generation == 1 && var.deploy_function && var.allow_public_access ? 1 : 0

  project        = var.project_id
  region         = var.region
  cloud_function = google_cloudfunctions_function.function_v1[0].name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

# Cloud Function v1 IAM Binding for Specific Members
resource "google_cloudfunctions_function_iam_binding" "invoker_binding_v1" {
  count = var.generation == 1 && var.deploy_function && length(var.invoker_members) > 0 ? 1 : 0

  project        = var.project_id
  region         = var.region
  cloud_function = google_cloudfunctions_function.function_v1[0].name

  role    = "roles/cloudfunctions.invoker"
  members = var.invoker_members
}

# Cloud Function v2 (Second Generation)
resource "google_cloudfunctions2_function" "function_v2" {
  count = var.generation == 2 && var.deploy_function ? 1 : 0

  project  = var.project_id
  name     = local.function_name
  location = var.region

  description = var.description

  build_config {
    runtime               = var.runtime
    entry_point          = var.entry_point
    environment_variables = var.build_environment_variables

    source {
      storage_source {
        bucket = local.source_archive_bucket
        object = local.source_archive_object
      }
    }

    docker_repository = var.docker_repository
    worker_pool      = var.build_worker_pool
  }

  service_config {
    max_instance_count               = var.max_instances_v2
    min_instance_count               = var.min_instances_v2
    available_memory                 = "${var.available_memory_mb}M"
    available_cpu                    = var.available_cpu
    timeout_seconds                  = local.timeout
    environment_variables            = local.env_vars
    max_instance_request_concurrency = var.max_instance_request_concurrency
    service_account_email           = local.service_account_email
    ingress_settings                = local.ingress_settings
    all_traffic_on_latest_revision  = var.all_traffic_on_latest_revision
    vpc_connector                    = local.vpc_connector_name
    vpc_connector_egress_settings   = var.vpc_connector_egress_settings

    # Secret environment variables
    dynamic "secret_environment_variables" {
      for_each = local.secret_env_vars
      content {
        key        = secret_environment_variables.key
        project_id = try(secret_environment_variables.value.project_id, var.project_id)
        secret     = secret_environment_variables.value.secret
        version    = secret_environment_variables.value.version
      }
    }

    # Secret volumes
    dynamic "secret_volumes" {
      for_each = var.secret_volumes
      content {
        mount_path = secret_volumes.value.mount_path
        project_id = try(secret_volumes.value.project_id, var.project_id)
        secret     = secret_volumes.value.secret

        dynamic "versions" {
          for_each = try(secret_volumes.value.versions, [])
          content {
            path    = versions.value.path
            version = versions.value.version
          }
        }
      }
    }
  }

  # Event trigger configuration
  dynamic "event_trigger" {
    for_each = local.event_trigger_v2 != null ? [local.event_trigger_v2] : []
    content {
      trigger_region        = event_trigger.value.trigger_region
      event_type           = event_trigger.value.event_type
      pubsub_topic         = event_trigger.value.pubsub_topic
      service_account_email = event_trigger.value.service_account_email
      retry_policy         = event_trigger.value.retry_policy

      dynamic "event_filters" {
        for_each = var.event_filters
        content {
          attribute = event_filters.value.attribute
          value     = event_filters.value.value
          operator  = try(event_filters.value.operator, "MATCH_PATH_PATTERN")
        }
      }
    }
  }

  labels = local.labels

  lifecycle {
    ignore_changes        = var.ignore_function_changes
    create_before_destroy = var.create_before_destroy
  }
}

# Cloud Function v2 IAM Member for Public Access
resource "google_cloud_run_service_iam_member" "invoker_v2" {
  count = var.generation == 2 && var.deploy_function && var.allow_public_access ? 1 : 0

  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.function_v2[0].name

  role   = "roles/run.invoker"
  member = "allUsers"
}

# Cloud Function v2 IAM Binding for Specific Members
resource "google_cloud_run_service_iam_binding" "invoker_binding_v2" {
  count = var.generation == 2 && var.deploy_function && length(var.invoker_members) > 0 ? 1 : 0

  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.function_v2[0].name

  role    = "roles/run.invoker"
  members = var.invoker_members
}

# Monitoring Alert Policies
resource "google_monitoring_alert_policy" "function_alerts" {
  for_each = var.create_monitoring_alerts ? var.monitoring_alerts : {}

  project      = var.project_id
  display_name = each.value.display_name
  combiner     = try(each.value.combiner, "OR")
  enabled      = try(each.value.enabled, true)

  conditions {
    display_name = each.value.condition_display_name

    condition_threshold {
      filter          = each.value.filter
      duration        = try(each.value.duration, "60s")
      comparison      = try(each.value.comparison, "COMPARISON_GT")
      threshold_value = each.value.threshold_value

      aggregations {
        alignment_period     = try(each.value.alignment_period, "60s")
        per_series_aligner   = try(each.value.per_series_aligner, "ALIGN_RATE")
        cross_series_reducer = try(each.value.cross_series_reducer, "REDUCE_NONE")
        group_by_fields      = try(each.value.group_by_fields, [])
      }

      dynamic "trigger" {
        for_each = each.value.trigger_count != null || each.value.trigger_percent != null ? [1] : []
        content {
          count   = try(each.value.trigger_count, null)
          percent = try(each.value.trigger_percent, null)
        }
      }
    }
  }

  notification_channels = try(each.value.notification_channels, [])

  alert_strategy {
    auto_close = try(each.value.auto_close, "1800s")

    dynamic "notification_rate_limit" {
      for_each = try(each.value.rate_limit, null) != null ? [each.value.rate_limit] : []
      content {
        period = notification_rate_limit.value.period
      }
    }
  }

  documentation {
    content   = try(each.value.documentation_content, "Alert for ${each.value.display_name}")
    mime_type = try(each.value.documentation_mime_type, "text/markdown")
    subject   = try(each.value.documentation_subject, null)
  }

  user_labels = merge(local.labels, try(each.value.labels, {}))
}

# Monitoring Dashboard
resource "google_monitoring_dashboard" "function_dashboard" {
  count = var.create_monitoring_dashboard ? 1 : 0

  project        = var.project_id
  dashboard_json = jsonencode({
    displayName = "${local.function_name} Dashboard"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          height = 4
          width  = 6
          widget = {
            title = "Function Executions"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"cloudfunctions.googleapis.com/function/execution_count\" resource.type=\"cloud_function\" resource.labels.function_name=\"${local.function_name}\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.function_name"]
                    }
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
        },
        {
          height = 4
          width  = 6
          xPos   = 6
          widget = {
            title = "Function Execution Time"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"cloudfunctions.googleapis.com/function/execution_times\" resource.type=\"cloud_function\" resource.labels.function_name=\"${local.function_name}\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_DELTA"
                      crossSeriesReducer = "REDUCE_PERCENTILE_95"
                      groupByFields      = ["resource.function_name"]
                    }
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Execution time (ms)"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          height = 4
          width  = 6
          yPos   = 4
          widget = {
            title = "Function Errors"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"cloudfunctions.googleapis.com/function/execution_count\" resource.type=\"cloud_function\" resource.labels.function_name=\"${local.function_name}\" metric.labels.status!=\"ok\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.status"]
                    }
                  }
                }
                plotType = "STACKED_BAR"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Errors/sec"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          height = 4
          width  = 6
          xPos   = 6
          yPos   = 4
          widget = {
            title = "Memory Utilization"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"cloudfunctions.googleapis.com/function/user_memory_bytes\" resource.type=\"cloud_function\" resource.labels.function_name=\"${local.function_name}\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MAX"
                      crossSeriesReducer = "REDUCE_MEAN"
                      groupByFields      = ["resource.function_name"]
                    }
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Memory (bytes)"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          height = 4
          width  = 12
          yPos   = 8
          widget = {
            title = "Active Instances"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"cloudfunctions.googleapis.com/function/active_instances\" resource.type=\"cloud_function\" resource.labels.function_name=\"${local.function_name}\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MAX"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.function_name"]
                    }
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Active Instances"
                scale = "LINEAR"
              }
            }
          }
        }
      ]
    }
  })
}

# Cloud Scheduler Job for Scheduled Functions
resource "google_cloud_scheduler_job" "function_scheduler" {
  count = var.create_scheduler_job ? 1 : 0

  project  = var.project_id
  region   = var.region
  name     = var.scheduler_job_name != null ? var.scheduler_job_name : "${local.function_name}-scheduler"
  schedule = var.scheduler_cron_schedule

  description     = var.scheduler_description
  time_zone      = var.scheduler_time_zone
  attempt_deadline = var.scheduler_attempt_deadline

  retry_config {
    retry_count          = var.scheduler_retry_count
    max_retry_duration   = var.scheduler_max_retry_duration
    min_backoff_duration = var.scheduler_min_backoff_duration
    max_backoff_duration = var.scheduler_max_backoff_duration
    max_doublings        = var.scheduler_max_doublings
  }

  dynamic "http_target" {
    for_each = var.generation == 1 && var.trigger_http ? [1] : []
    content {
      uri         = google_cloudfunctions_function.function_v1[0].https_trigger_url
      http_method = var.scheduler_http_method
      headers     = var.scheduler_http_headers
      body        = var.scheduler_http_body != null ? base64encode(var.scheduler_http_body) : null

      dynamic "oidc_token" {
        for_each = var.scheduler_oidc_token != null ? [var.scheduler_oidc_token] : []
        content {
          service_account_email = oidc_token.value.service_account_email
          audience             = try(oidc_token.value.audience, null)
        }
      }

      dynamic "oauth_token" {
        for_each = var.scheduler_oauth_token != null ? [var.scheduler_oauth_token] : []
        content {
          service_account_email = oauth_token.value.service_account_email
          scope                = oauth_token.value.scope
        }
      }
    }
  }

  dynamic "http_target" {
    for_each = var.generation == 2 ? [1] : []
    content {
      uri         = google_cloudfunctions2_function.function_v2[0].service_config[0].uri
      http_method = var.scheduler_http_method
      headers     = var.scheduler_http_headers
      body        = var.scheduler_http_body != null ? base64encode(var.scheduler_http_body) : null

      dynamic "oidc_token" {
        for_each = var.scheduler_oidc_token != null ? [var.scheduler_oidc_token] : []
        content {
          service_account_email = oidc_token.value.service_account_email
          audience             = try(oidc_token.value.audience, null)
        }
      }

      dynamic "oauth_token" {
        for_each = var.scheduler_oauth_token != null ? [var.scheduler_oauth_token] : []
        content {
          service_account_email = oauth_token.value.service_account_email
          scope                = oauth_token.value.scope
        }
      }
    }
  }

  dynamic "pubsub_target" {
    for_each = var.scheduler_pubsub_target != null ? [var.scheduler_pubsub_target] : []
    content {
      topic_name = pubsub_target.value.topic_name
      data       = try(base64encode(pubsub_target.value.data), null)
      attributes = try(pubsub_target.value.attributes, {})
    }
  }
}

# Budget Alert for Function Costs
resource "google_billing_budget" "function_budget" {
  count = var.create_budget_alert ? 1 : 0

  billing_account = var.billing_account
  display_name    = "${local.function_name} Budget"

  budget_filter {
    projects               = ["projects/${var.project_id}"]
    labels                = local.labels
    services              = ["cloudfunctions.googleapis.com"]
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
    calendar_period       = var.budget_calendar_period

    dynamic "custom_period" {
      for_each = var.budget_custom_period != null ? [var.budget_custom_period] : []
      content {
        start_date {
          year  = custom_period.value.start_year
          month = custom_period.value.start_month
          day   = custom_period.value.start_day
        }
        end_date {
          year  = custom_period.value.end_year
          month = custom_period.value.end_month
          day   = custom_period.value.end_day
        }
      }
    }
  }

  amount {
    dynamic "specified_amount" {
      for_each = var.budget_amount != null ? [var.budget_amount] : []
      content {
        currency_code = specified_amount.value.currency_code
        units        = tostring(specified_amount.value.units)
        nanos        = try(specified_amount.value.nanos, null)
      }
    }

    dynamic "last_period_amount" {
      for_each = var.budget_amount == null ? [1] : []
      content {
      }
    }
  }

  dynamic "threshold_rules" {
    for_each = var.budget_threshold_rules
    content {
      threshold_percent = threshold_rules.value.threshold_percent
      spend_basis      = try(threshold_rules.value.spend_basis, "CURRENT_SPEND")
    }
  }

  all_updates_rule {
    pubsub_topic                       = var.budget_pubsub_topic
    schema_version                     = "1.0"
    monitoring_notification_channels   = var.budget_notification_channels
    disable_default_iam_recipients    = var.budget_disable_default_recipients
  }
}