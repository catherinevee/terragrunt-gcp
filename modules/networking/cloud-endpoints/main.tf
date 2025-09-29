# Cloud Endpoints Module - Main Configuration
# Provides API management, monitoring, authentication, and quota management for REST and gRPC APIs

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
  }
}

# Local variables for configuration
locals {
  # API configuration defaults
  api_defaults = {
    api_version         = "v1"
    display_name        = ""
    management_features = ["LOGGING", "MONITORING", "TRACING"]
    quota_limits        = {}
    authentication      = {}
    backend_rules       = []
    documentation       = {}
  }

  # Merge user configs with defaults
  managed_services = {
    for name, config in var.managed_services : name => merge(
      local.api_defaults,
      config,
      {
        service_name = "${name}.endpoints.${var.project_id}.cloud.goog"
        config_id    = substr(md5(jsonencode(config)), 0, 8)
      }
    )
  }

  # OpenAPI specs processing
  openapi_specs = {
    for name, config in var.openapi_services : name => {
      service_name = "${name}.endpoints.${var.project_id}.cloud.goog"
      openapi_config = templatefile(
        config.openapi_spec_path,
        merge(
          {
            project_id   = var.project_id
            service_name = "${name}.endpoints.${var.project_id}.cloud.goog"
            backend_url  = config.backend_url
            api_version  = coalesce(config.api_version, "v1")
          },
          config.template_variables
        )
      )
    }
  }

  # gRPC service configs
  grpc_configs = {
    for name, config in var.grpc_services : name => {
      service_name = "${name}.endpoints.${var.project_id}.cloud.goog"
      service_config = {
        type                = "grpc"
        backend_address     = config.backend_address
        backend_port        = config.backend_port
        transcoding_enabled = config.enable_transcoding
        proto_descriptors   = config.proto_descriptor_path != null ? filebase64(config.proto_descriptor_path) : null
      }
    }
  }

  # Service perimeter for VPC Service Controls
  service_perimeter = var.enable_vpc_service_controls ? {
    resources           = [for name, _ in local.managed_services : "projects/${var.project_id}/services/${name}.endpoints.${var.project_id}.cloud.goog"]
    restricted_services = ["servicemanagement.googleapis.com", "servicecontrol.googleapis.com", "endpoints.googleapis.com"]
    access_levels       = var.vpc_access_levels
  } : null

  # API Gateway configurations
  api_gateways = var.enable_api_gateway ? {
    for name, config in var.api_gateway_configs : name => {
      api_id       = "${name}-api"
      gateway_id   = "${name}-gateway"
      region       = config.region
      display_name = coalesce(config.display_name, "${title(name)} API Gateway")
      labels       = merge(var.labels, config.labels)
    }
  } : {}

  # Service monitoring configuration
  monitoring_config = var.enable_monitoring ? {
    metrics = [
      "serviceruntime.googleapis.com/api/request_count",
      "serviceruntime.googleapis.com/api/request_latencies",
      "serviceruntime.googleapis.com/api/request_bytes",
      "serviceruntime.googleapis.com/api/response_bytes",
      "serviceruntime.googleapis.com/quota/exceeded"
    ]
    notification_channels = var.notification_channels
    alert_policies        = var.alert_policies
  } : null
}

# Enable required APIs
resource "google_project_service" "endpoints_apis" {
  for_each = toset(var.enable_apis ? [
    "endpoints.googleapis.com",
    "servicemanagement.googleapis.com",
    "servicecontrol.googleapis.com",
    "serviceusage.googleapis.com",
    "apigateway.googleapis.com",
    "apikeys.googleapis.com"
  ] : [])

  project                    = var.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}

# Service account for Endpoints
resource "google_service_account" "endpoints_sa" {
  count = var.create_service_account ? 1 : 0

  account_id   = var.service_account_id
  display_name = "Cloud Endpoints Service Account"
  description  = "Service account for Cloud Endpoints API management"
  project      = var.project_id
}

# Service account IAM bindings
resource "google_project_iam_member" "endpoints_sa_roles" {
  for_each = var.create_service_account ? toset(var.service_account_roles) : []

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.endpoints_sa[0].email}"

  depends_on = [google_service_account.endpoints_sa]
}

# Managed Services for OpenAPI specs
resource "google_endpoints_service" "openapi_services" {
  for_each = local.openapi_specs

  service_name   = each.value.service_name
  project        = var.project_id
  openapi_config = each.value.openapi_config

  depends_on = [google_project_service.endpoints_apis]
}

