# Cloud Spanner Module Outputs

# Instance Outputs
output "instance_id" {
  description = "The identifier for the Spanner instance"
  value       = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].id : google_spanner_instance.instance[0].id
}

output "instance_name" {
  description = "The name of the Spanner instance"
  value       = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].name : google_spanner_instance.instance[0].name
}

output "instance_display_name" {
  description = "The display name of the Spanner instance"
  value       = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].display_name : google_spanner_instance.instance[0].display_name
}

output "instance_config" {
  description = "The configuration of the Spanner instance"
  value       = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].config : google_spanner_instance.instance[0].config
}

output "instance_num_nodes" {
  description = "The number of nodes in the Spanner instance"
  value       = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].num_nodes : google_spanner_instance.instance[0].num_nodes
}

output "instance_processing_units" {
  description = "The number of processing units in the Spanner instance"
  value       = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].processing_units : google_spanner_instance.instance[0].processing_units
}

output "instance_state" {
  description = "The current state of the Spanner instance"
  value       = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].state : google_spanner_instance.instance[0].state
}

output "instance_labels" {
  description = "The labels of the Spanner instance"
  value       = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].labels : google_spanner_instance.instance[0].labels
}

# Database Outputs
output "database_ids" {
  description = "The identifiers for Spanner databases"
  value = {
    for k, v in google_spanner_database.databases : k => v.id
  }
}

output "database_names" {
  description = "The names of Spanner databases"
  value = {
    for k, v in google_spanner_database.databases : k => v.name
  }
}

output "database_states" {
  description = "The states of Spanner databases"
  value = {
    for k, v in google_spanner_database.databases : k => v.state
  }
}

output "database_version_retention_periods" {
  description = "The version retention periods of Spanner databases"
  value = {
    for k, v in google_spanner_database.databases : k => v.version_retention_period
  }
}

output "database_dialects" {
  description = "The dialects of Spanner databases"
  value = {
    for k, v in google_spanner_database.databases : k => v.database_dialect
  }
}

output "database_earliest_version_times" {
  description = "The earliest version times of Spanner databases"
  value = {
    for k, v in google_spanner_database.databases : k => v.earliest_version_time
  }
}

output "database_encryption_configs" {
  description = "The encryption configurations of Spanner databases"
  value = {
    for k, v in google_spanner_database.databases : k => v.encryption_config
  }
}

# Backup Outputs
output "backup_ids" {
  description = "The identifiers for Spanner backups"
  value = {
    for k, v in google_spanner_backup.backups : k => v.id
  }
}

output "backup_names" {
  description = "The names of Spanner backups"
  value = {
    for k, v in google_spanner_backup.backups : k => v.name
  }
}

output "backup_states" {
  description = "The states of Spanner backups"
  value = {
    for k, v in google_spanner_backup.backups : k => v.state
  }
}

output "backup_create_times" {
  description = "The creation times of Spanner backups"
  value = {
    for k, v in google_spanner_backup.backups : k => v.create_time
  }
}

output "backup_size_bytes" {
  description = "The sizes in bytes of Spanner backups"
  value = {
    for k, v in google_spanner_backup.backups : k => v.size_bytes
  }
}

output "backup_referencing_databases" {
  description = "The databases referencing each backup"
  value = {
    for k, v in google_spanner_backup.backups : k => v.referencing_databases
  }
}

# Backup Schedule Outputs
output "backup_schedule_ids" {
  description = "The identifiers for backup schedules"
  value = {
    for k, v in google_spanner_backup_schedule.backup_schedules : k => v.id
  }
}

output "backup_schedule_names" {
  description = "The names of backup schedules"
  value = {
    for k, v in google_spanner_backup_schedule.backup_schedules : k => v.name
  }
}

# Service Account Outputs
output "service_account_email" {
  description = "The email of the created service account"
  value       = var.create_service_account ? google_service_account.spanner[0].email : null
}

output "service_account_id" {
  description = "The unique id of the service account"
  value       = var.create_service_account ? google_service_account.spanner[0].unique_id : null
}

output "service_account_name" {
  description = "The fully-qualified name of the service account"
  value       = var.create_service_account ? google_service_account.spanner[0].name : null
}

output "service_account_member" {
  description = "The IAM member format for the service account"
  value       = var.create_service_account ? "serviceAccount:${google_service_account.spanner[0].email}" : null
}

# IAM Outputs
output "instance_iam_bindings" {
  description = "IAM bindings for the Spanner instance"
  value = {
    for k, v in google_spanner_instance_iam_binding.instance_iam : k => {
      role    = v.role
      members = v.members
    }
  }
}

output "database_iam_bindings" {
  description = "IAM bindings for Spanner databases"
  value = {
    for k, v in google_spanner_database_iam_binding.database_iam : k => {
      database = v.database
      role     = v.role
      members  = v.members
    }
  }
}

# Monitoring Outputs
output "monitoring_alert_policy_ids" {
  description = "IDs of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.spanner_alerts : k => v.id
  }
}

output "monitoring_alert_policy_names" {
  description = "Names of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.spanner_alerts : k => v.name
  }
}

