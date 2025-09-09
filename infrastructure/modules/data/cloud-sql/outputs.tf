# Cloud SQL Module Outputs

output "instance_name" {
  description = "The name of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.name
}

output "instance_connection_name" {
  description = "The connection name of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.connection_name
}

output "instance_self_link" {
  description = "The self link of the Cloud SQL instance"
  value       = google_sql_database_instance.instance.self_link
}

output "instance_ip_address" {
  description = "The IP address of the Cloud SQL instance"
  value = {
    public  = try(google_sql_database_instance.instance.public_ip_address, null)
    private = try(google_sql_database_instance.instance.private_ip_address, null)
  }
}

output "database_version" {
  description = "The database version"
  value       = google_sql_database_instance.instance.database_version
}

output "databases" {
  description = "List of databases created"
  value       = [for db in google_sql_database.databases : db.name]
}

output "users" {
  description = "List of users created"
  value       = [for user in google_sql_user.users : user.name]
}

output "root_password" {
  description = "The root password"
  value       = var.root_password != "" ? var.root_password : try(random_password.root_password[0].result, null)
  sensitive   = true
}

output "user_passwords" {
  description = "Map of user passwords"
  value = {
    for k, v in var.users : k => (
      v.password != "" ? v.password : random_password.user_passwords[k].result
    )
  }
  sensitive = true
}

output "secret_manager_secret_ids" {
  description = "Map of Secret Manager secret IDs for passwords"
  value = {
    for k, v in google_secret_manager_secret.db_passwords : k => v.secret_id
  }
}

output "read_replica_names" {
  description = "Names of read replicas"
  value       = [for replica in google_sql_database_instance.read_replica : replica.name]
}

output "read_replica_connection_names" {
  description = "Connection names of read replicas"
  value       = [for replica in google_sql_database_instance.read_replica : replica.connection_name]
}

output "read_replica_ip_addresses" {
  description = "IP addresses of read replicas"
  value = [
    for replica in google_sql_database_instance.read_replica : {
      name    = replica.name
      public  = try(replica.public_ip_address, null)
      private = try(replica.private_ip_address, null)
    }
  ]
}