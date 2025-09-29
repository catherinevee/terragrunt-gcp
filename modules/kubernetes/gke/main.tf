# Google Kubernetes Engine (GKE) Cluster Module
# Manages GKE clusters with comprehensive configuration options

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

locals {
  # Cluster name with optional random suffix
  cluster_name = var.name != null ? var.name : "${var.name_prefix}-${random_id.cluster_suffix[0].hex}"

  # Network configuration
  network_name    = var.network_name != null ? var.network_name : "default"
  subnetwork_name = var.subnetwork_name != null ? var.subnetwork_name : "default"

  # Master authorized networks with defaults
  master_authorized_networks = concat(
    var.master_authorized_networks,
    var.enable_private_endpoint && !var.enable_private_nodes ? [] : [{
      cidr_block   = "0.0.0.0/0"
      display_name = "all-for-testing"
    }]
  )

  # Node pool configurations
  node_pools = { for np in var.node_pools : np.name => np }

  # Default node pool configuration
  default_node_pool = var.remove_default_node_pool ? {} : {
    name                        = "default-pool"
    initial_node_count          = var.initial_node_count
    min_count                   = var.min_count
    max_count                   = var.max_count
    machine_type                = var.machine_type
    disk_size_gb                = var.disk_size_gb
    disk_type                   = var.disk_type
    preemptible                 = var.preemptible
    spot                        = var.spot
    auto_repair                 = var.auto_repair
    auto_upgrade                = var.auto_upgrade
    enable_integrity_monitoring = var.enable_integrity_monitoring
    enable_secure_boot          = var.enable_secure_boot
    tags                        = var.node_tags
    labels                      = var.node_labels
    metadata                    = var.node_metadata
    oauth_scopes                = var.oauth_scopes
    service_account             = var.node_service_account
  }

  # Labels with defaults
  labels = merge(
    var.cluster_labels,
    {
      managed_by  = "terraform"
      module      = "gke"
      environment = var.environment
      created_at  = formatdate("YYYY-MM-DD", timestamp())
    }
  )

  # Cluster autoscaling
  cluster_autoscaling = var.enable_cluster_autoscaling ? [{
    enabled         = true
    resource_limits = var.cluster_autoscaling_resource_limits
    auto_provisioning_defaults = var.auto_provisioning_defaults != null ? [{
      oauth_scopes = lookup(var.auto_provisioning_defaults, "oauth_scopes", [
        "https://www.googleapis.com/auth/cloud-platform"
      ])
      service_account          = lookup(var.auto_provisioning_defaults, "service_account", null)
      min_cpu_platform         = lookup(var.auto_provisioning_defaults, "min_cpu_platform", null)
      disk_size                = lookup(var.auto_provisioning_defaults, "disk_size", 100)
      disk_type                = lookup(var.auto_provisioning_defaults, "disk_type", "pd-standard")
      image_type               = lookup(var.auto_provisioning_defaults, "image_type", "COS_CONTAINERD")
      boot_disk_kms_key        = lookup(var.auto_provisioning_defaults, "boot_disk_kms_key", null)
      shielded_instance_config = lookup(var.auto_provisioning_defaults, "shielded_instance_config", null)
      management               = lookup(var.auto_provisioning_defaults, "management", null)
      upgrade_settings         = lookup(var.auto_provisioning_defaults, "upgrade_settings", null)
    }] : []
  }] : []

  # Workload Identity Config
  workload_identity_config = var.enable_workload_identity ? [{
    workload_pool = "${var.project_id}.svc.id.goog"
  }] : []
}

# Random suffix for cluster naming
resource "random_id" "cluster_suffix" {
  count       = var.name == null ? 1 : 0
  byte_length = 4

  keepers = {
    project_id = var.project_id
    location   = var.location
  }
}

