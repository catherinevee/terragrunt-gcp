# Cloud Endpoints Module - Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "enable_apis" {
  description = "Whether to enable required GCP APIs"
  type        = bool
  default     = true
}

variable "create_service_account" {
  description = "Whether to create a service account for Endpoints"
  type        = bool
  default     = true
}

variable "service_account_id" {
  description = "The service account ID for Endpoints"
  type        = string
  default     = "cloud-endpoints-sa"
}

variable "service_account_roles" {
  description = "Roles to assign to the Endpoints service account"
  type        = list(string)
  default = [
    "roles/endpoints.serviceAgent",
    "roles/servicemanagement.serviceController",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter"
  ]
}

variable "managed_services" {
  description = "Configuration for managed API services"
  type = map(object({
    api_version          = optional(string)
    display_name         = optional(string)
    management_features  = optional(list(string))
    quota_limits        = optional(map(number))
    authentication      = optional(any)
    backend_rules       = optional(list(any))
    documentation       = optional(any)
  }))
  default = {}
}

variable "openapi_services" {
  description = "OpenAPI-based services configuration"
  type = map(object({
    openapi_spec_path    = string
    backend_url          = string
    api_version          = optional(string)
    template_variables   = optional(map(string))
  }))
  default = {}
}

variable "grpc_services" {
  description = "gRPC-based services configuration"
  type = map(object({
    backend_address        = string
    backend_port          = number
    proto_descriptor_path = optional(string)
    enable_transcoding    = optional(bool, false)
  }))
  default = {}
}

variable "api_keys" {
  description = "API keys configuration for authentication"
  type = map(object({
    display_name        = string
    service            = string
    allowed_methods    = optional(list(string))
    browser_restrictions = optional(object({
      allowed_referrers = list(string)
    }))
    server_restrictions = optional(object({
      allowed_ips = list(string)
    }))
    android_restrictions = optional(object({
      package_name     = string
      sha1_fingerprint = string
    }))
    ios_restrictions = optional(object({
      allowed_bundle_ids = list(string)
    }))
  }))
  default = {}
}

variable "enable_api_gateway" {
  description = "Whether to enable API Gateway"
  type        = bool
  default     = false
}

variable "api_gateway_configs" {
  description = "API Gateway configurations"
  type = map(object({
    region                   = string
    display_name            = optional(string)
    openapi_spec            = optional(string)
    openapi_spec_inline     = optional(string)
    backend_service_account = string
    labels                  = optional(map(string))
  }))
  default = {}
}

variable "authentication_config" {
  description = "Authentication configuration for services"
  type = object({
    providers = optional(list(object({
      id                    = string
      issuer               = string
      jwks_uri             = optional(string)
      audiences            = optional(list(string))
      authorization_url    = optional(string)
      jwt_locations        = optional(list(any))
    })))
    rules = optional(list(object({
      selector              = string
      requirements         = optional(list(any))
      allow_without_credential = optional(bool)
    })))
  })
  default = null
}

variable "enable_quota" {
  description = "Whether to enable quota management"
  type        = bool
  default     = true
}

variable "quota_configs" {
  description = "Quota configuration for API methods"
  type = map(object({
    selector           = string
    allow_unregistered = optional(bool, false)
    skip_control      = optional(bool, false)
  }))
  default = {}
}

variable "quota_overrides" {
  description = "Quota override configurations"
  type = map(object({
    service = string
    metric  = string
    limit   = string
    value   = number
    force   = optional(bool, false)
  }))
  default = {}
}

variable "backend_deadline" {
  description = "Default deadline for backend requests in seconds"
  type        = number
  default     = 30
}

variable "enable_monitoring" {
  description = "Whether to enable monitoring for APIs"
  type        = bool
  default     = true
}

variable "create_dashboard" {
  description = "Whether to create a monitoring dashboard"
  type        = bool
  default     = true
}

variable "dashboard_display_name" {
  description = "Display name for the monitoring dashboard"
  type        = string
  default     = "Cloud Endpoints API Dashboard"
}

variable "enable_logging" {
  description = "Whether to enable logging for APIs"
  type        = bool
  default     = true
}

variable "notification_channels" {
  description = "List of notification channel IDs for alerts"
  type        = list(string)
  default     = []
}

variable "alert_policies" {
  description = "Alert policies configuration"
  type = map(object({
    display_name           = string
    combiner              = optional(string, "OR")
    enabled               = optional(bool, true)
    documentation         = optional(string)
    condition_display_name = string
    filter                = string
    duration              = string
    comparison            = string
    threshold_value       = number
    alignment_period      = optional(string, "60s")
    per_series_aligner    = optional(string, "ALIGN_RATE")
    cross_series_reducer  = optional(string, "REDUCE_SUM")
    group_by_fields       = optional(list(string), [])
    trigger_count         = optional(number)
    trigger_percent       = optional(number)
    notification_channels = optional(list(string), [])
    labels               = optional(map(string), {})
    auto_close_duration   = optional(string, "86400s")
    rate_limit           = optional(string)
  }))
  default = {}
}

variable "enable_controlled_rollout" {
  description = "Whether to enable controlled rollout for service updates"
  type        = bool
  default     = false
}

variable "enable_vpc_service_controls" {
  description = "Whether to enable VPC Service Controls"
  type        = bool
  default     = false
}

variable "vpc_service_perimeter_name" {
  description = "Name of the VPC Service Control perimeter"
  type        = string
  default     = ""
}

variable "vpc_access_levels" {
  description = "VPC Service Control access levels"
  type        = list(string)
  default     = []
}

variable "service_iam_bindings" {
  description = "IAM bindings for specific services"
  type = map(object({
    role    = string
    members = list(string)
  }))
  default = {}
}

