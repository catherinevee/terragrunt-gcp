# Cloud Logging Module Outputs

output "log_sink_ids" {
  description = "Map of log sink names to their IDs"
  value = {
    for k, v in google_logging_project_sink.log_sinks : k => v.id
  }
}

output "log_sink_names" {
  description = "List of created log sink names"
  value = [
    for sink in google_logging_project_sink.log_sinks : sink.name
  ]
}

output "log_exclusion_ids" {
  description = "Map of log exclusion names to their IDs"
  value = {
    for k, v in google_logging_project_exclusion.log_exclusions : k => v.id
  }
}

output "log_exclusion_names" {
  description = "List of created log exclusion names"
  value = [
    for exclusion in google_logging_project_exclusion.log_exclusions : exclusion.name
  ]
}

output "project_id" {
  description = "The project ID where logging is configured"
  value       = var.project_id
}