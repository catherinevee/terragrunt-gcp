# Cloud Asset Inventory Module - Outputs

# Asset Feed outputs
output "project_feed_ids" {
  description = "IDs of project-level asset feeds"
  value = {
    for k, v in google_cloud_asset_project_feed.asset_feeds : k => v.name
  }
}

output "project_feed_details" {
  description = "Detailed information about project-level asset feeds"
  value = {
    for k, v in google_cloud_asset_project_feed.asset_feeds : k => {
      name               = v.name
      feed_id            = v.feed_id
      content_type       = v.content_type
      asset_types        = v.asset_types
      asset_names        = v.asset_names
      pubsub_topic       = v.feed_output_config[0].pubsub_destination[0].topic
      condition          = v.condition
      relationship_types = v.relationship_types
    }
  }
}

output "org_feed_ids" {
  description = "IDs of organization-level asset feeds"
  value = {
    for k, v in google_cloud_asset_organization_feed.org_asset_feeds : k => v.name
  }
}

output "org_feed_details" {
  description = "Detailed information about organization-level asset feeds"
  value = {
    for k, v in google_cloud_asset_organization_feed.org_asset_feeds : k => {
      name               = v.name
      feed_id            = v.feed_id
      org_id             = v.org_id
      content_type       = v.content_type
      asset_types        = v.asset_types
      asset_names        = v.asset_names
      pubsub_topic       = v.feed_output_config[0].pubsub_destination[0].topic
      condition          = v.condition
      relationship_types = v.relationship_types
    }
  }
}

output "folder_feed_ids" {
  description = "IDs of folder-level asset feeds"
  value = {
    for k, v in google_cloud_asset_folder_feed.folder_asset_feeds : k => v.name
  }
}

output "folder_feed_details" {
  description = "Detailed information about folder-level asset feeds"
  value = {
    for k, v in google_cloud_asset_folder_feed.folder_asset_feeds : k => {
      name               = v.name
      feed_id            = v.feed_id
      folder             = v.folder
      content_type       = v.content_type
      asset_types        = v.asset_types
      asset_names        = v.asset_names
      pubsub_topic       = v.feed_output_config[0].pubsub_destination[0].topic
      condition          = v.condition
      relationship_types = v.relationship_types
    }
  }
}

# Pub/Sub outputs
output "pubsub_topic_names" {
  description = "Names of Pub/Sub topics for asset feeds"
  value = {
    for k, v in google_pubsub_topic.asset_feed_topics : k => v.name
  }
}

output "pubsub_topic_ids" {
  description = "IDs of Pub/Sub topics for asset feeds"
  value = {
    for k, v in google_pubsub_topic.asset_feed_topics : k => v.id
  }
}

output "pubsub_topic_details" {
  description = "Detailed information about Pub/Sub topics"
  value = {
    for k, v in google_pubsub_topic.asset_feed_topics : k => {
      name                       = v.name
      id                         = v.id
      message_retention_duration = v.message_retention_duration
      kms_key_name               = v.kms_key_name
      labels                     = v.labels
      message_storage_policy     = v.message_storage_policy
    }
  }
}

output "pubsub_subscription_names" {
  description = "Names of Pub/Sub subscriptions for asset feeds"
  value = {
    for k, v in google_pubsub_subscription.asset_feed_subscriptions : k => v.name
  }
}

output "pubsub_subscription_ids" {
  description = "IDs of Pub/Sub subscriptions for asset feeds"
  value = {
    for k, v in google_pubsub_subscription.asset_feed_subscriptions : k => v.id
  }
}

output "pubsub_subscription_details" {
  description = "Detailed information about Pub/Sub subscriptions"
  value = {
    for k, v in google_pubsub_subscription.asset_feed_subscriptions : k => {
      name                       = v.name
      id                         = v.id
      topic                      = v.topic
      ack_deadline_seconds       = v.ack_deadline_seconds
      message_retention_duration = v.message_retention_duration
      retain_acked_messages      = v.retain_acked_messages
      enable_message_ordering    = v.enable_message_ordering
      filter                     = v.filter
      push_config                = v.push_config
      retry_policy               = v.retry_policy
      dead_letter_policy         = v.dead_letter_policy
      expiration_policy          = v.expiration_policy
      labels                     = v.labels
    }
  }
}

