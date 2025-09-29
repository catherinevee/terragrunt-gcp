# Cloud Composer Module Outputs

# Environment Outputs
output "environment_id" {
  description = "The identifier for the Composer environment"
  value       = google_composer_environment.composer.id
}

output "environment_name" {
  description = "The name of the Composer environment"
  value       = google_composer_environment.composer.name
}

output "environment_state" {
  description = "The current state of the Composer environment"
  value       = google_composer_environment.composer.state
}

output "environment_uuid" {
  description = "The UUID of the Composer environment"
  value       = google_composer_environment.composer.uuid
}

# Configuration Outputs
output "airflow_uri" {
  description = "The URI of the Apache Airflow Web UI"
  value       = google_composer_environment.composer.config[0].airflow_uri
}

output "dag_gcs_prefix" {
  description = "The Cloud Storage prefix of the DAGs for this environment"
  value       = google_composer_environment.composer.config[0].dag_gcs_prefix
}

output "gke_cluster" {
  description = "The Kubernetes cluster used to run this environment"
  value       = google_composer_environment.composer.config[0].gke_cluster
}

output "node_config" {
  description = "The configuration used for the Kubernetes Engine cluster"
  value       = google_composer_environment.composer.config[0].node_config
}

output "software_config" {
  description = "The configuration settings for software inside the environment"
  value       = google_composer_environment.composer.config[0].software_config
}

output "private_environment_config" {
  description = "The configuration used for the Private IP Cloud Composer environment"
  value       = length(google_composer_environment.composer.config[0].private_environment_config) > 0 ? google_composer_environment.composer.config[0].private_environment_config[0] : null
}

output "database_config" {
  description = "The configuration settings for Cloud SQL instance used internally"
  value       = length(google_composer_environment.composer.config[0].database_config) > 0 ? google_composer_environment.composer.config[0].database_config[0] : null
}

output "web_server_config" {
  description = "The configuration settings for the Airflow web server"
  value       = length(google_composer_environment.composer.config[0].web_server_config) > 0 ? google_composer_environment.composer.config[0].web_server_config[0] : null
}

output "encryption_config" {
  description = "The encryption options for the Cloud Composer environment"
  value       = length(google_composer_environment.composer.config[0].encryption_config) > 0 ? google_composer_environment.composer.config[0].encryption_config[0] : null
}

output "workloads_config" {
  description = "The workloads configuration settings for the GKE cluster"
  value       = length(google_composer_environment.composer.config[0].workloads_config) > 0 ? google_composer_environment.composer.config[0].workloads_config[0] : null
}

output "maintenance_window" {
  description = "The maintenance window configuration"
  value       = length(google_composer_environment.composer.config[0].maintenance_window) > 0 ? google_composer_environment.composer.config[0].maintenance_window[0] : null
}

# Network Outputs
output "network" {
  description = "The Compute Engine network to be used for machine communications"
  value       = google_composer_environment.composer.config[0].node_config[0].network
}

output "subnetwork" {
  description = "The Compute Engine subnetwork to be used for machine communications"
  value       = google_composer_environment.composer.config[0].node_config[0].subnetwork
}

# Service Account Outputs
output "service_account_email" {
  description = "The email of the created service account"
  value       = var.create_service_account ? google_service_account.composer[0].email : null
}

output "service_account_id" {
  description = "The unique id of the service account"
  value       = var.create_service_account ? google_service_account.composer[0].unique_id : null
}

output "service_account_name" {
  description = "The fully-qualified name of the service account"
  value       = var.create_service_account ? google_service_account.composer[0].name : null
}

output "service_account_member" {
  description = "The IAM member format for the service account"
  value       = var.create_service_account ? "serviceAccount:${google_service_account.composer[0].email}" : null
}

output "node_service_account" {
  description = "The Google Cloud Platform Service Account used by the node VMs"
  value       = google_composer_environment.composer.config[0].node_config[0].service_account
}

# Storage Outputs
output "composer_bucket_name" {
  description = "Name of the Composer storage bucket"
  value       = var.create_composer_bucket ? google_storage_bucket.composer_bucket[0].name : null
}