output "monitoring_dashboard_id" {
  description = "ID of the monitoring dashboard"
  value       = var.create_monitoring_dashboard ? google_monitoring_dashboard.spanner[0].id : null
}

# Log Metrics Outputs
output "log_metric_names" {
  description = "Names of created log-based metrics"
  value = {
    for k, v in google_logging_metric.spanner_metrics : k => v.name
  }
}

output "log_metric_ids" {
  description = "IDs of created log-based metrics"
  value = {
    for k, v in google_logging_metric.spanner_metrics : k => v.id
  }
}

# Operation Functions Outputs
output "operation_function_ids" {
  description = "IDs of created operation functions"
  value = {
    for k, v in google_cloudfunctions_function.spanner_operations : k => v.id
  }
}

output "operation_function_names" {
  description = "Names of created operation functions"
  value = {
    for k, v in google_cloudfunctions_function.spanner_operations : k => v.name
  }
}

output "operation_function_trigger_urls" {
  description = "Trigger URLs for HTTP operation functions"
  value = {
    for k, v in google_cloudfunctions_function.spanner_operations : k => v.https_trigger_url
    if v.https_trigger_url != null
  }
}

# BigQuery Export Outputs
output "bigquery_dataset_id" {
  description = "ID of the BigQuery export dataset"
  value       = var.enable_bigquery_export ? google_bigquery_dataset.spanner_export[0].dataset_id : null
}

output "bigquery_dataset_location" {
  description = "Location of the BigQuery export dataset"
  value       = var.enable_bigquery_export ? google_bigquery_dataset.spanner_export[0].location : null
}

output "bigquery_dataset_self_link" {
  description = "Self link of the BigQuery export dataset"
  value       = var.enable_bigquery_export ? google_bigquery_dataset.spanner_export[0].self_link : null
}

# Dataflow Job Outputs
output "dataflow_job_id" {
  description = "ID of the Dataflow export job"
  value       = var.enable_dataflow_export ? google_dataflow_job.spanner_to_bigquery[0].job_id : null
}

output "dataflow_job_name" {
  description = "Name of the Dataflow export job"
  value       = var.enable_dataflow_export ? google_dataflow_job.spanner_to_bigquery[0].name : null
}

output "dataflow_job_state" {
  description = "State of the Dataflow export job"
  value       = var.enable_dataflow_export ? google_dataflow_job.spanner_to_bigquery[0].state : null
}

# Change Streams Outputs
output "change_stream_topic_names" {
  description = "Names of change stream Pub/Sub topics"
  value = {
    for k, v in google_pubsub_topic.spanner_change_streams : k => v.name
  }
}

output "change_stream_topic_ids" {
  description = "IDs of change stream Pub/Sub topics"
  value = {
    for k, v in google_pubsub_topic.spanner_change_streams : k => v.id
  }
}

# Maintenance Jobs Outputs
output "maintenance_job_ids" {
  description = "IDs of maintenance Cloud Scheduler jobs"
  value = {
    for k, v in google_cloud_scheduler_job.spanner_maintenance : k => v.id
  }
}

output "maintenance_job_names" {
  description = "Names of maintenance Cloud Scheduler jobs"
  value = {
    for k, v in google_cloud_scheduler_job.spanner_maintenance : k => v.name
  }
}

# Connection Information
output "connection_info" {
  description = "Connection information for Spanner"
  value = {
    project_id  = var.project_id
    instance_id = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].name : google_spanner_instance.instance[0].name
    databases = {
      for k, v in google_spanner_database.databases : k => {
        database_id = v.name
        dialect     = v.database_dialect
        state       = v.state
      }
    }
    endpoint = "spanner.googleapis.com"
  }
  sensitive = false
}

# Configuration Summary
output "instance_configuration" {
  description = "Summary of instance configuration"
  value = {
    name              = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].name : google_spanner_instance.instance[0].name
    config            = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].config : google_spanner_instance.instance[0].config
    display_name      = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].display_name : google_spanner_instance.instance[0].display_name
    num_nodes         = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].num_nodes : google_spanner_instance.instance[0].num_nodes
    processing_units  = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].processing_units : google_spanner_instance.instance[0].processing_units
    edition           = var.use_existing_instance ? null : google_spanner_instance.instance[0].edition
    force_destroy     = var.use_existing_instance ? null : google_spanner_instance.instance[0].force_destroy
    existing_instance = var.use_existing_instance
  }
}

output "database_configurations" {
  description = "Summary of database configurations"
  value = {
    for k, v in local.database_configs : k => {
      name                     = v.name
      version_retention_period = v.version_retention_period
      deletion_protection      = v.deletion_protection
      enable_drop_protection   = v.enable_drop_protection
      database_dialect         = v.database_dialect
      ddl_statements_count     = length(v.ddl)
      encryption_enabled       = v.encryption_config.kms_key_name != null
    }
  }
}

