# Cloud Functions Module Outputs

# Function Information
output "function_name" {
  description = "Name of the Cloud Function"
  value       = local.function_name
}

output "function_id" {
  description = "ID of the Cloud Function"
  value = var.generation == 1 && var.deploy_function ? (
    try(google_cloudfunctions_function.function_v1[0].id, null)
  ) : var.generation == 2 && var.deploy_function ? (
    try(google_cloudfunctions2_function.function_v2[0].id, null)
  ) : null
}

output "function_region" {
  description = "Region of the Cloud Function"
  value       = var.region
}

output "function_project" {
  description = "Project of the Cloud Function"
  value       = var.project_id
}

output "generation" {
  description = "Generation of the Cloud Function"
  value       = var.generation
}

# Trigger URLs
output "https_trigger_url" {
  description = "HTTPS trigger URL for the function"
  value = var.generation == 1 && var.deploy_function && var.trigger_http ? (
    try(google_cloudfunctions_function.function_v1[0].https_trigger_url, null)
  ) : var.generation == 2 && var.deploy_function ? (
    try(google_cloudfunctions2_function.function_v2[0].service_config[0].uri, null)
  ) : null
}

output "trigger_url" {
  description = "Trigger URL for the function (alias for https_trigger_url)"
  value = var.generation == 1 && var.deploy_function && var.trigger_http ? (
    try(google_cloudfunctions_function.function_v1[0].https_trigger_url, null)
  ) : var.generation == 2 && var.deploy_function ? (
    try(google_cloudfunctions2_function.function_v2[0].service_config[0].uri, null)
  ) : null
}

# Service Configuration (Gen 2)
output "service_name" {
  description = "Cloud Run service name (Gen 2 only)"
  value = var.generation == 2 && var.deploy_function ? (
    try(google_cloudfunctions2_function.function_v2[0].name, null)
  ) : null
}

output "service_config" {
  description = "Service configuration (Gen 2 only)"
  value = var.generation == 2 && var.deploy_function ? {
    uri                              = try(google_cloudfunctions2_function.function_v2[0].service_config[0].uri, null)
    service                          = try(google_cloudfunctions2_function.function_v2[0].service_config[0].service, null)
    service_account_email           = try(google_cloudfunctions2_function.function_v2[0].service_config[0].service_account_email, null)
    timeout_seconds                 = try(google_cloudfunctions2_function.function_v2[0].service_config[0].timeout_seconds, null)
    available_memory                = try(google_cloudfunctions2_function.function_v2[0].service_config[0].available_memory, null)
    available_cpu                   = try(google_cloudfunctions2_function.function_v2[0].service_config[0].available_cpu, null)
    max_instance_count              = try(google_cloudfunctions2_function.function_v2[0].service_config[0].max_instance_count, null)
    min_instance_count              = try(google_cloudfunctions2_function.function_v2[0].service_config[0].min_instance_count, null)
    max_instance_request_concurrency = try(google_cloudfunctions2_function.function_v2[0].service_config[0].max_instance_request_concurrency, null)
  } : null
}

# Build Configuration
output "build_config" {
  description = "Build configuration"
  value = var.generation == 2 && var.deploy_function ? {
    runtime        = try(google_cloudfunctions2_function.function_v2[0].build_config[0].runtime, null)
    entry_point    = try(google_cloudfunctions2_function.function_v2[0].build_config[0].entry_point, null)
    build_id       = try(google_cloudfunctions2_function.function_v2[0].build_config[0].build, null)
    worker_pool    = try(google_cloudfunctions2_function.function_v2[0].build_config[0].worker_pool, null)
    docker_repository = try(google_cloudfunctions2_function.function_v2[0].build_config[0].docker_repository, null)
  } : null
}

# State and Status
output "state" {
  description = "State of the Cloud Function"
  value = var.generation == 2 && var.deploy_function ? (
    try(google_cloudfunctions2_function.function_v2[0].state, null)
  ) : null
}

output "update_time" {
  description = "Last update time of the function"
  value = var.generation == 2 && var.deploy_function ? (
    try(google_cloudfunctions2_function.function_v2[0].update_time, null)
  ) : null
}

# Source Configuration
output "source_bucket" {
  description = "Source bucket name"
  value       = local.source_archive_bucket
}

output "source_object" {
  description = "Source object name"
  value       = local.source_archive_object
}

output "source_bucket_url" {
  description = "Source bucket URL"
  value = var.create_source_bucket ? (
    try(google_storage_bucket.source_bucket[0].url, null)
  ) : null
}