# BigQuery outputs
output "bigquery_dataset_id" {
  description = "ID of the BigQuery dataset for asset inventory"
  value       = var.enable_bigquery_export ? google_bigquery_dataset.asset_inventory_dataset[0].dataset_id : null
}

output "bigquery_dataset_location" {
  description = "Location of the BigQuery dataset"
  value       = var.enable_bigquery_export ? google_bigquery_dataset.asset_inventory_dataset[0].location : null
}

output "bigquery_dataset_details" {
  description = "Detailed information about the BigQuery dataset"
  value = var.enable_bigquery_export ? {
    dataset_id                      = google_bigquery_dataset.asset_inventory_dataset[0].dataset_id
    project                         = google_bigquery_dataset.asset_inventory_dataset[0].project
    location                        = google_bigquery_dataset.asset_inventory_dataset[0].location
    description                     = google_bigquery_dataset.asset_inventory_dataset[0].description
    default_table_expiration_ms     = google_bigquery_dataset.asset_inventory_dataset[0].default_table_expiration_ms
    default_partition_expiration_ms = google_bigquery_dataset.asset_inventory_dataset[0].default_partition_expiration_ms
    creation_time                   = google_bigquery_dataset.asset_inventory_dataset[0].creation_time
    last_modified_time              = google_bigquery_dataset.asset_inventory_dataset[0].last_modified_time
    labels                          = google_bigquery_dataset.asset_inventory_dataset[0].labels
    access                          = google_bigquery_dataset.asset_inventory_dataset[0].access
  } : null
}

output "bigquery_table_ids" {
  description = "IDs of BigQuery tables for asset inventory"
  value = {
    for k, v in google_bigquery_table.asset_tables : k => v.table_id
  }
}

output "bigquery_table_details" {
  description = "Detailed information about BigQuery tables"
  value = {
    for k, v in google_bigquery_table.asset_tables : k => {
      table_id            = v.table_id
      dataset_id          = v.dataset_id
      project             = v.project
      description         = v.description
      schema              = v.schema
      time_partitioning   = v.time_partitioning
      range_partitioning  = v.range_partitioning
      clustering          = v.clustering
      creation_time       = v.creation_time
      last_modified_time  = v.last_modified_time
      labels              = v.labels
      num_bytes           = v.num_bytes
      num_long_term_bytes = v.num_long_term_bytes
      num_rows            = v.num_rows
    }
  }
}

# Cloud Storage outputs
output "storage_bucket_name" {
  description = "Name of the Cloud Storage bucket for asset exports"
  value       = var.enable_storage_export ? google_storage_bucket.asset_export_bucket[0].name : null
}

output "storage_bucket_url" {
  description = "URL of the Cloud Storage bucket"
  value       = var.enable_storage_export ? google_storage_bucket.asset_export_bucket[0].url : null
}

output "storage_bucket_details" {
  description = "Detailed information about the Cloud Storage bucket"
  value = var.enable_storage_export ? {
    name                        = google_storage_bucket.asset_export_bucket[0].name
    location                    = google_storage_bucket.asset_export_bucket[0].location
    project                     = google_storage_bucket.asset_export_bucket[0].project
    storage_class               = google_storage_bucket.asset_export_bucket[0].storage_class
    uniform_bucket_level_access = google_storage_bucket.asset_export_bucket[0].uniform_bucket_level_access
    versioning                  = google_storage_bucket.asset_export_bucket[0].versioning
    lifecycle_rule              = google_storage_bucket.asset_export_bucket[0].lifecycle_rule
    retention_policy            = google_storage_bucket.asset_export_bucket[0].retention_policy
    encryption                  = google_storage_bucket.asset_export_bucket[0].encryption
    logging                     = google_storage_bucket.asset_export_bucket[0].logging
    labels                      = google_storage_bucket.asset_export_bucket[0].labels
    self_link                   = google_storage_bucket.asset_export_bucket[0].self_link
    url                         = google_storage_bucket.asset_export_bucket[0].url
  } : null
}

# Service Account outputs
output "service_account_email" {
  description = "Email of the asset inventory service account"
  value       = var.create_service_account ? google_service_account.asset_inventory_sa[0].email : null
}

output "service_account_id" {
  description = "ID of the asset inventory service account"
  value       = var.create_service_account ? google_service_account.asset_inventory_sa[0].account_id : null
}

