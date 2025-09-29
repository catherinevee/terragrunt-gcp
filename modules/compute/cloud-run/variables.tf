# Cloud Run Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for Cloud Run"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# Service Configuration
variable "service_name" {
  description = "Name of the Cloud Run service"
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Name prefix for the Cloud Run service"
  type        = string
  default     = "cloud-run"
}

variable "description" {
  description = "Description of the service"
  type        = string
  default     = null
}

variable "deploy_service" {
  description = "Whether to deploy the service"
  type        = bool
  default     = true
}

variable "ingress" {
  description = "Ingress settings"
  type        = string
  default     = "all"

  validation {
    condition     = contains(["all", "internal", "internal-and-cloud-load-balancing"], var.ingress)
    error_message = "Ingress must be all, internal, or internal-and-cloud-load-balancing"
  }
}

variable "launch_stage" {
  description = "Launch stage"
  type        = string
  default     = "GA"

  validation {
    condition     = contains(["ALPHA", "BETA", "GA", "DEPRECATED", "EARLY_ACCESS", "PRELAUNCH"], var.launch_stage)
    error_message = "Invalid launch stage"
  }
}

variable "binary_authorization" {
  description = "Enable binary authorization"
  type        = bool
  default     = false
}

variable "binary_authorization_breakglass" {
  description = "Binary authorization breakglass justification"
  type        = string
  default     = null
}

# Container Configuration
variable "container_image" {
  description = "Container image to deploy"
  type        = string
}

variable "container_name" {
  description = "Container name"
  type        = string
  default     = null
}

variable "container_command" {
  description = "Container command"
  type        = list(string)
  default     = null
}

variable "container_args" {
  description = "Container arguments"
  type        = list(string)
  default     = null
}

variable "container_working_dir" {
  description = "Container working directory"
  type        = string
  default     = null
}

variable "container_port" {
  description = "Container port"
  type = object({
    name = optional(string)
    port = number
  })
  default = {
    name = "http1"
    port = 8080
  }
}

# Resource Configuration
variable "cpu_limit" {
  description = "CPU limit"
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = "Memory limit"
  type        = string
  default     = "512Mi"
}

variable "cpu_idle" {
  description = "CPU idle configuration"
  type        = bool
  default     = true
}

variable "startup_cpu_boost" {
  description = "Enable startup CPU boost"
  type        = bool
  default     = false
}

variable "timeout" {
  description = "Request timeout in seconds"
  type        = number
  default     = 300
}

# Scaling Configuration
variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 100
}

variable "max_concurrency" {
  description = "Maximum requests per instance"
  type        = number
  default     = 80
}

variable "execution_environment" {
  description = "Execution environment"
  type        = string
  default     = "EXECUTION_ENVIRONMENT_GEN2"
}

variable "session_affinity" {
  description = "Enable session affinity"
  type        = bool
  default     = false
}

# Network Configuration
variable "vpc_connector" {
  description = "VPC connector name"
  type        = string
  default     = null
}

variable "vpc_egress" {
  description = "VPC egress settings"
  type        = string
  default     = "PRIVATE_RANGES_ONLY"

  validation {
    condition     = contains(["PRIVATE_RANGES_ONLY", "ALL_TRAFFIC"], var.vpc_egress)
    error_message = "VPC egress must be PRIVATE_RANGES_ONLY or ALL_TRAFFIC"
  }
}

variable "vpc_network" {
  description = "VPC network"
  type        = string
  default     = null
}

variable "vpc_subnetwork" {
  description = "VPC subnetwork"
  type        = string
  default     = null
}

variable "vpc_network_tags" {
  description = "VPC network tags"
  type        = list(string)
  default     = []
}

# Service Account Configuration
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
  description = "Service account name"
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
  description = "Roles to grant"
  type        = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/cloudtrace.agent"
  ]
}

# Security Configuration
variable "encryption_key" {
  description = "Encryption key"
  type        = string
  default     = null
}

variable "allow_public_access" {
  description = "Allow public access"
  type        = bool
  default     = false
}

variable "invoker_members" {
  description = "Members who can invoke the service"
  type        = list(string)
  default     = []
}

# Environment Variables
variable "environment_variables" {
  description = "Environment variables"
  type        = map(string)
  default     = {}
}

variable "secret_environment_variables" {
  description = "Secret environment variables"
  type = map(object({
    secret  = string
    version = string
  }))
  default = {}
}

# Volumes
variable "volumes" {
  description = "Volume configurations"
  type = list(object({
    name       = string
    mount_path = string
    secret = optional(object({
      secret_name = string
      items = optional(list(object({
        path    = string
        version = string
        mode    = optional(number)
      })))
    }))
    cloud_sql_instance = optional(object({
      instances = list(string)
    }))
    gcs = optional(object({
      bucket    = string
      read_only = optional(bool)
    }))
    nfs = optional(object({
      server    = string
      path      = string
      read_only = optional(bool)
    }))
    empty_dir = optional(object({
      medium     = optional(string)
      size_limit = optional(string)
    }))
  }))
  default = []
}

