# Production - Europe West 1 Region Configuration
# European production region for GDPR compliance and EU presence

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
    region_tier = "platinum"
    is_primary  = false
    is_dr       = false
    is_compliance = true  # GDPR compliance region
  }

  # Networking configuration for this region with GDPR compliance
  network_config = {
    # VPC CIDR ranges
    vpc_cidr_primary   = "10.2.0.0/16"
    vpc_cidr_secondary = "10.102.0.0/16"

    # Subnet configurations with micro-segmentation
    subnets = {
      public_lb = {
        cidr = "10.2.0.0/22"
        purpose = "load_balancers"
        flow_logs = true
        flow_logs_metadata = "INCLUDE_ALL"  # GDPR audit requirement
      }

      public_nat = {
        cidr = "10.2.4.0/22"
        purpose = "nat_gateways"
        flow_logs = true
        flow_logs_metadata = "INCLUDE_ALL"
      }

      private_web = {
        cidr = "10.2.8.0/21"
        secondary_ranges = {
          pods     = "10.102.0.0/17"
          services = "10.102.128.0/20"
        }
        purpose = "web_tier"
        flow_logs = true
        flow_logs_metadata = "INCLUDE_ALL"
      }

      private_app = {
        cidr = "10.2.16.0/21"
        secondary_ranges = {
          pods     = "10.102.144.0/17"
          services = "10.102.208.0/20"
        }
        purpose = "application_tier"
        flow_logs = true
        flow_logs_metadata = "INCLUDE_ALL"
      }

      private_data = {
        cidr = "10.2.24.0/21"
        secondary_ranges = {}
        purpose = "database_tier"
        flow_logs = true
        flow_logs_metadata = "INCLUDE_ALL"
        private_ip_google_access = true
      }

      management = {
        cidr = "10.2.32.0/21"
        secondary_ranges = {}
        purpose = "management"
        flow_logs = true
        flow_logs_metadata = "INCLUDE_ALL"
      }

      dmz = {
        cidr = "10.2.40.0/21"
        secondary_ranges = {}
        purpose = "dmz"
        flow_logs = true
        flow_logs_metadata = "INCLUDE_ALL"
      }

      security = {
        cidr = "10.2.48.0/21"
        secondary_ranges = {}
        purpose = "security_appliances"
        flow_logs = true
        flow_logs_metadata = "INCLUDE_ALL"
      }

      gdpr_sensitive = {
        cidr = "10.2.56.0/21"
        secondary_ranges = {}
        purpose = "gdpr_sensitive_data"
        flow_logs = true
        flow_logs_metadata = "INCLUDE_ALL"
        enable_private_endpoint = true
      }
    }

    # NAT configuration
    enable_nat = true
    nat_ip_count = 4
    enable_nat_logging = true
    nat_log_config = {
      enable = true
      filter = "ALL"
    }

    # VPN configuration
    enable_vpn = true
    vpn_peer_networks = ["prod-usc1-vpc", "prod-use1-vpc", "eu-partner-network"]
    enable_ha_vpn = true

    # Interconnect configuration for EU
    enable_interconnect = true
    interconnect_type = "PARTNER"
    interconnect_bandwidth = "5Gbps"
    interconnect_location = "Brussels"

    # Private Google Access
    enable_private_google_access = true
    enable_private_service_connect = true

    # Network peering
    enable_vpc_peering = true
    peer_networks = {
      us_primary = {
        network = "projects/prod-project/global/networks/prod-usc1-vpc"
        export_custom_routes = false
        import_custom_routes = false
      }
      us_secondary = {
        network = "projects/prod-project/global/networks/prod-use1-vpc"
        export_custom_routes = false
        import_custom_routes = false
      }
    }

    # Advanced networking
    enable_cloud_cdn = true
    enable_cloud_armor = true
    enable_traffic_director = true

    # GDPR specific network controls
    gdpr_network_controls = {
      restrict_data_egress = true
      allowed_egress_regions = ["europe-west1", "europe-west4", "europe-north1"]
      enable_data_residency = true
      enable_traffic_inspection = true
      enable_ssl_inspection = true
    }
  }

  # Compute resources configuration for EU region
  compute_config = {
    # GKE cluster configuration - EU production cluster
    gke_clusters = {
      eu_primary = {
        name               = "prod-${local.region_short}-primary"
        initial_node_count = 6
        min_node_count    = 3
        max_node_count    = 60
        machine_type      = "n2-standard-8"
        disk_size_gb      = 400
        disk_type         = "pd-ssd"
        preemptible       = false
        spot              = false
        auto_repair       = true
        auto_upgrade      = false
        enable_autopilot  = false
        enable_shielded_nodes = true
        enable_network_policy = true
        enable_private_cluster = true
        enable_private_endpoint = true  # GDPR requirement
        master_ipv4_cidr = "172.18.0.0/28"
        enable_vertical_pod_autoscaling = true
        enable_cluster_autoscaling = true
        enable_workload_identity = true
        enable_binary_authorization = true
        enable_intranode_visibility = true
        enable_confidential_nodes = true
        release_channel = "STABLE"

        # EU specific configurations
        enable_regional_cluster = true
        cluster_locations = ["europe-west1-b", "europe-west1-c", "europe-west1-d"]
        resource_usage_bigquery_dataset = "prod_eu_gke_usage"
        enable_network_egress_metering = true
        enable_resource_consumption_metering = true

        # GDPR compliance
        enable_application_layer_encryption = true
        enable_etcd_encryption = true
        database_encryption = {
          state = "ENCRYPTED"
          key_name = "projects/prod-project/locations/europe-west1/keyRings/prod-euw1-keyring/cryptoKeys/gke-key"
        }
      }

      eu_secondary = {
        name               = "prod-${local.region_short}-secondary"
        initial_node_count = 3
        min_node_count    = 2
        max_node_count    = 30
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
        enable_private_endpoint = true
        master_ipv4_cidr = "172.18.0.16/28"
        enable_workload_identity = true
        release_channel = "STABLE"
      }

      gdpr_workloads = {
        name               = "prod-${local.region_short}-gdpr"
        initial_node_count = 4
        min_node_count    = 2
        max_node_count    = 20
        machine_type      = "n2-standard-16"
        disk_size_gb      = 500
        disk_type         = "pd-ssd"
        preemptible       = false
        auto_repair       = true
        auto_upgrade      = false
        enable_autopilot  = false
        enable_shielded_nodes = true
        enable_network_policy = true
        enable_private_cluster = true
        enable_private_endpoint = true
        master_ipv4_cidr = "172.18.0.32/28"
        enable_workload_identity = true
        enable_binary_authorization = true
        enable_confidential_nodes = true

        # GDPR specific node pool
        node_pools = {
          gdpr_sensitive = {
            machine_type = "n2d-standard-16"  # AMD confidential computing
            enable_secure_boot = true
            enable_integrity_monitoring = true
            enable_confidential_nodes = true
            sandbox_type = "gvisor"
          }
        }
      }
    }

    # Instance groups for EU
    instance_groups = {
      web = {
        size         = 6
        machine_type = "n2-standard-4"
        disk_size    = 200
        disk_type    = "pd-ssd"
        preemptible  = false
        enable_auto_healing = true
        health_check_interval = 10
        enable_stateful = false

        # EU specific
        location_preference = {
          zone = "europe-west1-b"
        }
        enable_secure_boot = true
      }

      backend = {
        size         = 12
        machine_type = "n2-standard-8"
        disk_size    = 400
        disk_type    = "pd-ssd"
        preemptible  = false
        enable_auto_healing = true
        health_check_interval = 10
        enable_stateful = true

        # EU specific
        location_preference = {
          zone = "europe-west1-b"
        }
        enable_secure_boot = true
      }

      gdpr_processors = {
        size         = 5
        machine_type = "n2d-standard-8"  # AMD for confidential computing
        disk_size    = 300
        disk_type    = "pd-ssd"
        preemptible  = false
        enable_auto_healing = true
        enable_confidential_compute = true
        enable_secure_boot = true
        enable_vtpm = true
        enable_integrity_monitoring = true
      }
    }

    # Cloud Run configuration for EU
    cloud_run = {
      cpu_limit    = "4"
      memory_limit = "16Gi"
      max_instances = 500
      min_instances = 2
      concurrency  = 500
      enable_vpc_connector = true
      enable_binary_authorization = true
      enable_cmek = true

      # EU specific
      allowed_ingress = "internal-and-cloud-load-balancing"
      execution_environment = "gen2"
      enable_session_affinity = true

      # GDPR compliance
      encryption_key = "projects/prod-project/locations/europe-west1/keyRings/prod-euw1-keyring/cryptoKeys/cloudrun-key"
    }

    # Cloud Functions configuration for EU
    cloud_functions = {
      available_memory_mb = 4096
      timeout            = 540
      max_instances      = 500
      min_instances      = 2
      enable_vpc_connector = true
      enable_cmek = true

      # EU specific
      ingress_settings = "ALLOW_INTERNAL_AND_GCLB"
      vpc_connector_egress_settings = "ALL_TRAFFIC"

      # GDPR compliance
      kms_key_name = "projects/prod-project/locations/europe-west1/keyRings/prod-euw1-keyring/cryptoKeys/functions-key"
    }

    # Auto-scaling policies for EU
    autoscaling_policies = {
      web_tier = {
        min_replicas = 3
        max_replicas = 60
        cpu_utilization = 65
        load_balancing_utilization = 0.65
        scale_down_control = {
          max_scaled_down_replicas = 2
          time_window = 600
        }

        # EU specific
        time_zone = "Europe/Brussels"
      }

      app_tier = {
        min_replicas = 6
        max_replicas = 120
        cpu_utilization = 70
        memory_utilization = 75
        custom_metrics = [
          {
            name = "gdpr_request_queue"
            target = 50
          },
          {
            name = "data_processing_latency"
            target = 100
          }
        ]

        # EU specific
        time_zone = "Europe/Brussels"
      }
    }
  }

  # Storage configuration for EU with GDPR compliance
  storage_config = {
    # GCS buckets with EU data residency
    buckets = {
      static_assets = {
        storage_class = "STANDARD"
        location = "EUROPE-WEST1"
        location_type = "REGION"
        versioning = true
        enable_cdn = true
        uniform_bucket_level_access = true

        # GDPR specific
        data_locations = ["EUROPE"]
        retention_policy = {
          retention_period = 63072000  # 2 years
          is_locked = false
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

        encryption = {
          default_kms_key = "projects/prod-project/locations/europe-west1/keyRings/prod-euw1-keyring/cryptoKeys/gcs-key"
        }
      }

      gdpr_personal_data = {
        storage_class = "STANDARD"
        location = "EUROPE-WEST1"
        location_type = "REGION"
        versioning = true
        uniform_bucket_level_access = true

        # GDPR specific
        data_locations = ["EUROPE"]
        retention_policy = {
          retention_period = 63072000  # 2 years as per GDPR
          is_locked = true
        }

        lifecycle_rules = [
          {
            age_days = 730  # 2 years
            action   = "Delete"
            matches_storage_class = ["STANDARD", "NEARLINE", "COLDLINE"]
          }
        ]

        encryption = {
          default_kms_key = "projects/prod-project/locations/europe-west1/keyRings/prod-euw1-keyring/cryptoKeys/gdpr-key"
        }

        # GDPR compliance features
        enable_bucket_policy_only = true
        requester_pays = false
        default_event_based_hold = false
        labels = {
          data_classification = "pii"
          gdpr_relevant = "true"
          retention_policy = "2years"
        }
      }

      gdpr_audit_logs = {
        storage_class = "STANDARD"
        location = "EUROPE-WEST1"
        location_type = "REGION"
        versioning = true
        uniform_bucket_level_access = true

        # GDPR audit requirements
        data_locations = ["EUROPE"]
        retention_policy = {
          retention_period = 220752000  # 7 years for audit logs
          is_locked = true
        }

        encryption = {
          default_kms_key = "projects/prod-project/locations/europe-west1/keyRings/prod-euw1-keyring/cryptoKeys/audit-key"
        }

        # Immutable audit logs
        object_lifecycle_management = {
          rule = {
            action = {
              type = "SetStorageClass"
              storage_class = "ARCHIVE"
            }
            condition = {
              age = 90
              matches_storage_class = ["STANDARD", "NEARLINE"]
            }
          }
        }
      }

      backups = {
        storage_class = "NEARLINE"
        location = "EUROPE"
        location_type = "MULTI-REGION"
        versioning = true

        # EU specific backup location
        dual_region_configuration = {
          primary = "europe-west1"
          secondary = "europe-west4"
        }

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

        encryption = {
          default_kms_key = "projects/prod-project/locations/europe/keyRings/prod-eu-keyring/cryptoKeys/backup-key"
        }
      }
    }

    # Filestore configuration for EU
    filestore_instances = {
      eu_primary = {
        tier = "ENTERPRISE"
        capacity_gb = 5120
        location = "europe-west1-b"
        enable_snapshots = true
        snapshot_schedule = "0 */4 * * *"

        # GDPR compliance
        kms_key_name = "projects/prod-project/locations/europe-west1/keyRings/prod-euw1-keyring/cryptoKeys/filestore-key"
        enable_audit_logs = true
      }

      eu_gdpr = {
        tier = "HIGH_SCALE_SSD"
        capacity_gb = 2560
        location = "europe-west1-c"
        enable_snapshots = true

        # GDPR specific
        labels = {
          data_residency = "eu"
          gdpr_compliant = "true"
        }
        kms_key_name = "projects/prod-project/locations/europe-west1/keyRings/prod-euw1-keyring/cryptoKeys/gdpr-filestore-key"
      }
    }
  }

  # Database configuration for EU with GDPR compliance
  database_config = {
    # Cloud SQL configuration - EU production database
    cloud_sql = {
      eu_primary = {
        tier = "db-n1-highmem-16"
        disk_size = 3000
        disk_type = "PD_SSD"
        disk_autoresize = true
        disk_autoresize_limit = 6000
        backup_enabled = true
        backup_start_time = "01:00"  # 1 AM CET
        backup_location = "europe-west1"
        transaction_log_retention_days = 7
        retained_backups = 365
        high_availability = true
        availability_type = "REGIONAL"
        point_in_time_recovery = true

        # EU specific location
        location_preference = {
          zone = "europe-west1-b"
          secondary_zone = "europe-west1-c"
          follow_gae_application = ""
        }

        read_replicas = 2

        maintenance_window = {
          day          = 7  # Sunday
          hour         = 2  # 2 AM CET
          update_track = "stable"
        }

        insights_config = {
          query_insights_enabled = true
          query_plans_per_minute = 5
          query_string_length = 2048
          record_application_tags = true
          record_client_address = false  # GDPR - no IP logging
        }

        # GDPR compliance flags
        database_flags = [
          {
            name = "max_connections"
            value = "500"
          },
          {
            name = "log_checkpoints"
            value = "on"
          },
          {
            name = "log_connections"
            value = "off"  # GDPR - no connection logging with IPs
          },
          {
            name = "log_disconnections"
            value = "off"  # GDPR - no disconnection logging with IPs
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
            name = "cloudsql_iam_authentication"
            value = "on"
          },
          {
            name = "cloudsql.enable_pg_audit"
            value = "on"
          }
        ]

        # GDPR specific encryption
        encryption_key_name = "projects/prod-project/locations/europe-west1/keyRings/prod-euw1-keyring/cryptoKeys/sql-key"
      }

      gdpr_database = {
        tier = "db-n1-highmem-8"
        disk_size = 1000
        disk_type = "PD_SSD"
        disk_autoresize = true
        disk_autoresize_limit = 2000
        backup_enabled = true
        backup_start_time = "02:00"  # 2 AM CET
        backup_location = "europe-west1"
        high_availability = true
        availability_type = "REGIONAL"
        point_in_time_recovery = true

        # GDPR specific database for PII
        database_version = "POSTGRES_14"
        deletion_protection = true

        settings = {
          tier = "db-n1-highmem-8"
          activation_policy = "ALWAYS"
          authorized_gae_applications = []

          ip_configuration = {
            ipv4_enabled = false  # Private IP only
            private_network = "projects/prod-project/global/networks/prod-euw1-vpc"
            require_ssl = true
            ssl_mode = "ENCRYPTED_ONLY"
          }

          backup_configuration = {
            enabled = true
            start_time = "02:00"
            point_in_time_recovery_enabled = true
            transaction_log_retention_days = 7
            retained_backups = 90
            retention_unit = "COUNT"
          }

          # GDPR audit logging
          audit_configuration = {
            audit_log_max_size = 100
            audit_log_max_age = 7
            pgaudit_database_log = "all"
          }
        }

        # Encryption for GDPR
        encryption_key_name = "projects/prod-project/locations/europe-west1/keyRings/prod-euw1-keyring/cryptoKeys/gdpr-sql-key"
      }
    }

    # Firestore configuration for EU
    firestore = {
      type = "FIRESTORE_NATIVE"
      location_id = "eur3"  # Multi-region in Europe
      concurrency_mode = "OPTIMISTIC"
      app_engine_integration_mode = "DISABLED"
      delete_protection_state = "ENABLED"
      point_in_time_recovery_enablement = "ENABLED"

      # GDPR specific
      database_type = "MULTI_REGION_EUROPE"
      enable_delete_protection = true
      cmek_key_name = "projects/prod-project/locations/europe/keyRings/prod-eu-keyring/cryptoKeys/firestore-key"
    }

    # Redis configuration for EU
    redis_instances = {
      eu_cache = {
        tier = "STANDARD_HA"
        memory_size_gb = 20
        version = "REDIS_7_0"
        auth_enabled = true
        transit_encryption_mode = "SERVER_AUTHENTICATION"
        replica_count = 2
        read_replicas_mode = "READ_REPLICAS_ENABLED"

        # EU specific location
        location_id = "europe-west1-b"
        alternative_location_id = "europe-west1-c"

        persistence_config = {
          persistence_mode = "RDB"
          rdb_snapshot_period = "ONE_HOUR"
        }

        # GDPR compliance
        customer_managed_key = "projects/prod-project/locations/europe-west1/keyRings/prod-euw1-keyring/cryptoKeys/redis-key"
      }

      eu_session = {
        tier = "STANDARD_HA"
        memory_size_gb = 15
        version = "REDIS_7_0"
        auth_enabled = true
        transit_encryption_mode = "SERVER_AUTHENTICATION"
        replica_count = 2

        # EU specific location
        location_id = "europe-west1-b"
        alternative_location_id = "europe-west1-d"

        # GDPR compliance - sessions expire
        redis_configs = {
          maxmemory-policy = "allkeys-lru"
          timeout = "3600"  # 1 hour session timeout
        }

        customer_managed_key = "projects/prod-project/locations/europe-west1/keyRings/prod-euw1-keyring/cryptoKeys/session-key"
      }
    }

    # BigQuery configuration for EU
    bigquery = {
      location = "EU"  # Multi-region Europe
      default_table_expiration_ms = 63072000000  # 730 days (2 years) for GDPR
      default_partition_expiration_ms = 7776000000  # 90 days
      delete_contents_on_destroy = false
      enable_encryption = true
      default_kms_key_name = "projects/prod-project/locations/eu/keyRings/prod-eu-keyring/cryptoKeys/bigquery-key"

      # EU specific datasets
      datasets = {
        eu_analytics = {
          friendly_name = "EU Production Analytics"
          description = "Analytics dataset for EU region"
          location = "EU"
          max_time_travel_hours = 168  # 7 days

          # GDPR compliance
          default_table_expiration_ms = 63072000000  # 2 years
          default_encryption_configuration = {
            kms_key_name = "projects/prod-project/locations/eu/keyRings/prod-eu-keyring/cryptoKeys/bq-analytics-key"
          }

          access_controls = [
            {
              role = "READER"
              group_by_email = "eu-analytics-readers@company.com"
            },
            {
              role = "WRITER"
              group_by_email = "eu-analytics-writers@company.com"
            }
          ]
        }

        gdpr_data = {
          friendly_name = "GDPR Compliant Data"
          description = "Dataset for GDPR-relevant personal data"
          location = "EU"
          max_time_travel_hours = 24

          # GDPR specific settings
          default_table_expiration_ms = 63072000000  # 2 years
          default_partition_expiration_ms = 63072000000  # 2 years

          labels = {
            gdpr = "true"
            data_classification = "pii"
            region = "eu"
          }

          default_encryption_configuration = {
            kms_key_name = "projects/prod-project/locations/eu/keyRings/prod-eu-keyring/cryptoKeys/gdpr-bq-key"
          }
        }

        eu_ml = {
          friendly_name = "EU Machine Learning"
          description = "ML dataset for EU region"
          location = "EU"
          max_time_travel_hours = 72

          # GDPR compliance for ML
          default_table_expiration_ms = 31536000000  # 1 year
          default_encryption_configuration = {
            kms_key_name = "projects/prod-project/locations/eu/keyRings/prod-eu-keyring/cryptoKeys/ml-bq-key"
          }
        }
      }
    }

    # Spanner configuration for EU
    spanner = {
      config = "eur6"  # Multi-region Europe configuration
      processing_units = 500
      enable_backup = true
      backup_schedule = "0 */6 * * *"
      backup_retention_days = 30
      version_retention_period = "7d"
      enable_drop_protection = true

      # EU specific
      encryption_config = {
        kms_key_name = "projects/prod-project/locations/europe-west1/keyRings/prod-euw1-keyring/cryptoKeys/spanner-key"
      }

      # GDPR compliance
      enable_data_boost = true
      enable_point_in_time_recovery = true
      pitr_retention_days = 7

      labels = {
        region = "eu"
        gdpr_compliant = "true"
        data_residency = "europe"
      }
    }
  }

  # Monitoring configuration for EU with GDPR compliance
  monitoring_config = {
    # Log retention (GDPR compliant)
    log_retention_days = 90
    log_buckets = {
      _Required = 90
      _Default = 90
      application = 90  # Reduced for GDPR
      audit = 2555  # 7 years for audit
      security = 365
      gdpr_logs = 730  # 2 years for GDPR-related logs
    }

    # Log exclusions for GDPR
    log_exclusions = [
      {
        name = "gdpr_ip_exclusion"
        description = "Exclude IP addresses from logs"
        filter = "protoPayload.request.@type=\"type.googleapis.com/google.privacy.dlp.v2.*\""
      },
      {
        name = "gdpr_pii_exclusion"
        description = "Exclude PII from logs"
        filter = "jsonPayload.personal_data=true"
      }
    ]

    # Metrics retention
    metrics_retention_days = 90  # Reduced for GDPR

    # Alerting
    enable_alerting = true
    notification_channels = ["email", "slack", "pagerduty", "opsgenie"]

    # Alert policies
    alert_policies = {
      enable_smart_alerts = true
      enable_anomaly_detection = true
      enable_predictive_alerts = true
      alert_auto_close = 3600  # 1 hour
      alert_cooldown = 300  # 5 minutes

      # GDPR specific alerts
      gdpr_alerts = {
        data_breach_detection = {
          enabled = true
          threshold = 1
          severity = "CRITICAL"
          notification_channels = ["email", "pagerduty", "executive"]
        }
        unauthorized_data_access = {
          enabled = true
          threshold = 1
          severity = "CRITICAL"
        }
        data_export_monitoring = {
          enabled = true
          threshold = 100  # MB
          severity = "HIGH"
        }
        retention_policy_violation = {
          enabled = true
          severity = "HIGH"
        }
      }
    }

    # Dashboards
    create_default_dashboards = true
    custom_dashboards = [
      "gdpr-compliance",
      "data-residency",
      "eu-performance",
      "privacy-metrics",
      "data-access-audit",
      "consent-management",
      "right-to-be-forgotten",
      "data-portability",
      "breach-detection",
      "eu-cost-analysis"
    ]

    # Uptime checks
    enable_uptime_checks = true
    uptime_check_frequency = 60  # seconds
    uptime_check_regions = ["EUROPE"]  # EU only

    # APM with privacy settings
    enable_apm = true
    enable_profiler = true
    enable_trace = true
    trace_sampling_rate = 0.001  # 0.1% for high volume

    # Privacy settings
    anonymize_user_data = true
    mask_sensitive_fields = true
    exclude_pii_from_logs = true

    # Synthetic monitoring
    enable_synthetic_monitoring = true
    synthetic_check_frequency = 300  # 5 minutes
    synthetic_check_locations = ["europe-west1", "europe-west4"]

    # SLOs for EU
    slo_configs = {
      eu_availability = {
        sli_type = "availability"
        goal = 0.999  # 99.9% for EU
        rolling_period_days = 30
      }

      gdpr_compliance = {
        sli_type = "custom"
        metric = "gdpr_compliance_score"
        goal = 1.0  # 100% compliance
        rolling_period_days = 30
      }

      data_residency = {
        sli_type = "custom"
        metric = "data_residency_compliance"
        goal = 1.0  # 100% in EU
        rolling_period_days = 30
      }
    }
  }

  # Security configuration for EU with GDPR requirements
  security_config = {
    # KMS configuration
    kms = {
      key_ring = "prod-${local.region_short}-keyring"
      location = "europe-west1"
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
        gdpr = {
          purpose = "ENCRYPT_DECRYPT"
          rotation_period = "604800s"  # 7 days
        }
        pii = {
          purpose = "ENCRYPT_DECRYPT"
          rotation_period = "604800s"  # 7 days
        }
        audit = {
          purpose = "ENCRYPT_DECRYPT"
          rotation_period = "2592000s"
          destroy_scheduled_duration = "7776000s"  # 90 days
        }
      }
    }

    # Secret Manager for EU
    secret_manager = {
      replication = "USER_MANAGED"
      replicas = [
        {
          location = "europe-west1"
        },
        {
          location = "europe-west4"
        }
      ]
      enable_cmek = true
      enable_audit_logs = true
      enable_secret_rotation = true
      rotation_period = "86400s"  # 1 day for critical secrets

      # GDPR compliance
      labels = {
        region = "eu"
        gdpr_compliant = "true"
      }
    }

    # VPC Service Controls for EU
    enable_vpc_sc = true
    vpc_sc_perimeter = "prod-eu-perimeter"
    vpc_sc_policy = "strict"

    # Access Context Manager for EU
    access_levels = {
      eu_only = {
        basic = {
          conditions = [
            {
              regions = ["BE", "NL", "DE", "FR", "IT", "ES", "PT", "IE", "DK", "SE", "FI", "NO", "PL", "CZ", "AT", "CH"]
            }
          ]
        }
      }

      gdpr_access = {
        basic = {
          conditions = [
            {
              regions = ["BE", "NL", "DE", "FR"]
              ip_subnetworks = ["10.2.0.0/16"]
              require_corp_owned = true
              require_screen_lock = true
            }
          ]
          combining_function = "AND"
        }
      }
    }

    # Binary Authorization
    enable_binary_authorization = true
    require_attestations = true
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"

    # Security Command Center
    enable_scc = true
    enable_scc_notifications = true
    scc_notification_config = {
      high_severity = ["email", "pagerduty", "slack", "executive"]
      medium_severity = ["email", "slack"]
      low_severity = ["email"]
    }

    # Web Security with EU-specific rules
    enable_cloud_armor = true
    cloud_armor_policies = {
      eu_policy = {
        default_rule_action = "allow"
        rules = [
          {
            action = "deny(403)"
            priority = 1000
            match = {
              versioned_expr = "SRC_IPS_V1"
              config = {
                src_ip_ranges = ["0.0.0.0/8", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]  # Block RFC1918
              }
            }
            description = "Block private IP ranges"
          },
          {
            action = "allow"
            priority = 2000
            match = {
              expr = {
                expression = "origin.region_code == 'EU'"
              }
            }
            description = "Allow EU traffic"
          },
          {
            action = "deny(451)"  # HTTP 451 Unavailable For Legal Reasons
            priority = 3000
            match = {
              expr = {
                expression = "origin.region_code != 'EU' && origin.region_code != 'EEA'"
              }
            }
            description = "GDPR - Block non-EU traffic to PII endpoints"
            preview = false
          }
        ]

        # EU specific security
        adaptive_protection = {
          enable = true
          auto_deploy = true
        }

        # Rate limiting for GDPR data export
        rate_limit_options = {
          conform_action = "allow"
          exceed_action = "deny(429)"
          rate_limit_threshold = {
            count = 100
            interval_sec = 3600  # 100 requests per hour for data export
          }
          ban_duration_sec = 600
        }
      }
    }
    enable_ddos_protection = true

    # Data Loss Prevention for GDPR
    enable_dlp = true
    dlp_config = {
      inspect_templates = [
        {
          name = "gdpr-pii-template"
          info_types = ["EMAIL_ADDRESS", "PHONE_NUMBER", "PERSON_NAME", "CREDIT_CARD_NUMBER", "IBAN_CODE", "PASSPORT"]
          min_likelihood = "POSSIBLE"
        },
        {
          name = "gdpr-sensitive-template"
          info_types = ["ETHNIC_ORIGIN", "POLITICAL_VIEWS", "RELIGIOUS_VIEWS", "MEDICAL_RECORD_NUMBER", "HEALTHCARE_DEA_NUMBER"]
          min_likelihood = "LIKELY"
        }
      ]

      deidentify_templates = [
        {
          name = "gdpr-deidentify-template"
          deidentify_config = {
            info_type_transformations = {
              transformations = [
                {
                  info_types = ["EMAIL_ADDRESS"]
                  primitive_transformation = {
                    replace_config = {
                      new_value = "[EMAIL_REDACTED]"
                    }
                  }
                }
              ]
            }
          }
        }
      ]

      job_triggers = [
        {
          name = "gdpr-scan-trigger"
          inspect_job = {
            storage_config = {
              cloud_storage_options = {
                file_set = {
                  url = "gs://prod-euw1-gdpr-personal-data/**"
                }
              }
            }
          }
          triggers = [
            {
              schedule = {
                recurrence_period_duration = "86400s"  # Daily
              }
            }
          ]
        }
      ]
    }

    # Identity & Access
    enable_workload_identity = true
    enable_identity_aware_proxy = true
    enable_beyondcorp = true

    # Additional EU security features
    enable_container_analysis = true
    enable_vulnerability_scanning = true
    enable_web_security_scanner = true
    enable_phishing_protection = true
    enable_recaptcha_enterprise = true

    # GDPR specific security
    gdpr_security = {
      enable_consent_management = true
      enable_privacy_api = true
      enable_data_catalog = true
      enable_sensitive_data_protection = true
      enable_privacy_dlp = true
      enable_assured_workloads = true
      assured_workloads_compliance = "EU_REGIONS_AND_SUPPORT"
    }
  }

  # Backup configuration for EU with GDPR requirements
  backup_config = {
    # Backup schedules (CET timezone)
    backup_schedule = "0 1 * * *"  # 1 AM CET daily

    # Retention policies (GDPR compliant)
    backup_retention_days = 90
    backup_retention_weekly = 52  # 1 year
    backup_retention_monthly = 24  # 2 years for GDPR
    backup_retention_yearly = 7  # 7 years for regulatory

    # Backup location (EU only)
    backup_location = "EUROPE"
    backup_storage_class = "NEARLINE"
    backup_storage_locations = ["europe-west1", "europe-west4"]

    # Cross-region backup (within EU only)
    enable_cross_region_backup = true
    cross_region_backup_locations = ["europe-west4", "europe-north1"]

    # Backup testing
    enable_backup_testing = true
    backup_test_frequency = "weekly"
    enable_automated_recovery_testing = true

    # GDPR specific backup settings
    gdpr_backup_config = {
      enable_encrypted_backups = true
      encryption_key = "projects/prod-project/locations/europe/keyRings/prod-eu-keyring/cryptoKeys/backup-key"
      enable_immutable_backups = true
      enable_backup_access_logging = true
      restrict_backup_access = true
      allowed_backup_restore_identities = [
        "gdpr-backup-admin@company.com",
        "eu-operations@company.com"
      ]
      enable_right_to_be_forgotten = true
      enable_selective_restore = true
    }
  }

  # Disaster recovery configuration for EU
  dr_config = {
    # DR enablement
    enable_dr = true
    dr_role = "regional_primary"

    # DR region (within EU)
    dr_region = "europe-west4"

    # RPO/RTO targets
    rpo_minutes = 30   # 30 minutes
    rto_minutes = 120  # 2 hours

    # DR testing
    enable_dr_testing = true
    dr_test_frequency = "monthly"

    # EU specific DR
    eu_dr_config = {
      failover_within_eu_only = true
      allowed_dr_regions = ["europe-west4", "europe-north1"]
      data_sovereignty_enforced = true
      cross_border_restrictions = true
    }
  }

  # Cost optimization for EU
  cost_optimization = {
    # Committed use discounts
    use_committed_use_discounts = true
    committed_use_cpu_cores = 300
    committed_use_memory_gb = 1200
    committed_use_local_ssd_gb = 5000

    # Resource optimization
    enable_rightsizing_recommendations = true
    enable_idle_resource_recommendations = true
    enable_unattached_disk_recommendations = true

    # EU specific cost optimization
    eu_cost_optimization = {
      currency = "EUR"
      enable_sustained_use_discounts = true
      enable_preemptible_vms = false  # Not for production
      optimize_cross_region_egress = true
    }

    # Budget alerts (in EUR)
    enable_budget_alerts = true
    budget_amount = 35000  # EUR
    budget_currency = "EUR"
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
    compliance  = "gdpr"
    data_residency = "europe"
    data_sovereignty = "eu"
    privacy_shield = "compliant"
  }

  # Feature flags for EU region
  feature_flags = {
    enable_gke_autopilot = true
    enable_anthos       = true
    enable_cloud_run    = true
    enable_cloud_functions = true
    enable_app_engine   = false  # Not available in all EU regions
    enable_dataflow     = true
    enable_dataproc     = true
    enable_composer     = true
    enable_cloud_cdn    = true
    enable_cloud_armor  = true
    enable_api_gateway  = true
    enable_apigee      = false
    enable_traffic_director = true
    enable_service_mesh = true

    # EU/GDPR specific features
    enable_assured_workloads = true
    enable_sovereign_controls = true
    enable_data_residency_controls = true
    enable_privacy_dlp = true
    enable_consent_management = true
    enable_gdpr_compliance_toolkit = true
  }
}