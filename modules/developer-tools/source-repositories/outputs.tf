# Cloud Source Repositories Module - Outputs

# Repository outputs
output "repository_names" {
  description = "Names of Cloud Source Repositories"
  value = {
    for k, v in google_sourcerepo_repository.repositories : k => v.name
  }
}

output "repository_urls" {
  description = "URLs of Cloud Source Repositories"
  value = {
    for k, v in google_sourcerepo_repository.repositories : k => v.url
  }
}

output "repository_details" {
  description = "Detailed information about Cloud Source Repositories"
  value = {
    for k, v in google_sourcerepo_repository.repositories : k => {
      name    = v.name
      url     = v.url
      size    = v.size
      project = v.project
    }
  }
}

# Cloud Build Trigger outputs
output "build_trigger_ids" {
  description = "IDs of Cloud Build triggers"
  value = {
    for k, v in google_cloudbuild_trigger.repo_triggers : k => v.id
  }
}

output "build_trigger_names" {
  description = "Names of Cloud Build triggers"
  value = {
    for k, v in google_cloudbuild_trigger.repo_triggers : k => v.name
  }
}

output "build_trigger_details" {
  description = "Detailed information about Cloud Build triggers"
  value = {
    for k, v in google_cloudbuild_trigger.repo_triggers : k => {
      id               = v.id
      name             = v.name
      description      = v.description
      project          = v.project
      filename         = v.filename
      disabled         = v.disabled
      trigger_template = v.trigger_template
      service_account  = v.service_account
      tags             = v.tags
    }
  }
}

# Pub/Sub outputs
output "pubsub_topic_names" {
  description = "Names of Pub/Sub topics for repository events"
  value = {
    for k, v in google_pubsub_topic.repo_event_topics : k => v.name
  }
}

output "pubsub_topic_ids" {
  description = "IDs of Pub/Sub topics for repository events"
  value = {
    for k, v in google_pubsub_topic.repo_event_topics : k => v.id
  }
}

output "pubsub_subscription_names" {
  description = "Names of Pub/Sub subscriptions for repository events"
  value = {
    for k, v in google_pubsub_subscription.repo_event_subscriptions : k => v.name
  }
}

output "pubsub_subscription_ids" {
  description = "IDs of Pub/Sub subscriptions for repository events"
  value = {
    for k, v in google_pubsub_subscription.repo_event_subscriptions : k => v.id
  }
}

# Cloud Storage outputs
output "build_artifacts_bucket_name" {
  description = "Name of the build artifacts storage bucket"
  value       = var.enable_build_artifacts_storage ? google_storage_bucket.build_artifacts_bucket[0].name : null
}

output "build_artifacts_bucket_url" {
  description = "URL of the build artifacts storage bucket"
  value       = var.enable_build_artifacts_storage ? google_storage_bucket.build_artifacts_bucket[0].url : null
}

# Service Account outputs
output "service_account_email" {
  description = "Email of the Source Repositories service account"
  value       = var.create_service_account ? google_service_account.source_repos_sa[0].email : null
}

output "service_account_id" {
  description = "ID of the Source Repositories service account"
  value       = var.create_service_account ? google_service_account.source_repos_sa[0].account_id : null
}

# Secret Manager outputs
output "repository_secret_names" {
  description = "Names of repository secrets in Secret Manager"
  value = {
    for k, v in google_secret_manager_secret.repo_secrets : k => v.secret_id
  }
}

output "repository_secret_details" {
  description = "Detailed information about repository secrets"
  value = {
    for k, v in google_secret_manager_secret.repo_secrets : k => {
      secret_id   = v.secret_id
      name        = v.name
      project     = v.project
      replication = v.replication
      labels      = v.labels
    }
  }
  sensitive = true
}

# Cloud Functions outputs
output "webhook_function_names" {
  description = "Names of webhook Cloud Functions"
  value = {
    for k, v in google_cloudfunctions_function.repo_webhooks : k => v.name
  }
}

output "webhook_function_urls" {
  description = "HTTPS trigger URLs for webhook Cloud Functions"
  value = {
    for k, v in google_cloudfunctions_function.repo_webhooks : k => v.https_trigger_url
  }
}