output "service_account_unique_id" {
  description = "Unique ID of the asset inventory service account"
  value       = var.create_service_account ? google_service_account.asset_inventory_sa[0].unique_id : null
}

output "service_account_details" {
  description = "Detailed information about the service account"
  value = var.create_service_account ? {
    account_id   = google_service_account.asset_inventory_sa[0].account_id
    email        = google_service_account.asset_inventory_sa[0].email
    display_name = google_service_account.asset_inventory_sa[0].display_name
    description  = google_service_account.asset_inventory_sa[0].description
    project      = google_service_account.asset_inventory_sa[0].project
    unique_id    = google_service_account.asset_inventory_sa[0].unique_id
    name         = google_service_account.asset_inventory_sa[0].name
  } : null
}

# Cloud Functions outputs
output "cloud_function_names" {
  description = "Names of Cloud Functions for asset processing"
  value = {
    for k, v in google_cloudfunctions_function.asset_processor : k => v.name
  }
}

output "cloud_function_details" {
  description = "Detailed information about Cloud Functions"
  value = {
    for k, v in google_cloudfunctions_function.asset_processor : k => {
      name                  = v.name
      description           = v.description
      region                = v.region
      runtime               = v.runtime
      available_memory_mb   = v.available_memory_mb
      timeout               = v.timeout
      entry_point           = v.entry_point
      service_account_email = v.service_account_email
      https_trigger_url     = v.https_trigger_url
      source_archive_bucket = v.source_archive_bucket
      source_archive_object = v.source_archive_object
      event_trigger         = v.event_trigger
      environment_variables = v.environment_variables
      labels                = v.labels
    }
  }
}

# Cloud Scheduler outputs
output "scheduler_job_names" {
  description = "Names of Cloud Scheduler jobs for asset exports"
  value = {
    for k, v in google_cloud_scheduler_job.asset_export_jobs : k => v.name
  }
}

output "scheduler_job_details" {
  description = "Detailed information about Cloud Scheduler jobs"
  value = {
    for k, v in google_cloud_scheduler_job.asset_export_jobs : k => {
      name          = v.name
      description   = v.description
      schedule      = v.schedule
      time_zone     = v.time_zone
      region        = v.region
      pubsub_target = v.pubsub_target
      http_target   = v.http_target
      retry_config  = v.retry_config
      state         = v.state
    }
  }
}

# Monitoring outputs
output "monitoring_dashboard_id" {
  description = "ID of the asset inventory monitoring dashboard"
  value       = var.enable_monitoring && var.create_dashboard ? google_monitoring_dashboard.asset_inventory_dashboard[0].id : null
}

output "monitoring_dashboard_url" {
  description = "URL to the asset inventory monitoring dashboard"
  value = var.enable_monitoring && var.create_dashboard ? (
    "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.asset_inventory_dashboard[0].id}?project=${var.project_id}"
  ) : null
}

output "alert_policy_ids" {
  description = "IDs of created alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.asset_inventory_alerts : k => v.id
  }
}

output "alert_policy_names" {
  description = "Names of created alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.asset_inventory_alerts : k => v.display_name
  }
}

output "alert_policy_details" {
  description = "Detailed information about alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.asset_inventory_alerts : k => {
      name                  = v.name
      display_name          = v.display_name
      combiner              = v.combiner
      enabled               = v.enabled
      conditions            = v.conditions
      notification_channels = v.notification_channels
      alert_strategy        = v.alert_strategy
      documentation         = v.documentation
    }
  }
}

# Security Center outputs
output "security_center_source_name" {
  description = "Name of the Security Command Center source"
  value       = var.enable_security_center_integration ? google_security_center_source.asset_inventory_source[0].name : null
}

output "security_center_source_details" {
  description = "Detailed information about the Security Command Center source"
  value = var.enable_security_center_integration ? {
    name         = google_security_center_source.asset_inventory_source[0].name
    display_name = google_security_center_source.asset_inventory_source[0].display_name
    description  = google_security_center_source.asset_inventory_source[0].description
    organization = google_security_center_source.asset_inventory_source[0].organization
  } : null
}

