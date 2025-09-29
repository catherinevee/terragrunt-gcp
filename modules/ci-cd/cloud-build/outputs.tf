# Cloud Build Module Outputs

# Build Trigger Outputs
output "build_trigger_ids" {
  description = "The identifiers for Cloud Build triggers"
  value = {
    for k, v in google_cloudbuild_trigger.build_triggers : k => v.id
  }
}

output "build_trigger_names" {
  description = "The names of Cloud Build triggers"
  value = {
    for k, v in google_cloudbuild_trigger.build_triggers : k => v.name
  }
}

output "build_trigger_trigger_ids" {
  description = "The unique trigger IDs for Cloud Build triggers"
  value = {
    for k, v in google_cloudbuild_trigger.build_triggers : k => v.trigger_id
  }
}

output "build_trigger_create_times" {
  description = "The creation times of Cloud Build triggers"
  value = {
    for k, v in google_cloudbuild_trigger.build_triggers : k => v.create_time
  }
}

output "build_trigger_webhook_configs" {
  description = "Webhook configurations for Cloud Build triggers"
  value = {
    for k, v in google_cloudbuild_trigger.build_triggers : k => v.webhook_config
    if v.webhook_config != null
  }
}

# Worker Pool Outputs
output "worker_pool_ids" {
  description = "The identifiers for Cloud Build worker pools"
  value = {
    for k, v in google_cloudbuild_worker_pool.worker_pools : k => v.id
  }
}

output "worker_pool_names" {
  description = "The names of Cloud Build worker pools"
  value = {
    for k, v in google_cloudbuild_worker_pool.worker_pools : k => v.name
  }
}

output "worker_pool_states" {
  description = "The states of Cloud Build worker pools"
  value = {
    for k, v in google_cloudbuild_worker_pool.worker_pools : k => v.state
  }
}

output "worker_pool_create_times" {
  description = "The creation times of Cloud Build worker pools"
  value = {
    for k, v in google_cloudbuild_worker_pool.worker_pools : k => v.create_time
  }
}

output "worker_pool_update_times" {
  description = "The last update times of Cloud Build worker pools"
  value = {
    for k, v in google_cloudbuild_worker_pool.worker_pools : k => v.update_time
  }
}

output "worker_pool_delete_times" {
  description = "The scheduled deletion times of Cloud Build worker pools"
  value = {
    for k, v in google_cloudbuild_worker_pool.worker_pools : k => v.delete_time
    if v.delete_time != null
  }
}

output "worker_pool_etags" {
  description = "The etags of Cloud Build worker pools"
  value = {
    for k, v in google_cloudbuild_worker_pool.worker_pools : k => v.etag
  }
}

output "worker_pool_uids" {
  description = "The unique identifiers of Cloud Build worker pools"
  value = {
    for k, v in google_cloudbuild_worker_pool.worker_pools : k => v.uid
  }
}

# Source Repository Outputs
output "source_repository_urls" {
  description = "The URLs of Cloud Source repositories"
  value = {
    for k, v in google_sourcerepo_repository.repositories : k => v.url
  }
}

output "source_repository_names" {
  description = "The names of Cloud Source repositories"
  value = {
    for k, v in google_sourcerepo_repository.repositories : k => v.name
  }
}

output "source_repository_sizes" {
  description = "The sizes of Cloud Source repositories in bytes"
  value = {
    for k, v in google_sourcerepo_repository.repositories : k => v.size
  }
}

# Artifact Registry Outputs
output "artifact_registry_ids" {
  description = "The identifiers for Artifact Registry repositories"
  value = {
    for k, v in google_artifact_registry_repository.registries : k => v.id
  }
}

output "artifact_registry_names" {
  description = "The names of Artifact Registry repositories"
  value = {
    for k, v in google_artifact_registry_repository.registries : k => v.name
  }
}

output "artifact_registry_create_times" {
  description = "The creation times of Artifact Registry repositories"
  value = {
    for k, v in google_artifact_registry_repository.registries : k => v.create_time
  }
}

output "artifact_registry_update_times" {
  description = "The last update times of Artifact Registry repositories"
  value = {
    for k, v in google_artifact_registry_repository.registries : k => v.update_time
  }
}

output "artifact_registry_formats" {
  description = "The formats of Artifact Registry repositories"
  value = {
    for k, v in google_artifact_registry_repository.registries : k => v.format
  }
}

