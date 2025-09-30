# Cloud Monitoring Module Outputs

output "alert_policy_ids" {
  description = "Map of alert policy names to their IDs"
  value = {
    for k, v in google_monitoring_alert_policy.alert_policies : k => v.id
  }
}

output "alert_policy_names" {
  description = "List of created alert policy names"
  value = [
    for policy in google_monitoring_alert_policy.alert_policies : policy.display_name
  ]
}

output "monitoring_service_ids" {
  description = "Map of monitoring service names to their IDs"
  value = {
    for k, v in google_monitoring_service.monitoring_services : k => v.id
  }
}

output "monitoring_service_names" {
  description = "List of created monitoring service names"
  value = [
    for service in google_monitoring_service.monitoring_services : service.display_name
  ]
}

output "slo_ids" {
  description = "Map of SLO names to their IDs"
  value = {
    for k, v in google_monitoring_slo.slos : k => v.id
  }
}

output "slo_names" {
  description = "List of created SLO names"
  value = [
    for slo in google_monitoring_slo.slos : slo.display_name
  ]
}

output "project_id" {
  description = "The project ID where monitoring is configured"
  value       = var.project_id
}