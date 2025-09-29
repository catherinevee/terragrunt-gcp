# Cloud SQL Configuration for Production - US Central 1
# Enterprise-grade managed PostgreSQL and MySQL database instances with HA, backups, and monitoring

terraform {
  source = "${get_repo_root()}/modules/data/cloud-sql"
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

# Cloud SQL depends on VPC for private IP configuration
dependency "vpc" {
  config_path = "../../networking/vpc"

  mock_outputs = {
    network_id = "mock-network-id"
    network_name = "mock-network-name"
    private_vpc_connection = "mock-private-connection"
    subnets = {
      data = {
        id = "mock-subnet-id"
        name = "mock-subnet-name"
        ip_cidr_range = "10.0.3.0/24"
        region = "us-central1"
      }
    }
  }
}

# Cloud SQL depends on KMS for encryption
dependency "kms" {
  config_path = "../../security/kms"
  skip_outputs = true
  mock_outputs = {
    keyring_id = "mock-keyring-id"
    keys = {
      cloud_sql = {
        id = "mock-key-id"
        self_link = "projects/mock-project/locations/us-central1/keyRings/mock-keyring/cryptoKeys/mock-key"
      }
    }
  }
}

# Prevent accidental destruction of production databases
prevent_destroy = true

locals {
  # Extract configuration from includes
  env_config    = include.env.locals
  region_config = include.region.locals

  # Database configuration from environment
  database_config = try(local.env_config.database_config, {})

  # Common instance settings
  common_settings = {
    tier = local.env_config.environment == "prod" ? "db-custom-8-32768" : "db-custom-4-16384"
    edition = local.env_config.environment == "prod" ? "ENTERPRISE_PLUS" : "ENTERPRISE"
    availability_type = local.env_config.environment == "prod" ? "REGIONAL" : "ZONAL"
    disk_size = local.env_config.environment == "prod" ? 500 : 100
    disk_type = "PD_SSD"
    disk_autoresize = true
    disk_autoresize_limit = local.env_config.environment == "prod" ? 2000 : 500
    deletion_protection = local.env_config.environment == "prod"
  }

  # PostgreSQL instances configuration
  postgresql_instances = {
    main = {
      name = "${local.env_config.environment}-${local.region_config.region_short}-postgres-main"
      database_version = "POSTGRES_15"
      region = local.region_config.region
      zone = "${local.region_config.region}-a"
      secondary_zone = local.env_config.environment == "prod" ? "${local.region_config.region}-b" : null

      # Instance settings
      settings = merge(local.common_settings, {
        tier = local.env_config.environment == "prod" ? "db-custom-16-65536" : "db-custom-8-32768"

        # IP configuration
        ip_configuration = {
          ipv4_enabled = false
          private_network = dependency.vpc.outputs.network_id
          enable_private_path_for_google_cloud_services = true
          require_ssl = true
          ssl_mode = "ENCRYPTED_ONLY"
          authorized_networks = []
          allocated_ip_range = null
        }

        # Backup configuration
        backup_configuration = {
          enabled = true
          start_time = "03:00"
          location = local.env_config.environment == "prod" ? "us" : local.region_config.region
          point_in_time_recovery_enabled = true
          transaction_log_retention_days = local.env_config.environment == "prod" ? 7 : 3
          retained_backups = local.env_config.environment == "prod" ? 30 : 7
          retention_unit = "COUNT"
          deletion_protection_enabled = local.env_config.environment == "prod"
        }

        # Database flags
        database_flags = [
          { name = "max_connections", value = "500" },
          { name = "shared_buffers", value = "16384" },
          { name = "effective_cache_size", value = "49152" },
          { name = "maintenance_work_mem", value = "2048" },
          { name = "checkpoint_segments", value = "32" },
          { name = "checkpoint_completion_target", value = "0.9" },
          { name = "wal_buffers", value = "16" },
          { name = "default_statistics_target", value = "100" },
          { name = "random_page_cost", value = "1.1" },
          { name = "effective_io_concurrency", value = "200" },
          { name = "work_mem", value = "32768" },
          { name = "min_wal_size", value = "1024" },
          { name = "max_wal_size", value = "4096" },
          { name = "max_worker_processes", value = "8" },
          { name = "max_parallel_workers_per_gather", value = "4" },
          { name = "max_parallel_workers", value = "8" },
          { name = "max_parallel_maintenance_workers", value = "4" },
          { name = "log_min_duration_statement", value = "1000" },
          { name = "log_checkpoints", value = "on" },
          { name = "log_connections", value = "on" },
          { name = "log_disconnections", value = "on" },
          { name = "log_lock_waits", value = "on" },
          { name = "log_temp_files", value = "0" },
          { name = "log_autovacuum_min_duration", value = "0" },
          { name = "cloudsql.enable_pgaudit", value = "on" },
          { name = "pgaudit.log", value = "all" }
        ]

        # Insights configuration
        insights_config = {
          query_insights_enabled = true
          query_string_length = 4096
          record_application_tags = true
          record_client_address = true
          query_plans_per_minute = 5
        }

        # Maintenance window
        maintenance_window = {
          day = 7
          hour = 4
          update_track = local.env_config.environment == "prod" ? "stable" : "canary"
        }

        # Active Directory configuration (if needed)
        active_directory_config = null

        # Deny maintenance period (production only)
        deny_maintenance_period = local.env_config.environment == "prod" ? [
          {
            end_date = "2024-12-31"
            start_date = "2024-12-20"
            time = "00:00:00"
          }
        ] : []

        # Password validation policy
        password_validation_policy = {
          enable_password_policy = true
          min_length = 12
          complexity = "COMPLEXITY_HIGH"
          reuse_interval = 10
          disallow_username_substring = true
        }
      })

      # Databases to create
      databases = [
        {
          name = "application"
          charset = "UTF8"
          collation = "en_US.UTF8"
        },
        {
          name = "analytics"
          charset = "UTF8"
          collation = "en_US.UTF8"
        },
        {
          name = "reporting"
          charset = "UTF8"
          collation = "en_US.UTF8"
        }
      ]

      # Users to create
      users = [
        {
          name = "app_user"
          password = ""  # Will be generated
          type = "BUILT_IN"
        },
        {
          name = "analytics_user"
          password = ""  # Will be generated
          type = "BUILT_IN"
        },
        {
          name = "readonly_user"
          password = ""  # Will be generated
          type = "BUILT_IN"
        }
      ]

      # Read replicas
      read_replicas = local.env_config.environment == "prod" ? [
        {
          name = "${local.env_config.environment}-${local.region_config.region_short}-postgres-main-replica-1"
          zone = "${local.region_config.region}-c"
          tier = "db-custom-8-32768"
          ip_configuration = {
            ipv4_enabled = false
            private_network = dependency.vpc.outputs.network_id
            require_ssl = true
          }
          database_flags = [
            { name = "max_connections", value = "500" }
          ]
          disk_autoresize = true
          disk_autoresize_limit = 1000
          disk_size = 250
          disk_type = "PD_SSD"
          user_labels = {
            replica_type = "read"
            replica_number = "1"
          }
        },
        {
          name = "${local.env_config.environment}-${local.region_config.region_short}-postgres-main-replica-2"
          zone = "${local.region_config.region}-b"
          tier = "db-custom-8-32768"
          ip_configuration = {
            ipv4_enabled = false
            private_network = dependency.vpc.outputs.network_id
            require_ssl = true
          }
          database_flags = [
            { name = "max_connections", value = "500" }
          ]
          disk_autoresize = true
          disk_autoresize_limit = 1000
          disk_size = 250
          disk_type = "PD_SSD"
          user_labels = {
            replica_type = "read"
            replica_number = "2"
          }
        }
      ] : []
    }

    # Analytics database instance
    analytics = {
      name = "${local.env_config.environment}-${local.region_config.region_short}-postgres-analytics"
      database_version = "POSTGRES_15"
      region = local.region_config.region
      zone = "${local.region_config.region}-b"

      settings = merge(local.common_settings, {
        tier = local.env_config.environment == "prod" ? "db-custom-32-131072" : "db-custom-8-32768"
        disk_size = local.env_config.environment == "prod" ? 1000 : 200

        ip_configuration = {
          ipv4_enabled = false
          private_network = dependency.vpc.outputs.network_id
          enable_private_path_for_google_cloud_services = true
          require_ssl = true
          ssl_mode = "ENCRYPTED_ONLY"
        }

        backup_configuration = {
          enabled = true
          start_time = "04:00"
          location = local.env_config.environment == "prod" ? "us" : local.region_config.region
          point_in_time_recovery_enabled = true
          transaction_log_retention_days = local.env_config.environment == "prod" ? 7 : 3
          retained_backups = local.env_config.environment == "prod" ? 14 : 7
        }

        database_flags = [
          { name = "max_connections", value = "200" },
          { name = "shared_buffers", value = "32768" },
          { name = "effective_cache_size", value = "98304" },
          { name = "work_mem", value = "65536" },
          { name = "maintenance_work_mem", value = "4096" },
          { name = "max_parallel_workers", value = "16" },
          { name = "max_parallel_workers_per_gather", value = "8" },
          { name = "max_parallel_maintenance_workers", value = "8" },
          { name = "enable_partitionwise_join", value = "on" },
          { name = "enable_partitionwise_aggregate", value = "on" },
          { name = "jit", value = "on" }
        ]

        insights_config = {
          query_insights_enabled = true
          query_string_length = 8192
          record_application_tags = true
          record_client_address = true
          query_plans_per_minute = 10
        }
      })

      databases = [
        {
          name = "data_warehouse"
          charset = "UTF8"
          collation = "en_US.UTF8"
        },
        {
          name = "data_lake"
          charset = "UTF8"
          collation = "en_US.UTF8"
        }
      ]
    }
  }

  # MySQL instances configuration
  mysql_instances = {
    webapp = {
      name = "${local.env_config.environment}-${local.region_config.region_short}-mysql-webapp"
      database_version = "MYSQL_8_0_31"
      region = local.region_config.region
      zone = "${local.region_config.region}-a"
      secondary_zone = local.env_config.environment == "prod" ? "${local.region_config.region}-b" : null

      settings = merge(local.common_settings, {
        tier = local.env_config.environment == "prod" ? "db-n1-highmem-8" : "db-n1-standard-4"

        ip_configuration = {
          ipv4_enabled = false
          private_network = dependency.vpc.outputs.network_id
          enable_private_path_for_google_cloud_services = true
          require_ssl = true
        }

        backup_configuration = {
          enabled = true
          start_time = "02:00"
          location = local.env_config.environment == "prod" ? "us" : local.region_config.region
          binary_log_enabled = true
          point_in_time_recovery_enabled = true
          transaction_log_retention_days = local.env_config.environment == "prod" ? 7 : 3
          retained_backups = local.env_config.environment == "prod" ? 30 : 7
        }

        database_flags = [
          { name = "max_connections", value = "1000" },
          { name = "innodb_buffer_pool_size", value = "24696061952" },
          { name = "innodb_log_buffer_size", value = "33554432" },
          { name = "innodb_log_file_size", value = "1073741824" },
          { name = "innodb_flush_log_at_trx_commit", value = "2" },
          { name = "innodb_flush_method", value = "O_DIRECT" },
          { name = "innodb_file_per_table", value = "on" },
          { name = "innodb_io_capacity", value = "2000" },
          { name = "innodb_io_capacity_max", value = "3000" },
          { name = "innodb_read_io_threads", value = "64" },
          { name = "innodb_write_io_threads", value = "64" },
          { name = "innodb_thread_concurrency", value = "0" },
          { name = "innodb_autoinc_lock_mode", value = "2" },
          { name = "innodb_change_buffering", value = "none" },
          { name = "character_set_server", value = "utf8mb4" },
          { name = "collation_server", value = "utf8mb4_unicode_ci" },
          { name = "long_query_time", value = "2" },
          { name = "slow_query_log", value = "on" },
          { name = "general_log", value = local.env_config.environment == "dev" ? "on" : "off" },
          { name = "log_output", value = "FILE" },
          { name = "binlog_row_image", value = "minimal" },
          { name = "binlog_cache_size", value = "32768" },
          { name = "sync_binlog", value = "1000" },
          { name = "expire_logs_days", value = "7" },
          { name = "sql_mode", value = "TRADITIONAL" },
          { name = "transaction_isolation", value = "READ-COMMITTED" },
          { name = "local_infile", value = "off" }
        ]

        insights_config = {
          query_insights_enabled = true
          query_string_length = 2048
          record_application_tags = true
          record_client_address = true
          query_plans_per_minute = 5
        }

        maintenance_window = {
          day = 7
          hour = 3
          update_track = local.env_config.environment == "prod" ? "stable" : "canary"
        }
      })

      databases = [
        {
          name = "webapp_production"
          charset = "utf8mb4"
          collation = "utf8mb4_unicode_ci"
        },
        {
          name = "sessions"
          charset = "utf8mb4"
          collation = "utf8mb4_unicode_ci"
        },
        {
          name = "cache"
          charset = "utf8mb4"
          collation = "utf8mb4_unicode_ci"
        }
      ]

      users = [
        {
          name = "webapp_user"
          host = "%"
          password = ""  # Will be generated
        },
        {
          name = "session_user"
          host = "%"
          password = ""  # Will be generated
        },
        {
          name = "cache_user"
          host = "%"
          password = ""  # Will be generated
        }
      ]

      read_replicas = local.env_config.environment == "prod" ? [
        {
          name = "${local.env_config.environment}-${local.region_config.region_short}-mysql-webapp-replica"
          zone = "${local.region_config.region}-c"
          tier = "db-n1-standard-4"
          ip_configuration = {
            ipv4_enabled = false
            private_network = dependency.vpc.outputs.network_id
            require_ssl = true
          }
        }
      ] : []
    }
  }

  # Monitoring and alerting configuration
  monitoring_config = {
    alerts = {
      high_cpu = {
        display_name = "High CPU Usage - Cloud SQL"
        conditions = {
          threshold_value = 0.8
          duration = "300s"
        }
      }
      high_memory = {
        display_name = "High Memory Usage - Cloud SQL"
        conditions = {
          threshold_value = 0.9
          duration = "300s"
        }
      }
      disk_usage = {
        display_name = "High Disk Usage - Cloud SQL"
        conditions = {
          threshold_value = 0.85
          duration = "600s"
        }
      }
      replication_lag = {
        display_name = "High Replication Lag - Cloud SQL"
        conditions = {
          threshold_value = 30
          duration = "300s"
        }
      }
      connection_limit = {
        display_name = "Connection Limit Approaching - Cloud SQL"
        conditions = {
          threshold_value = 0.9
          duration = "120s"
        }
      }
      backup_failed = {
        display_name = "Backup Failed - Cloud SQL"
        conditions = {
          threshold_value = 1
          duration = "60s"
        }
      }
      database_down = {
        display_name = "Database Down - Cloud SQL"
        conditions = {
          threshold_value = 1
          duration = "60s"
        }
      }
    }

    dashboard = {
      display_name = "Cloud SQL Dashboard - ${local.env_config.environment}"
      grid_layout = {
        widgets = [
          {
            title = "CPU Utilization"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\""
                  }
                }
              }]
            }
          },
          {
            title = "Memory Usage"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/memory/utilization\""
                  }
                }
              }]
            }
          },
          {
            title = "Disk Usage"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/disk/utilization\""
                  }
                }
              }]
            }
          },
          {
            title = "Connections"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/network/connections\""
                  }
                }
              }]
            }
          },
          {
            title = "Replication Lag"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/replication/replica_lag\""
                  }
                }
              }]
            }
          },
          {
            title = "Query Insights"
            scorecard = {
              time_series_query = {
                time_series_filter = {
                  filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/insights/queries/count\""
                }
              }
            }
          }
        ]
      }
    }
  }

  # Backup and disaster recovery configuration
  backup_config = {
    enable_automated_backups = true
    backup_retention_days = local.env_config.environment == "prod" ? 30 : 7
    point_in_time_recovery = true

    # Cross-region backup replication (production only)
    cross_region_backup = local.env_config.environment == "prod" ? {
      enabled = true
      target_region = "us-east1"
      retention_days = 90
    } : null

    # Export to GCS configuration
    scheduled_exports = local.env_config.environment == "prod" ? {
      enabled = true
      schedule = "0 5 * * *"  # Daily at 5 AM
      gcs_bucket = "${local.env_config.environment}-${local.region_config.region_short}-sql-exports"
      file_format = "SQL"
      compression = true
      retention_days = 90
    } : null
  }

  # Security configuration
  security_config = {
    # Encryption at rest
    encryption_key_name = try(dependency.kms.outputs.keys.cloud_sql.self_link, null)

    # SSL/TLS configuration
    require_ssl = true
    ssl_mode = "ENCRYPTED_ONLY"

    # Private IP only
    private_ip_only = true

    # IAM authentication
    enable_iam_authentication = local.env_config.environment == "prod"

    # Audit logging
    audit_log_config = {
      enable_audit_logs = true
      log_types = ["DATA_READ", "DATA_WRITE", "ADMIN_READ", "ADMIN_WRITE"]
    }

    # VPC Service Controls (production only)
    vpc_service_controls = local.env_config.environment == "prod" ? {
      enabled = true
      perimeter_name = "${local.env_config.environment}-sql-perimeter"
    } : null
  }
}

