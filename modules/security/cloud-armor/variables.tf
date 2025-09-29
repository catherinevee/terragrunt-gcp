# Cloud Armor Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for Cloud Armor resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
  default     = "armor"
}

# Security Policies Configuration
variable "security_policies" {
  description = "Map of Cloud Armor security policy configurations"
  type = map(object({
    name        = optional(string)
    description = optional(string)
    type        = optional(string) # "CLOUD_ARMOR", "CLOUD_ARMOR_EDGE"

    # Default rule configuration
    default_rule = optional(object({
      action      = optional(string) # "allow", "deny"
      priority    = optional(number)
      description = optional(string)
      preview     = optional(bool)
      match = optional(object({
        versioned_expr = optional(string)
        config = optional(object({
          src_ip_ranges = optional(list(string))
        }))
      }))
    }))

    # Rate limiting rules
    rate_limit_rules = optional(list(object({
      action      = string # "rate_based_ban", "throttle"
      priority    = number
      description = optional(string)
      preview     = optional(bool)

      match = object({
        versioned_expr = string
        config = object({
          src_ip_ranges = list(string)
        })
      })

      rate_limit_options = object({
        conform_action = string # "allow"
        exceed_action  = string # "deny", "redirect"

        rate_limit_threshold = object({
          count        = number
          interval_sec = number
        })

        enforce_on_key = optional(object({
          enforce_on_key_type = string # "IP", "HTTP_HEADER", "XFF_IP"
          enforce_on_key_name = optional(string)
        }))

        ban_threshold = optional(object({
          count        = number
          interval_sec = number
        }))

        ban_duration_sec = optional(number)

        exceed_redirect_options = optional(object({
          type   = string
          target = string
        }))
      })
    })))

    # Geographic rules
    geo_rules = optional(list(object({
      action      = string # "allow", "deny"
      priority    = number
      description = optional(string)
      preview     = optional(bool)
      expression  = string # CEL expression for geographic filtering

      header_action = optional(object({
        request_headers_to_adds = optional(list(object({
          header_name  = string
          header_value = string
          replace      = optional(bool)
        })))
      }))
    })))

    # IP allowlist/blocklist rules
    ip_rules = optional(list(object({
      action        = string # "allow", "deny"
      priority      = number
      description   = optional(string)
      preview       = optional(bool)
      src_ip_ranges = list(string)
    })))

    # Custom expression rules
    custom_rules = optional(list(object({
      action      = string # "allow", "deny", "redirect"
      priority    = number
      description = optional(string)
      preview     = optional(bool)
      expression  = string # CEL expression

      redirect_options = optional(object({
        type   = string
        target = string
      }))
    })))

    # OWASP ModSecurity CRS rules
    owasp_rules = optional(list(object({
      action      = string # "allow", "deny"
      priority    = number
      description = optional(string)
      preview     = optional(bool)
      expression  = string # CEL expression for OWASP rules

      preconfigured_waf_config = optional(object({
        exclusions = optional(list(object({
          target_rule_set = string
          target_rule_ids = optional(list(string))

          request_headers = optional(list(object({
            operator = string
            value    = string
          })))

          request_cookies = optional(list(object({
            operator = string
            value    = string
          })))

          request_uris = optional(list(object({
            operator = string
            value    = string
          })))

          request_query_params = optional(list(object({
            operator = string
            value    = string
          })))
        })))
      }))
    })))

    # Bot management rules
    bot_management_rules = optional(list(object({
      action      = string # "allow", "deny"
      priority    = number
      description = optional(string)
      preview     = optional(bool)
      expression  = string # CEL expression for bot detection
    })))

    # Adaptive protection configuration
    adaptive_protection_config = optional(object({
      layer_7_ddos_defense_config = optional(object({
        enable          = optional(bool)
        rule_visibility = optional(string) # "STANDARD", "PREMIUM"

        threshold_configs = optional(list(object({
          name                                    = string
          threshold_config_type                   = string
          auto_deploy_load_threshold              = optional(number)
          auto_deploy_confidence_threshold        = optional(number)
          auto_deploy_impacted_baseline_threshold = optional(number)
          auto_deploy_expiration_sec              = optional(number)
        })))
      }))

      auto_deploy_config = optional(object({
        load_threshold              = optional(number)
        confidence_threshold        = optional(number)
        impacted_baseline_threshold = optional(number)
        expiration_sec              = optional(number)
      }))
    }))

    # Advanced options configuration
    advanced_options_config = optional(object({
      json_parsing            = optional(string) # "STANDARD", "DISABLED"
      log_level               = optional(string) # "NORMAL", "VERBOSE"
      user_ip_request_headers = optional(list(string))

      json_custom_config = optional(object({
        content_types = optional(list(string))
      }))
    }))
  }))
  default = {}
}

