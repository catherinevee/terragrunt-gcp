# VPC Module Variables

variable "name" {
  description = "The name of the VPC network"
  type        = string
}

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for regional resources"
  type        = string
  default     = "us-central1"
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
}

variable "mtu" {
  description = "The network MTU"
  type        = number
  default     = 1460
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
}

variable "tags" {
  description = "Network tags"
  type        = list(string)
  default     = []
}