# Cloud SQL Module

# Random suffix for database instance
resource "random_id" "db_suffix" {
  byte_length = 4
}

# Cloud SQL Instance
resource "google_sql_database_instance" "instance" {
  name             = "${var.name}-${random_id.db_suffix.hex}"
  project          = var.project_id
  region           = var.region
  database_version = var.database_version
  
  settings {
    tier              = var.tier
    availability_type = var.high_availability ? "REGIONAL" : "ZONAL"
    disk_size         = var.disk_size_gb
    disk_type         = var.disk_type
    disk_autoresize   = var.disk_autoresize
    
    backup_configuration {
      enabled                        = var.backup_enabled
      start_time                     = var.backup_start_time
      location                       = var.backup_location
      point_in_time_recovery_enabled = var.point_in_time_recovery
      transaction_log_retention_days = var.transaction_log_retention_days
      
      backup_retention_settings {
        retained_backups = var.retained_backups
        retention_unit   = "COUNT"
      }
    }
    
    ip_configuration {
      ipv4_enabled                                  = var.ipv4_enabled
      private_network                               = var.private_network
      enable_private_path_for_google_cloud_services = var.enable_private_path
      require_ssl                                   = var.require_ssl
      
      dynamic "authorized_networks" {
        for_each = var.authorized_networks
        content {
          name  = authorized_networks.value.name
          value = authorized_networks.value.cidr
        }
      }
    }
    
    maintenance_window {
      day          = var.maintenance_window_day
      hour         = var.maintenance_window_hour
      update_track = var.maintenance_update_track
    }
    
    database_flags {
      name  = "max_connections"
      value = var.max_connections
    }
    
    dynamic "database_flags" {
      for_each = var.database_flags
      content {
        name  = database_flags.value.name
        value = database_flags.value.value
      }
    }
    
    insights_config {
      query_insights_enabled  = var.query_insights_enabled
      query_string_length    = var.query_string_length
      record_application_tags = var.record_application_tags
      record_client_address  = var.record_client_address
    }
    
    user_labels = var.labels
    
    deletion_protection_enabled = var.deletion_protection
  }
  
  deletion_protection = var.deletion_protection
  
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [name]
  }
}

# Databases
resource "google_sql_database" "databases" {
  for_each = toset(var.databases)
  
  name     = each.value
  project  = var.project_id
  instance = google_sql_database_instance.instance.name
  
  charset   = var.database_charset
  collation = var.database_collation
}

# Root User Password
resource "random_password" "root_password" {
  count = var.root_password == "" ? 1 : 0
  
  length  = 32
  special = true
}

# Users
resource "google_sql_user" "users" {
  for_each = var.users
  
  name     = each.key
  project  = var.project_id
  instance = google_sql_database_instance.instance.name
  password = each.value.password != "" ? each.value.password : random_password.user_passwords[each.key].result
  
  deletion_policy = lookup(each.value, "deletion_policy", "ABANDON")
}

# Random passwords for users without specified passwords
resource "random_password" "user_passwords" {
  for_each = {
    for k, v in var.users : k => v
    if v.password == ""
  }
  
  length  = 24
  special = true
}

# Store passwords in Secret Manager
resource "google_secret_manager_secret" "db_passwords" {
  for_each = var.store_passwords_in_secret_manager ? var.users : {}
  
  secret_id = "${var.name}-${each.key}-password"
  project   = var.project_id
  
  labels = merge(
    var.labels,
    {
      database = var.name
      user     = each.key
    }
  )
  
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "db_passwords" {
  for_each = var.store_passwords_in_secret_manager ? var.users : {}
  
  secret      = google_secret_manager_secret.db_passwords[each.key].id
  secret_data = each.value.password != "" ? each.value.password : random_password.user_passwords[each.key].result
}

# Read Replica (optional)
resource "google_sql_database_instance" "read_replica" {
  count = var.read_replica_count
  
  name                 = "${var.name}-replica-${count.index}-${random_id.db_suffix.hex}"
  project              = var.project_id
  region               = var.read_replica_regions[count.index]
  database_version     = var.database_version
  master_instance_name = google_sql_database_instance.instance.name
  
  replica_configuration {
    failover_target = false
  }
  
  settings {
    tier            = var.read_replica_tier != "" ? var.read_replica_tier : var.tier
    disk_size       = var.disk_size_gb
    disk_type       = var.disk_type
    disk_autoresize = var.disk_autoresize
    
    ip_configuration {
      ipv4_enabled                                  = var.ipv4_enabled
      private_network                               = var.private_network
      enable_private_path_for_google_cloud_services = var.enable_private_path
      require_ssl                                   = var.require_ssl
    }
    
    database_flags {
      name  = "max_connections"
      value = var.max_connections
    }
    
    dynamic "database_flags" {
      for_each = var.database_flags
      content {
        name  = database_flags.value.name
        value = database_flags.value.value
      }
    }
    
    user_labels = merge(
      var.labels,
      {
        replica_index = count.index
      }
    )
  }
  
  lifecycle {
    ignore_changes = [name]
  }
}