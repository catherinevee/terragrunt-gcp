# Production Cloud SQL Configuration - US East 1 (Disaster Recovery)
# This configuration creates Cloud SQL instances for disaster recovery

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
  source = "../../../../../../modules/database/cloud-sql"
}

dependency "vpc" {
  config_path = "../../networking/vpc"
  mock_outputs = {
    network_self_link = "projects/mock-project/global/networks/mock-network"
    subnet_self_links = {
      "private_data" = "projects/mock-project/regions/us-east1/subnetworks/mock-subnet-data"
    }
    network_name = "mock-network"
  }
}

dependency "kms" {
  config_path = "../../security/kms"
  mock_outputs = {
    crypto_keys = {
      database = "projects/mock-project/locations/us-east1/keyRings/mock/cryptoKeys/database"
    }
  }
}

inputs = {
  project_id = "your-prod-project-id"
  region     = local.region

  # Primary DR database instance
  database_instances = {
    dr_primary = {
      name                = "prod-${local.region_short}-db-primary"
      database_version    = "POSTGRES_15"
      tier                = local.database_config.cloud_sql.dr_primary.tier
      disk_type           = local.database_config.cloud_sql.dr_primary.disk_type
      disk_size           = local.database_config.cloud_sql.dr_primary.disk_size
      disk_autoresize     = local.database_config.cloud_sql.dr_primary.disk_autoresize
      disk_autoresize_limit = local.database_config.cloud_sql.dr_primary.disk_autoresize_limit

      # Region and availability
      region                = local.region
      availability_type     = local.database_config.cloud_sql.dr_primary.availability_type
      secondary_zone        = "${local.region}-c"

      # Network configuration
      network = dependency.vpc.outputs.network_self_link

      private_network = dependency.vpc.outputs.network_self_link
      allocated_ip_range = null
      authorized_networks = []

      # Enable private IP only for security
      ipv4_enabled = false
      require_ssl  = true

      # Backup configuration
      backup_configuration = {
        enabled                        = local.database_config.cloud_sql.dr_primary.backup_enabled
        start_time                     = local.database_config.cloud_sql.dr_primary.backup_start_time
        location                       = local.database_config.cloud_sql.dr_primary.backup_location
        point_in_time_recovery_enabled = local.database_config.cloud_sql.dr_primary.point_in_time_recovery
        transaction_log_retention_days = local.database_config.cloud_sql.dr_primary.transaction_log_retention_days
        backup_retention_settings = {
          retained_backups = local.database_config.cloud_sql.dr_primary.retained_backups
          retention_unit   = "COUNT"
        }
      }

      # Database flags from region configuration
      database_flags = local.database_config.cloud_sql.dr_primary.database_flags

      # Maintenance window
      maintenance_window = local.database_config.cloud_sql.dr_primary.maintenance_window

      # Deletion protection
      deletion_protection = true

      # Insights configuration
      insights_config = local.database_config.cloud_sql.dr_primary.insights_config

      # Encryption
      encryption_key_name = dependency.kms.outputs.crypto_keys.database

      # Root password
      root_password = "your-secure-root-password-dr"

      # Replica configuration for DR
      replica_configuration = {
        failover_target            = local.database_config.cloud_sql.dr_primary.replica_configuration.failover_target
        ca_certificate            = ""
        client_certificate        = ""
        client_key               = ""
        connect_retry_interval    = 60
        dump_file_path           = ""
        master_heartbeat_period   = 10000
        password                 = ""
        ssl_cipher               = ""
        username                 = ""
        verify_server_certificate = false
      }

      # Settings
      settings = {
        tier                        = local.database_config.cloud_sql.dr_primary.tier
        activation_policy          = "ALWAYS"
        availability_type          = local.database_config.cloud_sql.dr_primary.availability_type
        crash_safe_replication     = true
        disk_autoresize           = local.database_config.cloud_sql.dr_primary.disk_autoresize
        disk_autoresize_limit     = local.database_config.cloud_sql.dr_primary.disk_autoresize_limit
        disk_size                 = local.database_config.cloud_sql.dr_primary.disk_size
        disk_type                 = local.database_config.cloud_sql.dr_primary.disk_type
        pricing_plan              = "PER_USE"
        replication_type          = "SYNCHRONOUS"

        # User labels
        user_labels = {
          environment = "production"
          region = local.region_short
          tier = "primary"
          role = "disaster-recovery"
          backup_enabled = "true"
          encryption_enabled = "true"
          high_availability = "true"
        }

        # IP configuration
        ip_configuration = {
          ipv4_enabled                                  = false
          private_network                              = dependency.vpc.outputs.network_self_link
          require_ssl                                  = true
          allocated_ip_range                           = null
          enable_private_path_for_google_cloud_services = true

          authorized_networks = []
        }

        # Location preferences
        location_preference = {
          zone                   = "${local.region}-b"
          secondary_zone        = "${local.region}-c"
          follow_gae_application = ""
        }

        # Backup configuration
        backup_configuration = {
          enabled                        = true
          start_time                     = local.database_config.cloud_sql.dr_primary.backup_start_time
          location                       = local.database_config.cloud_sql.dr_primary.backup_location
          point_in_time_recovery_enabled = true
          transaction_log_retention_days = local.database_config.cloud_sql.dr_primary.transaction_log_retention_days

          backup_retention_settings = {
            retained_backups = local.database_config.cloud_sql.dr_primary.retained_backups
            retention_unit   = "COUNT"
          }
        }

        # Password validation policy
        password_validation_policy = {
          enable_password_policy      = true
          min_length                 = 12
          complexity                 = "COMPLEXITY_DEFAULT"
          reuse_interval            = 5
          disallow_username_substring = true
        }

        # Deny maintenance period
        deny_maintenance_period = {
          end_date   = "2024-12-31"
          start_date = "2024-12-20"
          time       = "00:00:00"
        }

        # Advanced machine configuration
        advanced_machine_features = {
          threads_per_core = 2
        }
      }

      # DR specific settings
      dr_configuration = {
        # Master instance information for replica setup
        master_instance_name = "prod-usc1-db-primary"

        # Cross-region backup configuration
        automated_backup_replication = local.database_config.cloud_sql.dr_primary.automated_backup_replication

        # Failover configuration
        enable_automatic_failover = true
        failover_threshold_minutes = 5

        # Read replica configuration
        read_replica_count = local.database_config.cloud_sql.dr_primary.read_replicas

        # Point-in-time recovery
        enable_point_in_time_recovery = true
        pitr_retention_days = 7
      }
    }
  }

  # Databases to create
  databases = {
    application_db = {
      name     = "application"
      charset  = "UTF8"
      collation = "en_US.UTF8"
    }

    analytics_db = {
      name     = "analytics"
      charset  = "UTF8"
      collation = "en_US.UTF8"
    }

    sessions_db = {
      name     = "sessions"
      charset  = "UTF8"
      collation = "en_US.UTF8"
    }

    audit_db = {
      name     = "audit"
      charset  = "UTF8"
      collation = "en_US.UTF8"
    }

    dr_metadata_db = {
      name     = "dr_metadata"
      charset  = "UTF8"
      collation = "en_US.UTF8"
    }
  }

  # Database users
  database_users = {
    # Application service accounts
    app_user = {
      name     = "app-service"
      password = "your-secure-app-password"
      type     = "BUILT_IN"
      host     = ""
    }

    # Read-only user for analytics
    analytics_user = {
      name     = "analytics-readonly"
      password = "your-secure-analytics-password"
      type     = "BUILT_IN"
      host     = ""
    }

    # Backup and restore user
    backup_user = {
      name     = "backup-service"
      password = "your-secure-backup-password"
      type     = "BUILT_IN"
      host     = ""
    }

    # DR monitoring user
    dr_monitor_user = {
      name     = "dr-monitor"
      password = "your-secure-dr-monitor-password"
      type     = "BUILT_IN"
      host     = ""
    }

    # Replication user for cross-region sync
    replication_user = {
      name     = "replication-service"
      password = "your-secure-replication-password"
      type     = "BUILT_IN"
      host     = ""
    }
  }

  # Read replicas for load distribution
  read_replicas = [
    {
      name               = "prod-${local.region_short}-db-read-1"
      tier              = "db-n1-highmem-8"
      disk_size         = 2000
      disk_type         = "PD_SSD"
      disk_autoresize   = true
      region            = local.region
      zone              = "${local.region}-b"

      replica_configuration = {
        failover_target = false
      }

      settings = {
        availability_type = "ZONAL"
        crash_safe_replication = true

        backup_configuration = {
          enabled = false
        }

        ip_configuration = {
          ipv4_enabled    = false
          private_network = dependency.vpc.outputs.network_self_link
          require_ssl     = true
        }

        user_labels = {
          environment = "production"
          region = local.region_short
          tier = "read-replica"
          role = "disaster-recovery"
          replica_number = "1"
        }
      }
    },

    {
      name               = "prod-${local.region_short}-db-read-2"
      tier              = "db-n1-highmem-8"
      disk_size         = 2000
      disk_type         = "PD_SSD"
      disk_autoresize   = true
      region            = local.region
      zone              = "${local.region}-c"

      replica_configuration = {
        failover_target = false
      }

      settings = {
        availability_type = "ZONAL"
        crash_safe_replication = true

        backup_configuration = {
          enabled = false
        }

        ip_configuration = {
          ipv4_enabled    = false
          private_network = dependency.vpc.outputs.network_self_link
          require_ssl     = true
        }

        user_labels = {
          environment = "production"
          region = local.region_short
          tier = "read-replica"
          role = "disaster-recovery"
          replica_number = "2"
        }
      }
    }
  ]

  # SSL certificates
  server_ca_certs = {
    dr_primary_ca = {
      common_name = "prod-${local.region_short}-db-ca"
      cert_serial_number = "0"
    }
  }

  # Private IP allocation for SQL instances
  private_ip_allocation = {
    allocated_ip_range = "google-managed-services-prod-use1-db"
    ip_version        = "IPV4"
    prefix_length     = 24
    purpose           = "VPC_PEERING"
  }

  # Firestore configuration for NoSQL needs
  firestore_config = local.database_config.firestore

  # Redis instances for caching in DR
  redis_instances = {
    dr_cache = local.database_config.redis_instances.dr_cache
    dr_session = local.database_config.redis_instances.dr_session
  }

  # BigQuery configuration for analytics in DR
  bigquery_datasets = {
    analytics_replica = local.database_config.bigquery.datasets.analytics_replica
    ml_replica = local.database_config.bigquery.datasets.ml_replica
    realtime_replica = local.database_config.bigquery.datasets.realtime_replica
  }

  # Spanner configuration for global consistency
  spanner_config = local.database_config.spanner

  # Bigtable instances for time-series data
  bigtable_instances = local.database_config.bigtable_instances

  # Database monitoring and alerting
  monitoring_config = {
    # Custom metrics
    custom_metrics = [
      {
        name = "database_connection_count"
        metric_kind = "GAUGE"
        value_type = "INT64"
        description = "Number of active database connections"
      },
      {
        name = "database_replica_lag"
        metric_kind = "GAUGE"
        value_type = "DOUBLE"
        description = "Replication lag in seconds"
      },
      {
        name = "database_query_latency"
        metric_kind = "GAUGE"
        value_type = "DOUBLE"
        description = "Average query latency in milliseconds"
      }
    ]

    # Alert policies
    alert_policies = [
      {
        display_name = "High Database CPU Usage"
        conditions = [{
          display_name = "CPU usage > 80%"
          condition_threshold = {
            filter = "resource.type=\"cloudsql_database\""
            comparison = "COMPARISON_GT"
            threshold_value = 0.8
            duration = "300s"
          }
        }]
        notification_channels = ["projects/your-prod-project-id/notificationChannels/email-ops"]
        alert_strategy = {
          auto_close = "1800s"
        }
      },
      {
        display_name = "Database Replica Lag"
        conditions = [{
          display_name = "Replica lag > 60 seconds"
          condition_threshold = {
            filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/replica_lag\""
            comparison = "COMPARISON_GT"
            threshold_value = 60
            duration = "120s"
          }
        }]
        notification_channels = ["projects/your-prod-project-id/notificationChannels/pagerduty-critical"]
        alert_strategy = {
          auto_close = "3600s"
        }
      }
    ]
  }

  # Disaster recovery configuration
  disaster_recovery = {
    # Cross-region replication
    enable_cross_region_replication = true
    primary_region = "us-central1"

    # Backup strategy
    backup_strategy = {
      frequency = "every_6_hours"
      retention_days = 30
      cross_region_backup = true
      backup_encryption = true
    }

    # Failover configuration
    failover_config = {
      automatic_failover = true
      manual_failover = true
      failover_threshold_minutes = 5
      failback_delay_minutes = 30
    }

    # Testing configuration
    dr_testing = {
      enable_automated_testing = true
      test_frequency = "weekly"
      test_scenarios = ["failover", "failback", "backup_restore"]
    }
  }

  # Integration with existing resources
  network_self_link = dependency.vpc.outputs.network_self_link
  subnet_self_links = dependency.vpc.outputs.subnet_self_links
  kms_crypto_key = dependency.kms.outputs.crypto_keys.database

  # Tags for resource organization
  tags = {
    Environment = "production"
    Region = local.region
    RegionShort = local.region_short
    RegionType = "disaster-recovery"
    Team = "platform"
    Component = "database"
    CostCenter = "engineering"
    Compliance = "required"
    DataClassification = "sensitive"
    BackupRequired = "true"
    MonitoringRequired = "true"
    DRRole = "secondary"
    DRPriority = "1"
    SecurityLevel = "high"
    EncryptionEnabled = "true"
    HighAvailability = "true"
    PointInTimeRecovery = "enabled"
  }
}