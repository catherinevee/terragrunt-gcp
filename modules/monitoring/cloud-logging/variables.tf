# Cloud Logging Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "log_sinks" {
  description = "Log sinks to create"
  type = map(object({
    name        = string
    destination = string
    filter      = string
  }))
  default = {}
}

variable "log_exclusions" {
  description = "Log exclusions to create"
  type = map(object({
    name        = string
    description = string
    filter      = string
  }))
  default = {}
}
