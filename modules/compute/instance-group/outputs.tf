# Managed Instance Group Module Outputs

# MIG Identifiers
output "mig_id" {
  description = "The identifier of the managed instance group"
  value       = var.regional ? google_compute_region_instance_group_manager.mig[0].id : google_compute_instance_group_manager.mig[0].id
}

output "mig_name" {
  description = "The name of the managed instance group"
  value       = var.regional ? google_compute_region_instance_group_manager.mig[0].name : google_compute_instance_group_manager.mig[0].name
}

output "mig_self_link" {
  description = "The self link of the managed instance group"
  value       = var.regional ? google_compute_region_instance_group_manager.mig[0].self_link : google_compute_instance_group_manager.mig[0].self_link
}

output "mig_instance_group" {
  description = "The instance group URL of the managed instance group"
  value       = var.regional ? google_compute_region_instance_group_manager.mig[0].instance_group : google_compute_instance_group_manager.mig[0].instance_group
}

# Instance Template
output "instance_template_id" {
  description = "The ID of the instance template"
  value       = google_compute_instance_template.template.id
}

output "instance_template_self_link" {
  description = "The self link of the instance template"
  value       = google_compute_instance_template.template.self_link
}

output "instance_template_name" {
  description = "The name of the instance template"
  value       = google_compute_instance_template.template.name
}

output "instance_template_metadata_fingerprint" {
  description = "The unique fingerprint of the instance template metadata"
  value       = google_compute_instance_template.template.metadata_fingerprint
}

output "instance_template_tags_fingerprint" {
  description = "The unique fingerprint of the instance template tags"
  value       = google_compute_instance_template.template.tags_fingerprint
}

# MIG Details
output "base_instance_name" {
  description = "The base instance name for the managed instance group"
  value       = local.base_instance_name
}

output "target_size" {
  description = "The target number of instances for the managed instance group"
  value       = var.target_size
}

output "current_size" {
  description = "The current number of instances in the managed instance group"
  value       = var.regional ? google_compute_region_instance_group_manager.mig[0].target_size : google_compute_instance_group_manager.mig[0].target_size
}

output "fingerprint" {
  description = "The fingerprint of the managed instance group"
  value       = var.regional ? google_compute_region_instance_group_manager.mig[0].fingerprint : google_compute_instance_group_manager.mig[0].fingerprint
}

# Status
output "status" {
  description = "The status of the managed instance group"
  value       = var.regional ? google_compute_region_instance_group_manager.mig[0].status : google_compute_instance_group_manager.mig[0].status
}

output "creation_timestamp" {
  description = "Creation timestamp of the managed instance group"
  value       = var.regional ? google_compute_region_instance_group_manager.mig[0].creation_timestamp : google_compute_instance_group_manager.mig[0].creation_timestamp
}

# Health Check
output "health_check_id" {
  description = "The ID of the health check"
  value       = var.create_health_check ? google_compute_health_check.health_check[0].id : var.health_check_id
}

output "health_check_self_link" {
  description = "The self link of the health check"
  value       = var.create_health_check ? google_compute_health_check.health_check[0].self_link : null
}

# Autoscaler
output "autoscaler_id" {
  description = "The ID of the autoscaler"
  value = var.autoscaling_enabled ? (
    var.regional ? google_compute_region_autoscaler.autoscaler[0].id : google_compute_autoscaler.autoscaler[0].id
  ) : null
}

output "autoscaler_self_link" {
  description = "The self link of the autoscaler"
  value = var.autoscaling_enabled ? (
    var.regional ? google_compute_region_autoscaler.autoscaler[0].self_link : google_compute_autoscaler.autoscaler[0].self_link
  ) : null
}

output "autoscaler_name" {
  description = "The name of the autoscaler"
  value = var.autoscaling_enabled ? (
    var.regional ? google_compute_region_autoscaler.autoscaler[0].name : google_compute_autoscaler.autoscaler[0].name
  ) : null
}

# Service Account
output "service_account_email" {
  description = "The email of the service account used by instances"
  value       = local.service_account_email
}

output "created_service_account" {
  description = "The service account created for the MIG (if applicable)"
  value       = var.create_service_account ? google_service_account.mig[0].email : null
}

# Location Information
output "region" {
  description = "The region where the MIG is deployed"
  value       = var.region
}

