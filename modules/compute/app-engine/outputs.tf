# App Engine Module Outputs

# Application Information
output "app_id" {
  description = "App Engine application ID"
  value       = var.create_application ? try(google_app_engine_application.app[0].app_id, null) : var.app_id
}

output "app_name" {
  description = "App Engine application name"
  value       = var.create_application ? try(google_app_engine_application.app[0].name, null) : null
}

output "app_location" {
  description = "App Engine application location"
  value       = var.create_application ? try(google_app_engine_application.app[0].location_id, null) : local.app_location
}

output "app_default_hostname" {
  description = "Default hostname"
  value       = var.create_application ? try(google_app_engine_application.app[0].default_hostname, null) : null
}

output "app_default_bucket" {
  description = "Default GCS bucket"
  value       = var.create_application ? try(google_app_engine_application.app[0].default_bucket, null) : null
}

output "app_gcr_domain" {
  description = "GCR domain"
  value       = var.create_application ? try(google_app_engine_application.app[0].gcr_domain, null) : null
}

output "app_code_bucket" {
  description = "Code bucket"
  value       = var.create_application ? try(google_app_engine_application.app[0].code_bucket, null) : null
}

output "app_serving_status" {
  description = "Serving status"
  value       = var.create_application ? try(google_app_engine_application.app[0].serving_status, null) : var.serving_status
}

# Service Version Information (Standard)
output "standard_version_id" {
  description = "Standard environment version ID"
  value       = var.environment_type == "standard" && var.deploy_version ? try(google_app_engine_standard_app_version.standard[0].version_id, null) : null
}

output "standard_version_name" {
  description = "Standard environment version name"
  value       = var.environment_type == "standard" && var.deploy_version ? try(google_app_engine_standard_app_version.standard[0].name, null) : null
}

output "standard_version_url" {
  description = "Standard environment version URL"
  value       = var.environment_type == "standard" && var.deploy_version ? try("https://${google_app_engine_standard_app_version.standard[0].version_id}-dot-${local.service_name}-dot-${var.project_id}.appspot.com", null) : null
}

# Service Version Information (Flexible)
output "flexible_version_id" {
  description = "Flexible environment version ID"
  value       = var.environment_type == "flexible" && var.deploy_version ? try(google_app_engine_flexible_app_version.flexible[0].version_id, null) : null
}

output "flexible_version_name" {
  description = "Flexible environment version name"
  value       = var.environment_type == "flexible" && var.deploy_version ? try(google_app_engine_flexible_app_version.flexible[0].name, null) : null
}

output "flexible_version_url" {
  description = "Flexible environment version URL"
  value       = var.environment_type == "flexible" && var.deploy_version ? try("https://${google_app_engine_flexible_app_version.flexible[0].version_id}-dot-${local.service_name}-dot-${var.project_id}.appspot.com", null) : null
}

# Service Information
output "service_name" {
  description = "Service name"
  value       = local.service_name
}

output "service_url" {
  description = "Service URL"
  value       = var.deploy_version ? "https://${local.service_name}-dot-${var.project_id}.appspot.com" : null
}

output "default_service_url" {
  description = "Default service URL"
  value       = "https://${var.project_id}.appspot.com"
}

# Runtime Information
output "runtime" {
  description = "Runtime"
  value       = var.runtime
}

output "environment_type" {
  description = "Environment type"
  value       = var.environment_type
}

output "scaling_type" {
  description = "Scaling type"
  value       = var.scaling_type
}

# Domain Mappings
output "domain_mappings" {
  description = "Domain mappings"
  value = {
    for k, v in google_app_engine_domain_mapping.domain :
    k => {
      id               = v.id
      domain_name      = v.domain_name
      resource_records = try(v.resource_records, [])
    }
  }
}

# Firewall Rules
output "firewall_rules" {
  description = "Firewall rules"
  value = {
    for k, v in google_app_engine_firewall_rule.rules :
    k => {
      id           = v.id
      priority     = v.priority
      action       = v.action
      source_range = v.source_range
    }
  }
}

# Console URLs
output "console_urls" {
  description = "Cloud Console URLs"
  value = {
    app_engine_dashboard = "https://console.cloud.google.com/appengine?project=${var.project_id}"

    services = "https://console.cloud.google.com/appengine/services?project=${var.project_id}"

    versions = "https://console.cloud.google.com/appengine/versions?project=${var.project_id}&serviceId=${local.service_name}"

    instances = "https://console.cloud.google.com/appengine/instances?project=${var.project_id}&serviceId=${local.service_name}"

    logs = "https://console.cloud.google.com/logs/query;query=resource.type%3D%22gae_app%22?project=${var.project_id}"

    monitoring = "https://console.cloud.google.com/monitoring/dashboards/resourceList/gae_app?project=${var.project_id}"

    settings = "https://console.cloud.google.com/appengine/settings?project=${var.project_id}"

    firewall = "https://console.cloud.google.com/appengine/firewall?project=${var.project_id}"

    quotas = "https://console.cloud.google.com/appengine/quotadetails?project=${var.project_id}"

    task_queues = "https://console.cloud.google.com/appengine/taskqueues?project=${var.project_id}"

    cron_jobs = "https://console.cloud.google.com/appengine/cronjobs?project=${var.project_id}"
  }
}

# gcloud Commands
output "gcloud_commands" {
  description = "Useful gcloud commands"
  value = {
    deploy = "gcloud app deploy --project=${var.project_id}"

    browse = "gcloud app browse --project=${var.project_id}"

    describe = "gcloud app describe --project=${var.project_id}"

    services_list = "gcloud app services list --project=${var.project_id}"

    versions_list = "gcloud app versions list --project=${var.project_id}"

    logs_tail = "gcloud app logs tail --project=${var.project_id} --service=${local.service_name}"

    logs_read = "gcloud app logs read --project=${var.project_id} --service=${local.service_name}"

    instances_list = "gcloud app instances list --project=${var.project_id} --service=${local.service_name}"

    traffic_split = var.deploy_version ? "gcloud app services set-traffic ${local.service_name} --splits=${var.version_id != null ? var.version_id : "latest"}=1 --project=${var.project_id}" : null

    version_migrate = var.deploy_version ? "gcloud app versions migrate ${var.version_id != null ? var.version_id : "latest"} --service=${local.service_name} --project=${var.project_id}" : null

    version_start = var.deploy_version ? "gcloud app versions start ${var.version_id != null ? var.version_id : "latest"} --service=${local.service_name} --project=${var.project_id}" : null

    version_stop = var.deploy_version ? "gcloud app versions stop ${var.version_id != null ? var.version_id : "latest"} --service=${local.service_name} --project=${var.project_id}" : null

    version_delete = var.deploy_version ? "gcloud app versions delete ${var.version_id != null ? var.version_id : "latest"} --service=${local.service_name} --project=${var.project_id}" : null

    firewall_update = "gcloud app firewall-rules update PRIORITY --action=ACTION --source-range=RANGE --project=${var.project_id}"
  }
}

# Labels
output "labels" {
  description = "Labels applied"
  value       = local.labels
}