# Health Checks
variable "startup_probe" {
  description = "Startup probe configuration"
  type = object({
    initial_delay_seconds = optional(number)
    timeout_seconds       = optional(number)
    period_seconds        = optional(number)
    failure_threshold     = optional(number)
    http_get = optional(object({
      path = optional(string)
      port = optional(number)
      http_headers = optional(list(object({
        name  = string
        value = string
      })))
    }))
    tcp_socket = optional(object({
      port = number
    }))
    grpc = optional(object({
      port    = optional(number)
      service = optional(string)
    }))
  })
  default = null
}

variable "liveness_probe" {
  description = "Liveness probe configuration"
  type = object({
    initial_delay_seconds = optional(number)
    timeout_seconds       = optional(number)
    period_seconds        = optional(number)
    failure_threshold     = optional(number)
    http_get = optional(object({
      path = optional(string)
      port = optional(number)
      http_headers = optional(list(object({
        name  = string
        value = string
      })))
    }))
    tcp_socket = optional(object({
      port = number
    }))
    grpc = optional(object({
      port    = optional(number)
      service = optional(string)
    }))
  })
  default = null
}

# Traffic Configuration
variable "traffic_percent" {
  description = "Traffic percentage to latest revision"
  type        = number
  default     = 100
}

variable "traffic_revision" {
  description = "Specific revision for traffic"
  type        = string
  default     = null
}

variable "traffic_tag" {
  description = "Traffic tag"
  type        = string
  default     = null
}

# Domain Mapping
variable "domain_name" {
  description = "Custom domain name"
  type        = string
  default     = null
}

variable "certificate_mode" {
  description = "Certificate mode"
  type        = string
  default     = "AUTOMATIC"

  validation {
    condition     = contains(["AUTOMATIC", "NONE"], var.certificate_mode)
    error_message = "Certificate mode must be AUTOMATIC or NONE"
  }
}

variable "force_domain_override" {
  description = "Force domain override"
  type        = bool
  default     = false
}

# Cloud Run Job Configuration
variable "deploy_job" {
  description = "Deploy a Cloud Run Job"
  type        = bool
  default     = false
}

variable "job_name" {
  description = "Job name"
  type        = string
  default     = null
}

variable "job_parallelism" {
  description = "Job parallelism"
  type        = number
  default     = 1
}

variable "job_task_count" {
  description = "Job task count"
  type        = number
  default     = 1
}

variable "job_task_timeout" {
  description = "Job task timeout in seconds"
  type        = number
  default     = 600
}

variable "job_max_retries" {
  description = "Job max retries"
  type        = number
  default     = 3
}

variable "job_container_command" {
  description = "Job container command"
  type        = list(string)
  default     = null
}

variable "job_container_args" {
  description = "Job container arguments"
  type        = list(string)
  default     = null
}

variable "job_cpu_limit" {
  description = "Job CPU limit"
  type        = string
  default     = "1"
}

variable "job_memory_limit" {
  description = "Job memory limit"
  type        = string
  default     = "512Mi"
}

# Job Scheduler Configuration
variable "create_job_scheduler" {
  description = "Create scheduler for job"
  type        = bool
  default     = false
}

variable "job_scheduler_name" {
  description = "Scheduler name"
  type        = string
  default     = null
}

variable "job_scheduler_schedule" {
  description = "Scheduler cron schedule"
  type        = string
  default     = "0 */1 * * *"
}

variable "job_scheduler_description" {
  description = "Scheduler description"
  type        = string
  default     = null
}

variable "job_scheduler_time_zone" {
  description = "Scheduler time zone"
  type        = string
  default     = "UTC"
}

variable "job_scheduler_attempt_deadline" {
  description = "Scheduler attempt deadline"
  type        = string
  default     = "320s"
}

variable "job_scheduler_retry_count" {
  description = "Scheduler retry count"
  type        = number
  default     = 1
}

variable "job_scheduler_max_retry_duration" {
  description = "Scheduler max retry duration"
  type        = string
  default     = "3600s"
}

variable "job_scheduler_min_backoff_duration" {
  description = "Scheduler min backoff"
  type        = string
  default     = "5s"
}

variable "job_scheduler_max_backoff_duration" {
  description = "Scheduler max backoff"
  type        = string
  default     = "3600s"
}

variable "job_scheduler_max_doublings" {
  description = "Scheduler max doublings"
  type        = number
  default     = 5
}

# Monitoring Configuration
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

# Lifecycle Configuration
variable "ignore_service_changes" {
  description = "Attributes to ignore for service"
  type        = list(string)
  default     = []
}

variable "ignore_job_changes" {
  description = "Attributes to ignore for job"
  type        = list(string)
  default     = []
}

variable "ignore_domain_changes" {
  description = "Attributes to ignore for domain"
  type        = list(string)
  default     = []
}

variable "create_before_destroy" {
  description = "Create before destroy"
  type        = bool
  default     = false
}

# Labels and Annotations
variable "labels" {
  description = "Labels to apply"
  type        = map(string)
  default     = {}
}

variable "annotations" {
  description = "Annotations to apply"
  type        = map(string)
  default     = {}
}