# Development - US Central 1 Region Configuration
# Primary development region with standard resources

locals {
  region = "us-central1"
  region_short = "usc1"

  # Region-specific configuration
  region_config = {
    location     = "us-central1"
    location_id  = "us-central1"
    display_name = "US Central 1 (Iowa)"

    # Availability zones
    availability_zones = [
      "us-central1-a",
      "us-central1-b",
      "us-central1-c",
      "us-central1-f"
    ]

    # Default zone for single-zone resources
    default_zone = "us-central1-a"

    # Region type and tier
    region_type = "primary"
    region_tier = "standard"
    is_primary  = true
    is_dr       = false
  }

  # Networking configuration for this region
  network_config = {
    # VPC CIDR ranges
    vpc_cidr_primary   = "10.10.0.0/16"
    vpc_cidr_secondary = "10.110.0.0/16"

    # Subnet configurations
    subnets = {
      public = {
        cidr = "10.10.0.0/20"
        secondary_ranges = {
          pods     = "10.110.0.0/18"
          services = "10.110.64.0/20"
        }
      }

      private = {
        cidr = "10.10.16.0/20"
        secondary_ranges = {
          pods     = "10.110.80.0/18"
          services = "10.110.144.0/20"
        }
      }

      database = {
        cidr = "10.10.32.0/20"
        secondary_ranges = {}
      }

      management = {
        cidr = "10.10.48.0/20"
        secondary_ranges = {}
      }
    }

    # NAT configuration
    enable_nat = true
    nat_ip_count = 2

    # VPN configuration
    enable_vpn = false
    vpn_peer_networks = []

    # Private Google Access
    enable_private_google_access = true
    enable_private_service_connect = false
  }

  # Compute resources configuration
  compute_config = {
    # GKE cluster configuration
    gke_clusters = {
      primary = {
        name               = "dev-${local.region_short}-primary"
        initial_node_count = 3
        min_node_count    = 1
        max_node_count    = 10
        machine_type      = "n2-standard-2"
        disk_size_gb      = 100
        disk_type         = "pd-standard"
        preemptible       = true
        auto_repair       = true
        auto_upgrade      = true
        enable_autopilot  = false
      }
    }

    # Instance groups
    instance_groups = {
      web = {
        size         = 2
        machine_type = "n2-standard-2"
        disk_size    = 50
        disk_type    = "pd-standard"
        preemptible  = true
      }

      backend = {
        size         = 2
        machine_type = "n2-standard-4"
        disk_size    = 100
        disk_type    = "pd-standard"
        preemptible  = true
      }
    }

    # Cloud Run configuration
    cloud_run = {
      cpu_limit    = "2"
      memory_limit = "4Gi"
      max_instances = 10
      min_instances = 0
      concurrency  = 100
    }

    # Cloud Functions configuration
    cloud_functions = {
      available_memory_mb = 512
      timeout            = 60
      max_instances      = 10
      min_instances      = 0
    }
  }

  # Storage configuration
  storage_config = {
    # GCS buckets
    buckets = {
      data = {
        storage_class = "STANDARD"
        lifecycle_rules = {
          age_days = 90
          action   = "SetStorageClass"
          storage_class = "NEARLINE"
        }
      }

      backups = {
        storage_class = "NEARLINE"
        lifecycle_rules = {
          age_days = 30
          action   = "Delete"
        }
      }

      logs = {
        storage_class = "STANDARD"
        lifecycle_rules = {
          age_days = 7
          action   = "Delete"
        }
      }
    }

    # Filestore configuration
    filestore = {
      tier = "BASIC_HDD"
      capacity_gb = 1024
    }
  }

  # Database configuration
  database_config = {
    # Cloud SQL configuration
    cloud_sql = {
      tier = "db-n1-standard-2"
      disk_size = 100
      disk_type = "PD_SSD"
      backup_enabled = true
      backup_start_time = "03:00"
      high_availability = false
      point_in_time_recovery = false

      read_replicas = 0

      maintenance_window = {
        day          = 7  # Sunday
        hour         = 4
        update_track = "stable"
      }
    }

    # Firestore configuration
    firestore = {
      type = "FIRESTORE_NATIVE"
      concurrency_mode = "OPTIMISTIC"
      app_engine_integration_mode = "DISABLED"
    }

    # Redis configuration
    redis = {
      tier = "BASIC"
      memory_size_gb = 1
      version = "REDIS_7_0"
      auth_enabled = true
      transit_encryption_mode = "DISABLED"
    }

    # BigQuery configuration
    bigquery = {
      default_table_expiration_ms = 7776000000  # 90 days
      default_partition_expiration_ms = 2592000000  # 30 days
      delete_contents_on_destroy = true
    }
  }

  # Monitoring configuration
  monitoring_config = {
    # Log retention
    log_retention_days = 30

    # Metrics retention
    metrics_retention_days = 30

    # Alerting
    enable_alerting = true
    notification_channels = ["email"]

    # Dashboards
    create_default_dashboards = true

    # Uptime checks
    enable_uptime_checks = false

    # APM
    enable_apm = false
    enable_profiler = false
    enable_trace = true
  }

  # Security configuration
  security_config = {
    # KMS configuration
    kms = {
      key_ring = "dev-${local.region_short}-keyring"
      rotation_period = "7776000s"  # 90 days
      algorithm = "GOOGLE_SYMMETRIC_ENCRYPTION"
      protection_level = "SOFTWARE"
    }

    # Secret Manager
    secret_manager = {
      replication = "USER_MANAGED"
      locations = [local.region]
    }

    # VPC Service Controls
    enable_vpc_sc = false

    # Binary Authorization
    enable_binary_authorization = false

    # Security Command Center
    enable_scc = false
  }

  # Backup configuration
  backup_config = {
    # Backup schedules
    backup_schedule = "0 2 * * *"  # 2 AM daily

    # Retention
    backup_retention_days = 7

    # Backup location
    backup_location = local.region

    # Cross-region backup
    enable_cross_region_backup = false
  }

  # Disaster recovery configuration
  dr_config = {
    # DR enablement
    enable_dr = false

    # DR region (if enabled)
    dr_region = ""

    # RPO/RTO targets
    rpo_minutes = 1440  # 24 hours
    rto_minutes = 2880  # 48 hours
  }

  # Cost optimization
  cost_optimization = {
    # Use preemptible/spot instances
    use_preemptible = true

    # Use committed use discounts
    use_committed_use_discounts = false

    # Auto-shutdown non-production resources
    enable_auto_shutdown = true
    shutdown_time = "20:00"
    startup_time  = "08:00"
    shutdown_days = ["SATURDAY", "SUNDAY"]
  }

  # Region labels
  region_labels = {
    region       = local.region
    region_short = local.region_short
    region_type  = local.region_config.region_type
    region_tier  = local.region_config.region_tier
    environment  = "development"
    cost_center  = "engineering"
    managed_by   = "terragrunt"
  }

  # Feature flags for this region
  feature_flags = {
    enable_gke_autopilot = false
    enable_anthos       = false
    enable_cloud_run    = true
    enable_cloud_functions = true
    enable_app_engine   = false
    enable_dataflow     = false
    enable_dataproc     = false
    enable_composer     = false
    enable_cloud_cdn    = false
    enable_cloud_armor  = false
  }
}