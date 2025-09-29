# Cloud Spanner Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for Cloud Spanner resources"
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
  default     = "spanner"
}

# Instance Configuration
variable "use_existing_instance" {
  description = "Whether to use an existing Spanner instance"
  type        = bool
  default     = false
}

variable "existing_instance_name" {
  description = "Name of existing Spanner instance to use"
  type        = string
  default     = null
}

variable "instance_config" {
  description = "Spanner instance configuration"
  type = object({
    name             = optional(string)
    config           = optional(string) # e.g., "regional-us-central1", "multi-region-us"
    display_name     = optional(string)
    num_nodes        = optional(number)
    processing_units = optional(number)
    labels           = optional(map(string))
    force_destroy    = optional(bool)
    edition          = optional(string) # "STANDARD", "ENTERPRISE", "ENTERPRISE_PLUS"
  })
  default = {}
}

# Database Configuration
variable "databases" {
  description = "Map of Spanner databases to create"
  type = map(object({
    name                     = optional(string)
    version_retention_period = optional(string)
    ddl                      = optional(list(string))
    deletion_protection      = optional(bool)
    enable_drop_protection   = optional(bool)
    database_dialect         = optional(string) # "GOOGLE_STANDARD_SQL", "POSTGRESQL"
    encryption_config = optional(object({
      kms_key_name = optional(string)
    }))
  }))
  default = {}
}

# Backup Configuration
variable "backup_configs" {
  description = "Map of backup configurations"
  type = map(object({
    database_id      = string
    backup_id        = optional(string)
    expire_time      = optional(string)
    retention_period = optional(string)
    version_time     = optional(string)
    encryption_config = optional(object({
      encryption_type = optional(string) # "USE_DATABASE_ENCRYPTION", "CUSTOMER_MANAGED_ENCRYPTION"
      kms_key_name    = optional(string)
    }))
  }))
  default = {}
}

# Backup Schedule Configuration
variable "backup_schedules" {
  description = "Map of backup schedule configurations"
  type = map(object({
    database_id        = string
    retention_duration = string
    backup_type        = string # "full", "incremental"
    cron_spec = optional(object({
      text      = string
      time_zone = string
    }))
    encryption_config = optional(object({
      encryption_type = string
      kms_key_name    = optional(string)
    }))
  }))
  default = {}
}

# Service Account Configuration
variable "create_service_account" {
  description = "Whether to create a service account for Spanner operations"
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
    "roles/spanner.databaseAdmin",
    "roles/spanner.databaseUser",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter"
  ]
}

# IAM Configuration
variable "instance_iam_policies" {
  description = "IAM policies for the Spanner instance"
  type = map(object({
    role    = string
    members = list(string)
    condition = optional(object({
      title       = string
      description = string
      expression  = string
    }))
  }))
  default = {}
}

