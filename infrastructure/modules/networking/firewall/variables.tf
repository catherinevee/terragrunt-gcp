variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
}

variable "firewall_rules" {
  description = "List of firewall rules to create"
  type = list(object({
    name                    = string
    description            = optional(string)
    direction              = optional(string, "INGRESS")
    priority               = optional(number, 1000)
    source_ranges          = optional(list(string), [])
    destination_ranges     = optional(list(string), [])
    source_tags            = optional(list(string), [])
    target_tags            = optional(list(string), [])
    source_service_accounts = optional(list(string), [])
    target_service_accounts = optional(list(string), [])
    allow = optional(list(object({
      protocol = string
      ports    = optional(list(string), [])
    })), [])
    deny = optional(list(object({
      protocol = string
      ports    = optional(list(string), [])
    })), [])
    enable_logging = optional(bool, false)
    disabled       = optional(bool, false)
  }))
  default = []
}