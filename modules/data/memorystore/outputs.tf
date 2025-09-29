# Memorystore Module Outputs

# Redis Instance Outputs
output "redis_instance_ids" {
  description = "The identifiers for Redis instances"
  value = {
    for k, v in google_redis_instance.redis : k => v.id
  }
}

output "redis_instance_names" {
  description = "The names of Redis instances"
  value = {
    for k, v in google_redis_instance.redis : k => v.name
  }
}

output "redis_instance_hosts" {
  description = "The hostnames of Redis instances"
  value = {
    for k, v in google_redis_instance.redis : k => v.host
  }
}

output "redis_instance_ports" {
  description = "The ports of Redis instances"
  value = {
    for k, v in google_redis_instance.redis : k => v.port
  }
}

output "redis_instance_current_location_ids" {
  description = "The current zone where the Redis instance is provisioned"
  value = {
    for k, v in google_redis_instance.redis : k => v.current_location_id
  }
}

output "redis_instance_memory_sizes" {
  description = "The memory sizes of Redis instances in GB"
  value = {
    for k, v in google_redis_instance.redis : k => v.memory_size_gb
  }
}

output "redis_instance_persistence_iam_identity" {
  description = "Cloud IAM identity used by import/export operations"
  value = {
    for k, v in google_redis_instance.redis : k => v.persistence_iam_identity
  }
}

output "redis_instance_server_ca_certs" {
  description = "List of server CA certificates for Redis instances"
  value = {
    for k, v in google_redis_instance.redis : k => v.server_ca_certs
  }
}

output "redis_instance_auth_strings" {
  description = "AUTH string for Redis instances (sensitive)"
  value = {
    for k, v in google_redis_instance.redis : k => v.auth_string
  }
  sensitive = true
}

output "redis_instance_read_endpoint" {
  description = "The read endpoint for Redis instances"
  value = {
    for k, v in google_redis_instance.redis : k => v.read_endpoint
  }
}

output "redis_instance_read_endpoint_port" {
  description = "The read endpoint port for Redis instances"
  value = {
    for k, v in google_redis_instance.redis : k => v.read_endpoint_port
  }
}

# Memcached Instance Outputs
output "memcached_instance_ids" {
  description = "The identifiers for Memcached instances"
  value = {
    for k, v in google_memcache_instance.memcached : k => v.id
  }
}

output "memcached_instance_names" {
  description = "The names of Memcached instances"
  value = {
    for k, v in google_memcache_instance.memcached : k => v.name
  }
}

output "memcached_instance_discovery_endpoint" {
  description = "The discovery endpoints for Memcached instances"
  value = {
    for k, v in google_memcache_instance.memcached : k => v.discovery_endpoint
  }
}

output "memcached_instance_memcache_full_version" {
  description = "The full version of Memcached instances"
  value = {
    for k, v in google_memcache_instance.memcached : k => v.memcache_full_version
  }
}

output "memcached_instance_memcache_nodes" {
  description = "Additional information about the Memcached nodes"
  value = {
    for k, v in google_memcache_instance.memcached : k => v.memcache_nodes
  }
}

# Service Account Outputs
output "service_account_email" {
  description = "The email of the created service account"
  value       = var.create_service_account ? google_service_account.memorystore[0].email : null
}

output "service_account_id" {
  description = "The unique id of the service account"
  value       = var.create_service_account ? google_service_account.memorystore[0].unique_id : null
}

output "service_account_name" {
  description = "The fully-qualified name of the service account"
  value       = var.create_service_account ? google_service_account.memorystore[0].name : null
}

output "service_account_member" {
  description = "The IAM member format for the service account"
  value       = var.create_service_account ? "serviceAccount:${google_service_account.memorystore[0].email}" : null
}

# Network Outputs
output "private_ip_address" {
  description = "The private IP address range for VPC peering"
  value       = var.enable_private_service_access ? google_compute_global_address.private_ip_address[0].address : null
}

output "private_ip_address_name" {
  description = "The name of the private IP address range"
  value       = var.enable_private_service_access ? google_compute_global_address.private_ip_address[0].name : null
}

output "vpc_connection_service" {
  description = "The VPC peering service"
  value       = var.enable_private_service_access ? google_service_networking_connection.private_vpc_connection[0].service : null
}

output "vpc_connection_network" {
  description = "The VPC network used for peering"
  value       = var.enable_private_service_access ? google_service_networking_connection.private_vpc_connection[0].network : null
}

