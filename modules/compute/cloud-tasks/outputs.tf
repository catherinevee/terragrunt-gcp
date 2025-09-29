# Cloud Tasks Module Outputs

# HTTP Queue Outputs
output "http_queue_ids" {
  description = "The identifiers for HTTP task queues"
  value = {
    for k, v in google_cloud_tasks_queue.http_queues : k => v.id
  }
}

output "http_queue_names" {
  description = "The names of HTTP task queues"
  value = {
    for k, v in google_cloud_tasks_queue.http_queues : k => v.name
  }
}

output "http_queue_locations" {
  description = "The locations of HTTP task queues"
  value = {
    for k, v in google_cloud_tasks_queue.http_queues : k => v.location
  }
}

# App Engine Queue Outputs
output "app_engine_queue_ids" {
  description = "The identifiers for App Engine task queues"
  value = {
    for k, v in google_cloud_tasks_queue.app_engine_queues : k => v.id
  }
}

output "app_engine_queue_names" {
  description = "The names of App Engine task queues"
  value = {
    for k, v in google_cloud_tasks_queue.app_engine_queues : k => v.name
  }
}

output "app_engine_queue_locations" {
  description = "The locations of App Engine task queues"
  value = {
    for k, v in google_cloud_tasks_queue.app_engine_queues : k => v.location
  }
}

# Pull Queue Outputs
output "pull_queue_ids" {
  description = "The identifiers for pull task queues"
  value = {
    for k, v in google_cloud_tasks_queue.pull_queues : k => v.id
  }
}

output "pull_queue_names" {
  description = "The names of pull task queues"
  value = {
    for k, v in google_cloud_tasks_queue.pull_queues : k => v.name
  }
}

output "pull_queue_locations" {
  description = "The locations of pull task queues"
  value = {
    for k, v in google_cloud_tasks_queue.pull_queues : k => v.location
  }
}

# All Queues Combined
output "all_queue_ids" {
  description = "All task queue identifiers by type"
  value = {
    http       = { for k, v in google_cloud_tasks_queue.http_queues : k => v.id }
    app_engine = { for k, v in google_cloud_tasks_queue.app_engine_queues : k => v.id }
    pull       = { for k, v in google_cloud_tasks_queue.pull_queues : k => v.id }
  }
}

output "all_queue_names" {
  description = "All task queue names by type"
  value = {
    http       = { for k, v in google_cloud_tasks_queue.http_queues : k => v.name }
    app_engine = { for k, v in google_cloud_tasks_queue.app_engine_queues : k => v.name }
    pull       = { for k, v in google_cloud_tasks_queue.pull_queues : k => v.name }
  }
}

output "total_queue_count" {
  description = "Total number of task queues created"
  value = (
    length(google_cloud_tasks_queue.http_queues) +
    length(google_cloud_tasks_queue.app_engine_queues) +
    length(google_cloud_tasks_queue.pull_queues)
  )
}

# Service Account Outputs
output "service_account_email" {
  description = "The email of the created service account"
  value       = var.create_service_account ? google_service_account.tasks[0].email : null
}

output "service_account_id" {
  description = "The unique id of the service account"
  value       = var.create_service_account ? google_service_account.tasks[0].unique_id : null
}

output "service_account_name" {
  description = "The fully-qualified name of the service account"
  value       = var.create_service_account ? google_service_account.tasks[0].name : null
}

output "service_account_member" {
  description = "The IAM member format for the service account"
  value       = var.create_service_account ? "serviceAccount:${google_service_account.tasks[0].email}" : null
}

# Sample Tasks Outputs
output "sample_task_ids" {
  description = "IDs of created sample tasks"
  value = {
    for k, v in google_cloud_tasks_task.sample_tasks : k => v.id
  }
}

output "sample_task_names" {
  description = "Names of created sample tasks"
  value = {
    for k, v in google_cloud_tasks_task.sample_tasks : k => v.name
  }
}

# Task Processor Outputs (Cloud Functions)
output "task_processor_ids" {
  description = "IDs of created task processor functions"
  value = {
    for k, v in google_cloudfunctions_function.task_processor : k => v.id
  }
}

output "task_processor_names" {
  description = "Names of created task processor functions"
  value = {
    for k, v in google_cloudfunctions_function.task_processor : k => v.name
  }
}

output "task_processor_trigger_urls" {
  description = "Trigger URLs for HTTP task processors"
  value = {
    for k, v in google_cloudfunctions_function.task_processor : k => v.https_trigger_url
    if v.https_trigger_url != null
  }
}

# Monitoring Outputs
output "monitoring_alert_policy_ids" {
  description = "IDs of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.tasks_alerts : k => v.id
  }
}

output "monitoring_alert_policy_names" {
  description = "Names of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.tasks_alerts : k => v.name
  }
}

output "monitoring_dashboard_id" {
  description = "ID of the monitoring dashboard"
  value       = var.create_monitoring_dashboard ? google_monitoring_dashboard.tasks[0].id : null
}

# Log Metrics Outputs
output "log_metric_names" {
  description = "Names of created log-based metrics"
  value = {
    for k, v in google_logging_metric.tasks_metrics : k => v.name
  }
}

