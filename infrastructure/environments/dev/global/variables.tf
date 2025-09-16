# Global Variables for Multi-Region Deployment

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "primary_region" {
  description = "Primary GCP region"
  type        = string
  default     = "us-central1"
}

variable "secondary_region" {
  description = "Secondary GCP region"
  type        = string
  default     = "us-east1"
}

variable "dns_zone_name" {
  description = "DNS zone name"
  type        = string
  default     = "acme-ecommerce-dev-com"
}

variable "dns_name" {
  description = "DNS name for the zone"
  type        = string
  default     = "dev.acme-ecommerce.com."
}

variable "organization" {
  description = "Organization name"
  type        = string
  default     = "acme-corp"
}

variable "business_unit" {
  description = "Business unit name"
  type        = string
  default     = "ecommerce"
}

variable "application" {
  description = "Application name"
  type        = string
  default     = "ecommerce-platform"
}

# Load Balancer Configuration
variable "load_balancer_health_check_interval" {
  description = "Health check interval for load balancer in seconds"
  type        = number
  default     = 10
  validation {
    condition     = var.load_balancer_health_check_interval >= 5 && var.load_balancer_health_check_interval <= 60
    error_message = "Load balancer health check interval must be between 5 and 60 seconds."
  }
}

variable "load_balancer_health_check_timeout" {
  description = "Health check timeout for load balancer in seconds"
  type        = number
  default     = 5
  validation {
    condition     = var.load_balancer_health_check_timeout >= 1 && var.load_balancer_health_check_timeout <= 30
    error_message = "Load balancer health check timeout must be between 1 and 30 seconds."
  }
}

variable "load_balancer_health_check_port" {
  description = "Health check port for load balancer"
  type        = number
  default     = 80
  validation {
    condition     = var.load_balancer_health_check_port >= 1 && var.load_balancer_health_check_port <= 65535
    error_message = "Load balancer health check port must be between 1 and 65535."
  }
}

variable "load_balancer_healthy_threshold" {
  description = "Number of consecutive successful health checks before marking instance healthy"
  type        = number
  default     = 2
  validation {
    condition     = var.load_balancer_healthy_threshold >= 1 && var.load_balancer_healthy_threshold <= 10
    error_message = "Load balancer healthy threshold must be between 1 and 10."
  }
}

variable "load_balancer_unhealthy_threshold" {
  description = "Number of consecutive failed health checks before marking instance unhealthy"
  type        = number
  default     = 3
  validation {
    condition     = var.load_balancer_unhealthy_threshold >= 1 && var.load_balancer_unhealthy_threshold <= 10
    error_message = "Load balancer unhealthy threshold must be between 1 and 10."
  }
}

# DNS Configuration
variable "dns_ttl_seconds" {
  description = "DNS record TTL in seconds"
  type        = number
  default     = 300
  validation {
    condition     = var.dns_ttl_seconds >= 60 && var.dns_ttl_seconds <= 86400
    error_message = "DNS TTL must be between 60 and 86400 seconds (24 hours)."
  }
}

# Monitoring Configuration
variable "monitoring_cpu_threshold_percent" {
  description = "CPU utilization threshold for monitoring alerts"
  type        = number
  default     = 80
  validation {
    condition     = var.monitoring_cpu_threshold_percent >= 50 && var.monitoring_cpu_threshold_percent <= 95
    error_message = "CPU threshold must be between 50 and 95 percent."
  }
}

variable "monitoring_memory_threshold_percent" {
  description = "Memory utilization threshold for monitoring alerts"
  type        = number
  default     = 85
  validation {
    condition     = var.monitoring_memory_threshold_percent >= 50 && var.monitoring_memory_threshold_percent <= 95
    error_message = "Memory threshold must be between 50 and 95 percent."
  }
}

variable "monitoring_disk_threshold_percent" {
  description = "Disk utilization threshold for monitoring alerts"
  type        = number
  default     = 20
  validation {
    condition     = var.monitoring_disk_threshold_percent >= 10 && var.monitoring_disk_threshold_percent <= 90
    error_message = "Disk threshold must be between 10 and 90 percent."
  }
}

# SLO Configuration
variable "slo_availability_goal" {
  description = "Availability goal for SLO (as decimal, e.g., 0.999 for 99.9%)"
  type        = number
  default     = 0.999
  validation {
    condition     = var.slo_availability_goal >= 0.9 && var.slo_availability_goal <= 0.9999
    error_message = "SLO availability goal must be between 0.9 (90%) and 0.9999 (99.99%)."
  }
}

variable "slo_rolling_period_days" {
  description = "Rolling period for SLO calculation in days"
  type        = number
  default     = 30
  validation {
    condition     = var.slo_rolling_period_days >= 7 && var.slo_rolling_period_days <= 90
    error_message = "SLO rolling period must be between 7 and 90 days."
  }
}

variable "monitoring_dashboard_columns" {
  description = "Number of columns for monitoring dashboards"
  type        = number
  default     = 12
  validation {
    condition     = var.monitoring_dashboard_columns >= 1 && var.monitoring_dashboard_columns <= 48
    error_message = "Dashboard columns must be between 1 and 48."
  }
}

