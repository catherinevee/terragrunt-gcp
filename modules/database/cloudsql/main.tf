# Google Cloud SQL Module
# Manages Cloud SQL instances with comprehensive configuration options

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

locals {
  # Instance name with optional random suffix
  instance_name = var.name != null ? var.name : "${var.name_prefix}-${random_id.name_suffix[0].hex}"

  # Database version
  database_version = var.database_version != null ? var.database_version : (
    var.database_type == "POSTGRES" ? "POSTGRES_14" :
    var.database_type == "MYSQL" ? "MYSQL_8_0" :
    "SQLSERVER_2019_STANDARD"
  )

  # Default flags based on database type
  default_database_flags = var.database_type == "POSTGRES" ? {
    "log_checkpoints"             = "on"
    "log_connections"             = "on"
    "log_disconnections"          = "on"
    "log_lock_waits"              = "on"
    "log_temp_files"              = "0"
    "log_autovacuum_min_duration" = "0"
    "shared_preload_libraries"    = "pg_stat_statements"
    } : var.database_type == "MYSQL" ? {
    "slow_query_log"                = "on"
    "long_query_time"               = "1"
    "log_output"                    = "FILE"
    "general_log"                   = "off"
    "log_queries_not_using_indexes" = "on"
  } : {}

  # Merge default and custom database flags
  database_flags = merge(local.default_database_flags, var.database_flags)

  # Backup configuration with defaults
  backup_configuration = merge({
    enabled                        = true
    start_time                     = "03:00"
    location                       = var.region
    point_in_time_recovery_enabled = var.database_type != "SQLSERVER"
    transaction_log_retention_days = var.database_type == "POSTGRES" || var.database_type == "MYSQL" ? 7 : null
    retained_backups               = 7
    retention_unit                 = "COUNT"
  }, var.backup_configuration)

  # IP configuration
  ip_configuration = merge({
    ipv4_enabled                                  = true
    private_network                               = null
    allocated_ip_range                            = null
    enable_private_path_for_google_cloud_services = false
    require_ssl                                   = var.require_ssl
  }, var.ip_configuration)

  # Maintenance window
  maintenance_window = merge({
    day          = 7 # Sunday
    hour         = 4 # 4 AM
    update_track = "stable"
  }, var.maintenance_window)

  # Labels with defaults
  labels = merge(
    var.labels,
    {
      managed_by  = "terraform"
      module      = "cloudsql"
      environment = var.environment
      database    = var.database_type
    }
  )
}

# Random suffix for instance naming
resource "random_id" "name_suffix" {
  count       = var.name == null ? 1 : 0
  byte_length = 4

  keepers = {
    database_version = local.database_version
    tier             = var.tier
  }
}

# Random password for root user if not provided
resource "random_password" "root_password" {
  count   = var.root_password == null ? 1 : 0
  length  = 32
  special = true

  keepers = {
    instance_name = local.instance_name
  }
}

