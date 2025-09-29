# Cloud Scheduler Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for Cloud Scheduler jobs"
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
  default     = "scheduler"
}

# Scheduler Jobs Configuration
variable "scheduler_jobs" {
  description = "Map of scheduler job configurations"
  type = map(object({
    target_type     = string  # "http", "pubsub", "app_engine", "cloud_function"
    description     = optional(string)
    schedule        = optional(string)  # Cron format
    time_zone       = optional(string)
    attempt_deadline = optional(string)
    enabled         = optional(bool)

    retry_config = optional(object({
      retry_count          = optional(number)
      max_retry_duration   = optional(string)
      min_backoff_duration = optional(string)
      max_backoff_duration = optional(string)
      max_doublings        = optional(number)
    }))

    # HTTP target configuration
    http_config = optional(object({
      method  = string
      uri     = string
      body    = optional(string)
      headers = optional(map(string))

      oauth_token = optional(object({
        service_account_email = string
        scope                = string
      }))

      oidc_token = optional(object({
        service_account_email = string
        audience             = string
      }))
    }))

    # Pub/Sub target configuration
    pubsub_config = optional(object({
      topic_name = string
      data       = optional(string)
      attributes = optional(map(string))
    }))

    # App Engine target configuration
    app_engine_config = optional(object({
      method       = string
      relative_uri = string
      body         = optional(string)
      headers      = optional(map(string))

      routing = optional(object({
        service  = optional(string)
        version  = optional(string)
        instance = optional(string)
      }))
    }))

    # Cloud Function target configuration
    cloud_function_config = optional(object({
      function_url = string
      data        = optional(string)
      headers     = optional(map(string))

      oidc_token = optional(object({
        service_account_email = string
        audience             = string
      }))
    }))
  }))
  default = {}
}

# Service Account Configuration
variable "create_service_account" {
  description = "Whether to create a service account for scheduler jobs"
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
    "roles/cloudscheduler.jobRunner",
    "roles/pubsub.publisher",
    "roles/cloudfunctions.invoker",
    "roles/appengine.appViewer"
  ]
}

# Pub/Sub Configuration
variable "create_pubsub_topics" {
  description = "Whether to create Pub/Sub topics for scheduler jobs"
  type        = bool
  default     = false
}

variable "pubsub_topic_names" {
  description = "List of Pub/Sub topic names to create"
  type        = list(string)
  default     = []
}

variable "pubsub_message_retention_duration" {
  description = "Message retention duration for Pub/Sub topics (in seconds)"
  type        = number
  default     = null
}

variable "pubsub_schema_name" {
  description = "Schema name for Pub/Sub topics"
  type        = string
  default     = null
}

variable "pubsub_schema_encoding" {
  description = "Schema encoding for Pub/Sub topics"
  type        = string
  default     = "JSON"
  validation {
    condition     = contains(["JSON", "BINARY"], var.pubsub_schema_encoding)
    error_message = "Schema encoding must be either JSON or BINARY."
  }
}

# IAM Configuration
variable "job_iam_bindings" {
  description = "IAM bindings for scheduler jobs"
  type = map(object({
    job_name = string
    role     = string
    member   = string
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
    filter                = string
    threshold_value       = number
    combiner              = optional(string)
    enabled               = optional(bool)
    duration              = optional(string)
    comparison            = optional(string)
    alignment_period      = optional(string)
    per_series_aligner    = optional(string)
    cross_series_reducer  = optional(string)
    group_by_fields       = optional(list(string))
    trigger_count         = optional(number)
    trigger_percent       = optional(number)
    notification_channels = optional(list(string))
    auto_close           = optional(string)
    rate_limit = optional(object({
      period = string
    }))
    documentation_content   = optional(string)
    documentation_mime_type = optional(string)
    documentation_subject   = optional(string)
    labels                 = optional(map(string))
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
    filter = string
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

# Labels and Tags
variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

# Job Templates for Common Use Cases
variable "create_backup_jobs" {
  description = "Whether to create common backup scheduler jobs"
  type        = bool
  default     = false
}

variable "backup_jobs_config" {
  description = "Configuration for backup jobs"
  type = object({
    database_backup = optional(object({
      schedule    = optional(string)
      topic_name  = string
      description = optional(string)
    }))

    storage_backup = optional(object({
      schedule    = optional(string)
      topic_name  = string
      description = optional(string)
    }))

    log_export = optional(object({
      schedule    = optional(string)
      topic_name  = string
      description = optional(string)
    }))
  })
  default = {}
}

variable "create_maintenance_jobs" {
  description = "Whether to create common maintenance scheduler jobs"
  type        = bool
  default     = false
}

variable "maintenance_jobs_config" {
  description = "Configuration for maintenance jobs"
  type = object({
    cleanup_old_logs = optional(object({
      schedule        = optional(string)
      function_url    = string
      description     = optional(string)
      service_account = optional(string)
    }))

    health_check = optional(object({
      schedule        = optional(string)
      http_endpoint   = string
      description     = optional(string)
      expected_status = optional(number)
    }))

    cache_warmup = optional(object({
      schedule      = optional(string)
      http_endpoint = string
      description   = optional(string)
    }))
  })
  default = {}
}

variable "create_report_jobs" {
  description = "Whether to create common reporting scheduler jobs"
  type        = bool
  default     = false
}

variable "report_jobs_config" {
  description = "Configuration for reporting jobs"
  type = object({
    daily_report = optional(object({
      schedule    = optional(string)
      topic_name  = string
      description = optional(string)
    }))

    weekly_summary = optional(object({
      schedule    = optional(string)
      topic_name  = string
      description = optional(string)
    }))

    monthly_metrics = optional(object({
      schedule    = optional(string)
      topic_name  = string
      description = optional(string)
    }))
  })
  default = {}
}

# Advanced Configuration
variable "max_concurrent_jobs" {
  description = "Maximum number of concurrent jobs (used for naming)"
  type        = number
  default     = 100
}

variable "default_time_zone" {
  description = "Default time zone for all jobs"
  type        = string
  default     = "UTC"
}

variable "default_attempt_deadline" {
  description = "Default attempt deadline for all jobs"
  type        = string
  default     = "180s"
}

variable "enable_job_monitoring" {
  description = "Whether to enable comprehensive job monitoring"
  type        = bool
  default     = true
}

variable "job_timeout_threshold" {
  description = "Job timeout threshold for alerts (in seconds)"
  type        = number
  default     = 300
}

variable "job_failure_threshold" {
  description = "Job failure threshold for alerts"
  type        = number
  default     = 3
}