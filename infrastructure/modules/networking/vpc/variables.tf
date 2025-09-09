# VPC Module Variables

variable "name" {
  description = "The name of the VPC network"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]{0,61}[a-z0-9])?$", var.name))
    error_message = "VPC name must start with a lowercase letter, contain only lowercase letters, numbers, and hyphens, and be at most 63 characters."
  }
}

variable "project_id" {
  description = "The GCP project ID"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, start with a lowercase letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "region" {
  description = "The region for regional resources"
  type        = string
  default     = "us-central1"
  
  validation {
    condition = contains([
      "us-central1", "us-east1", "us-east4", "us-west1", "us-west2", "us-west3", "us-west4",
      "europe-west1", "europe-west2", "europe-west3", "europe-west4", "europe-west6",
      "asia-east1", "asia-northeast1", "asia-southeast1"
    ], var.region)
    error_message = "Region must be a valid GCP region."
  }
}

variable "auto_create_subnetworks" {
  description = "Whether to create subnetworks automatically"
  type        = bool
  default     = false
}

variable "routing_mode" {
  description = "The network routing mode (REGIONAL or GLOBAL)"
  type        = string
  default     = "REGIONAL"
  
  validation {
    condition     = contains(["REGIONAL", "GLOBAL"], var.routing_mode)
    error_message = "Routing mode must be either REGIONAL or GLOBAL."
  }
}

variable "mtu" {
  description = "The network MTU"
  type        = number
  default     = 1460
  
  validation {
    condition     = var.mtu >= 1300 && var.mtu <= 8896
    error_message = "MTU must be between 1300 and 8896."
  }
}

variable "delete_default_routes_on_create" {
  description = "Whether to delete default routes on create"
  type        = bool
  default     = false
}

variable "description" {
  description = "Description of the VPC network"
  type        = string
  default     = ""
}

variable "subnets" {
  description = "List of subnets to create"
  type = list(object({
    subnet_name           = string
    subnet_ip             = string
    subnet_region         = string
    subnet_private_access = optional(bool)
    subnet_flow_logs      = optional(bool)
    description          = optional(string)
  }))
  default = []
}

variable "secondary_ranges" {
  description = "Secondary ranges for subnets"
  type = map(list(object({
    range_name    = string
    ip_cidr_range = string
  })))
  default = {}
}

variable "firewall_rules" {
  description = "List of firewall rules"
  type = list(object({
    name        = string
    description = optional(string)
    direction   = optional(string)
    priority    = optional(number)
    
    source_ranges      = optional(list(string))
    destination_ranges = optional(list(string))
    source_tags       = optional(list(string))
    target_tags       = optional(list(string))
    
    allow = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })))
    
    deny = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })))
    
    enable_logging = optional(bool)
  }))
  default = []
}

variable "enable_cloud_nat" {
  description = "Whether to enable Cloud NAT"
  type        = bool
  default     = false
}

variable "nat_config" {
  description = "Cloud NAT configuration"
  type = object({
    name                               = string
    source_subnetwork_ip_ranges_to_nat = string
    min_ports_per_vm                   = optional(number)
    max_ports_per_vm                   = optional(number)
    tcp_established_idle_timeout_sec   = optional(number)
    tcp_transitory_idle_timeout_sec    = optional(number)
    enable_endpoint_independent_mapping = optional(bool)
  })
  default = {
    name                               = "nat-gateway"
    source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  }
}

variable "enable_vpc_connector" {
  description = "Whether to enable VPC connector for serverless"
  type        = bool
  default     = false
}

variable "vpc_connector_config" {
  description = "VPC connector configuration"
  type = object({
    name          = string
    ip_cidr_range = string
    min_instances = optional(number)
    max_instances = optional(number)
    machine_type  = optional(string)
  })
  default = {
    name          = "vpc-connector"
    ip_cidr_range = "10.8.0.0/28"
  }
}

variable "enable_private_service_connection" {
  description = "Whether to enable private service connection for managed services"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
  
  validation {
    condition = alltrue([
      for k, v in var.labels : can(regex("^[a-z][a-z0-9_-]{0,62}$", k))
    ])
    error_message = "Label keys must start with a lowercase letter and contain only lowercase letters, numbers, underscores, and hyphens."
  }
  
  validation {
    condition = alltrue([
      for k, v in var.labels : length(v) <= 63
    ])
    error_message = "Label values must be 63 characters or less."
  }
}

variable "tags" {
  description = "Network tags"
  type        = list(string)
  default     = []
}