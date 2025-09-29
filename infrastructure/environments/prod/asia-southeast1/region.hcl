# Production - Asia Southeast 1 Region Configuration
# APAC production region for Asia-Pacific presence and low latency

locals {
  region = "asia-southeast1"
  region_short = "ase1"

  # Region-specific configuration
  region_config = {
    location     = "asia-southeast1"
    location_id  = "asia-southeast1"
    display_name = "Asia Southeast 1 (Singapore)"

    # Availability zones
    availability_zones = [
      "asia-southeast1-a",
      "asia-southeast1-b",
      "asia-southeast1-c"
    ]

    # Default zone for single-zone resources
    default_zone = "asia-southeast1-a"

    # Region type and tier
    region_type = "quaternary"
    region_tier = "platinum"
    is_primary  = false
    is_dr       = false
    is_apac_hub = true
  }

  # Networking configuration for APAC region
  network_config = {
    # VPC CIDR ranges
    vpc_cidr_primary   = "10.3.0.0/16"
    vpc_cidr_secondary = "10.103.0.0/16"

    # Subnet configurations with micro-segmentation
    subnets = {
      public_lb = {
        cidr = "10.3.0.0/22"
        purpose = "load_balancers"
        flow_logs = true
        flow_logs_metadata = "INCLUDE_ALL"
      }

      public_nat = {
        cidr = "10.3.4.0/22"
        purpose = "nat_gateways"
        flow_logs = true
        flow_logs_metadata = "INCLUDE_ALL"
      }

      private_web = {
        cidr = "10.3.8.0/21"
        secondary_ranges = {
          pods     = "10.103.0.0/17"
          services = "10.103.128.0/20"
        }
        purpose = "web_tier"
        flow_logs = true
      }

      private_app = {
        cidr = "10.3.16.0/21"
        secondary_ranges = {
          pods     = "10.103.144.0/17"
          services = "10.103.208.0/20"
        }
        purpose = "application_tier"
        flow_logs = true
      }

      private_data = {
        cidr = "10.3.24.0/21"
        secondary_ranges = {}
        purpose = "database_tier"
        flow_logs = true
        private_ip_google_access = true
      }

      management = {
        cidr = "10.3.32.0/21"
        secondary_ranges = {}
        purpose = "management"
        flow_logs = true
      }

      dmz = {
        cidr = "10.3.40.0/21"
        secondary_ranges = {}
        purpose = "dmz"
        flow_logs = true
      }

      security = {
        cidr = "10.3.48.0/21"
        secondary_ranges = {}
        purpose = "security_appliances"
        flow_logs = true
      }

      edge = {
        cidr = "10.3.56.0/21"
        secondary_ranges = {}
        purpose = "edge_computing"
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

    # VPN configuration for APAC partners
    enable_vpn = true
    vpn_peer_networks = ["prod-usc1-vpc", "apac-partner-network", "singapore-dc"]
    enable_ha_vpn = true

    # Interconnect configuration for APAC
    enable_interconnect = true
    interconnect_type = "PARTNER"
    interconnect_bandwidth = "10Gbps"
    interconnect_location = "Singapore"

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
      eu_primary = {
        network = "projects/prod-project/global/networks/prod-euw1-vpc"
        export_custom_routes = false
        import_custom_routes = false
      }
      australia = {
        network = "projects/prod-project/global/networks/prod-aus1-vpc"
        export_custom_routes = true
        import_custom_routes = true
      }
    }

    # Advanced networking for APAC
    enable_cloud_cdn = true
    enable_cloud_armor = true
    enable_traffic_director = true

    # APAC specific network optimization
    apac_network_optimization = {
      enable_anycast = true
      enable_global_load_balancing = true
      enable_premium_network_tier = true
      enable_cdn_interconnect = true
      cdn_providers = ["Akamai", "Cloudflare", "Fastly"]
    }
  }

  # Compute resources configuration for APAC
  compute_config = {
    # GKE cluster configuration - APAC production cluster
    gke_clusters = {
      apac_primary = {
        name               = "prod-${local.region_short}-primary"
        initial_node_count = 8
        min_node_count    = 4
        max_node_count    = 100
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
        enable_private_endpoint = false
        master_ipv4_cidr = "172.19.0.0/28"
        enable_vertical_pod_autoscaling = true
        enable_cluster_autoscaling = true
        enable_workload_identity = true
        enable_binary_authorization = true
        enable_intranode_visibility = true
        enable_confidential_nodes = true
        release_channel = "STABLE"

        # APAC specific configurations
        enable_regional_cluster = true
        cluster_locations = ["asia-southeast1-a", "asia-southeast1-b", "asia-southeast1-c"]
        resource_usage_bigquery_dataset = "prod_apac_gke_usage"
        enable_network_egress_metering = true
        enable_resource_consumption_metering = true

        # Multi-language support
        default_max_pods_per_node = 110
        enable_tpu = false
        enable_legacy_abac = false

        node_pools = {
          general = {
            machine_type = "n2-standard-8"
            min_count = 4
            max_count = 40
            disk_size_gb = 400
            disk_type = "pd-ssd"
            preemptible = false
          }

          memory_optimized = {
            machine_type = "n2-highmem-4"
            min_count = 2
            max_count = 20
            disk_size_gb = 200
            disk_type = "pd-ssd"
            preemptible = false
          }

          edge_computing = {
            machine_type = "n2-standard-4"
            min_count = 2
            max_count = 30
            disk_size_gb = 200
            disk_type = "pd-ssd"
            preemptible = false
            taints = [
              {
                key = "edge-computing"
                value = "true"
                effect = "NO_SCHEDULE"
              }
            ]
          }
        }
      }

      apac_secondary = {
        name               = "prod-${local.region_short}-secondary"
        initial_node_count = 4
        min_node_count    = 2
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
        master_ipv4_cidr = "172.19.0.16/28"
        enable_workload_identity = true
        release_channel = "STABLE"
      }

      apac_microservices = {
        name               = "prod-${local.region_short}-microservices"
        initial_node_count = 6
        min_node_count    = 3
        max_node_count    = 80
        machine_type      = "n2-standard-4"
        disk_size_gb      = 200
        disk_type         = "pd-ssd"
        preemptible       = false
        spot              = true
        spot_percentage   = 20
        auto_repair       = true
        auto_upgrade      = false
        enable_autopilot  = true  # Autopilot for microservices
        enable_shielded_nodes = true
        enable_network_policy = true
        enable_private_cluster = true
        master_ipv4_cidr = "172.19.0.32/28"
        enable_workload_identity = true
      }
    }

    # Instance groups for APAC
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

        # APAC specific
        enable_cross_zone_load_balancing = true
      }

      backend = {
        size         = 20
        machine_type = "n2-standard-8"
        disk_size    = 400
        disk_type    = "pd-ssd"
        preemptible  = false
        enable_auto_healing = true
        health_check_interval = 10
        enable_stateful = true

        # APAC specific
        enable_session_affinity = true
        session_affinity_type = "CLIENT_IP"
      }

      cache = {
        size         = 8
        machine_type = "n2-highmem-8"
        disk_size    = 100
        disk_type    = "pd-ssd"
        preemptible  = false
        enable_auto_healing = true

        # APAC specific - distributed cache
        enable_memcache = true
        memcache_node_count = 3
      }

      edge = {
        size         = 15
        machine_type = "n2-standard-2"
        disk_size    = 100
        disk_type    = "pd-standard"
        preemptible  = false
        enable_auto_healing = true

        # Edge computing for APAC
        locations = ["asia-southeast1-a", "asia-southeast1-b", "asia-southeast1-c"]
        enable_gpu = false
      }
    }

    # Cloud Run configuration for APAC
    cloud_run = {
      cpu_limit    = "8"
      memory_limit = "32Gi"
      max_instances = 1000
      min_instances = 5
      concurrency  = 1000
      enable_vpc_connector = true
      enable_binary_authorization = true
      enable_cmek = true

      # APAC specific
      enable_cdn = true
      enable_http2 = true
      enable_session_affinity = true
      timeout_seconds = 900  # 15 minutes for long-running requests
    }

    # Cloud Functions configuration for APAC
    cloud_functions = {
      available_memory_mb = 8192
      timeout            = 540
      max_instances      = 1000
      min_instances      = 5
      enable_vpc_connector = true
      enable_cmek = true

      # APAC specific
      regions = ["asia-southeast1", "asia-northeast1", "asia-south1"]
      enable_retry_on_failure = true
      retry_count = 3
    }

    # Auto-scaling policies for APAC
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

        # APAC specific - handle traffic spikes
        custom_metrics = [
          {
            name = "requests_per_second"
            target = 1000
          },
          {
            name = "latency_p95"
            target = 100
          }
        ]
      }

      app_tier = {
        min_replicas = 10
        max_replicas = 200
        cpu_utilization = 65
        memory_utilization = 70

        # APAC specific metrics
        custom_metrics = [
          {
            name = "active_connections"
            target = 10000
          },
          {
            name = "queue_depth"
            target = 100
          },
          {
            name = "cross_region_latency"
            target = 50
          }
        ]
      }
    }
  }

  # Storage configuration for APAC
  storage_config = {
    # GCS buckets with APAC optimization
    buckets = {
      static_assets = {
        storage_class = "STANDARD"
        location = "ASIA"
        location_type = "MULTI-REGION"
        versioning = true
        enable_cdn = true
        uniform_bucket_level_access = true

        # APAC specific CDN configuration
        cdn_config = {
          enable_cloud_cdn = true
          cache_max_age = 86400
          negative_caching = true
          serve_stale_content = true
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
          default_kms_key = "projects/prod-project/locations/asia-southeast1/keyRings/prod-ase1-keyring/cryptoKeys/gcs-key"
        }
      }

      media_content = {
        storage_class = "STANDARD"
        location = "ASIA-SOUTHEAST1"
        location_type = "REGION"
        versioning = true
        enable_cdn = true

        # APAC media delivery optimization
        cdn_config = {
          enable_cloud_cdn = true
          enable_signed_urls = true
          signed_url_cache_max_age = 3600
          enable_cache_invalidation = true
        }

        lifecycle_rules = [
          {
            age_days = 30
            action   = "SetStorageClass"
            storage_class = "NEARLINE"
          }
        ]

        encryption = {
          default_kms_key = "projects/prod-project/locations/asia-southeast1/keyRings/prod-ase1-keyring/cryptoKeys/media-key"
        }
      }

      application_data = {
        storage_class = "STANDARD"
        location = "ASIA-SOUTHEAST1"
        versioning = true
        retention_policy = {
          retention_period = 7776000  # 90 days
        }

        # APAC specific replication
        turbo_replication = true
        dual_region_configuration = {
          regions = ["asia-southeast1", "asia-northeast1"]
        }

        encryption = {
          default_kms_key = "projects/prod-project/locations/asia-southeast1/keyRings/prod-ase1-keyring/cryptoKeys/app-data-key"
        }
      }

      backups = {
        storage_class = "NEARLINE"
        location = "ASIA"
        location_type = "MULTI-REGION"
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

        encryption = {
          default_kms_key = "projects/prod-project/locations/asia/keyRings/prod-asia-keyring/cryptoKeys/backup-key"
        }
      }

      edge_cache = {
        storage_class = "STANDARD"
        location = "ASIA-SOUTHEAST1"
        versioning = false

        # Edge caching for APAC
        lifecycle_rules = [
          {
            age_days = 7
            action   = "Delete"
          }
        ]

        cors_configuration = {
          origin = ["*"]
          method = ["GET", "HEAD"]
          response_header = ["*"]
          max_age_seconds = 3600
        }
      }
    }

    # Filestore configuration for APAC
    filestore_instances = {
      apac_primary = {
        tier = "ENTERPRISE"
        capacity_gb = 10240
        location = "asia-southeast1-a"
        enable_snapshots = true
        snapshot_schedule = "0 */6 * * *"  # Every 6 hours

        # APAC specific
        enable_nfs_export_options = true
        nfs_export_options = [
          {
            ip_ranges = ["10.3.0.0/16"]
            access_mode = "READ_WRITE"
            squash_mode = "NO_ROOT_SQUASH"
          }
        ]
      }

      apac_secondary = {
        tier = "HIGH_SCALE_SSD"
        capacity_gb = 5120
        location = "asia-southeast1-b"
        enable_snapshots = true

        # APAC specific
        performance_config = {
          iops = 100000
          throughput_mb = 2000
        }
      }
    }
  }

  # Database configuration for APAC
  database_config = {
    # Cloud SQL configuration - APAC production database
    cloud_sql = {
      apac_primary = {
        tier = "db-n1-highmem-32"
        disk_size = 4000
        disk_type = "PD_SSD"
        disk_autoresize = true
        disk_autoresize_limit = 8000
        backup_enabled = true
        backup_start_time = "18:00"  # 2 AM SGT
        backup_location = "asia-southeast1"
        transaction_log_retention_days = 7
        retained_backups = 365
        high_availability = true
        availability_type = "REGIONAL"
        point_in_time_recovery = true

        # APAC specific location
        location_preference = {
          zone = "asia-southeast1-a"
          secondary_zone = "asia-southeast1-b"
        }

        read_replicas = 3
        read_replica_configuration = [
          {
            tier = "db-n1-highmem-16"
            zone = "asia-southeast1-b"
          },
          {
            tier = "db-n1-highmem-16"
            zone = "asia-southeast1-c"
          },
          {
            tier = "db-n1-highmem-8"
            zone = "asia-northeast1-a"  # Tokyo replica for Japan traffic
          }
        ]

        maintenance_window = {
          day          = 7  # Sunday
          hour         = 19  # 3 AM SGT
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
            value = "2000"
          },
          {
            name = "shared_buffers"
            value = "8GB"
          },
          {
            name = "effective_cache_size"
            value = "24GB"
          },
          {
            name = "maintenance_work_mem"
            value = "2GB"
          },
          {
            name = "checkpoint_completion_target"
            value = "0.9"
          },
          {
            name = "wal_buffers"
            value = "16MB"
          },
          {
            name = "default_statistics_target"
            value = "100"
          },
          {
            name = "random_page_cost"
            value = "1.1"
          },
          {
            name = "effective_io_concurrency"
            value = "200"
          },
          {
            name = "work_mem"
            value = "16MB"
          },
          {
            name = "huge_pages"
            value = "off"
          }
        ]

        # APAC specific - multi-language support
        collation = "en_US.UTF8"
        character_set = "UTF8"
      }

      apac_analytics = {
        tier = "db-n1-highmem-16"
        disk_size = 2000
        disk_type = "PD_SSD"
        disk_autoresize = true
        disk_autoresize_limit = 4000
        backup_enabled = true
        backup_start_time = "20:00"  # 4 AM SGT
        high_availability = true
        availability_type = "REGIONAL"

        # APAC analytics specific
        database_version = "MYSQL_8_0"
        enable_bin_log = true
        bin_log_retention_days = 7

        # Read replicas for analytics
        read_replicas = 2
      }
    }

    # Firestore configuration for APAC
    firestore = {
      type = "FIRESTORE_NATIVE"
      location_id = "asia-southeast1"
      concurrency_mode = "OPTIMISTIC"
      app_engine_integration_mode = "DISABLED"
      delete_protection_state = "ENABLED"
      point_in_time_recovery_enablement = "ENABLED"

      # APAC specific
      database_type = "REGIONAL"
      enable_delete_protection = true
      cmek_key_name = "projects/prod-project/locations/asia-southeast1/keyRings/prod-ase1-keyring/cryptoKeys/firestore-key"
    }

    # Redis configuration for APAC
    redis_instances = {
      apac_cache = {
        tier = "STANDARD_HA"
        memory_size_gb = 30
        version = "REDIS_7_0"
        auth_enabled = true
        transit_encryption_mode = "SERVER_AUTHENTICATION"
        replica_count = 2
        read_replicas_mode = "READ_REPLICAS_ENABLED"

        # APAC specific location
        location_id = "asia-southeast1-a"
        alternative_location_id = "asia-southeast1-b"

        persistence_config = {
          persistence_mode = "RDB"
          rdb_snapshot_period = "ONE_HOUR"
        }

        # APAC specific - handle high throughput
        redis_configs = {
          maxmemory-policy = "allkeys-lru"
          lazyfree-lazy-eviction = "yes"
          lazyfree-lazy-expire = "yes"
          lazyfree-lazy-server-del = "yes"
          replica-lazy-flush = "yes"
          maxclients = "100000"
        }

        customer_managed_key = "projects/prod-project/locations/asia-southeast1/keyRings/prod-ase1-keyring/cryptoKeys/redis-key"
      }

      apac_session = {
        tier = "STANDARD_HA"
        memory_size_gb = 20
        version = "REDIS_7_0"
        auth_enabled = true
        transit_encryption_mode = "SERVER_AUTHENTICATION"
        replica_count = 2

        # APAC specific location
        location_id = "asia-southeast1-a"
        alternative_location_id = "asia-southeast1-c"

        # Session management for APAC
        redis_configs = {
          maxmemory-policy = "volatile-lru"
          timeout = "7200"  # 2 hour session timeout
          tcp-keepalive = "60"
          tcp-backlog = "511"
        }

        customer_managed_key = "projects/prod-project/locations/asia-southeast1/keyRings/prod-ase1-keyring/cryptoKeys/session-key"
      }

      apac_realtime = {
        tier = "STANDARD_HA"
        memory_size_gb = 15
        version = "REDIS_7_0"
        auth_enabled = true
        transit_encryption_mode = "SERVER_AUTHENTICATION"
        replica_count = 1

        # Real-time data for APAC
        redis_configs = {
          maxmemory-policy = "noeviction"
          latency-monitor-threshold = "100"
          slowlog-log-slower-than = "10000"
        }

        customer_managed_key = "projects/prod-project/locations/asia-southeast1/keyRings/prod-ase1-keyring/cryptoKeys/realtime-key"
      }
    }

    # BigQuery configuration for APAC
    bigquery = {
      location = "asia-southeast1"
      default_table_expiration_ms = 31536000000  # 365 days
      default_partition_expiration_ms = 7776000000  # 90 days
      delete_contents_on_destroy = false
      enable_encryption = true
      default_kms_key_name = "projects/prod-project/locations/asia-southeast1/keyRings/prod-ase1-keyring/cryptoKeys/bigquery-key"

      # APAC specific datasets
      datasets = {
        apac_analytics = {
          friendly_name = "APAC Production Analytics"
          description = "Analytics dataset for APAC region"
          location = "asia-southeast1"
          max_time_travel_hours = 168  # 7 days

          # APAC specific tables
          tables = [
            {
              name = "user_behavior"
              partitioning = "DAY"
              clustering = ["country", "user_segment"]
            },
            {
              name = "transaction_data"
              partitioning = "HOUR"
              clustering = ["payment_method", "merchant_category"]
            },
            {
              name = "real_time_events"
              partitioning = "HOUR"
              clustering = ["event_type", "user_id"]
              streaming_buffer_size = 100000
            }
          ]
        }

        apac_ml = {
          friendly_name = "APAC Machine Learning"
          description = "ML dataset for APAC region"
          location = "asia-southeast1"
          max_time_travel_hours = 72

          # APAC ML models
          ml_models = [
            {
              name = "recommendation_engine"
              model_type = "TENSORFLOW"
            },
            {
              name = "fraud_detection"
              model_type = "XGBOOST"
            },
            {
              name = "demand_forecasting"
              model_type = "ARIMA_PLUS"
            }
          ]
        }

        apac_realtime = {
          friendly_name = "APAC Real-time Data"
          description = "Streaming data ingestion for APAC"
          location = "asia-southeast1"
          default_partition_expiration_ms = 2592000000  # 30 days

          # Streaming configuration
          streaming_config = {
            enable_streaming_inserts = true
            streaming_buffer_size_mb = 1000
            enable_exactly_once_delivery = true
          }
        }
      }

      # APAC specific BigQuery settings
      materialized_views = [
        {
          name = "hourly_aggregates"
          query = "SELECT DATE_TRUNC(timestamp, HOUR) as hour, COUNT(*) FROM apac_analytics.user_behavior GROUP BY 1"
          enable_refresh = true
          refresh_interval_minutes = 60
        }
      ]

      scheduled_queries = [
        {
          name = "daily_etl"
          query = "CALL apac_analytics.daily_etl_procedure()"
          schedule = "every day 01:00"
          time_zone = "Asia/Singapore"
        }
      ]
    }

    # Spanner configuration for APAC
    spanner = {
      config = "asia-southeast1"
      processing_units = 1000
      enable_backup = true
      backup_schedule = "0 */4 * * *"
      backup_retention_days = 30
      version_retention_period = "7d"
      enable_drop_protection = true

      # APAC specific
      enable_cross_region_backup = true
      cross_region_backup_locations = ["asia-northeast1", "asia-south1"]

      encryption_config = {
        kms_key_name = "projects/prod-project/locations/asia-southeast1/keyRings/prod-ase1-keyring/cryptoKeys/spanner-key"
      }

      # APAC optimization
      enable_query_optimizer = "VERSION_LATEST"
      enable_leader_aware_routing = true

      labels = {
        region = "apac"
        tier = "production"
        criticality = "high"
      }
    }

    # Bigtable configuration for APAC
    bigtable_instances = {
      apac_timeseries = {
        cluster_config = {
          cluster_id = "prod-ase1-timeseries"
          zone = "asia-southeast1-a"
          num_nodes = 5
          storage_type = "SSD"

          autoscaling_config = {
            min_nodes = 3
            max_nodes = 10
            cpu_target = 70
            storage_target = 4096  # GB
          }
        }

        replication_config = {
          cluster_id = "prod-ase1-timeseries-replica"
          zone = "asia-southeast1-b"
          num_nodes = 5
          storage_type = "SSD"
        }

        # APAC specific - IoT data handling
        tables = [
          {
            name = "iot_sensor_data"
            column_families = [
              {
                name = "metrics"
                gc_rule = "maxversions=1"
              },
              {
                name = "metadata"
                gc_rule = "maxage=7d"
              }
            ]
          },
          {
            name = "user_events"
            column_families = [
              {
                name = "events"
                gc_rule = "maxversions=5"
              }
            ]
          }
        ]

        # APAC specific encryption
        encryption_config = {
          kms_key_name = "projects/prod-project/locations/asia-southeast1/keyRings/prod-ase1-keyring/cryptoKeys/bigtable-key"
        }
      }

      apac_analytics = {
        cluster_config = {
          cluster_id = "prod-ase1-analytics"
          zone = "asia-southeast1-a"
          num_nodes = 3
          storage_type = "SSD"
        }

        # APAC analytics workload
        app_profile = {
          app_profile_id = "analytics"
          routing_policy = "MULTI_CLUSTER_ROUTING"
          allow_transactional_writes = false
        }
      }
    }

    # Dataflow configuration for APAC
    dataflow = {
      enable_streaming_engine = true
      enable_flex_template = true
      worker_region = "asia-southeast1"
      worker_zone = "asia-southeast1-a"

      # APAC specific streaming pipelines
      streaming_pipelines = [
        {
          name = "realtime_analytics"
          template = "streaming-analytics-template"
          max_workers = 20
          machine_type = "n2-standard-4"
        },
        {
          name = "iot_ingestion"
          template = "iot-ingestion-template"
          max_workers = 15
          machine_type = "n2-standard-2"
        }
      ]
    }
  }

  # Monitoring configuration for APAC
  monitoring_config = {
    # Log retention
    log_retention_days = 90
    log_buckets = {
      _Required = 90
      _Default = 90
      application = 180
      audit = 2555  # 7 years
      security = 365
      apac_regional = 90
    }

    # Metrics retention
    metrics_retention_days = 180

    # Alerting
    enable_alerting = true
    notification_channels = ["email", "slack", "pagerduty", "opsgenie", "webhook"]

    # Alert policies for APAC
    alert_policies = {
      enable_smart_alerts = true
      enable_anomaly_detection = true
      enable_predictive_alerts = true
      alert_auto_close = 3600  # 1 hour
      alert_cooldown = 300  # 5 minutes

      # APAC specific alerts
      apac_alerts = {
        cross_region_latency = {
          threshold = 100  # ms
          severity = "HIGH"
        }
        bandwidth_utilization = {
          threshold = 80  # percent
          severity = "MEDIUM"
        }
        cdn_cache_hit_ratio = {
          threshold = 90  # percent
          severity = "LOW"
        }
      }
    }

    # Dashboards
    create_default_dashboards = true
    custom_dashboards = [
      "apac-overview",
      "singapore-dc-status",
      "cross-region-performance",
      "cdn-performance",
      "edge-computing-metrics",
      "iot-ingestion",
      "real-time-analytics",
      "multi-language-support",
      "payment-gateway-status",
      "apac-cost-analysis"
    ]

    # Uptime checks for APAC
    enable_uptime_checks = true
    uptime_check_frequency = 60  # seconds
    uptime_check_regions = [
      "ASIA_PACIFIC",
      "USA",  # For cross-region monitoring
      "EUROPE"  # For cross-region monitoring
    ]

    # APM
    enable_apm = true
    enable_profiler = true
    enable_trace = true
    trace_sampling_rate = 0.001  # 0.1% for high volume

    # Synthetic monitoring for APAC
    enable_synthetic_monitoring = true
    synthetic_check_frequency = 300  # 5 minutes
    synthetic_check_locations = [
      "asia-southeast1",  # Singapore
      "asia-northeast1",  # Tokyo
      "asia-south1",      # Mumbai
      "australia-southeast1"  # Sydney
    ]

    # SLOs for APAC
    slo_configs = {
      apac_availability = {
        sli_type = "availability"
        goal = 0.999  # 99.9%
        rolling_period_days = 30
      }

      apac_latency = {
        sli_type = "latency"
        threshold_value = 100  # ms
        goal = 0.99  # 99%
        rolling_period_days = 30
      }

      cdn_performance = {
        sli_type = "custom"
        metric = "cdn_cache_hit_ratio"
        goal = 0.95  # 95%
        rolling_period_days = 30
      }
    }
  }

  # Security configuration for APAC
  security_config = {
    # KMS configuration
    kms = {
      key_ring = "prod-${local.region_short}-keyring"
      location = "asia-southeast1"
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
        payment = {
          purpose = "ENCRYPT_DECRYPT"
          rotation_period = "604800s"  # 7 days - PCI compliance
        }
        pii = {
          purpose = "ENCRYPT_DECRYPT"
          rotation_period = "604800s"  # 7 days
        }
      }
    }

    # Secret Manager for APAC
    secret_manager = {
      replication = "USER_MANAGED"
      replicas = [
        {
          location = "asia-southeast1"
        },
        {
          location = "asia-northeast1"
        },
        {
          location = "asia-south1"
        }
      ]
      enable_cmek = true
      enable_audit_logs = true
      enable_secret_rotation = true
      rotation_period = "86400s"  # 1 day for critical secrets
    }

    # VPC Service Controls
    enable_vpc_sc = true
    vpc_sc_perimeter = "prod-apac-perimeter"
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

    # Web Security for APAC
    enable_cloud_armor = true
    cloud_armor_policies = {
      apac_policy = {
        default_rule_action = "allow"
        rules = [
          {
            action = "deny(403)"
            priority = 1000
            match = {
              versioned_expr = "SRC_IPS_V1"
              config = {
                src_ip_ranges = ["0.0.0.0/8"]  # Block bogon
              }
            }
            description = "Block bogon IP ranges"
          },
          {
            action = "throttle"
            priority = 2000
            match = {
              versioned_expr = "SRC_IPS_V1"
              config = {
                src_ip_ranges = ["0.0.0.0/0"]  # All IPs
              }
            }
            rate_limit_options = {
              rate_limit_threshold = {
                count = 10000
                interval_sec = 60
              }
              conform_action = "allow"
              exceed_action = "deny(429)"
              ban_duration_sec = 600
            }
            description = "Rate limiting for APAC"
          },
          {
            action = "allow"
            priority = 3000
            match = {
              expr = {
                expression = "origin.region_code in ['SG', 'MY', 'ID', 'TH', 'PH', 'VN', 'JP', 'KR', 'CN', 'IN', 'AU', 'NZ']"
              }
            }
            description = "Prioritize APAC traffic"
          }
        ]

        adaptive_protection = {
          enable = true
          auto_deploy = true
        }

        # APAC specific - country-based rules
        geo_filtering = {
          priority_countries = ["SG", "MY", "ID", "TH", "PH", "VN", "JP", "KR", "IN", "AU"]
          blocked_countries = []  # No blocking for APAC
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

    # APAC specific security
    apac_security = {
      enable_payment_card_tokenization = true  # PCI compliance
      enable_multi_factor_authentication = true
      mfa_methods = ["sms", "totp", "push", "biometric"]
      enable_fraud_detection = true
      fraud_detection_model = "ml_based"
    }
  }

  # Backup configuration for APAC
  backup_config = {
    # Backup schedules (SGT timezone)
    backup_schedule = "0 18 * * *"  # 2 AM SGT

    # Retention policies
    backup_retention_days = 90
    backup_retention_weekly = 52  # 1 year
    backup_retention_monthly = 84  # 7 years
    backup_retention_yearly = 10  # 10 years

    # Backup location
    backup_location = "ASIA"
    backup_storage_class = "NEARLINE"
    backup_storage_locations = ["asia-southeast1", "asia-northeast1", "asia-south1"]

    # Cross-region backup
    enable_cross_region_backup = true
    cross_region_backup_locations = ["asia-northeast1", "asia-south1", "us-central1"]

    # Backup testing
    enable_backup_testing = true
    backup_test_frequency = "weekly"
    enable_automated_recovery_testing = true

    # Continuous backup
    enable_continuous_backup = true
    continuous_backup_retention = "7d"

    # APAC specific backup
    apac_backup_config = {
      enable_geo_redundant_backup = true
      geo_redundant_locations = ["asia-northeast1", "australia-southeast1"]
      enable_cross_continental_backup = true
      continental_backup_location = "us-central1"
    }
  }

  # Disaster recovery configuration for APAC
  dr_config = {
    # DR enablement
    enable_dr = true
    dr_role = "regional_primary"

    # DR regions for APAC
    dr_region = "asia-northeast1"  # Tokyo as DR for Singapore
    secondary_dr_region = "asia-south1"  # Mumbai as secondary DR

    # RPO/RTO targets
    rpo_minutes = 30   # 30 minutes
    rto_minutes = 120  # 2 hours

    # DR testing
    enable_dr_testing = true
    dr_test_frequency = "monthly"

    # APAC specific DR
    apac_dr_config = {
      enable_multi_region_failover = true
      failover_regions = ["asia-northeast1", "asia-south1", "australia-southeast1"]
      enable_cross_continental_dr = true
      continental_dr_region = "us-central1"
      enable_automatic_failback = true
      failback_window = "maintenance"  # Only during maintenance windows
    }
  }

  # Cost optimization for APAC
  cost_optimization = {
    # Committed use discounts
    use_committed_use_discounts = true
    committed_use_cpu_cores = 400
    committed_use_memory_gb = 1600
    committed_use_local_ssd_gb = 10000

    # Resource optimization
    enable_rightsizing_recommendations = true
    enable_idle_resource_recommendations = true
    enable_unattached_disk_recommendations = true

    # APAC specific cost optimization
    apac_cost_optimization = {
      currency = "USD"  # Can be SGD, JPY, INR based on billing
      enable_sustained_use_discounts = true
      enable_preemptible_vms = false  # Not for production
      optimize_cross_region_egress = true
      enable_cdn_caching = true
      cdn_cache_optimization = true
    }

    # Budget alerts
    enable_budget_alerts = true
    budget_amount = 45000
    budget_currency = "USD"
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
    market      = "apac"
    hub_type    = "regional"
  }

  # Feature flags for APAC region
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

    # APAC specific features
    enable_edge_computing = true
    enable_iot_core = true
    enable_media_cdn = true
    enable_game_servers = true
    enable_stream_analytics = true
    enable_multi_cloud_support = true
  }
}