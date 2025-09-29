# Load Balancer Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "global_ip_name" {
  description = "Name of the global IP address"
  type        = string
}

variable "health_check_name" {
  description = "Name of the health check"
  type        = string
}

variable "backend_service_name" {
  description = "Name of the backend service"
  type        = string
}

variable "url_map_name" {
  description = "Name of the URL map"
  type        = string
}

variable "forwarding_rule_name" {
  description = "Name of the forwarding rule"
  type        = string
}

variable "backend_regions" {
  description = "List of backend regions"
  type        = list(string)
  default     = []
}

variable "backend_instance_groups" {
  description = "Map of region to instance group URLs or names"
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for group_ref in values(var.backend_instance_groups) :
      can(regex("^(projects/.+/regions/.+/instanceGroups/.+|[a-z0-9-]+)$", group_ref))
    ])
    error_message = "Instance group references must be either full URLs (projects/{project}/regions/{region}/instanceGroups/{name}) or simple names."
  }
}

variable "auto_create_instance_groups" {
  description = "Whether to automatically create managed instance groups for backend regions"
  type        = bool
  default     = false
}

variable "instance_group_config" {
  description = "Configuration for auto-created instance groups"
  type = object({
    base_instance_name = string
    instance_template  = string
    target_size        = number
    zone_distribution_policy = optional(object({
      zones        = list(string)
      target_shape = optional(string, "EVEN")
    }))
  })
  default = {
    base_instance_name = "backend-instance"
    instance_template  = ""
    target_size        = 1
  }
}

variable "health_check_config" {
  description = "Health check configuration"
  type = object({
    check_interval_sec  = number
    timeout_sec         = number
    healthy_threshold   = number
    unhealthy_threshold = number
    port                = number
    request_path        = string
  })
  default = {
    check_interval_sec  = 10
    timeout_sec         = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    port                = 80
    request_path        = "/"
  }
}
