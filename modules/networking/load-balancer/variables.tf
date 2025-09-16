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