# Edge Security Policies Configuration
variable "edge_security_policies" {
  description = "Map of Cloud Armor Edge security policy configurations"
  type = map(object({
    name        = optional(string)
    description = optional(string)
    type        = optional(string)

    # Default rule
    default_rule = optional(object({
      action      = optional(string)
      priority    = optional(number)
      description = optional(string)
    }))

    # Edge rules
    rules = optional(list(object({
      action      = string
      priority    = number
      description = optional(string)
      expression  = string
    })))
  }))
  default = {}
}

# WAF Exclusion Policies
variable "waf_exclusion_policies" {
  description = "Map of WAF exclusion policy configurations"
  type = map(object({
    waf_rules = list(object({
      action      = string
      priority    = number
      description = optional(string)
      expression  = string

      exclusions = list(object({
        target_rule_set = string
        target_rule_ids = optional(list(string))

        request_headers = optional(list(object({
          operator = string
          value    = string
        })))

        request_cookies = optional(list(object({
          operator = string
          value    = string
        })))

        request_uris = optional(list(object({
          operator = string
          value    = string
        })))

        request_query_params = optional(list(object({
          operator = string
          value    = string
        })))
      }))
    }))
  }))
  default = {}
}

# Policy Attachments Configuration
variable "policy_attachments" {
  description = "Map of security policy attachments to backend services"
  type = map(object({
    security_policy = string
    backend_service = string
  }))
  default = {}
}

# Service Account Configuration
variable "create_service_account" {
  description = "Whether to create a service account for Cloud Armor operations"
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
    "roles/compute.securityAdmin",
    "roles/compute.loadBalancerAdmin",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
    "roles/cloudfunctions.invoker"
  ]
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

# Log Metrics Configuration
variable "create_log_metrics" {
  description = "Whether to create log-based metrics"
  type        = bool
  default     = false
}

variable "log_metrics" {
  description = "Log-based metrics configuration"
  type = map(object({
    filter           = string
    label_extractors = optional(map(string))

    metric_descriptor = optional(object({
      metric_kind  = string
      value_type   = string
      unit         = optional(string)
      display_name = optional(string)
      labels = optional(list(object({
        key         = string
        value_type  = string
        description = optional(string)
      })))
    }))

    bucket_options = optional(object({
      linear_buckets = optional(object({
        num_finite_buckets = number
        width              = number
        offset             = number
      }))

      exponential_buckets = optional(object({
        num_finite_buckets = number
        growth_factor      = number
        scale              = number
      }))
    }))
  }))
  default = {}
}

# Notification Channels Configuration
variable "notification_channels" {
  description = "Map of notification channel configurations"
  type = map(object({
    display_name = string
    type         = string # "email", "slack", "pagerduty", "webhook"
    labels       = map(string)
    description  = optional(string)
    enabled      = optional(bool)
  }))
  default = {}
}

# Security Response Functions Configuration
variable "create_security_response_functions" {
  description = "Whether to create Cloud Functions for automated security response"
  type        = bool
  default     = false
}