# GKE Cluster
resource "google_container_cluster" "cluster" {
  provider = google-beta

  project  = var.project_id
  name     = local.cluster_name
  location = var.location

  # Network configuration
  network    = local.network_name
  subnetwork = local.subnetwork_name

  # Cluster configuration
  min_master_version = var.min_master_version
  release_channel {
    channel = var.release_channel
  }

  # Default node pool
  remove_default_node_pool = var.remove_default_node_pool
  initial_node_count       = var.remove_default_node_pool ? 1 : var.initial_node_count

  dynamic "node_pool" {
    for_each = var.remove_default_node_pool ? {} : { default = local.default_node_pool }
    content {
      name               = node_pool.value.name
      initial_node_count = node_pool.value.initial_node_count

      dynamic "autoscaling" {
        for_each = node_pool.value.min_count != null && node_pool.value.max_count != null ? [1] : []
        content {
          min_node_count = node_pool.value.min_count
          max_node_count = node_pool.value.max_count
        }
      }

      node_config {
        machine_type    = node_pool.value.machine_type
        disk_size_gb    = node_pool.value.disk_size_gb
        disk_type       = node_pool.value.disk_type
        preemptible     = node_pool.value.preemptible
        spot            = node_pool.value.spot
        tags            = node_pool.value.tags
        labels          = node_pool.value.labels
        metadata        = node_pool.value.metadata
        oauth_scopes    = node_pool.value.oauth_scopes
        service_account = node_pool.value.service_account
        image_type      = lookup(node_pool.value, "image_type", "COS_CONTAINERD")

        dynamic "shielded_instance_config" {
          for_each = node_pool.value.enable_integrity_monitoring || node_pool.value.enable_secure_boot ? [1] : []
          content {
            enable_integrity_monitoring = node_pool.value.enable_integrity_monitoring
            enable_secure_boot          = node_pool.value.enable_secure_boot
          }
        }

        dynamic "workload_metadata_config" {
          for_each = var.enable_workload_identity ? [1] : []
          content {
            mode = "GKE_METADATA"
          }
        }
      }

      management {
        auto_repair  = node_pool.value.auto_repair
        auto_upgrade = node_pool.value.auto_upgrade
      }
    }
  }

  # Cluster autoscaling
  dynamic "cluster_autoscaling" {
    for_each = local.cluster_autoscaling
    content {
      enabled = cluster_autoscaling.value.enabled

      dynamic "resource_limits" {
        for_each = cluster_autoscaling.value.resource_limits
        content {
          resource_type = resource_limits.value.resource_type
          minimum       = resource_limits.value.minimum
          maximum       = resource_limits.value.maximum
        }
      }

      dynamic "auto_provisioning_defaults" {
        for_each = cluster_autoscaling.value.auto_provisioning_defaults
        content {
          oauth_scopes      = auto_provisioning_defaults.value.oauth_scopes
          service_account   = auto_provisioning_defaults.value.service_account
          min_cpu_platform  = auto_provisioning_defaults.value.min_cpu_platform
          disk_size         = auto_provisioning_defaults.value.disk_size
          disk_type         = auto_provisioning_defaults.value.disk_type
          image_type        = auto_provisioning_defaults.value.image_type
          boot_disk_kms_key = auto_provisioning_defaults.value.boot_disk_kms_key

          dynamic "shielded_instance_config" {
            for_each = auto_provisioning_defaults.value.shielded_instance_config != null ? [auto_provisioning_defaults.value.shielded_instance_config] : []
            content {
              enable_secure_boot          = lookup(shielded_instance_config.value, "enable_secure_boot", false)
              enable_integrity_monitoring = lookup(shielded_instance_config.value, "enable_integrity_monitoring", true)
            }
          }

          dynamic "management" {
            for_each = auto_provisioning_defaults.value.management != null ? [auto_provisioning_defaults.value.management] : []
            content {
              auto_repair  = lookup(management.value, "auto_repair", true)
              auto_upgrade = lookup(management.value, "auto_upgrade", true)
            }
          }

          dynamic "upgrade_settings" {
            for_each = auto_provisioning_defaults.value.upgrade_settings != null ? [auto_provisioning_defaults.value.upgrade_settings] : []
            content {
              max_surge       = lookup(upgrade_settings.value, "max_surge", 1)
              max_unavailable = lookup(upgrade_settings.value, "max_unavailable", 0)
              strategy        = lookup(upgrade_settings.value, "strategy", "SURGE")

              dynamic "blue_green_settings" {
                for_each = lookup(upgrade_settings.value, "blue_green_settings", null) != null ? [upgrade_settings.value.blue_green_settings] : []
                content {
                  node_pool_soak_duration = lookup(blue_green_settings.value, "node_pool_soak_duration", null)

                  dynamic "standard_rollout_policy" {
                    for_each = lookup(blue_green_settings.value, "standard_rollout_policy", null) != null ? [blue_green_settings.value.standard_rollout_policy] : []
                    content {
                      batch_percentage    = lookup(standard_rollout_policy.value, "batch_percentage", null)
                      batch_node_count    = lookup(standard_rollout_policy.value, "batch_node_count", null)
                      batch_soak_duration = lookup(standard_rollout_policy.value, "batch_soak_duration", null)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  # Vertical pod autoscaling
  vertical_pod_autoscaling {
    enabled = var.enable_vertical_pod_autoscaling
  }

  # Binary authorization
  dynamic "binary_authorization" {
    for_each = var.enable_binary_authorization ? [1] : []
    content {
      evaluation_mode = var.binary_authorization_evaluation_mode
    }
  }

  # Network policy
  network_policy {
    enabled  = var.enable_network_policy
    provider = var.enable_network_policy ? var.network_policy_provider : null
  }

  # IP allocation policy
  ip_allocation_policy {
    cluster_secondary_range_name  = var.cluster_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
    cluster_ipv4_cidr_block       = var.cluster_ipv4_cidr
    services_ipv4_cidr_block      = var.services_ipv4_cidr
  }

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = var.enable_private_nodes
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block

    dynamic "master_global_access_config" {
      for_each = var.enable_master_global_access ? [1] : []
      content {
        enabled = true
      }
    }
  }

  # Master authorized networks
  dynamic "master_authorized_networks_config" {
    for_each = length(local.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = local.master_authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  # Maintenance policy
  maintenance_policy {
    dynamic "daily_maintenance_window" {
      for_each = var.maintenance_start_time != null ? [1] : []
      content {
        start_time = var.maintenance_start_time
      }
    }

    dynamic "recurring_window" {
      for_each = var.maintenance_recurrence != null ? [1] : []
      content {
        start_time = var.maintenance_recurrence.start_time
        end_time   = var.maintenance_recurrence.end_time
        recurrence = var.maintenance_recurrence.recurrence
      }
    }

    dynamic "maintenance_exclusion" {
      for_each = var.maintenance_exclusions
      content {
        exclusion_name = maintenance_exclusion.value.name
        start_time     = maintenance_exclusion.value.start_time
        end_time       = maintenance_exclusion.value.end_time

        dynamic "exclusion_options" {
          for_each = lookup(maintenance_exclusion.value, "scope", null) != null ? [1] : []
          content {
            scope = maintenance_exclusion.value.scope
          }
        }
      }
    }
  }

  # Addons configuration
  addons_config {
    http_load_balancing {
      disabled = !var.enable_http_load_balancing
    }
    horizontal_pod_autoscaling {
      disabled = !var.enable_horizontal_pod_autoscaling
    }
    network_policy_config {
      disabled = !var.enable_network_policy
    }
    dns_cache_config {
      enabled = var.enable_dns_cache
    }
    gcp_filestore_csi_driver_config {
      enabled = var.enable_filestore_csi_driver
    }
    gcs_fuse_csi_driver_config {
      enabled = var.enable_gcs_fuse_csi_driver
    }
    gke_backup_agent_config {
      enabled = var.enable_backup_agent
    }
    config_connector_config {
      enabled = var.enable_config_connector
    }
    gce_persistent_disk_csi_driver_config {
      enabled = var.enable_gce_persistent_disk_csi_driver
    }
    kalm_config {
      enabled = var.enable_kalm
    }
    istio_config {
      disabled = !var.enable_istio
      auth     = var.istio_auth
    }
    cloudrun_config {
      disabled           = !var.enable_cloud_run
      load_balancer_type = var.cloud_run_load_balancer_type
    }
  }

  # Workload Identity
  dynamic "workload_identity_config" {
    for_each = local.workload_identity_config
    content {
      workload_pool = workload_identity_config.value.workload_pool
    }
  }

  # Database encryption
  dynamic "database_encryption" {
    for_each = var.database_encryption_key_name != null ? [1] : []
    content {
      state    = "ENCRYPTED"
      key_name = var.database_encryption_key_name
    }
  }

  # Notification config
  dynamic "notification_config" {
    for_each = var.notification_config_topic != null ? [1] : []
    content {
      pubsub {
        enabled = true
        topic   = var.notification_config_topic
        filter {
          event_type = var.notification_filter_event_types
        }
      }
    }
  }

  # Confidential nodes
  dynamic "confidential_nodes" {
    for_each = var.enable_confidential_nodes ? [1] : []
    content {
      enabled = true
    }
  }

  # Cost management
  dynamic "cost_management_config" {
    for_each = var.enable_cost_management ? [1] : []
    content {
      enabled = true
    }
  }

  # Resource usage export
  dynamic "resource_usage_export_config" {
    for_each = var.resource_usage_export_dataset_id != null ? [1] : []
    content {
      enable_network_egress_metering       = var.enable_network_egress_metering
      enable_resource_consumption_metering = var.enable_resource_consumption_metering

      bigquery_destination {
        dataset_id = var.resource_usage_export_dataset_id
      }
    }
  }

  # Authenticator groups
  dynamic "authenticator_groups_config" {
    for_each = var.security_group != null ? [1] : []
    content {
      security_group = var.security_group
    }
  }

  # DNS config
  dynamic "dns_config" {
    for_each = var.cluster_dns_provider != null || var.cluster_dns_scope != null || var.cluster_dns_domain != null ? [1] : []
    content {
      cluster_dns        = var.cluster_dns_provider
      cluster_dns_scope  = var.cluster_dns_scope
      cluster_dns_domain = var.cluster_dns_domain
    }
  }

  # Gateway API
  dynamic "gateway_api_config" {
    for_each = var.enable_gateway_api ? [1] : []
    content {
      channel = var.gateway_api_channel
    }
  }

  # Fleet
  dynamic "fleet" {
    for_each = var.fleet_project != null ? [1] : []
    content {
      project = var.fleet_project
    }
  }

  # Service External IPs
  dynamic "service_external_ips_config" {
    for_each = var.enable_service_external_ips != null ? [1] : []
    content {
      enabled = var.enable_service_external_ips
    }
  }

  # Mesh certificates
  dynamic "mesh_certificates" {
    for_each = var.enable_mesh_certificates ? [1] : []
    content {
      enable_certificates = true
    }
  }

  # Security posture
  dynamic "security_posture_config" {
    for_each = var.security_posture_mode != null || var.vulnerability_mode != null ? [1] : []
    content {
      mode               = var.security_posture_mode
      vulnerability_mode = var.vulnerability_mode
    }
  }

  # Enable features
  enable_kubernetes_alpha     = var.enable_kubernetes_alpha
  enable_tpu                  = var.enable_tpu
  enable_legacy_abac          = var.enable_legacy_abac
  enable_shielded_nodes       = var.enable_shielded_nodes
  enable_autopilot            = var.enable_autopilot
  enable_intranode_visibility = var.enable_intranode_visibility
  enable_l4_ilb_subsetting    = var.enable_l4_ilb_subsetting

  # Logging and monitoring
  logging_service    = var.logging_service
  monitoring_service = var.monitoring_service

  dynamic "monitoring_config" {
    for_each = var.enable_monitoring_config ? [1] : []
    content {
      enable_components = var.monitoring_enable_components

      dynamic "managed_prometheus" {
        for_each = var.enable_managed_prometheus ? [1] : []
        content {
          enabled = true
        }
      }

      dynamic "advanced_datapath_observability_config" {
        for_each = var.enable_advanced_datapath_observability ? [1] : []
        content {
          enable_metrics = var.advanced_datapath_observability_mode == "INTERNAL_VPC" || var.advanced_datapath_observability_mode == "EXTERNAL_LB"
          relay_mode     = var.advanced_datapath_observability_mode
        }
      }
    }
  }

  dynamic "logging_config" {
    for_each = var.enable_logging_config ? [1] : []
    content {
      enable_components = var.logging_enable_components
    }
  }

  # Default SNAT
  dynamic "default_snat_status" {
    for_each = var.disable_default_snat ? [1] : []
    content {
      disabled = true
    }
  }

  # Resource labels
  resource_labels = local.labels

  # Node locations
  node_locations = var.node_locations

  # Default max pods per node
  default_max_pods_per_node = var.default_max_pods_per_node

  # Enable dataplane V2
  datapath_provider = var.datapath_provider

  # TPU configuration
  dynamic "enable_k8s_beta_apis" {
    for_each = var.enable_tpu ? [1] : []
    content {
      enabled_apis = ["compute.googleapis.com/v1beta1"]
    }
  }

  timeouts {
    create = var.cluster_create_timeout
    update = var.cluster_update_timeout
    delete = var.cluster_delete_timeout
  }

  lifecycle {
    # ignore_changes must be static, not variable
    ignore_changes = []
  }
}