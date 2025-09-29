# Cloud Tasks Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for Cloud Tasks queues"
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
  default     = "tasks"
}

# Task Queues Configuration
variable "task_queues" {
  description = "Map of task queue configurations"
  type = map(object({
    target_type = string # "http", "app_engine", "pull"
    location    = optional(string)
    state       = optional(string) # "RUNNING", "PAUSED", "DISABLED"

    # Rate limiting configuration
    rate_limits = optional(object({
      max_dispatches_per_second = optional(number)
      max_burst_size            = optional(number)
      max_concurrent_dispatches = optional(number)
    }))

    # Retry configuration
    retry_config = optional(object({
      max_attempts       = optional(number)
      max_retry_duration = optional(string)
      max_backoff        = optional(string)
      min_backoff        = optional(string)
      max_doublings      = optional(number)
    }))

    # Logging configuration
    logging_config = optional(object({
      sampling_ratio = optional(number)
    }))

    # HTTP target configuration
    http_target = optional(object({
      app_engine_routing = optional(object({
        service  = optional(string)
        version  = optional(string)
        instance = optional(string)
      }))
    }))

    # App Engine target configuration
    app_engine_target = optional(object({
      routing = optional(object({
        service  = optional(string)
        version  = optional(string)
        instance = optional(string)
      }))
    }))
  }))
  default = {}
}

# Service Account Configuration
variable "create_service_account" {
  description = "Whether to create a service account for task queues"
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
    "roles/cloudtasks.enqueuer",
    "roles/cloudtasks.taskRunner",
    "roles/cloudfunctions.invoker",
    "roles/appengine.appViewer"
  ]
}

# IAM Configuration
variable "queue_iam_bindings" {
  description = "IAM bindings for task queues"
  type = map(object({
    queue_name = string
    role       = string
    member     = string
  }))
  default = {}
}

# Sample Tasks Configuration
variable "create_sample_tasks" {
  description = "Whether to create sample tasks for testing"
  type        = bool
  default     = false
}

variable "sample_tasks" {
  description = "Sample tasks configuration for testing"
  type = map(object({
    queue_name    = string
    schedule_time = optional(string)

    # HTTP request configuration
    http_request = optional(object({
      method  = string
      url     = string
      body    = optional(string)
      headers = optional(map(string))

      oauth_token = optional(object({
        service_account_email = string
        scope                 = string
      }))

      oidc_token = optional(object({
        service_account_email = string
        audience              = string
      }))
    }))

    # App Engine request configuration
    app_engine_request = optional(object({
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

# Task Processors Configuration (Cloud Functions)
variable "create_task_processors" {
  description = "Whether to create Cloud Functions for task processing"
  type        = bool
  default     = false
}

variable "task_processors" {
  description = "Cloud Function task processors configuration"
  type = map(object({
    runtime               = string
    entry_point           = string
    source_bucket         = string
    source_object         = string
    trigger_type          = string # "http", "firestore", "pubsub"
    trigger_resource      = optional(string)
    memory_mb             = optional(number)
    timeout_seconds       = optional(number)
    environment_variables = optional(map(string))
    labels                = optional(map(string))
  }))
  default = {}
}

# Queue Templates for Common Use Cases
variable "create_default_queues" {
  description = "Whether to create common default queues"
  type        = bool
  default     = false
}

variable "default_queues_config" {
  description = "Configuration for default queues"
  type = object({
    high_priority = optional(object({
      max_dispatches_per_second = optional(number)
      max_concurrent_dispatches = optional(number)
      max_retry_duration        = optional(string)
    }))

    normal_priority = optional(object({
      max_dispatches_per_second = optional(number)
      max_concurrent_dispatches = optional(number)
      max_retry_duration        = optional(string)
    }))

    low_priority = optional(object({
      max_dispatches_per_second = optional(number)
      max_concurrent_dispatches = optional(number)
      max_retry_duration        = optional(string)
    }))

    batch_processing = optional(object({
      max_dispatches_per_second = optional(number)
      max_concurrent_dispatches = optional(number)
      max_retry_duration        = optional(string)
    }))
  })
  default = {}
}

# Error Handling Configuration
variable "dead_letter_queue_config" {
  description = "Dead letter queue configuration"
  type = object({
    enabled               = bool
    max_delivery_attempts = optional(number)
    dead_letter_topic     = optional(string)
  })
  default = {
    enabled = false
  }
}

# Advanced Configuration
variable "enable_queue_stats" {
  description = "Whether to enable detailed queue statistics"
  type        = bool
  default     = true
}

variable "max_concurrent_tasks" {
  description = "Maximum number of concurrent tasks per queue"
  type        = number
  default     = 1000
}

variable "default_task_timeout" {
  description = "Default task timeout in seconds"
  type        = number
  default     = 600
}

variable "enable_task_retries" {
  description = "Whether to enable task retries by default"
  type        = bool
  default     = true
}

variable "default_retry_attempts" {
  description = "Default number of retry attempts"
  type        = number
  default     = 3
}

variable "enable_dlq" {
  description = "Whether to enable dead letter queues"
  type        = bool
  default     = false
}

# Performance Configuration
variable "performance_config" {
  description = "Performance configuration for queues"
  type = object({
    high_throughput_mode = optional(bool)
    batch_size           = optional(number)
    prefetch_count       = optional(number)
    ack_deadline         = optional(number)
  })
  default = {}
}

# Security Configuration
variable "security_config" {
  description = "Security configuration for queues"
  type = object({
    encryption_key  = optional(string)
    require_ssl     = optional(bool)
    allowed_origins = optional(list(string))
    ip_restrictions = optional(list(string))
  })
  default = {}
}

# Labels and Tags
variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

# Lifecycle Configuration
variable "ignore_changes" {
  description = "List of attributes to ignore changes for"
  type        = list(string)
  default     = []
}

# Integration Configuration
variable "pubsub_integration" {
  description = "Pub/Sub integration configuration"
  type = object({
    enabled      = bool
    topic_prefix = optional(string)
    subscription_config = optional(object({
      ack_deadline_seconds       = optional(number)
      retain_acked_messages      = optional(bool)
      message_retention_duration = optional(string)
    }))
  })
  default = {
    enabled = false
  }
}

variable "firestore_integration" {
  description = "Firestore integration configuration"
  type = object({
    enabled       = bool
    database_id   = optional(string)
    collection_id = optional(string)
    document_mask = optional(list(string))
  })
  default = {
    enabled = false
  }
}

# Alerting Thresholds
variable "alerting_thresholds" {
  description = "Alerting thresholds for queue metrics"
  type = object({
    queue_depth_threshold   = optional(number)
    task_failure_rate       = optional(number)
    task_latency_threshold  = optional(number)
    dispatch_rate_threshold = optional(number)
  })
  default = {
    queue_depth_threshold   = 1000
    task_failure_rate       = 0.1
    task_latency_threshold  = 30
    dispatch_rate_threshold = 500
  }
}