# Memorystore Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for Memorystore instances"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
  default     = "memorystore"
}

# Network Configuration
variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = null
}

variable "subnetwork_name" {
  description = "Name of the subnetwork"
  type        = string
  default     = null
}

variable "location_id" {
  description = "The zone where the Redis instance should be provisioned"
  type        = string
  default     = null
}

variable "alternative_location_id" {
  description = "The alternative zone where the Redis instance should be provisioned"
  type        = string
  default     = null
}

# Private Service Access Configuration
variable "enable_private_service_access" {
  description = "Whether to enable private service access"
  type        = bool
  default     = true
}

variable "private_ip_prefix_length" {
  description = "The prefix length of the IP range for private service access"
  type        = number
  default     = 16
}

# Redis Instances Configuration
variable "redis_instances" {
  description = "Map of Redis instance configurations"
  type = map(object({
    tier                    = optional(string) # "BASIC", "STANDARD_HA"
    memory_size_gb          = optional(number)
    redis_version           = optional(string) # "REDIS_3_2", "REDIS_4_0", "REDIS_5_0", "REDIS_6_X"
    display_name            = optional(string)
    reserved_ip_range       = optional(string)
    connect_mode            = optional(string) # "DIRECT_PEERING", "PRIVATE_SERVICE_ACCESS"
    auth_enabled            = optional(bool)
    transit_encryption_mode = optional(string) # "SERVER_AUTHENTICATION", "DISABLED"

    persistence_config = optional(object({
      persistence_mode        = optional(string) # "RDB", "AOF", "DISABLED"
      rdb_snapshot_period     = optional(string) # "ONE_HOUR", "SIX_HOURS", "TWELVE_HOURS", "TWENTY_FOUR_HOURS"
      rdb_snapshot_start_time = optional(string) # HH:MM format
    }))

    maintenance_policy = optional(object({
      weekly_maintenance_window = optional(list(object({
        day = string # "MONDAY", "TUESDAY", etc.
        start_time = object({
          hours   = number
          minutes = number
          seconds = number
          nanos   = number
        })
        duration = string # Duration in seconds with suffix 's'
      })))
    }))

    redis_configs = optional(map(string))
    labels        = optional(map(string))
  }))
  default = {}
}

# Memcached Instances Configuration
variable "memcached_instances" {
  description = "Map of Memcached instance configurations"
  type = map(object({
    node_count       = optional(number)
    memcache_version = optional(string) # "MEMCACHE_1_5", "MEMCACHE_1_6"
    display_name     = optional(string)
    zones            = optional(list(string))

    node_config = optional(list(object({
      cpu_count      = number
      memory_size_mb = number
    })))

    memcache_parameters = optional(map(string))
    labels              = optional(map(string))
  }))
  default = {}
}

# Service Account Configuration
variable "create_service_account" {
  description = "Whether to create a service account for Memorystore operations"
  type        = bool
  default     = false
}

variable "service_account_name" {
  description = "Name of the service account"
  type        = string
  default     = null
}

variable "grant_service_account_roles" {
  description = "Whether to grant roles to the service account"
  type        = bool
  default     = false
}

variable "service_account_roles" {
  description = "Roles to grant to the service account"
  type        = list(string)
  default = [
    "roles/redis.admin",
    "roles/memcache.admin",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter"
  ]
}

# Firewall Configuration
variable "create_firewall_rules" {
  description = "Whether to create firewall rules for Memorystore access"
  type        = bool
  default     = false
}

