# Staging - Europe West 1 Region Configuration
# European staging region for GDPR compliance and EU presence

locals {
  region = "europe-west1"
  region_short = "euw1"

  # Region-specific configuration
  region_config = {
    location     = "europe-west1"
    location_id  = "europe-west1"
    display_name = "Europe West 1 (Belgium)"

    # Availability zones
    availability_zones = [
      "europe-west1-b",
      "europe-west1-c",
      "europe-west1-d"
    ]

    # Default zone for single-zone resources
    default_zone = "europe-west1-b"

    # Region type and tier
    region_type = "tertiary"
    region_tier = "enterprise"
    is_primary  = false
    is_dr       = false
  }

  # Networking configuration for this region
  network_config = {
    # VPC CIDR ranges
    vpc_cidr_primary   = "10.22.0.0/16"
    vpc_cidr_secondary = "10.122.0.0/16"

    # Subnet configurations
    subnets = {
      public = {
        cidr = "10.22.0.0/20"
        secondary_ranges = {
          pods     = "10.122.0.0/17"
          services = "10.122.128.0/20"
        }
      }

      private = {
        cidr = "10.22.16.0/20"
        secondary_ranges = {
          pods     = "10.122.144.0/17"
          services = "10.122.208.0/20"
        }
      }

      database = {
        cidr = "10.22.32.0/20"
        secondary_ranges = {}
      }

      management = {
        cidr = "10.22.48.0/20"
        secondary_ranges = {}
      }

      dmz = {
        cidr = "10.22.64.0/20"
        secondary_ranges = {}
      }
    }

    # NAT configuration
    enable_nat = true
    nat_ip_count = 2
    enable_nat_logging = true

    # VPN configuration
    enable_vpn = true
    vpn_peer_networks = ["staging-usc1-vpc", "prod-euw1-vpc"]

    # Private Google Access
    enable_private_google_access = true
    enable_private_service_connect = true

    # Network peering
    enable_vpc_peering = true
    peer_networks = {
      staging_primary = {
        network = "projects/staging-project/global/networks/staging-usc1-vpc"
        export_custom_routes = false
        import_custom_routes = false
      }
    }
  }

  # Compute resources configuration
  compute_config = {
    # GKE cluster configuration
    gke_clusters = {
      eu_primary = {
        name               = "staging-${local.region_short}-primary"
        initial_node_count = 3
        min_node_count    = 2
        max_node_count    = 12
        machine_type      = "n2-standard-4"
        disk_size_gb      = 200
        disk_type         = "pd-ssd"
        preemptible       = false
        spot              = true
        spot_percentage   = 30
        auto_repair       = true
        auto_upgrade      = true
        enable_autopilot  = false
        enable_shielded_nodes = true
        enable_network_policy = true
        enable_private_cluster = true
        master_ipv4_cidr = "172.16.0.64/28"
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
    }

    # Cloud Run configuration
    cloud_run = {
      cpu_limit    = "2"
      memory_limit = "4Gi"
      max_instances = 25
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

  # Storage configuration with GDPR compliance
  storage_config = {
    # GCS buckets with EU data residency
    buckets = {
      data = {
        storage_class = "STANDARD"
        location_type = "REGION"
        data_locations = ["EUROPE"]
        versioning = true
        uniform_bucket_level_access = true
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
        location_type = "REGION"
        data_locations = ["EUROPE"]
        versioning = true
        uniform_bucket_level_access = true
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
        location_type = "REGION"
        data_locations = ["EUROPE"]
        uniform_bucket_level_access = true
        lifecycle_rules = [
          {
            age_days = 30
            action   = "Delete"
          }
        ]
      }

      gdpr_data = {
        storage_class = "STANDARD"
        location_type = "REGION"
        data_locations = ["EUROPE"]
        versioning = true
        uniform_bucket_level_access = true
        retention_policy = {
          retention_period = 63072000  # 2 years in seconds
          is_locked = true
        }
      }
    }

    # Filestore configuration
    filestore = {
      tier = "BASIC_SSD"
      capacity_gb = 1024
      enable_snapshots = true
      location = local.region
    }
  }

  # Database configuration with EU data residency
  database_config = {
    # Cloud SQL configuration
    cloud_sql = {
      tier = "db-n1-standard-4"
      disk_size = 300
      disk_type = "PD_SSD"
      disk_autoresize = true
      disk_autoresize_limit = 750
      backup_enabled = true
      backup_start_time = "01:00"  # 1 AM CET
      backup_location = local.region
      high_availability = true
      availability_type = "REGIONAL"
      point_in_time_recovery = true

      read_replicas = 1

      maintenance_window = {
        day          = 6  # Saturday
        hour         = 2  # 2 AM CET
        update_track = "stable"
      }

      insights_config = {
        query_insights_enabled = true
        query_string_length = 1024
        record_application_tags = true
        record_client_address = false  # GDPR compliance
      }

      # GDPR compliance settings
      location_preference = {
        zone = "europe-west1-b"
        secondary_zone = "europe-west1-c"
      }

      database_flags = [
        {
          name = "cloudsql.enable_pg_audit"
          value = "on"
        },
        {
          name = "log_connections"
          value = "on"
        },
        {
          name = "log_disconnections"
          value = "on"
        }
      ]
    }

    # Firestore configuration
    firestore = {
      type = "FIRESTORE_NATIVE"
      location_id = "eur3"  # Multi-region in Europe
      concurrency_mode = "OPTIMISTIC"
      app_engine_integration_mode = "DISABLED"
    }

    # Redis configuration
    redis = {
      tier = "STANDARD_HA"
      memory_size_gb = 3
      version = "REDIS_7_0"
      auth_enabled = true
      transit_encryption_mode = "SERVER_AUTHENTICATION"
      replica_count = 1
      read_replicas_mode = "READ_REPLICAS_ENABLED"
      location_id = "europe-west1-b"
      alternative_location_id = "europe-west1-c"
    }

    # BigQuery configuration
    bigquery = {
      location = "EU"  # Multi-region in Europe
      default_table_expiration_ms = 15552000000  # 180 days
      default_partition_expiration_ms = 7776000000  # 90 days
      delete_contents_on_destroy = false
      enable_encryption = true
      default_kms_key_name = "projects/staging-project/locations/europe/keyRings/staging-euw1-keyring/cryptoKeys/bigquery-key"
    }
  }

  # Monitoring configuration
  monitoring_config = {
    # Log retention (GDPR compliant)
    log_retention_days = 60
    log_exclusions = [
      "protoPayload.request.@type=\"type.googleapis.com/google.privacy.dlp.v2.InspectContentRequest\"",
      "resource.labels.cluster_name=\"staging-euw1-primary\" AND severity<ERROR"
    ]

    # Metrics retention
    metrics_retention_days = 90

    # Alerting
    enable_alerting = true
    notification_channels = ["email", "slack", "pagerduty"]

    # Dashboards
    create_default_dashboards = true
    custom_dashboards = ["gdpr-compliance", "data-residency", "eu-performance"]

    # Uptime checks
    enable_uptime_checks = true
    uptime_check_frequency = 60  # seconds
    uptime_check_regions = ["EUROPE"]

    # APM
    enable_apm = true
    enable_profiler = true
    enable_trace = true
    trace_sampling_rate = 0.1

    # Privacy settings
    anonymize_ip = true
    mask_sensitive_data = true
  }

  # Security configuration with GDPR requirements
  security_config = {
    # KMS configuration
    kms = {
      key_ring = "staging-${local.region_short}-keyring"
      rotation_period = "2592000s"  # 30 days
      algorithm = "GOOGLE_SYMMETRIC_ENCRYPTION"
      protection_level = "SOFTWARE"
      enable_automatic_rotation = true
      location = local.region
    }

    # Secret Manager
    secret_manager = {
      replication = "USER_MANAGED"
      locations = ["europe-west1", "europe-west4"]  # EU only
      enable_cmek = true
      enable_audit_logs = true
    }

    # VPC Service Controls
    enable_vpc_sc = true
    vpc_sc_perimeter = "staging-eu-perimeter"

    # Binary Authorization
    enable_binary_authorization = true
    require_attestations = true

    # Security Command Center
    enable_scc = true
    enable_scc_notifications = true

    # Data Loss Prevention
    enable_dlp = true
    dlp_inspection_templates = ["gdpr-template", "pii-template"]

    # Web Security
    enable_cloud_armor = true
    enable_ddos_protection = true
    geo_blocking = {
      allowed_countries = ["EU", "EEA"]
      blocked_countries = []
    }

    # Identity & Access
    enable_workload_identity = true
    enable_identity_aware_proxy = true

    # GDPR specific
    gdpr_compliance = {
      data_residency_enforced = true
      allowed_locations = ["europe-west1", "europe-west4", "europe-north1"]
      encryption_at_rest = true
      encryption_in_transit = true
      audit_logging_enabled = true
      data_retention_days = 730  # 2 years
      right_to_be_forgotten = true
      data_portability = true
    }
  }

  # Backup configuration
  backup_config = {
    # Backup schedules (CET timezone)
    backup_schedule = "0 1 * * *"  # 1 AM CET

    # Retention
    backup_retention_days = 30
    backup_retention_weekly = 12  # weeks
    backup_retention_monthly = 6  # months
    backup_retention_yearly = 2   # years (GDPR requirement)

    # Backup location (EU only)
    backup_location = local.region
    backup_storage_class = "NEARLINE"

    # Cross-region backup (within EU)
    enable_cross_region_backup = true
    cross_region_backup_location = "europe-west4"

    # Backup testing
    enable_backup_testing = true
    backup_test_frequency = "weekly"

    # GDPR compliance
    encrypt_backups = true
    immutable_backups = true
  }

  # Disaster recovery configuration
  dr_config = {
    # DR enablement
    enable_dr = true

    # DR region (within EU)
    dr_region = "europe-west4"

    # RPO/RTO targets
    rpo_minutes = 60   # 1 hour
    rto_minutes = 240  # 4 hours

    # DR testing
    enable_dr_testing = true
    dr_test_frequency = "monthly"
  }

  # Cost optimization
  cost_optimization = {
    # Use preemptible/spot instances
    use_preemptible = false
    use_spot = true
    spot_percentage = 30

    # Use committed use discounts
    use_committed_use_discounts = true
    committed_use_cpu_cores = 20
    committed_use_memory_gb = 80

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
    compliance   = "gdpr"
    data_residency = "europe"
  }

  # Feature flags for this region
  feature_flags = {
    enable_gke_autopilot = true
    enable_anthos       = true
    enable_cloud_run    = true
    enable_cloud_functions = true
    enable_app_engine   = false
    enable_dataflow     = true
    enable_dataproc     = true
    enable_composer     = false
    enable_cloud_cdn    = true
    enable_cloud_armor  = true
    enable_api_gateway  = true
    enable_apigee      = false
  }
}