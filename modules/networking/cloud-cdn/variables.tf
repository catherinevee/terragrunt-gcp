# Cloud CDN Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for Cloud CDN resources"
  type        = string
}

variable "zone" {
  description = "The zone for instance groups"
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
  default     = "cdn"
}

# Network Configuration
variable "network_self_link" {
  description = "Self link of the VPC network"
  type        = string
  default     = null
}

# Backend Services Configuration
variable "backend_services" {
  description = "Map of backend service configurations"
  type = map(object({
    name                            = optional(string)
    description                     = optional(string)
    protocol                        = optional(string) # "HTTP", "HTTPS", "HTTP2", "GRPC"
    port_name                       = optional(string)
    timeout_sec                     = optional(number)
    enable_cdn                      = optional(bool)
    connection_draining_timeout_sec = optional(number)
    load_balancing_scheme           = optional(string)
    locality_lb_policy              = optional(string)
    session_affinity                = optional(string)
    affinity_cookie_ttl_sec         = optional(number)

    # CDN policy configuration
    cdn_policy = optional(object({
      cache_mode                   = optional(string) # "CACHE_ALL_STATIC", "USE_ORIGIN_HEADERS", "FORCE_CACHE_ALL"
      default_ttl                  = optional(number)
      client_ttl                   = optional(number)
      max_ttl                      = optional(number)
      negative_caching             = optional(bool)
      serve_while_stale            = optional(number)
      signed_url_cache_max_age_sec = optional(number)

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

      bypass_cache_on_request_headers = optional(list(object({
        header_name = string
      })))
    }))

    # Backend configuration
    backends = optional(list(object({
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
    })))

    # Health checks
    health_checks = optional(list(string))

    # Circuit breaker configuration
    circuit_breakers = optional(object({
      max_requests_per_connection = optional(number)
      max_connections             = optional(number)
      max_pending_requests        = optional(number)
      max_requests                = optional(number)
      max_retries                 = optional(number)
    }))

    # Consistent hash configuration
    consistent_hash = optional(object({
      http_cookie_ttl_seconds = optional(number)
      http_cookie_name        = optional(string)
      http_cookie_path        = optional(string)
      http_header_name        = optional(string)
      minimum_ring_size       = optional(number)
    }))

    # IAP configuration
    iap_config = optional(object({
      oauth2_client_id     = string
      oauth2_client_secret = string
    }))

    # Security policy
    security_policy = optional(string)

    # Custom headers
    custom_request_headers  = optional(list(string))
    custom_response_headers = optional(list(string))

    # Outlier detection
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

    # Log configuration
    log_config = optional(object({
      enable      = bool
      sample_rate = number
    }))
  }))
  default = {}
}

# Origins Configuration
variable "origins" {
  description = "Map of origin configurations"
  type = map(object({
    address  = string
    port     = optional(number)
    protocol = optional(string)

    # Health check configuration
    health_check = optional(object({
      type                = optional(string) # "HTTP", "HTTPS", "TCP"
      port                = optional(number)
      request_path        = optional(string)
      response            = optional(string)
      proxy_header        = optional(string)
      port_specification  = optional(string)
      request             = optional(string)
      check_interval_sec  = optional(number)
      timeout_sec         = optional(number)
      healthy_threshold   = optional(number)
      unhealthy_threshold = optional(number)
    }))

    # Backend service configuration
    backend_config = optional(object({
      max_rate_per_instance        = optional(number)
      max_rate                     = optional(number)
      max_connections              = optional(number)
      max_connections_per_instance = optional(number)
      max_utilization              = optional(number)
      capacity_scaler              = optional(number)
      balancing_mode               = optional(string)
    }))
  }))
  default = {}
}