# Monitoring outputs
output "monitoring_dashboard_id" {
  description = "ID of the Source Repositories monitoring dashboard"
  value       = var.enable_monitoring && var.create_dashboard ? google_monitoring_dashboard.source_repos_dashboard[0].id : null
}

output "monitoring_dashboard_url" {
  description = "URL to the Source Repositories monitoring dashboard"
  value = var.enable_monitoring && var.create_dashboard ? (
    "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.source_repos_dashboard[0].id}?project=${var.project_id}"
  ) : null
}

output "alert_policy_ids" {
  description = "IDs of created alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.source_repos_alerts : k => v.id
  }
}

output "alert_policy_names" {
  description = "Names of created alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.source_repos_alerts : k => v.display_name
  }
}

# Configuration metadata
output "configuration_metadata" {
  description = "Metadata about the Source Repositories configuration"
  value = {
    project_id                      = var.project_id
    repositories_count              = length(google_sourcerepo_repository.repositories)
    build_triggers_count            = length(google_cloudbuild_trigger.repo_triggers)
    pubsub_topics_count             = length(google_pubsub_topic.repo_event_topics)
    pubsub_subscriptions_count      = length(google_pubsub_subscription.repo_event_subscriptions)
    webhook_functions_count         = length(google_cloudfunctions_function.repo_webhooks)
    repository_secrets_count        = length(google_secret_manager_secret.repo_secrets)
    build_artifacts_storage_enabled = var.enable_build_artifacts_storage
    pubsub_notifications_enabled    = var.enable_pubsub_notifications
    cloud_build_integration_enabled = var.enable_cloud_build_integration
    secret_management_enabled       = var.enable_secret_management
    webhook_functions_enabled       = var.enable_webhook_functions
    monitoring_enabled              = var.enable_monitoring
    audit_logging_enabled           = var.enable_audit_logging
    total_alert_policies            = length(google_monitoring_alert_policy.source_repos_alerts)
  }
}

# Repository summary
output "repository_summary" {
  description = "Summary of repository configurations"
  value = {
    total_repositories = length(var.repositories)
    repository_names   = keys(var.repositories)
    repositories_with_triggers = [
      for trigger_name, trigger_config in var.cloud_build_triggers : trigger_config.repository_name
    ]
    repositories_with_iam = [
      for binding_name, binding_config in var.repository_iam_bindings : binding_config.repository_name
    ]
  }
}

# Build configuration summary
output "build_configuration_summary" {
  description = "Summary of build configurations"
  value = {
    cloud_build_enabled = var.enable_cloud_build_integration
    total_triggers      = length(var.cloud_build_triggers)
    trigger_types = {
      branch_triggers = length([
        for trigger in var.cloud_build_triggers : trigger if trigger.branch_name != null
      ])
      tag_triggers = length([
        for trigger in var.cloud_build_triggers : trigger if trigger.tag_name != null
      ])
      manual_triggers = length([
        for trigger in var.cloud_build_triggers : trigger if trigger.branch_name == null && trigger.tag_name == null
      ])
    }
    build_artifacts_storage = {
      enabled     = var.enable_build_artifacts_storage
      bucket_name = var.build_artifacts_bucket_name
      location    = var.storage_bucket_location
    }
  }
}

# Security configuration summary
output "security_configuration" {
  description = "Security configuration details"
  value = {
    secret_management = {
      enabled       = var.enable_secret_management
      secrets_count = length(var.repository_secrets)
    }
    branch_protection = {
      enabled     = var.enable_branch_protection
      rules_count = length(var.branch_protection_rules)
    }
    code_scanning = {
      enabled                 = var.enable_code_scanning
      repositories_configured = length(var.code_scanning_config)
    }
    dependency_scanning = {
      enabled            = var.enable_dependency_scanning
      auto_update        = var.dependency_scanning_config.auto_update_enabled
      severity_threshold = var.dependency_scanning_config.severity_threshold
    }
    container_scanning = {
      enabled          = var.enable_container_scanning
      scan_on_build    = var.container_scanning_config.scan_on_build
      fail_on_critical = var.container_scanning_config.fail_on_critical
    }
    compliance_monitoring = {
      enabled   = var.enable_compliance_monitoring
      standards = var.compliance_config.compliance_standards
    }
  }
}

