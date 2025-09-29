# Cloud Run Module - Main Configuration

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
  }
}

# Local variables
locals {
  service_name = var.service_name != null ? var.service_name : "${var.name_prefix}-${var.environment}"

  labels = merge(
    {
      environment = var.environment
      managed_by  = "terraform"
      service     = local.service_name
    },
    var.labels
  )

  service_account_email = var.create_service_account ? (
    google_service_account.service_sa[0].email
  ) : var.service_account_email

  annotations = merge(
    {
      "run.googleapis.com/launch-stage" = var.launch_stage
    },
    var.ingress == "internal" ? {
      "run.googleapis.com/ingress" = "internal"
      } : {
      "run.googleapis.com/ingress" = var.ingress
    },
    var.binary_authorization ? {
      "run.googleapis.com/binary-authorization" = "default"
    } : {},
    var.annotations
  )

  env_vars = [
    for k, v in merge(
      {
        SERVICE_NAME = local.service_name
        ENVIRONMENT  = var.environment
        PROJECT_ID   = var.project_id
        REGION       = var.region
      },
      var.environment_variables
      ) : {
      name  = k
      value = v
    }
  ]

  secret_env_vars = [
    for k, v in var.secret_environment_variables : {
      name = k
      value_from = [{
        secret_key_ref = {
          name = v.secret
          key  = v.version
        }
      }]
    }
  ]

  volume_mounts = [
    for v in var.volumes : {
      name       = v.name
      mount_path = v.mount_path
    }
  ]

  volumes = [
    for v in var.volumes : merge(
      {
        name = v.name
      },
      v.secret != null ? {
        secret = {
          secret_name = v.secret.secret_name
          items = [
            for item in try(v.secret.items, []) : {
              key  = item.key
              path = item.path
            }
          ]
        }
      } : {}
    )
  ]
}

# Service Account for Cloud Run
resource "google_service_account" "service_sa" {
  count = var.create_service_account ? 1 : 0

  project      = var.project_id
  account_id   = var.service_account_name != null ? var.service_account_name : "${local.service_name}-sa"
  display_name = "Service Account for Cloud Run ${local.service_name}"
  description  = "Service account for Cloud Run service ${local.service_name}"
}

# Service Account Key
resource "google_service_account_key" "service_sa_key" {
  count = var.create_service_account && var.create_service_account_key ? 1 : 0

  service_account_id = google_service_account.service_sa[0].name
  key_algorithm      = "KEY_ALG_RSA_2048"
}

# IAM Roles for Service Account
resource "google_project_iam_member" "service_sa_roles" {
  for_each = var.create_service_account && var.grant_service_account_roles ? toset(var.service_account_roles) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.service_sa[0].email}"
}