# Firewall Outputs
output "firewall_rule_id" {
  description = "The identifier for the firewall rule"
  value       = var.create_firewall_rules ? google_compute_firewall.memorystore_access[0].id : null
}

output "firewall_rule_name" {
  description = "The name of the firewall rule"
  value       = var.create_firewall_rules ? google_compute_firewall.memorystore_access[0].name : null
}

output "firewall_rule_self_link" {
  description = "The self link of the firewall rule"
  value       = var.create_firewall_rules ? google_compute_firewall.memorystore_access[0].self_link : null
}

# Backup Storage Outputs
output "backup_bucket_names" {
  description = "Names of backup storage buckets"
  value = {
    for k, v in google_storage_bucket.redis_backups : k => v.name
  }
}

output "backup_bucket_urls" {
  description = "URLs of backup storage buckets"
  value = {
    for k, v in google_storage_bucket.redis_backups : k => v.url
  }
}

output "backup_bucket_self_links" {
  description = "Self links of backup storage buckets"
  value = {
    for k, v in google_storage_bucket.redis_backups : k => v.self_link
  }
}

# Backup Function Outputs
output "backup_function_ids" {
  description = "IDs of backup functions"
  value = {
    for k, v in google_cloudfunctions_function.redis_backup : k => v.id
  }
}

output "backup_function_names" {
  description = "Names of backup functions"
  value = {
    for k, v in google_cloudfunctions_function.redis_backup : k => v.name
  }
}

output "backup_function_sources" {
  description = "Source locations of backup functions"
  value = {
    for k, v in google_cloudfunctions_function.redis_backup : k => {
      bucket = v.source_archive_bucket
      object = v.source_archive_object
    }
  }
}

# Monitoring Outputs
output "monitoring_alert_policy_ids" {
  description = "IDs of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.memorystore_alerts : k => v.id
  }
}

output "monitoring_alert_policy_names" {
  description = "Names of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.memorystore_alerts : k => v.name
  }
}

output "monitoring_dashboard_id" {
  description = "ID of the monitoring dashboard"
  value       = var.create_monitoring_dashboard ? google_monitoring_dashboard.memorystore[0].id : null
}

# Log Metrics Outputs
output "log_metric_names" {
  description = "Names of created log-based metrics"
  value = {
    for k, v in google_logging_metric.memorystore_metrics : k => v.name
  }
}

output "log_metric_ids" {
  description = "IDs of created log-based metrics"
  value = {
    for k, v in google_logging_metric.memorystore_metrics : k => v.id
  }
}

# IAM Outputs
output "iam_members" {
  description = "IAM members assigned to Redis instances"
  value = {
    for k, v in google_redis_instance_iam_member.redis_iam : k => {
      instance = v.instance
      role     = v.role
      member   = v.member
    }
  }
}

# Connection Information
output "redis_connection_info" {
  description = "Connection information for Redis instances"
  value = {
    for k, v in google_redis_instance.redis : k => {
      host                = v.host
      port                = v.port
      auth_enabled        = v.auth_enabled
      transit_encryption  = v.transit_encryption_mode
      connection_string   = "redis://${v.host}:${v.port}"
      ssl_connection_string = v.transit_encryption_mode == "SERVER_AUTHENTICATION" ? "rediss://${v.host}:${v.port}" : null
    }
  }
}

output "memcached_connection_info" {
  description = "Connection information for Memcached instances"
  value = {
    for k, v in google_memcache_instance.memcached : k => {
      discovery_endpoint = v.discovery_endpoint
      nodes             = v.memcache_nodes
    }
  }
}

# Configuration Summary
output "redis_configurations" {
  description = "Summary of Redis instance configurations"
  value = {
    for k, v in local.redis_instances : k => {
      tier                    = v.tier
      memory_size_gb         = v.memory_size_gb
      redis_version          = v.redis_version
      auth_enabled           = v.auth_enabled
      transit_encryption_mode = v.transit_encryption_mode
      connect_mode           = v.connect_mode
      persistence_enabled    = v.persistence_config != null
    }
  }
}

output "memcached_configurations" {
  description = "Summary of Memcached instance configurations"
  value = {
    for k, v in local.memcached_instances : k => {
      node_count       = v.node_count
      memcache_version = v.memcache_version
      total_memory_mb  = sum([for node in v.node_config : node.memory_size_mb])
      total_cpu_count  = sum([for node in v.node_config : node.cpu_count])
    }
  }
}