# Service Account
output "service_account_email" {
  description = "Service account email"
  value       = local.service_account_email
}

output "service_account_name" {
  description = "Service account name"
  value = var.create_service_account ? (
    try(google_service_account.function_sa[0].name, null)
  ) : null
}

output "service_account_key" {
  description = "Service account key (base64 encoded)"
  value = var.create_service_account && var.create_service_account_key ? (
    try(google_service_account_key.function_sa_key[0].private_key, null)
  ) : null
  sensitive = true
}

# VPC Connector
output "vpc_connector_name" {
  description = "VPC connector name"
  value       = local.vpc_connector_name
}

output "vpc_connector_id" {
  description = "VPC connector ID"
  value = var.create_vpc_connector ? (
    try(google_vpc_access_connector.connector[0].id, null)
  ) : null
}

# Event Trigger
output "event_trigger" {
  description = "Event trigger configuration"
  value = var.generation == 1 && var.deploy_function && local.event_trigger != null ? {
    event_type = local.event_trigger.event_type
    resource   = local.event_trigger.resource
  } : var.generation == 2 && var.deploy_function && local.event_trigger_v2 != null ? {
    event_type    = local.event_trigger_v2.event_type
    pubsub_topic  = local.event_trigger_v2.pubsub_topic
    trigger_region = local.event_trigger_v2.trigger_region
  } : null
}

# Scheduler Job
output "scheduler_job_name" {
  description = "Cloud Scheduler job name"
  value = var.create_scheduler_job ? (
    try(google_cloud_scheduler_job.function_scheduler[0].name, null)
  ) : null
}

output "scheduler_job_id" {
  description = "Cloud Scheduler job ID"
  value = var.create_scheduler_job ? (
    try(google_cloud_scheduler_job.function_scheduler[0].id, null)
  ) : null
}

output "scheduler_schedule" {
  description = "Cloud Scheduler cron schedule"
  value = var.create_scheduler_job ? (
    try(google_cloud_scheduler_job.function_scheduler[0].schedule, null)
  ) : null
}

# Monitoring
output "monitoring_dashboard_id" {
  description = "Monitoring dashboard ID"
  value = var.create_monitoring_dashboard ? (
    try(google_monitoring_dashboard.function_dashboard[0].id, null)
  ) : null
}

output "monitoring_alert_policies" {
  description = "Monitoring alert policy IDs"
  value = {
    for name, policy in google_monitoring_alert_policy.function_alerts :
    name => {
      id           = policy.id
      name         = policy.name
      display_name = policy.display_name
      enabled      = policy.enabled
    }
  }
}

# Budget
output "budget_name" {
  description = "Budget name"
  value = var.create_budget_alert ? (
    try(google_billing_budget.function_budget[0].display_name, null)
  ) : null
}

# Labels
output "labels" {
  description = "Labels applied to the function"
  value       = local.labels
}

# Console URLs
output "console_urls" {
  description = "Google Cloud Console URLs"
  value = {
    function_details = var.deploy_function ? (
      "https://console.cloud.google.com/functions/details/${var.region}/${local.function_name}?project=${var.project_id}"
    ) : null

    function_logs = var.deploy_function ? (
      "https://console.cloud.google.com/logs/query;query=resource.type%3D%22cloud_function%22%20resource.labels.function_name%3D%22${local.function_name}%22?project=${var.project_id}"
    ) : null

    function_metrics = var.deploy_function ? (
      "https://console.cloud.google.com/monitoring/metrics-explorer?project=${var.project_id}&pageState=%7B%22xyChart%22:%7B%22dataSets%22:%5B%7B%22timeSeriesFilter%22:%7B%22filter%22:%22metric.type%3D%5C%22cloudfunctions.googleapis.com%2Ffunction%2Fexecution_count%5C%22%20resource.type%3D%5C%22cloud_function%5C%22%20resource.label.function_name%3D%5C%22${local.function_name}%5C%22%22%7D%7D%5D%7D%7D"
    ) : null

    source_bucket = var.create_source_bucket ? (
      "https://console.cloud.google.com/storage/browser/${local.source_archive_bucket}?project=${var.project_id}"
    ) : null

    scheduler_job = var.create_scheduler_job ? (
      "https://console.cloud.google.com/cloudscheduler/jobs/${var.region}/${try(google_cloud_scheduler_job.function_scheduler[0].name, "")}?project=${var.project_id}"
    ) : null

    monitoring_dashboard = var.create_monitoring_dashboard ? (
      "https://console.cloud.google.com/monitoring/dashboards/custom/${try(google_monitoring_dashboard.function_dashboard[0].id, "")}?project=${var.project_id}"
    ) : null
  }
}

