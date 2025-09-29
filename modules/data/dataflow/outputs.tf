# Dataflow Module Outputs

# Job Information
output "job_name" {
  description = "Name of the Dataflow job"
  value = var.template_type == "classic" && var.deploy_job ? (
    try(google_dataflow_job.classic_job[0].name, null)
  ) : var.template_type == "flex" && var.deploy_job ? (
    try(google_dataflow_flex_template_job.flex_job[0].name, null)
  ) : var.template_type == "sql" && var.deploy_job ? (
    try(google_dataflow_job.sql_job[0].name, null)
  ) : var.template_type == "python" && var.deploy_job ? (
    local.job_name
  ) : null
}

output "job_id" {
  description = "ID of the Dataflow job"
  value = var.template_type == "classic" && var.deploy_job ? (
    try(google_dataflow_job.classic_job[0].id, null)
  ) : var.template_type == "flex" && var.deploy_job ? (
    try(google_dataflow_flex_template_job.flex_job[0].id, null)
  ) : var.template_type == "sql" && var.deploy_job ? (
    try(google_dataflow_job.sql_job[0].id, null)
  ) : null
}

output "job_state" {
  description = "Current state of the Dataflow job"
  value = var.template_type == "classic" && var.deploy_job ? (
    try(google_dataflow_job.classic_job[0].state, null)
  ) : var.template_type == "flex" && var.deploy_job ? (
    try(google_dataflow_flex_template_job.flex_job[0].state, null)
  ) : var.template_type == "sql" && var.deploy_job ? (
    try(google_dataflow_job.sql_job[0].state, null)
  ) : null
}

output "job_type" {
  description = "Type of the Dataflow job"
  value = var.template_type == "classic" && var.deploy_job ? (
    try(google_dataflow_job.classic_job[0].type, null)
  ) : var.template_type == "flex" && var.deploy_job ? (
    try(google_dataflow_flex_template_job.flex_job[0].type, null)
  ) : var.template_type == "sql" && var.deploy_job ? (
    try(google_dataflow_job.sql_job[0].type, null)
  ) : null
}

output "template_type" {
  description = "Type of template used"
  value       = var.template_type
}

output "region" {
  description = "Region where the job is running"
  value       = var.region
}

output "project_id" {
  description = "Project ID where the job is running"
  value       = var.project_id
}

# Classic Job Specific Outputs
output "classic_job_details" {
  description = "Details of classic Dataflow job"
  value = var.template_type == "classic" && var.deploy_job ? {
    id                = try(google_dataflow_job.classic_job[0].id, null)
    name              = try(google_dataflow_job.classic_job[0].name, null)
    state             = try(google_dataflow_job.classic_job[0].state, null)
    type              = try(google_dataflow_job.classic_job[0].type, null)
    template_gcs_path = try(google_dataflow_job.classic_job[0].template_gcs_path, null)
    temp_gcs_location = try(google_dataflow_job.classic_job[0].temp_gcs_location, null)
    max_workers       = try(google_dataflow_job.classic_job[0].max_workers, null)
    on_delete         = try(google_dataflow_job.classic_job[0].on_delete, null)
    labels            = try(google_dataflow_job.classic_job[0].labels, null)
  } : null
}

# Flex Template Job Specific Outputs
output "flex_job_details" {
  description = "Details of flex template Dataflow job"
  value = var.template_type == "flex" && var.deploy_job ? {
    id                       = try(google_dataflow_flex_template_job.flex_job[0].id, null)
    name                     = try(google_dataflow_flex_template_job.flex_job[0].name, null)
    state                    = try(google_dataflow_flex_template_job.flex_job[0].state, null)
    type                     = try(google_dataflow_flex_template_job.flex_job[0].type, null)
    container_spec_gcs_path  = try(google_dataflow_flex_template_job.flex_job[0].container_spec_gcs_path, null)
    max_workers              = try(google_dataflow_flex_template_job.flex_job[0].max_workers, null)
    on_delete                = try(google_dataflow_flex_template_job.flex_job[0].on_delete, null)
    labels                   = try(google_dataflow_flex_template_job.flex_job[0].labels, null)
  } : null
}