variable "consumer_iam_bindings" {
  description = "IAM bindings for service consumers"
  type = map(object({
    role    = string
    members = list(string)
  }))
  default = {}
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

# Advanced configuration variables

variable "enable_private_service_connect" {
  description = "Whether to enable Private Service Connect for private API access"
  type        = bool
  default     = false
}

variable "private_service_connect_config" {
  description = "Private Service Connect configuration"
  type = object({
    network               = string
    subnet               = string
    ip_address           = optional(string)
    service_attachment_names = optional(list(string))
  })
  default = null
}

variable "enable_cloud_trace" {
  description = "Whether to enable Cloud Trace for distributed tracing"
  type        = bool
  default     = true
}

variable "trace_sampling_rate" {
  description = "Sampling rate for Cloud Trace (0.0 to 1.0)"
  type        = number
  default     = 0.1
}

variable "enable_cloud_profiler" {
  description = "Whether to enable Cloud Profiler for performance profiling"
  type        = bool
  default     = false
}

variable "rate_limit_configs" {
  description = "Rate limiting configurations per API method"
  type = map(object({
    requests_per_minute = number
    requests_per_user   = optional(number)
    burst_size         = optional(number)
    enforce_on_key     = optional(string, "IP")
  }))
  default = {}
}

variable "cors_configs" {
  description = "CORS configurations for APIs"
  type = map(object({
    allow_origins      = list(string)
    allow_methods      = list(string)
    allow_headers      = list(string)
    expose_headers     = optional(list(string))
    allow_credentials  = optional(bool, false)
    max_age           = optional(number, 3600)
  }))
  default = {}
}

variable "backend_service_configs" {
  description = "Advanced backend service configurations"
  type = map(object({
    protocol                = optional(string, "HTTP2")
    load_balancing_scheme   = optional(string, "ROUND_ROBIN")
    session_affinity        = optional(string, "NONE")
    timeout_sec            = optional(number, 30)
    connection_draining_timeout_sec = optional(number, 300)
    circuit_breaker = optional(object({
      max_requests_per_connection = optional(number)
      max_connections            = optional(number)
      max_pending_requests       = optional(number)
      max_requests              = optional(number)
      max_retries               = optional(number)
    }))
    health_check = optional(object({
      check_interval_sec   = optional(number, 30)
      timeout_sec         = optional(number, 10)
      healthy_threshold   = optional(number, 2)
      unhealthy_threshold = optional(number, 2)
      request_path        = optional(string, "/health")
      port               = optional(number)
    }))
  }))
  default = {}
}

variable "service_level_objectives" {
  description = "Service Level Objectives (SLOs) for APIs"
  type = map(object({
    display_name        = string
    goal               = number
    rolling_period_days = optional(number, 30)
    service_level_indicator = object({
      request_based = optional(object({
        distribution_cut = optional(object({
          range = object({
            min = optional(number)
            max = number
          })
        }))
        good_total_ratio = optional(object({
          good_service_filter = optional(string)
          bad_service_filter  = optional(string)
          total_service_filter = optional(string)
        }))
      }))
      windows_based = optional(object({
        window_period = string
        good_bad_metric_filter = optional(string)
        good_total_ratio_threshold = optional(object({
          threshold = number
          performance = object({
            distribution_cut = optional(object({
              range = object({
                min = optional(number)
                max = number
              })
            }))
            good_total_ratio = optional(object({
              good_service_filter = optional(string)
              bad_service_filter  = optional(string)
              total_service_filter = optional(string)
            }))
          })
        }))
      }))
    })
  }))
  default = {}
}

variable "custom_domain_mappings" {
  description = "Custom domain mappings for APIs"
  type = map(object({
    domain_name     = string
    certificate_id  = string
    path_mappings   = optional(map(string))
  }))
  default = {}
}

variable "enable_request_validation" {
  description = "Whether to enable request validation"
  type        = bool
  default     = true
}

variable "request_validation_rules" {
  description = "Request validation rules for APIs"
  type = map(object({
    validate_request_parameters = optional(bool, true)
    validate_request_body       = optional(bool, true)
    fail_on_warnings           = optional(bool, false)
  }))
  default = {}
}

variable "enable_response_compression" {
  description = "Whether to enable response compression"
  type        = bool
  default     = true
}

variable "compression_types" {
  description = "Supported compression types"
  type        = list(string)
  default     = ["gzip", "br"]
}

variable "enable_caching" {
  description = "Whether to enable response caching"
  type        = bool
  default     = false
}

variable "cache_configs" {
  description = "Cache configurations per API method"
  type = map(object({
    cache_key_parameters = optional(list(string))
    default_ttl         = optional(number, 3600)
    max_ttl            = optional(number, 86400)
    client_ttl         = optional(number, 3600)
    negative_caching   = optional(bool, false)
    cache_modes        = optional(list(string), ["GET", "HEAD"])
  }))
  default = {}
}

variable "webhook_configs" {
  description = "Webhook configurations for API events"
  type = map(object({
    url                = string
    events            = list(string)
    secret            = optional(string)
    headers           = optional(map(string))
    retry_policy      = optional(object({
      max_attempts     = optional(number, 3)
      initial_interval = optional(string, "1s")
      max_interval     = optional(string, "60s")
      multiplier       = optional(number, 2)
    }))
  }))
  default = {}
}

variable "enable_api_deprecation_warnings" {
  description = "Whether to enable API deprecation warnings"
  type        = bool
  default     = true
}

variable "api_lifecycle_policies" {
  description = "API lifecycle policies"
  type = map(object({
    deprecation_date    = optional(string)
    sunset_date        = optional(string)
    migration_guide_url = optional(string)
    replacement_api    = optional(string)
  }))
  default = {}
}