output "artifact_registry_modes" {
  description = "The modes of Artifact Registry repositories"
  value = {
    for k, v in google_artifact_registry_repository.registries : k => v.mode
  }
}

output "artifact_registry_size_bytes" {
  description = "The sizes of Artifact Registry repositories in bytes"
  value = {
    for k, v in google_artifact_registry_repository.registries : k => v.size_bytes
  }
}

output "artifact_registry_satisfies_pzs" {
  description = "Whether Artifact Registry repositories satisfy PZS"
  value = {
    for k, v in google_artifact_registry_repository.registries : k => v.satisfies_pzs
  }
}

# Service Account Outputs
output "service_account_email" {
  description = "The email of the created service account"
  value       = var.create_service_account ? google_service_account.cloud_build[0].email : null
}

output "service_account_id" {
  description = "The unique id of the service account"
  value       = var.create_service_account ? google_service_account.cloud_build[0].unique_id : null
}

output "service_account_name" {
  description = "The fully-qualified name of the service account"
  value       = var.create_service_account ? google_service_account.cloud_build[0].name : null
}

output "service_account_member" {
  description = "The IAM member format for the service account"
  value       = var.create_service_account ? "serviceAccount:${google_service_account.cloud_build[0].email}" : null
}

# Monitoring Outputs
output "monitoring_alert_policy_ids" {
  description = "IDs of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.build_alerts : k => v.id
  }
}

output "monitoring_alert_policy_names" {
  description = "Names of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.build_alerts : k => v.name
  }
}

output "monitoring_dashboard_id" {
  description = "ID of the monitoring dashboard"
  value       = var.create_monitoring_dashboard ? google_monitoring_dashboard.build_dashboard[0].id : null
}

# Budget Outputs
output "budget_id" {
  description = "ID of the budget alert"
  value       = var.create_budget_alert ? google_billing_budget.build_budget[0].id : null
}

output "budget_name" {
  description = "Name of the budget alert"
  value       = var.create_budget_alert ? google_billing_budget.build_budget[0].name : null
}

# Build Configuration Summary
output "build_configuration_summary" {
  description = "Summary of Cloud Build configuration"
  value = {
    total_triggers     = length(local.build_triggers)
    total_worker_pools = length(local.worker_pools)
    total_repositories = length(var.source_repositories)
    total_registries   = length(local.artifact_registries)

    triggers_by_type = {
      github  = length([for k, v in local.build_triggers : k if v.github != null])
      repo    = length([for k, v in local.build_triggers : k if v.repository_event_config != null])
      webhook = length([for k, v in local.build_triggers : k if v.webhook_config != null])
      pubsub  = length([for k, v in local.build_triggers : k if v.pubsub_config != null])
      manual  = length([for k, v in local.build_triggers : k if v.github == null && v.repository_event_config == null && v.webhook_config == null && v.pubsub_config == null])
    }

    enabled_triggers  = length([for k, v in local.build_triggers : k if v.disabled != true])
    disabled_triggers = length([for k, v in local.build_triggers : k if v.disabled == true])
  }
}

# Registry Configuration Summary
output "registry_configuration_summary" {
  description = "Summary of Artifact Registry configuration"
  value = {
    registries_by_format = {
      docker  = length([for k, v in local.artifact_registries : k if v.format == "DOCKER"])
      maven   = length([for k, v in local.artifact_registries : k if v.format == "MAVEN"])
      npm     = length([for k, v in local.artifact_registries : k if v.format == "NPM"])
      python  = length([for k, v in local.artifact_registries : k if v.format == "PYTHON"])
      apt     = length([for k, v in local.artifact_registries : k if v.format == "APT"])
      yum     = length([for k, v in local.artifact_registries : k if v.format == "YUM"])
      helm    = length([for k, v in local.artifact_registries : k if v.format == "HELM"])
      go      = length([for k, v in local.artifact_registries : k if v.format == "GO"])
      generic = length([for k, v in local.artifact_registries : k if v.format == "GENERIC"])
    }

    registries_by_mode = {
      standard = length([for k, v in local.artifact_registries : k if v.mode == "STANDARD_REPOSITORY" || v.mode == null])
      virtual  = length([for k, v in local.artifact_registries : k if v.mode == "VIRTUAL_REPOSITORY"])
      remote   = length([for k, v in local.artifact_registries : k if v.mode == "REMOTE_REPOSITORY"])
    }

    encrypted_registries = length([for k, v in local.artifact_registries : k if v.kms_key_name != null])
  }
}

