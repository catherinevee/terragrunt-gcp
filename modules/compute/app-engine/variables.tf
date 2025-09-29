# App Engine Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for App Engine"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# Application Configuration
variable "create_application" {
  description = "Whether to create App Engine application"
  type        = bool
  default     = true
}

variable "app_id" {
  description = "App Engine application ID"
  type        = string
  default     = null
}

variable "auth_domain" {
  description = "Auth domain for the application"
  type        = string
  default     = null
}

variable "serving_status" {
  description = "Serving status of the application"
  type        = string
  default     = "SERVING"
}

variable "database_type" {
  description = "Database type for the application"
  type        = string
  default     = "CLOUD_FIRESTORE"
}

variable "feature_settings" {
  description = "Feature settings for the application"
  type = object({
    split_health_checks = bool
  })
  default = null
}

# Service Configuration
variable "service_name" {
  description = "Name of the App Engine service"
  type        = string
  default     = "default"
}

variable "version_id" {
  description = "Version ID for the deployment"
  type        = string
  default     = null
}

variable "deploy_version" {
  description = "Whether to deploy a version"
  type        = bool
  default     = true
}

variable "environment_type" {
  description = "App Engine environment type"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "flexible"], var.environment_type)
    error_message = "Environment type must be standard or flexible"
  }
}

# Runtime Configuration
variable "runtime" {
  description = "Runtime for the application"
  type        = string
  default     = "python39"
}

variable "runtime_channel" {
  description = "Runtime channel (flexible only)"
  type        = string
  default     = null
}

variable "instance_class" {
  description = "Instance class for standard environment"
  type        = string
  default     = "F1"
}

# Scaling Configuration
variable "scaling_type" {
  description = "Type of scaling"
  type        = string
  default     = "automatic"

  validation {
    condition     = contains(["automatic", "manual", "basic"], var.scaling_type)
    error_message = "Scaling type must be automatic, manual, or basic"
  }
}

variable "automatic_scaling" {
  description = "Automatic scaling configuration for standard"
  type = object({
    min_idle_instances      = optional(number)
    max_idle_instances      = optional(number)
    min_pending_latency     = optional(string)
    max_pending_latency     = optional(string)
    max_concurrent_requests = optional(number)
    standard_scheduler_settings = optional(object({
      target_cpu_utilization        = optional(number)
      target_throughput_utilization = optional(number)
      min_instances                = optional(number)
      max_instances                = optional(number)
    }))
  })
  default = {
    min_idle_instances      = 1
    max_idle_instances      = 10
    min_pending_latency     = "0.1s"
    max_pending_latency     = "1s"
    max_concurrent_requests = 10
  }
}

variable "automatic_scaling_flex" {
  description = "Automatic scaling for flexible environment"
  type = object({
    min_total_instances       = number
    max_total_instances       = number
    cool_down_period         = optional(string)
    cpu_utilization = optional(object({
      target_utilization        = number
      aggregation_window_length = optional(string)
    }))
    disk_utilization = optional(object({
      target_write_bytes_per_second = optional(number)
      target_write_ops_per_second   = optional(number)
      target_read_bytes_per_second  = optional(number)
      target_read_ops_per_second    = optional(number)
    }))
    network_utilization = optional(object({
      target_sent_bytes_per_second       = optional(number)
      target_sent_packets_per_second     = optional(number)
      target_received_bytes_per_second   = optional(number)
      target_received_packets_per_second = optional(number)
    }))
    request_utilization = optional(object({
      target_request_count_per_second = optional(string)
      target_concurrent_requests      = optional(number)
    }))
  })
  default = {
    min_total_instances = 1
    max_total_instances = 10
    cool_down_period    = "120s"
    cpu_utilization = {
      target_utilization = 0.6
    }
  }
}

variable "manual_scaling" {
  description = "Manual scaling for standard"
  type = object({
    instances = number
  })
  default = {
    instances = 1
  }
}

variable "manual_scaling_flex" {
  description = "Manual scaling for flexible"
  type = object({
    instances = number
  })
  default = {
    instances = 2
  }
}

variable "basic_scaling" {
  description = "Basic scaling configuration"
  type = object({
    max_instances = number
    idle_timeout  = optional(string)
  })
  default = {
    max_instances = 5
    idle_timeout  = "10m"
  }
}

# Deployment Configuration
variable "deployment_zip" {
  description = "Deployment ZIP configuration"
  type = object({
    source_url  = string
    files_count = optional(number)
  })
  default = null
}

variable "deployment_container" {
  description = "Container deployment for flexible"
  type = object({
    image = string
  })
  default = null
}

variable "deployment_files" {
  description = "Deployment files map"
  type        = map(string)
  default     = {}
}

variable "cloud_build_options" {
  description = "Cloud Build options"
  type = object({
    app_yaml_path       = optional(string)
    cloud_build_timeout = optional(string)
  })
  default = null
}

