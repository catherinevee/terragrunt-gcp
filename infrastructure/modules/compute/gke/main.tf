# GKE Cluster Module

resource "google_container_cluster" "cluster" {
  name     = var.name
  project  = var.project_id
  location = var.regional ? var.region : var.zone
  
  # Network configuration
  network    = var.network
  subnetwork = var.subnetwork
  
  # Cluster configuration
  min_master_version = var.kubernetes_version
  initial_node_count = var.regional ? null : 1
  
  remove_default_node_pool = true
  
  # Network policy
  network_policy {
    enabled  = var.network_policy_enabled
    provider = var.network_policy_enabled ? "CALICO" : "PROVIDER_UNSPECIFIED"
  }
  
  # IP allocation policy for VPC-native cluster
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }
  
  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = var.enable_private_nodes
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block = var.master_ipv4_cidr_block
    
    master_global_access_config {
      enabled = var.master_global_access
    }
  }
  
  # Master authorized networks
  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }
  
  # Workload Identity
  workload_identity_config {
    workload_pool = var.enable_workload_identity ? "${var.project_id}.svc.id.goog" : null
  }
  
  # Binary Authorization
  dynamic "binary_authorization" {
    for_each = var.enable_binary_authorization ? [1] : []
    content {
      evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
    }
  }
  
  # Shielded nodes
  enable_shielded_nodes = var.enable_shielded_nodes
  
  # Maintenance policy
  maintenance_policy {
    daily_maintenance_window {
      start_time = var.maintenance_start_time
    }
  }
  
  # Cluster autoscaling
  cluster_autoscaling {
    enabled = var.enable_cluster_autoscaling
    
    dynamic "resource_limits" {
      for_each = var.enable_cluster_autoscaling ? var.cluster_autoscaling_resource_limits : []
      content {
        resource_type = resource_limits.value.resource_type
        minimum       = resource_limits.value.minimum
        maximum       = resource_limits.value.maximum
      }
    }
    
    auto_provisioning_defaults {
      service_account = var.service_account
      oauth_scopes    = var.oauth_scopes
      
      management {
        auto_repair  = true
        auto_upgrade = var.auto_upgrade
      }
      
      shielded_instance_config {
        enable_secure_boot          = var.enable_secure_boot
        enable_integrity_monitoring = var.enable_integrity_monitoring
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
      disabled = !var.network_policy_enabled
    }
    
    gce_persistent_disk_csi_driver_config {
      enabled = var.enable_gce_pd_csi_driver
    }
    
    dns_cache_config {
      enabled = var.enable_dns_cache
    }
  }
  
  # Logging and monitoring
  logging_config {
    enable_components = var.logging_enabled_components
  }
  
  monitoring_config {
    enable_components = var.monitoring_enabled_components
    
    managed_prometheus {
      enabled = var.enable_managed_prometheus
    }
  }
  
  # Resource labels
  resource_labels = var.labels
  
  lifecycle {
    ignore_changes = [initial_node_count]
  }
}

# Node Pools
resource "google_container_node_pool" "node_pools" {
  for_each = var.node_pools
  
  name     = each.key
  project  = var.project_id
  location = google_container_cluster.cluster.location
  cluster  = google_container_cluster.cluster.name
  
  initial_node_count = lookup(each.value, "initial_node_count", 1)
  
  # Autoscaling configuration
  autoscaling {
    min_node_count = lookup(each.value, "min_nodes", 1)
    max_node_count = lookup(each.value, "max_nodes", 3)
  }
  
  # Node management
  management {
    auto_repair  = lookup(each.value, "auto_repair", true)
    auto_upgrade = lookup(each.value, "auto_upgrade", var.auto_upgrade)
  }
  
  # Node configuration
  node_config {
    preemptible     = lookup(each.value, "preemptible", false)
    machine_type    = lookup(each.value, "machine_type", "n1-standard-2")
    disk_size_gb    = lookup(each.value, "disk_size_gb", 100)
    disk_type       = lookup(each.value, "disk_type", "pd-standard")
    image_type      = lookup(each.value, "image_type", "COS_CONTAINERD")
    
    service_account = var.service_account
    oauth_scopes    = var.oauth_scopes
    
    # Workload Identity
    dynamic "workload_metadata_config" {
      for_each = var.enable_workload_identity ? [1] : []
      content {
        mode = "GKE_METADATA"
      }
    }
    
    # Shielded instance configuration
    shielded_instance_config {
      enable_secure_boot          = var.enable_secure_boot
      enable_integrity_monitoring = var.enable_integrity_monitoring
    }
    
    # Labels
    labels = merge(
      var.labels,
      lookup(each.value, "labels", {})
    )
    
    # Metadata
    metadata = merge(
      {
        disable-legacy-endpoints = "true"
      },
      lookup(each.value, "metadata", {})
    )
    
    # Tags
    tags = concat(
      var.tags,
      lookup(each.value, "tags", [])
    )
    
    # Taints
    dynamic "taint" {
      for_each = lookup(each.value, "taints", [])
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }
  }
  
  lifecycle {
    ignore_changes = [initial_node_count]
  }
}