# Configuration metadata
output "configuration_metadata" {
  description = "Metadata about the Cloud Asset Inventory configuration"
  value = {
    project_id                    = var.project_id
    org_id                        = var.org_id
    project_feeds_count           = length(google_cloud_asset_project_feed.asset_feeds)
    org_feeds_count               = length(google_cloud_asset_organization_feed.org_asset_feeds)
    folder_feeds_count            = length(google_cloud_asset_folder_feed.folder_asset_feeds)
    pubsub_topics_count           = length(google_pubsub_topic.asset_feed_topics)
    pubsub_subscriptions_count    = length(google_pubsub_subscription.asset_feed_subscriptions)
    bigquery_export_enabled       = var.enable_bigquery_export
    storage_export_enabled        = var.enable_storage_export
    bigquery_tables_count         = length(google_bigquery_table.asset_tables)
    cloud_functions_count         = length(google_cloudfunctions_function.asset_processor)
    scheduled_jobs_count          = length(google_cloud_scheduler_job.asset_export_jobs)
    monitoring_enabled            = var.enable_monitoring
    security_center_enabled       = var.enable_security_center_integration
    audit_logging_enabled         = var.enable_audit_logging
    compliance_monitoring_enabled = var.enable_compliance_monitoring
    data_governance_enabled       = var.enable_data_governance
    cost_analysis_enabled         = var.enable_cost_analysis
    security_insights_enabled     = var.enable_security_insights
    automation_enabled            = var.enable_automation
    total_alert_policies          = length(google_monitoring_alert_policy.asset_inventory_alerts)
  }
}

# Feed configuration summary
output "feed_configuration_summary" {
  description = "Summary of all asset feed configurations"
  value = {
    total_feeds = length(local.all_feeds)
    feeds_by_type = {
      project_level = length(var.asset_feeds)
      org_level     = length(var.org_asset_feeds)
      folder_level  = length(var.folder_asset_feeds)
    }
    content_types = {
      for feed_name, feed_config in local.all_feeds : feed_name => feed_config.content_type
    }
    monitored_asset_types = flatten([
      for feed_config in local.all_feeds : feed_config.asset_types != null ? feed_config.asset_types : []
    ])
    pubsub_topics_used = {
      for feed_name, feed_config in local.all_feeds : feed_name => feed_config.pubsub_topic
    }
  }
}

# Export configuration summary
output "export_configuration_summary" {
  description = "Summary of export configurations"
  value = {
    bigquery = {
      enabled      = var.enable_bigquery_export
      dataset_id   = var.bigquery_dataset_id
      location     = var.bigquery_location
      tables_count = length(var.bigquery_tables)
      table_names  = keys(var.bigquery_tables)
    }
    storage = {
      enabled         = var.enable_storage_export
      bucket_name     = var.storage_bucket_name
      location        = var.storage_bucket_location
      versioning      = var.bucket_versioning_enabled
      lifecycle_rules = length(var.bucket_lifecycle_rules)
    }
    formats = {
      json_enabled    = var.export_formats.enable_json_export
      csv_enabled     = var.export_formats.enable_csv_export
      parquet_enabled = var.export_formats.enable_parquet_export
      avro_enabled    = var.export_formats.enable_avro_export
      compression     = var.export_formats.compression_enabled
    }
  }
}

# Automation and processing summary
output "automation_summary" {
  description = "Summary of automation and processing capabilities"
  value = {
    cloud_functions = {
      enabled         = var.enable_cloud_functions
      functions_count = length(var.cloud_functions)
      function_names  = keys(var.cloud_functions)
    }
    scheduled_exports = {
      enabled    = var.enable_scheduled_exports
      jobs_count = length(var.scheduled_export_jobs)
      job_names  = keys(var.scheduled_export_jobs)
    }
    automation_features = {
      auto_remediation     = var.automation_config.enable_auto_remediation
      policy_enforcement   = var.automation_config.enable_policy_enforcement
      automated_tagging    = var.automation_config.enable_automated_tagging
      lifecycle_management = var.automation_config.enable_lifecycle_management
    }
  }
}

# Security and compliance summary
output "security_compliance_summary" {
  description = "Summary of security and compliance features"
  value = {
    compliance_monitoring = {
      enabled        = var.enable_compliance_monitoring
      policies_count = length(var.compliance_policies)
      policy_names   = keys(var.compliance_policies)
    }
    data_governance = {
      enabled           = var.enable_data_governance
      classification    = var.data_governance_config.enable_data_classification
      lineage           = var.data_governance_config.enable_data_lineage
      access_monitoring = var.data_governance_config.enable_access_monitoring
    }
    security_insights = {
      enabled                = var.enable_security_insights
      vulnerability_scanning = var.security_insights_config.enable_vulnerability_scanning
      misconfig_detection    = var.security_insights_config.enable_misconfig_detection
      access_analysis        = var.security_insights_config.enable_access_analysis
      threat_detection       = var.security_insights_config.enable_threat_detection
    }
    security_center_integration = var.enable_security_center_integration
  }
}

