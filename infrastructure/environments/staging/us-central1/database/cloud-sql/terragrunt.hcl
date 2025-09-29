# Staging Cloud SQL Configuration - US Central 1
# This configuration creates cost-optimized Cloud SQL instances for staging

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
      "database" = "projects/mock-project/regions/us-central1/subnetworks/mock-subnet-db"
    }
    network_name = "mock-network"
  }
}

inputs = {
  project_id = local.project_id
  region     = "us-central1"

  # Staging database instances (cost-optimized)
  database_instances = {
    staging_primary = {
      name                = "staging-usc1-db-primary"
      database_version    = "POSTGRES_15"
      tier                = local.database_config.tier
      disk_type           = "PD_HDD"  # HDD for cost savings
      disk_size           = 20  # Smaller disk for staging
      disk_autoresize     = local.database_config.disk_autoresize
      disk_autoresize_limit = local.database_config.disk_autoresize_limit

      # Region and availability (cost-optimized)
      region                = "us-central1"
      availability_type     = "ZONAL"  # Single zone for cost savings
      secondary_zone        = null

      # Network configuration
      network = dependency.vpc.outputs.network_self_link

      private_network = dependency.vpc.outputs.network_self_link
      allocated_ip_range = null
      authorized_networks = []

      # Enable private IP only for security
      ipv4_enabled = false
      require_ssl  = true

      # Backup configuration (basic)
      backup_configuration = {
        enabled                        = local.database_config.backup_enabled
        start_time                     = local.database_config.backup_start_time
        location                       = "us"
        point_in_time_recovery_enabled = false  # Disabled for cost savings
        transaction_log_retention_days = 1      # Minimal retention
        backup_retention_settings = {
          retained_backups = local.database_config.backup_retention_days
          retention_unit   = "COUNT"
        }
      }

      # Basic database flags
      database_flags = [
        {
          name = "max_connections"
          value = "100"  # Lower for staging
        },
        {
          name = "shared_preload_libraries"
          value = "pg_stat_statements"
        },
        {
          name = "log_checkpoints"
          value = "on"
        },
        {
          name = "log_connections"
          value = "off"  # Disabled for cost savings
        },
        {
          name = "log_disconnections"
          value = "off"  # Disabled for cost savings
        }
      ]

      # Maintenance window
      maintenance_window = {
        day          = local.database_config.maintenance_window_day
        hour         = local.database_config.maintenance_window_hour
        update_track = "stable"
      }

      # Deletion protection (disabled for staging flexibility)
      deletion_protection = false

      # Insights configuration (basic)
      insights_config = {
        query_insights_enabled = false  # Disabled for cost savings
        query_plans_per_minute = 0
        query_string_length = 1024
        record_application_tags = false
        record_client_address = false
      }

      # No encryption for staging
      encryption_key_name = ""

      # Root password
      root_password = "staging-secure-password"

      # Settings
      settings = {
        tier                        = local.database_config.tier
        activation_policy          = "ALWAYS"
        availability_type          = "ZONAL"
        crash_safe_replication     = false  # Not needed for staging
        disk_autoresize           = true
        disk_autoresize_limit     = local.database_config.disk_autoresize_limit
        disk_size                 = 20
        disk_type                 = "PD_HDD"
        pricing_plan              = "PER_USE"
        replication_type          = "SYNCHRONOUS"

        # User labels
        user_labels = {
          environment = "staging"
          region = "usc1"
          tier = "primary"
          purpose = "testing"
          cost_optimized = "true"
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
          zone                   = "us-central1-a"
          secondary_zone        = null
          follow_gae_application = ""
        }

        # Backup configuration
        backup_configuration = {
          enabled                        = true
          start_time                     = local.database_config.backup_start_time
          location                       = "us"
          point_in_time_recovery_enabled = false
          transaction_log_retention_days = 1

          backup_retention_settings = {
            retained_backups = local.database_config.backup_retention_days
            retention_unit   = "COUNT"
          }
        }

        # Password validation policy (relaxed for staging)
        password_validation_policy = {
          enable_password_policy      = false
          min_length                 = 8
          complexity                 = "COMPLEXITY_DEFAULT"
          reuse_interval            = 2
          disallow_username_substring = false
        }

        # No maintenance exclusions for staging
        deny_maintenance_period = null

        # Basic machine configuration
        advanced_machine_features = {
          threads_per_core = 1
        }
      }
    }
  }

  # Databases to create
  databases = {
    application_db = {
      name     = "staging_app"
      charset  = "UTF8"
      collation = "en_US.UTF8"
    }

    test_db = {
      name     = "test_data"
      charset  = "UTF8"
      collation = "en_US.UTF8"
    }

    analytics_db = {
      name     = "staging_analytics"
      charset  = "UTF8"
      collation = "en_US.UTF8"
    }
  }

  # Database users
  database_users = {
    # Application service account
    app_user = {
      name     = "staging-app-service"
      password = "staging-app-password"
      type     = "BUILT_IN"
      host     = ""
    }

    # Developer access user
    dev_user = {
      name     = "developer"
      password = "staging-dev-password"
      type     = "BUILT_IN"
      host     = ""
    }

    # Read-only user for testing
    readonly_user = {
      name     = "readonly-test"
      password = "staging-readonly-password"
      type     = "BUILT_IN"
      host     = ""
    }

    # Analytics user
    analytics_user = {
      name     = "staging-analytics"
      password = "staging-analytics-password"
      type     = "BUILT_IN"
      host     = ""
    }
  }

  # No read replicas for staging (cost optimization)
  read_replicas = []

  # SSL certificates (basic)
  server_ca_certs = {
    staging_ca = {
      common_name = "staging-usc1-db-ca"
      cert_serial_number = "0"
    }
  }

  # Private IP allocation for SQL instances
  private_ip_allocation = {
    allocated_ip_range = "google-managed-services-staging-usc1-db"
    ip_version        = "IPV4"
    prefix_length     = 24
    purpose           = "VPC_PEERING"
  }

  # Basic monitoring configuration
  monitoring_config = {
    # Custom metrics (minimal for staging)
    custom_metrics = [
      {
        name = "staging_database_connections"
        metric_kind = "GAUGE"
        value_type = "INT64"
        description = "Number of active database connections in staging"
      }
    ]

    # Alert policies (basic for staging)
    alert_policies = [
      {
        display_name = "Staging Database High CPU"
        conditions = [{
          display_name = "CPU usage > 90%"
          condition_threshold = {
            filter = "resource.type=\"cloudsql_database\" AND resource.labels.database_id=\"staging-usc1-db-primary\""
            comparison = "COMPARISON_GT"
            threshold_value = 0.9
            duration = "600s"  # 10 minutes for staging
          }
        }]
        notification_channels = []  # No notifications for staging
        alert_strategy = {
          auto_close = "3600s"
        }
      }
    ]
  }

  # Basic cost monitoring
  cost_monitoring = {
    # Budget configuration
    budget_config = {
      amount = 100  # $100 monthly budget for staging DB
      alert_thresholds = [80, 100]
    }

    # Auto-shutdown configuration
    auto_shutdown = {
      enabled = false  # Staging needs to be available for testing
      shutdown_schedule = ""
      startup_schedule = ""
    }
  }

  # Integration with existing resources
  network_self_link = dependency.vpc.outputs.network_self_link
  subnet_self_links = dependency.vpc.outputs.subnet_self_links

  # Tags for resource organization
  tags = {
    Environment = "staging"
    Region = "us-central1"
    RegionShort = "usc1"
    Team = "platform"
    Component = "database"
    CostCenter = "staging"
    Purpose = "testing"
    CostOptimized = "true"
    HighAvailability = "false"
    BackupEnabled = "true"
    SecurityLevel = "basic"
    DiskType = "hdd"
    AvailabilityType = "zonal"
  }
}