output "log_metric_ids" {
  description = "IDs of created log-based metrics"
  value = {
    for k, v in google_logging_metric.tasks_metrics : k => v.id
  }
}

# Queue Configuration Summary
output "queue_configurations" {
  description = "Summary of queue configurations by type"
  value = {
    http = {
      count = length(local.http_queues)
      queues = { for k, v in local.http_queues : k => {
        location     = v.location
        state        = v.state
        rate_limits  = v.rate_limits
        retry_config = v.retry_config
      } }
    }
    app_engine = {
      count = length(local.app_engine_queues)
      queues = { for k, v in local.app_engine_queues : k => {
        location     = v.location
        state        = v.state
        rate_limits  = v.rate_limits
        retry_config = v.retry_config
      } }
    }
    pull = {
      count = length(local.pull_queues)
      queues = { for k, v in local.pull_queues : k => {
        location     = v.location
        state        = v.state
        rate_limits  = v.rate_limits
        retry_config = v.retry_config
      } }
    }
  }
}

# IAM Outputs
output "iam_members" {
  description = "IAM members assigned to task queues"
  value = {
    for k, v in google_cloud_tasks_queue_iam_member.queue_iam : k => {
      queue  = v.name
      role   = v.role
      member = v.member
    }
  }
}

# Rate Limit Summary
output "rate_limit_summary" {
  description = "Summary of rate limits for all queues"
  value = {
    for queue_name, queue_config in local.queue_configs : queue_name => {
      max_dispatches_per_second = queue_config.rate_limits.max_dispatches_per_second
      max_burst_size            = queue_config.rate_limits.max_burst_size
      max_concurrent_dispatches = queue_config.rate_limits.max_concurrent_dispatches
      target_type               = queue_config.target_type
    }
  }
}

# Retry Configuration Summary
output "retry_configurations" {
  description = "Summary of retry configurations for all queues"
  value = {
    for queue_name, queue_config in local.queue_configs : queue_name => {
      max_attempts       = queue_config.retry_config.max_attempts
      max_retry_duration = queue_config.retry_config.max_retry_duration
      max_backoff        = queue_config.retry_config.max_backoff
      min_backoff        = queue_config.retry_config.min_backoff
      max_doublings      = queue_config.retry_config.max_doublings
      target_type        = queue_config.target_type
    }
  }
}

# Queue State Summary
output "queue_states" {
  description = "Current state of all queues"
  value = {
    for queue_name, queue_config in local.queue_configs : queue_name => {
      state       = queue_config.state
      target_type = queue_config.target_type
      location    = queue_config.location
    }
  }
}

# Logging Configuration Summary
output "logging_configurations" {
  description = "Summary of logging configurations"
  value = {
    for queue_name, queue_config in local.queue_configs : queue_name => {
      sampling_ratio = queue_config.logging_config != null ? queue_config.logging_config.sampling_ratio : 1.0
      target_type    = queue_config.target_type
    }
  }
}

# Configuration Metadata
output "module_configuration" {
  description = "Module configuration summary"
  value = {
    project_id              = var.project_id
    region                  = var.region
    environment             = local.environment
    name_prefix             = local.name_prefix
    service_account_created = var.create_service_account
    sample_tasks_created    = var.create_sample_tasks
    processors_created      = var.create_task_processors
    monitoring_enabled      = var.create_monitoring_alerts
    dashboard_created       = var.create_monitoring_dashboard
    log_metrics_enabled     = var.create_log_metrics
    default_task_timeout    = var.default_task_timeout
    max_concurrent_tasks    = var.max_concurrent_tasks
    enable_task_retries     = var.enable_task_retries
    default_retry_attempts  = var.default_retry_attempts
  }
}

# Performance Summary
output "performance_summary" {
  description = "Performance configuration summary"
  value = {
    total_max_dispatches = sum([
      for queue_config in local.queue_configs : queue_config.rate_limits.max_dispatches_per_second
    ])
    total_max_concurrent = sum([
      for queue_config in local.queue_configs : queue_config.rate_limits.max_concurrent_dispatches
    ])
    average_max_attempts = var.task_queues != null && length(var.task_queues) > 0 ? (
      sum([
        for queue_config in local.queue_configs : queue_config.retry_config.max_attempts
      ]) / length(local.queue_configs)
    ) : 0
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
    task_queues      = var.task_queues != null ? length(var.task_queues) : 0
    service_accounts = var.create_service_account ? 1 : 0
    sample_tasks     = var.create_sample_tasks ? length(var.sample_tasks) : 0
    task_processors  = var.create_task_processors ? length(var.task_processors) : 0
    alert_policies   = var.create_monitoring_alerts ? length(var.monitoring_alerts) : 0
    dashboards       = var.create_monitoring_dashboard ? 1 : 0
    log_metrics      = var.create_log_metrics ? length(var.log_metrics) : 0
    iam_bindings     = length(var.queue_iam_bindings)
  }
}

# Integration Status
output "integration_status" {
  description = "Status of various integrations"
  value = {
    pubsub_integration    = var.pubsub_integration.enabled
    firestore_integration = var.firestore_integration.enabled
    dead_letter_queue     = var.dead_letter_queue_config.enabled
    security_config       = var.security_config != null
    performance_config    = var.performance_config != null
  }
}