variable "security_response_functions" {
  description = "Security response function configurations"
  type = map(object({
    runtime               = string
    entry_point           = string
    source_bucket         = string
    source_object         = string
    trigger_topic         = string
    memory_mb             = optional(number)
    timeout_seconds       = optional(number)
    environment_variables = optional(map(string))
    labels                = optional(map(string))
  }))
  default = {}
}

# Security Configuration Templates
variable "enable_owasp_rules" {
  description = "Whether to enable OWASP ModSecurity CRS rules"
  type        = bool
  default     = false
}

variable "owasp_rule_sensitivity" {
  description = "Sensitivity level for OWASP rules"
  type        = string
  default     = "STANDARD"
  validation {
    condition     = contains(["LOW", "STANDARD", "HIGH"], var.owasp_rule_sensitivity)
    error_message = "OWASP rule sensitivity must be LOW, STANDARD, or HIGH."
  }
}

variable "enable_ddos_protection" {
  description = "Whether to enable DDoS protection"
  type        = bool
  default     = true
}

variable "enable_bot_management" {
  description = "Whether to enable bot management"
  type        = bool
  default     = false
}

variable "enable_rate_limiting" {
  description = "Whether to enable rate limiting"
  type        = bool
  default     = true
}

variable "default_rate_limit" {
  description = "Default rate limit configuration"
  type = object({
    requests_per_minute = number
    burst_capacity      = number
    ban_duration_sec    = number
  })
  default = {
    requests_per_minute = 1000
    burst_capacity      = 100
    ban_duration_sec    = 300
  }
}

# Geo-blocking Configuration
variable "enable_geo_blocking" {
  description = "Whether to enable geographic blocking"
  type        = bool
  default     = false
}

variable "blocked_countries" {
  description = "List of country codes to block"
  type        = list(string)
  default     = []
}

variable "allowed_countries" {
  description = "List of country codes to allow (empty means allow all)"
  type        = list(string)
  default     = []
}

# IP Management Configuration
variable "ip_allowlists" {
  description = "Map of IP allowlist configurations"
  type = map(object({
    priority    = number
    description = string
    ip_ranges   = list(string)
    action      = optional(string) # "allow"
  }))
  default = {}
}

variable "ip_blocklists" {
  description = "Map of IP blocklist configurations"
  type = map(object({
    priority    = number
    description = string
    ip_ranges   = list(string)
    action      = optional(string) # "deny"
  }))
  default = {}
}

# Advanced Security Features
variable "advanced_security_config" {
  description = "Advanced security configuration"
  type = object({
    enable_adaptive_protection = optional(bool)
    enable_preview_mode        = optional(bool)
    enable_json_parsing        = optional(bool)
    enable_verbose_logging     = optional(bool)
    custom_error_pages         = optional(map(string))
    security_headers = optional(object({
      enable_hsts                 = optional(bool)
      enable_content_type_options = optional(bool)
      enable_frame_options        = optional(bool)
      enable_xss_protection       = optional(bool)
    }))
  })
  default = {
    enable_adaptive_protection = true
    enable_preview_mode        = false
    enable_json_parsing        = true
    enable_verbose_logging     = false
  }
}

# Compliance Configuration
variable "compliance_config" {
  description = "Compliance configuration for security policies"
  type = object({
    pci_dss_compliance     = optional(bool)
    gdpr_compliance        = optional(bool)
    hipaa_compliance       = optional(bool)
    sox_compliance         = optional(bool)
    data_residency_regions = optional(list(string))
    audit_logging_enabled  = optional(bool)
  })
  default = {
    audit_logging_enabled = true
  }
}

# Integration Configuration
variable "integration_config" {
  description = "Integration configuration with other services"
  type = object({
    cloud_logging_enabled    = optional(bool)
    cloud_monitoring_enabled = optional(bool)
    security_command_center  = optional(bool)
    forseti_integration      = optional(bool)
    third_party_siem = optional(object({
      enabled      = bool
      endpoint_url = string
      auth_token   = string
    }))
  })
  default = {
    cloud_logging_enabled    = true
    cloud_monitoring_enabled = true
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