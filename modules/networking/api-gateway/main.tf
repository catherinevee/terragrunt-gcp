# API Gateway Module - Main Configuration

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
  api_name = var.api_name != null ? var.api_name : "${var.name_prefix}-${var.environment}"
  
  labels = merge(
    {
      environment = var.environment
      managed_by  = "terraform"
      service     = "api-gateway"
      api_name    = local.api_name
    },
    var.labels
  )
  
  gateway_name = var.gateway_name != null ? var.gateway_name : "${local.api_name}-gateway"
  config_name  = var.config_name != null ? var.config_name : "${local.api_name}-config-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  
  # Process OpenAPI spec
  openapi_spec = var.openapi_spec_path != null ? file(var.openapi_spec_path) : var.openapi_spec_inline
  
  # Merge backend config with OpenAPI spec if provided
  processed_spec = var.grpc_service_configs != null ? jsonencode(merge(
    jsondecode(local.openapi_spec),
    {
      "x-google-backend" = var.grpc_service_configs
    }
  )) : local.openapi_spec
}

# Service Account for API Gateway
resource "google_service_account" "api_gateway_sa" {
  count = var.create_service_account ? 1 : 0
  
  project      = var.project_id
  account_id   = var.service_account_name != null ? var.service_account_name : "${local.api_name}-sa"
  display_name = "Service Account for API Gateway ${local.api_name}"
  description  = "Service account used by API Gateway ${local.api_name}"
}

# IAM roles for service account
resource "google_project_iam_member" "api_gateway_sa_roles" {
  for_each = var.create_service_account && var.grant_service_account_roles ? toset(var.service_account_roles) : toset([])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.api_gateway_sa[0].email}"
}

