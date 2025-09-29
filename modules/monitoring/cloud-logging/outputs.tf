# Cloud Logging Module Outputs

output "log_sink_id" {
  description = "The ID of the created log sink"
  value       = try(google_logging_project_sink.main[0].id, "")
}

output "log_sink_name" {
  description = "The name of the created log sink"
  value       = try(google_logging_project_sink.main[0].name, "")
}

output "log_sink_destination" {
  description = "The destination of the log sink"
  value       = try(google_logging_project_sink.main[0].destination, "")
}

output "log_sink_writer_identity" {
  description = "The identity associated with the sink for permission grants"
  value       = try(google_logging_project_sink.main[0].writer_identity, "")
}

output "log_metric_ids" {
  description = "Map of log metric names to their IDs"
  value = {
    for k, v in google_logging_metric.metrics : k => v.id
  }
}

output "log_metric_names" {
  description = "List of created log metric names"
  value = [
    for metric in google_logging_metric.metrics : metric.name
  ]
}

output "log_view_ids" {
  description = "Map of log view names to their IDs"
  value = {
    for k, v in google_logging_log_view.views : k => v.id
  }
}

output "log_view_names" {
  description = "List of created log view names"
  value = [
    for view in google_logging_log_view.views : view.name
  ]
}

output "log_bucket_id" {
  description = "The ID of the log bucket"
  value       = try(google_logging_project_bucket_config.main[0].id, "")
}

output "log_bucket_name" {
  description = "The name of the log bucket"
  value       = try(google_logging_project_bucket_config.main[0].name, "")
}

output "log_bucket_location" {
  description = "The location of the log bucket"
  value       = try(google_logging_project_bucket_config.main[0].location, "")
}

output "log_bucket_lifecycle_state" {
  description = "The lifecycle state of the log bucket"
  value       = try(google_logging_project_bucket_config.main[0].lifecycle_state, "")
}

output "log_bucket_retention_days" {
  description = "The retention period of the log bucket in days"
  value       = try(google_logging_project_bucket_config.main[0].retention_days, 0)
}

output "log_bucket_locked" {
  description = "Whether the log bucket is locked"
  value       = try(google_logging_project_bucket_config.main[0].locked, false)
}

output "log_exclusion_ids" {
  description = "Map of log exclusion names to their IDs"
  value = {
    for k, v in google_logging_project_exclusion.exclusions : k => v.id
  }
}

output "log_exclusion_names" {
  description = "List of created log exclusion names"
  value = [
    for exclusion in google_logging_project_exclusion.exclusions : exclusion.name
  ]
}

output "log_router_sink_ids" {
  description = "Map of log router sink names to their IDs"
  value = {
    for k, v in google_logging_folder_sink.folder_sinks : k => v.id
  }
}

output "organization_sink_ids" {
  description = "Map of organization sink names to their IDs"
  value = {
    for k, v in google_logging_organization_sink.org_sinks : k => v.id
  }
}

output "billing_account_sink_ids" {
  description = "Map of billing account sink names to their IDs"
  value = {
    for k, v in google_logging_billing_account_sink.billing_sinks : k => v.id
  }
}

output "custom_log_scopes" {
  description = "List of custom log scopes configured"
  value       = var.custom_log_scopes
}

output "log_sink_filter" {
  description = "The filter used by the log sink"
  value       = try(google_logging_project_sink.main[0].filter, "")
}

output "log_sink_bigquery_options" {
  description = "BigQuery options for the log sink"
  value       = try(google_logging_project_sink.main[0].bigquery_options, {})
}

output "log_sink_exclusions" {
  description = "Exclusions configured for the log sink"
  value       = try(google_logging_project_sink.main[0].exclusions, [])
}

output "project_id" {
  description = "The project ID where logging is configured"
  value       = var.project_id
}

output "enabled_apis" {
  description = "List of APIs enabled for logging"
  value = [
    "logging.googleapis.com",
    "stackdriver.googleapis.com"
  ]
}

output "monitoring_notification_channels" {
  description = "Map of notification channels for log-based alerts"
  value = {
    for k, v in google_monitoring_notification_channel.log_channels : k => {
      id   = v.id
      name = v.display_name
      type = v.type
    }
  }
}

output "log_based_alert_policies" {
  description = "Map of log-based alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.log_alerts : k => {
      id      = v.id
      name    = v.display_name
      enabled = v.enabled
    }
  }
}

output "cmek_settings" {
  description = "CMEK settings for log encryption"
  value = {
    enabled     = var.cmek_key_name != ""
    key_name    = var.cmek_key_name
    key_version = try(google_logging_project_bucket_config.main[0].cmek_settings[0].kms_key_version, "")
  }
}

output "audit_log_config" {
  description = "Audit log configuration details"
  value = {
    admin_activity_enabled = var.enable_admin_activity_audit
    data_access_enabled    = var.enable_data_access_audit
    system_event_enabled   = var.enable_system_event_audit
    retention_period       = var.audit_log_retention_days
  }
}

output "export_destinations" {
  description = "Map of all configured export destinations"
  value = {
    storage  = var.storage_destination
    bigquery = var.bigquery_destination
    pubsub   = var.pubsub_destination
    splunk   = var.splunk_destination
    datadog  = var.datadog_destination
  }
}