# GKE Cluster Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "name" {
  description = "Name of the GKE cluster. If null, will use name_prefix with random suffix"
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Name prefix for the GKE cluster"
  type        = string
  default     = "gke-cluster"
}

variable "location" {
  description = "The location (region or zone) for the cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Network Configuration
variable "network_name" {
  description = "The name of the network to attach to the cluster"
  type        = string
  default     = null
}

variable "subnetwork_name" {
  description = "The name of the subnetwork to attach to the cluster"
  type        = string
  default     = null
}

variable "cluster_secondary_range_name" {
  description = "The name of the secondary range for pods"
  type        = string
  default     = null
}

variable "services_secondary_range_name" {
  description = "The name of the secondary range for services"
  type        = string
  default     = null
}

variable "cluster_ipv4_cidr" {
  description = "The IP address range for pods"
  type        = string
  default     = null
}

variable "services_ipv4_cidr" {
  description = "The IP address range for services"
  type        = string
  default     = null
}

# Cluster Version and Release Channel
variable "min_master_version" {
  description = "The minimum version of the master"
  type        = string
  default     = null
}

variable "release_channel" {
  description = "The release channel of the cluster"
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["UNSPECIFIED", "RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "Release channel must be UNSPECIFIED, RAPID, REGULAR, or STABLE"
  }
}

# Default Node Pool Configuration
variable "remove_default_node_pool" {
  description = "Remove the default node pool"
  type        = bool
  default     = false
}

variable "initial_node_count" {
  description = "Initial number of nodes in the default pool"
  type        = number
  default     = 3
}

variable "min_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 1
}

variable "max_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 10
}

variable "machine_type" {
  description = "Machine type for default node pool"
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "Disk size in GB for nodes"
  type        = number
  default     = 100
}

variable "disk_type" {
  description = "Disk type for nodes"
  type        = string
  default     = "pd-standard"
}

variable "preemptible" {
  description = "Use preemptible instances"
  type        = bool
  default     = false
}

variable "spot" {
  description = "Use spot instances"
  type        = bool
  default     = false
}

variable "auto_repair" {
  description = "Enable auto repair for nodes"
  type        = bool
  default     = true
}

variable "auto_upgrade" {
  description = "Enable auto upgrade for nodes"
  type        = bool
  default     = true
}

variable "enable_integrity_monitoring" {
  description = "Enable integrity monitoring"
  type        = bool
  default     = true
}

variable "enable_secure_boot" {
  description = "Enable secure boot"
  type        = bool
  default     = false
}

variable "node_tags" {
  description = "Network tags for nodes"
  type        = list(string)
  default     = []
}

variable "node_labels" {
  description = "Labels for nodes"
  type        = map(string)
  default     = {}
}

variable "node_metadata" {
  description = "Metadata for nodes"
  type        = map(string)
  default     = {}
}

variable "oauth_scopes" {
  description = "OAuth scopes for nodes"
  type        = list(string)
  default = [
    "https://www.googleapis.com/auth/cloud-platform"
  ]
}

variable "node_service_account" {
  description = "Service account for nodes"
  type        = string
  default     = null
}

variable "node_locations" {
  description = "List of zones where nodes should be located"
  type        = list(string)
  default     = []
}

# Additional Node Pools
variable "node_pools" {
  description = "List of additional node pools"
  type = list(object({
    name                        = string
    initial_node_count          = optional(number)
    min_count                   = optional(number)
    max_count                   = optional(number)
    machine_type                = optional(string)
    disk_size_gb                = optional(number)
    disk_type                   = optional(string)
    preemptible                 = optional(bool)
    spot                        = optional(bool)
    auto_repair                 = optional(bool)
    auto_upgrade                = optional(bool)
    enable_integrity_monitoring = optional(bool)
    enable_secure_boot          = optional(bool)
    image_type                  = optional(string)
    tags                        = optional(list(string))
    labels                      = optional(map(string))
    metadata                    = optional(map(string))
    oauth_scopes                = optional(list(string))
    service_account             = optional(string)
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })))
    node_locations     = optional(list(string))
    max_pods_per_node  = optional(number)
    enable_gcfs        = optional(bool)
    enable_gvnic       = optional(bool)
    sandbox_type       = optional(string)
    boot_disk_kms_key  = optional(string)
    accelerator_count  = optional(number)
    accelerator_type   = optional(string)
    gpu_partition_size = optional(string)
    gpu_sharing_config = optional(object({
      gpu_sharing_strategy       = string
      max_shared_clients_per_gpu = number
    }))
    gpu_driver_installation_config = optional(object({
      gpu_driver_version = string
    }))
  }))
  default = []
}

# Cluster Autoscaling
variable "enable_cluster_autoscaling" {
  description = "Enable cluster autoscaling"
  type        = bool
  default     = false
}

variable "cluster_autoscaling_resource_limits" {
  description = "Resource limits for cluster autoscaling"
  type = list(object({
    resource_type = string
    minimum       = number
    maximum       = number
  }))
  default = []
}

