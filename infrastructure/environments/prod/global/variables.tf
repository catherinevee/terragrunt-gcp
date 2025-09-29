# Variables for production environment global configuration

variable "project_id" {
  description = "The GCP project ID for production environment"
  type        = string
}

variable "billing_account" {
  description = "The billing account ID for production"
  type        = string
}

variable "organization" {
  description = "Organization name"
  type        = string
  default     = "acme-corp"
}

variable "default_region" {
  description = "Default region for production resources"
  type        = string
  default     = "us-central1"
}

variable "prod_domain" {
  description = "Primary domain name for production"
  type        = string
  default     = "acme-corp.com"
}

variable "prod_critical_email" {
  description = "Email for critical production alerts"
  type        = string
  default     = "prod-critical@acme-corp.com"
}

variable "prod_warning_email" {
  description = "Email for warning production alerts"
  type        = string
  default     = "prod-warning@acme-corp.com"
}

variable "pagerduty_service_key" {
  description = "PagerDuty service key for critical alerts"
  type        = string
  sensitive   = true
}

variable "pagerduty_auth_token" {
  description = "PagerDuty auth token"
  type        = string
  sensitive   = true
}

variable "slack_webhook_critical" {
  description = "Slack webhook URL for critical alerts"
  type        = string
  sensitive   = true
}