# Cloud SQL Database Instance
resource "google_sql_database_instance" "instance" {
  project             = var.project_id
  name                = local.instance_name
  database_version    = local.database_version
  region              = var.region
  deletion_protection = var.deletion_protection

  # Master instance configuration (for read replicas)
  master_instance_name = var.master_instance_name

  # Replica configuration
  dynamic "replica_configuration" {
    for_each = var.replica_configuration != null ? [var.replica_configuration] : []
    content {
      ca_certificate            = lookup(replica_configuration.value, "ca_certificate", null)
      client_certificate        = lookup(replica_configuration.value, "client_certificate", null)
      client_key                = lookup(replica_configuration.value, "client_key", null)
      connect_retry_interval    = lookup(replica_configuration.value, "connect_retry_interval", null)
      dump_file_path            = lookup(replica_configuration.value, "dump_file_path", null)
      failover_target           = lookup(replica_configuration.value, "failover_target", false)
      master_heartbeat_period   = lookup(replica_configuration.value, "master_heartbeat_period", null)
      password                  = lookup(replica_configuration.value, "password", null)
      ssl_cipher                = lookup(replica_configuration.value, "ssl_cipher", null)
      username                  = lookup(replica_configuration.value, "username", null)
      verify_server_certificate = lookup(replica_configuration.value, "verify_server_certificate", null)
    }
  }

  # Restore from backup
  dynamic "restore_backup_context" {
    for_each = var.restore_backup_context != null ? [var.restore_backup_context] : []
    content {
      backup_run_id = restore_backup_context.value.backup_run_id
      instance_id   = lookup(restore_backup_context.value, "instance_id", null)
      project       = lookup(restore_backup_context.value, "project", null)
    }
  }

  # Clone from another instance
  dynamic "clone" {
    for_each = var.clone_source != null ? [var.clone_source] : []
    content {
      source_instance_name = clone.value.source_instance_name
      point_in_time        = lookup(clone.value, "point_in_time", null)
      database_names       = lookup(clone.value, "database_names", null)
      allocated_ip_range   = lookup(clone.value, "allocated_ip_range", null)
    }
  }

  settings {
    tier                  = var.tier
    edition               = var.edition
    user_labels           = local.labels
    activation_policy     = var.activation_policy
    availability_type     = var.availability_type
    collation             = var.collation
    connector_enforcement = var.connector_enforcement

    disk_autoresize       = var.disk_autoresize
    disk_autoresize_limit = var.disk_autoresize_limit
    disk_size             = var.disk_size
    disk_type             = var.disk_type
    pricing_plan          = var.pricing_plan

    # Time zone (SQL Server only)
    time_zone = var.database_type == "SQLSERVER" ? var.time_zone : null

    # Database flags
    dynamic "database_flags" {
      for_each = local.database_flags
      content {
        name  = database_flags.key
        value = database_flags.value
      }
    }

    # Backup configuration
    dynamic "backup_configuration" {
      for_each = [local.backup_configuration]
      content {
        enabled                        = backup_configuration.value.enabled
        start_time                     = backup_configuration.value.start_time
        location                       = backup_configuration.value.location
        point_in_time_recovery_enabled = backup_configuration.value.point_in_time_recovery_enabled
        transaction_log_retention_days = backup_configuration.value.transaction_log_retention_days

        dynamic "backup_retention_settings" {
          for_each = backup_configuration.value.retained_backups != null ? [1] : []
          content {
            retained_backups = backup_configuration.value.retained_backups
            retention_unit   = backup_configuration.value.retention_unit
          }
        }
      }
    }

    # IP configuration
    dynamic "ip_configuration" {
      for_each = [local.ip_configuration]
      content {
        ipv4_enabled                                  = ip_configuration.value.ipv4_enabled
        private_network                               = ip_configuration.value.private_network
        allocated_ip_range                            = ip_configuration.value.allocated_ip_range
        enable_private_path_for_google_cloud_services = ip_configuration.value.enable_private_path_for_google_cloud_services
        require_ssl                                   = ip_configuration.value.require_ssl

        # Authorized networks
        dynamic "authorized_networks" {
          for_each = var.authorized_networks
          content {
            name            = authorized_networks.value.name
            value           = authorized_networks.value.value
            expiration_time = lookup(authorized_networks.value, "expiration_time", null)
          }
        }

        # PSC config
        dynamic "psc_config" {
          for_each = var.psc_config != null ? [var.psc_config] : []
          content {
            psc_enabled               = lookup(psc_config.value, "psc_enabled", null)
            allowed_consumer_projects = lookup(psc_config.value, "allowed_consumer_projects", null)
          }
        }
      }
    }

    # Maintenance window
    dynamic "maintenance_window" {
      for_each = [local.maintenance_window]
      content {
        day          = maintenance_window.value.day
        hour         = maintenance_window.value.hour
        update_track = maintenance_window.value.update_track
      }
    }

    # Insights config
    dynamic "insights_config" {
      for_each = var.insights_config != null ? [var.insights_config] : []
      content {
        query_insights_enabled  = lookup(insights_config.value, "query_insights_enabled", null)
        query_string_length     = lookup(insights_config.value, "query_string_length", null)
        record_application_tags = lookup(insights_config.value, "record_application_tags", null)
        record_client_address   = lookup(insights_config.value, "record_client_address", null)
        query_plans_per_minute  = lookup(insights_config.value, "query_plans_per_minute", null)
      }
    }

    # Password validation policy
    dynamic "password_validation_policy" {
      for_each = var.password_validation_policy != null ? [var.password_validation_policy] : []
      content {
        enable_password_policy      = lookup(password_validation_policy.value, "enable_password_policy", true)
        min_length                  = lookup(password_validation_policy.value, "min_length", 8)
        complexity                  = lookup(password_validation_policy.value, "complexity", null)
        reuse_interval              = lookup(password_validation_policy.value, "reuse_interval", null)
        disallow_username_substring = lookup(password_validation_policy.value, "disallow_username_substring", null)
        password_change_interval    = lookup(password_validation_policy.value, "password_change_interval", null)
      }
    }

    # SQL Server audit config
    dynamic "sql_server_audit_config" {
      for_each = var.database_type == "SQLSERVER" && var.sql_server_audit_config != null ? [var.sql_server_audit_config] : []
      content {
        bucket             = sql_server_audit_config.value.bucket
        retention_interval = lookup(sql_server_audit_config.value, "retention_interval", null)
        upload_interval    = lookup(sql_server_audit_config.value, "upload_interval", null)
      }
    }

    # Active Directory config
    dynamic "active_directory_config" {
      for_each = var.active_directory_config != null ? [var.active_directory_config] : []
      content {
        domain = active_directory_config.value.domain
      }
    }

    # Data cache config
    dynamic "data_cache_config" {
      for_each = var.data_cache_config != null ? [var.data_cache_config] : []
      content {
        data_cache_enabled = data_cache_config.value.data_cache_enabled
      }
    }

    # Deny maintenance period
    dynamic "deny_maintenance_period" {
      for_each = var.deny_maintenance_periods
      content {
        end_date   = deny_maintenance_period.value.end_date
        start_date = deny_maintenance_period.value.start_date
        time       = deny_maintenance_period.value.time
      }
    }
  }

  # Encryption configuration
  encryption_key_name = var.encryption_key_name

  timeouts {
    create = var.create_timeout
    update = var.update_timeout
    delete = var.delete_timeout
  }

  lifecycle {
    ignore_changes = concat(
      var.ignore_changes_list,
      var.ignore_default_location ? [settings[0].backup_configuration[0].location] : []
    )
  }

  depends_on = [var.module_depends_on]
}

