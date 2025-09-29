# API Gateway Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for the API Gateway"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# API Configuration
variable "create_api" {
  description = "Whether to create the API Gateway API"
  type        = bool
  default     = true
}

variable "api_name" {
  description = "Name of the API"
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
  default     = "api-gateway"
}

variable "display_name" {
  description = "Display name for the API"
  type        = string
  default     = null
}

# API Config
variable "deploy_config" {
  description = "Whether to deploy API config"
  type        = bool
  default     = true
}

variable "config_name" {
  description = "Name of the API config"
  type        = string
  default     = null
}

variable "config_display_name" {
  description = "Display name for the API config"
  type        = string
  default     = null
}

# OpenAPI Specification
variable "openapi_spec_path" {
  description = "Path to OpenAPI specification file"
  type        = string
  default     = null
}

variable "openapi_spec_inline" {
  description = "Inline OpenAPI specification"
  type        = string
  default     = null
}

# Gateway Configuration
variable "deploy_gateway" {
  description = "Whether to deploy the gateway"
  type        = bool
  default     = true
}

variable "gateway_name" {
  description = "Name of the gateway"
  type        = string
  default     = null
}

variable "gateway_display_name" {
  description = "Display name for the gateway"
  type        = string
  default     = null
}

variable "gateway_config" {
  description = "Gateway configuration"
  type = object({
    service_account_email = string
  })
  default = null
}

# Service Account
variable "create_service_account" {
  description = "Create service account"
  type        = bool
  default     = false
}

variable "service_account_name" {
  description = "Service account name"
  type        = string
  default     = null
}

variable "grant_service_account_roles" {
  description = "Grant roles to service account"
  type        = bool
  default     = false
}

variable "service_account_roles" {
  description = "Roles to grant"
  type        = list(string)
  default = [
    "roles/servicemanagement.serviceController",
    "roles/logging.logWriter"
  ]
}

# Managed Service Configs
variable "managed_service_configs" {
  description = "Managed service configurations"
  type = list(object({
    path     = string
    contents = string
  }))
  default = []
}

# gRPC Services
variable "grpc_services" {
  description = "gRPC service configurations"
  type = list(object({
    file_descriptor_set_path     = string
    file_descriptor_set_contents = string
    sources = list(object({
      path     = string
      contents = string
    }))
  }))
  default = []
}

variable "grpc_service_configs" {
  description = "gRPC backend service configurations"
  type        = any
  default     = null
}

# Cloud Endpoints
variable "create_endpoints_service" {
  description = "Create Cloud Endpoints service"
  type        = bool
  default     = false
}

variable "endpoints_service_name" {
  description = "Endpoints service name"
  type        = string
  default     = null
}

variable "endpoints_grpc_config" {
  description = "Endpoints gRPC config"
  type        = string
  default     = null
}

variable "endpoints_protoc_output" {
  description = "Path to protoc output"
  type        = string
  default     = null
}

