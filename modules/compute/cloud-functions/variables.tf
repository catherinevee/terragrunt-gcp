# Cloud Functions Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for the Cloud Function"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Function Configuration
variable "function_name" {
  description = "Name of the Cloud Function"
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Name prefix for the Cloud Function"
  type        = string
  default     = "cloud-function"
}

variable "description" {
  description = "Description of the Cloud Function"
  type        = string
  default     = null
}

variable "generation" {
  description = "Cloud Functions generation (1 or 2)"
  type        = number
  default     = 2

  validation {
    condition     = contains([1, 2], var.generation)
    error_message = "Generation must be 1 or 2"
  }
}

variable "deploy_function" {
  description = "Whether to deploy the function"
  type        = bool
  default     = true
}

# Runtime Configuration
variable "runtime" {
  description = "Runtime for the function (e.g., nodejs18, python311, go121, java17)"
  type        = string
  default     = "nodejs18"
}

variable "entry_point" {
  description = "Entry point for the function"
  type        = string
  default     = "main"
}

variable "available_memory_mb" {
  description = "Memory in MB for the function"
  type        = number
  default     = 256

  validation {
    condition     = contains([128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768], var.available_memory_mb)
    error_message = "Memory must be one of: 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768"
  }
}

variable "available_cpu" {
  description = "CPU allocation for Gen 2 functions"
  type        = string
  default     = null
}

variable "timeout" {
  description = "Timeout in seconds (max 540 for Gen1, 3600 for Gen2)"
  type        = number
  default     = 60
}

# Instance Configuration
variable "max_instances_v1" {
  description = "Maximum instances for Gen 1 functions"
  type        = number
  default     = 100
}

variable "min_instances_v1" {
  description = "Minimum instances for Gen 1 functions"
  type        = number
  default     = 0
}

variable "max_instances_v2" {
  description = "Maximum instances for Gen 2 functions"
  type        = number
  default     = 100
}

variable "min_instances_v2" {
  description = "Minimum instances for Gen 2 functions"
  type        = number
  default     = 0
}

variable "max_instance_request_concurrency" {
  description = "Maximum concurrent requests per instance (Gen 2 only)"
  type        = number
  default     = 1000
}

# Source Configuration
variable "source_directory" {
  description = "Local directory containing function source code"
  type        = string
  default     = null
}

variable "source_archive_path" {
  description = "Path to source archive file"
  type        = string
  default     = null
}

variable "source_archive_bucket" {
  description = "GCS bucket for source archives"
  type        = string
  default     = null
}

variable "source_archive_object" {
  description = "GCS object path for source archive"
  type        = string
  default     = null
}

variable "create_source_archive" {
  description = "Create source archive from local directory"
  type        = bool
  default     = false
}

variable "source_archive_excludes" {
  description = "Files to exclude from source archive"
  type        = list(string)
  default     = [".git", ".gitignore", "node_modules", "__pycache__", ".env"]
}

variable "create_source_bucket" {
  description = "Create GCS bucket for source archives"
  type        = bool
  default     = false
}

variable "source_bucket_name" {
  description = "Name for source bucket"
  type        = string
  default     = null
}

variable "source_bucket_location" {
  description = "Location for source bucket"
  type        = string
  default     = "US"
}

variable "source_bucket_storage_class" {
  description = "Storage class for source bucket"
  type        = string
  default     = "STANDARD"
}

variable "source_bucket_force_destroy" {
  description = "Force destroy source bucket"
  type        = bool
  default     = false
}

variable "source_bucket_versioning" {
  description = "Enable versioning for source bucket"
  type        = bool
  default     = true
}

variable "source_bucket_lifecycle_days" {
  description = "Days before deleting old source archives"
  type        = number
  default     = 30
}

# Build Configuration
variable "docker_registry" {
  description = "Docker registry for build"
  type        = string
  default     = "CONTAINER_REGISTRY"
}

variable "docker_repository" {
  description = "Docker repository for build"
  type        = string
  default     = null
}

variable "build_environment_variables" {
  description = "Environment variables for build"
  type        = map(string)
  default     = {}
}

variable "build_worker_pool" {
  description = "Cloud Build worker pool"
  type        = string
  default     = null
}

# Trigger Configuration
variable "trigger_http" {
  description = "Create HTTP trigger"
  type        = bool
  default     = true
}

