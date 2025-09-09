variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "name" {
  description = "Name of the Cloud NAT"
  type        = string
}

variable "router_name" {
  description = "Name of the Cloud Router to attach NAT to"
  type        = string
}

variable "nat_ip_allocate_option" {
  description = "How external IPs should be allocated for this NAT"
  type        = string
  default     = "AUTO_ONLY"
  validation {
    condition     = contains(["AUTO_ONLY", "MANUAL_ONLY"], var.nat_ip_allocate_option)
    error_message = "nat_ip_allocate_option must be either AUTO_ONLY or MANUAL_ONLY"
  }
}

variable "source_subnetwork_ip_ranges_to_nat" {
  description = "How NAT should be configured per Subnetwork"
  type        = string
  default     = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  validation {
    condition = contains([
      "ALL_SUBNETWORKS_ALL_IP_RANGES",
      "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES",
      "LIST_OF_SUBNETWORKS"
    ], var.source_subnetwork_ip_ranges_to_nat)
    error_message = "Invalid source_subnetwork_ip_ranges_to_nat value"
  }
}

variable "nat_ips" {
  description = "List of self_links of external IPs. Only valid if nat_ip_allocate_option is MANUAL_ONLY"
  type        = list(string)
  default     = []
}

variable "subnetworks" {
  description = "List of subnetworks to NAT. Only used if source_subnetwork_ip_ranges_to_nat is LIST_OF_SUBNETWORKS"
  type = list(object({
    name                     = string
    source_ip_ranges_to_nat  = list(string)
    secondary_ip_range_names = list(string)
  }))
  default = []
}

variable "min_ports_per_vm" {
  description = "Minimum number of ports allocated to a VM from this NAT"
  type        = number
  default     = 64
}

variable "max_ports_per_vm" {
  description = "Maximum number of ports allocated to a VM from this NAT"
  type        = number
  default     = null
}

variable "enable_endpoint_independent_mapping" {
  description = "Specifies if endpoint independent mapping is enabled"
  type        = bool
  default     = false
}

variable "enable_dynamic_port_allocation" {
  description = "Enable Dynamic Port Allocation"
  type        = bool
  default     = true
}

variable "icmp_idle_timeout_sec" {
  description = "Timeout (in seconds) for ICMP connections"
  type        = number
  default     = 30
}

variable "tcp_established_idle_timeout_sec" {
  description = "Timeout (in seconds) for TCP established connections"
  type        = number
  default     = 1200
}

variable "tcp_transitory_idle_timeout_sec" {
  description = "Timeout (in seconds) for TCP transitory connections"
  type        = number
  default     = 30
}

variable "tcp_time_wait_timeout_sec" {
  description = "Timeout (in seconds) for TCP connections in TIME_WAIT state"
  type        = number
  default     = 120
}

variable "udp_idle_timeout_sec" {
  description = "Timeout (in seconds) for UDP connections"
  type        = number
  default     = 30
}

variable "log_config" {
  description = "Configuration for NAT logging"
  type = object({
    enable = bool
    filter = string
  })
  default = {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

variable "labels" {
  description = "Labels to apply to the NAT"
  type        = map(string)
  default     = {}
}