# SQL Job Specific Outputs
output "sql_job_details" {
  description = "Details of SQL Dataflow job"
  value = var.template_type == "sql" && var.deploy_job ? {
    id                = try(google_dataflow_job.sql_job[0].id, null)
    name              = try(google_dataflow_job.sql_job[0].name, null)
    state             = try(google_dataflow_job.sql_job[0].state, null)
    type              = try(google_dataflow_job.sql_job[0].type, null)
    template_gcs_path = try(google_dataflow_job.sql_job[0].template_gcs_path, null)
    temp_gcs_location = try(google_dataflow_job.sql_job[0].temp_gcs_location, null)
    max_workers       = try(google_dataflow_job.sql_job[0].max_workers, null)
    on_delete         = try(google_dataflow_job.sql_job[0].on_delete, null)
    labels            = try(google_dataflow_job.sql_job[0].labels, null)
  } : null
}

# Python Job Specific Outputs
output "python_job_details" {
  description = "Details of Python Dataflow job"
  value = var.template_type == "python" && var.deploy_job ? {
    name            = local.job_name
    pipeline_path   = var.python_pipeline_path
    setup_file      = var.python_setup_file
    requirements    = var.python_requirements_file
    container_image = var.python_sdk_container_image
  } : null
}

# Storage Bucket Outputs
output "staging_bucket_name" {
  description = "Name of the staging bucket"
  value       = try(google_storage_bucket.staging_bucket[0].name, null)
}

output "staging_bucket_url" {
  description = "URL of the staging bucket"
  value       = try(google_storage_bucket.staging_bucket[0].url, null)
}

output "temp_bucket_name" {
  description = "Name of the temp bucket"
  value       = try(google_storage_bucket.temp_bucket[0].name, null)
}

output "temp_bucket_url" {
  description = "URL of the temp bucket"
  value       = try(google_storage_bucket.temp_bucket[0].url, null)
}

output "staging_location" {
  description = "GCS staging location"
  value       = var.staging_location != null ? var.staging_location : (
    var.create_staging_bucket ? "gs://${google_storage_bucket.staging_bucket[0].name}/staging" : null
  )
}

output "temp_location" {
  description = "GCS temp location"
  value       = var.temp_location != null ? var.temp_location : (
    var.create_temp_bucket ? "gs://${google_storage_bucket.temp_bucket[0].name}/temp" : null
  )
}

# Flex Template Spec Outputs
output "flex_template_spec_path" {
  description = "Path to flex template spec file"
  value = var.create_flex_template_spec && local.flex_template_spec != null ? (
    "gs://${var.flex_template_bucket}/${google_storage_bucket_object.flex_template_spec[0].name}"
  ) : var.flex_template_spec_path
}

output "flex_template_spec" {
  description = "Flex template specification"
  value       = local.flex_template_spec
  sensitive   = true
}

# Service Account Outputs
output "service_account_email" {
  description = "Email of the service account used"
  value = var.create_service_account ? (
    try(google_service_account.dataflow_sa[0].email, null)
  ) : var.service_account_email
}

output "service_account_name" {
  description = "Name of the service account"
  value       = try(google_service_account.dataflow_sa[0].name, null)
}

output "service_account_key" {
  description = "Service account key (base64 encoded)"
  value       = try(google_service_account_key.dataflow_sa_key[0].private_key, null)
  sensitive   = true
}

# Network Configuration
output "network" {
  description = "Network used by Dataflow job"
  value       = local.network
}

output "subnetwork" {
  description = "Subnetwork used by Dataflow job"
  value       = local.subnetwork
}

output "ip_configuration" {
  description = "IP configuration for workers"
  value       = var.ip_configuration
}

# Firewall Rules
output "firewall_rules" {
  description = "Created firewall rules"
  value = var.create_firewall_rules ? {
    ingress = try(google_compute_firewall.dataflow_ingress[0].name, null)
    egress  = try(google_compute_firewall.dataflow_egress[0].name, null)
  } : null
}

# Monitoring Outputs
output "monitoring_alert_policies" {
  description = "Created monitoring alert policies"
  value = {
    for name, policy in google_monitoring_alert_policy.dataflow_alerts :
    name => {
      id           = policy.id
      name         = policy.name
      display_name = policy.display_name
      enabled      = policy.enabled
    }
  }
}

output "monitoring_dashboard_id" {
  description = "ID of the monitoring dashboard"
  value       = try(google_monitoring_dashboard.dataflow_dashboard[0].id, null)
}

