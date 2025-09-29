# Cloud Scheduler Module Outputs

# HTTP Jobs Outputs
output "http_job_ids" {
  description = "The identifiers for HTTP scheduler jobs"
  value = {
    for k, v in google_cloud_scheduler_job.http_jobs : k => v.id
  }
}

output "http_job_names" {
  description = "The names of HTTP scheduler jobs"
  value = {
    for k, v in google_cloud_scheduler_job.http_jobs : k => v.name
  }
}

output "http_job_regions" {
  description = "The regions of HTTP scheduler jobs"
  value = {
    for k, v in google_cloud_scheduler_job.http_jobs : k => v.region
  }
}

output "http_job_schedules" {
  description = "The schedules of HTTP scheduler jobs"
  value = {
    for k, v in google_cloud_scheduler_job.http_jobs : k => v.schedule
  }
}

# Pub/Sub Jobs Outputs
output "pubsub_job_ids" {
  description = "The identifiers for Pub/Sub scheduler jobs"
  value = {
    for k, v in google_cloud_scheduler_job.pubsub_jobs : k => v.id
  }
}

output "pubsub_job_names" {
  description = "The names of Pub/Sub scheduler jobs"
  value = {
    for k, v in google_cloud_scheduler_job.pubsub_jobs : k => v.name
  }
}

output "pubsub_job_topics" {
  description = "The target topics for Pub/Sub scheduler jobs"
  value = {
    for k, v in google_cloud_scheduler_job.pubsub_jobs : k => v.pubsub_target[0].topic_name
  }
}

# App Engine Jobs Outputs
output "app_engine_job_ids" {
  description = "The identifiers for App Engine scheduler jobs"
  value = {
    for k, v in google_cloud_scheduler_job.app_engine_jobs : k => v.id
  }
}

output "app_engine_job_names" {
  description = "The names of App Engine scheduler jobs"
  value = {
    for k, v in google_cloud_scheduler_job.app_engine_jobs : k => v.name
  }
}

output "app_engine_job_uris" {
  description = "The relative URIs for App Engine scheduler jobs"
  value = {
    for k, v in google_cloud_scheduler_job.app_engine_jobs : k => v.app_engine_http_target[0].relative_uri
  }
}

# Cloud Function Jobs Outputs
output "cloud_function_job_ids" {
  description = "The identifiers for Cloud Function scheduler jobs"
  value = {
    for k, v in google_cloud_scheduler_job.cloud_function_jobs : k => v.id
  }
}

output "cloud_function_job_names" {
  description = "The names of Cloud Function scheduler jobs"
  value = {
    for k, v in google_cloud_scheduler_job.cloud_function_jobs : k => v.name
  }
}

output "cloud_function_job_uris" {
  description = "The URIs for Cloud Function scheduler jobs"
  value = {
    for k, v in google_cloud_scheduler_job.cloud_function_jobs : k => v.http_target[0].uri
  }
}

# All Jobs Combined
output "all_job_ids" {
  description = "All scheduler job identifiers by type"
  value = {
    http           = { for k, v in google_cloud_scheduler_job.http_jobs : k => v.id }
    pubsub         = { for k, v in google_cloud_scheduler_job.pubsub_jobs : k => v.id }
    app_engine     = { for k, v in google_cloud_scheduler_job.app_engine_jobs : k => v.id }
    cloud_function = { for k, v in google_cloud_scheduler_job.cloud_function_jobs : k => v.id }
  }
}

output "all_job_names" {
  description = "All scheduler job names by type"
  value = {
    http           = { for k, v in google_cloud_scheduler_job.http_jobs : k => v.name }
    pubsub         = { for k, v in google_cloud_scheduler_job.pubsub_jobs : k => v.name }
    app_engine     = { for k, v in google_cloud_scheduler_job.app_engine_jobs : k => v.name }
    cloud_function = { for k, v in google_cloud_scheduler_job.cloud_function_jobs : k => v.name }
  }
}

output "total_job_count" {
  description = "Total number of scheduler jobs created"
  value = (
    length(google_cloud_scheduler_job.http_jobs) +
    length(google_cloud_scheduler_job.pubsub_jobs) +
    length(google_cloud_scheduler_job.app_engine_jobs) +
    length(google_cloud_scheduler_job.cloud_function_jobs)
  )
}

# Service Account Outputs
output "service_account_email" {
  description = "The email of the created service account"
  value       = var.create_service_account ? google_service_account.scheduler[0].email : null
}

output "service_account_id" {
  description = "The unique id of the service account"
  value       = var.create_service_account ? google_service_account.scheduler[0].unique_id : null
}

output "service_account_name" {
  description = "The fully-qualified name of the service account"
  value       = var.create_service_account ? google_service_account.scheduler[0].name : null
}

output "service_account_member" {
  description = "The IAM member format for the service account"
  value       = var.create_service_account ? "serviceAccount:${google_service_account.scheduler[0].email}" : null
}