# Resources (Flexible only)
variable "resources" {
  description = "Resource allocation for flexible"
  type = object({
    cpu       = number
    memory_gb = number
    disk_gb   = number
    volumes = optional(list(object({
      name        = string
      volume_type = string
      size_gb     = number
    })))
  })
  default = {
    cpu       = 1
    memory_gb = 1
    disk_gb   = 10
    volumes   = []
  }
}

# Network Configuration
variable "network_name" {
  description = "Network name for flexible"
  type        = string
  default     = "default"
}

variable "subnetwork_name" {
  description = "Subnetwork name for flexible"
  type        = string
  default     = null
}

variable "instance_tag" {
  description = "Instance tag for flexible"
  type        = string
  default     = null
}

variable "forwarded_ports" {
  description = "Forwarded ports for flexible"
  type        = list(string)
  default     = []
}

variable "session_affinity" {
  description = "Enable session affinity"
  type        = bool
  default     = false
}

variable "vpc_connector_name" {
  description = "VPC connector name"
  type        = string
  default     = null
}

variable "vpc_egress_setting" {
  description = "VPC egress setting"
  type        = string
  default     = "PRIVATE_IP_RANGES"
}

# Application Configuration
variable "entrypoint_shell" {
  description = "Entrypoint shell command"
  type        = string
  default     = null
}

variable "env_variables" {
  description = "Environment variables"
  type        = map(string)
  default     = {}
}

variable "beta_settings" {
  description = "Beta settings"
  type        = map(string)
  default     = {}
}

# Handlers (Standard only)
variable "handlers" {
  description = "URL handlers for standard"
  type = list(object({
    url_regex                   = string
    security_level             = optional(string)
    login                      = optional(string)
    auth_fail_action           = optional(string)
    redirect_http_response_code = optional(string)
    static_files = optional(object({
      path                  = string
      upload_path_regex     = string
      http_headers         = optional(map(string))
      mime_type            = optional(string)
      expiration           = optional(string)
      require_matching_file = optional(bool)
      application_readable = optional(bool)
    }))
    script = optional(object({
      script_path = string
    }))
  }))
  default = []
}

# Libraries (Standard only)
variable "libraries" {
  description = "Libraries for standard"
  type = list(object({
    name    = string
    version = string
  }))
  default = []
}

# Inbound Services
variable "inbound_services" {
  description = "Inbound services"
  type        = list(string)
  default     = []
}

# Health Checks
variable "liveness_check" {
  description = "Liveness check configuration"
  type = object({
    path              = string
    host              = optional(string)
    failure_threshold = optional(number)
    success_threshold = optional(number)
    check_interval    = optional(string)
    timeout           = optional(string)
    initial_delay     = optional(string)
  })
  default = {
    path              = "/"
    failure_threshold = 2
    success_threshold = 2
    check_interval    = "30s"
    timeout           = "4s"
    initial_delay     = "300s"
  }
}

variable "readiness_check" {
  description = "Readiness check configuration"
  type = object({
    path              = string
    host              = optional(string)
    failure_threshold = optional(number)
    success_threshold = optional(number)
    check_interval    = optional(string)
    timeout           = optional(string)
    app_start_timeout = optional(string)
  })
  default = {
    path              = "/"
    failure_threshold = 2
    success_threshold = 2
    check_interval    = "5s"
    timeout           = "4s"
    app_start_timeout = "300s"
  }
}

# API Configuration
variable "endpoints_api_service" {
  description = "Endpoints API service"
  type = object({
    name                   = string
    config_id             = optional(string)
    rollout_strategy      = optional(string)
    disable_trace_sampling = optional(bool)
  })
  default = null
}

variable "api_config" {
  description = "API configuration"
  type = object({
    auth_fail_action = optional(string)
    login           = optional(string)
    script          = optional(string)
    security_level  = optional(string)
    url             = optional(string)
  })
  default = null
}

# Domain Mappings
variable "domain_mappings" {
  description = "Domain mappings"
  type = map(object({
    domain_name = string
    ssl_settings = optional(object({
      ssl_management_type = string
      certificate_id     = optional(string)
    }))
  }))
  default = {}
}

# Firewall Rules
variable "firewall_rules" {
  description = "App Engine firewall rules"
  type = map(object({
    priority     = number
    action       = string
    source_range = string
    description  = optional(string)
  }))
  default = {}
}

# IAM
variable "service_iam_members" {
  description = "Service IAM members"
  type = map(object({
    service = string
    role    = string
    member  = string
  }))
  default = {}
}

# Lifecycle
variable "delete_service_on_destroy" {
  description = "Delete service on destroy"
  type        = bool
  default     = false
}

variable "noop_on_destroy" {
  description = "No-op on destroy"
  type        = bool
  default     = false
}

variable "ignore_changes" {
  description = "List of attributes to ignore"
  type        = list(string)
  default     = []
}

# Labels
variable "labels" {
  description = "Labels to apply"
  type        = map(string)
  default     = {}
}