# Security Summary
output "security_summary" {
  description = "Summary of security configurations"
  value = {
    redis_auth_enabled = {
      for k, v in local.redis_instances : k => v.auth_enabled
    }
    redis_transit_encryption = {
      for k, v in local.redis_instances : k => v.transit_encryption_mode
    }
    private_service_access_enabled = var.enable_private_service_access
    firewall_rules_created        = var.create_firewall_rules
    service_account_created       = var.create_service_account
  }
}

# Performance Summary
output "performance_summary" {
  description = "Summary of performance configurations"
  value = {
    total_redis_memory_gb = sum([
      for instance in local.redis_instances : instance.memory_size_gb
    ])
    total_memcached_memory_mb = sum([
      for instance in local.memcached_instances : sum([
        for node in instance.node_config : node.memory_size_mb
      ])
    ])
    redis_instances_count    = length(local.redis_instances)
    memcached_instances_count = length(local.memcached_instances)
    high_availability_instances = length([
      for k, v in local.redis_instances : k if v.tier == "STANDARD_HA"
    ])
  }
}

# High Availability Summary
output "high_availability_summary" {
  description = "Summary of high availability configurations"
  value = {
    redis_ha_instances = {
      for k, v in local.redis_instances : k => {
        tier                    = v.tier
        alternative_location_id = var.alternative_location_id
        maintenance_policy      = v.maintenance_policy != null
      } if v.tier == "STANDARD_HA"
    }
    cross_region_replicas_enabled = var.high_availability_config.enable_cross_region_replicas
    failover_mode                 = var.high_availability_config.failover_mode
  }
}

# Backup Summary
output "backup_summary" {
  description = "Summary of backup configurations"
  value = {
    redis_backups_enabled     = var.enable_redis_backups
    automated_backups_enabled = var.enable_automated_backups
    backup_buckets_count      = var.enable_redis_backups ? length(var.redis_backup_configs) : 0
    backup_functions_count    = var.enable_automated_backups ? length(var.backup_functions) : 0
    persistence_configs = {
      for k, v in local.redis_instances : k => v.persistence_config
      if v.persistence_config != null
    }
  }
}

# Module Metadata
output "module_configuration" {
  description = "Module configuration summary"
  value = {
    project_id                    = var.project_id
    region                       = var.region
    environment                  = local.environment
    name_prefix                  = local.name_prefix
    network_name                 = var.network_name
    subnetwork_name              = var.subnetwork_name
    private_service_access_enabled = var.enable_private_service_access
    monitoring_enabled           = var.create_monitoring_alerts
    dashboard_created            = var.create_monitoring_dashboard
    log_metrics_enabled          = var.create_log_metrics
  }
}

# Labels
output "applied_labels" {
  description = "Labels applied to resources"
  value       = local.default_labels
}

# Resource Counts
output "resource_counts" {
  description = "Count of each resource type created"
  value = {
    redis_instances       = length(var.redis_instances)
    memcached_instances   = length(var.memcached_instances)
    service_accounts      = var.create_service_account ? 1 : 0
    firewall_rules        = var.create_firewall_rules ? 1 : 0
    backup_buckets        = var.enable_redis_backups ? length(var.redis_backup_configs) : 0
    backup_functions      = var.enable_automated_backups ? length(var.backup_functions) : 0
    alert_policies        = var.create_monitoring_alerts ? length(var.monitoring_alerts) : 0
    dashboards           = var.create_monitoring_dashboard ? 1 : 0
    log_metrics          = var.create_log_metrics ? length(var.log_metrics) : 0
    iam_bindings         = length(var.redis_iam_bindings)
    private_ip_addresses = var.enable_private_service_access ? 1 : 0
    vpc_connections      = var.enable_private_service_access ? 1 : 0
  }
}

# Cost Information
output "cost_summary" {
  description = "Summary of cost-related information"
  value = {
    redis_instances_by_tier = {
      for tier in distinct([for instance in local.redis_instances : instance.tier]) :
      tier => length([for k, v in local.redis_instances : k if v.tier == tier])
    }
    total_redis_memory_cost_factor = sum([
      for instance in local.redis_instances : instance.memory_size_gb * (instance.tier == "STANDARD_HA" ? 2 : 1)
    ])
    memcached_node_count = sum([
      for instance in local.memcached_instances : instance.node_count
    ])
    spot_instances_enabled = var.cost_optimization_config.enable_spot_instances
  }
}