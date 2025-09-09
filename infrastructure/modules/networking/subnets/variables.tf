variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
}

variable "subnets" {
  description = "List of subnets to create"
  type = list(object({
    name                     = string
    ip_cidr_range           = string
    region                  = optional(string)
    description             = optional(string)
    purpose                 = optional(string)
    role                    = optional(string)
    private_ip_google_access = optional(bool, true)
    flow_logs               = optional(bool, false)
    log_config = optional(object({
      aggregation_interval = optional(string, "INTERVAL_5_SEC")
      flow_sampling       = optional(number, 0.5)
      metadata           = optional(string, "INCLUDE_ALL_METADATA")
    }))
    secondary_ip_ranges = optional(list(object({
      range_name    = string
      ip_cidr_range = string
    })), [])
  }))
}

variable "labels" {
  description = "Labels to apply to all subnets"
  type        = map(string)
  default     = {}
}