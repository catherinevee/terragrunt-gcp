# Staging GKE Cluster Configuration - US Central 1
# This configuration creates a cost-optimized GKE cluster for staging

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("env.hcl")
}

include "region" {
  path = find_in_parent_folders("region.hcl")
}

terraform {
  source = "../../../../../../modules/kubernetes/gke-cluster"
}

dependency "vpc" {
  config_path = "../../networking/vpc"
  mock_outputs = {
    network_self_link = "projects/mock-project/global/networks/mock-network"
    subnet_self_links = {
      "private" = "projects/mock-project/regions/us-central1/subnetworks/mock-subnet"
    }
    network_name = "mock-network"
  }
}

inputs = {
  project_id = local.project_id
  region     = "us-central1"

  # Staging cluster configuration
  primary_cluster = {
    name        = "staging-usc1-cluster"
    description = "Staging GKE cluster for testing and validation"
    location    = "us-central1-a"  # Zonal for cost savings

    # Cluster configuration optimized for staging
    remove_default_node_pool = true
    initial_node_count      = 1

    # Network configuration
    network    = dependency.vpc.outputs.network_self_link
    subnetwork = dependency.vpc.outputs.subnet_self_links["private"]

    # Master configuration
    master_auth = {
      client_certificate_config = {
        issue_client_certificate = false
      }
    }

    # Private cluster configuration (simplified)
    private_cluster_config = {
      enable_private_nodes    = true
      enable_private_endpoint = false  # Public endpoint for easier access
      master_ipv4_cidr_block = "172.16.0.0/28"

      master_global_access_config = {
        enabled = false  # Disabled for cost optimization
      }
    }

    # IP allocation for secondary ranges
    ip_allocation_policy = {
      cluster_secondary_range_name  = "pods"
      services_secondary_range_name = "services"
    }

    # Basic network policy
    network_policy = {
      enabled  = false  # Disabled for staging simplicity
      provider = "CALICO"
    }

    # Addons configuration (minimal for staging)
    addons_config = {
      http_load_balancing = {
        disabled = false
      }
      horizontal_pod_autoscaling = {
        disabled = false
      }
      network_policy_config = {
        disabled = true  # Disabled for staging
      }
      gcp_filestore_csi_driver_config = {
        enabled = false  # Disabled for cost optimization
      }
      gcs_fuse_csi_driver_config = {
        enabled = false  # Disabled for cost optimization
      }
      gke_backup_agent_config = {
        enabled = false  # Disabled for staging
      }
      config_connector_config = {
        enabled = false  # Disabled for staging
      }
    }

    # Cluster features (minimal for staging)
    enable_autopilot                    = false
    enable_shielded_nodes              = false  # Disabled for cost optimization
    enable_binary_authorization        = local.security_config.enable_binary_authorization
    enable_intranode_visibility        = false  # Disabled for cost optimization
    enable_workload_identity           = local.security_config.enable_workload_identity

    # Resource usage metering (disabled for cost)
    resource_usage_export_config = {
      enable_network_egress_metering = false
      enable_resource_consumption_metering = false
    }

    # Release channel
    release_channel = {
      channel = "REGULAR"  # Regular channel for staging
    }

    # Workload identity (basic setup)
    workload_identity_config = {
      workload_pool = "${local.project_id}.svc.id.goog"
    }

    # Maintenance policy (flexible for staging)
    maintenance_policy = {
      recurring_window = {
        start_time = "2024-01-01T02:00:00Z"
        end_time   = "2024-01-01T06:00:00Z"
        recurrence = "FREQ=WEEKLY;BYDAY=SU"  # Sunday maintenance
      }
    }

    # Database encryption (disabled for staging)
    database_encryption = {
      state    = "DECRYPTED"
      key_name = ""
    }

    # Logging and monitoring (basic)
    logging_config = {
      enable_components = [
        "SYSTEM_COMPONENTS",
        "WORKLOADS"
      ]
    }

    monitoring_config = {
      enable_components = [
        "SYSTEM_COMPONENTS"
      ]

      managed_prometheus = {
        enabled = false  # Disabled for cost optimization
      }
    }

    # Notification configuration (basic)
    notification_config = {
      pubsub = {
        enabled = false  # Disabled for staging
        topic   = ""
        filter  = ""
      }
    }

    # Pod security policy (disabled for staging)
    pod_security_policy_config = {
      enabled = false
    }

    # Vertical Pod Autoscaling
    vertical_pod_autoscaling = {
      enabled = true
    }

    # Cluster autoscaling (basic)
    cluster_autoscaling = {
      enabled = false  # Disabled for predictable costs
    }

    # Security configuration (basic)
    authenticator_groups_config = {
      security_group = ""  # No security group for staging
    }

    # Cost management
    cost_management_config = {
      enabled = true
    }

    # Gateway API (disabled for staging)
    gateway_api_config = {
      channel = "CHANNEL_DISABLED"
    }

    # Fleet configuration (disabled for staging)
    fleet = {
      project = ""
    }
  }

  # Node pools for staging
  node_pools = {
    # Primary node pool with preemptible instances
    primary_pool = {
      name         = "staging-primary-pool"
      location     = "us-central1-a"
      node_count   = local.gke_config.min_nodes

      # Node configuration (cost-optimized)
      node_config = {
        machine_type = local.gke_config.machine_type
        disk_size_gb = local.gke_config.disk_size_gb
        disk_type    = "pd-standard"  # Standard disk for cost savings

        # Service account
        service_account = "default"  # Use default for staging

        oauth_scopes = [
          "https://www.googleapis.com/auth/cloud-platform"
        ]

        # Labels
        labels = {
          environment = "staging"
          region = "usc1"
          node_pool = "primary"
          workload_type = "general"
          tier = "staging"
          cost_optimized = "true"
        }

        # No taints for staging simplicity
        taint = []

        # Metadata
        metadata = {
          disable-legacy-endpoints = "true"
          enable-oslogin = "false"  # Disabled for easier debugging
        }

        # Tags for firewall rules
        tags = ["gke-node", "staging-cluster", "internal", "ssh-allowed"]

        # Image type
        image_type = "COS_CONTAINERD"

        # Local SSD (disabled for cost savings)
        local_ssd_count = 0

        # GPU configuration (disabled for staging)
        guest_accelerator = []

        # Preemptible instances for cost savings
        preemptible = local.gke_config.preemptible
        spot        = false

        # Shielded instance config (disabled for cost)
        shielded_instance_config = {
          enable_secure_boot          = false
          enable_integrity_monitoring = false
        }

        # Workload metadata config
        workload_metadata_config = {
          mode = "GKE_METADATA"
        }

        # Advanced machine features (disabled for cost)
        advanced_machine_features = {
          threads_per_core = 1
        }

        # Confidential nodes (disabled for staging)
        confidential_nodes = {
          enabled = false
        }

        # Kubelet config (basic)
        kubelet_config = {
          cpu_manager_policy   = "none"
          cpu_cfs_quota_enabled = false
          pod_pids_limit       = 1024
        }

        # Linux node config (basic)
        linux_node_config = {
          sysctls = {}
          cgroup_mode = "CGROUP_MODE_V1"
        }

        # Resource labels
        resource_labels = {
          node_pool = "primary"
          cluster = "staging-usc1-cluster"
          environment = "staging"
          managed_by = "terragrunt"
        }
      }

      # Autoscaling configuration
      autoscaling = {
        min_node_count = local.gke_config.min_nodes
        max_node_count = local.gke_config.max_nodes
      }

      # Management configuration
      management = {
        auto_repair  = local.gke_config.auto_repair
        auto_upgrade = local.gke_config.auto_upgrade
      }

      # Upgrade settings (basic)
      upgrade_settings = {
        strategy        = "SURGE"
        max_surge       = 1
        max_unavailable = 0

        blue_green_settings = {
          node_pool_soak_duration = "1800s"  # 30 minutes

          standard_rollout_policy = {
            batch_percentage    = 100
            batch_soak_duration = "600s"  # 10 minutes
          }
        }
      }

      # Network configuration
      network_config = {
        create_pod_range     = false
        pod_range           = "pods"
        pod_ipv4_cidr_block = "10.10.64.0/18"

        enable_private_nodes = true
      }

      # Placement policy (basic)
      placement_policy = {
        type         = "BALANCED"
        tpu_topology = ""
      }
    }

    # Development node pool for experimental workloads
    dev_pool = {
      name         = "staging-dev-pool"
      location     = "us-central1-a"
      node_count   = 1

      node_config = {
        machine_type = "e2-medium"  # Smaller instances for dev workloads
        disk_size_gb = 30
        disk_type    = "pd-standard"

        service_account = "default"

        oauth_scopes = [
          "https://www.googleapis.com/auth/cloud-platform"
        ]

        labels = {
          environment = "staging"
          region = "usc1"
          node_pool = "dev"
          workload_type = "development"
          tier = "staging"
          cost_optimized = "true"
        }

        taint = [
          {
            key    = "dev-workload"
            value  = "true"
            effect = "NO_SCHEDULE"
          }
        ]

        metadata = {
          disable-legacy-endpoints = "true"
          enable-oslogin = "false"
        }

        tags = ["gke-node", "staging-cluster", "dev-workload", "ssh-allowed"]

        image_type = "COS_CONTAINERD"
        preemptible = true  # Always preemptible for dev pool

        shielded_instance_config = {
          enable_secure_boot          = false
          enable_integrity_monitoring = false
        }

        workload_metadata_config = {
          mode = "GKE_METADATA"
        }
      }

      autoscaling = {
        min_node_count = 0  # Can scale to zero
        max_node_count = 3
      }

      management = {
        auto_repair  = true
        auto_upgrade = true
      }

      upgrade_settings = {
        strategy        = "SURGE"
        max_surge       = 1
        max_unavailable = 1
      }
    }
  }

  # Integration with existing resources
  network_self_link = dependency.vpc.outputs.network_self_link
  subnet_self_links = dependency.vpc.outputs.subnet_self_links

  # Tags for resource organization
  tags = {
    Environment = "staging"
    Region = "us-central1"
    RegionShort = "usc1"
    Team = "platform"
    Component = "kubernetes"
    CostCenter = "staging"
    Purpose = "testing"
    AutoShutdown = "enabled"
    CostOptimized = "true"
    Preemptible = "enabled"
    SecurityLevel = "basic"
    MonitoringLevel = "basic"
  }
}