# API Gateway API
resource "google_api_gateway_api" "api" {
  count = var.create_api ? 1 : 0
  
  provider = google-beta
  project  = var.project_id
  api_id   = local.api_name
  
  display_name = var.display_name != null ? var.display_name : local.api_name
  
  labels = local.labels
  
  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway API Config
resource "google_api_gateway_api_config" "api_config" {
  count = var.create_api && var.deploy_config ? 1 : 0
  
  provider      = google-beta
  project       = var.project_id
  api           = google_api_gateway_api.api[0].api_id
  api_config_id = local.config_name
  
  display_name = var.config_display_name != null ? var.config_display_name : local.config_name
  
  # OpenAPI specification
  openapi_documents {
    document {
      path     = "openapi.yaml"
      contents = base64encode(local.processed_spec)
    }
  }
  
  # Gateway config
  dynamic "gateway_config" {
    for_each = var.gateway_config != null ? [var.gateway_config] : []
    content {
      backend_config {
        google_service_account = var.create_service_account ? google_service_account.api_gateway_sa[0].email : var.gateway_config.service_account_email
      }
    }
  }
  
  # Managed service configurations
  dynamic "managed_service_configs" {
    for_each = var.managed_service_configs
    content {
      path     = managed_service_configs.value.path
      contents = base64encode(managed_service_configs.value.contents)
    }
  }
  
  # gRPC services
  dynamic "grpc_services" {
    for_each = var.grpc_services
    content {
      file_descriptor_set {
        path     = grpc_services.value.file_descriptor_set_path
        contents = filebase64(grpc_services.value.file_descriptor_set_contents)
      }
      
      dynamic "source" {
        for_each = grpc_services.value.sources
        content {
          path     = source.value.path
          contents = base64encode(source.value.contents)
        }
      }
    }
  }
  
  labels = local.labels
  
  lifecycle {
    create_before_destroy = true
    ignore_changes       = var.ignore_config_changes
  }
}

# API Gateway Gateway (Deployment)
resource "google_api_gateway_gateway" "gateway" {
  count = var.create_api && var.deploy_gateway ? 1 : 0
  
  provider   = google-beta
  project    = var.project_id
  gateway_id = local.gateway_name
  api_config = google_api_gateway_api_config.api_config[0].id
  region     = var.region
  
  display_name = var.gateway_display_name != null ? var.gateway_display_name : local.gateway_name
  
  labels = local.labels
  
  lifecycle {
    create_before_destroy = true
  }
  
  depends_on = [
    google_api_gateway_api_config.api_config
  ]
}

# IAM policy for API Gateway API
resource "google_api_gateway_api_iam_binding" "api_iam" {
  for_each = var.api_iam_bindings
  
  provider = google-beta
  project  = var.project_id
  api      = google_api_gateway_api.api[0].api_id
  role     = each.value.role
  members  = each.value.members
}

# IAM policy for API Gateway Gateway
resource "google_api_gateway_gateway_iam_binding" "gateway_iam" {
  for_each = var.gateway_iam_bindings
  
  provider = google-beta
  project  = var.project_id
  gateway  = google_api_gateway_gateway.gateway[0].gateway_id
  region   = var.region
  role     = each.value.role
  members  = each.value.members
}

# Cloud Endpoints Service (if using Cloud Endpoints)
resource "google_endpoints_service" "api_service" {
  count = var.create_endpoints_service ? 1 : 0
  
  project      = var.project_id
  service_name = var.endpoints_service_name != null ? var.endpoints_service_name : "${local.api_name}.endpoints.${var.project_id}.cloud.goog"
  
  openapi_config = local.processed_spec
  
  grpc_config = var.endpoints_grpc_config
  
  protoc_output_base64 = var.endpoints_protoc_output != null ? filebase64(var.endpoints_protoc_output) : null
}

# Cloud Endpoints Service IAM
resource "google_endpoints_service_iam_binding" "endpoints_iam" {
  for_each = var.create_endpoints_service ? var.endpoints_iam_bindings : {}
  
  service_name = google_endpoints_service.api_service[0].service_name
  role         = each.value.role
  members      = each.value.members
}

# Backend Services for API Gateway (if using backend services)
resource "google_compute_backend_service" "api_backend" {
  for_each = var.backend_services
  
  project = var.project_id
  name    = "${local.api_name}-${each.key}-backend"
  
  protocol    = each.value.protocol
  port_name   = each.value.port_name
  timeout_sec = each.value.timeout_sec
  
  dynamic "backend" {
    for_each = each.value.backends
    content {
      group           = backend.value.group
      balancing_mode  = backend.value.balancing_mode
      capacity_scaler = backend.value.capacity_scaler
      description     = backend.value.description
      
      max_connections             = backend.value.max_connections
      max_connections_per_instance = backend.value.max_connections_per_instance
      max_connections_per_endpoint = backend.value.max_connections_per_endpoint
      max_rate                    = backend.value.max_rate
      max_rate_per_instance       = backend.value.max_rate_per_instance
      max_rate_per_endpoint       = backend.value.max_rate_per_endpoint
      max_utilization            = backend.value.max_utilization
    }
  }
  
  health_checks = each.value.health_checks
  
  dynamic "circuit_breakers" {
    for_each = each.value.circuit_breakers != null ? [each.value.circuit_breakers] : []
    content {
      max_requests_per_connection = circuit_breakers.value.max_requests_per_connection
      max_connections            = circuit_breakers.value.max_connections
      max_pending_requests       = circuit_breakers.value.max_pending_requests
      max_requests              = circuit_breakers.value.max_requests
      max_retries               = circuit_breakers.value.max_retries
    }
  }
  
  connection_draining_timeout_sec = each.value.connection_draining_timeout_sec
  
  dynamic "consistent_hash" {
    for_each = each.value.consistent_hash != null ? [each.value.consistent_hash] : []
    content {
      http_cookie {
        ttl {
          seconds = consistent_hash.value.http_cookie_ttl_seconds
        }
        name = consistent_hash.value.http_cookie_name
        path = consistent_hash.value.http_cookie_path
      }
      
      http_header_name  = consistent_hash.value.http_header_name
      minimum_ring_size = consistent_hash.value.minimum_ring_size
    }
  }
  
  dynamic "cdn_policy" {
    for_each = each.value.enable_cdn ? [each.value.cdn_policy] : []
    content {
      cache_mode                   = cdn_policy.value.cache_mode
      signed_url_cache_max_age_sec = cdn_policy.value.signed_url_cache_max_age_sec
      default_ttl                  = cdn_policy.value.default_ttl
      max_ttl                      = cdn_policy.value.max_ttl
      client_ttl                   = cdn_policy.value.client_ttl
      negative_caching             = cdn_policy.value.negative_caching
      serve_while_stale            = cdn_policy.value.serve_while_stale
      
      dynamic "negative_caching_policy" {
        for_each = cdn_policy.value.negative_caching_policy
        content {
          code = negative_caching_policy.value.code
          ttl  = negative_caching_policy.value.ttl
        }
      }
      
      dynamic "cache_key_policy" {
        for_each = cdn_policy.value.cache_key_policy != null ? [cdn_policy.value.cache_key_policy] : []
        content {
          include_protocol         = cache_key_policy.value.include_protocol
          include_host            = cache_key_policy.value.include_host
          include_query_string    = cache_key_policy.value.include_query_string
          query_string_whitelist  = cache_key_policy.value.query_string_whitelist
          query_string_blacklist  = cache_key_policy.value.query_string_blacklist
          include_http_headers    = cache_key_policy.value.include_http_headers
          include_named_cookies   = cache_key_policy.value.include_named_cookies
        }
      }
    }
  }
  
  custom_request_headers  = each.value.custom_request_headers
  custom_response_headers = each.value.custom_response_headers
  
  description = "Backend service for API Gateway ${local.api_name} - ${each.key}"
  
  enable_cdn = each.value.enable_cdn
  
  dynamic "iap" {
    for_each = each.value.iap_config != null ? [each.value.iap_config] : []
    content {
      oauth2_client_id     = iap.value.oauth2_client_id
      oauth2_client_secret = iap.value.oauth2_client_secret
    }
  }
  
  load_balancing_scheme = each.value.load_balancing_scheme
  locality_lb_policy   = each.value.locality_lb_policy
  
  dynamic "log_config" {
    for_each = each.value.log_config != null ? [each.value.log_config] : []
    content {
      enable      = log_config.value.enable
      sample_rate = log_config.value.sample_rate
    }
  }
  
  dynamic "outlier_detection" {
    for_each = each.value.outlier_detection != null ? [each.value.outlier_detection] : []
    content {
      consecutive_errors                    = outlier_detection.value.consecutive_errors
      consecutive_gateway_failure          = outlier_detection.value.consecutive_gateway_failure
      enforcing_consecutive_errors         = outlier_detection.value.enforcing_consecutive_errors
      enforcing_consecutive_gateway_failure = outlier_detection.value.enforcing_consecutive_gateway_failure
      enforcing_success_rate               = outlier_detection.value.enforcing_success_rate
      interval {
        seconds = outlier_detection.value.interval_seconds
      }
      base_ejection_time {
        seconds = outlier_detection.value.base_ejection_time_seconds
      }
      max_ejection_percent       = outlier_detection.value.max_ejection_percent
      split_external_local_origin_errors = outlier_detection.value.split_external_local_origin_errors
      success_rate_minimum_hosts  = outlier_detection.value.success_rate_minimum_hosts
      success_rate_request_volume = outlier_detection.value.success_rate_request_volume
      success_rate_stdev_factor   = outlier_detection.value.success_rate_stdev_factor
    }
  }
  
  security_policy = each.value.security_policy
  session_affinity = each.value.session_affinity
  affinity_cookie_ttl_sec = each.value.affinity_cookie_ttl_sec
}

# Monitoring Alert Policies for API Gateway
resource "google_monitoring_alert_policy" "api_gateway_alerts" {
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

# Monitoring Dashboard for API Gateway
resource "google_monitoring_dashboard" "api_gateway_dashboard" {
  count = var.create_monitoring_dashboard ? 1 : 0
  
  project = var.project_id
  
  dashboard_json = jsonencode({
    displayName = "${local.api_name} API Gateway Dashboard"
    
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Request Rate"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"apigateway.googleapis.com/gateway/request_count\" resource.type=\"api_gateway\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.gateway_id"]
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
          width  = 6
          height = 4
          xPos   = 6
          widget = {
            title = "Error Rate"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"apigateway.googleapis.com/gateway/request_count\" resource.type=\"api_gateway\" metric.label.\"response_code_class\"=\"5xx\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.gateway_id"]
                    }
                  }
                }
                plotType = "LINE"
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
          width  = 6
          height = 4
          yPos   = 4
          widget = {
            title = "Request Latency (P95)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"apigateway.googleapis.com/gateway/request_latencies\" resource.type=\"api_gateway\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_DELTA"
                      crossSeriesReducer = "REDUCE_PERCENTILE_95"
                      groupByFields      = ["resource.gateway_id"]
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
          width  = 6
          height = 4
          xPos   = 6
          yPos   = 4
          widget = {
            title = "Response Code Distribution"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"apigateway.googleapis.com/gateway/request_count\" resource.type=\"api_gateway\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.response_code_class"]
                    }
                  }
                }
                plotType = "STACKED_BAR"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Requests/sec"
                scale = "LINEAR"
              }
            }
          }
        }
      ]
    }
  })
}