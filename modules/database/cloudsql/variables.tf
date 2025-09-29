# Cloud SQL Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "name" {
  description = "Name of the Cloud SQL instance. If null, will use name_prefix with random suffix"
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Name prefix for the Cloud SQL instance"
  type        = string
  default     = "cloudsql"
}

variable "region" {
  description = "The region for the Cloud SQL instance"
  type        = string
  default     = "us-central1"
}

variable "database_type" {
  description = "The type of database (POSTGRES, MYSQL, SQLSERVER)"
  type        = string
  default     = "POSTGRES"

  validation {
    condition     = contains(["POSTGRES", "MYSQL", "SQLSERVER"], var.database_type)
    error_message = "Database type must be POSTGRES, MYSQL, or SQLSERVER"
  }
}

variable "database_version" {
  description = "The database version"
  type        = string
  default     = null
}

variable "tier" {
  description = "The machine type to use"
  type        = string
  default     = "db-f1-micro"
}

variable "edition" {
  description = "The edition of the Cloud SQL instance (ENTERPRISE or ENTERPRISE_PLUS)"
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "deletion_protection" {
  description = "Enable deletion protection for the instance"
  type        = bool
  default     = true
}

# Instance Configuration
variable "activation_policy" {
  description = "The activation policy (ALWAYS, NEVER, ON_DEMAND)"
  type        = string
  default     = "ALWAYS"
}

variable "availability_type" {
  description = "The availability type (REGIONAL, ZONAL)"
  type        = string
  default     = "ZONAL"
}

variable "collation" {
  description = "The collation for SQL Server instances"
  type        = string
  default     = null
}

variable "connector_enforcement" {
  description = "Enforce connection through Cloud SQL Proxy"
  type        = string
  default     = "NOT_REQUIRED"
}

variable "time_zone" {
  description = "The time zone for SQL Server instances"
  type        = string
  default     = null
}

# Disk Configuration
variable "disk_autoresize" {
  description = "Enable disk autoresize"
  type        = bool
  default     = true
}

variable "disk_autoresize_limit" {
  description = "Maximum disk size for autoresize in GB"
  type        = number
  default     = 100
}

variable "disk_size" {
  description = "The disk size in GB"
  type        = number
  default     = 10
}

variable "disk_type" {
  description = "The disk type (PD_SSD, PD_HDD)"
  type        = string
  default     = "PD_SSD"
}

variable "pricing_plan" {
  description = "The pricing plan (PER_USE, PACKAGE)"
  type        = string
  default     = "PER_USE"
}

# Database Configuration
variable "database_charset" {
  description = "The charset for the database"
  type        = string
  default     = "utf8mb4"
}

variable "database_collation" {
  description = "The collation for the database"
  type        = string
  default     = null
}

variable "database_deletion_policy" {
  description = "The deletion policy for databases"
  type        = string
  default     = "ABANDON"
}

variable "database_flags" {
  description = "Database flags to set"
  type        = map(string)
  default     = {}
}

variable "additional_databases" {
  description = "List of additional databases to create"
  type        = list(string)
  default     = []
}

# User Configuration
variable "enable_default_user" {
  description = "Enable the default root/postgres user"
  type        = bool
  default     = true
}

variable "root_password" {
  description = "Password for the root/postgres user"
  type        = string
  default     = null
  sensitive   = true
}

variable "additional_users" {
  description = "Map of additional users to create"
  type = map(object({
    password        = string
    type           = optional(string)
    deletion_policy = optional(string)
  }))
  default   = {}
  sensitive = true
}

# Backup Configuration
variable "backup_configuration" {
  description = "Backup configuration settings"
  type = object({
    enabled                        = optional(bool)
    start_time                     = optional(string)
    location                       = optional(string)
    point_in_time_recovery_enabled = optional(bool)
    transaction_log_retention_days = optional(number)
    retained_backups              = optional(number)
    retention_unit                = optional(string)
  })
  default = {}
}

# IP Configuration
variable "ip_configuration" {
  description = "IP configuration settings"
  type = object({
    ipv4_enabled                                  = optional(bool)
    private_network                               = optional(string)
    allocated_ip_range                            = optional(string)
    enable_private_path_for_google_cloud_services = optional(bool)
    require_ssl                                   = optional(bool)
  })
  default = {}
}

variable "authorized_networks" {
  description = "List of authorized networks"
  type = list(object({
    name            = string
    value           = string
    expiration_time = optional(string)
  }))
  default = []
}

variable "require_ssl" {
  description = "Require SSL connections"
  type        = bool
  default     = false
}

variable "psc_config" {
  description = "PSC configuration"
  type = object({
    psc_enabled               = optional(bool)
    allowed_consumer_projects = optional(list(string))
  })
  default = null
}

# Maintenance Configuration
variable "maintenance_window" {
  description = "Maintenance window configuration"
  type = object({
    day          = optional(number)
    hour         = optional(number)
    update_track = optional(string)
  })
  default = {}
}

variable "deny_maintenance_periods" {
  description = "List of deny maintenance periods"
  type = list(object({
    end_date   = string
    start_date = string
    time       = string
  }))
  default = []
}

# Insights Configuration
variable "insights_config" {
  description = "Query insights configuration"
  type = object({
    query_insights_enabled  = optional(bool)
    query_string_length    = optional(number)
    record_application_tags = optional(bool)
    record_client_address  = optional(bool)
    query_plans_per_minute = optional(number)
  })
  default = null
}

# Password Validation Policy
variable "password_validation_policy" {
  description = "Password validation policy configuration"
  type = object({
    enable_password_policy      = optional(bool)
    min_length                 = optional(number)
    complexity                 = optional(string)
    reuse_interval             = optional(number)
    disallow_username_substring = optional(bool)
    password_change_interval   = optional(string)
  })
  default = null
}

# SQL Server Specific
variable "sql_server_audit_config" {
  description = "SQL Server audit configuration"
  type = object({
    bucket             = string
    retention_interval = optional(string)
    upload_interval    = optional(string)
  })
  default = null
}

variable "active_directory_config" {
  description = "Active Directory configuration"
  type = object({
    domain = string
  })
  default = null
}

# Data Cache Configuration
variable "data_cache_config" {
  description = "Data cache configuration"
  type = object({
    data_cache_enabled = bool
  })
  default = null
}

# Encryption
variable "encryption_key_name" {
  description = "KMS key for encryption"
  type        = string
  default     = null
}

# Replication Configuration
variable "master_instance_name" {
  description = "The name of the master instance for read replicas"
  type        = string
  default     = null
}

variable "replica_configuration" {
  description = "Replica configuration for the instance"
  type = object({
    ca_certificate            = optional(string)
    client_certificate        = optional(string)
    client_key               = optional(string)
    connect_retry_interval   = optional(number)
    dump_file_path           = optional(string)
    failover_target          = optional(bool)
    master_heartbeat_period  = optional(number)
    password                 = optional(string)
    ssl_cipher               = optional(string)
    username                 = optional(string)
    verify_server_certificate = optional(bool)
  })
  default = null
}

variable "read_replicas" {
  description = "List of read replicas to create"
  type = list(object({
    name                = string
    region              = optional(string)
    tier                = optional(string)
    availability_type   = optional(string)
    disk_size           = optional(number)
    disk_type           = optional(string)
    disk_autoresize     = optional(bool)
    disk_autoresize_limit = optional(number)
    pricing_plan        = optional(string)
    deletion_protection = optional(bool)
    failover_target     = optional(bool)
    activation_policy   = optional(string)
    authorized_networks = optional(list(object({
      name            = string
      value           = string
      expiration_time = optional(string)
    })))
    encryption_key_name = optional(string)
    labels             = optional(map(string))
  }))
  default = []
}

# Restore and Clone Configuration
variable "restore_backup_context" {
  description = "Configuration for restoring from a backup"
  type = object({
    backup_run_id = string
    instance_id   = optional(string)
    project      = optional(string)
  })
  default = null
}

variable "clone_source" {
  description = "Configuration for cloning from another instance"
  type = object({
    source_instance_name = string
    point_in_time       = optional(string)
    database_names      = optional(list(string))
    allocated_ip_range  = optional(string)
  })
  default = null
}

# Labels
variable "labels" {
  description = "Labels to apply to the instance"
  type        = map(string)
  default     = {}
}

# Timeouts
variable "create_timeout" {
  description = "Timeout for create operations"
  type        = string
  default     = "60m"
}

variable "update_timeout" {
  description = "Timeout for update operations"
  type        = string
  default     = "60m"
}

variable "delete_timeout" {
  description = "Timeout for delete operations"
  type        = string
  default     = "60m"
}

# Lifecycle
variable "ignore_changes_list" {
  description = "List of attributes to ignore changes on"
  type        = list(string)
  default     = []
}

variable "ignore_default_location" {
  description = "Ignore changes to default backup location"
  type        = bool
  default     = true
}

variable "module_depends_on" {
  description = "List of modules or resources this module depends on"
  type        = list(any)
  default     = []
}