# URL Maps Configuration
variable "url_maps" {
  description = "Map of URL map configurations"
  type = map(object({
    name            = optional(string)
    description     = optional(string)
    default_service = optional(string)

    # Host rules
    host_rules = optional(list(object({
      hosts        = list(string)
      path_matcher = string
      description  = optional(string)
    })))

    # Path matchers
    path_matchers = optional(list(object({
      name            = string
      default_service = optional(string)
      description     = optional(string)

      path_rules = optional(list(object({
        paths   = list(string)
        service = optional(string)

        route_action = optional(object({
          url_rewrite = optional(object({
            host_rewrite        = optional(string)
            path_prefix_rewrite = optional(string)
          }))
        }))
      })))

      default_url_redirect = optional(object({
        redirect_response_code = optional(string)
        strip_query            = optional(bool)
        host_redirect          = optional(string)
        path_redirect          = optional(string)
        prefix_redirect        = optional(string)
        https_redirect         = optional(bool)
      }))
    })))

    # Default URL redirect
    default_url_redirect = optional(object({
      redirect_response_code = optional(string)
      strip_query            = optional(bool)
      host_redirect          = optional(string)
      path_redirect          = optional(string)
      prefix_redirect        = optional(string)
      https_redirect         = optional(bool)
    }))

    # Tests
    tests = optional(list(object({
      service     = string
      host        = string
      path        = string
      description = optional(string)
    })))
  }))
  default = {}
}

# SSL Certificates Configuration
variable "ssl_certificates" {
  description = "Map of SSL certificate configurations"
  type = map(object({
    name        = optional(string)
    description = optional(string)

    # Managed certificate configuration
    managed = optional(object({
      domains = list(string)
    }))

    # Self-managed certificate configuration
    self_managed = optional(object({
      certificate = string
      private_key = string
    }))
  }))
  default = {}
}

# Target HTTPS Proxies Configuration
variable "target_https_proxies" {
  description = "Map of target HTTPS proxy configurations"
  type = map(object({
    name                        = optional(string)
    description                 = optional(string)
    url_map                     = optional(string)
    ssl_certificates            = optional(list(string))
    ssl_policy                  = optional(string)
    quic_override               = optional(string) # "NONE", "ENABLE", "DISABLE"
    http_keep_alive_timeout_sec = optional(number)
  }))
  default = {}
}

# Global Forwarding Rules Configuration
variable "global_forwarding_rules" {
  description = "Map of global forwarding rule configurations"
  type = map(object({
    name                  = optional(string)
    description           = optional(string)
    port_range            = optional(string)
    ip_protocol           = optional(string)
    ip_address            = optional(string)
    target                = optional(string)
    load_balancing_scheme = optional(string)
    network_tier          = optional(string)
    labels                = optional(map(string))
  }))
  default = {}
}

# Security Policies Configuration
variable "security_policies" {
  description = "Map of Cloud Armor security policy configurations"
  type = map(object({
    name        = optional(string)
    description = optional(string)
    type        = optional(string)

    # Default rule
    default_rule = optional(object({
      action      = string
      priority    = number
      description = optional(string)
      match = object({
        versioned_expr = string
        config = object({
          src_ip_ranges = list(string)
        })
      })
    }))

    # Additional rules
    rules = optional(list(object({
      action      = string
      priority    = number
      description = optional(string)

      match = optional(object({
        versioned_expr = optional(string)
        expr = optional(object({
          expression = string
        }))
      }))

      rate_limit_options = optional(object({
        conform_action = string
        exceed_action  = string

        rate_limit_threshold = optional(object({
          count        = number
          interval_sec = number
        }))
      }))
    })))

    # Adaptive protection
    adaptive_protection_config = optional(object({
      layer_7_ddos_defense_config = object({
        enable          = bool
        rule_visibility = string
      })
    }))
  }))
  default = {}
}

# Service Account Configuration
variable "create_service_account" {
  description = "Whether to create a service account for CDN operations"
  type        = bool
  default     = false
}

variable "service_account_name" {
  description = "Name of the service account"
  type        = string
  default     = null
}

variable "grant_service_account_roles" {
  description = "Whether to grant roles to the service account"
  type        = bool
  default     = false
}

variable "service_account_roles" {
  description = "Roles to grant to the service account"
  type        = list(string)
  default = [
    "roles/compute.loadBalancerAdmin",
    "roles/compute.securityAdmin",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter"
  ]
}

# Instance Groups Configuration
variable "create_instance_groups" {
  description = "Whether to create instance groups for backends"
  type        = bool
  default     = false
}