variable "event_trigger_config" {
  description = "Event trigger configuration for Gen 1"
  type = object({
    event_type      = string
    resource        = optional(string)
    service         = optional(string)
    trigger_region  = optional(string)
    retry_policy    = optional(bool)
  })
  default = null
}

variable "event_trigger_v2_config" {
  description = "Event trigger configuration for Gen 2"
  type = object({
    event_type             = string
    pubsub_topic          = optional(string)
    trigger_region        = optional(string)
    service_account_email = optional(string)
    retry_policy          = optional(string)
  })
  default = null
}

variable "event_filters" {
  description = "Event filters for Gen 2 triggers"
  type = list(object({
    attribute = string
    value     = string
    operator  = optional(string)
  }))
  default = []
}

# Network Configuration
variable "vpc_connector" {
  description = "VPC connector name"
  type        = string
  default     = null
}

variable "create_vpc_connector" {
  description = "Create VPC connector"
  type        = bool
  default     = false
}

variable "vpc_connector_name" {
  description = "Name for VPC connector"
  type        = string
  default     = null
}

variable "vpc_connector_network" {
  description = "Network for VPC connector"
  type        = string
  default     = null
}

variable "vpc_connector_ip_range" {
  description = "IP CIDR range for VPC connector"
  type        = string
  default     = null
}

variable "vpc_connector_min_instances" {
  description = "Minimum instances for VPC connector"
  type        = number
  default     = 2
}

variable "vpc_connector_max_instances" {
  description = "Maximum instances for VPC connector"
  type        = number
  default     = 10
}

variable "vpc_connector_min_throughput" {
  description = "Minimum throughput for VPC connector"
  type        = number
  default     = 200
}

variable "vpc_connector_max_throughput" {
  description = "Maximum throughput for VPC connector"
  type        = number
  default     = 1000
}

variable "vpc_connector_egress_settings" {
  description = "VPC egress settings"
  type        = string
  default     = "PRIVATE_RANGES_ONLY"

  validation {
    condition = contains([
      "PRIVATE_RANGES_ONLY",
      "ALL_TRAFFIC"
    ], var.vpc_connector_egress_settings)
    error_message = "VPC egress settings must be PRIVATE_RANGES_ONLY or ALL_TRAFFIC"
  }
}

variable "ingress_settings_v1" {
  description = "Ingress settings for Gen 1"
  type        = string
  default     = "ALLOW_ALL"

  validation {
    condition = contains([
      "ALLOW_ALL",
      "ALLOW_INTERNAL_ONLY",
      "ALLOW_INTERNAL_AND_GCLB"
    ], var.ingress_settings_v1)
    error_message = "Invalid ingress settings for Gen 1"
  }
}

variable "ingress_settings_v2" {
  description = "Ingress settings for Gen 2"
  type        = string
  default     = "ALLOW_ALL"

  validation {
    condition = contains([
      "ALLOW_ALL",
      "ALLOW_INTERNAL_ONLY",
      "ALLOW_INTERNAL_AND_GCLB"
    ], var.ingress_settings_v2)
    error_message = "Invalid ingress settings for Gen 2"
  }
}

variable "all_traffic_on_latest_revision" {
  description = "Route all traffic to latest revision (Gen 2)"
  type        = bool
  default     = true
}

# Security Configuration
variable "service_account_email" {
  description = "Service account email"
  type        = string
  default     = null
}

variable "create_service_account" {
  description = "Create service account"
  type        = bool
  default     = false
}

variable "service_account_name" {
  description = "Name for service account"
  type        = string
  default     = null
}

variable "create_service_account_key" {
  description = "Create service account key"
  type        = bool
  default     = false
}

variable "grant_service_account_roles" {
  description = "Grant roles to service account"
  type        = bool
  default     = false
}

variable "service_account_roles" {
  description = "Roles to grant to service account"
  type        = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/cloudtrace.agent"
  ]
}

variable "kms_key_name" {
  description = "KMS key for encryption"
  type        = string
  default     = null
}

# IAM Configuration
variable "allow_public_access" {
  description = "Allow public access to function"
  type        = bool
  default     = false
}

variable "invoker_members" {
  description = "Members who can invoke the function"
  type        = list(string)
  default     = []
}

# Environment Variables
variable "environment_variables" {
  description = "Environment variables for function"
  type        = map(string)
  default     = {}
}

variable "secret_environment_variables" {
  description = "Secret environment variables"
  type = map(object({
    secret     = string
    version    = string
    project_id = optional(string)
  }))
  default = {}
}