# Service configs for gRPC services
resource "google_endpoints_service" "grpc_services" {
  for_each = local.grpc_configs

  service_name = each.value.service_name
  project      = var.project_id

  grpc_config = yamlencode({
    type = "google.api.Service"
    name = each.value.service_name

    backend = {
      rules = [{
        selector = "*"
        address  = each.value.service_config.backend_address
        port     = each.value.service_config.backend_port
        deadline = var.backend_deadline
      }]
    }

    authentication = var.authentication_config

    usage = var.enable_quota ? {
      rules = [
        for quota_name, quota_config in var.quota_configs : {
          selector                 = quota_config.selector
          allow_unregistered_calls = quota_config.allow_unregistered
          skip_service_control     = quota_config.skip_control
        }
      ]
    } : null

    monitoring = var.enable_monitoring ? {
      producer_destinations = [{
        monitored_resource = "api"
        metrics            = local.monitoring_config.metrics
      }]

      consumer_destinations = [{
        monitored_resource = "api"
        metrics            = local.monitoring_config.metrics
      }]
    } : null

    logging = var.enable_logging ? {
      producer_destinations = [{
        monitored_resource = "api"
        logs = [
          "endpoints_log",
          "request_log",
          "backend_log"
        ]
      }]
    } : null
  })

  protoc_output_base64 = each.value.service_config.proto_descriptors

  depends_on = [google_project_service.endpoints_apis]
}

# Service rollouts for controlled deployments
resource "google_endpoints_service_iam_member" "rollout_permissions" {
  for_each = var.enable_controlled_rollout ? merge(
    { for k, v in local.openapi_specs : k => v.service_name },
    { for k, v in local.grpc_configs : k => v.service_name }
  ) : {}

  service_name = each.value
  role         = "roles/endpoints.serviceAgent"
  member       = "serviceAccount:${var.project_id}@cloudservices.gserviceaccount.com"

  depends_on = [
    google_endpoints_service.openapi_services,
    google_endpoints_service.grpc_services
  ]
}

# API Keys for authentication
resource "google_apikeys_key" "api_keys" {
  for_each = var.api_keys

  name         = each.key
  display_name = each.value.display_name
  project      = var.project_id

  restrictions {
    api_targets {
      service = each.value.service
      methods = each.value.allowed_methods
    }

    dynamic "browser_key_restrictions" {
      for_each = each.value.browser_restrictions != null ? [each.value.browser_restrictions] : []
      content {
        allowed_referrers = browser_key_restrictions.value.allowed_referrers
      }
    }

    dynamic "server_key_restrictions" {
      for_each = each.value.server_restrictions != null ? [each.value.server_restrictions] : []
      content {
        allowed_ips = server_key_restrictions.value.allowed_ips
      }
    }

    dynamic "android_key_restrictions" {
      for_each = each.value.android_restrictions != null ? [each.value.android_restrictions] : []
      content {
        allowed_applications {
          package_name     = android_key_restrictions.value.package_name
          sha1_fingerprint = android_key_restrictions.value.sha1_fingerprint
        }
      }
    }

    dynamic "ios_key_restrictions" {
      for_each = each.value.ios_restrictions != null ? [each.value.ios_restrictions] : []
      content {
        allowed_bundle_ids = ios_key_restrictions.value.allowed_bundle_ids
      }
    }
  }

  depends_on = [google_project_service.endpoints_apis]
}

# API Gateway resources
resource "google_api_gateway_api" "gateways" {
  for_each = local.api_gateways

  provider     = google-beta
  api_id       = each.value.api_id
  project      = var.project_id
  display_name = each.value.display_name
  labels       = each.value.labels

  depends_on = [google_project_service.endpoints_apis]
}