# Cloud Run Service
resource "google_cloud_run_v2_service" "service" {
  count = var.deploy_service ? 1 : 0

  project  = var.project_id
  name     = local.service_name
  location = var.region

  description = var.description
  labels      = local.labels

  ingress      = var.ingress
  launch_stage = var.launch_stage
  binary_authorization = var.binary_authorization ? {
    use_default              = true
    breakglass_justification = var.binary_authorization_breakglass
  } : null

  template {
    labels      = local.labels
    annotations = local.annotations

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    service_account                  = local.service_account_email
    execution_environment            = var.execution_environment
    encryption_key                   = var.encryption_key
    max_instance_request_concurrency = var.max_concurrency
    timeout                          = "${var.timeout}s"
    session_affinity                 = var.session_affinity

    dynamic "vpc_access" {
      for_each = var.vpc_connector != null || var.vpc_network != null ? [1] : []
      content {
        connector = var.vpc_connector
        egress    = var.vpc_egress

        dynamic "network_interfaces" {
          for_each = var.vpc_network != null ? [1] : []
          content {
            network    = var.vpc_network
            subnetwork = var.vpc_subnetwork
            tags       = var.vpc_network_tags
          }
        }
      }
    }

    containers {
      name  = var.container_name != null ? var.container_name : local.service_name
      image = var.container_image

      command     = var.container_command
      args        = var.container_args
      working_dir = var.container_working_dir

      dynamic "ports" {
        for_each = var.container_port != null ? [var.container_port] : []
        content {
          name           = try(ports.value.name, "http1")
          container_port = ports.value.port
        }
      }

      dynamic "env" {
        for_each = local.env_vars
        content {
          name  = env.value.name
          value = env.value.value
        }
      }

      dynamic "env" {
        for_each = local.secret_env_vars
        content {
          name = env.value.name
          dynamic "value_source" {
            for_each = env.value.value_from
            content {
              secret_key_ref {
                secret  = value_source.value.secret_key_ref.name
                version = value_source.value.secret_key_ref.key
              }
            }
          }
        }
      }

      dynamic "volume_mounts" {
        for_each = local.volume_mounts
        content {
          name       = volume_mounts.value.name
          mount_path = volume_mounts.value.mount_path
        }
      }

      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
        cpu_idle          = var.cpu_idle
        startup_cpu_boost = var.startup_cpu_boost
      }

      dynamic "startup_probe" {
        for_each = var.startup_probe != null ? [var.startup_probe] : []
        content {
          initial_delay_seconds = try(startup_probe.value.initial_delay_seconds, 0)
          timeout_seconds       = try(startup_probe.value.timeout_seconds, 1)
          period_seconds        = try(startup_probe.value.period_seconds, 10)
          failure_threshold     = try(startup_probe.value.failure_threshold, 3)

          dynamic "http_get" {
            for_each = try(startup_probe.value.http_get, null) != null ? [startup_probe.value.http_get] : []
            content {
              path = try(http_get.value.path, "/")
              port = try(http_get.value.port, null)
              dynamic "http_headers" {
                for_each = try(http_get.value.http_headers, [])
                content {
                  name  = http_headers.value.name
                  value = http_headers.value.value
                }
              }
            }
          }

          dynamic "tcp_socket" {
            for_each = try(startup_probe.value.tcp_socket, null) != null ? [startup_probe.value.tcp_socket] : []
            content {
              port = tcp_socket.value.port
            }
          }

          dynamic "grpc" {
            for_each = try(startup_probe.value.grpc, null) != null ? [startup_probe.value.grpc] : []
            content {
              port    = try(grpc.value.port, null)
              service = try(grpc.value.service, null)
            }
          }
        }
      }

      dynamic "liveness_probe" {
        for_each = var.liveness_probe != null ? [var.liveness_probe] : []
        content {
          initial_delay_seconds = try(liveness_probe.value.initial_delay_seconds, 0)
          timeout_seconds       = try(liveness_probe.value.timeout_seconds, 1)
          period_seconds        = try(liveness_probe.value.period_seconds, 10)
          failure_threshold     = try(liveness_probe.value.failure_threshold, 3)

          dynamic "http_get" {
            for_each = try(liveness_probe.value.http_get, null) != null ? [liveness_probe.value.http_get] : []
            content {
              path = try(http_get.value.path, "/")
              port = try(http_get.value.port, null)
              dynamic "http_headers" {
                for_each = try(http_get.value.http_headers, [])
                content {
                  name  = http_headers.value.name
                  value = http_headers.value.value
                }
              }
            }
          }

          dynamic "tcp_socket" {
            for_each = try(liveness_probe.value.tcp_socket, null) != null ? [liveness_probe.value.tcp_socket] : []
            content {
              port = tcp_socket.value.port
            }
          }

          dynamic "grpc" {
            for_each = try(liveness_probe.value.grpc, null) != null ? [liveness_probe.value.grpc] : []
            content {
              port    = try(grpc.value.port, null)
              service = try(grpc.value.service, null)
            }
          }
        }
      }
    }

    dynamic "volumes" {
      for_each = var.volumes
      content {
        name = volumes.value.name

        dynamic "secret" {
          for_each = volumes.value.secret != null ? [volumes.value.secret] : []
          content {
            secret = secret.value.secret_name
            dynamic "items" {
              for_each = try(secret.value.items, [])
              content {
                path    = items.value.path
                version = items.value.version
                mode    = items.value.mode
              }
            }
          }
        }

        dynamic "cloud_sql_instance" {
          for_each = volumes.value.cloud_sql_instance != null ? [volumes.value.cloud_sql_instance] : []
          content {
            instances = cloud_sql_instance.value.instances
          }
        }

        dynamic "gcs" {
          for_each = volumes.value.gcs != null ? [volumes.value.gcs] : []
          content {
            bucket    = gcs.value.bucket
            read_only = try(gcs.value.read_only, false)
          }
        }

        dynamic "nfs" {
          for_each = volumes.value.nfs != null ? [volumes.value.nfs] : []
          content {
            server    = nfs.value.server
            path      = nfs.value.path
            read_only = try(nfs.value.read_only, false)
          }
        }

        dynamic "empty_dir" {
          for_each = volumes.value.empty_dir != null ? [volumes.value.empty_dir] : []
          content {
            medium     = try(empty_dir.value.medium, "MEMORY")
            size_limit = try(empty_dir.value.size_limit, null)
          }
        }
      }
    }
  }

  traffic {
    type     = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent  = var.traffic_percent
    revision = var.traffic_revision
    tag      = var.traffic_tag
  }

  lifecycle {
    ignore_changes        = var.ignore_service_changes
    create_before_destroy = var.create_before_destroy
  }

  depends_on = [
    google_project_iam_member.service_sa_roles
  ]
}