# Data retention and lifecycle
output "data_lifecycle_summary" {
  description = "Summary of data retention and lifecycle policies"
  value = {
    retention_periods = {
      raw_data_days       = var.data_retention_config.raw_data_retention_days
      processed_data_days = var.data_retention_config.processed_data_retention_days
      audit_log_days      = var.data_retention_config.audit_log_retention_days
    }
    automatic_cleanup = {
      enabled  = var.data_retention_config.enable_automatic_cleanup
      schedule = var.data_retention_config.cleanup_schedule
    }
    bigquery_lifecycle = var.enable_bigquery_export ? {
      table_expiration     = var.bigquery_table_expiration_ms
      partition_expiration = var.bigquery_partition_expiration_ms
    } : null
    storage_lifecycle = var.enable_storage_export ? {
      lifecycle_rules_count = length(var.bucket_lifecycle_rules)
      versioning_enabled    = var.bucket_versioning_enabled
    } : null
  }
}

# Integration status
output "integration_status" {
  description = "Status of third-party integrations"
  value = {
    integrations_count = length(var.integration_configs)
    integrations = {
      for k, v in var.integration_configs : k => {
        type      = v.integration_type
        enabled   = v.enabled
        frequency = v.sync_frequency
      }
    }
    notification_integrations = {
      email_enabled   = var.notification_config.enable_email_notifications
      slack_enabled   = var.notification_config.enable_slack_notifications
      webhook_enabled = var.notification_config.enable_webhook_notifications
    }
  }
}

# Management URLs
output "management_urls" {
  description = "URLs for managing Cloud Asset Inventory resources"
  value = {
    asset_inventory_console = "https://console.cloud.google.com/security/asset-inventory?project=${var.project_id}"
    bigquery_console        = var.enable_bigquery_export ? "https://console.cloud.google.com/bigquery?project=${var.project_id}" : null
    storage_console         = var.enable_storage_export ? "https://console.cloud.google.com/storage/browser?project=${var.project_id}" : null
    pubsub_console          = var.create_pubsub_topics ? "https://console.cloud.google.com/cloudpubsub?project=${var.project_id}" : null
    cloud_functions_console = var.enable_cloud_functions ? "https://console.cloud.google.com/functions?project=${var.project_id}" : null
    scheduler_console       = var.enable_scheduled_exports ? "https://console.cloud.google.com/cloudscheduler?project=${var.project_id}" : null
    monitoring_console      = var.enable_monitoring ? "https://console.cloud.google.com/monitoring?project=${var.project_id}" : null
    security_center_console = var.enable_security_center_integration && var.org_id != null ? "https://console.cloud.google.com/security/command-center?organizationId=${var.org_id}" : null
    logs_console            = "https://console.cloud.google.com/logs/query?project=${var.project_id}"
  }
}

# Resource identifiers for integration
output "resource_identifiers" {
  description = "Resource identifiers for integration with other modules"
  value = {
    project_feed_resources = {
      for k, v in google_cloud_asset_project_feed.asset_feeds : k => v.name
    }
    org_feed_resources = {
      for k, v in google_cloud_asset_organization_feed.org_asset_feeds : k => v.name
    }
    folder_feed_resources = {
      for k, v in google_cloud_asset_folder_feed.folder_asset_feeds : k => v.name
    }
    pubsub_topic_resources = {
      for k, v in google_pubsub_topic.asset_feed_topics : k => v.name
    }
    bigquery_dataset_resource       = var.enable_bigquery_export ? google_bigquery_dataset.asset_inventory_dataset[0].id : null
    storage_bucket_resource         = var.enable_storage_export ? google_storage_bucket.asset_export_bucket[0].name : null
    service_account_resource        = var.create_service_account ? google_service_account.asset_inventory_sa[0].email : null
    security_center_source_resource = var.enable_security_center_integration ? google_security_center_source.asset_inventory_source[0].name : null
  }
}