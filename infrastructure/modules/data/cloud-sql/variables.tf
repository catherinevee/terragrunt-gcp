# Cloud SQL Module Variables

variable "name" {
  description = "The name of the Cloud SQL instance"
  type        = string
}

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for the Cloud SQL instance"
  type        = string
}

variable "database_version" {
  description = "The database version (e.g., POSTGRES_14, MYSQL_8_0)"
  type        = string
  default     = "POSTGRES_14"
}

variable "tier" {
  description = "The machine type/tier (e.g., db-f1-micro, db-n1-standard-1)"
  type        = string
  default     = "db-f1-micro"
}

variable "high_availability" {
  description = "Whether to enable high availability (regional)"
  type        = bool
  default     = false
}

variable "disk_size_gb" {
  description = "The disk size in GB"
  type        = number
  default     = 10
}

variable "disk_type" {
  description = "The disk type (PD_SSD or PD_HDD)"
  type        = string
  default     = "PD_SSD"
}

variable "disk_autoresize" {
  description = "Whether to enable disk autoresize"
  type        = bool
  default     = true
}

variable "backup_enabled" {
  description = "Whether to enable backups"
  type        = bool
  default     = true
}

variable "backup_start_time" {
  description = "The start time for backups in HH:MM format"
  type        = string
  default     = "03:00"
}

variable "backup_location" {
  description = "The location for backups"
  type        = string
  default     = null
}

variable "point_in_time_recovery" {
  description = "Whether to enable point-in-time recovery"
  type        = bool
  default     = true
}

variable "transaction_log_retention_days" {
  description = "Number of days to retain transaction logs"
  type        = number
  default     = 7
}

variable "retained_backups" {
  description = "Number of backups to retain"
  type        = number
  default     = 7
}

variable "ipv4_enabled" {
  description = "Whether to assign a public IP"
  type        = bool
  default     = false
}

variable "private_network" {
  description = "The VPC network for private IP"
  type        = string
  default     = ""
}

variable "enable_private_path" {
  description = "Whether to enable private path for Google Cloud services"
  type        = bool
  default     = true
}

variable "require_ssl" {
  description = "Whether to require SSL connections"
  type        = bool
  default     = true
}

variable "authorized_networks" {
  description = "List of authorized networks"
  type = list(object({
    name = string
    cidr = string
  }))
  default = []
}

variable "maintenance_window_day" {
  description = "Day of week for maintenance window (1-7, 1=Monday)"
  type        = number
  default     = 7
}

variable "maintenance_window_hour" {
  description = "Hour of day for maintenance window (0-23)"
  type        = number
  default     = 3
}

variable "maintenance_update_track" {
  description = "Maintenance update track (stable or canary)"
  type        = string
  default     = "stable"
}

variable "max_connections" {
  description = "Maximum number of connections"
  type        = string
  default     = "100"
}

variable "database_flags" {
  description = "Database flags"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "query_insights_enabled" {
  description = "Whether to enable Query Insights"
  type        = bool
  default     = true
}

variable "query_string_length" {
  description = "Maximum query string length to log"
  type        = number
  default     = 1024
}

variable "record_application_tags" {
  description = "Whether to record application tags"
  type        = bool
  default     = true
}

variable "record_client_address" {
  description = "Whether to record client address"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection"
  type        = bool
  default     = true
}

variable "databases" {
  description = "List of database names to create"
  type        = list(string)
  default     = []
}

variable "database_charset" {
  description = "The charset for databases"
  type        = string
  default     = "UTF8"
}

variable "database_collation" {
  description = "The collation for databases"
  type        = string
  default     = null
}

variable "root_password" {
  description = "The root password (auto-generated if not provided)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "users" {
  description = "Map of database users to create"
  type = map(object({
    password        = string
    deletion_policy = optional(string)
  }))
  default   = {}
  sensitive = true
}

variable "store_passwords_in_secret_manager" {
  description = "Whether to store passwords in Secret Manager"
  type        = bool
  default     = true
}

variable "read_replica_count" {
  description = "Number of read replicas to create"
  type        = number
  default     = 0
}

variable "read_replica_regions" {
  description = "Regions for read replicas"
  type        = list(string)
  default     = []
}

variable "read_replica_tier" {
  description = "The tier for read replicas (defaults to primary tier)"
  type        = string
  default     = ""
}

variable "labels" {
  description = "Labels to apply to the instance"
  type        = map(string)
  default     = {}
}