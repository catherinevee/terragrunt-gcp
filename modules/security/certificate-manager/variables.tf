# Certificate Manager Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for regional resources"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
  default     = "cert-manager"
}

# Certificate Configurations
variable "certificates" {
  description = "Map of Certificate Manager certificate configurations"
  type = map(object({
    name        = optional(string)
    description = optional(string)
    scope       = optional(string) # "DEFAULT", "EDGE_CACHE", "ALL_REGIONS"
    location    = optional(string) # "global" or specific region

    # Managed certificate configuration
    managed = optional(object({
      domains                = list(string)
      dns_authorization_keys = optional(list(string)) # References to dns_authorizations keys
      issuance_config_key    = optional(string)       # Reference to certificate_issuance_configs key
    }))

    # Self-managed certificate configuration
    self_managed = optional(object({
      pem_certificate = string
      pem_private_key = string
    }))

    labels = optional(map(string))
  }))
  default = {}
}

# Certificate Map Configurations
variable "certificate_maps" {
  description = "Map of certificate map configurations"
  type = map(object({
    name        = optional(string)
    description = optional(string)
    labels      = optional(map(string))
  }))
  default = {}
}

# Certificate Map Entry Configurations
variable "certificate_map_entries" {
  description = "Map of certificate map entry configurations"
  type = map(object({
    name                = optional(string)
    description         = optional(string)
    certificate_map_key = optional(string)       # Reference to certificate_maps key
    certificate_map     = optional(string)       # Direct certificate map name
    certificate_keys    = optional(list(string)) # References to certificates keys
    certificates        = optional(list(string)) # Direct certificate IDs
    hostname            = optional(string)
    matcher             = optional(string) # "PRIMARY"
    labels              = optional(map(string))
  }))
  default = {}
}

# DNS Authorization Configurations
variable "dns_authorizations" {
  description = "Map of DNS authorization configurations"
  type = map(object({
    name        = optional(string)
    description = optional(string)
    domain      = string
    location    = optional(string)
    labels      = optional(map(string))
  }))
  default = {}
}

# Certificate Issuance Configurations
variable "certificate_issuance_configs" {
  description = "Map of certificate issuance config configurations"
  type = map(object({
    name                       = optional(string)
    description                = optional(string)
    location                   = optional(string)
    rotation_window_percentage = optional(number) # 1-100
    key_algorithm              = optional(string) # "RSA_2048", "ECDSA_P256"
    lifetime                   = optional(string) # Duration string like "2592000s"
    ca_pool                    = string           # CA pool resource name
    labels                     = optional(map(string))
  }))
  default = {}
}

# Trust Config Configurations
variable "trust_configs" {
  description = "Map of trust config configurations"
  type = map(object({
    name        = optional(string)
    description = optional(string)
    location    = optional(string)

    trust_stores = optional(list(object({
      trust_anchors = optional(list(object({
        pem_certificate = string
      })))

      intermediate_cas = optional(list(object({
        pem_certificate = string
      })))
    })))

    labels = optional(map(string))
  }))
  default = {}
}

# Classic SSL Certificates (for backward compatibility)
variable "classic_ssl_certificates" {
  description = "Map of classic SSL certificate configurations"
  type = map(object({
    name        = optional(string)
    description = optional(string)
    private_key = string
    certificate = string
    name_prefix = optional(string)
  }))
  default = {}
}

# Classic Managed SSL Certificates
variable "classic_managed_ssl_certificates" {
  description = "Map of classic managed SSL certificate configurations"
  type = map(object({
    name        = optional(string)
    description = optional(string)
    domains     = list(string)
  }))
  default = {}
}

# SSL Policies
variable "ssl_policies" {
  description = "Map of SSL policy configurations"
  type = map(object({
    name            = optional(string)
    description     = optional(string)
    profile         = optional(string)       # "COMPATIBLE", "MODERN", "RESTRICTED", "CUSTOM"
    min_tls_version = optional(string)       # "TLS_1_0", "TLS_1_1", "TLS_1_2"
    custom_features = optional(list(string)) # Custom cipher suites for CUSTOM profile
  }))
  default = {}
}

# Target HTTPS Proxies
variable "target_https_proxies" {
  description = "Map of target HTTPS proxy configurations with certificate maps"
  type = map(object({
    name                        = optional(string)
    description                 = optional(string)
    url_map                     = string
    certificate_map_key         = optional(string)       # Reference to certificate_maps key
    certificate_map             = optional(string)       # Direct certificate map reference
    ssl_certificate_keys        = optional(list(string)) # References to classic_ssl_certificates keys
    ssl_certificates            = optional(list(string)) # Direct SSL certificate references
    ssl_policy_key              = optional(string)       # Reference to ssl_policies key
    ssl_policy                  = optional(string)       # Direct SSL policy reference
    quic_override               = optional(string)       # "NONE", "ENABLE", "DISABLE"
    http_keep_alive_timeout_sec = optional(number)
  }))
  default = {}
}

