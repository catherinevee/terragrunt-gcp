# Production GKE Cluster Configuration - US East 1 (Disaster Recovery)
# This configuration creates a disaster recovery GKE cluster

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
      "private_web" = "projects/mock-project/regions/us-east1/subnetworks/mock-subnet"
      "private_app" = "projects/mock-project/regions/us-east1/subnetworks/mock-subnet-app"
    }
    network_name = "mock-network"
  }
}

dependency "kms" {
  config_path = "../../security/kms"
  mock_outputs = {
    crypto_keys = {
      gke = "projects/mock-project/locations/us-east1/keyRings/mock/cryptoKeys/gke"
    }
  }
}

inputs = {
  project_id = "your-prod-project-id"
  region     = local.region

  # Primary DR cluster configuration
  primary_cluster = {
    name        = local.compute_config.gke_clusters.dr_primary.name
    description = "Primary GKE cluster for disaster recovery in US East 1"
    location    = local.region

    # Cluster configuration optimized for DR
    remove_default_node_pool = true
    initial_node_count      = 1

    # Network configuration
    network    = dependency.vpc.outputs.network_self_link
    subnetwork = dependency.vpc.outputs.subnet_self_links["private_web"]

    # Master configuration
    master_auth = {
      client_certificate_config = {
        issue_client_certificate = false
      }
    }

    # Private cluster configuration
    private_cluster_config = {
      enable_private_nodes    = local.compute_config.gke_clusters.dr_primary.enable_private_cluster
      enable_private_endpoint = local.compute_config.gke_clusters.dr_primary.enable_private_endpoint
      master_ipv4_cidr_block = local.compute_config.gke_clusters.dr_primary.master_ipv4_cidr

      master_global_access_config = {
        enabled = true
      }
    }

    # IP allocation for secondary ranges
    ip_allocation_policy = {
      cluster_secondary_range_name  = "pods"
      services_secondary_range_name = "services"
    }

    # Network policy
    network_policy = {
      enabled  = local.compute_config.gke_clusters.dr_primary.enable_network_policy
      provider = "CALICO"
    }

    # Addons configuration
    addons_config = {
      http_load_balancing = {
        disabled = false
      }
      horizontal_pod_autoscaling = {
        disabled = false
      }
      network_policy_config = {
        disabled = false
      }
      gcp_filestore_csi_driver_config = {
        enabled = true
      }
      gcs_fuse_csi_driver_config = {
        enabled = true
      }
      gke_backup_agent_config = {
        enabled = true
      }
      config_connector_config = {
        enabled = true
      }
    }

    # Cluster features
    enable_autopilot                    = local.compute_config.gke_clusters.dr_primary.enable_autopilot
    enable_shielded_nodes              = local.compute_config.gke_clusters.dr_primary.enable_shielded_nodes
    enable_binary_authorization        = local.compute_config.gke_clusters.dr_primary.enable_binary_authorization
    enable_intranode_visibility        = local.compute_config.gke_clusters.dr_primary.enable_intranode_visibility
    enable_workload_identity           = local.compute_config.gke_clusters.dr_primary.enable_workload_identity

    # Resource usage metering
    resource_usage_export_config = {
      enable_network_egress_metering = local.compute_config.gke_clusters.dr_primary.enable_network_egress_metering
      enable_resource_consumption_metering = local.compute_config.gke_clusters.dr_primary.enable_resource_consumption_metering

      bigquery_destination = {
        dataset_id = "gke_usage_metering_dr"
      }
    }

    # Release channel
    release_channel = {
      channel = local.compute_config.gke_clusters.dr_primary.release_channel
    }

    # Workload identity
    workload_identity_config = {
      workload_pool = "your-prod-project-id.svc.id.goog"
    }

    # Maintenance policy
    maintenance_policy = {
      recurring_window = {
        start_time = "2024-01-01T09:00:00Z"
        end_time   = "2024-01-01T17:00:00Z"
        recurrence = "FREQ=WEEKLY;BYDAY=SA"
      }

      maintenance_exclusions = [
        {
          exclusion_name = "holiday-exclusion"
          start_time     = "2024-12-22T00:00:00Z"
          end_time       = "2024-01-02T23:59:59Z"
          exclusion_options = {
            scope = "NO_UPGRADES"
          }
        }
      ]
    }

    # Database encryption
    database_encryption = {
      state    = "ENCRYPTED"
      key_name = dependency.kms.outputs.crypto_keys.gke
    }

    # Logging and monitoring
    logging_config = {
      enable_components = [
        "SYSTEM_COMPONENTS",
        "WORKLOADS",
        "API_SERVER"
      ]
    }

    monitoring_config = {
      enable_components = [
        "SYSTEM_COMPONENTS",
        "CONTROLLER_MANAGER",
        "SCHEDULER"
      ]

      managed_prometheus = {
        enabled = true
      }
    }

    # Notification configuration
    notification_config = {
      pubsub = {
        enabled = true
        topic   = "projects/your-prod-project-id/topics/gke-notifications-dr"
        filter  = "UPGRADE_AVAILABLE_EVENT|UPGRADE_EVENT|SECURITY_BULLETIN_EVENT"
      }
    }

    # Pod security policy
    pod_security_policy_config = {
      enabled = local.compute_config.gke_clusters.dr_primary.enable_pod_security_policy
    }

    # Vertical Pod Autoscaling
    vertical_pod_autoscaling = {
      enabled = local.compute_config.gke_clusters.dr_primary.enable_vertical_pod_autoscaling
    }

    # Cluster autoscaling (regional)
    cluster_autoscaling = {
      enabled = local.compute_config.gke_clusters.dr_primary.enable_cluster_autoscaling
      auto_provisioning_defaults = {
        min_cpu_platform = "Intel Skylake"
        oauth_scopes = [
          "https://www.googleapis.com/auth/cloud-platform"
        ]
        service_account = "gke-dr-cluster@your-prod-project-id.iam.gserviceaccount.com"

        management = {
          auto_repair  = true
          auto_upgrade = false  # Manual control for DR
        }

        shielded_instance_config = {
          enable_secure_boot          = true
          enable_integrity_monitoring = true
        }

        disk_type    = "pd-ssd"
        disk_size_gb = 100

        upgrade_settings = {
          strategy        = "SURGE"
          max_surge       = 1
          max_unavailable = 0
        }
      }

      resource_limits = [
        {
          resource_type = "cpu"
          minimum       = 16
          maximum       = 1000
        },
        {
          resource_type = "memory"
          minimum       = 64
          maximum       = 4000
        }
      ]
    }

    # Security configuration
    authenticator_groups_config = {
      security_group = "gke-security-groups@your-company.com"
    }

    # Cost optimization
    cost_management_config = {
      enabled = true
    }

    # Gateway API
    gateway_api_config = {
      channel = "CHANNEL_STANDARD"
    }

    # Fleet configuration
    fleet = {
      project = "your-prod-project-id"
    }

    # DR specific configurations
    disaster_recovery_config = {
      enable_backup = true
      backup_schedule = "0 */6 * * *"  # Every 6 hours
      backup_retention_days = 30

      enable_cross_region_backup = true
      backup_locations = ["us-central1", "europe-west1"]

      enable_automated_restore = true
      restore_strategy = "POINT_IN_TIME"
    }
  }

  # Primary node pool for DR cluster
  node_pools = {
    dr_primary_pool = {
      name         = "dr-primary-pool"
      location     = local.region
      node_count   = local.compute_config.gke_clusters.dr_primary.initial_node_count

      # Node configuration
      node_config = {
        machine_type = local.compute_config.gke_clusters.dr_primary.machine_type
        disk_size_gb = local.compute_config.gke_clusters.dr_primary.disk_size_gb
        disk_type    = local.compute_config.gke_clusters.dr_primary.disk_type

        # Service account
        service_account = "gke-dr-nodes@your-prod-project-id.iam.gserviceaccount.com"

        oauth_scopes = [
          "https://www.googleapis.com/auth/cloud-platform"
        ]

        # Labels
        labels = {
          environment = "production"
          region = local.region_short
          node_pool = "dr-primary"
          workload_type = "general"
          tier = "production"
          dr_role = "primary"
        }

        # Taints for DR workloads
        taint = [
          {
            key    = "dr-node"
            value  = "true"
            effect = "NO_SCHEDULE"
          }
        ]

        # Metadata
        metadata = {
          disable-legacy-endpoints = "true"
          enable-oslogin = "true"
        }

        # Tags for firewall rules
        tags = ["gke-node", "dr-cluster", "internal"]

        # Image type
        image_type = "COS_CONTAINERD"

        # Local SSD configuration
        local_ssd_count = 1

        # GPU configuration for ML workloads
        guest_accelerator = []

        # Preemptible setting
        preemptible = local.compute_config.gke_clusters.dr_primary.preemptible
        spot        = local.compute_config.gke_clusters.dr_primary.spot

        # Shielded instance config
        shielded_instance_config = {
          enable_secure_boot          = true
          enable_integrity_monitoring = true
        }

        # Workload metadata config
        workload_metadata_config = {
          mode = "GKE_METADATA"
        }

        # Advanced machine features
        advanced_machine_features = {
          threads_per_core = 2
        }

        # Confidential nodes
        confidential_nodes = {
          enabled = local.compute_config.gke_clusters.dr_primary.enable_confidential_nodes
        }

        # Kubelet config
        kubelet_config = {
          cpu_manager_policy   = "static"
          cpu_cfs_quota_enabled = true
          pod_pids_limit       = 2048
        }

        # Linux node config
        linux_node_config = {
          sysctls = {
            "net.core.rmem_max" = "134217728"
            "net.core.wmem_max" = "134217728"
            "net.ipv4.tcp_rmem" = "4096 87380 134217728"
            "net.ipv4.tcp_wmem" = "4096 65536 134217728"
          }

          cgroup_mode = "CGROUP_MODE_V1"
        }

        # Resource labels
        resource_labels = {
          node_pool = "dr-primary"
          cluster = local.compute_config.gke_clusters.dr_primary.name
          environment = "production"
          managed_by = "terragrunt"
        }
      }

      # Autoscaling configuration
      autoscaling = {
        min_node_count = local.compute_config.gke_clusters.dr_primary.min_node_count
        max_node_count = local.compute_config.gke_clusters.dr_primary.max_node_count
      }

      # Management configuration
      management = {
        auto_repair  = local.compute_config.gke_clusters.dr_primary.auto_repair
        auto_upgrade = local.compute_config.gke_clusters.dr_primary.auto_upgrade
      }

      # Upgrade settings
      upgrade_settings = {
        strategy        = "SURGE"
        max_surge       = 2
        max_unavailable = 1

        blue_green_settings = {
          node_pool_soak_duration = "7200s"  # 2 hours

          standard_rollout_policy = {
            batch_percentage    = 50
            batch_soak_duration = "3600s"  # 1 hour
          }
        }
      }

      # Network configuration
      network_config = {
        create_pod_range     = false
        pod_range           = "pods"
        pod_ipv4_cidr_block = local.network_config.subnets.private_web.secondary_ranges.pods

        enable_private_nodes = true
      }

      # Placement policy
      placement_policy = {
        type         = "BALANCED"
        tpu_topology = ""
      }
    }

    # Secondary node pool for specific workloads
    dr_secondary_pool = {
      name         = "dr-secondary-pool"
      location     = local.region
      node_count   = local.compute_config.gke_clusters.dr_secondary.initial_node_count

      node_config = {
        machine_type = local.compute_config.gke_clusters.dr_secondary.machine_type
        disk_size_gb = local.compute_config.gke_clusters.dr_secondary.disk_size_gb
        disk_type    = local.compute_config.gke_clusters.dr_secondary.disk_type

        service_account = "gke-dr-nodes@your-prod-project-id.iam.gserviceaccount.com"

        oauth_scopes = [
          "https://www.googleapis.com/auth/cloud-platform"
        ]

        labels = {
          environment = "production"
          region = local.region_short
          node_pool = "dr-secondary"
          workload_type = "batch"
          tier = "production"
          dr_role = "secondary"
        }

        taint = [
          {
            key    = "batch-workload"
            value  = "true"
            effect = "NO_SCHEDULE"
          }
        ]

        metadata = {
          disable-legacy-endpoints = "true"
          enable-oslogin = "true"
        }

        tags = ["gke-node", "dr-cluster", "batch-workload"]

        image_type = "COS_CONTAINERD"
        preemptible = local.compute_config.gke_clusters.dr_secondary.preemptible

        shielded_instance_config = {
          enable_secure_boot          = true
          enable_integrity_monitoring = true
        }

        workload_metadata_config = {
          mode = "GKE_METADATA"
        }
      }

      autoscaling = {
        min_node_count = local.compute_config.gke_clusters.dr_secondary.min_node_count
        max_node_count = local.compute_config.gke_clusters.dr_secondary.max_node_count
      }

      management = {
        auto_repair  = local.compute_config.gke_clusters.dr_secondary.auto_repair
        auto_upgrade = local.compute_config.gke_clusters.dr_secondary.auto_upgrade
      }

      upgrade_settings = {
        strategy        = "BLUE_GREEN"
        max_surge       = 0
        max_unavailable = 1

        blue_green_settings = {
          node_pool_soak_duration = "3600s"

          standard_rollout_policy = {
            batch_percentage    = 100
            batch_soak_duration = "1800s"
          }
        }
      }
    }
  }

  # Integration with existing resources
  network_self_link = dependency.vpc.outputs.network_self_link
  subnet_self_links = dependency.vpc.outputs.subnet_self_links
  kms_crypto_key = dependency.kms.outputs.crypto_keys.gke

  # Tags for resource organization
  tags = {
    Environment = "production"
    Region = local.region
    RegionShort = local.region_short
    RegionType = "disaster-recovery"
    Team = "platform"
    Component = "kubernetes"
    CostCenter = "engineering"
    Compliance = "required"
    DataClassification = "internal"
    BackupRequired = "true"
    MonitoringRequired = "true"
    DRRole = "secondary"
    DRPriority = "1"
    SecurityLevel = "high"
    WorkloadIdentity = "enabled"
    BinaryAuthorization = "enforced"
  }
}