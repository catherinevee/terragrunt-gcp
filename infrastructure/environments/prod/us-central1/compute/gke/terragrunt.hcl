# GKE Cluster Configuration for Production - US Central 1
# Primary production Kubernetes cluster with enterprise features

terraform {
  source = "${get_repo_root()}/modules/kubernetes/gke"
}

# Include root configuration
include "root" {
  path = find_in_parent_folders()
}

# Include environment configuration
include "env" {
  path = find_in_parent_folders("env.hcl")
  expose = true
}

# Include region configuration
include "region" {
  path = find_in_parent_folders("region.hcl")
  expose = true
}

# GKE depends on VPC and Cloud NAT
dependency "vpc" {
  config_path = "../../networking/vpc"

  mock_outputs = {
    network_id = "mock-network-id"
    network_name = "mock-network-name"
    subnets = {
      private_web = {
        id = "mock-subnet-id"
        name = "mock-subnet-name"
        ip_cidr_range = "10.0.0.0/24"
        region = "us-central1"
        secondary_ip_ranges = [
          {
            range_name = "pods"
            ip_cidr_range = "10.100.0.0/16"
          },
          {
            range_name = "services"
            ip_cidr_range = "10.101.0.0/16"
          }
        ]
      }
    }
  }
}

dependency "nat" {
  config_path = "../../networking/cloud-nat"

  mock_outputs = {
    router_name = "mock-router-name"
    nat_name = "mock-nat-name"
  }
}

# Prevent accidental destruction of production GKE cluster
prevent_destroy = true