variable "database_iam_policies" {
  description = "IAM policies for Spanner databases"
  type = map(object({
    database = string
    role     = string
    members  = list(string)
    condition = optional(object({
      title       = string
      description = string
      expression  = string
    }))
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

# Cloud Functions for Operations
variable "create_operation_functions" {
  description = "Whether to create Cloud Functions for Spanner operations"
  type        = bool
  default     = false
}

variable "operation_functions" {
  description = "Cloud Function operation configurations"
  type = map(object({
    runtime               = string
    entry_point           = string
    source_bucket         = string
    source_object         = string
    trigger_type          = string # "http", "pubsub", "storage"
    event_type            = optional(string)
    trigger_resource      = optional(string)
    memory_mb             = optional(number)
    timeout_seconds       = optional(number)
    environment_variables = optional(map(string))
    labels                = optional(map(string))
  }))
  default = {}
}

# BigQuery Export Configuration
variable "enable_bigquery_export" {
  description = "Whether to enable BigQuery export for Spanner"
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

# Dataflow Export Configuration
variable "enable_dataflow_export" {
  description = "Whether to enable Dataflow export from Spanner to BigQuery"
  type        = bool
  default     = false
}

variable "dataflow_template_path" {
  description = "GCS path to Dataflow template"
  type        = string
  default     = null
}

variable "dataflow_temp_location" {
  description = "GCS temp location for Dataflow"
  type        = string
  default     = null
}

variable "dataflow_source_database" {
  description = "Source Spanner database for Dataflow export"
  type        = string
  default     = null
}

variable "dataflow_output_table" {
  description = "Output BigQuery table for Dataflow export"
  type        = string
  default     = null
}

variable "dataflow_parameters" {
  description = "Additional parameters for Dataflow job"
  type        = map(string)
  default     = {}
}

# Change Streams Configuration
variable "enable_change_streams" {
  description = "Whether to enable Spanner change streams"
  type        = bool
  default     = false
}

variable "change_stream_topics" {
  description = "Pub/Sub topics for change streams"
  type = map(object({
    message_retention_duration = optional(number)
    schema_name                = optional(string)
    schema_encoding            = optional(string)
  }))
  default = {}
}

# Maintenance Jobs Configuration
variable "enable_maintenance_jobs" {
  description = "Whether to enable maintenance Cloud Scheduler jobs"
  type        = bool
  default     = false
}

variable "maintenance_jobs" {
  description = "Maintenance job configurations"
  type = map(object({
    description           = string
    schedule              = string
    time_zone             = string
    target_url            = string
    payload               = map(any)
    service_account_email = optional(string)
  }))
  default = {}
}

# Performance Configuration
variable "performance_config" {
  description = "Performance configuration for Spanner"
  type = object({
    query_optimizer_version            = optional(string)
    query_optimizer_statistics_package = optional(string)
    max_commit_delay                   = optional(string)
    enable_batch_write_optimization    = optional(bool)
  })
  default = {}
}

# Security Configuration
variable "security_config" {
  description = "Security configuration for Spanner"
  type = object({
    enable_audit_logs       = optional(bool)
    enable_data_access_logs = optional(bool)
    enable_vpc_sc           = optional(bool)
    allowed_ip_ranges       = optional(list(string))
    require_ssl             = optional(bool)
    enable_cmek             = optional(bool)
    kms_key_ring            = optional(string)
    kms_crypto_key          = optional(string)
  })
  default = {
    enable_audit_logs = true
    require_ssl       = true
  }
}

# Scaling Configuration
variable "scaling_config" {
  description = "Scaling configuration for Spanner"
  type = object({
    enable_autoscaling         = optional(bool)
    min_processing_units       = optional(number)
    max_processing_units       = optional(number)
    target_cpu_utilization     = optional(number)
    target_storage_utilization = optional(number)
    scale_down_cooldown        = optional(string)
    scale_up_cooldown          = optional(string)
  })
  default = {
    enable_autoscaling = false
  }
}

# Multi-region Configuration
variable "multi_region_config" {
  description = "Multi-region configuration for Spanner"
  type = object({
    enable_multi_region = optional(bool)
    read_replicas = optional(list(object({
      region      = string
      config      = string
      description = optional(string)
    })))
    placement_policy = optional(object({
      include_replicas = list(string)
      exclude_replicas = list(string)
    }))
  })
  default = {
    enable_multi_region = false
  }
}

# Disaster Recovery Configuration
variable "disaster_recovery_config" {
  description = "Disaster recovery configuration"
  type = object({
    enable_point_in_time_recovery = optional(bool)
    backup_retention_days         = optional(number)
    cross_region_backup_enabled   = optional(bool)
    recovery_time_objective       = optional(number)
    recovery_point_objective      = optional(number)
    automated_backup_policy = optional(object({
      retention_period = string
      backup_schedule  = string
    }))
  })
  default = {
    enable_point_in_time_recovery = true
    backup_retention_days         = 7
  }
}

# Connection Pooling Configuration
variable "connection_config" {
  description = "Connection configuration for Spanner clients"
  type = object({
    max_sessions             = optional(number)
    min_sessions             = optional(number)
    max_idle_sessions        = optional(number)
    write_sessions_fraction  = optional(number)
    keep_alive_interval      = optional(string)
    action_on_exhausted_pool = optional(string)
  })
  default = {}
}

# Query Configuration
variable "query_config" {
  description = "Query configuration for Spanner"
  type = object({
    query_timeout          = optional(string)
    max_staleness          = optional(string)
    enable_query_hints     = optional(bool)
    enable_commit_stats    = optional(bool)
    enable_execution_stats = optional(bool)
    priority               = optional(string) # "PRIORITY_LOW", "PRIORITY_MEDIUM", "PRIORITY_HIGH"
  })
  default = {}
}

# Cost Optimization Configuration
variable "cost_optimization_config" {
  description = "Cost optimization configuration"
  type = object({
    enable_low_cost_instances   = optional(bool)
    enable_regional_instances   = optional(bool)
    optimize_for_cost           = optional(bool)
    enable_storage_optimization = optional(bool)
    compression_algorithm       = optional(string)
  })
  default = {
    optimize_for_cost = false
  }
}

# Compliance Configuration
variable "compliance_config" {
  description = "Compliance configuration for Spanner"
  type = object({
    data_residency_regions     = optional(list(string))
    enable_field_encryption    = optional(bool)
    pii_detection_enabled      = optional(bool)
    audit_log_retention_days   = optional(number)
    enable_data_classification = optional(bool)
  })
  default = {}
}

# Advanced Features Configuration
variable "advanced_features_config" {
  description = "Advanced features configuration"
  type = object({
    enable_foreign_key_cascades  = optional(bool)
    enable_interleaved_tables    = optional(bool)
    enable_json_data_type        = optional(bool)
    enable_generated_columns     = optional(bool)
    enable_check_constraints     = optional(bool)
    enable_column_default_values = optional(bool)
  })
  default = {}
}

# Migration Configuration
variable "migration_config" {
  description = "Migration configuration for database imports"
  type = object({
    enable_database_migration = optional(bool)
    source_database_type      = optional(string) # "mysql", "postgresql", "oracle"
    migration_tool            = optional(string) # "dms", "striim", "custom"
    parallel_import_workers   = optional(number)
    batch_size                = optional(number)
  })
  default = {
    enable_database_migration = false
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
    prevent_destroy = true
  }
}