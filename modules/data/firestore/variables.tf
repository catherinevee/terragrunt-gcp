# Firestore Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for Firestore database"
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
  default     = "firestore"
}

# Database Configuration
variable "database_config" {
  description = "Firestore database configuration"
  type = object({
    name                              = optional(string)
    location_id                       = optional(string)
    type                              = optional(string) # "FIRESTORE_NATIVE", "DATASTORE_MODE"
    concurrency_mode                  = optional(string) # "OPTIMISTIC", "PESSIMISTIC"
    app_engine_integration_mode       = optional(string) # "ENABLED", "DISABLED"
    point_in_time_recovery_enablement = optional(string) # "POINT_IN_TIME_RECOVERY_ENABLED", "POINT_IN_TIME_RECOVERY_DISABLED"
    delete_protection_state           = optional(string) # "DELETE_PROTECTION_ENABLED", "DELETE_PROTECTION_DISABLED"
  })
  default = {}
}

# Security Rules Configuration
variable "deploy_security_rules" {
  description = "Whether to deploy Firestore security rules"
  type        = bool
  default     = true
}

variable "security_rules_content" {
  description = "Content of Firestore security rules"
  type        = string
  default     = null
}

variable "security_rules_file" {
  description = "Path to Firestore security rules file"
  type        = string
  default     = null
}

# Indexes Configuration
variable "indexes" {
  description = "List of Firestore indexes to create"
  type = list(object({
    collection  = string
    query_scope = optional(string) # "COLLECTION", "COLLECTION_GROUP"
    api_scope   = optional(string) # "ANY_API", "DATASTORE_MODE_API"
    fields = list(object({
      field_path   = string
      order        = optional(string) # "ASCENDING", "DESCENDING"
      array_config = optional(string) # "CONTAINS"
    }))
  }))
  default = []
}

# TTL Policies Configuration
variable "ttl_policies" {
  description = "Time-to-live policies for Firestore collections"
  type = list(object({
    collection = string
    field      = string
    state      = optional(string) # "ACTIVE", "DISABLED"
  }))
  default = []
}

# Service Account Configuration
variable "create_service_account" {
  description = "Whether to create a service account for Firestore operations"
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
    "roles/datastore.user",
    "roles/firebase.admin",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter"
  ]
}

# IAM Configuration
variable "database_iam_bindings" {
  description = "IAM bindings for the Firestore database"
  type = map(object({
    role   = string
    member = string
  }))
  default = {}
}

# Backup Configuration
variable "enable_backups" {
  description = "Whether to enable Firestore backup schedules"
  type        = bool
  default     = false
}

variable "backup_schedules" {
  description = "Backup schedules configuration"
  type = map(object({
    retention     = string           # Duration in seconds
    schedule_type = string           # "daily", "weekly"
    day_of_week   = optional(string) # For weekly schedules: "MONDAY", "TUESDAY", etc.
  }))
  default = {}
}

# Initial Data Configuration
variable "create_initial_documents" {
  description = "Whether to create initial documents"
  type        = bool
  default     = false
}

