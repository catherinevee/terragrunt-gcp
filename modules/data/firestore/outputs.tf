# Firestore Module Outputs

# Database Outputs
output "database_id" {
  description = "The identifier for the Firestore database"
  value       = google_firestore_database.database.id
}

output "database_name" {
  description = "The name of the Firestore database"
  value       = google_firestore_database.database.name
}

output "database_location" {
  description = "The location of the Firestore database"
  value       = google_firestore_database.database.location_id
}

output "database_type" {
  description = "The type of the Firestore database"
  value       = google_firestore_database.database.type
}

output "database_uid" {
  description = "The unique identifier for the Firestore database"
  value       = google_firestore_database.database.uid
}

output "database_create_time" {
  description = "The creation time of the Firestore database"
  value       = google_firestore_database.database.create_time
}

output "database_earliest_version_time" {
  description = "The earliest version time of the Firestore database"
  value       = google_firestore_database.database.earliest_version_time
}

output "database_version_retention_period" {
  description = "The version retention period of the Firestore database"
  value       = google_firestore_database.database.version_retention_period
}

output "database_etag" {
  description = "The etag of the Firestore database"
  value       = google_firestore_database.database.etag
}

output "database_key_prefix" {
  description = "The key prefix for the Firestore database"
  value       = google_firestore_database.database.key_prefix
}

# Service Account Outputs
output "service_account_email" {
  description = "The email of the created service account"
  value       = var.create_service_account ? google_service_account.firestore[0].email : null
}

output "service_account_id" {
  description = "The unique id of the service account"
  value       = var.create_service_account ? google_service_account.firestore[0].unique_id : null
}

output "service_account_name" {
  description = "The fully-qualified name of the service account"
  value       = var.create_service_account ? google_service_account.firestore[0].name : null
}

output "service_account_member" {
  description = "The IAM member format for the service account"
  value       = var.create_service_account ? "serviceAccount:${google_service_account.firestore[0].email}" : null
}

# Security Rules Outputs
output "security_ruleset_name" {
  description = "The name of the deployed security ruleset"
  value       = var.deploy_security_rules ? google_firestore_ruleset.rules[0].name : null
}

output "security_ruleset_create_time" {
  description = "The creation time of the security ruleset"
  value       = var.deploy_security_rules ? google_firestore_ruleset.rules[0].create_time : null
}

output "security_rules_release_name" {
  description = "The name of the security rules release"
  value       = var.deploy_security_rules ? google_firestore_release.rules_release[0].name : null
}

output "security_rules_release_create_time" {
  description = "The creation time of the security rules release"
  value       = var.deploy_security_rules ? google_firestore_release.rules_release[0].create_time : null
}

# Indexes Outputs
output "index_ids" {
  description = "The identifiers for created Firestore indexes"
  value = {
    for k, v in google_firestore_index.indexes : k => v.id
  }
}

output "index_names" {
  description = "The names of created Firestore indexes"
  value = {
    for k, v in google_firestore_index.indexes : k => v.name
  }
}

output "index_collections" {
  description = "The collections for created Firestore indexes"
  value = {
    for k, v in google_firestore_index.indexes : k => v.collection
  }
}

output "index_fields" {
  description = "The fields for created Firestore indexes"
  value = {
    for k, v in google_firestore_index.indexes : k => v.fields
  }
}

# TTL Fields Outputs
output "ttl_field_names" {
  description = "Names of TTL fields created"
  value = {
    for k, v in google_firestore_field.ttl_fields : k => v.name
  }
}

output "ttl_field_collections" {
  description = "Collections with TTL fields"
  value = {
    for k, v in google_firestore_field.ttl_fields : k => v.collection
  }
}

output "ttl_field_states" {
  description = "States of TTL fields"
  value = {
    for k, v in google_firestore_field.ttl_fields : k => v.ttl_config[0].state
  }
}

# Backup Schedules Outputs
output "backup_schedule_ids" {
  description = "IDs of created backup schedules"
  value = {
    for k, v in google_firestore_backup_schedule.backup_schedules : k => v.id
  }
}

output "backup_schedule_names" {
  description = "Names of created backup schedules"
  value = {
    for k, v in google_firestore_backup_schedule.backup_schedules : k => v.name
  }
}

# Initial Documents Outputs
output "initial_document_ids" {
  description = "IDs of created initial documents"
  value = {
    for k, v in google_firestore_document.initial_documents : k => v.id
  }
}

output "initial_document_names" {
  description = "Names of created initial documents"
  value = {
    for k, v in google_firestore_document.initial_documents : k => v.name
  }
}

output "initial_document_paths" {
  description = "Paths of created initial documents"
  value = {
    for k, v in google_firestore_document.initial_documents : k => v.path
  }
}

# BigQuery Export Outputs
output "bigquery_dataset_id" {
  description = "ID of the BigQuery export dataset"
  value       = var.enable_bigquery_export ? google_bigquery_dataset.firestore_export[0].dataset_id : null
}

output "bigquery_dataset_location" {
  description = "Location of the BigQuery export dataset"
  value       = var.enable_bigquery_export ? google_bigquery_dataset.firestore_export[0].location : null
}

output "bigquery_dataset_self_link" {
  description = "Self link of the BigQuery export dataset"
  value       = var.enable_bigquery_export ? google_bigquery_dataset.firestore_export[0].self_link : null
}

# Data Processors Outputs
output "data_processor_ids" {
  description = "IDs of created data processor functions"
  value = {
    for k, v in google_cloudfunctions_function.data_processor : k => v.id
  }
}

output "data_processor_names" {
  description = "Names of created data processor functions"
  value = {
    for k, v in google_cloudfunctions_function.data_processor : k => v.name
  }
}

