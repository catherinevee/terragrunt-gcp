# DNS Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "zone_name" {
  description = "Name of the DNS zone"
  type        = string
}

variable "dns_name" {
  description = "DNS name of the zone"
  type        = string
}

variable "load_balancer_ip" {
  description = "IP address of the load balancer"
  type        = string
}

variable "records" {
  description = "DNS records to create"
  type = map(object({
    name = string
    type = string
    ttl  = number
  }))
  default = {}
}