variable "auto_provisioning_defaults" {
  description = "Default values for auto-provisioned node pools"
  type = object({
    oauth_scopes      = optional(list(string))
    service_account   = optional(string)
    min_cpu_platform  = optional(string)
    disk_size         = optional(number)
    disk_type         = optional(string)
    image_type        = optional(string)
    boot_disk_kms_key = optional(string)
    shielded_instance_config = optional(object({
      enable_secure_boot          = optional(bool)
      enable_integrity_monitoring = optional(bool)
    }))
    management = optional(object({
      auto_repair  = optional(bool)
      auto_upgrade = optional(bool)
    }))
    upgrade_settings = optional(object({
      max_surge       = optional(number)
      max_unavailable = optional(number)
      strategy        = optional(string)
      blue_green_settings = optional(object({
        node_pool_soak_duration = optional(string)
        standard_rollout_policy = optional(object({
          batch_percentage    = optional(number)
          batch_node_count    = optional(number)
          batch_soak_duration = optional(string)
        }))
      }))
    }))
  })
  default = null
}

# Private Cluster Configuration
variable "enable_private_nodes" {
  description = "Enable private nodes"
  type        = bool
  default     = false
}

variable "enable_private_endpoint" {
  description = "Enable private endpoint"
  type        = bool
  default     = false
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for master"
  type        = string
  default     = "172.16.0.0/28"
}

variable "enable_master_global_access" {
  description = "Enable global access to master endpoint"
  type        = bool
  default     = false
}