# Worker Pool Configuration Summary
output "worker_pool_configuration_summary" {
  description = "Summary of worker pool configuration"
  value = {
    pools_by_location = {
      for location in distinct([for v in local.worker_pools : v.location != null ? v.location : var.region]) :
      location => length([
        for k, v in local.worker_pools : k
        if(v.location != null ? v.location : var.region) == location
      ])
    }

    pools_with_private_network = length([
      for k, v in local.worker_pools : k
      if v.network_config != null && v.network_config.peered_network != null
    ])

    pools_with_no_external_ip = length([
      for k, v in local.worker_pools : k
      if v.worker_config != null && v.worker_config.no_external_ip == true
    ])
  }
}

# Security Configuration Summary
output "security_configuration_summary" {
  description = "Summary of security configuration"
  value = {
    service_account_created = var.create_service_account
    service_account_roles   = var.create_service_account ? var.service_account_roles : []

    triggers_with_custom_sa = length([
      for k, v in local.build_triggers : k
      if v.service_account != null
    ])

    triggers_with_approval = length([
      for k, v in local.build_triggers : k
      if v.approval_config != null && v.approval_config.approval_required == true
    ])

    encrypted_repositories = length([
      for k, v in local.artifact_registries : k
      if v.kms_key_name != null
    ])
  }
}

# Monitoring Configuration Summary
output "monitoring_configuration_summary" {
  description = "Summary of monitoring configuration"
  value = {
    alerts_enabled    = var.create_monitoring_alerts
    dashboard_enabled = var.create_monitoring_dashboard
    budget_enabled    = var.create_budget_alert

    alert_policies_count = var.create_monitoring_alerts ? length(var.monitoring_alerts) : 0
    budget_amount        = var.create_budget_alert ? var.budget_amount : null
    budget_currency      = var.create_budget_alert ? var.budget_currency : null
  }
}

# Build Steps Summary
output "build_steps_summary" {
  description = "Summary of build steps across all triggers"
  value = {
    for k, v in local.build_triggers : k => {
      total_steps = v.build != null && v.build.steps != null ? length(v.build.steps) : 0
      steps_with_timeout = v.build != null && v.build.steps != null ? length([
        for step in v.build.steps : step
        if step.timeout != null
      ]) : 0
      steps_with_script = v.build != null && v.build.steps != null ? length([
        for step in v.build.steps : step
        if step.script != null
      ]) : 0
      steps_with_volumes = v.build != null && v.build.steps != null ? length([
        for step in v.build.steps : step
        if step.volumes != null && length(step.volumes) > 0
      ]) : 0
    }
    if v.build != null
  }
}

# Connection Information
output "connection_info" {
  description = "Connection information for Cloud Build resources"
  value = {
    project_id = var.project_id
    region     = var.region

    triggers = {
      for k, v in google_cloudbuild_trigger.build_triggers : k => {
        id         = v.id
        name       = v.name
        trigger_id = v.trigger_id
        location   = v.location
      }
    }

    worker_pools = {
      for k, v in google_cloudbuild_worker_pool.worker_pools : k => {
        id       = v.id
        name     = v.name
        location = v.location
        state    = v.state
      }
    }

    repositories = {
      for k, v in google_sourcerepo_repository.repositories : k => {
        name = v.name
        url  = v.url
      }
    }

    registries = {
      for k, v in google_artifact_registry_repository.registries : k => {
        id       = v.id
        name     = v.name
        location = v.location
        format   = v.format
      }
    }
  }
  sensitive = false
}

# Module Metadata
output "module_configuration" {
  description = "Module configuration summary"
  value = {
    project_id              = var.project_id
    region                  = var.region
    environment             = local.environment
    name_prefix             = local.name_prefix
    service_account_created = var.create_service_account
    monitoring_enabled      = var.create_monitoring_alerts
    dashboard_created       = var.create_monitoring_dashboard
    budget_alerts_enabled   = var.create_budget_alert
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
    build_triggers      = length(var.build_triggers)
    worker_pools        = length(var.worker_pools)
    source_repositories = length(var.source_repositories)
    artifact_registries = length(var.artifact_registries)
    service_accounts    = var.create_service_account ? 1 : 0
    alert_policies      = var.create_monitoring_alerts ? length(var.monitoring_alerts) : 0
    dashboards          = var.create_monitoring_dashboard ? 1 : 0
    budgets             = var.create_budget_alert ? 1 : 0
  }
}