# Service Account Configuration
variable "create_service_account" {
  description = "Whether to create a service account for Certificate Manager operations"
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
    "roles/certificatemanager.editor",
    "roles/compute.loadBalancerAdmin",
    "roles/dns.admin",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter"
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

# Notification Channels
variable "notification_channels" {
  description = "Map of notification channel configurations"
  type = map(object({
    display_name = string
    type         = string # "email", "slack", "pagerduty", "webhook", "sms"
    labels       = map(string)
    description  = optional(string)
    enabled      = optional(bool)
    user_labels  = optional(map(string))

    sensitive_labels = optional(object({
      auth_token  = optional(string)
      password    = optional(string)
      service_key = optional(string)
    }))
  }))
  default = {}
}

# Auto-rotation Configuration
variable "enable_auto_rotation" {
  description = "Whether to enable automatic certificate rotation"
  type        = bool
  default     = false
}

variable "rotation_function_source_bucket" {
  description = "GCS bucket containing the rotation function source code"
  type        = string
  default     = null
}

variable "rotation_function_source_object" {
  description = "GCS object path for the rotation function source code"
  type        = string
  default     = null
}

variable "rotation_days_before_expiry" {
  description = "Number of days before expiry to trigger rotation"
  type        = string
  default     = "30"
}

variable "rotation_schedule" {
  description = "Cron schedule for certificate rotation checks"
  type        = string
  default     = "0 2 * * *" # Daily at 2 AM
}

variable "rotation_time_zone" {
  description = "Time zone for rotation schedule"
  type        = string
  default     = "UTC"
}

variable "rotation_log_level" {
  description = "Log level for rotation function"
  type        = string
  default     = "INFO"
}

# Certificate Validation Configuration
variable "validation_config" {
  description = "Certificate validation configuration"
  type = object({
    enable_ocsp_validation     = optional(bool)
    enable_crl_validation      = optional(bool)
    strict_validation          = optional(bool)
    validation_timeout_seconds = optional(number)
    allowed_san_patterns       = optional(list(string))
    forbidden_san_patterns     = optional(list(string))
    minimum_key_size           = optional(number)
    maximum_validity_days      = optional(number)
  })
  default = {
    enable_ocsp_validation = true
    strict_validation      = true
    minimum_key_size       = 2048
    maximum_validity_days  = 397 # Current browser requirement
  }
}

# Compliance Configuration
variable "compliance_config" {
  description = "Compliance configuration for certificates"
  type = object({
    enforce_cap_baseline     = optional(bool)
    enforce_mozilla_policy   = optional(bool)
    enforce_chrome_ct_policy = optional(bool)
    require_sct              = optional(bool) # Signed Certificate Timestamps
    require_caa_check        = optional(bool)
    audit_logging_enabled    = optional(bool)
    compliance_report_bucket = optional(string)
  })
  default = {
    enforce_cap_baseline  = true
    require_sct           = true
    require_caa_check     = true
    audit_logging_enabled = true
  }
}

# Security Configuration
variable "security_config" {
  description = "Security configuration for certificate management"
  type = object({
    enable_hsm_protection           = optional(bool)
    hsm_protection_level            = optional(string) # "SOFTWARE", "EXTERNAL", "EXTERNAL_VPC"
    enable_private_ca               = optional(bool)
    private_ca_pool                 = optional(string)
    enable_certificate_transparency = optional(bool)
    ct_log_urls                     = optional(list(string))
    enable_key_rotation             = optional(bool)
    key_rotation_period_days        = optional(number)
    enable_backup_certificates      = optional(bool)
    backup_storage_bucket           = optional(string)
  })
  default = {
    enable_certificate_transparency = true
    enable_key_rotation             = true
    key_rotation_period_days        = 90
    enable_backup_certificates      = true
  }
}

# Rate Limiting Configuration
variable "rate_limiting_config" {
  description = "Rate limiting configuration for certificate operations"
  type = object({
    enable_rate_limiting               = optional(bool)
    max_certificates_per_hour          = optional(number)
    max_renewals_per_day               = optional(number)
    max_dns_validations_per_hour       = optional(number)
    rate_limit_bypass_service_accounts = optional(list(string))
  })
  default = {
    enable_rate_limiting         = true
    max_certificates_per_hour    = 100
    max_renewals_per_day         = 500
    max_dns_validations_per_hour = 200
  }
}

# Cost Optimization Configuration
variable "cost_optimization_config" {
  description = "Cost optimization configuration"
  type = object({
    enable_unused_cert_cleanup    = optional(bool)
    cleanup_age_days              = optional(number)
    enable_wildcard_consolidation = optional(bool)
    prefer_managed_certificates   = optional(bool)
    enable_certificate_sharing    = optional(bool)
    cost_allocation_tags          = optional(map(string))
  })
  default = {
    enable_unused_cert_cleanup  = true
    cleanup_age_days            = 90
    prefer_managed_certificates = true
    enable_certificate_sharing  = true
  }
}

# Labels
variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}