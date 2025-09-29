# Cloud SQL Module Outputs

# Instance Information
output "instance_name" {
  description = "The name of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.name
}

output "instance_id" {
  description = "The ID of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.id
}

output "instance_self_link" {
  description = "The self link of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.self_link
}

output "instance_connection_name" {
  description = "The connection name of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.connection_name
}

output "instance_service_account_email" {
  description = "The service account email associated with the Cloud SQL instance"
  value       = google_sql_database_instance.instance.service_account_email_address
}

# Connection Information
output "public_ip_address" {
  description = "The public IPv4 address of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.public_ip_address
}

output "private_ip_address" {
  description = "The private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.private_ip_address
}

output "ip_addresses" {
  description = "All IP addresses of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.ip_address
}

output "first_ip_address" {
  description = "The first IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.first_ip_address
}

# Database Information
output "database_version" {
  description = "The database version running on the Cloud SQL instance"
  value       = google_sql_database_instance.instance.database_version
}

output "database_type" {
  description = "The type of database"
  value       = var.database_type
}

output "databases" {
  description = "List of databases created"
  value       = keys(google_sql_database.database)
}

output "database_resources" {
  description = "Map of database resources"
  value       = google_sql_database.database
}

# User Information
output "root_user" {
  description = "The name of the root user"
  value       = var.database_type == "POSTGRES" ? "postgres" : "root"
}

output "root_password" {
  description = "The password for the root user"
  value       = var.root_password != null ? var.root_password : (length(random_password.root_password) > 0 ? random_password.root_password[0].result : null)
  sensitive   = true
}

output "additional_users" {
  description = "Map of additional users created"
  value       = keys(google_sql_user.additional_users)
}

# Configuration Details
output "settings" {
  description = "The settings of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.settings[0]
}

output "tier" {
  description = "The machine tier of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.settings[0].tier
}

output "disk_size" {
  description = "The disk size of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.settings[0].disk_size
}

output "disk_type" {
  description = "The disk type of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.settings[0].disk_type
}

output "availability_type" {
  description = "The availability type of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.settings[0].availability_type
}

output "activation_policy" {
  description = "The activation policy of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.settings[0].activation_policy
}

# Backup Information
output "backup_configuration" {
  description = "The backup configuration of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.settings[0].backup_configuration
}

output "backup_start_time" {
  description = "The start time for backups"
  value       = try(google_sql_database_instance.instance.settings[0].backup_configuration[0].start_time, null)
}

output "point_in_time_recovery_enabled" {
  description = "Whether point-in-time recovery is enabled"
  value       = try(google_sql_database_instance.instance.settings[0].backup_configuration[0].point_in_time_recovery_enabled, false)
}

# Network Configuration
output "authorized_networks" {
  description = "The authorized networks for the Cloud SQL instance"
  value       = try(google_sql_database_instance.instance.settings[0].ip_configuration[0].authorized_networks, [])
}

output "require_ssl" {
  description = "Whether SSL is required for connections"
  value       = try(google_sql_database_instance.instance.settings[0].ip_configuration[0].require_ssl, false)
}

output "private_network" {
  description = "The private network connected to the Cloud SQL instance"
  value       = try(google_sql_database_instance.instance.settings[0].ip_configuration[0].private_network, null)
}

# Maintenance Window
output "maintenance_window" {
  description = "The maintenance window configuration"
  value       = try(google_sql_database_instance.instance.settings[0].maintenance_window[0], null)
}

# Encryption
output "encryption_key_name" {
  description = "The KMS key used for encryption"
  value       = google_sql_database_instance.instance.encryption_key_name
}

# Read Replicas
output "read_replicas" {
  description = "Information about read replicas"
  value = {
    for k, v in google_sql_database_instance.read_replica : k => {
      name                = v.name
      connection_name     = v.connection_name
      public_ip_address   = v.public_ip_address
      private_ip_address  = v.private_ip_address
      region             = v.region
      self_link          = v.self_link
      service_account    = v.service_account_email_address
    }
  }
}

output "read_replica_connection_names" {
  description = "Connection names of all read replicas"
  value       = [for k, v in google_sql_database_instance.read_replica : v.connection_name]
}

output "read_replica_ips" {
  description = "IP addresses of all read replicas"
  value = {
    for k, v in google_sql_database_instance.read_replica : k => {
      public  = v.public_ip_address
      private = v.private_ip_address
    }
  }
}