variable "allowed_source_ranges" {
  description = "Source IP ranges allowed to access Memorystore instances"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "firewall_target_tags" {
  description = "Target tags for firewall rules"
  type        = list(string)
  default     = ["memorystore-client"]
}

# IAM Configuration
variable "redis_iam_bindings" {
  description = "IAM bindings for Redis instances"
  type = map(object({
    instance_name = string
    role          = string
    member        = string
  }))
  default = {}
}

# Monitoring Configuration
variable "create_monitoring_alerts" {
  description = "Whether to create monitoring alert policies"
  type        = bool
  default     = false
}

variable "monitoring_alerts" {
  description = "Monitoring alert policies configuration"
  type = map(object({
    display_name           = string
    condition_display_name = string
    filter                 = string
    threshold_value        = number
    combiner               = optional(string)
    enabled                = optional(bool)
    duration               = optional(string)
    comparison             = optional(string)
    alignment_period       = optional(string)
    per_series_aligner     = optional(string)
    cross_series_reducer   = optional(string)
    group_by_fields        = optional(list(string))
    trigger_count          = optional(number)
    trigger_percent        = optional(number)
    notification_channels  = optional(list(string))
    auto_close             = optional(string)
    rate_limit = optional(object({
      period = string
    }))
    documentation_content   = optional(string)
    documentation_mime_type = optional(string)
    documentation_subject   = optional(string)
    labels                  = optional(map(string))
  }))
  default = {}
}

variable "create_monitoring_dashboard" {
  description = "Whether to create a monitoring dashboard"
  type        = bool
  default     = false
}

# Log Metrics Configuration
variable "create_log_metrics" {
  description = "Whether to create log-based metrics"
  type        = bool
  default     = false
}

variable "log_metrics" {
  description = "Log-based metrics configuration"
  type = map(object({
    filter           = string
    label_extractors = optional(map(string))

    metric_descriptor = optional(object({
      metric_kind  = string
      value_type   = string
      unit         = optional(string)
      display_name = optional(string)
      labels = optional(list(object({
        key         = string
        value_type  = string
        description = optional(string)
      })))
    }))

    bucket_options = optional(object({
      linear_buckets = optional(object({
        num_finite_buckets = number
        width              = number
        offset             = number
      }))

      exponential_buckets = optional(object({
        num_finite_buckets = number
        growth_factor      = number
        scale              = number
      }))
    }))
  }))
  default = {}
}

# Backup Configuration
variable "enable_redis_backups" {
  description = "Whether to enable Redis backup storage"
  type        = bool
  default     = false
}

variable "redis_backup_configs" {
  description = "Redis backup configuration"
  type = map(object({
    backup_location = string
    retention_days  = number
  }))
  default = {}
}

variable "enable_automated_backups" {
  description = "Whether to enable automated backup functions"
  type        = bool
  default     = false
}

variable "backup_functions" {
  description = "Backup function configurations"
  type = map(object({
    runtime               = string
    entry_point           = string
    source_bucket         = string
    source_object         = string
    trigger_topic         = string
    memory_mb             = optional(number)
    timeout_seconds       = optional(number)
    environment_variables = optional(map(string))
    labels                = optional(map(string))
  }))
  default = {}
}

# High Availability Configuration
variable "high_availability_config" {
  description = "High availability configuration"
  type = object({
    enable_cross_region_replicas = optional(bool)
    replica_regions              = optional(list(string))
    failover_mode                = optional(string) # "AUTOMATIC", "MANUAL"
    read_replicas_count          = optional(number)
  })
  default = {
    enable_cross_region_replicas = false
  }
}

# Security Configuration
variable "security_config" {
  description = "Security configuration for Memorystore"
  type = object({
    enable_auth               = optional(bool)
    auth_string               = optional(string)
    enable_tls                = optional(bool)
    tls_certificates          = optional(list(string))
    customer_managed_key      = optional(string)
    allowed_persistence_modes = optional(list(string))
  })
  default = {
    enable_auth = true
    enable_tls  = true
  }
}

# Performance Configuration
variable "performance_config" {
  description = "Performance configuration for instances"
  type = object({
    max_memory_policy      = optional(string) # "ALLKEYS_LRU", "VOLATILE_LRU", etc.
    timeout_seconds        = optional(number)
    tcp_keepalive          = optional(number)
    max_clients            = optional(number)
    notify_keyspace_events = optional(string)
  })
  default = {}
}

# Scaling Configuration
variable "scaling_config" {
  description = "Scaling configuration for instances"
  type = object({
    enable_auto_scaling = optional(bool)
    min_memory_gb       = optional(number)
    max_memory_gb       = optional(number)
    scaling_threshold   = optional(number)
    scaling_cooldown    = optional(number)
  })
  default = {
    enable_auto_scaling = false
  }
}

# Maintenance Configuration
variable "maintenance_config" {
  description = "Maintenance configuration"
  type = object({
    maintenance_window_day  = optional(string)
    maintenance_window_hour = optional(number)
    maintenance_duration    = optional(string)
    allow_automatic_updates = optional(bool)
    maintenance_exclusions = optional(list(object({
      start_time = string
      end_time   = string
      scope      = string
    })))
  })
  default = {
    maintenance_window_day  = "SUNDAY"
    maintenance_window_hour = 3
    allow_automatic_updates = true
  }
}

# Connection Configuration
variable "connection_config" {
  description = "Connection configuration for clients"
  type = object({
    connection_pool_size = optional(number)
    connection_timeout   = optional(number)
    read_timeout         = optional(number)
    max_idle_connections = optional(number)
    keepalive_interval   = optional(number)
  })
  default = {}
}

# Cost Optimization Configuration
variable "cost_optimization_config" {
  description = "Cost optimization configuration"
  type = object({
    enable_spot_instances = optional(bool)
    preemptible_instances = optional(bool)
    reserved_capacity     = optional(bool)
    cost_allocation_tags  = optional(map(string))
  })
  default = {
    enable_spot_instances = false
  }
}

# Disaster Recovery Configuration
variable "disaster_recovery_config" {
  description = "Disaster recovery configuration"
  type = object({
    enable_point_in_time_recovery = optional(bool)
    backup_retention_days         = optional(number)
    cross_region_backup_enabled   = optional(bool)
    recovery_time_objective       = optional(number)
    recovery_point_objective      = optional(number)
  })
  default = {
    enable_point_in_time_recovery = true
    backup_retention_days         = 7
  }
}

# Compliance Configuration
variable "compliance_config" {
  description = "Compliance configuration"
  type = object({
    data_residency_regions = optional(list(string))
    encryption_at_rest     = optional(bool)
    encryption_in_transit  = optional(bool)
    audit_logging_enabled  = optional(bool)
    access_logging_enabled = optional(bool)
  })
  default = {
    encryption_at_rest    = true
    encryption_in_transit = true
    audit_logging_enabled = true
  }
}

# Labels and Tags
variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

# Advanced Features
variable "enable_import_export" {
  description = "Whether to enable import/export functionality"
  type        = bool
  default     = false
}

variable "enable_pub_sub_notifications" {
  description = "Whether to enable Pub/Sub notifications"
  type        = bool
  default     = false
}

variable "enable_stackdriver_integration" {
  description = "Whether to enable Stackdriver integration"
  type        = bool
  default     = true
}

# Multi-region Configuration
variable "multi_region_config" {
  description = "Multi-region configuration"
  type = object({
    enable_multi_region = optional(bool)
    primary_region      = optional(string)
    secondary_regions   = optional(list(string))
    replication_mode    = optional(string) # "ASYNC", "SYNC"
    consistency_level   = optional(string) # "EVENTUAL", "STRONG"
  })
  default = {
    enable_multi_region = false
  }
}

# Lifecycle Configuration
variable "lifecycle_config" {
  description = "Lifecycle configuration for resources"
  type = object({
    prevent_destroy       = optional(bool)
    ignore_changes        = optional(list(string))
    create_before_destroy = optional(bool)
  })
  default = {
    prevent_destroy = true
  }
}