# Global IP Configuration
variable "create_global_ips" {
  description = "Whether to create global IP addresses"
  type        = bool
  default     = false
}

# Monitoring Configuration
variable "create_monitoring_alerts" {
  description = "Whether to create monitoring alert policies"
  type        = bool
  default     = false
}

variable "monitoring_alerts" {
  description = "Monitoring alert policies configuration"
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
  description = "Whether to create a monitoring dashboard"
  type        = bool
  default     = false
}

# Advanced CDN Configuration
variable "advanced_cdn_config" {
  description = "Advanced CDN configuration options"
  type = object({
    enable_brotli_compression = optional(bool)
    enable_gzip_compression   = optional(bool)
    compression_whitelist     = optional(list(string))
    enable_origin_failover    = optional(bool)
    origin_failover_criteria  = optional(list(string))
    custom_error_responses = optional(map(object({
      error_code             = number
      response_code          = number
      error_service          = optional(string)
      path                   = optional(string)
      override_response_code = optional(number)
    })))
  })
  default = {}
}

# Security Configuration
variable "security_config" {
  description = "Security configuration for CDN"
  type = object({
    enable_cloud_armor     = optional(bool)
    enable_ddos_protection = optional(bool)
    enable_bot_management  = optional(bool)
    enable_owasp_rules     = optional(bool)
    custom_security_rules = optional(list(object({
      priority    = number
      action      = string
      expression  = string
      description = optional(string)
    })))
    rate_limiting_rules = optional(list(object({
      priority = number
      rate_limit_threshold = object({
        count        = number
        interval_sec = number
      })
      action      = string
      description = optional(string)
    })))
  })
  default = {
    enable_cloud_armor = true
  }
}

# Performance Configuration
variable "performance_config" {
  description = "Performance configuration for CDN"
  type = object({
    enable_http2                = optional(bool)
    enable_http3_quic           = optional(bool)
    connection_draining_timeout = optional(number)
    request_timeout             = optional(number)
    enable_connection_pooling   = optional(bool)
    max_connections_per_origin  = optional(number)
    origin_request_policy = optional(object({
      cache_key_policy = object({
        include_protocol     = bool
        include_host         = bool
        include_query_string = bool
        include_headers      = list(string)
        include_cookies      = list(string)
      })
      origin_request_policy = object({
        header_behavior       = string
        headers               = list(string)
        query_string_behavior = string
        query_strings         = list(string)
        cookie_behavior       = string
        cookies               = list(string)
      })
    }))
  })
  default = {
    enable_http2      = true
    enable_http3_quic = false
  }
}

# Cache Configuration
variable "cache_config" {
  description = "Advanced cache configuration"
  type = object({
    global_cache_behaviors = optional(list(object({
      path_pattern = string
      cache_policy = object({
        cache_mode  = string
        default_ttl = number
        max_ttl     = number
        client_ttl  = number
      })
      compress = optional(bool)
    })))

    cache_invalidation_rules = optional(list(object({
      path_patterns     = list(string)
      invalidation_type = string # "PURGE", "REFRESH"
    })))

    edge_caching_policy = optional(object({
      enable_edge_caching = bool
      edge_cache_ttl      = number
      origin_cache_ttl    = number
    }))
  })
  default = {}
}

# Cost Optimization Configuration
variable "cost_optimization_config" {
  description = "Cost optimization configuration"
  type = object({
    enable_cost_optimization  = optional(bool)
    cache_efficiency_target   = optional(number) # Percentage
    bandwidth_optimization    = optional(bool)
    regional_cache_preference = optional(list(string))
    cost_allocation_tags      = optional(map(string))
  })
  default = {
    enable_cost_optimization = false
  }
}

# Labels and Tags
variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

# Lifecycle Configuration
variable "lifecycle_config" {
  description = "Lifecycle configuration for resources"
  type = object({
    prevent_destroy       = optional(bool)
    ignore_changes        = optional(list(string))
    create_before_destroy = optional(bool)
  })
  default = {
    prevent_destroy = false
  }
}