# Backend Services
variable "backend_services" {
  description = "Backend services configuration"
  type = map(object({
    protocol    = string
    port_name   = optional(string)
    timeout_sec = optional(number)

    backends = list(object({
      group                        = string
      balancing_mode               = optional(string)
      capacity_scaler              = optional(number)
      description                  = optional(string)
      max_connections              = optional(number)
      max_connections_per_instance = optional(number)
      max_connections_per_endpoint = optional(number)
      max_rate                     = optional(number)
      max_rate_per_instance        = optional(number)
      max_rate_per_endpoint        = optional(number)
      max_utilization              = optional(number)
    }))

    health_checks                   = list(string)
    connection_draining_timeout_sec = optional(number)

    circuit_breakers = optional(object({
      max_requests_per_connection = optional(number)
      max_connections             = optional(number)
      max_pending_requests        = optional(number)
      max_requests                = optional(number)
      max_retries                 = optional(number)
    }))

    consistent_hash = optional(object({
      http_cookie_ttl_seconds = optional(number)
      http_cookie_name        = optional(string)
      http_cookie_path        = optional(string)
      http_header_name        = optional(string)
      minimum_ring_size       = optional(number)
    }))

    enable_cdn = optional(bool)
    cdn_policy = optional(object({
      cache_mode                   = optional(string)
      signed_url_cache_max_age_sec = optional(number)
      default_ttl                  = optional(number)
      max_ttl                      = optional(number)
      client_ttl                   = optional(number)
      negative_caching             = optional(bool)
      serve_while_stale            = optional(number)
      negative_caching_policy = optional(list(object({
        code = number
        ttl  = number
      })))
      cache_key_policy = optional(object({
        include_protocol       = optional(bool)
        include_host           = optional(bool)
        include_query_string   = optional(bool)
        query_string_whitelist = optional(list(string))
        query_string_blacklist = optional(list(string))
        include_http_headers   = optional(list(string))
        include_named_cookies  = optional(list(string))
      }))
    }))

    custom_request_headers  = optional(list(string))
    custom_response_headers = optional(list(string))

    iap_config = optional(object({
      oauth2_client_id     = string
      oauth2_client_secret = string
    }))

    load_balancing_scheme = optional(string)
    locality_lb_policy    = optional(string)

    log_config = optional(object({
      enable      = bool
      sample_rate = number
    }))

    outlier_detection = optional(object({
      consecutive_errors                    = optional(number)
      consecutive_gateway_failure           = optional(number)
      enforcing_consecutive_errors          = optional(number)
      enforcing_consecutive_gateway_failure = optional(number)
      enforcing_success_rate                = optional(number)
      interval_seconds                      = optional(number)
      base_ejection_time_seconds            = optional(number)
      max_ejection_percent                  = optional(number)
      split_external_local_origin_errors    = optional(bool)
      success_rate_minimum_hosts            = optional(number)
      success_rate_request_volume           = optional(number)
      success_rate_stdev_factor             = optional(number)
    }))

    security_policy         = optional(string)
    session_affinity        = optional(string)
    affinity_cookie_ttl_sec = optional(number)
  }))
  default = {}
}

# IAM
variable "api_iam_bindings" {
  description = "IAM bindings for API"
  type = map(object({
    role    = string
    members = list(string)
  }))
  default = {}
}

variable "gateway_iam_bindings" {
  description = "IAM bindings for gateway"
  type = map(object({
    role    = string
    members = list(string)
  }))
  default = {}
}

variable "endpoints_iam_bindings" {
  description = "IAM bindings for endpoints"
  type = map(object({
    role    = string
    members = list(string)
  }))
  default = {}
}

# Monitoring
variable "create_monitoring_alerts" {
  description = "Create monitoring alerts"
  type        = bool
  default     = false
}

variable "monitoring_alerts" {
  description = "Monitoring alert policies"
  type = map(object({
    display_name           = string
    condition_display_name = string
    filter                 = string
    threshold_value        = number
    combiner               = optional(string)
    enabled                = optional(bool)
    duration               = optional(string)
    comparison             = optional(string)
    alignment_period       = optional(string)
    per_series_aligner     = optional(string)
    cross_series_reducer   = optional(string)
    group_by_fields        = optional(list(string))
    trigger_count          = optional(number)
    trigger_percent        = optional(number)
    notification_channels  = optional(list(string))
    auto_close             = optional(string)
    rate_limit = optional(object({
      period = string
    }))
    documentation_content   = optional(string)
    documentation_mime_type = optional(string)
    documentation_subject   = optional(string)
    labels                  = optional(map(string))
  }))
  default = {}
}

variable "create_monitoring_dashboard" {
  description = "Create monitoring dashboard"
  type        = bool
  default     = false
}

# Lifecycle
variable "ignore_config_changes" {
  description = "Attributes to ignore"
  type        = list(string)
  default     = []
}

# Labels
variable "labels" {
  description = "Labels to apply"
  type        = map(string)
  default     = {}
}