output "composer_bucket_url" {
  description = "URL of the Composer storage bucket"
  value       = var.create_composer_bucket ? google_storage_bucket.composer_bucket[0].url : null
}

output "composer_bucket_self_link" {
  description = "Self link of the Composer storage bucket"
  value       = var.create_composer_bucket ? google_storage_bucket.composer_bucket[0].self_link : null
}

# Monitoring Outputs
output "monitoring_alert_policy_ids" {
  description = "IDs of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.composer_alerts : k => v.id
  }
}

output "monitoring_alert_policy_names" {
  description = "Names of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.composer_alerts : k => v.name
  }
}

output "monitoring_dashboard_id" {
  description = "ID of the monitoring dashboard"
  value       = var.create_monitoring_dashboard ? google_monitoring_dashboard.composer[0].id : null
}

# Log Metrics Outputs
output "log_metric_names" {
  description = "Names of created log-based metrics"
  value = {
    for k, v in google_logging_metric.composer_metrics : k => v.name
  }
}

output "log_metric_ids" {
  description = "IDs of created log-based metrics"
  value = {
    for k, v in google_logging_metric.composer_metrics : k => v.id
  }
}

# IAM Outputs
output "iam_members" {
  description = "IAM members assigned to the Composer environment"
  value = {
    for k, v in google_composer_environment_iam_member.environment_iam : k => {
      role   = v.role
      member = v.member
    }
  }
}

output "dags_bucket_iam_members" {
  description = "IAM members assigned to DAGs bucket"
  value = {
    for k, v in google_storage_bucket_iam_member.dags_bucket_iam : k => {
      bucket = v.bucket
      role   = v.role
      member = v.member
    }
  }
}

# Environment Details
output "environment_details" {
  description = "Detailed information about the Composer environment"
  value = {
    name                = google_composer_environment.composer.name
    state              = google_composer_environment.composer.state
    create_time        = google_composer_environment.composer.create_time
    update_time        = google_composer_environment.composer.update_time
    labels             = google_composer_environment.composer.labels
    project            = var.project_id
    region             = var.region
  }
}

# Cluster Information
output "gke_cluster_info" {
  description = "Information about the underlying GKE cluster"
  value = {
    cluster_name = google_composer_environment.composer.config[0].gke_cluster
    zone         = google_composer_environment.composer.config[0].node_config[0].zone
    machine_type = google_composer_environment.composer.config[0].node_config[0].machine_type
    disk_size_gb = google_composer_environment.composer.config[0].node_config[0].disk_size_gb
    disk_type    = google_composer_environment.composer.config[0].node_config[0].disk_type
  }
}

# Software Information
output "software_info" {
  description = "Information about software configuration"
  value = {
    image_version    = google_composer_environment.composer.config[0].software_config[0].image_version
    python_version   = google_composer_environment.composer.config[0].software_config[0].python_version
    scheduler_count  = try(google_composer_environment.composer.config[0].software_config[0].scheduler_count[0].count, null)
    airflow_config_overrides = google_composer_environment.composer.config[0].software_config[0].airflow_config_overrides
    pypi_packages    = google_composer_environment.composer.config[0].software_config[0].pypi_packages
    env_variables    = google_composer_environment.composer.config[0].software_config[0].env_variables
  }
}

# Security Information
output "security_info" {
  description = "Security-related configuration information"
  value = {
    private_environment = var.enable_private_environment
    encryption_enabled  = var.encryption_config != null
    kms_key_name       = var.encryption_config != null ? var.encryption_config.kms_key_name : null
    service_account    = google_composer_environment.composer.config[0].node_config[0].service_account
    oauth_scopes       = google_composer_environment.composer.config[0].node_config[0].oauth_scopes
    tags              = google_composer_environment.composer.config[0].node_config[0].tags
  }
}

# Network Information
output "network_info" {
  description = "Network configuration information"
  value = {
    network                = google_composer_environment.composer.config[0].node_config[0].network
    subnetwork            = google_composer_environment.composer.config[0].node_config[0].subnetwork
    enable_ip_alias       = google_composer_environment.composer.config[0].node_config[0].enable_ip_alias
    max_pods_per_node     = google_composer_environment.composer.config[0].node_config[0].max_pods_per_node
    private_cluster_config = var.enable_private_environment ? {
      enable_private_endpoint = var.private_cluster_config.enable_private_endpoint
      master_ipv4_cidr_block = var.private_cluster_config.master_ipv4_cidr_block
    } : null
  }
}

