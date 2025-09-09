# GKE Module Variables

variable "name" {
  description = "The name of the GKE cluster"
  type        = string
}

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for the GKE cluster"
  type        = string
}

variable "zone" {
  description = "The zone for zonal clusters"
  type        = string
  default     = ""
}

variable "regional" {
  description = "Whether to create a regional cluster"
  type        = bool
  default     = true
}

variable "network" {
  description = "The VPC network self link"
  type        = string
}

variable "subnetwork" {
  description = "The subnetwork self link"
  type        = string
}

variable "pods_range_name" {
  description = "The name of the secondary range for pods"
  type        = string
}

variable "services_range_name" {
  description = "The name of the secondary range for services"
  type        = string
}

variable "kubernetes_version" {
  description = "The Kubernetes version for the cluster"
  type        = string
  default     = "latest"
}

variable "enable_private_nodes" {
  description = "Whether nodes have internal IP addresses only"
  type        = bool
  default     = true
}

variable "enable_private_endpoint" {
  description = "Whether the master's internal IP is used as the cluster endpoint"
  type        = bool
  default     = false
}

variable "master_ipv4_cidr_block" {
  description = "The IP range for the master"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_global_access" {
  description = "Whether the cluster master is accessible globally"
  type        = bool
  default     = true
}

variable "master_authorized_networks" {
  description = "List of master authorized networks"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "enable_workload_identity" {
  description = "Whether to enable Workload Identity"
  type        = bool
  default     = true
}

variable "enable_binary_authorization" {
  description = "Whether to enable Binary Authorization"
  type        = bool
  default     = false
}

variable "enable_shielded_nodes" {
  description = "Whether to enable Shielded GKE Nodes"
  type        = bool
  default     = true
}

variable "enable_secure_boot" {
  description = "Whether to enable secure boot for nodes"
  type        = bool
  default     = true
}

variable "enable_integrity_monitoring" {
  description = "Whether to enable integrity monitoring for nodes"
  type        = bool
  default     = true
}

variable "maintenance_start_time" {
  description = "Start time for daily maintenance window"
  type        = string
  default     = "03:00"
}

variable "enable_cluster_autoscaling" {
  description = "Whether to enable cluster autoscaling"
  type        = bool
  default     = true
}

variable "cluster_autoscaling_resource_limits" {
  description = "Resource limits for cluster autoscaling"
  type = list(object({
    resource_type = string
    minimum       = number
    maximum       = number
  }))
  default = [
    {
      resource_type = "cpu"
      minimum       = 1
      maximum       = 100
    },
    {
      resource_type = "memory"
      minimum       = 1
      maximum       = 1000
    }
  ]
}

variable "network_policy_enabled" {
  description = "Whether to enable network policy"
  type        = bool
  default     = true
}

variable "enable_http_load_balancing" {
  description = "Whether to enable HTTP load balancing addon"
  type        = bool
  default     = true
}

variable "enable_horizontal_pod_autoscaling" {
  description = "Whether to enable horizontal pod autoscaling addon"
  type        = bool
  default     = true
}

variable "enable_gce_pd_csi_driver" {
  description = "Whether to enable GCE Persistent Disk CSI Driver"
  type        = bool
  default     = true
}

variable "enable_dns_cache" {
  description = "Whether to enable NodeLocal DNSCache"
  type        = bool
  default     = true
}

variable "enable_managed_prometheus" {
  description = "Whether to enable Google Cloud Managed Service for Prometheus"
  type        = bool
  default     = false
}

variable "logging_enabled_components" {
  description = "List of GKE components to collect logs for"
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS", "WORKLOADS"]
}

variable "monitoring_enabled_components" {
  description = "List of GKE components to collect metrics for"
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS"]
}

variable "service_account" {
  description = "Service account email for nodes"
  type        = string
  default     = ""
}

variable "oauth_scopes" {
  description = "OAuth scopes for nodes"
  type        = list(string)
  default = [
    "https://www.googleapis.com/auth/cloud-platform"
  ]
}

variable "auto_upgrade" {
  description = "Whether to enable auto-upgrade for nodes"
  type        = bool
  default     = true
}

variable "node_pools" {
  description = "Map of node pool configurations"
  type = map(object({
    initial_node_count = optional(number)
    min_nodes         = optional(number)
    max_nodes         = optional(number)
    machine_type      = optional(string)
    disk_size_gb      = optional(number)
    disk_type         = optional(string)
    image_type        = optional(string)
    preemptible       = optional(bool)
    auto_repair       = optional(bool)
    auto_upgrade      = optional(bool)
    labels            = optional(map(string))
    metadata          = optional(map(string))
    tags              = optional(list(string))
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })))
  }))
  default = {
    default-pool = {
      min_nodes    = 1
      max_nodes    = 3
      machine_type = "n1-standard-2"
    }
  }
}

variable "labels" {
  description = "Labels to apply to the cluster"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Network tags for nodes"
  type        = list(string)
  default     = []
}