# gcloud Commands
output "gcloud_commands" {
  description = "Useful gcloud commands"
  value = {
    describe = var.generation == 1 && var.deploy_function ? (
      "gcloud functions describe ${local.function_name} --region=${var.region} --project=${var.project_id}"
    ) : var.generation == 2 && var.deploy_function ? (
      "gcloud functions describe ${local.function_name} --region=${var.region} --gen2 --project=${var.project_id}"
    ) : null

    call = var.generation == 1 && var.deploy_function && var.trigger_http ? (
      "gcloud functions call ${local.function_name} --region=${var.region} --project=${var.project_id}"
    ) : var.generation == 2 && var.deploy_function ? (
      "gcloud functions call ${local.function_name} --region=${var.region} --gen2 --project=${var.project_id}"
    ) : null

    logs = var.deploy_function ? (
      "gcloud functions logs read ${local.function_name} --region=${var.region} --project=${var.project_id}"
    ) : null

    delete = var.generation == 1 && var.deploy_function ? (
      "gcloud functions delete ${local.function_name} --region=${var.region} --project=${var.project_id}"
    ) : var.generation == 2 && var.deploy_function ? (
      "gcloud functions delete ${local.function_name} --region=${var.region} --gen2 --project=${var.project_id}"
    ) : null

    deploy_from_source = var.generation == 1 ? (
      "gcloud functions deploy ${local.function_name} --runtime=${var.runtime} --trigger-http --entry-point=${var.entry_point} --region=${var.region} --project=${var.project_id}"
    ) : (
      "gcloud functions deploy ${local.function_name} --runtime=${var.runtime} --trigger-http --entry-point=${var.entry_point} --region=${var.region} --gen2 --project=${var.project_id}"
    )

    test_scheduler = var.create_scheduler_job ? (
      "gcloud scheduler jobs run ${try(google_cloud_scheduler_job.function_scheduler[0].name, "")} --location=${var.region} --project=${var.project_id}"
    ) : null
  }
}

# curl Commands
output "curl_commands" {
  description = "Example curl commands"
  value = var.deploy_function && var.trigger_http ? {
    basic = var.generation == 1 ? (
      "curl -X POST ${try(google_cloudfunctions_function.function_v1[0].https_trigger_url, "")}"
    ) : (
      "curl -X POST ${try(google_cloudfunctions2_function.function_v2[0].service_config[0].uri, "")}"
    )

    with_data = var.generation == 1 ? (
      "curl -X POST ${try(google_cloudfunctions_function.function_v1[0].https_trigger_url, "")} -H 'Content-Type: application/json' -d '{\"key\":\"value\"}'"
    ) : (
      "curl -X POST ${try(google_cloudfunctions2_function.function_v2[0].service_config[0].uri, "")} -H 'Content-Type: application/json' -d '{\"key\":\"value\"}'"
    )

    with_auth = var.generation == 1 ? (
      "curl -X POST ${try(google_cloudfunctions_function.function_v1[0].https_trigger_url, "")} -H \"Authorization: Bearer $(gcloud auth print-identity-token)\""
    ) : (
      "curl -X POST ${try(google_cloudfunctions2_function.function_v2[0].service_config[0].uri, "")} -H \"Authorization: Bearer $(gcloud auth print-identity-token)\""
    )
  } : null
}

# Import Commands
output "import_commands" {
  description = "Terraform import commands"
  value = {
    function = var.generation == 1 && var.deploy_function ? (
      "terraform import google_cloudfunctions_function.function_v1 projects/${var.project_id}/locations/${var.region}/functions/${local.function_name}"
    ) : var.generation == 2 && var.deploy_function ? (
      "terraform import google_cloudfunctions2_function.function_v2 projects/${var.project_id}/locations/${var.region}/functions/${local.function_name}"
    ) : null

    service_account = var.create_service_account ? (
      "terraform import google_service_account.function_sa projects/${var.project_id}/serviceAccounts/${try(google_service_account.function_sa[0].email, "")}"
    ) : null

    source_bucket = var.create_source_bucket ? (
      "terraform import google_storage_bucket.source_bucket ${var.project_id}/${local.source_archive_bucket}"
    ) : null

    scheduler_job = var.create_scheduler_job ? (
      "terraform import google_cloud_scheduler_job.function_scheduler projects/${var.project_id}/locations/${var.region}/jobs/${try(google_cloud_scheduler_job.function_scheduler[0].name, "")}"
    ) : null
  }
}