# Cloud Run Service IAM Member for Public Access
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  count = var.deploy_service && var.allow_public_access ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.service[0].name

  role   = "roles/run.invoker"
  member = "allUsers"
}

# Cloud Run Service IAM Binding for Specific Members
resource "google_cloud_run_v2_service_iam_binding" "invoker_binding" {
  count = var.deploy_service && length(var.invoker_members) > 0 ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.service[0].name

  role    = "roles/run.invoker"
  members = var.invoker_members
}

# Domain Mapping
resource "google_cloud_run_domain_mapping" "domain" {
  count = var.deploy_service && var.domain_name != null ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = var.domain_name

  metadata {
    namespace = var.project_id
    labels    = local.labels
    annotations = {
      "run.googleapis.com/launch-stage" = var.launch_stage
    }
  }

  spec {
    route_name       = google_cloud_run_v2_service.service[0].name
    certificate_mode = var.certificate_mode
    force_override   = var.force_domain_override
  }

  lifecycle {
    ignore_changes = var.ignore_domain_changes
  }
}

# Cloud Run Job
resource "google_cloud_run_v2_job" "job" {
  count = var.deploy_job ? 1 : 0

  project  = var.project_id
  name     = var.job_name != null ? var.job_name : "${local.service_name}-job"
  location = var.region

  labels = local.labels

  template {
    labels      = local.labels
    annotations = local.annotations

    parallelism  = var.job_parallelism
    task_count   = var.job_task_count
    task_timeout = "${var.job_task_timeout}s"

    template {
      service_account       = local.service_account_email
      execution_environment = var.execution_environment
      encryption_key        = var.encryption_key
      max_retries           = var.job_max_retries

      dynamic "vpc_access" {
        for_each = var.vpc_connector != null || var.vpc_network != null ? [1] : []
        content {
          connector = var.vpc_connector
          egress    = var.vpc_egress

          dynamic "network_interfaces" {
            for_each = var.vpc_network != null ? [1] : []
            content {
              network    = var.vpc_network
              subnetwork = var.vpc_subnetwork
              tags       = var.vpc_network_tags
            }
          }
        }
      }

      containers {
        name  = var.container_name != null ? var.container_name : "${local.service_name}-job"
        image = var.container_image

        command     = var.job_container_command
        args        = var.job_container_args
        working_dir = var.container_working_dir

        dynamic "env" {
          for_each = local.env_vars
          content {
            name  = env.value.name
            value = env.value.value
          }
        }

        dynamic "env" {
          for_each = local.secret_env_vars
          content {
            name = env.value.name
            dynamic "value_source" {
              for_each = env.value.value_from
              content {
                secret_key_ref {
                  secret  = value_source.value.secret_key_ref.name
                  version = value_source.value.secret_key_ref.key
                }
              }
            }
          }
        }

        dynamic "volume_mounts" {
          for_each = local.volume_mounts
          content {
            name       = volume_mounts.value.name
            mount_path = volume_mounts.value.mount_path
          }
        }

        resources {
          limits = {
            cpu    = var.job_cpu_limit
            memory = var.job_memory_limit
          }
        }
      }

      dynamic "volumes" {
        for_each = var.volumes
        content {
          name = volumes.value.name

          dynamic "secret" {
            for_each = volumes.value.secret != null ? [volumes.value.secret] : []
            content {
              secret = secret.value.secret_name
              dynamic "items" {
                for_each = try(secret.value.items, [])
                content {
                  path    = items.value.path
                  version = items.value.version
                  mode    = items.value.mode
                }
              }
            }
          }

          dynamic "cloud_sql_instance" {
            for_each = volumes.value.cloud_sql_instance != null ? [volumes.value.cloud_sql_instance] : []
            content {
              instances = cloud_sql_instance.value.instances
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes        = var.ignore_job_changes
    create_before_destroy = var.create_before_destroy
  }

  depends_on = [
    google_project_iam_member.service_sa_roles
  ]
}

# Cloud Scheduler Job for Cloud Run Job
resource "google_cloud_scheduler_job" "job_scheduler" {
  count = var.deploy_job && var.create_job_scheduler ? 1 : 0

  project  = var.project_id
  region   = var.region
  name     = var.job_scheduler_name != null ? var.job_scheduler_name : "${var.job_name != null ? var.job_name : "${local.service_name}-job"}-scheduler"
  schedule = var.job_scheduler_schedule

  description      = var.job_scheduler_description
  time_zone        = var.job_scheduler_time_zone
  attempt_deadline = var.job_scheduler_attempt_deadline

  retry_config {
    retry_count          = var.job_scheduler_retry_count
    max_retry_duration   = var.job_scheduler_max_retry_duration
    min_backoff_duration = var.job_scheduler_min_backoff_duration
    max_backoff_duration = var.job_scheduler_max_backoff_duration
    max_doublings        = var.job_scheduler_max_doublings
  }

  http_target {
    uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.job[0].name}:run"
    http_method = "POST"
    headers = {
      "Content-Type" = "application/json"
    }

    oauth_token {
      service_account_email = local.service_account_email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }
}

# Monitoring Alert Policies
resource "google_monitoring_alert_policy" "service_alerts" {
  for_each = var.deploy_service && var.create_monitoring_alerts ? var.monitoring_alerts : {}

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
resource "google_monitoring_dashboard" "service_dashboard" {
  count = var.deploy_service && var.create_monitoring_dashboard ? 1 : 0

  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "${local.service_name} Dashboard"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          height = 4
          width  = 6
          widget = {
            title = "Request Count"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"run.googleapis.com/request_count\" resource.type=\"cloud_run_revision\" resource.labels.service_name=\"${local.service_name}\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.service_name"]
                    }
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
          height = 4
          width  = 6
          xPos   = 6
          widget = {
            title = "Request Latencies"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\" resource.labels.service_name=\"${local.service_name}\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_DELTA"
                      crossSeriesReducer = "REDUCE_PERCENTILE_95"
                      groupByFields      = ["resource.service_name"]
                    }
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Latency (ms)"
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
            title = "Instance Count"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"run.googleapis.com/container/instance_count\" resource.type=\"cloud_run_revision\" resource.labels.service_name=\"${local.service_name}\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MAX"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.service_name"]
                    }
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Instances"
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
            title = "CPU Utilization"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"run.googleapis.com/container/cpu/utilizations\" resource.type=\"cloud_run_revision\" resource.labels.service_name=\"${local.service_name}\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_MEAN"
                      groupByFields      = ["resource.service_name"]
                    }
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "CPU Utilization (%)"
                scale = "LINEAR"
              }
            }
          }
        }
      ]
    }
  })
}