variable "secret_volumes" {
  description = "Secret volumes to mount"
  type = list(object({
    mount_path = string
    secret     = string
    project_id = optional(string)
    versions = optional(list(object({
      path    = string
      version = string
    })))
  }))
  default = []
}

# Scheduler Configuration
variable "create_scheduler_job" {
  description = "Create Cloud Scheduler job"
  type        = bool
  default     = false
}

variable "scheduler_job_name" {
  description = "Name for scheduler job"
  type        = string
  default     = null
}

variable "scheduler_cron_schedule" {
  description = "Cron schedule for scheduler"
  type        = string
  default     = "0 */1 * * *"
}

variable "scheduler_description" {
  description = "Description for scheduler job"
  type        = string
  default     = null
}

variable "scheduler_time_zone" {
  description = "Time zone for scheduler"
  type        = string
  default     = "UTC"
}

variable "scheduler_attempt_deadline" {
  description = "Attempt deadline for scheduler"
  type        = string
  default     = "320s"
}

variable "scheduler_retry_count" {
  description = "Retry count for scheduler"
  type        = number
  default     = 1
}

variable "scheduler_max_retry_duration" {
  description = "Maximum retry duration"
  type        = string
  default     = "3600s"
}

variable "scheduler_min_backoff_duration" {
  description = "Minimum backoff duration"
  type        = string
  default     = "5s"
}

variable "scheduler_max_backoff_duration" {
  description = "Maximum backoff duration"
  type        = string
  default     = "3600s"
}

variable "scheduler_max_doublings" {
  description = "Maximum doublings for backoff"
  type        = number
  default     = 5
}

variable "scheduler_http_method" {
  description = "HTTP method for scheduler"
  type        = string
  default     = "POST"
}

variable "scheduler_http_headers" {
  description = "HTTP headers for scheduler"
  type        = map(string)
  default     = {}
}

variable "scheduler_http_body" {
  description = "HTTP body for scheduler"
  type        = string
  default     = null
}

variable "scheduler_oidc_token" {
  description = "OIDC token configuration"
  type = object({
    service_account_email = string
    audience             = optional(string)
  })
  default = null
}

variable "scheduler_oauth_token" {
  description = "OAuth token configuration"
  type = object({
    service_account_email = string
    scope                = string
  })
  default = null
}

variable "scheduler_pubsub_target" {
  description = "Pub/Sub target for scheduler"
  type = object({
    topic_name = string
    data       = optional(string)
    attributes = optional(map(string))
  })
  default = null
}

# Monitoring Configuration
variable "create_monitoring_alerts" {
  description = "Create monitoring alert policies"
  type        = bool
  default     = false
}

variable "monitoring_alerts" {
  description = "Map of monitoring alert policies"
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
  description = "Create monitoring dashboard"
  type        = bool
  default     = false
}

# Budget Configuration
variable "create_budget_alert" {
  description = "Create budget alert"
  type        = bool
  default     = false
}

variable "billing_account" {
  description = "Billing account ID"
  type        = string
  default     = null
}

variable "budget_amount" {
  description = "Budget amount"
  type = object({
    currency_code = string
    units        = number
    nanos        = optional(number)
  })
  default = null
}

variable "budget_calendar_period" {
  description = "Calendar period for budget"
  type        = string
  default     = "MONTH"
}

variable "budget_custom_period" {
  description = "Custom period for budget"
  type = object({
    start_year  = number
    start_month = number
    start_day   = number
    end_year    = number
    end_month   = number
    end_day     = number
  })
  default = null
}

variable "budget_threshold_rules" {
  description = "Budget threshold rules"
  type = list(object({
    threshold_percent = number
    spend_basis      = optional(string)
  }))
  default = [
    { threshold_percent = 0.5 },
    { threshold_percent = 0.9 },
    { threshold_percent = 1.0 }
  ]
}

variable "budget_pubsub_topic" {
  description = "Pub/Sub topic for budget alerts"
  type        = string
  default     = null
}

variable "budget_notification_channels" {
  description = "Notification channels for budget"
  type        = list(string)
  default     = []
}

variable "budget_disable_default_recipients" {
  description = "Disable default budget recipients"
  type        = bool
  default     = false
}

# Lifecycle Configuration
variable "ignore_function_changes" {
  description = "List of attributes to ignore changes on"
  type        = list(string)
  default     = []
}

variable "create_before_destroy" {
  description = "Create new function before destroying old"
  type        = bool
  default     = false
}

# Labels
variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}