# Connection Information
output "connection_info" {
  description = "Connection information for the Composer environment"
  value = {
    airflow_uri        = google_composer_environment.composer.config[0].airflow_uri
    dag_gcs_prefix     = google_composer_environment.composer.config[0].dag_gcs_prefix
    gke_cluster        = google_composer_environment.composer.config[0].gke_cluster
    environment_name   = google_composer_environment.composer.name
    environment_uuid   = google_composer_environment.composer.uuid
  }
  sensitive = false
}

# Configuration Summary
output "configuration_summary" {
  description = "Summary of environment configuration"
  value = {
    environment_size        = var.environment_size
    composer_version       = local.software_config.image_version
    python_version         = local.software_config.python_version
    node_machine_type      = local.node_config.machine_type
    node_disk_size_gb      = local.node_config.disk_size_gb
    private_environment    = var.enable_private_environment
    high_availability      = var.high_availability_config.enable_multi_zone
    auto_scaling_enabled   = var.high_availability_config.enable_auto_scaling
    workloads_config_enabled = var.enable_workloads_config
    cloud_data_lineage_enabled = var.enable_cloud_data_lineage
  }
}

# Performance Summary
output "performance_summary" {
  description = "Summary of performance configuration"
  value = {
    scheduler_resources = var.enable_workloads_config ? {
      cpu     = local.software_config.scheduler.cpu
      memory  = local.software_config.scheduler.memory
      storage = local.software_config.scheduler.storage
      count   = local.software_config.scheduler.count
    } : null
    worker_resources = var.enable_workloads_config ? {
      cpu        = local.software_config.worker.cpu
      memory     = local.software_config.worker.memory
      storage    = local.software_config.worker.storage
      min_count  = local.software_config.worker.min_count
      max_count  = local.software_config.worker.max_count
    } : null
    web_server_resources = var.enable_workloads_config ? {
      cpu     = local.software_config.web_server.cpu
      memory  = local.software_config.web_server.memory
      storage = local.software_config.web_server.storage
    } : null
  }
}

# Cost Information
output "cost_summary" {
  description = "Summary of cost-related configuration"
  value = {
    environment_size          = var.environment_size
    node_machine_type        = local.node_config.machine_type
    preemptible_nodes_enabled = var.cost_optimization_config.enable_preemptible_nodes
    auto_pause_enabled       = var.cost_optimization_config.enable_auto_pause
    database_machine_type    = var.enable_database_config ? local.database_config.machine_type : null
    web_server_machine_type  = var.enable_web_server_config ? local.web_server_config.machine_type : null
  }
}

# Module Metadata
output "module_configuration" {
  description = "Module configuration summary"
  value = {
    project_id                = var.project_id
    region                   = var.region
    zone                     = var.zone
    environment              = local.environment
    name_prefix              = local.name_prefix
    service_account_created  = var.create_service_account
    bucket_created           = var.create_composer_bucket
    monitoring_enabled       = var.create_monitoring_alerts
    dashboard_created        = var.create_monitoring_dashboard
    log_metrics_enabled      = var.create_log_metrics
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
    composer_environments = 1
    service_accounts     = var.create_service_account ? 1 : 0
    storage_buckets      = var.create_composer_bucket ? 1 : 0
    alert_policies       = var.create_monitoring_alerts ? length(var.monitoring_alerts) : 0
    dashboards          = var.create_monitoring_dashboard ? 1 : 0
    log_metrics         = var.create_log_metrics ? length(var.log_metrics) : 0
    environment_iam_bindings = length(var.environment_iam_bindings)
    bucket_iam_bindings = length(var.dags_bucket_iam_bindings)
  }
}

# Deployment Status
output "deployment_status" {
  description = "Status of the deployment"
  value = {
    environment_state    = google_composer_environment.composer.state
    create_time         = google_composer_environment.composer.create_time
    update_time         = google_composer_environment.composer.update_time
    ready_for_use       = google_composer_environment.composer.state == "RUNNING"
  }
}