locals {
  # Extract configuration from includes
  env_config    = include.env.locals
  region_config = include.region.locals

  # GKE configuration from region
  gke_config = region_config.compute_config.gke_clusters.primary

  # Cluster name
  cluster_name = local.gke_config.name

  # Network configuration
  network_name = dependency.vpc.outputs.network_name
  subnet_name  = dependency.vpc.outputs.subnets.private_web.name
  pods_range_name = "pods"
  services_range_name = "services"

  # Node pool configurations for production
  node_pools = {
    # Default node pool (system workloads)
    system = {
      name               = "system-pool"
      machine_type       = "n2-standard-4"
      node_locations     = join(",", local.region_config.region_config.availability_zones)
      min_count          = 3
      max_count          = 10
      initial_count      = 3
      disk_size_gb       = 100
      disk_type          = "pd-ssd"
      auto_repair        = true
      auto_upgrade       = false
      preemptible        = false
      spot               = false

      node_config = {
        oauth_scopes = [
          "https://www.googleapis.com/auth/cloud-platform"
        ]

        labels = {
          pool = "system"
          workload = "system"
        }

        taint = []

        tags = ["gke-node", "gke-${local.cluster_name}", "system-pool"]

        metadata = {
          disable-legacy-endpoints = "true"
        }

        shielded_instance_config = {
          enable_secure_boot = true
          enable_integrity_monitoring = true
        }

        workload_metadata_config = {
          mode = "GKE_METADATA"
        }

        kubelet_config = {
          cpu_manager_policy = "static"
          cpu_cfs_quota_enabled = true
          pod_pids_limit = 4096
        }

        linux_node_config = {
          sysctls = {
            "net.core.netdev_max_backlog" = "30000"
            "net.core.rmem_max" = "134217728"
            "net.core.wmem_max" = "134217728"
            "net.ipv4.tcp_rmem" = "4096 87380 134217728"
            "net.ipv4.tcp_wmem" = "4096 65536 134217728"
          }
        }
      }

      management = {
        auto_repair  = true
        auto_upgrade = false
      }

      upgrade_settings = {
        max_surge       = 1
        max_unavailable = 0
        strategy        = "SURGE"
      }
    }

    # Application node pool
    application = {
      name               = "app-pool"
      machine_type       = "n2-standard-8"
      node_locations     = join(",", local.region_config.region_config.availability_zones)
      min_count          = 5
      max_count          = 50
      initial_count      = 10
      disk_size_gb       = 200
      disk_type          = "pd-ssd"
      auto_repair        = true
      auto_upgrade       = false
      preemptible        = false
      spot               = false

      node_config = {
        oauth_scopes = [
          "https://www.googleapis.com/auth/cloud-platform"
        ]

        labels = {
          pool = "application"
          workload = "application"
          tier = "standard"
        }

        taint = []

        tags = ["gke-node", "gke-${local.cluster_name}", "app-pool"]

        metadata = {
          disable-legacy-endpoints = "true"
        }

        shielded_instance_config = {
          enable_secure_boot = true
          enable_integrity_monitoring = true
        }

        workload_metadata_config = {
          mode = "GKE_METADATA"
        }
      }

      management = {
        auto_repair  = true
        auto_upgrade = false
      }

      upgrade_settings = {
        max_surge       = 2
        max_unavailable = 0
        strategy        = "SURGE"
      }

      autoscaling = {
        enabled = true
        min_count = 5
        max_count = 50
        location_policy = "BALANCED"
        total_min_count = 5
        total_max_count = 50
      }
    }

    # High-memory node pool
    highmem = {
      name               = "highmem-pool"
      machine_type       = "n2-highmem-8"
      node_locations     = join(",", local.region_config.region_config.availability_zones)
      min_count          = 0
      max_count          = 20
      initial_count      = 2
      disk_size_gb       = 200
      disk_type          = "pd-ssd"
      auto_repair        = true
      auto_upgrade       = false
      preemptible        = false
      spot               = false

      node_config = {
        oauth_scopes = [
          "https://www.googleapis.com/auth/cloud-platform"
        ]

        labels = {
          pool = "highmem"
          workload = "memory-intensive"
          tier = "premium"
        }

        taint = [
          {
            key    = "workload"
            value  = "memory-intensive"
            effect = "NO_SCHEDULE"
          }
        ]

        tags = ["gke-node", "gke-${local.cluster_name}", "highmem-pool"]

        metadata = {
          disable-legacy-endpoints = "true"
        }

        shielded_instance_config = {
          enable_secure_boot = true
          enable_integrity_monitoring = true
        }
      }

      management = {
        auto_repair  = true
        auto_upgrade = false
      }

      autoscaling = {
        enabled = true
        min_count = 0
        max_count = 20
      }
    }

    # Spot instance node pool (for batch workloads)
    spot = {
      name               = "spot-pool"
      machine_type       = "n2-standard-4"
      node_locations     = join(",", local.region_config.region_config.availability_zones)
      min_count          = 0
      max_count          = 30
      initial_count      = 0
      disk_size_gb       = 100
      disk_type          = "pd-standard"
      auto_repair        = true
      auto_upgrade       = false
      preemptible        = false
      spot               = true

      node_config = {
        oauth_scopes = [
          "https://www.googleapis.com/auth/cloud-platform"
        ]

        labels = {
          pool = "spot"
          workload = "batch"
          tier = "economy"
        }

        taint = [
          {
            key    = "cloud.google.com/gke-spot"
            value  = "true"
            effect = "NO_SCHEDULE"
          }
        ]

        tags = ["gke-node", "gke-${local.cluster_name}", "spot-pool"]

        spot = true

        metadata = {
          disable-legacy-endpoints = "true"
        }
      }

      management = {
        auto_repair  = true
        auto_upgrade = false
      }

      autoscaling = {
        enabled = true
        min_count = 0
        max_count = 30
      }
    }
  }

  # Cluster autoscaling configuration
  cluster_autoscaling = {
    enabled = true
    autoscaling_profile = "OPTIMIZE_UTILIZATION"

    resource_limits = [
      {
        resource_type = "cpu"
        minimum = 10
        maximum = 1000
      },
      {
        resource_type = "memory"
        minimum = 40
        maximum = 4000
      }
    ]

    auto_provisioning_defaults = {
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]

      service_account = var.terraform_service_account

      disk_size = 100
      disk_type = "pd-ssd"

      shielded_instance_config = {
        enable_secure_boot = true
        enable_integrity_monitoring = true
      }

      management = {
        auto_repair = true
        auto_upgrade = false
      }

      upgrade_settings = {
        max_surge = 1
        max_unavailable = 0
      }
    }
  }

  # Maintenance window for production (Sunday 2-6 AM)
  maintenance_policy = {
    daily_maintenance_window = null
    recurring_window = {
      start_time = "2024-01-07T02:00:00Z"  # Sunday 2 AM
      end_time   = "2024-01-07T06:00:00Z"  # Sunday 6 AM
      recurrence = "FREQ=WEEKLY;BYDAY=SU"
    }
    maintenance_exclusion = []
  }

  # Monitoring configuration
  monitoring_config = {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
      "APISERVER",
      "CONTROLLER_MANAGER",
      "SCHEDULER"
    ]

    managed_prometheus = {
      enabled = true
    }

    advanced_datapath_observability_config = {
      enable_metrics = true
      relay_mode = "INTERNAL_VPC_LB"
    }
  }

  # Logging configuration
  logging_config = {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
      "APISERVER",
      "CONTROLLER_MANAGER",
      "SCHEDULER"
    ]
  }

  # Security configuration
  security_config = {
    workload_identity_config = {
      workload_pool = "${var.project_id}.svc.id.goog"
    }

    binary_authorization = {
      evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
    }

    shielded_nodes = {
      enabled = true
    }

    network_policy_config = {
      disabled = false
    }

    private_cluster_config = {
      enable_private_nodes = true
      enable_private_endpoint = false
      master_ipv4_cidr_block = local.gke_config.master_ipv4_cidr

      master_global_access_config = {
        enabled = true
      }
    }

    authenticator_groups_config = {
      security_group = "gke-security-groups@${local.env_config.organization_domain}"
    }

    master_authorized_networks = [
      {
        display_name = "Company Office"
        cidr_block   = "203.0.113.0/24"
      },
      {
        display_name = "VPN Gateway"
        cidr_block   = "198.51.100.0/24"
      },
      {
        display_name = "Cloud NAT IPs"
        cidr_block   = "35.235.240.0/20"
      }
    ]

    database_encryption = {
      state    = "ENCRYPTED"
      key_name = "projects/${var.project_id}/locations/${local.region_config.region}/keyRings/${var.kms_key_ring}/cryptoKeys/gke-database-key"
    }

    sandbox_config = {
      enabled = true
      sandbox_type = "GVISOR"
    }
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

    gce_persistent_disk_csi_driver_config = {
      enabled = true
    }

    config_connector_config = {
      enabled = true
    }

    dns_cache_config = {
      enabled = true
    }

    stateful_ha_config = {
      enabled = true
    }
  }

  # Cost management features
  cost_management_config = {
    enabled = true
  }

  # Fleet configuration
  fleet_config = {
    enabled = true
    project = var.project_id
  }
}