# Module inputs
inputs = {
  # PostgreSQL instances
  postgresql_instances = local.postgresql_instances

  # MySQL instances
  mysql_instances = local.mysql_instances

  # Network configuration
  network_config = {
    network_id = dependency.vpc.outputs.network_id
    private_vpc_connection = dependency.vpc.outputs.private_vpc_connection
    allocated_ip_range = try(dependency.vpc.outputs.allocated_ip_ranges.cloud_sql, null)
  }

  # Encryption configuration
  encryption_config = local.security_config

  # Backup configuration
  backup_config = local.backup_config

  # Monitoring configuration
  monitoring_config = local.monitoring_config
  enable_monitoring = true
  create_monitoring_dashboard = local.env_config.environment == "prod"
  create_monitoring_alerts = local.env_config.environment != "dev"

  # High Availability configuration
  ha_config = {
    enable_ha = local.env_config.environment == "prod"
    regional_availability = local.env_config.environment == "prod"
    automatic_failover = local.env_config.environment == "prod"

    # Replica configuration
    replica_configuration = {
      failover_target = true
      master_heartbeat_period = 60000
      connect_retry_interval = 60
      ca_certificate = null
      client_certificate = null
      client_key = null
      ssl_cipher = null
      verify_server_certificate = true
    }
  }

  # Maintenance configuration
  maintenance_config = {
    maintenance_window = {
      day = 7  # Sunday
      hour = local.env_config.environment == "prod" ? 4 : 2  # 4 AM for prod, 2 AM for others
      update_track = local.env_config.environment == "prod" ? "stable" : "canary"
    }

    # Deny maintenance periods (blackout windows)
    deny_maintenance_periods = local.env_config.environment == "prod" ? [
      {
        start_date = "2024-11-20"
        end_date = "2024-11-30"
        time = "00:00:00"
        reason = "Black Friday period"
      },
      {
        start_date = "2024-12-20"
        end_date = "2025-01-05"
        time = "00:00:00"
        reason = "Holiday season"
      }
    ] : []
  }

  # Performance tuning
  performance_config = {
    # Connection pooling
    enable_connection_pooling = true
    max_connections = local.env_config.environment == "prod" ? 1000 : 500

    # Query optimization
    enable_query_insights = true
    query_string_length = 4096
    query_plans_per_minute = local.env_config.environment == "prod" ? 10 : 5

    # Cache configuration
    enable_query_cache = true
    query_cache_size = local.env_config.environment == "prod" ? 268435456 : 134217728  # 256MB for prod, 128MB for others
  }

  # Compliance configuration
  compliance_config = {
    # Data residency
    data_residency_region = local.region_config.region

    # Compliance standards
    enable_hipaa_compliance = false
    enable_pci_compliance = local.env_config.environment == "prod"
    enable_sox_compliance = local.env_config.environment == "prod"

    # Data retention
    data_retention_days = local.env_config.environment == "prod" ? 2555 : 365  # 7 years for prod, 1 year for others

    # Data classification
    data_classification = local.env_config.environment == "prod" ? "HIGHLY_CONFIDENTIAL" : "CONFIDENTIAL"
  }

  # Cost optimization
  cost_optimization = {
    # Committed use discounts (production only)
    enable_committed_use_discount = local.env_config.environment == "prod"
    commitment_plan = local.env_config.environment == "prod" ? "THREE_YEAR" : null

    # Resource optimization
    enable_automatic_storage_optimization = true
    enable_automatic_memory_optimization = true

    # Idle instance management
    enable_idle_instance_shutdown = local.env_config.environment == "dev"
    idle_timeout_minutes = 60
  }

  # Migration configuration (if needed)
  migration_config = {
    enable_migration = false
    source_instance_name = null
    migration_type = null  # "MYSQL_TO_CLOUDSQL" or "POSTGRES_TO_CLOUDSQL"
  }

  # Labels
  labels = merge(
    var.common_labels,
    {
      component = "data"
      service   = "cloud-sql"
      tier      = "database"
    }
  )

  # Project configuration
  project_id = var.project_id
  region     = local.region_config.region

  # Dependencies
  depends_on = [dependency.vpc, dependency.kms]
}