output "zone" {
  description = "The zone where the MIG is deployed (for zonal MIGs)"
  value       = var.regional ? null : var.zone
}

output "distribution_zones" {
  description = "The zones where instances are distributed (for regional MIGs)"
  value       = var.regional ? local.distribution_zones : null
}

# Instance Management URLs
output "list_managed_instances_url" {
  description = "URL for listing managed instances"
  value = var.regional ? (
    "https://console.cloud.google.com/compute/instanceGroups/details/${var.region}/${var.name}?project=${var.project_id}"
  ) : (
    "https://console.cloud.google.com/compute/instanceGroups/details/${var.zone}/${var.name}?project=${var.project_id}"
  )
}

# Named Ports
output "named_ports" {
  description = "The named ports configured for the instance group"
  value       = var.named_ports
}

# Update Policy
output "update_policy" {
  description = "The update policy of the managed instance group"
  value       = var.update_policy
}

# Versions
output "versions" {
  description = "The versions configured for the managed instance group"
  value = var.regional ? (
    google_compute_region_instance_group_manager.mig[0].version
  ) : (
    google_compute_instance_group_manager.mig[0].version
  )
}

# Stateful Configuration
output "stateful_disks" {
  description = "The stateful disks configured for the managed instance group"
  value       = var.stateful_disks
}

output "stateful_internal_ips" {
  description = "The stateful internal IPs configured for the managed instance group"
  value       = var.stateful_internal_ips
}

output "stateful_external_ips" {
  description = "The stateful external IPs configured for the managed instance group"
  value       = var.stateful_external_ips
}

# Instance Lifecycle Policy
output "instance_lifecycle_policy" {
  description = "The instance lifecycle policy of the managed instance group"
  value       = var.instance_lifecycle_policy
}

# Autoscaling Configuration
output "autoscaling_configuration" {
  description = "The autoscaling configuration"
  value = var.autoscaling_enabled ? {
    enabled              = var.autoscaling_enabled
    min_replicas        = var.min_replicas
    max_replicas        = var.max_replicas
    cooldown_period     = var.autoscaling_cooldown_period
    cpu_target          = var.autoscaling_cpu != null ? var.autoscaling_cpu.target : null
    custom_metrics      = var.autoscaling_metrics
    load_balancing_target = var.autoscaling_load_balancing_utilization != null ? var.autoscaling_load_balancing_utilization.target : null
    mode               = var.autoscaling_mode
  } : null
}

# Instance Template Configuration
output "instance_template_configuration" {
  description = "Configuration details of the instance template"
  value = {
    machine_type    = var.machine_type
    source_image    = var.source_image
    boot_disk_size  = var.boot_disk_size_gb
    boot_disk_type  = var.boot_disk_type
    network_tags    = var.tags
    labels         = var.labels
    service_account = local.service_account_email
    metadata       = var.metadata
  }
}

# Useful for Load Balancer Backend Services
output "instance_group_urls" {
  description = "List of instance group URLs for backend service configuration"
  value = var.regional ? (
    [google_compute_region_instance_group_manager.mig[0].instance_group]
  ) : (
    [google_compute_instance_group_manager.mig[0].instance_group]
  )
}

# Health Status URL
output "health_status_url" {
  description = "URL to check the health status of instances"
  value = var.create_health_check ? (
    "https://console.cloud.google.com/compute/healthChecks/details/${google_compute_health_check.health_check[0].name}?project=${var.project_id}"
  ) : null
}

# Instance URLs (useful for debugging)
output "instance_urls" {
  description = "Console URLs for viewing instances in this MIG"
  value = {
    instances_list = var.regional ? (
      "https://console.cloud.google.com/compute/instanceGroups/details/${var.region}/${var.name}?project=${var.project_id}&tab=instances"
    ) : (
      "https://console.cloud.google.com/compute/instanceGroups/details/${var.zone}/${var.name}?project=${var.project_id}&tab=instances"
    )

    monitoring = var.regional ? (
      "https://console.cloud.google.com/compute/instanceGroups/details/${var.region}/${var.name}?project=${var.project_id}&tab=monitoring"
    ) : (
      "https://console.cloud.google.com/compute/instanceGroups/details/${var.zone}/${var.name}?project=${var.project_id}&tab=monitoring"
    )
  }
}