# Labels
output "labels" {
  description = "Labels applied to the job"
  value       = local.labels
}

# Console URLs
output "console_urls" {
  description = "Google Cloud Console URLs"
  value = {
    job_details = var.deploy_job ? (
      "https://console.cloud.google.com/dataflow/jobs/${var.region}/${local.job_name}?project=${var.project_id}"
    ) : null

    jobs_list = "https://console.cloud.google.com/dataflow/jobs?project=${var.project_id}"

    monitoring = var.deploy_job ? (
      "https://console.cloud.google.com/monitoring/dashboards/custom/${try(google_monitoring_dashboard.dataflow_dashboard[0].id, "")}?project=${var.project_id}"
    ) : null

    logs = var.deploy_job ? (
      "https://console.cloud.google.com/logs/query;query=resource.type%3D%22dataflow_step%22%20resource.labels.job_name%3D%22${local.job_name}%22?project=${var.project_id}"
    ) : null
  }
}

# gcloud Commands
output "gcloud_commands" {
  description = "Useful gcloud commands"
  value = {
    list_jobs = "gcloud dataflow jobs list --region=${var.region} --project=${var.project_id}"

    describe_job = var.deploy_job ? (
      "gcloud dataflow jobs describe ${local.job_name} --region=${var.region} --project=${var.project_id}"
    ) : null

    cancel_job = var.deploy_job ? (
      "gcloud dataflow jobs cancel ${local.job_name} --region=${var.region} --project=${var.project_id}"
    ) : null

    drain_job = var.deploy_job && var.is_streaming_job ? (
      "gcloud dataflow jobs drain ${local.job_name} --region=${var.region} --project=${var.project_id}"
    ) : null

    update_job = var.deploy_job && var.is_streaming_job ? (
      "gcloud dataflow jobs update ${local.job_name} --region=${var.region} --project=${var.project_id}"
    ) : null

    show_metrics = var.deploy_job ? (
      "gcloud dataflow metrics list ${local.job_name} --region=${var.region} --project=${var.project_id}"
    ) : null

    tail_logs = var.deploy_job ? (
      "gcloud logging tail 'resource.type=\"dataflow_step\" AND resource.labels.job_name=\"${local.job_name}\"' --project=${var.project_id}"
    ) : null
  }
}

# Job Parameters
output "job_parameters" {
  description = "Parameters used for the job"
  value       = local.job_parameters
}

# Job Metrics Queries
output "metrics_queries" {
  description = "Monitoring metrics queries"
  value = var.deploy_job ? {
    element_count = "fetch dataflow_job | metric 'dataflow.googleapis.com/job/element_count' | filter resource.job_name == '${local.job_name}' | align rate(1m) | every 1m"

    system_lag = "fetch dataflow_job | metric 'dataflow.googleapis.com/job/system_lag' | filter resource.job_name == '${local.job_name}' | align mean(1m) | every 1m"

    cpu_utilization = "fetch dataflow_job | metric 'dataflow.googleapis.com/job/current_vcore_count' | filter resource.job_name == '${local.job_name}' | align mean(1m) | every 1m"

    data_watermark = "fetch dataflow_job | metric 'dataflow.googleapis.com/job/data_watermark_age' | filter resource.job_name == '${local.job_name}' | align max(1m) | every 1m"

    failed_status = "fetch dataflow_job | metric 'dataflow.googleapis.com/job/is_failed' | filter resource.job_name == '${local.job_name}' | align max(1m) | every 1m"
  } : null
}

# Import Commands
output "import_commands" {
  description = "Terraform import commands"
  value = {
    classic_job = var.template_type == "classic" && var.deploy_job ? (
      "terraform import google_dataflow_job.classic_job projects/${var.project_id}/regions/${var.region}/jobs/${local.job_name}"
    ) : null

    flex_job = var.template_type == "flex" && var.deploy_job ? (
      "terraform import google_dataflow_flex_template_job.flex_job projects/${var.project_id}/regions/${var.region}/jobs/${local.job_name}"
    ) : null

    staging_bucket = var.create_staging_bucket ? (
      "terraform import google_storage_bucket.staging_bucket ${var.project_id}/${try(google_storage_bucket.staging_bucket[0].name, "")}"
    ) : null
  }
}