# API Gateway configs
resource "google_api_gateway_api_config" "gateway_configs" {
  for_each = local.api_gateways

  provider             = google-beta
  api                  = google_api_gateway_api.gateways[each.key].api_id
  api_config_id_prefix = "${each.key}-config"
  project              = var.project_id

  openapi_documents {
    document {
      path = "openapi.yaml"
      contents = base64encode(
        var.api_gateway_configs[each.key].openapi_spec != null ?
        file(var.api_gateway_configs[each.key].openapi_spec) :
        var.api_gateway_configs[each.key].openapi_spec_inline
      )
    }
  }

  gateway_config {
    backend_config {
      google_service_account = var.api_gateway_configs[each.key].backend_service_account
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_api_gateway_api.gateways]
}

# API Gateway deployments
resource "google_api_gateway_gateway" "gateway_deployments" {
  for_each = local.api_gateways

  provider     = google-beta
  gateway_id   = each.value.gateway_id
  api_config   = google_api_gateway_api_config.gateway_configs[each.key].id
  region       = each.value.region
  project      = var.project_id
  display_name = "${each.value.display_name} Gateway"
  labels       = each.value.labels

  depends_on = [google_api_gateway_api_config.gateway_configs]
}

# Service Consumer Management for quota and billing
resource "google_service_management_consumer_quota_override" "quota_overrides" {
  for_each = var.quota_overrides

  provider       = google-beta
  service        = each.value.service
  consumer       = "project:${var.project_id}"
  metric         = each.value.metric
  limit          = each.value.limit
  override_value = each.value.value
  force          = each.value.force

  depends_on = [
    google_endpoints_service.openapi_services,
    google_endpoints_service.grpc_services
  ]
}

# Monitoring dashboards for API metrics
resource "google_monitoring_dashboard" "api_dashboard" {
  count = var.enable_monitoring && var.create_dashboard ? 1 : 0

  dashboard_json = jsonencode({
    displayName = "${var.dashboard_display_name}"
    mosaicLayout = {
      columns = 12
      tiles = [
        # Request rate
        {
          width  = 6
          height = 4
          widget = {
            title = "API Request Rate"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"serviceruntime.googleapis.com/api/request_count\" resource.type=\"api\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["resource.service"]
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
              yAxis = {
                label = "requests/sec"
                scale = "LINEAR"
              }
            }
          }
        },
        # Latency
        {
          xPos   = 6
          width  = 6
          height = 4
          widget = {
            title = "API Latency (95th percentile)"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"serviceruntime.googleapis.com/api/request_latencies\" resource.type=\"api\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_PERCENTILE_95"
                        crossSeriesReducer = "REDUCE_MEAN"
                        groupByFields      = ["resource.service"]
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
              yAxis = {
                label = "milliseconds"
                scale = "LINEAR"
              }
            }
          }
        },
        # Error rate
        {
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "API Error Rate"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"serviceruntime.googleapis.com/api/request_count\" resource.type=\"api\" metric.label.response_code_class=\"5xx\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["resource.service"]
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
              yAxis = {
                label = "errors/sec"
                scale = "LINEAR"
              }
            }
          }
        },
        # Quota usage
        {
          xPos   = 6
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "API Quota Usage"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"serviceruntime.googleapis.com/quota/exceeded\" resource.type=\"consumer_quota\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.quota_metric"]
                      }
                    }
                  }
                  plotType = "STACKED_AREA"
                }
              ]
            }
          }
        },
        # Backend health
        {
          yPos   = 8
          width  = 12
          height = 4
          widget = {
            title = "Backend Health Status"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"serviceruntime.googleapis.com/api/backend_latencies\" resource.type=\"api\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_MEAN"
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_LINE"
              }
            }
          }
        }
      ]
    }
  })

  project = var.project_id
}

# Alert policies for API monitoring
resource "google_monitoring_alert_policy" "api_alerts" {
  for_each = var.enable_monitoring ? var.alert_policies : {}

  display_name = each.value.display_name
  project      = var.project_id
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
        alignment_period     = each.value.alignment_period
        per_series_aligner   = each.value.per_series_aligner
        cross_series_reducer = each.value.cross_series_reducer
        group_by_fields      = each.value.group_by_fields
      }

      trigger {
        count   = each.value.trigger_count
        percent = each.value.trigger_percent
      }
    }
  }

  notification_channels = each.value.notification_channels

  user_labels = merge(
    var.labels,
    each.value.labels
  )

  alert_strategy {
    auto_close = each.value.auto_close_duration

    dynamic "notification_rate_limit" {
      for_each = each.value.rate_limit != null ? [each.value.rate_limit] : []
      content {
        period = notification_rate_limit.value
      }
    }
  }
}

# Service perimeter for VPC Service Controls
resource "google_access_context_manager_service_perimeter_resource" "endpoints_perimeter" {
  for_each = var.enable_vpc_service_controls ? local.service_perimeter.resources : []

  perimeter_name = var.vpc_service_perimeter_name
  resource       = each.value
}

# IAM bindings for services
resource "google_endpoints_service_iam_binding" "service_bindings" {
  for_each = var.service_iam_bindings

  service_name = "${each.key}.endpoints.${var.project_id}.cloud.goog"
  role         = each.value.role
  members      = each.value.members

  depends_on = [
    google_endpoints_service.openapi_services,
    google_endpoints_service.grpc_services
  ]
}

# Consumer IAM policies for service access control
resource "google_endpoints_service_consumers_iam_binding" "consumer_bindings" {
  for_each = var.consumer_iam_bindings

  service_name  = "${each.key}.endpoints.${var.project_id}.cloud.goog"
  consumer_name = "project:${var.project_id}"
  role          = each.value.role
  members       = each.value.members

  depends_on = [
    google_endpoints_service.openapi_services,
    google_endpoints_service.grpc_services
  ]
}