variable "sms_numbers" {
  description = "SMS numbers for critical alerts"
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "enable_vpc_sc" {
  description = "Enable VPC Service Controls"
  type        = bool
  default     = true
}

variable "access_policy_id" {
  description = "Access Context Manager policy ID"
  type        = string
  default     = ""
}

variable "access_level_id" {
  description = "Access level ID for VPC-SC"
  type        = string
  default     = ""
}

variable "project_number" {
  description = "GCP project number"
  type        = string
}

variable "blocked_ip_ranges" {
  description = "IP ranges to block in Cloud Armor"
  type        = list(string)
  default = [
    "192.0.2.0/24",     # TEST-NET-1
    "198.51.100.0/24",  # TEST-NET-2
    "203.0.113.0/24",   # TEST-NET-3
    "10.0.0.0/8",       # Private network - block if not expected
    "172.16.0.0/12",    # Private network - block if not expected
    "169.254.0.0/16"    # Link local
  ]
}

variable "prod_budget_amount" {
  description = "Monthly budget amount for production in USD"
  type        = number
  default     = 50000
}

variable "prod_regions" {
  description = "Production deployment regions with configuration"
  type = map(object({
    enabled = bool
    zones   = list(string)
    priority = number
  }))
  default = {
    "us-central1" = {
      enabled  = true
      zones    = ["us-central1-a", "us-central1-b", "us-central1-c", "us-central1-f"]
      priority = 1
    }
    "us-east1" = {
      enabled  = true
      zones    = ["us-east1-b", "us-east1-c", "us-east1-d"]
      priority = 2
    }
    "europe-west1" = {
      enabled  = true
      zones    = ["europe-west1-b", "europe-west1-c", "europe-west1-d"]
      priority = 3
    }
    "asia-southeast1" = {
      enabled  = true
      zones    = ["asia-southeast1-a", "asia-southeast1-b", "asia-southeast1-c"]
      priority = 4
    }
  }
}

variable "prod_network_config" {
  description = "Network configuration for production"
  type = object({
    vpc_name                = string
    auto_create_subnetworks = bool
    routing_mode           = string
    mtu                    = number
    enable_flow_logs       = bool
    flow_log_sampling      = number
  })
  default = {
    vpc_name                = "prod-vpc"
    auto_create_subnetworks = false
    routing_mode           = "GLOBAL"
    mtu                    = 1500
    enable_flow_logs       = true
    flow_log_sampling      = 1.0  # 100% sampling in production
  }
}

variable "prod_compute_defaults" {
  description = "Default compute settings for production"
  type = object({
    machine_type           = string
    preemptible           = bool
    automatic_restart     = bool
    on_host_maintenance   = string
    provisioning_model    = string
    enable_shielded_vm    = bool
    enable_secure_boot    = bool
    enable_vtpm           = bool
    enable_integrity_monitoring = bool
  })
  default = {
    machine_type               = "n2-standard-4"
    preemptible               = false
    automatic_restart         = true
    on_host_maintenance       = "MIGRATE"
    provisioning_model        = "STANDARD"
    enable_shielded_vm        = true
    enable_secure_boot        = true
    enable_vtpm               = true
    enable_integrity_monitoring = true
  }
}

variable "prod_database_defaults" {
  description = "Default database settings for production"
  type = object({
    tier                    = string
    availability_type       = string
    backup_enabled         = bool
    backup_start_time      = string
    point_in_time_recovery = bool
    transaction_log_retention_days = number
    backup_retention_count  = number
    maintenance_window_day  = number
    maintenance_window_hour = number
    maintenance_window_update_track = string
    database_flags = map(string)
  })
  default = {
    tier                    = "db-n1-highmem-4"
    availability_type       = "REGIONAL"  # High availability
    backup_enabled         = true
    backup_start_time      = "02:00"
    point_in_time_recovery = true
    transaction_log_retention_days = 7
    backup_retention_count  = 30
    maintenance_window_day  = 7  # Sunday
    maintenance_window_hour = 3   # 3 AM
    maintenance_window_update_track = "stable"
    database_flags = {
      slow_query_log = "on"
      log_output     = "FILE"
      general_log    = "on"
    }
  }
}

variable "prod_storage_defaults" {
  description = "Default storage settings for production"
  type = object({
    location      = string
    storage_class = string
    versioning    = bool
    lifecycle_rules = list(object({
      age                   = number
      type                  = string
      with_state            = string
    }))
    encryption = object({
      default_kms_key_name = string
    })
    uniform_bucket_level_access = bool
    public_access_prevention   = string
    retention_policy_days      = number
  })
  default = {
    location      = "US"  # Multi-regional
    storage_class = "MULTI_REGIONAL"
    versioning    = true
    lifecycle_rules = [
      {
        age        = 90
        type       = "Delete"
        with_state = "ARCHIVED"
      },
      {
        age        = 365
        type       = "Delete"
        with_state = "ANY"
      }
    ]
    encryption = {
      default_kms_key_name = null  # Will be set dynamically
    }
    uniform_bucket_level_access = true
    public_access_prevention   = "enforced"
    retention_policy_days      = 30
  }
}

variable "prod_autoscaling_defaults" {
  description = "Default autoscaling settings for production"
  type = object({
    min_replicas            = number
    max_replicas            = number
    cpu_utilization_target  = number
    scale_down_control = object({
      max_scaled_down_replicas = number
      time_window_sec         = number
    })
    scale_up_control = object({
      max_scaled_up_replicas = number
      time_window_sec       = number
    })
  })
  default = {
    min_replicas           = 3  # Minimum 3 for HA
    max_replicas           = 100
    cpu_utilization_target = 0.6
    scale_down_control = {
      max_scaled_down_replicas = 10
      time_window_sec         = 600  # 10 minutes
    }
    scale_up_control = {
      max_scaled_up_replicas = 20
      time_window_sec       = 60  # 1 minute for quick response
    }
  }
}

variable "prod_monitoring_config" {
  description = "Monitoring configuration for production"
  type = object({
    metrics_interval       = string
    log_sampling_ratio    = number
    trace_sampling_ratio  = number
    profiler_enabled      = bool
    debugger_enabled      = bool
    error_reporting_enabled = bool
    uptime_check_interval = string
    alert_auto_close      = string
    notification_rate_limit = string
  })
  default = {
    metrics_interval       = "30s"
    log_sampling_ratio    = 1.0  # 100% in production
    trace_sampling_ratio  = 0.5  # 50% trace sampling
    profiler_enabled      = true
    debugger_enabled      = false  # Disabled in production
    error_reporting_enabled = true
    uptime_check_interval = "60s"
    alert_auto_close      = "86400s"  # 24 hours
    notification_rate_limit = "300s"  # 5 minutes
  }
}

variable "prod_security_config" {
  description = "Security configuration for production"
  type = object({
    enable_private_google_access = bool
    enable_private_service_connect = bool
    enable_binary_authorization = bool
    enable_vulnerability_scanning = bool
    enable_security_command_center = bool
    enable_access_transparency = bool
    enable_data_access_logs = bool
    require_ssl_database = bool
    enable_cmek_encryption = bool
    enable_application_layer_encryption = bool
  })
  default = {
    enable_private_google_access = true
    enable_private_service_connect = true
    enable_binary_authorization = true
    enable_vulnerability_scanning = true
    enable_security_command_center = true
    enable_access_transparency = true
    enable_data_access_logs = true
    require_ssl_database = true
    enable_cmek_encryption = true
    enable_application_layer_encryption = true
  }
}

variable "prod_compliance_config" {
  description = "Compliance configuration for production"
  type = object({
    enable_audit_logs = bool
    log_retention_days = number
    enable_data_residency = bool
    data_residency_regions = list(string)
    enable_hipaa_compliance = bool
    enable_pci_compliance = bool
    enable_sox_compliance = bool
    enable_gdpr_compliance = bool
    enable_iso27001_compliance = bool
  })
  default = {
    enable_audit_logs = true
    log_retention_days = 365  # 1 year minimum
    enable_data_residency = true
    data_residency_regions = ["us-central1", "us-east1"]
    enable_hipaa_compliance = false
    enable_pci_compliance = true
    enable_sox_compliance = true
    enable_gdpr_compliance = true
    enable_iso27001_compliance = true
  }
}

variable "prod_disaster_recovery" {
  description = "Disaster recovery configuration"
  type = object({
    enable_cross_region_backup = bool
    backup_regions = list(string)
    rto_hours = number  # Recovery Time Objective
    rpo_hours = number  # Recovery Point Objective
    enable_automated_failover = bool
    failover_grace_period_seconds = number
  })
  default = {
    enable_cross_region_backup = true
    backup_regions = ["us-east1", "europe-west1"]
    rto_hours = 4
    rpo_hours = 1
    enable_automated_failover = true
    failover_grace_period_seconds = 300
  }
}

variable "labels" {
  description = "Default labels to apply to all production resources"
  type        = map(string)
  default = {
    environment   = "production"
    managed_by    = "terraform"
    cost_center   = "operations"
    business_unit = "platform"
    criticality   = "critical"
    compliance    = "pci-sox-gdpr"
    data_classification = "sensitive"
  }
}

variable "tags" {
  description = "Network tags for production resources"
  type        = list(string)
  default = [
    "production",
    "allow-health-checks",
    "allow-internal",
    "allow-google-apis"
  ]
}