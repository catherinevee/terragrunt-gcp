# Production - US Central 1 Region Configuration
# Primary production region with maximum availability and performance

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
    region_tier = "platinum"
    is_primary  = true
    is_dr       = false
  }

  # Networking configuration for this region
  network_config = {
    # VPC CIDR ranges
    vpc_cidr_primary   = "10.0.0.0/16"
    vpc_cidr_secondary = "10.100.0.0/16"

    # Subnet configurations with micro-segmentation
    subnets = {
      public_lb = {
        cidr = "10.0.0.0/22"
        purpose = "load_balancers"
        flow_logs = true
      }

      public_nat = {
        cidr = "10.0.4.0/22"
        purpose = "nat_gateways"
        flow_logs = true
      }

      private_web = {
        cidr = "10.0.8.0/21"
        secondary_ranges = {
          pods     = "10.100.0.0/17"
          services = "10.100.128.0/20"
        }
        purpose = "web_tier"
        flow_logs = true
      }

      private_app = {
        cidr = "10.0.16.0/21"
        secondary_ranges = {
          pods     = "10.100.144.0/17"
          services = "10.100.208.0/20"
        }
        purpose = "application_tier"
        flow_logs = true
      }

      private_data = {
        cidr = "10.0.24.0/21"
        secondary_ranges = {}
        purpose = "database_tier"
        flow_logs = true
        private_ip_google_access = true
      }

      management = {
        cidr = "10.0.32.0/21"
        secondary_ranges = {}
        purpose = "management"
        flow_logs = true
      }

      dmz = {
        cidr = "10.0.40.0/21"
        secondary_ranges = {}
        purpose = "dmz"
        flow_logs = true
      }

      security = {
        cidr = "10.0.48.0/21"
        secondary_ranges = {}
        purpose = "security_appliances"
        flow_logs = true
      }
    }

    # NAT configuration
    enable_nat = true
    nat_ip_count = 8
    enable_nat_logging = true
    nat_log_config = {
      enable = true
      filter = "ALL"
    }

    # VPN configuration
    enable_vpn = true
    vpn_peer_networks = ["partner-network-1", "partner-network-2"]
    enable_ha_vpn = true

    # Interconnect configuration
    enable_interconnect = true
    interconnect_type = "DEDICATED"
    interconnect_bandwidth = "10Gbps"

    # Private Google Access
    enable_private_google_access = true
    enable_private_service_connect = true

    # Network peering
    enable_vpc_peering = true
    peer_networks = {
      staging = {
        network = "projects/staging-project/global/networks/staging-vpc"
        export_custom_routes = true
        import_custom_routes = false
      }
      dev = {
        network = "projects/dev-project/global/networks/dev-vpc"
        export_custom_routes = false
        import_custom_routes = false
      }
    }

    # Advanced networking
    enable_cloud_cdn = true
    enable_cloud_armor = true
    enable_traffic_director = true
  }

  # Compute resources configuration
  compute_config = {
    # GKE cluster configuration - Primary production cluster
    gke_clusters = {
      primary = {
        name               = "prod-${local.region_short}-primary"
        initial_node_count = 10
        min_node_count    = 5
        max_node_count    = 100
        machine_type      = "n2-standard-8"
        disk_size_gb      = 500
        disk_type         = "pd-ssd"
        preemptible       = false
        spot              = false
        auto_repair       = true
        auto_upgrade      = false  # Manual control for production
        enable_autopilot  = false
        enable_shielded_nodes = true
        enable_network_policy = true
        enable_private_cluster = true
        enable_private_endpoint = false
        master_ipv4_cidr = "172.16.0.0/28"
        enable_vertical_pod_autoscaling = true
        enable_cluster_autoscaling = true
        enable_workload_identity = true
        enable_binary_authorization = true
        enable_intranode_visibility = true
        enable_confidential_nodes = true
        release_channel = "STABLE"
      }

      secondary = {
        name               = "prod-${local.region_short}-secondary"
        initial_node_count = 5
        min_node_count    = 3
        max_node_count    = 50
        machine_type      = "n2-standard-8"
        disk_size_gb      = 300
        disk_type         = "pd-ssd"
        preemptible       = false
        spot              = false
        auto_repair       = true
        auto_upgrade      = false
        enable_autopilot  = false
        enable_shielded_nodes = true
        enable_network_policy = true
        enable_private_cluster = true
        master_ipv4_cidr = "172.16.0.16/28"
        enable_workload_identity = true
        release_channel = "STABLE"
      }

      gpu_cluster = {
        name               = "prod-${local.region_short}-gpu"
        initial_node_count = 2
        min_node_count    = 0
        max_node_count    = 10
        machine_type      = "n1-standard-16"
        accelerator_type  = "nvidia-tesla-t4"
        accelerator_count = 2
        disk_size_gb      = 500
        disk_type         = "pd-ssd"
        preemptible       = false
        auto_repair       = true
        auto_upgrade      = false
        enable_autopilot  = false
        enable_shielded_nodes = true
        enable_private_cluster = true
        master_ipv4_cidr = "172.16.0.32/28"
      }
    }

    # Instance groups
    instance_groups = {
      web = {
        size         = 10
        machine_type = "n2-standard-4"
        disk_size    = 200
        disk_type    = "pd-ssd"
        preemptible  = false
        enable_auto_healing = true
        health_check_interval = 10
        enable_stateful = false
      }

      backend = {
        size         = 20
        machine_type = "n2-standard-8"
        disk_size    = 500
        disk_type    = "pd-ssd"
        preemptible  = false
        enable_auto_healing = true
        health_check_interval = 10
        enable_stateful = true
      }

      workers = {
        size         = 15
        machine_type = "n2-highmem-4"
        disk_size    = 300
        disk_type    = "pd-ssd"
        preemptible  = false
        enable_auto_healing = true
        health_check_interval = 10
      }

      cache = {
        size         = 5
        machine_type = "n2-highmem-8"
        disk_size    = 100
        disk_type    = "pd-ssd"
        preemptible  = false
        enable_auto_healing = true
      }
    }

    # Cloud Run configuration
    cloud_run = {
      cpu_limit    = "8"
      memory_limit = "32Gi"
      max_instances = 1000
      min_instances = 5
      concurrency  = 1000
      enable_vpc_connector = true
      enable_binary_authorization = true
      enable_cmek = true
    }

    # Cloud Functions configuration
    cloud_functions = {
      available_memory_mb = 8192
      timeout            = 540
      max_instances      = 1000
      min_instances      = 5
      enable_vpc_connector = true
      enable_cmek = true
    }

    # Auto-scaling policies
    autoscaling_policies = {
      web_tier = {
        min_replicas = 5
        max_replicas = 100
        cpu_utilization = 60
        load_balancing_utilization = 0.6
        scale_down_control = {
          max_scaled_down_replicas = 5
          time_window = 600
        }
      }

      app_tier = {
        min_replicas = 10
        max_replicas = 200
        cpu_utilization = 70
        memory_utilization = 75
        custom_metrics = [
          {
            name = "queue_depth"
            target = 100
          }
        ]
      }
    }
  }

  # Storage configuration
  storage_config = {
    # GCS buckets with lifecycle management
    buckets = {
      static_assets = {
        storage_class = "STANDARD"
        location_type = "MULTI-REGION"
        versioning = true
        enable_cdn = true
        uniform_bucket_level_access = true
        lifecycle_rules = [
          {
            age_days = 90
            action   = "SetStorageClass"
            storage_class = "NEARLINE"
          },
          {
            age_days = 365
            action   = "SetStorageClass"
            storage_class = "COLDLINE"
          }
        ]
      }

      application_data = {
        storage_class = "STANDARD"
        versioning = true
        retention_policy = {
          retention_period = 7776000  # 90 days
        }
        encryption = {
          default_kms_key = "projects/prod-project/locations/us-central1/keyRings/prod-keyring/cryptoKeys/gcs-key"
        }
      }

      backups = {
        storage_class = "NEARLINE"
        versioning = true
        lifecycle_rules = [
          {
            age_days = 365
            action   = "SetStorageClass"
            storage_class = "ARCHIVE"
          },
          {
            age_days = 2555
            action   = "Delete"
          }
        ]
        retention_policy = {
          retention_period = 31536000  # 365 days
          is_locked = true
        }
      }

      logs = {
        storage_class = "STANDARD"
        lifecycle_rules = [
          {
            age_days = 90
            action   = "SetStorageClass"
            storage_class = "NEARLINE"
          },
          {
            age_days = 365
            action   = "SetStorageClass"
            storage_class = "ARCHIVE"
          }
        ]
      }

      disaster_recovery = {
        storage_class = "MULTI-REGIONAL"
        location = "US"
        versioning = true
        turbo_replication = true
        retention_policy = {
          retention_period = 63072000  # 2 years
          is_locked = true
        }
      }
    }

    # Filestore configuration
    filestore_instances = {
      primary = {
        tier = "ENTERPRISE"
        capacity_gb = 10240
        enable_snapshots = true
        snapshot_schedule = "0 */4 * * *"
      }

      secondary = {
        tier = "HIGH_SCALE_SSD"
        capacity_gb = 5120
        enable_snapshots = true
      }
    }
  }

  # Database configuration
  database_config = {
    # Cloud SQL configuration - Primary production database
    cloud_sql = {
      primary = {
        tier = "db-n1-highmem-32"
        disk_size = 5000
        disk_type = "PD_SSD"
        disk_autoresize = true
        disk_autoresize_limit = 10000
        backup_enabled = true
        backup_start_time = "01:00"
        backup_location = "us"
        transaction_log_retention_days = 7
        retained_backups = 365
        high_availability = true
        availability_type = "REGIONAL"
        point_in_time_recovery = true

        replica_configuration = {
          failover_target = true
        }

        read_replicas = 3

        maintenance_window = {
          day          = 7  # Sunday
          hour         = 2  # 2 AM
          update_track = "stable"
        }

        insights_config = {
          query_insights_enabled = true
          query_plans_per_minute = 5
          query_string_length = 2048
          record_application_tags = true
          record_client_address = true
        }

        database_flags = [
          {
            name = "max_connections"
            value = "1000"
          },
          {
            name = "log_checkpoints"
            value = "on"
          },
          {
            name = "log_connections"
            value = "on"
          },
          {
            name = "log_disconnections"
            value = "on"
          },
          {
            name = "log_lock_waits"
            value = "on"
          },
          {
            name = "log_temp_files"
            value = "0"
          }
        ]
      }
    }

    # Firestore configuration
    firestore = {
      type = "FIRESTORE_NATIVE"
      location_id = "nam5"  # Multi-region in US
      concurrency_mode = "OPTIMISTIC"
      app_engine_integration_mode = "DISABLED"
      delete_protection_state = "ENABLED"
      point_in_time_recovery_enablement = "ENABLED"
    }

    # Redis configuration
    redis_instances = {
      cache = {
        tier = "STANDARD_HA"
        memory_size_gb = 30
        version = "REDIS_7_0"
        auth_enabled = true
        transit_encryption_mode = "SERVER_AUTHENTICATION"
        replica_count = 2
        read_replicas_mode = "READ_REPLICAS_ENABLED"
        persistence_config = {
          persistence_mode = "RDB"
          rdb_snapshot_period = "ONE_HOUR"
        }
      }

      session = {
        tier = "STANDARD_HA"
        memory_size_gb = 20
        version = "REDIS_7_0"
        auth_enabled = true
        transit_encryption_mode = "SERVER_AUTHENTICATION"
        replica_count = 2
      }
    }

    # BigQuery configuration
    bigquery = {
      location = "US"
      default_table_expiration_ms = 31536000000  # 365 days
      default_partition_expiration_ms = 7776000000  # 90 days
      delete_contents_on_destroy = false
      enable_encryption = true
      default_kms_key_name = "projects/prod-project/locations/us/keyRings/prod-keyring/cryptoKeys/bigquery-key"

      datasets = {
        analytics = {
          friendly_name = "Production Analytics"
          description = "Main analytics dataset"
          max_time_travel_hours = 168  # 7 days
        }

        ml = {
          friendly_name = "Machine Learning"
          description = "ML model training data"
          max_time_travel_hours = 72
        }

        realtime = {
          friendly_name = "Real-time Data"
          description = "Streaming data ingestion"
          default_partition_expiration_ms = 2592000000  # 30 days
        }
      }
    }

    # Spanner configuration
    spanner = {
      config = "nam10"  # Multi-region US configuration
      processing_units = 1000
      enable_backup = true
      backup_schedule = "0 */6 * * *"
      backup_retention_days = 30
      version_retention_period = "7d"
      enable_drop_protection = true
    }

    # Bigtable configuration
    bigtable_instances = {
      timeseries = {
        cluster_config = {
          cluster_id = "prod-usc1-timeseries"
          zone = "us-central1-a"
          num_nodes = 5
          storage_type = "SSD"
        }

        replication_config = {
          cluster_id = "prod-usc1-timeseries-replica"
          zone = "us-central1-f"
          num_nodes = 5
          storage_type = "SSD"
        }
      }
    }
  }

  # Monitoring configuration
  monitoring_config = {
    # Log retention
    log_retention_days = 90
    log_buckets = {
      _Required = 90
      _Default = 90
      application = 180
      audit = 2555  # 7 years
      security = 365
    }

    # Metrics retention
    metrics_retention_days = 180

    # Alerting
    enable_alerting = true
    notification_channels = ["email", "slack", "pagerduty", "opsgenie", "webhook"]

    # Alert policies
    alert_policies = {
      enable_smart_alerts = true
      enable_anomaly_detection = true
      enable_predictive_alerts = true
      alert_auto_close = 3600  # 1 hour
      alert_cooldown = 300  # 5 minutes
    }

    # Dashboards
    create_default_dashboards = true
    custom_dashboards = [
      "executive-summary",
      "service-health",
      "infrastructure-overview",
      "application-performance",
      "security-posture",
      "cost-analysis",
      "slo-compliance",
      "capacity-planning",
      "incident-response",
      "customer-experience"
    ]

    # Uptime checks
    enable_uptime_checks = true
    uptime_check_frequency = 60  # seconds
    uptime_check_regions = [
      "USA", "EUROPE", "SOUTH_AMERICA", "ASIA_PACIFIC"
    ]

    # APM
    enable_apm = true
    enable_profiler = true
    enable_trace = true
    trace_sampling_rate = 0.001  # 0.1% for high volume

    # Synthetic monitoring
    enable_synthetic_monitoring = true
    synthetic_check_frequency = 300  # 5 minutes

    # SLOs
    slo_configs = {
      api_availability = {
        sli_type = "availability"
        goal = 0.9999  # 99.99%
        rolling_period_days = 30
      }

      api_latency = {
        sli_type = "latency"
        threshold_value = 200  # ms
        goal = 0.999  # 99.9%
        rolling_period_days = 30
      }

      error_rate = {
        sli_type = "error_rate"
        goal = 0.001  # 0.1%
        rolling_period_days = 30
      }
    }
  }

  # Security configuration
  security_config = {
    # KMS configuration
    kms = {
      key_ring = "prod-${local.region_short}-keyring"
      rotation_period = "2592000s"  # 30 days
      algorithm = "GOOGLE_SYMMETRIC_ENCRYPTION"
      protection_level = "HSM"
      enable_automatic_rotation = true

      keys = {
        default = {
          purpose = "ENCRYPT_DECRYPT"
          rotation_period = "2592000s"
        }
        database = {
          purpose = "ENCRYPT_DECRYPT"
          rotation_period = "1209600s"  # 14 days
        }
        storage = {
          purpose = "ENCRYPT_DECRYPT"
          rotation_period = "2592000s"
        }
        secrets = {
          purpose = "ENCRYPT_DECRYPT"
          rotation_period = "604800s"  # 7 days
        }
      }
    }

    # Secret Manager
    secret_manager = {
      replication = "AUTOMATIC"
      enable_cmek = true
      enable_audit_logs = true
      enable_secret_rotation = true
      rotation_period = "86400s"  # 1 day for critical secrets
    }

    # VPC Service Controls
    enable_vpc_sc = true
    vpc_sc_perimeter = "prod-perimeter"
    vpc_sc_policy = "strict"

    # Binary Authorization
    enable_binary_authorization = true
    require_attestations = true
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"

    # Security Command Center
    enable_scc = true
    enable_scc_notifications = true
    scc_notification_config = {
      high_severity = ["email", "pagerduty", "slack"]
      medium_severity = ["email", "slack"]
      low_severity = ["email"]
    }

    # Web Security
    enable_cloud_armor = true
    cloud_armor_policies = {
      default = {
        default_rule_action = "allow"
        rules = [
          {
            action = "deny(403)"
            priority = 1000
            match = {
              versioned_expr = "SRC_IPS_V1"
              config = {
                src_ip_ranges = ["9.9.9.0/24"]
              }
            }
            description = "Deny traffic from specific IPs"
          }
        ]
      }
    }
    enable_ddos_protection = true

    # Identity & Access
    enable_workload_identity = true
    enable_identity_aware_proxy = true
    enable_beyondcorp = true

    # Additional security features
    enable_container_analysis = true
    enable_vulnerability_scanning = true
    enable_web_security_scanner = true
    enable_phishing_protection = true
    enable_recaptcha_enterprise = true
  }

  # Backup configuration
  backup_config = {
    # Backup schedules
    backup_schedule = "0 0 * * *"  # Midnight daily

    # Retention policies
    backup_retention_days = 90
    backup_retention_weekly = 52  # 1 year
    backup_retention_monthly = 84  # 7 years
    backup_retention_yearly = 10  # 10 years

    # Backup location
    backup_location = "US"  # Multi-region
    backup_storage_class = "NEARLINE"

    # Cross-region backup
    enable_cross_region_backup = true
    cross_region_backup_locations = ["us-east1", "europe-west1", "asia-southeast1"]

    # Backup testing
    enable_backup_testing = true
    backup_test_frequency = "daily"
    enable_automated_recovery_testing = true

    # Continuous backup
    enable_continuous_backup = true
    continuous_backup_retention = "7d"
  }

  # Disaster recovery configuration
  dr_config = {
    # DR enablement
    enable_dr = true

    # DR region
    dr_region = "us-east1"

    # RPO/RTO targets
    rpo_minutes = 15   # 15 minutes
    rto_minutes = 60   # 1 hour

    # DR testing
    enable_dr_testing = true
    dr_test_frequency = "weekly"

    # Automated failover
    enable_automatic_failover = true
    failover_threshold_minutes = 5
    failback_delay_minutes = 30

    # Replication
    enable_multi_region_replication = true
    replication_regions = ["us-east1", "europe-west1", "asia-southeast1"]
  }

  # Cost optimization
  cost_optimization = {
    # Committed use discounts
    use_committed_use_discounts = true
    committed_use_cpu_cores = 500
    committed_use_memory_gb = 2000
    committed_use_local_ssd_gb = 10000

    # Resource optimization
    enable_rightsizing_recommendations = true
    enable_idle_resource_recommendations = true
    enable_unattached_disk_recommendations = true

    # Budget alerts
    enable_budget_alerts = true
    budget_amount = 50000
    alert_thresholds = [50, 75, 90, 95, 100, 110]
  }

  # Region labels
  region_labels = {
    region       = local.region
    region_short = local.region_short
    region_type  = local.region_config.region_type
    region_tier  = local.region_config.region_tier
    environment  = "production"
    cost_center  = "operations"
    managed_by   = "terragrunt"
    criticality  = "mission-critical"
    sla_tier    = "platinum"
  }

  # Feature flags for this region
  feature_flags = {
    enable_gke_autopilot = true
    enable_anthos       = true
    enable_cloud_run    = true
    enable_cloud_functions = true
    enable_app_engine   = true
    enable_dataflow     = true
    enable_dataproc     = true
    enable_composer     = true
    enable_cloud_cdn    = true
    enable_cloud_armor  = true
    enable_api_gateway  = true
    enable_apigee      = true
    enable_traffic_director = true
    enable_service_mesh = true
  }
}