output "data_processor_sources" {
  description = "Source locations of data processor functions"
  value = {
    for k, v in google_cloudfunctions_function.data_processor : k => {
      bucket = v.source_archive_bucket
      object = v.source_archive_object
    }
  }
}

# Monitoring Outputs
output "monitoring_alert_policy_ids" {
  description = "IDs of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.firestore_alerts : k => v.id
  }
}

output "monitoring_alert_policy_names" {
  description = "Names of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.firestore_alerts : k => v.name
  }
}

output "monitoring_dashboard_id" {
  description = "ID of the monitoring dashboard"
  value       = var.create_monitoring_dashboard ? google_monitoring_dashboard.firestore[0].id : null
}

# Log Metrics Outputs
output "log_metric_names" {
  description = "Names of created log-based metrics"
  value = {
    for k, v in google_logging_metric.firestore_metrics : k => v.name
  }
}

output "log_metric_ids" {
  description = "IDs of created log-based metrics"
  value = {
    for k, v in google_logging_metric.firestore_metrics : k => v.id
  }
}

# IAM Outputs
output "iam_members" {
  description = "IAM members assigned to the Firestore database"
  value = {
    for k, v in google_firestore_database_iam_member.database_iam : k => {
      role   = v.role
      member = v.member
    }
  }
}

# Configuration Summary
output "database_configuration" {
  description = "Summary of database configuration"
  value = {
    name                              = google_firestore_database.database.name
    location_id                       = google_firestore_database.database.location_id
    type                             = google_firestore_database.database.type
    concurrency_mode                 = google_firestore_database.database.concurrency_mode
    app_engine_integration_mode      = google_firestore_database.database.app_engine_integration_mode
    point_in_time_recovery_enablement = google_firestore_database.database.point_in_time_recovery_enablement
    delete_protection_state          = google_firestore_database.database.delete_protection_state
  }
}

output "security_configuration" {
  description = "Summary of security configuration"
  value = {
    rules_deployed        = var.deploy_security_rules
    service_account_created = var.create_service_account
    ttl_policies_count    = length(var.ttl_policies)
    iam_bindings_count    = length(var.database_iam_bindings)
    security_config       = var.security_config
  }
}

output "monitoring_configuration" {
  description = "Summary of monitoring configuration"
  value = {
    alerts_enabled       = var.create_monitoring_alerts
    dashboard_created    = var.create_monitoring_dashboard
    log_metrics_enabled  = var.create_log_metrics
    alert_policies_count = var.create_monitoring_alerts ? length(var.monitoring_alerts) : 0
    log_metrics_count    = var.create_log_metrics ? length(var.log_metrics) : 0
  }
}

output "performance_configuration" {
  description = "Summary of performance configuration"
  value = {
    realtime_updates_enabled = var.enable_realtime_updates
    offline_support_enabled  = var.enable_offline_support
    persistence_enabled      = var.enable_persistence
    cache_size_mb           = var.cache_size_mb
    performance_config      = var.performance_config
  }
}

output "backup_configuration" {
  description = "Summary of backup configuration"
  value = {
    backups_enabled      = var.enable_backups
    backup_schedules_count = var.enable_backups ? length(var.backup_schedules) : 0
    bigquery_export_enabled = var.enable_bigquery_export
  }
}

# Index Summary
output "index_summary" {
  description = "Summary of created indexes"
  value = {
    total_indexes = length(var.indexes)
    collections_with_indexes = distinct([
      for idx in var.indexes : idx.collection
    ])
    index_types = {
      for idx in var.indexes : idx.collection => {
        query_scope = idx.query_scope != null ? idx.query_scope : "COLLECTION"
        api_scope   = idx.api_scope != null ? idx.api_scope : "ANY_API"
        field_count = length(idx.fields)
      }
    }
  }
}

# Collections Summary
output "collections_summary" {
  description = "Summary of collections configuration"
  value = {
    configured_collections = length(var.collections_config)
    ttl_enabled_collections = length([
      for k, v in var.collections_config : k if v.enable_ttl == true
    ])
    collections_with_custom_rules = length([
      for k, v in var.collections_config : k if v.security_rules != null
    ])
  }
}

# Module Metadata
output "module_configuration" {
  description = "Module configuration summary"
  value = {
    project_id                = var.project_id
    region                   = var.region
    environment              = local.environment
    name_prefix              = local.name_prefix
    database_name            = google_firestore_database.database.name
    multi_region_enabled     = var.multi_region_config.enable_multi_region
    compliance_configured    = var.compliance_config != null
    development_mode         = var.development_config.enable_emulator
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
    databases           = 1
    service_accounts    = var.create_service_account ? 1 : 0
    indexes            = length(var.indexes)
    ttl_fields         = length(var.ttl_policies)
    backup_schedules   = var.enable_backups ? length(var.backup_schedules) : 0
    initial_documents  = var.create_initial_documents ? length(var.initial_documents) : 0
    data_processors    = var.create_data_processors ? length(var.data_processors) : 0
    alert_policies     = var.create_monitoring_alerts ? length(var.monitoring_alerts) : 0
    dashboards         = var.create_monitoring_dashboard ? 1 : 0
    log_metrics        = var.create_log_metrics ? length(var.log_metrics) : 0
    iam_bindings       = length(var.database_iam_bindings)
    bigquery_datasets  = var.enable_bigquery_export ? 1 : 0
  }
}

# Connection Information
output "connection_info" {
  description = "Connection information for Firestore"
  value = {
    project_id   = var.project_id
    database_id  = google_firestore_database.database.name
    location_id  = google_firestore_database.database.location_id
    endpoint     = "https://firestore.googleapis.com"
    client_config = var.client_config
  }
  sensitive = false
}