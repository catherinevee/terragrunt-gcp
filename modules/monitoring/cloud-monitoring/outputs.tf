# Cloud Monitoring Module Outputs

output "dashboard_ids" {
  description = "Map of dashboard names to their IDs"
  value = {
    for k, v in google_monitoring_dashboard.dashboards : k => v.id
  }
}

output "dashboard_names" {
  description = "List of created dashboard display names"
  value = [
    for dashboard in google_monitoring_dashboard.dashboards : dashboard.display_name
  ]
}

output "alert_policy_ids" {
  description = "Map of alert policy names to their IDs"
  value = {
    for k, v in google_monitoring_alert_policy.policies : k => v.id
  }
}

output "alert_policy_names" {
  description = "List of created alert policy display names"
  value = [
    for policy in google_monitoring_alert_policy.policies : policy.display_name
  ]
}

output "alert_policy_enabled_status" {
  description = "Map of alert policy names to their enabled status"
  value = {
    for k, v in google_monitoring_alert_policy.policies : k => v.enabled
  }
}

output "notification_channel_ids" {
  description = "Map of notification channel names to their IDs"
  value = {
    for k, v in google_monitoring_notification_channel.channels : k => v.id
  }
}

output "notification_channel_names" {
  description = "List of created notification channel display names"
  value = [
    for channel in google_monitoring_notification_channel.channels : channel.display_name
  ]
}

output "notification_channel_types" {
  description = "Map of notification channel names to their types"
  value = {
    for k, v in google_monitoring_notification_channel.channels : k => v.type
  }
}

output "uptime_check_ids" {
  description = "Map of uptime check names to their IDs"
  value = {
    for k, v in google_monitoring_uptime_check_config.uptime_checks : k => v.id
  }
}

output "uptime_check_names" {
  description = "List of created uptime check display names"
  value = [
    for check in google_monitoring_uptime_check_config.uptime_checks : check.display_name
  ]
}

output "uptime_check_monitored_resources" {
  description = "Map of uptime checks to their monitored resources"
  value = {
    for k, v in google_monitoring_uptime_check_config.uptime_checks : k => v.monitored_resource
  }
}

output "custom_metric_descriptors" {
  description = "Map of custom metric names to their descriptors"
  value = {
    for k, v in google_monitoring_metric_descriptor.custom_metrics : k => {
      id           = v.id
      type         = v.type
      metric_kind  = v.metric_kind
      value_type   = v.value_type
      unit         = v.unit
      display_name = v.display_name
    }
  }
}

output "custom_metric_types" {
  description = "List of custom metric types created"
  value = [
    for metric in google_monitoring_metric_descriptor.custom_metrics : metric.type
  ]
}

output "slo_ids" {
  description = "Map of SLO names to their IDs"
  value = {
    for k, v in google_monitoring_slo.slos : k => v.id
  }
}

output "slo_names" {
  description = "List of created SLO display names"
  value = [
    for slo in google_monitoring_slo.slos : slo.display_name
  ]
}

output "slo_goals" {
  description = "Map of SLOs to their goal configurations"
  value = {
    for k, v in google_monitoring_slo.slos : k => v.goal
  }
}

output "service_ids" {
  description = "Map of service names to their IDs"
  value = {
    for k, v in google_monitoring_service.services : k => v.id
  }
}

output "service_names" {
  description = "List of created service display names"
  value = [
    for service in google_monitoring_service.services : service.display_name
  ]
}

output "service_telemetry" {
  description = "Map of services to their telemetry configurations"
  value = {
    for k, v in google_monitoring_service.services : k => v.telemetry
  }
}

output "group_ids" {
  description = "Map of monitoring group names to their IDs"
  value = {
    for k, v in google_monitoring_group.groups : k => v.id
  }
}

output "group_names" {
  description = "List of created monitoring group display names"
  value = [
    for group in google_monitoring_group.groups : group.display_name
  ]
}

output "group_filters" {
  description = "Map of monitoring groups to their filter criteria"
  value = {
    for k, v in google_monitoring_group.groups : k => v.filter
  }
}

output "custom_service_ids" {
  description = "Map of custom service names to their IDs"
  value = {
    for k, v in google_monitoring_custom_service.custom_services : k => v.id
  }
}

output "workspace_id" {
  description = "The ID of the monitoring workspace"
  value       = var.workspace_id
}

output "project_id" {
  description = "The project ID where monitoring is configured"
  value       = var.project_id
}

output "monitoring_scope" {
  description = "The monitoring scope configuration"
  value = {
    project_id         = var.project_id
    monitored_projects = var.monitored_projects
    metrics_scope      = var.metrics_scope
  }
}

output "alert_policy_documentation" {
  description = "Map of alert policies to their documentation"
  value = {
    for k, v in google_monitoring_alert_policy.policies : k => v.documentation
  }
}

output "notification_channel_labels" {
  description = "Map of notification channels to their labels"
  value = {
    for k, v in google_monitoring_notification_channel.channels : k => v.labels
  }
}

output "notification_channel_verification_status" {
  description = "Map of notification channels to their verification status"
  value = {
    for k, v in google_monitoring_notification_channel.channels : k => v.verification_status
  }
}

output "dashboard_json_configs" {
  description = "Map of dashboards to their JSON configurations"
  value = {
    for k, v in google_monitoring_dashboard.dashboards : k => v.dashboard_json
  }
  sensitive = true
}

output "log_metric_ids" {
  description = "Map of log-based metric names to their IDs"
  value = {
    for k, v in google_logging_metric.log_metrics : k => v.id
  }
}

output "log_metric_filters" {
  description = "Map of log-based metrics to their filters"
  value = {
    for k, v in google_logging_metric.log_metrics : k => v.filter
  }
}

output "synthetic_monitor_ids" {
  description = "Map of synthetic monitor names to their IDs"
  value = {
    for k, v in google_monitoring_uptime_check_config.synthetic_monitors : k => v.id
  }
}

output "incident_policies" {
  description = "Map of incident management policies"
  value = {
    for k, v in var.incident_policies : k => {
      severity         = v.severity
      auto_close       = v.auto_close
      escalation_chain = v.escalation_chain
    }
  }
}

output "monitoring_channels_summary" {
  description = "Summary of all notification channels by type"
  value = {
    email_channels     = length([for k, v in google_monitoring_notification_channel.channels : k if v.type == "email"])
    sms_channels       = length([for k, v in google_monitoring_notification_channel.channels : k if v.type == "sms"])
    slack_channels     = length([for k, v in google_monitoring_notification_channel.channels : k if v.type == "slack"])
    pagerduty_channels = length([for k, v in google_monitoring_notification_channel.channels : k if v.type == "pagerduty"])
    webhook_channels   = length([for k, v in google_monitoring_notification_channel.channels : k if v.type == "webhook"])
  }
}

output "alerting_rules_count" {
  description = "Total number of alerting rules configured"
  value       = length(google_monitoring_alert_policy.policies)
}

output "uptime_checks_count" {
  description = "Total number of uptime checks configured"
  value       = length(google_monitoring_uptime_check_config.uptime_checks)
}

output "dashboards_count" {
  description = "Total number of dashboards configured"
  value       = length(google_monitoring_dashboard.dashboards)
}

output "enabled_apis" {
  description = "List of APIs enabled for monitoring"
  value = [
    "monitoring.googleapis.com",
    "stackdriver.googleapis.com",
    "cloudtrace.googleapis.com",
    "cloudprofiler.googleapis.com"
  ]
}