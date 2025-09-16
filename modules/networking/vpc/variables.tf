# VPC Network Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "description" {
  description = "Description of the VPC network"
  type        = string
  default     = ""
}

variable "auto_create_subnetworks" {
  description = "Whether to automatically create subnetworks"
  type        = bool
  default     = false
}

variable "routing_mode" {
  description = "Routing mode for the VPC network"
  type        = string
  default     = "GLOBAL"
}