# Integration status
output "integration_status" {
  description = "Status of integrations and features"
  value = {
    pubsub_integration = {
      enabled             = var.enable_pubsub_notifications
      topics_count        = length(var.pubsub_topics)
      subscriptions_count = length(var.pubsub_subscriptions)
    }
    webhook_integration = {
      enabled         = var.enable_webhook_functions
      functions_count = length(var.webhook_functions)
    }
    third_party_integrations = {
      integrations_count = length(var.integration_configs)
      enabled_integrations = [
        for name, config in var.integration_configs : name if config.enabled
      ]
    }
    notification_integration = {
      email_enabled   = var.notification_config.enable_email_notifications
      slack_enabled   = var.notification_config.enable_slack_notifications
      webhook_enabled = var.notification_config.enable_webhook_notifications
    }
  }
}

# Performance and monitoring summary
output "performance_monitoring_summary" {
  description = "Performance and monitoring configuration"
  value = {
    monitoring_enabled = var.enable_monitoring
    performance_monitoring = {
      enabled       = var.enable_performance_monitoring
      build_metrics = var.performance_monitoring_config.enable_build_metrics
      clone_metrics = var.performance_monitoring_config.enable_clone_metrics
      api_metrics   = var.performance_monitoring_config.enable_api_metrics
    }
    automated_testing = {
      enabled            = var.enable_automated_testing
      frameworks         = var.automated_testing_config.test_frameworks
      environments       = length(var.automated_testing_config.test_environments)
      coverage_threshold = var.automated_testing_config.coverage_threshold
    }
    backup_and_recovery = {
      enabled                = var.enable_backup_and_recovery
      backup_frequency       = var.backup_config.backup_frequency
      retention_days         = var.backup_config.backup_retention_days
      point_in_time_recovery = var.backup_config.enable_point_in_time_recovery
    }
  }
}

# Workflow and template summary
output "workflow_template_summary" {
  description = "Workflow and template configuration"
  value = {
    workflow_templates = {
      templates_count = length(var.workflow_templates)
      template_types = [
        for template in var.workflow_templates : template.template_type
      ]
    }
    repository_templates = {
      templates_count = length(var.repository_templates)
      template_names  = keys(var.repository_templates)
    }
    custom_build_environments = {
      environments_count = length(var.custom_build_environments)
      environment_names  = keys(var.custom_build_environments)
    }
  }
}

# Management URLs
output "management_urls" {
  description = "URLs for managing Source Repositories resources"
  value = {
    source_repos_console    = "https://source.cloud.google.com/repos?project=${var.project_id}"
    cloud_build_console     = var.enable_cloud_build_integration ? "https://console.cloud.google.com/cloud-build?project=${var.project_id}" : null
    storage_console         = var.enable_build_artifacts_storage ? "https://console.cloud.google.com/storage/browser?project=${var.project_id}" : null
    pubsub_console          = var.enable_pubsub_notifications ? "https://console.cloud.google.com/cloudpubsub?project=${var.project_id}" : null
    secret_manager_console  = var.enable_secret_management ? "https://console.cloud.google.com/security/secret-manager?project=${var.project_id}" : null
    cloud_functions_console = var.enable_webhook_functions ? "https://console.cloud.google.com/functions?project=${var.project_id}" : null
    monitoring_console      = var.enable_monitoring ? "https://console.cloud.google.com/monitoring?project=${var.project_id}" : null
    logs_console            = "https://console.cloud.google.com/logs/query?project=${var.project_id}"
  }
}

# Resource identifiers for integration
output "resource_identifiers" {
  description = "Resource identifiers for integration with other modules"
  value = {
    repository_resources = {
      for k, v in google_sourcerepo_repository.repositories : k => v.name
    }
    build_trigger_resources = {
      for k, v in google_cloudbuild_trigger.repo_triggers : k => v.id
    }
    pubsub_topic_resources = {
      for k, v in google_pubsub_topic.repo_event_topics : k => v.name
    }
    storage_bucket_resource  = var.enable_build_artifacts_storage ? google_storage_bucket.build_artifacts_bucket[0].name : null
    service_account_resource = var.create_service_account ? google_service_account.source_repos_sa[0].email : null
    secret_resources = {
      for k, v in google_secret_manager_secret.repo_secrets : k => v.name
    }
    function_resources = {
      for k, v in google_cloudfunctions_function.repo_webhooks : k => v.name
    }
  }
}