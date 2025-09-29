# Cloud Composer Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for Cloud Composer environment"
  type        = string
}

variable "zone" {
  description = "The zone for Cloud Composer environment"
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
  default     = "composer"
}

# Environment Configuration
variable "environment_config" {
  description = "Cloud Composer environment configuration"
  type = object({
    name                            = optional(string)
    node_count                      = optional(number)
    machine_type                    = optional(string)
    disk_size_gb                    = optional(number)
    composer_version                = optional(string)
    python_version                  = optional(string)
    airflow_config_overrides        = optional(map(string))
    pypi_packages                   = optional(map(string))
    env_variables                   = optional(map(string))
    enable_private_ip_google_access = optional(bool)
    enable_ip_alias                 = optional(bool)
    enable_private_endpoint         = optional(bool)
    master_ipv4_cidr_block          = optional(string)
    database_machine_type           = optional(string)
    web_server_machine_type         = optional(string)
  })
  default = {}
}

# Software Configuration
variable "software_config" {
  description = "Software configuration for Composer environment"
  type = object({
    image_version  = optional(string)
    python_version = optional(string)
    scheduler = optional(object({
      cpu     = optional(number)
      memory  = optional(number)
      storage = optional(number)
      count   = optional(number)
    }))
    web_server = optional(object({
      cpu     = optional(number)
      memory  = optional(number)
      storage = optional(number)
    }))
    worker = optional(object({
      cpu       = optional(number)
      memory    = optional(number)
      storage   = optional(number)
      min_count = optional(number)
      max_count = optional(number)
    }))
  })
  default = {}
}

# Node Configuration
variable "node_config" {
  description = "Node configuration for Composer environment"
  type = object({
    zone              = optional(string)
    machine_type      = optional(string)
    disk_size_gb      = optional(number)
    disk_type         = optional(string)
    network           = optional(string)
    subnetwork        = optional(string)
    service_account   = optional(string)
    oauth_scopes      = optional(list(string))
    tags              = optional(list(string))
    enable_ip_alias   = optional(bool)
    max_pods_per_node = optional(number)
  })
  default = {}
}

# Network Configuration
variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = null
}

variable "subnetwork_name" {
  description = "Name of the subnetwork"
  type        = string
  default     = null
}

# Private Environment Configuration
variable "enable_private_environment" {
  description = "Whether to enable private environment"
  type        = bool
  default     = false
}

variable "private_cluster_config" {
  description = "Private cluster configuration"
  type = object({
    enable_private_nodes    = optional(bool)
    master_ipv4_cidr_block  = optional(string)
    enable_private_endpoint = optional(bool)
  })
  default = {}
}

variable "cloud_sql_ipv4_cidr_block" {
  description = "IPv4 CIDR block for Cloud SQL"
  type        = string
  default     = null
}

variable "composer_network_ipv4_cidr_block" {
  description = "IPv4 CIDR block for Composer network"
  type        = string
  default     = null
}

variable "enable_privately_used_public_ips" {
  description = "Whether to enable privately used public IPs"
  type        = bool
  default     = false
}

variable "composer_connection_subnetwork" {
  description = "Subnetwork for Composer connection"
  type        = string
  default     = null
}

# Web Server Network Access Control
variable "web_server_network_access_control" {
  description = "Web server network access control configuration"
  type = object({
    allowed_ip_ranges = list(object({
      value       = string
      description = optional(string)
    }))
  })
  default = null
}

# Database Configuration
variable "enable_database_config" {
  description = "Whether to enable database configuration"
  type        = bool
  default     = false
}

variable "database_config" {
  description = "Database configuration"
  type = object({
    machine_type = optional(string)
    zone         = optional(string)
  })
  default = {}
}

# Web Server Configuration
variable "enable_web_server_config" {
  description = "Whether to enable web server configuration"
  type        = bool
  default     = false
}

variable "web_server_config" {
  description = "Web server configuration"
  type = object({
    machine_type = optional(string)
  })
  default = {}
}

# Encryption Configuration
variable "encryption_config" {
  description = "Encryption configuration"
  type = object({
    kms_key_name = optional(string)
  })
  default = null
}

# Environment Size (Composer 2)
variable "environment_size" {
  description = "Environment size for Composer 2"
  type        = string
  default     = null
  validation {
    condition = var.environment_size == null || contains([
      "ENVIRONMENT_SIZE_SMALL",
      "ENVIRONMENT_SIZE_MEDIUM",
      "ENVIRONMENT_SIZE_LARGE"
    ], var.environment_size)
    error_message = "Environment size must be SMALL, MEDIUM, or LARGE."
  }
}