# Root user password
resource "google_sql_user" "root" {
  count    = var.database_type != "POSTGRES" && var.enable_default_user ? 1 : 0
  project  = var.project_id
  instance = google_sql_database_instance.instance.name
  name     = "root"
  password = var.root_password != null ? var.root_password : random_password.root_password[0].result

  depends_on = [google_sql_database_instance.instance]
}

# Default postgres user
resource "google_sql_user" "default" {
  count    = var.database_type == "POSTGRES" && var.enable_default_user ? 1 : 0
  project  = var.project_id
  instance = google_sql_database_instance.instance.name
  name     = "postgres"
  password = var.root_password != null ? var.root_password : random_password.root_password[0].result

  depends_on = [google_sql_database_instance.instance]
}

# Additional databases
resource "google_sql_database" "database" {
  for_each = toset(var.additional_databases)

  project         = var.project_id
  instance        = google_sql_database_instance.instance.name
  name            = each.value
  charset         = var.database_charset
  collation       = var.database_collation
  deletion_policy = var.database_deletion_policy

  depends_on = [
    google_sql_user.root,
    google_sql_user.default
  ]
}

# Additional users
resource "google_sql_user" "additional_users" {
  for_each = var.additional_users

  project  = var.project_id
  instance = google_sql_database_instance.instance.name
  name     = each.key
  password = each.value.password

  # IAM authentication
  type = lookup(each.value, "type", null)

  # User deletion policy
  deletion_policy = lookup(each.value, "deletion_policy", null)

  depends_on = [
    google_sql_database_instance.instance,
    google_sql_user.root,
    google_sql_user.default
  ]
}

# Read replicas
resource "google_sql_database_instance" "read_replica" {
  for_each = { for replica in var.read_replicas : replica.name => replica }

  project              = var.project_id
  name                 = each.value.name
  database_version     = local.database_version
  region               = lookup(each.value, "region", var.region)
  master_instance_name = google_sql_database_instance.instance.name
  deletion_protection  = lookup(each.value, "deletion_protection", false)

  replica_configuration {
    failover_target = lookup(each.value, "failover_target", false)
  }

  settings {
    tier              = lookup(each.value, "tier", var.tier)
    activation_policy = lookup(each.value, "activation_policy", "ALWAYS")
    availability_type = lookup(each.value, "availability_type", "ZONAL")

    disk_autoresize       = lookup(each.value, "disk_autoresize", var.disk_autoresize)
    disk_autoresize_limit = lookup(each.value, "disk_autoresize_limit", var.disk_autoresize_limit)
    disk_size             = lookup(each.value, "disk_size", var.disk_size)
    disk_type             = lookup(each.value, "disk_type", var.disk_type)
    pricing_plan          = lookup(each.value, "pricing_plan", var.pricing_plan)
    user_labels           = merge(local.labels, lookup(each.value, "labels", {}))

    # Database flags (inherit from primary)
    dynamic "database_flags" {
      for_each = local.database_flags
      content {
        name  = database_flags.key
        value = database_flags.value
      }
    }

    # IP configuration (inherit most from primary)
    dynamic "ip_configuration" {
      for_each = [local.ip_configuration]
      content {
        ipv4_enabled                                  = ip_configuration.value.ipv4_enabled
        private_network                               = ip_configuration.value.private_network
        allocated_ip_range                            = ip_configuration.value.allocated_ip_range
        enable_private_path_for_google_cloud_services = ip_configuration.value.enable_private_path_for_google_cloud_services
        require_ssl                                   = ip_configuration.value.require_ssl

        # Authorized networks (can be different for replicas)
        dynamic "authorized_networks" {
          for_each = lookup(each.value, "authorized_networks", var.authorized_networks)
          content {
            name            = authorized_networks.value.name
            value           = authorized_networks.value.value
            expiration_time = lookup(authorized_networks.value, "expiration_time", null)
          }
        }
      }
    }

    # Insights config (inherit from primary)
    dynamic "insights_config" {
      for_each = var.insights_config != null ? [var.insights_config] : []
      content {
        query_insights_enabled  = lookup(insights_config.value, "query_insights_enabled", null)
        query_string_length     = lookup(insights_config.value, "query_string_length", null)
        record_application_tags = lookup(insights_config.value, "record_application_tags", null)
        record_client_address   = lookup(insights_config.value, "record_client_address", null)
        query_plans_per_minute  = lookup(insights_config.value, "query_plans_per_minute", null)
      }
    }
  }

  encryption_key_name = lookup(each.value, "encryption_key_name", var.encryption_key_name)

  timeouts {
    create = var.create_timeout
    update = var.update_timeout
    delete = var.delete_timeout
  }

  lifecycle {
    ignore_changes = var.ignore_changes_list
  }
}