# Module inputs
inputs = {
  # Cluster basic configuration
  name        = local.cluster_name
  description = "Production GKE cluster for ${local.region_config.region}"

  # Location configuration
  location = local.region_config.region
  node_locations = local.region_config.region_config.availability_zones
  regional = true

  # Network configuration
  network    = local.network_name
  subnetwork = local.subnet_name

  # IP allocation for pods and services
  cluster_secondary_range_name  = local.pods_range_name
  services_secondary_range_name = local.services_range_name

  # Cluster version
  kubernetes_version = "1.28"
  release_channel    = local.gke_config.release_channel

  # Node pools
  node_pools = local.node_pools
  remove_default_node_pool = true
  initial_node_count = 1

  # Autoscaling
  cluster_autoscaling = local.cluster_autoscaling

  # Maintenance
  maintenance_policy = local.maintenance_policy

  # Monitoring and logging
  monitoring_config = local.monitoring_config
  logging_config = local.logging_config

  # Security features
  enable_private_nodes = local.security_config.private_cluster_config.enable_private_nodes
  enable_private_endpoint = local.security_config.private_cluster_config.enable_private_endpoint
  master_ipv4_cidr_block = local.security_config.private_cluster_config.master_ipv4_cidr_block

  enable_shielded_nodes = local.security_config.shielded_nodes.enabled
  enable_binary_authorization = true
  enable_network_policy = true
  enable_intranode_visibility = local.gke_config.enable_intranode_visibility

  workload_identity_config = local.security_config.workload_identity_config
  authenticator_groups_config = local.security_config.authenticator_groups_config
  master_authorized_networks = local.security_config.master_authorized_networks
  database_encryption = local.security_config.database_encryption

  # Vertical Pod Autoscaling
  enable_vertical_pod_autoscaling = local.gke_config.enable_vertical_pod_autoscaling

  # Confidential nodes
  enable_confidential_nodes = local.gke_config.enable_confidential_nodes

  # Addons
  addons_config = local.addons_config

  # Cost management
  enable_cost_allocation_feature = true
  cost_management_config = local.cost_management_config

  # Resource usage export
  resource_usage_export_config = {
    enable_network_egress_metering = local.gke_config.enable_network_egress_metering
    enable_resource_consumption_metering = local.gke_config.enable_resource_consumption_metering

    bigquery_destination = {
      dataset_id = local.gke_config.resource_usage_bigquery_dataset
    }
  }

  # Dataplane V2 (eBPF)
  enable_dataplane_v2 = true
  dataplane_v2_observability_mode = "INTERNAL_VPC_LB"

  # Gateway API
  gateway_api_config = {
    channel = "CHANNEL_STANDARD"
  }

  # DNS configuration
  cluster_dns_config = {
    cluster_dns = "CLOUD_DNS"
    cluster_dns_scope = "CLUSTER_SCOPE"
    cluster_dns_domain = "${local.cluster_name}.${local.env_config.environment}.local"
  }

  # Service mesh
  mesh_certificates = {
    enable_certificates = true
  }

  # Labels
  resource_labels = merge(
    var.common_labels,
    {
      component = "kubernetes"
      service   = "gke"
      tier      = "compute"
      cluster   = local.cluster_name
    }
  )

  # Timeouts
  timeouts = {
    create = "45m"
    update = "45m"
    delete = "45m"
  }

  # Project configuration
  project_id = var.project_id

  # Service account
  create_service_account = false
  service_account = var.terraform_service_account

  # Grant additional roles to service account
  grant_registry_access = true
  registry_project_ids = [var.project_id]

  # Fleet management
  fleet_project = var.project_id

  # Config sync (GitOps)
  config_sync = {
    enabled = true
    source_format = "unstructured"
    sync_repo = "https://github.com/${var.labels.git_repository}"
    sync_branch = "main"
    policy_dir = "k8s-config/${local.env_config.environment}"
    sync_wait_secs = "20"
    secret_type = "token"
  }

  # Policy controller
  policy_controller = {
    enabled = true
    template_library_installed = true
    referential_rules_enabled = true
    log_denies_enabled = true
  }

  # Enable APIs
  enable_apis = true
  activate_apis = [
    "container.googleapis.com",
    "containerregistry.googleapis.com",
    "gkehub.googleapis.com",
    "gkebackup.googleapis.com",
    "anthosconfigmanagement.googleapis.com",
    "binaryauthorization.googleapis.com",
    "meshconfig.googleapis.com",
    "meshca.googleapis.com"
  ]
}