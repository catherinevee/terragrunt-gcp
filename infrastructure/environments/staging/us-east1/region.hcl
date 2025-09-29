# Staging - US East 1 Region Configuration
# Secondary staging region for disaster recovery

locals {
  region = "us-east1"
  region_short = "use1"

  # Region-specific configuration
  region_config = {
    location     = "us-east1"
    location_id  = "us-east1"
    display_name = "US East 1 (South Carolina)"

    # Availability zones
    availability_zones = [
      "us-east1-b",
      "us-east1-c",
      "us-east1-d"
    ]

    # Default zone for single-zone resources
    default_zone = "us-east1-b"

    # Region type and tier
    region_type = "secondary"
    region_tier = "enterprise"
    is_primary  = false
    is_dr       = true
  }

  # Networking configuration for this region
  network_config = {
    # VPC CIDR ranges
    vpc_cidr_primary   = "10.21.0.0/16"
    vpc_cidr_secondary = "10.121.0.0/16"

    # Subnet configurations
    subnets = {
      public = {
        cidr = "10.21.0.0/20"
        secondary_ranges = {
          pods     = "10.121.0.0/17"
          services = "10.121.128.0/20"
        }
      }

      private = {
        cidr = "10.21.16.0/20"
        secondary_ranges = {
          pods     = "10.121.144.0/17"
          services = "10.121.208.0/20"
        }
      }

      database = {
        cidr = "10.21.32.0/20"
        secondary_ranges = {}
      }

      management = {
        cidr = "10.21.48.0/20"
        secondary_ranges = {}
      }

      dmz = {
        cidr = "10.21.64.0/20"
        secondary_ranges = {}
      }
    }

    # NAT configuration
    enable_nat = true
    nat_ip_count = 2
    enable_nat_logging = true

    # VPN configuration
    enable_vpn = true
    vpn_peer_networks = ["staging-usc1-vpc", "prod-vpc"]

    # Private Google Access
    enable_private_google_access = true
    enable_private_service_connect = true

    # Network peering
    enable_vpc_peering = true
    peer_networks = {
      staging_primary = {
        network = "projects/staging-project/global/networks/staging-usc1-vpc"
        export_custom_routes = true
        import_custom_routes = true
      }
    }
  }

  # Compute resources configuration
  compute_config = {
    # GKE cluster configuration
    gke_clusters = {
      dr = {
        name               = "staging-${local.region_short}-dr"
        initial_node_count = 3
        min_node_count    = 2
        max_node_count    = 15
        machine_type      = "n2-standard-4"
        disk_size_gb      = 200
        disk_type         = "pd-ssd"
        preemptible       = false
        spot              = true
        spot_percentage   = 40
        auto_repair       = true
        auto_upgrade      = true
        enable_autopilot  = false
        enable_shielded_nodes = true
        enable_network_policy = true
        enable_private_cluster = true
        master_ipv4_cidr = "172.16.0.32/28"
      }
    }

    # Instance groups
    instance_groups = {
      web = {
        size         = 2
        machine_type = "n2-standard-2"
        disk_size    = 100
        disk_type    = "pd-ssd"
        preemptible  = false
        enable_auto_healing = true
      }

      backend = {
        size         = 3
        machine_type = "n2-standard-4"
        disk_size    = 200
        disk_type    = "pd-ssd"
        preemptible  = false
        enable_auto_healing = true
      }

      workers = {
        size         = 2
        machine_type = "n2-highmem-2"
        disk_size    = 100
        disk_type    = "pd-standard"
        preemptible  = true
        enable_auto_healing = true
      }
    }

    # Cloud Run configuration
    cloud_run = {
      cpu_limit    = "2"
      memory_limit = "4Gi"
      max_instances = 30
      min_instances = 1
      concurrency  = 100
      enable_vpc_connector = true
    }

    # Cloud Functions configuration
    cloud_functions = {
      available_memory_mb = 512
      timeout            = 300
      max_instances      = 10
      min_instances      = 0
      enable_vpc_connector = true
    }
  }

  # Storage configuration
  storage_config = {
    # GCS buckets
    buckets = {
      data = {
        storage_class = "STANDARD"
        versioning = true
        lifecycle_rules = [
          {
            age_days = 30
            action   = "SetStorageClass"
            storage_class = "NEARLINE"
          },
          {
            age_days = 90
            action   = "SetStorageClass"
            storage_class = "COLDLINE"
          }
        ]
      }

      backups = {
        storage_class = "NEARLINE"
        versioning = true
        lifecycle_rules = [
          {
            age_days = 90
            action   = "SetStorageClass"
            storage_class = "ARCHIVE"
          }
        ]
      }

      logs = {
        storage_class = "STANDARD"
        lifecycle_rules = [
          {
            age_days = 30
            action   = "Delete"
          }
        ]
      }
    }

    # Filestore configuration
    filestore = {
      tier = "BASIC_SSD"
      capacity_gb = 1024
      enable_snapshots = true
    }
  }

  # Database configuration
  database_config = {
    # Cloud SQL configuration (DR replica)
    cloud_sql = {
      tier = "db-n1-standard-4"
      disk_size = 500
      disk_type = "PD_SSD"
      disk_autoresize = true
      disk_autoresize_limit = 1000
      backup_enabled = true
      backup_start_time = "03:00"
      backup_location = local.region
      high_availability = true
      availability_type = "REGIONAL"
      point_in_time_recovery = true

      # Replica of primary region
      replica_configuration = {
        master_instance_name = "staging-usc1-primary"
        failover_replica = true
      }

      maintenance_window = {
        day          = 6  # Saturday
        hour         = 4
        update_track = "stable"
      }

      insights_config = {
        query_insights_enabled = true
        query_string_length = 1024
        record_application_tags = true
        record_client_address = true
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
      tier = "STANDARD_HA"
      memory_size_gb = 5
      version = "REDIS_7_0"
      auth_enabled = true
      transit_encryption_mode = "SERVER_AUTHENTICATION"
      replica_count = 1
      read_replicas_mode = "READ_REPLICAS_ENABLED"
    }

    # BigQuery configuration
    bigquery = {
      default_table_expiration_ms = 15552000000  # 180 days
      default_partition_expiration_ms = 7776000000  # 90 days
      delete_contents_on_destroy = false
      enable_encryption = true
    }
  }

  # Monitoring configuration
  monitoring_config = {
    # Log retention
    log_retention_days = 60

    # Metrics retention
    metrics_retention_days = 90

    # Alerting
    enable_alerting = true
    notification_channels = ["email", "slack", "pagerduty"]

    # Dashboards
    create_default_dashboards = true
    custom_dashboards = ["dr-status", "replication-lag", "failover-readiness"]

    # Uptime checks
    enable_uptime_checks = true
    uptime_check_frequency = 60  # seconds

    # APM
    enable_apm = true
    enable_profiler = true
    enable_trace = true
    trace_sampling_rate = 0.1
  }

  # Security configuration
  security_config = {
    # KMS configuration
    kms = {
      key_ring = "staging-${local.region_short}-keyring"
      rotation_period = "2592000s"  # 30 days
      algorithm = "GOOGLE_SYMMETRIC_ENCRYPTION"
      protection_level = "SOFTWARE"
      enable_automatic_rotation = true
    }

    # Secret Manager
    secret_manager = {
      replication = "AUTOMATIC"
      enable_cmek = true
      enable_audit_logs = true
    }

    # VPC Service Controls
    enable_vpc_sc = true
    vpc_sc_perimeter = "staging-perimeter"

    # Binary Authorization
    enable_binary_authorization = true
    require_attestations = true

    # Security Command Center
    enable_scc = true
    enable_scc_notifications = true

    # Web Security
    enable_cloud_armor = true
    enable_ddos_protection = true

    # Identity & Access
    enable_workload_identity = true
    enable_identity_aware_proxy = true
  }

  # Backup configuration
  backup_config = {
    # Backup schedules
    backup_schedule = "0 2 * * *"  # 2 AM daily

    # Retention
    backup_retention_days = 30
    backup_retention_weekly = 12  # weeks
    backup_retention_monthly = 6  # months

    # Backup location
    backup_location = local.region
    backup_storage_class = "NEARLINE"

    # Cross-region backup
    enable_cross_region_backup = true
    cross_region_backup_location = "us-central1"

    # Backup testing
    enable_backup_testing = true
    backup_test_frequency = "weekly"
  }

  # Disaster recovery configuration
  dr_config = {
    # DR enablement
    enable_dr = true

    # Primary region
    primary_region = "us-central1"

    # RPO/RTO targets
    rpo_minutes = 30   # 30 minutes
    rto_minutes = 120  # 2 hours

    # DR testing
    enable_dr_testing = true
    dr_test_frequency = "monthly"

    # Failover configuration
    enable_automatic_failover = true
    failover_threshold_minutes = 15
    failback_delay_minutes = 60
  }

  # Cost optimization
  cost_optimization = {
    # Use preemptible/spot instances
    use_preemptible = false
    use_spot = true
    spot_percentage = 40

    # Use committed use discounts
    use_committed_use_discounts = true
    committed_use_cpu_cores = 30
    committed_use_memory_gb = 120

    # Resource optimization
    enable_rightsizing_recommendations = true
    enable_idle_resource_recommendations = true
  }

  # Region labels
  region_labels = {
    region       = local.region
    region_short = local.region_short
    region_type  = local.region_config.region_type
    region_tier  = local.region_config.region_tier
    environment  = "staging"
    cost_center  = "engineering"
    managed_by   = "terragrunt"
    dr_role      = "secondary"
  }

  # Feature flags for this region
  feature_flags = {
    enable_gke_autopilot = true
    enable_anthos       = true
    enable_cloud_run    = true
    enable_cloud_functions = true
    enable_app_engine   = false  # Only in primary region
    enable_dataflow     = true
    enable_dataproc     = true
    enable_composer     = false  # Only in primary region
    enable_cloud_cdn    = true
    enable_cloud_armor  = true
    enable_api_gateway  = true
    enable_apigee      = false
  }
}