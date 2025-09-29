# Dataflow Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for the Dataflow job"
  type        = string
}

variable "zone" {
  description = "The zone for the Dataflow job"
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Job Configuration
variable "job_name" {
  description = "Name of the Dataflow job"
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Name prefix for the Dataflow job"
  type        = string
  default     = "dataflow-job"
}

variable "job_description" {
  description = "Description of the Dataflow job"
  type        = string
  default     = null
}

variable "template_type" {
  description = "Type of Dataflow template (classic, flex, sql, python)"
  type        = string
  default     = "flex"

  validation {
    condition     = contains(["classic", "flex", "sql", "python"], var.template_type)
    error_message = "template_type must be classic, flex, sql, or python"
  }
}

variable "deploy_job" {
  description = "Whether to deploy the Dataflow job"
  type        = bool
  default     = true
}

variable "is_streaming_job" {
  description = "Whether this is a streaming job"
  type        = bool
  default     = false
}

# Template Configuration
variable "template_gcs_path" {
  description = "GCS path to the Dataflow template"
  type        = string
  default     = null
}

variable "classic_template_location" {
  description = "Location of classic template"
  type        = string
  default     = null
}

variable "flex_template_spec_path" {
  description = "GCS path to flex template spec"
  type        = string
  default     = null
}

variable "flex_template_bucket" {
  description = "Bucket for flex template spec"
  type        = string
  default     = null
}

variable "create_flex_template_spec" {
  description = "Create flex template spec file"
  type        = bool
  default     = false
}

variable "container_image" {
  description = "Container image for flex template"
  type        = string
  default     = null
}

variable "sdk_language" {
  description = "SDK language (JAVA, PYTHON)"
  type        = string
  default     = "JAVA"
}

variable "flex_template_metadata" {
  description = "Additional metadata for flex template"
  type        = map(string)
  default     = {}
}

variable "flex_template_spec" {
  description = "Complete flex template specification"
  type        = any
  default     = null
}

variable "parameter_metadata" {
  description = "Parameter metadata for flex template"
  type        = list(map(string))
  default     = []
}

variable "flex_template_parameters" {
  description = "Additional parameters for flex template"
  type        = map(string)
  default     = {}
}

# Python Job Configuration
variable "python_pipeline_path" {
  description = "Path to Python pipeline file"
  type        = string
  default     = null
}

variable "python_setup_file" {
  description = "Path to Python setup.py file"
  type        = string
  default     = null
}

variable "python_requirements_file" {
  description = "Path to Python requirements.txt file"
  type        = string
  default     = null
}

variable "python_save_main_session" {
  description = "Save main session for Python job"
  type        = bool
  default     = true
}

variable "python_sdk_container_image" {
  description = "SDK container image for Python"
  type        = string
  default     = null
}

variable "python_sdk_harness_overrides" {
  description = "SDK harness container image overrides"
  type        = map(string)
  default     = {}
}

variable "python_pipeline_options" {
  description = "Additional pipeline options for Python job"
  type        = map(string)
  default     = {}
}

variable "python_environment_vars" {
  description = "Environment variables for Python job execution"
  type        = map(string)
  default     = {}
}

variable "google_credentials_path" {
  description = "Path to Google credentials file"
  type        = string
  default     = null
}

# SQL Template Configuration
variable "sql_query" {
  description = "SQL query for SQL template"
  type        = string
  default     = null
}

variable "sql_output_table" {
  description = "Output table for SQL template"
  type        = string
  default     = null
}

variable "sql_bigquery_project" {
  description = "BigQuery project for SQL template"
  type        = string
  default     = null
}

variable "sql_bigquery_dataset" {
  description = "BigQuery dataset for SQL template"
  type        = string
  default     = null
}

variable "sql_temp_directory" {
  description = "Temporary directory for SQL template"
  type        = string
  default     = null
}

variable "sql_output_table_spec" {
  description = "Output table specification for SQL template"
  type        = string
  default     = null
}

variable "sql_input_subscription" {
  description = "Input Pub/Sub subscription for SQL template"
  type        = string
  default     = null
}

variable "sql_output_topic" {
  description = "Output Pub/Sub topic for SQL template"
  type        = string
  default     = null
}

variable "sql_udf_gcs_path" {
  description = "GCS path to JavaScript UDF for SQL template"
  type        = string
  default     = null
}

variable "sql_udf_function_name" {
  description = "JavaScript UDF function name"
  type        = string
  default     = null
}

# Worker Configuration
variable "machine_type" {
  description = "Machine type for workers"
  type        = string
  default     = "n1-standard-1"
}

variable "initial_workers" {
  description = "Initial number of workers"
  type        = number
  default     = 1
}

variable "max_workers" {
  description = "Maximum number of workers"
  type        = number
  default     = 10
}

variable "disk_type" {
  description = "Disk type for workers"
  type        = string
  default     = "pd-standard"
}

variable "disk_size_gb" {
  description = "Disk size in GB for workers"
  type        = number
  default     = 100
}

variable "worker_region" {
  description = "Region for workers"
  type        = string
  default     = null
}

variable "worker_zone" {
  description = "Zone for workers"
  type        = string
  default     = null
}

variable "launcher_machine_type" {
  description = "Machine type for launcher VM"
  type        = string
  default     = null
}

# Network Configuration
variable "network" {
  description = "Network for Dataflow job"
  type        = string
  default     = null
}

variable "subnetwork" {
  description = "Subnetwork for Dataflow job"
  type        = string
  default     = null
}

variable "use_public_ips" {
  description = "Use public IPs for workers"
  type        = bool
  default     = false
}

variable "ip_configuration" {
  description = "IP configuration (WORKER_IP_PUBLIC or WORKER_IP_PRIVATE)"
  type        = string
  default     = "WORKER_IP_PRIVATE"

  validation {
    condition     = contains(["WORKER_IP_PUBLIC", "WORKER_IP_PRIVATE"], var.ip_configuration)
    error_message = "ip_configuration must be WORKER_IP_PUBLIC or WORKER_IP_PRIVATE"
  }
}

variable "create_firewall_rules" {
  description = "Create firewall rules for Dataflow"
  type        = bool
  default     = false
}

# Storage Configuration
variable "temp_location" {
  description = "GCS path for temporary files"
  type        = string
  default     = null
}

variable "staging_location" {
  description = "GCS path for staging files"
  type        = string
  default     = null
}

variable "create_staging_bucket" {
  description = "Create staging bucket"
  type        = bool
  default     = false
}

variable "staging_bucket_name" {
  description = "Name of staging bucket"
  type        = string
  default     = null
}

variable "staging_bucket_force_destroy" {
  description = "Force destroy staging bucket"
  type        = bool
  default     = false
}

variable "staging_bucket_lifecycle_days" {
  description = "Lifecycle rule for staging bucket (days)"
  type        = number
  default     = 30
}

variable "create_temp_bucket" {
  description = "Create temporary files bucket"
  type        = bool
  default     = false
}

variable "temp_bucket_name" {
  description = "Name of temporary files bucket"
  type        = string
  default     = null
}

variable "temp_bucket_force_destroy" {
  description = "Force destroy temp bucket"
  type        = bool
  default     = false
}

variable "temp_bucket_lifecycle_days" {
  description = "Lifecycle rule for temp bucket (days)"
  type        = number
  default     = 7
}

# Service Account
variable "service_account_email" {
  description = "Service account email for Dataflow job"
  type        = string
  default     = null
}

variable "create_service_account" {
  description = "Create a new service account"
  type        = bool
  default     = false
}

variable "service_account_name" {
  description = "Name for new service account"
  type        = string
  default     = null
}

variable "create_service_account_key" {
  description = "Create service account key"
  type        = bool
  default     = false
}

variable "create_service_account_roles" {
  description = "Grant necessary roles to service account"
  type        = bool
  default     = false
}

variable "grant_bigquery_access" {
  description = "Grant BigQuery access to service account"
  type        = bool
  default     = false
}

variable "grant_pubsub_access" {
  description = "Grant Pub/Sub access to service account"
  type        = bool
  default     = false
}

# Security
variable "kms_key_name" {
  description = "KMS key for encryption"
  type        = string
  default     = null
}

variable "enable_kerberos" {
  description = "Enable Kerberos configuration"
  type        = bool
  default     = false
}

# Streaming Configuration
variable "enable_streaming_engine" {
  description = "Enable Streaming Engine"
  type        = bool
  default     = false
}

variable "enable_streaming_update" {
  description = "Enable streaming job update"
  type        = bool
  default     = false
}

variable "update_compatibility_version" {
  description = "Update compatibility version"
  type        = string
  default     = null
}

variable "transform_name_mapping" {
  description = "Transform name mapping for updates"
  type        = map(string)
  default     = {}
}

# Autoscaling
variable "enable_autoscaling" {
  description = "Enable autoscaling"
  type        = bool
  default     = true
}

variable "autoscaling_algorithm" {
  description = "Autoscaling algorithm"
  type        = string
  default     = "THROUGHPUT_BASED"

  validation {
    condition     = contains(["NONE", "THROUGHPUT_BASED", "BASIC"], var.autoscaling_algorithm)
    error_message = "autoscaling_algorithm must be NONE, THROUGHPUT_BASED, or BASIC"
  }
}

variable "enable_flexrs_goal" {
  description = "Enable FlexRS goal for autoscaling"
  type        = bool
  default     = false
}

# Job Management
variable "on_delete_action" {
  description = "Action to take on job deletion (cancel, drain)"
  type        = string
  default     = "cancel"

  validation {
    condition     = contains(["cancel", "drain"], var.on_delete_action)
    error_message = "on_delete_action must be cancel or drain"
  }
}

variable "skip_wait_on_job_termination" {
  description = "Skip waiting for job termination"
  type        = bool
  default     = false
}

variable "ignore_job_changes" {
  description = "List of attributes to ignore changes on"
  type        = list(string)
  default     = []
}

# Additional Configuration
variable "parameters" {
  description = "Additional parameters for the Dataflow job"
  type        = map(string)
  default     = {}
}

variable "labels" {
  description = "Labels for the Dataflow job"
  type        = map(string)
  default     = {}
}

variable "additional_experiments" {
  description = "Additional experiments to enable"
  type        = list(string)
  default     = []
}

# Monitoring
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