variable "initial_documents" {
  description = "Initial documents to create in Firestore"
  type = map(object({
    collection = string
    fields     = map(any)
  }))
  default = {}
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

# BigQuery Export Configuration
variable "enable_bigquery_export" {
  description = "Whether to enable BigQuery export for Firestore"
  type        = bool
  default     = false
}

variable "bigquery_export_location" {
  description = "Location for BigQuery export dataset"
  type        = string
  default     = "US"
}

variable "bigquery_table_expiration_ms" {
  description = "Default table expiration in milliseconds"
  type        = number
  default     = 3600000 # 1 hour
}

variable "bigquery_partition_expiration_ms" {
  description = "Default partition expiration in milliseconds"
  type        = number
  default     = null
}

variable "bigquery_access_config" {
  description = "Access configuration for BigQuery dataset"
  type = list(object({
    role           = string
    user_by_email  = optional(string)
    group_by_email = optional(string)
    special_group  = optional(string)
  }))
  default = []
}

# Data Processing Configuration
variable "create_data_processors" {
  description = "Whether to create Cloud Functions for data processing"
  type        = bool
  default     = false
}

variable "data_processors" {
  description = "Cloud Function data processors configuration"
  type = map(object({
    runtime               = string
    entry_point           = string
    source_bucket         = string
    source_object         = string
    trigger_path          = string # Firestore document path pattern
    memory_mb             = optional(number)
    timeout_seconds       = optional(number)
    environment_variables = optional(map(string))
    labels                = optional(map(string))
  }))
  default = {}
}

# Security Configuration
variable "security_config" {
  description = "Security configuration for Firestore"
  type = object({
    enable_audit_logs           = optional(bool)
    enable_data_loss_prevention = optional(bool)
    require_authentication      = optional(bool)
    allowed_ip_ranges           = optional(list(string))
    encryption_key              = optional(string)
  })
  default = {}
}

# Performance Configuration
variable "performance_config" {
  description = "Performance configuration for Firestore"
  type = object({
    max_concurrent_operations = optional(number)
    batch_write_size          = optional(number)
    query_timeout_seconds     = optional(number)
    connection_pool_size      = optional(number)
  })
  default = {}
}

# Collections Configuration
variable "collections_config" {
  description = "Configuration for Firestore collections"
  type = map(object({
    description     = optional(string)
    max_documents   = optional(number)
    enable_ttl      = optional(bool)
    ttl_field       = optional(string)
    security_rules  = optional(string)
    indexes_enabled = optional(bool)
  }))
  default = {}
}

# Import/Export Configuration
variable "import_export_config" {
  description = "Configuration for import/export operations"
  type = object({
    enable_scheduled_exports = optional(bool)
    export_bucket            = optional(string)
    export_schedule          = optional(string)
    export_collections       = optional(list(string))
    compression_type         = optional(string)
  })
  default = {}
}

# Multi-region Configuration
variable "multi_region_config" {
  description = "Multi-region configuration for Firestore"
  type = object({
    enable_multi_region = optional(bool)
    regions             = optional(list(string))
    replication_type    = optional(string) # "AUTOMATIC", "USER_MANAGED"
  })
  default = {
    enable_multi_region = false
  }
}

# Client Configuration
variable "client_config" {
  description = "Client configuration for Firestore access"
  type = object({
    max_idle_channels        = optional(number)
    max_send_message_size    = optional(number)
    max_receive_message_size = optional(number)
    keepalive_time           = optional(number)
    keepalive_timeout        = optional(number)
  })
  default = {}
}

# Development Configuration
variable "development_config" {
  description = "Development and testing configuration"
  type = object({
    enable_emulator   = optional(bool)
    emulator_port     = optional(number)
    enable_debug_mode = optional(bool)
    mock_data_enabled = optional(bool)
  })
  default = {
    enable_emulator = false
  }
}

# Compliance Configuration
variable "compliance_config" {
  description = "Compliance configuration for Firestore"
  type = object({
    data_residency_regions   = optional(list(string))
    enable_field_encryption  = optional(bool)
    pii_detection_enabled    = optional(bool)
    audit_log_retention_days = optional(number)
  })
  default = {}
}

# Labels and Tags
variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

# Advanced Features
variable "enable_realtime_updates" {
  description = "Whether to enable real-time updates"
  type        = bool
  default     = true
}

variable "enable_offline_support" {
  description = "Whether to enable offline support"
  type        = bool
  default     = false
}

variable "enable_persistence" {
  description = "Whether to enable local persistence"
  type        = bool
  default     = false
}

variable "cache_size_mb" {
  description = "Local cache size in MB"
  type        = number
  default     = 100
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
    prevent_destroy = true
  }
}