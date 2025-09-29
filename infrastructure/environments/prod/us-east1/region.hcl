# Production - US East 1 Region Configuration
# Secondary production region for disaster recovery and East Coast presence

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
    region_tier = "platinum"
    is_primary  = false
    is_dr       = true
  }

  # Networking configuration for this region
  network_config = {
    # VPC CIDR ranges
    vpc_cidr_primary   = "10.1.0.0/16"
    vpc_cidr_secondary = "10.101.0.0/16"

    # Subnet configurations with micro-segmentation
    subnets = {
      public_lb = {
        cidr = "10.1.0.0/22"
        purpose = "load_balancers"
        flow_logs = true
      }

      public_nat = {
        cidr = "10.1.4.0/22"
        purpose = "nat_gateways"
        flow_logs = true
      }

      private_web = {
        cidr = "10.1.8.0/21"
        secondary_ranges = {
          pods     = "10.101.0.0/17"
          services = "10.101.128.0/20"
        }
        purpose = "web_tier"
        flow_logs = true
      }

      private_app = {
        cidr = "10.1.16.0/21"
        secondary_ranges = {
          pods     = "10.101.144.0/17"
          services = "10.101.208.0/20"
        }
        purpose = "application_tier"
        flow_logs = true
      }

      private_data = {
        cidr = "10.1.24.0/21"
        secondary_ranges = {}
        purpose = "database_tier"
        flow_logs = true
        private_ip_google_access = true
      }

      management = {
        cidr = "10.1.32.0/21"
        secondary_ranges = {}
        purpose = "management"
        flow_logs = true
      }

      dmz = {
        cidr = "10.1.40.0/21"
        secondary_ranges = {}
        purpose = "dmz"
        flow_logs = true
      }

      security = {
        cidr = "10.1.48.0/21"
        secondary_ranges = {}
        purpose = "security_appliances"
        flow_logs = true
      }
    }

    # NAT configuration
    enable_nat = true
    nat_ip_count = 6
    enable_nat_logging = true
    nat_log_config = {
      enable = true
      filter = "ALL"
    }

    # VPN configuration
    enable_vpn = true
    vpn_peer_networks = ["prod-usc1-vpc", "partner-network-east"]
    enable_ha_vpn = true

    # Interconnect configuration
    enable_interconnect = true
    interconnect_type = "PARTNER"
    interconnect_bandwidth = "5Gbps"

    # Private Google Access
    enable_private_google_access = true
    enable_private_service_connect = true

    # Network peering
    enable_vpc_peering = true
    peer_networks = {
      primary = {
        network = "projects/prod-project/global/networks/prod-usc1-vpc"
        export_custom_routes = true
        import_custom_routes = true
      }
      staging = {
        network = "projects/staging-project/global/networks/staging-use1-vpc"
        export_custom_routes = false
        import_custom_routes = false
      }
    }

    # Advanced networking
    enable_cloud_cdn = true
    enable_cloud_armor = true
    enable_traffic_director = true
  }

  # Compute resources configuration for DR
  compute_config = {
    # GKE cluster configuration - DR cluster
    gke_clusters = {
      dr_primary = {
        name               = "prod-${local.region_short}-dr-primary"
        initial_node_count = 8
        min_node_count    = 3
        max_node_count    = 80
        machine_type      = "n2-standard-8"
        disk_size_gb      = 500
        disk_type         = "pd-ssd"
        preemptible       = false
        spot              = false
        auto_repair       = true
        auto_upgrade      = false
        enable_autopilot  = false
        enable_shielded_nodes = true
        enable_network_policy = true
        enable_private_cluster = true
        enable_private_endpoint = false
        master_ipv4_cidr = "172.17.0.0/28"
        enable_vertical_pod_autoscaling = true
        enable_cluster_autoscaling = true
        enable_workload_identity = true
        enable_binary_authorization = true
        enable_intranode_visibility = true
        enable_confidential_nodes = true
        release_channel = "STABLE"

        # DR specific configurations
        enable_regional_cluster = true
        cluster_locations = ["us-east1-b", "us-east1-c", "us-east1-d"]
        enable_pod_security_policy = true
        enable_network_egress_metering = true
        enable_resource_consumption_metering = true
      }

      dr_secondary = {
        name               = "prod-${local.region_short}-dr-secondary"
        initial_node_count = 4
        min_node_count    = 2
        max_node_count    = 40
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
        master_ipv4_cidr = "172.17.0.16/28"
        enable_workload_identity = true
        release_channel = "STABLE"
      }
    }

    # Instance groups for DR
    instance_groups = {
      web = {
        size         = 8
        machine_type = "n2-standard-4"
        disk_size    = 200
        disk_type    = "pd-ssd"
        preemptible  = false
        enable_auto_healing = true
        health_check_interval = 10
        enable_stateful = false

        # DR specific
        standby_mode = true
        auto_activation = true
      }

      backend = {
        size         = 15
        machine_type = "n2-standard-8"
        disk_size    = 500
        disk_type    = "pd-ssd"
        preemptible  = false
        enable_auto_healing = true
        health_check_interval = 10
        enable_stateful = true

        # DR specific
        standby_mode = true
        auto_activation = true
      }

      workers = {
        size         = 10
        machine_type = "n2-highmem-4"
        disk_size    = 300
        disk_type    = "pd-ssd"
        preemptible  = false
        enable_auto_healing = true
        health_check_interval = 10

        # DR specific
        standby_mode = true
        auto_activation = true
      }

      cache = {
        size         = 4
        machine_type = "n2-highmem-8"
        disk_size    = 100
        disk_type    = "pd-ssd"
        preemptible  = false
        enable_auto_healing = true

        # DR specific
        standby_mode = true
        auto_activation = true
      }
    }

    # Cloud Run configuration for DR
    cloud_run = {
      cpu_limit    = "8"
      memory_limit = "32Gi"
      max_instances = 800
      min_instances = 3
      concurrency  = 1000
      enable_vpc_connector = true
      enable_binary_authorization = true
      enable_cmek = true

      # DR specific
      traffic_split = {
        latest_revision = 100
        previous_revision = 0
      }
    }

    # Cloud Functions configuration for DR
    cloud_functions = {
      available_memory_mb = 8192
      timeout            = 540
      max_instances      = 800
      min_instances      = 3
      enable_vpc_connector = true
      enable_cmek = true

      # DR specific
      enable_retry_on_failure = true
      retry_count = 3
    }

    # Auto-scaling policies for DR
    autoscaling_policies = {
      web_tier = {
        min_replicas = 3
        max_replicas = 80
        cpu_utilization = 65
        load_balancing_utilization = 0.65
        scale_down_control = {
          max_scaled_down_replicas = 3
          time_window = 600
        }

        # DR specific
        rapid_scale_up = true
        scale_up_multiplier = 2
      }

      app_tier = {
        min_replicas = 8
        max_replicas = 160
        cpu_utilization = 70
        memory_utilization = 75
        custom_metrics = [
          {
            name = "queue_depth"
            target = 100
          },
          {
            name = "request_latency"
            target = 200
          }
        ]

        # DR specific
        rapid_scale_up = true
        scale_up_multiplier = 2
      }
    }
  }

  # Storage configuration for DR
  storage_config = {
    # GCS buckets with DR replication
    buckets = {
      static_assets = {
        storage_class = "STANDARD"
        location_type = "MULTI-REGION"
        versioning = true
        enable_cdn = true
        uniform_bucket_level_access = true

        # DR specific
        turbo_replication = true
        cross_region_replication = {
          destination_bucket = "prod-usc1-static-assets"
          replication_time = "15m"
        }

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
          default_kms_key = "projects/prod-project/locations/us-east1/keyRings/prod-use1-keyring/cryptoKeys/gcs-key"
        }

        # DR specific
        turbo_replication = true
        cross_region_replication = {
          destination_bucket = "prod-usc1-application-data"
          replication_time = "15m"
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
          }
        ]
        retention_policy = {
          retention_period = 31536000  # 365 days
          is_locked = true
        }

        # DR specific
        geo_redundant = true
        dual_region_configuration = {
          primary = "us-east1"
          secondary = "us-central1"
        }
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

        # DR specific
        immediate_consistency = true
        strong_consistency = true
      }
    }

    # Filestore configuration for DR
    filestore_instances = {
      dr_primary = {
        tier = "ENTERPRISE"
        capacity_gb = 8192
        enable_snapshots = true
        snapshot_schedule = "0 */2 * * *"  # Every 2 hours

        # DR specific
        replication_config = {
          enable = true
          source_instance = "prod-usc1-primary"
          replication_interval = "5m"
        }
      }

      dr_secondary = {
        tier = "HIGH_SCALE_SSD"
        capacity_gb = 4096
        enable_snapshots = true

        # DR specific
        standby_mode = true
      }
    }
  }

  # Database configuration for DR
  database_config = {
    # Cloud SQL configuration - DR replicas
    cloud_sql = {
      dr_primary = {
        tier = "db-n1-highmem-32"
        disk_size = 5000
        disk_type = "PD_SSD"
        disk_autoresize = true
        disk_autoresize_limit = 10000
        backup_enabled = true
        backup_start_time = "02:00"
        backup_location = "us"
        transaction_log_retention_days = 7
        retained_backups = 365
        high_availability = true
        availability_type = "REGIONAL"
        point_in_time_recovery = true

        # DR specific - replica of primary
        replica_configuration = {
          master_instance_name = "prod-usc1-primary"
          failover_target = true
          replica_lag_threshold = 60  # seconds
        }

        read_replicas = 2

        maintenance_window = {
          day          = 7  # Sunday
          hour         = 3  # 3 AM
          update_track = "stable"
        }

        insights_config = {
          query_insights_enabled = true
          query_plans_per_minute = 5
          query_string_length = 2048
          record_application_tags = true
          record_client_address = true
        }

        # DR specific configurations
        automated_backup_replication = {
          enabled = true
          regions = ["us-central1", "europe-west1"]
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
          },
          {
            name = "hot_standby"
            value = "on"
          },
          {
            name = "hot_standby_feedback"
            value = "on"
          }
        ]
      }
    }

    # Firestore configuration for DR
    firestore = {
      type = "FIRESTORE_NATIVE"
      location_id = "nam5"  # Multi-region in US
      concurrency_mode = "OPTIMISTIC"
      app_engine_integration_mode = "DISABLED"
      delete_protection_state = "ENABLED"
      point_in_time_recovery_enablement = "ENABLED"

      # DR specific
      database_type = "MULTI_REGION"
      enable_delete_protection = true
    }

    # Redis configuration for DR
    redis_instances = {
      dr_cache = {
        tier = "STANDARD_HA"
        memory_size_gb = 30
        version = "REDIS_7_0"
        auth_enabled = true
        transit_encryption_mode = "SERVER_AUTHENTICATION"
        replica_count = 2
        read_replicas_mode = "READ_REPLICAS_ENABLED"
        persistence_config = {
          persistence_mode = "RDB"
          rdb_snapshot_period = "THIRTY_MINUTES"
        }

        # DR specific
        replication_config = {
          primary_instance = "prod-usc1-cache"
          sync_mode = "async"
        }
      }

      dr_session = {
        tier = "STANDARD_HA"
        memory_size_gb = 20
        version = "REDIS_7_0"
        auth_enabled = true
        transit_encryption_mode = "SERVER_AUTHENTICATION"
        replica_count = 2

        # DR specific
        replication_config = {
          primary_instance = "prod-usc1-session"
          sync_mode = "async"
        }
      }
    }

    # BigQuery configuration for DR
    bigquery = {
      location = "US"
      default_table_expiration_ms = 31536000000  # 365 days
      default_partition_expiration_ms = 7776000000  # 90 days
      delete_contents_on_destroy = false
      enable_encryption = true
      default_kms_key_name = "projects/prod-project/locations/us/keyRings/prod-use1-keyring/cryptoKeys/bigquery-key"

      # DR specific datasets
      datasets = {
        analytics_replica = {
          friendly_name = "Production Analytics Replica"
          description = "DR replica of main analytics dataset"
          max_time_travel_hours = 168  # 7 days

          # DR specific
          source_dataset = "prod-usc1-analytics"
          replication_interval = "1h"
        }

        ml_replica = {
          friendly_name = "Machine Learning Replica"
          description = "DR replica of ML dataset"
          max_time_travel_hours = 72

          # DR specific
          source_dataset = "prod-usc1-ml"
          replication_interval = "2h"
        }

        realtime_replica = {
          friendly_name = "Real-time Data Replica"
          description = "DR replica of streaming data"
          default_partition_expiration_ms = 2592000000  # 30 days

          # DR specific
          source_dataset = "prod-usc1-realtime"
          replication_interval = "5m"
        }
      }
    }

    # Spanner configuration for DR
    spanner = {
      config = "nam10"  # Multi-region US configuration
      processing_units = 800
      enable_backup = true
      backup_schedule = "0 */4 * * *"  # Every 4 hours
      backup_retention_days = 30
      version_retention_period = "7d"
      enable_drop_protection = true

      # DR specific
      enable_cross_region_backup = true
      cross_region_backup_locations = ["us-central1", "europe-west1"]
      enable_point_in_time_recovery = true
      pitr_retention_days = 7
    }

    # Bigtable configuration for DR
    bigtable_instances = {
      dr_timeseries = {
        cluster_config = {
          cluster_id = "prod-use1-timeseries"
          zone = "us-east1-b"
          num_nodes = 4
          storage_type = "SSD"

          # DR specific
          autoscaling_config = {
            min_nodes = 2
            max_nodes = 8
            cpu_target = 70
          }
        }

        replication_config = {
          cluster_id = "prod-use1-timeseries-replica"
          zone = "us-east1-d"
          num_nodes = 4
          storage_type = "SSD"
        }

        # DR specific
        cross_region_replication = {
          cluster_id = "prod-usc1-timeseries-sync"
          enable_sync = true
          consistency_token = true
        }
      }
    }
  }

  # Monitoring configuration for DR
  monitoring_config = {
    # Log retention
    log_retention_days = 90
    log_buckets = {
      _Required = 90
      _Default = 90
      application = 180
      audit = 2555  # 7 years
      security = 365
      dr_events = 180  # DR specific
    }

    # Metrics retention
    metrics_retention_days = 180

    # Alerting
    enable_alerting = true
    notification_channels = ["email", "slack", "pagerduty", "opsgenie", "webhook"]

    # Alert policies for DR
    alert_policies = {
      enable_smart_alerts = true
      enable_anomaly_detection = true
      enable_predictive_alerts = true
      alert_auto_close = 3600  # 1 hour
      alert_cooldown = 300  # 5 minutes

      # DR specific alerts
      dr_specific = {
        replication_lag = {
          threshold = 300  # 5 minutes
          severity = "CRITICAL"
        }
        failover_readiness = {
          check_interval = 300  # 5 minutes
          severity = "HIGH"
        }
        backup_validation = {
          check_interval = 3600  # 1 hour
          severity = "MEDIUM"
        }
      }
    }

    # Dashboards
    create_default_dashboards = true
    custom_dashboards = [
      "dr-status",
      "replication-health",
      "failover-readiness",
      "rpo-rto-tracking",
      "cross-region-latency",
      "backup-status",
      "regional-comparison",
      "traffic-distribution",
      "resource-utilization-dr",
      "cost-analysis-dr"
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

    # SLOs for DR
    slo_configs = {
      dr_availability = {
        sli_type = "availability"
        goal = 0.999  # 99.9% for DR
        rolling_period_days = 30
      }

      dr_failover_time = {
        sli_type = "latency"
        threshold_value = 3600000  # 60 minutes in ms
        goal = 0.99  # 99%
        rolling_period_days = 30
      }

      dr_data_freshness = {
        sli_type = "freshness"
        threshold_value = 900  # 15 minutes
        goal = 0.999  # 99.9%
        rolling_period_days = 30
      }
    }
  }

  # Security configuration for DR
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
        dr_specific = {
          purpose = "ENCRYPT_DECRYPT"
          rotation_period = "604800s"  # 7 days
        }
      }
    }

    # Secret Manager
    secret_manager = {
      replication = "USER_MANAGED"
      replicas = [
        {
          location = "us-east1"
        },
        {
          location = "us-central1"
        }
      ]
      enable_cmek = true
      enable_audit_logs = true
      enable_secret_rotation = true
      rotation_period = "86400s"  # 1 day for critical secrets
    }

    # VPC Service Controls
    enable_vpc_sc = true
    vpc_sc_perimeter = "prod-use1-perimeter"
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
      dr_policy = {
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
            description = "Deny traffic from blacklisted IPs"
          },
          {
            action = "rate_limit"
            priority = 2000
            rate_limit_options = {
              conform_action = "allow"
              exceed_action = "deny(429)"
              rate_limit_threshold = {
                count = 1000
                interval_sec = 60
              }
            }
            description = "Rate limiting for DR region"
          }
        ]

        # DR specific rules
        adaptive_protection = {
          enable = true
          auto_deploy = true
        }
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

  # Backup configuration for DR
  backup_config = {
    # Backup schedules
    backup_schedule = "0 */6 * * *"  # Every 6 hours

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
    cross_region_backup_locations = ["us-central1", "europe-west1", "asia-southeast1"]

    # Backup testing
    enable_backup_testing = true
    backup_test_frequency = "daily"
    enable_automated_recovery_testing = true

    # Continuous backup
    enable_continuous_backup = true
    continuous_backup_retention = "7d"

    # DR specific backup settings
    dr_backup_config = {
      enable_instant_recovery = true
      enable_cross_region_restore = true
      enable_backup_validation = true
      validation_frequency = "hourly"
      backup_encryption = "customer_managed"
      immutable_backups = true
    }
  }

  # Disaster recovery configuration
  dr_config = {
    # DR enablement
    enable_dr = true
    dr_role = "secondary"

    # Primary region
    primary_region = "us-central1"

    # RPO/RTO targets
    rpo_minutes = 15   # 15 minutes
    rto_minutes = 60   # 1 hour

    # DR testing
    enable_dr_testing = true
    dr_test_frequency = "weekly"
    dr_test_scenarios = [
      "complete_failover",
      "partial_failover",
      "database_failover",
      "storage_failover",
      "network_partition",
      "application_failover"
    ]

    # Automated failover
    enable_automatic_failover = true
    failover_threshold_minutes = 5
    failback_delay_minutes = 30

    # Failover conditions
    failover_conditions = {
      health_check_failures = 3
      replication_lag_threshold = 300  # seconds
      error_rate_threshold = 0.1  # 10%
    }

    # Replication
    enable_multi_region_replication = true
    replication_regions = ["us-central1", "europe-west1", "asia-southeast1"]

    # DR orchestration
    orchestration = {
      enable_automated_orchestration = true
      orchestration_engine = "cloud_workflows"
      enable_runbook_automation = true
      enable_communication_automation = true
    }
  }

  # Cost optimization for DR
  cost_optimization = {
    # Committed use discounts
    use_committed_use_discounts = true
    committed_use_cpu_cores = 400
    committed_use_memory_gb = 1600
    committed_use_local_ssd_gb = 8000

    # Resource optimization
    enable_rightsizing_recommendations = true
    enable_idle_resource_recommendations = true
    enable_unattached_disk_recommendations = true

    # DR specific cost optimization
    dr_cost_optimization = {
      enable_standby_discounts = true
      enable_preemptible_failover = false  # Not for production DR
      optimize_replication_costs = true
      enable_tiered_storage = true
    }

    # Budget alerts
    enable_budget_alerts = true
    budget_amount = 40000  # Lower than primary
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
    dr_role     = "secondary"
    dr_priority = "1"
  }

  # Feature flags for DR region
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
    enable_apigee      = false  # Only in primary region
    enable_traffic_director = true
    enable_service_mesh = true

    # DR specific features
    enable_instant_failover = true
    enable_automated_recovery = true
    enable_cross_region_load_balancing = true
  }
}