variable "master_authorized_networks" {
  description = "List of authorized networks for master"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

# Maintenance Policy
variable "maintenance_start_time" {
  description = "Daily maintenance window start time"
  type        = string
  default     = null
}

variable "maintenance_recurrence" {
  description = "Recurring maintenance window"
  type = object({
    start_time = string
    end_time   = string
    recurrence = string
  })
  default = null
}

variable "maintenance_exclusions" {
  description = "List of maintenance exclusions"
  type = list(object({
    name       = string
    start_time = string
    end_time   = string
    scope      = optional(string)
  }))
  default = []
}

# Addons
variable "enable_http_load_balancing" {
  description = "Enable HTTP load balancing addon"
  type        = bool
  default     = true
}

variable "enable_horizontal_pod_autoscaling" {
  description = "Enable horizontal pod autoscaling addon"
  type        = bool
  default     = true
}

variable "enable_network_policy" {
  description = "Enable network policy addon"
  type        = bool
  default     = false
}

variable "network_policy_provider" {
  description = "Network policy provider"
  type        = string
  default     = "CALICO"
}

variable "enable_vertical_pod_autoscaling" {
  description = "Enable vertical pod autoscaling"
  type        = bool
  default     = false
}

variable "enable_dns_cache" {
  description = "Enable NodeLocal DNSCache"
  type        = bool
  default     = false
}

variable "enable_filestore_csi_driver" {
  description = "Enable Filestore CSI driver"
  type        = bool
  default     = false
}

variable "enable_gcs_fuse_csi_driver" {
  description = "Enable GCS Fuse CSI driver"
  type        = bool
  default     = false
}

variable "enable_backup_agent" {
  description = "Enable GKE backup agent"
  type        = bool
  default     = false
}

variable "enable_config_connector" {
  description = "Enable Config Connector"
  type        = bool
  default     = false
}

variable "enable_gce_persistent_disk_csi_driver" {
  description = "Enable GCE Persistent Disk CSI driver"
  type        = bool
  default     = true
}

variable "enable_kalm" {
  description = "Enable KALM"
  type        = bool
  default     = false
}

variable "enable_istio" {
  description = "Enable Istio"
  type        = bool
  default     = false
}

variable "istio_auth" {
  description = "Istio auth mode"
  type        = string
  default     = "AUTH_MUTUAL_TLS"
}

variable "enable_cloud_run" {
  description = "Enable Cloud Run"
  type        = bool
  default     = false
}

variable "cloud_run_load_balancer_type" {
  description = "Cloud Run load balancer type"
  type        = string
  default     = "LOAD_BALANCER_TYPE_EXTERNAL"
}

# Security
variable "enable_binary_authorization" {
  description = "Enable Binary Authorization"
  type        = bool
  default     = false
}

variable "binary_authorization_evaluation_mode" {
  description = "Binary Authorization evaluation mode"
  type        = string
  default     = "DISABLED"
}

variable "enable_workload_identity" {
  description = "Enable Workload Identity"
  type        = bool
  default     = false
}

variable "enable_shielded_nodes" {
  description = "Enable Shielded Nodes"
  type        = bool
  default     = false
}

variable "enable_confidential_nodes" {
  description = "Enable Confidential Nodes"
  type        = bool
  default     = false
}

variable "security_group" {
  description = "Security group for RBAC"
  type        = string
  default     = null
}

variable "database_encryption_key_name" {
  description = "KMS key for database encryption"
  type        = string
  default     = null
}

# Features
variable "enable_kubernetes_alpha" {
  description = "Enable Kubernetes Alpha features"
  type        = bool
  default     = false
}

variable "enable_tpu" {
  description = "Enable TPU support"
  type        = bool
  default     = false
}

variable "enable_legacy_abac" {
  description = "Enable legacy ABAC"
  type        = bool
  default     = false
}

variable "enable_autopilot" {
  description = "Enable Autopilot mode"
  type        = bool
  default     = false
}

variable "enable_intranode_visibility" {
  description = "Enable intra-node visibility"
  type        = bool
  default     = false
}

variable "enable_l4_ilb_subsetting" {
  description = "Enable L4 ILB subsetting"
  type        = bool
  default     = false
}

variable "enable_cost_management" {
  description = "Enable cost management"
  type        = bool
  default     = false
}

variable "enable_gateway_api" {
  description = "Enable Gateway API"
  type        = bool
  default     = false
}

variable "gateway_api_channel" {
  description = "Gateway API channel"
  type        = string
  default     = "CHANNEL_STANDARD"
}

variable "enable_service_external_ips" {
  description = "Enable Service External IPs"
  type        = bool
  default     = null
}

variable "enable_mesh_certificates" {
  description = "Enable mesh certificates"
  type        = bool
  default     = false
}

variable "disable_default_snat" {
  description = "Disable default SNAT"
  type        = bool
  default     = false
}

variable "default_max_pods_per_node" {
  description = "Default maximum pods per node"
  type        = number
  default     = null
}

variable "datapath_provider" {
  description = "Datapath provider (LEGACY_DATAPATH or ADVANCED_DATAPATH)"
  type        = string
  default     = null
}

# DNS Configuration
variable "cluster_dns_provider" {
  description = "Cluster DNS provider"
  type        = string
  default     = null
}

variable "cluster_dns_scope" {
  description = "Cluster DNS scope"
  type        = string
  default     = null
}

variable "cluster_dns_domain" {
  description = "Cluster DNS domain"
  type        = string
  default     = null
}

# Fleet
variable "fleet_project" {
  description = "Fleet host project"
  type        = string
  default     = null
}

# Monitoring and Logging
variable "logging_service" {
  description = "Logging service"
  type        = string
  default     = "logging.googleapis.com/kubernetes"
}

variable "monitoring_service" {
  description = "Monitoring service"
  type        = string
  default     = "monitoring.googleapis.com/kubernetes"
}

variable "enable_monitoring_config" {
  description = "Enable monitoring config"
  type        = bool
  default     = false
}

variable "monitoring_enable_components" {
  description = "Components to enable for monitoring"
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS", "WORKLOADS"]
}

variable "enable_managed_prometheus" {
  description = "Enable managed Prometheus"
  type        = bool
  default     = false
}

variable "enable_advanced_datapath_observability" {
  description = "Enable advanced datapath observability"
  type        = bool
  default     = false
}

variable "advanced_datapath_observability_mode" {
  description = "Advanced datapath observability mode"
  type        = string
  default     = null
}

variable "enable_logging_config" {
  description = "Enable logging config"
  type        = bool
  default     = false
}

variable "logging_enable_components" {
  description = "Components to enable for logging"
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS", "WORKLOADS"]
}

# Resource Usage Export
variable "resource_usage_export_dataset_id" {
  description = "BigQuery dataset ID for resource usage export"
  type        = string
  default     = null
}

variable "enable_network_egress_metering" {
  description = "Enable network egress metering"
  type        = bool
  default     = false
}

variable "enable_resource_consumption_metering" {
  description = "Enable resource consumption metering"
  type        = bool
  default     = false
}

# Notifications
variable "notification_config_topic" {
  description = "Pub/Sub topic for notifications"
  type        = string
  default     = null
}

variable "notification_filter_event_types" {
  description = "Event types for notification filter"
  type        = list(string)
  default     = []
}

# Security Posture
variable "security_posture_mode" {
  description = "Security posture mode"
  type        = string
  default     = null
}

variable "vulnerability_mode" {
  description = "Vulnerability mode"
  type        = string
  default     = null
}

# Labels
variable "cluster_labels" {
  description = "Labels for the cluster"
  type        = map(string)
  default     = {}
}

# Timeouts
variable "cluster_create_timeout" {
  description = "Timeout for cluster creation"
  type        = string
  default     = "45m"
}

variable "cluster_update_timeout" {
  description = "Timeout for cluster updates"
  type        = string
  default     = "45m"
}

variable "cluster_delete_timeout" {
  description = "Timeout for cluster deletion"
  type        = string
  default     = "45m"
}

# Lifecycle
variable "ignore_changes_on_update" {
  description = "List of fields to ignore on update"
  type        = list(string)
  default     = []
}