# Pub/Sub Topics Outputs
output "pubsub_topic_names" {
  description = "Names of created Pub/Sub topics"
  value = {
    for k, v in google_pubsub_topic.scheduler_topics : k => v.name
  }
}

output "pubsub_topic_ids" {
  description = "IDs of created Pub/Sub topics"
  value = {
    for k, v in google_pubsub_topic.scheduler_topics : k => v.id
  }
}

# Monitoring Outputs
output "monitoring_alert_policy_ids" {
  description = "IDs of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.scheduler_alerts : k => v.id
  }
}

output "monitoring_alert_policy_names" {
  description = "Names of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.scheduler_alerts : k => v.name
  }
}

output "monitoring_dashboard_id" {
  description = "ID of the monitoring dashboard"
  value       = var.create_monitoring_dashboard ? google_monitoring_dashboard.scheduler[0].id : null
}

# Log Metrics Outputs
output "log_metric_names" {
  description = "Names of created log-based metrics"
  value = {
    for k, v in google_logging_metric.scheduler_metrics : k => v.name
  }
}

output "log_metric_ids" {
  description = "IDs of created log-based metrics"
  value = {
    for k, v in google_logging_metric.scheduler_metrics : k => v.id
  }
}

# Job Configuration Summary
output "job_configurations" {
  description = "Summary of job configurations by type"
  value = {
    http = {
      count = length(local.http_jobs)
      jobs = { for k, v in local.http_jobs : k => {
        schedule = v.schedule
        enabled  = v.enabled
        uri      = v.http_config != null ? v.http_config.uri : null
      } }
    }
    pubsub = {
      count = length(local.pubsub_jobs)
      jobs = { for k, v in local.pubsub_jobs : k => {
        schedule = v.schedule
        enabled  = v.enabled
        topic    = v.pubsub_config != null ? v.pubsub_config.topic_name : null
      } }
    }
    app_engine = {
      count = length(local.app_engine_jobs)
      jobs = { for k, v in local.app_engine_jobs : k => {
        schedule = v.schedule
        enabled  = v.enabled
        uri      = v.app_engine_config != null ? v.app_engine_config.relative_uri : null
      } }
    }
    cloud_function = {
      count = length(local.cloud_function_jobs)
      jobs = { for k, v in local.cloud_function_jobs : k => {
        schedule = v.schedule
        enabled  = v.enabled
        url      = v.cloud_function_config != null ? v.cloud_function_config.function_url : null
      } }
    }
  }
}

# IAM Outputs
output "iam_members" {
  description = "IAM members assigned to scheduler jobs"
  value = {
    for k, v in google_cloud_scheduler_job_iam_member.job_iam : k => {
      job    = v.job
      role   = v.role
      member = v.member
    }
  }
}

# Configuration Metadata
output "module_configuration" {
  description = "Module configuration summary"
  value = {
    project_id               = var.project_id
    region                   = var.region
    environment              = local.environment
    name_prefix              = local.name_prefix
    service_account_created  = var.create_service_account
    pubsub_topics_created    = var.create_pubsub_topics
    monitoring_enabled       = var.create_monitoring_alerts
    dashboard_created        = var.create_monitoring_dashboard
    log_metrics_enabled      = var.create_log_metrics
    default_time_zone        = var.default_time_zone
    default_attempt_deadline = var.default_attempt_deadline
  }
}

# Retry Configuration Summary
output "retry_configurations" {
  description = "Summary of retry configurations for all jobs"
  value = {
    for job_name, job_config in local.job_configs : job_name => {
      retry_count          = job_config.retry_config.retry_count
      max_retry_duration   = job_config.retry_config.max_retry_duration
      min_backoff_duration = job_config.retry_config.min_backoff_duration
      max_backoff_duration = job_config.retry_config.max_backoff_duration
      max_doublings        = job_config.retry_config.max_doublings
    }
  }
}

# Schedule Summary
output "schedule_summary" {
  description = "Summary of job schedules and time zones"
  value = {
    for job_name, job_config in local.job_configs : job_name => {
      schedule    = job_config.schedule
      time_zone   = job_config.time_zone
      enabled     = job_config.enabled
      target_type = job_config.target_type
    }
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
    scheduler_jobs   = var.scheduler_jobs != null ? length(var.scheduler_jobs) : 0
    service_accounts = var.create_service_account ? 1 : 0
    pubsub_topics    = var.create_pubsub_topics ? length(var.pubsub_topic_names) : 0
    alert_policies   = var.create_monitoring_alerts ? length(var.monitoring_alerts) : 0
    dashboards       = var.create_monitoring_dashboard ? 1 : 0
    log_metrics      = var.create_log_metrics ? length(var.log_metrics) : 0
    iam_bindings     = length(var.job_iam_bindings)
  }
}