# Workloads Configuration (Composer 2)
variable "enable_workloads_config" {
  description = "Whether to enable workloads configuration"
  type        = bool
  default     = false
}

# Service Account Configuration
variable "create_service_account" {
  description = "Whether to create a service account for Composer"
  type        = bool
  default     = false
}

variable "service_account_name" {
  description = "Name of the service account"
  type        = string
  default     = null
}

variable "node_service_account" {
  description = "Service account for Composer nodes"
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
    "roles/composer.worker",
    "roles/storage.admin",
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
    "roles/pubsub.editor",
    "roles/dataflow.admin",
    "roles/cloudsql.client"
  ]
}

# Storage Configuration
variable "create_composer_bucket" {
  description = "Whether to create a bucket for Composer"
  type        = bool
  default     = false
}

variable "bucket_lifecycle_age_days" {
  description = "Age in days for bucket lifecycle rule"
  type        = number
  default     = 90
}

# Airflow Configuration
variable "airflow_config_overrides" {
  description = "Airflow configuration overrides"
  type        = map(string)
  default     = {}
}

variable "pypi_packages" {
  description = "Python packages to install"
  type        = map(string)
  default     = {}
}

variable "env_variables" {
  description = "Environment variables for Airflow"
  type        = map(string)
  default     = {}
}

# IAM Configuration
variable "environment_iam_bindings" {
  description = "IAM bindings for Composer environment"
  type = map(object({
    role   = string
    member = string
  }))
  default = {}
}

variable "dags_bucket_iam_bindings" {
  description = "IAM bindings for DAGs bucket"
  type = map(object({
    bucket_name = string
    role        = string
    member      = string
  }))
  default = {}
}

# Maintenance Configuration
variable "maintenance_window" {
  description = "Maintenance window configuration"
  type = object({
    start_time = string
    end_time   = string
    recurrence = string
  })
  default = null
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

# Timeout Configuration
variable "create_timeout" {
  description = "Timeout for creating the environment"
  type        = string
  default     = "45m"
}

variable "update_timeout" {
  description = "Timeout for updating the environment"
  type        = string
  default     = "60m"
}

variable "delete_timeout" {
  description = "Timeout for deleting the environment"
  type        = string
  default     = "45m"
}

# Advanced Features
variable "enable_cloud_data_lineage" {
  description = "Whether to enable Cloud Data Lineage integration"
  type        = bool
  default     = false
}

variable "enable_triggers" {
  description = "Whether to enable Airflow triggers"
  type        = bool
  default     = false
}

variable "enable_deferrable_operators" {
  description = "Whether to enable deferrable operators"
  type        = bool
  default     = false
}

# High Availability Configuration
variable "high_availability_config" {
  description = "High availability configuration"
  type = object({
    enable_multi_zone   = optional(bool)
    enable_auto_scaling = optional(bool)
    min_workers         = optional(number)
    max_workers         = optional(number)
    scheduler_count     = optional(number)
  })
  default = {
    enable_multi_zone = false
  }
}

# Security Configuration
variable "security_config" {
  description = "Security configuration"
  type = object({
    enable_rbac                = optional(bool)
    enable_pod_security_policy = optional(bool)
    enable_network_policy      = optional(bool)
    enable_workload_identity   = optional(bool)
  })
  default = {
    enable_rbac = true
  }
}

# Performance Configuration
variable "performance_config" {
  description = "Performance configuration"
  type = object({
    parallelism               = optional(number)
    dag_concurrency           = optional(number)
    max_active_runs_per_dag   = optional(number)
    celery_worker_concurrency = optional(number)
  })
  default = {}
}

# Cost Optimization Configuration
variable "cost_optimization_config" {
  description = "Cost optimization configuration"
  type = object({
    enable_preemptible_nodes = optional(bool)
    enable_auto_pause        = optional(bool)
    idle_timeout_minutes     = optional(number)
  })
  default = {
    enable_preemptible_nodes = false
  }
}

# Data Processing Configuration
variable "data_processing_config" {
  description = "Data processing configuration"
  type = object({
    enable_kubernetes_pod_operator = optional(bool)
    enable_dataflow_operator       = optional(bool)
    enable_bigquery_operator       = optional(bool)
    enable_cloud_sql_operator      = optional(bool)
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