output "backup_configuration" {
  description = "Summary of backup configuration"
  value = {
    manual_backups_count    = length(var.backup_configs)
    scheduled_backups_count = length(var.backup_schedules)
    retention_policies = {
      for k, v in local.backup_configs : k => {
        retention_period = v.retention_period
        expire_time      = v.expire_time
        encryption_type  = v.encryption_config.encryption_type
      }
    }
    automated_schedules = {
      for k, v in var.backup_schedules : k => {
        backup_type        = v.backup_type
        retention_duration = v.retention_duration
        cron_schedule      = v.cron_spec != null ? v.cron_spec.text : null
      }
    }
  }
}

output "security_configuration" {
  description = "Summary of security configuration"
  value = {
    service_account_created     = var.create_service_account
    instance_iam_policies_count = length(var.instance_iam_policies)
    database_iam_policies_count = length(var.database_iam_policies)
    encryption_enabled          = var.security_config.enable_cmek
    audit_logs_enabled          = var.security_config.enable_audit_logs
    ssl_required                = var.security_config.require_ssl
    vpc_sc_enabled              = var.security_config.enable_vpc_sc
  }
}

output "performance_configuration" {
  description = "Summary of performance configuration"
  value = {
    total_processing_units = var.use_existing_instance ? (
      data.google_spanner_instance.existing_instance[0].processing_units != null ?
      data.google_spanner_instance.existing_instance[0].processing_units :
      data.google_spanner_instance.existing_instance[0].num_nodes * 1000
      ) : (
      google_spanner_instance.instance[0].processing_units != null ?
      google_spanner_instance.instance[0].processing_units :
      google_spanner_instance.instance[0].num_nodes * 1000
    )
    autoscaling_enabled      = var.scaling_config.enable_autoscaling
    query_optimizer_version  = var.performance_config.query_optimizer_version
    batch_write_optimization = var.performance_config.enable_batch_write_optimization
  }
}

output "cost_summary" {
  description = "Summary of cost-related configuration"
  value = {
    instance_edition          = var.use_existing_instance ? null : google_spanner_instance.instance[0].edition
    total_nodes               = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].num_nodes : google_spanner_instance.instance[0].num_nodes
    processing_units          = var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].processing_units : google_spanner_instance.instance[0].processing_units
    regional_instance         = length(regexall("regional", var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].config : google_spanner_instance.instance[0].config)) > 0
    multi_region_instance     = length(regexall("multi-region", var.use_existing_instance ? data.google_spanner_instance.existing_instance[0].config : google_spanner_instance.instance[0].config)) > 0
    cost_optimization_enabled = var.cost_optimization_config.optimize_for_cost
  }
}

output "disaster_recovery_summary" {
  description = "Summary of disaster recovery configuration"
  value = {
    point_in_time_recovery  = var.disaster_recovery_config.enable_point_in_time_recovery
    backup_retention_days   = var.disaster_recovery_config.backup_retention_days
    cross_region_backup     = var.disaster_recovery_config.cross_region_backup_enabled
    rto_hours               = var.disaster_recovery_config.recovery_time_objective
    rpo_hours               = var.disaster_recovery_config.recovery_point_objective
    automated_backup_policy = var.disaster_recovery_config.automated_backup_policy
  }
}

output "integration_status" {
  description = "Status of various integrations"
  value = {
    bigquery_export_enabled     = var.enable_bigquery_export
    dataflow_export_enabled     = var.enable_dataflow_export
    change_streams_enabled      = var.enable_change_streams
    maintenance_jobs_enabled    = var.enable_maintenance_jobs
    operation_functions_enabled = var.create_operation_functions
    monitoring_enabled          = var.create_monitoring_alerts
    dashboard_created           = var.create_monitoring_dashboard
  }
}

# Module Metadata
output "module_configuration" {
  description = "Module configuration summary"
  value = {
    project_id            = var.project_id
    region                = var.region
    environment           = local.environment
    name_prefix           = local.name_prefix
    use_existing_instance = var.use_existing_instance
    multi_region_enabled  = var.multi_region_config.enable_multi_region
    scaling_enabled       = var.scaling_config.enable_autoscaling
    migration_enabled     = var.migration_config.enable_database_migration
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
    spanner_instances     = var.use_existing_instance ? 0 : 1
    spanner_databases     = length(var.databases)
    manual_backups        = length(var.backup_configs)
    backup_schedules      = length(var.backup_schedules)
    service_accounts      = var.create_service_account ? 1 : 0
    operation_functions   = var.create_operation_functions ? length(var.operation_functions) : 0
    alert_policies        = var.create_monitoring_alerts ? length(var.monitoring_alerts) : 0
    dashboards            = var.create_monitoring_dashboard ? 1 : 0
    log_metrics           = var.create_log_metrics ? length(var.log_metrics) : 0
    bigquery_datasets     = var.enable_bigquery_export ? 1 : 0
    dataflow_jobs         = var.enable_dataflow_export ? 1 : 0
    change_stream_topics  = var.enable_change_streams ? length(var.change_stream_topics) : 0
    maintenance_jobs      = var.enable_maintenance_jobs ? length(var.maintenance_jobs) : 0
    instance_iam_bindings = length(var.instance_iam_policies)
    database_iam_bindings = length(var.database_iam_policies)
  }
}