# State and Status
output "state" {
  description = "The current state of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.state
}

output "maintenance_version" {
  description = "The current maintenance version of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.maintenance_version
}

# Insights Configuration
output "insights_config" {
  description = "The query insights configuration"
  value       = try(google_sql_database_instance.instance.settings[0].insights_config[0], null)
}

# Labels
output "labels" {
  description = "The labels attached to the Cloud SQL instance"
  value       = google_sql_database_instance.instance.settings[0].user_labels
}

# Connection Strings
output "connection_strings" {
  description = "Connection strings for various scenarios"
  value = {
    public = var.database_type == "POSTGRES" ? (
      "postgresql://${var.database_type == "POSTGRES" ? "postgres" : "root"}:${urlencode(var.root_password != null ? var.root_password : (length(random_password.root_password) > 0 ? random_password.root_password[0].result : ""))}@${google_sql_database_instance.instance.public_ip_address}:5432/postgres"
    ) : var.database_type == "MYSQL" ? (
      "mysql://${var.database_type == "POSTGRES" ? "postgres" : "root"}:${urlencode(var.root_password != null ? var.root_password : (length(random_password.root_password) > 0 ? random_password.root_password[0].result : ""))}@${google_sql_database_instance.instance.public_ip_address}:3306/"
    ) : null

    private = var.database_type == "POSTGRES" && google_sql_database_instance.instance.private_ip_address != null ? (
      "postgresql://${var.database_type == "POSTGRES" ? "postgres" : "root"}:${urlencode(var.root_password != null ? var.root_password : (length(random_password.root_password) > 0 ? random_password.root_password[0].result : ""))}@${google_sql_database_instance.instance.private_ip_address}:5432/postgres"
    ) : var.database_type == "MYSQL" && google_sql_database_instance.instance.private_ip_address != null ? (
      "mysql://${var.database_type == "POSTGRES" ? "postgres" : "root"}:${urlencode(var.root_password != null ? var.root_password : (length(random_password.root_password) > 0 ? random_password.root_password[0].result : ""))}@${google_sql_database_instance.instance.private_ip_address}:3306/"
    ) : null

    socket = "/cloudsql/${google_sql_database_instance.instance.connection_name}"
  }
  sensitive = true
}

# Cloud SQL Proxy Command
output "cloud_sql_proxy_command" {
  description = "Command to connect using Cloud SQL Proxy"
  value       = "cloud_sql_proxy -instances=${google_sql_database_instance.instance.connection_name}=tcp:5432"
}

# gcloud Commands
output "gcloud_commands" {
  description = "Useful gcloud commands for managing the instance"
  value = {
    connect = var.database_type == "POSTGRES" ? (
      "gcloud sql connect ${google_sql_database_instance.instance.name} --user=postgres --database=postgres"
    ) : var.database_type == "MYSQL" ? (
      "gcloud sql connect ${google_sql_database_instance.instance.name} --user=root"
    ) : (
      "gcloud sql connect ${google_sql_database_instance.instance.name}"
    )

    describe = "gcloud sql instances describe ${google_sql_database_instance.instance.name}"

    backup = "gcloud sql backups create --instance=${google_sql_database_instance.instance.name}"

    export = var.database_type == "POSTGRES" ? (
      "gcloud sql export sql ${google_sql_database_instance.instance.name} gs://BUCKET/FILENAME.sql --database=postgres"
    ) : (
      "gcloud sql export sql ${google_sql_database_instance.instance.name} gs://BUCKET/FILENAME.sql"
    )
  }
}

# Console URLs
output "console_urls" {
  description = "Google Cloud Console URLs for the instance"
  value = {
    overview = "https://console.cloud.google.com/sql/instances/${google_sql_database_instance.instance.name}/overview?project=${var.project_id}"

    users = "https://console.cloud.google.com/sql/instances/${google_sql_database_instance.instance.name}/users?project=${var.project_id}"

    databases = "https://console.cloud.google.com/sql/instances/${google_sql_database_instance.instance.name}/databases?project=${var.project_id}"

    backups = "https://console.cloud.google.com/sql/instances/${google_sql_database_instance.instance.name}/backups?project=${var.project_id}"

    monitoring = "https://console.cloud.google.com/sql/instances/${google_sql_database_instance.instance.name}/monitoring?project=${var.project_id}"
  }
}