# Cloud Run Module Outputs

# Service Information
output "service_name" {
  description = "Name of the Cloud Run service"
  value       = var.deploy_service ? try(google_cloud_run_v2_service.service[0].name, null) : null
}

output "service_id" {
  description = "ID of the Cloud Run service"
  value       = var.deploy_service ? try(google_cloud_run_v2_service.service[0].id, null) : null
}

output "service_uri" {
  description = "URI of the Cloud Run service"
  value       = var.deploy_service ? try(google_cloud_run_v2_service.service[0].uri, null) : null
}

output "service_url" {
  description = "URL of the Cloud Run service"
  value       = var.deploy_service ? try(google_cloud_run_v2_service.service[0].uri, null) : null
}

output "service_status" {
  description = "Status of the Cloud Run service"
  value       = var.deploy_service ? try(google_cloud_run_v2_service.service[0].conditions, null) : null
}

output "service_latest_revision" {
  description = "Latest revision of the service"
  value       = var.deploy_service ? try(google_cloud_run_v2_service.service[0].latest_ready_revision, null) : null
}

output "service_latest_created_revision" {
  description = "Latest created revision"
  value       = var.deploy_service ? try(google_cloud_run_v2_service.service[0].latest_created_revision, null) : null
}

output "service_generation" {
  description = "Generation of the service"
  value       = var.deploy_service ? try(google_cloud_run_v2_service.service[0].generation, null) : null
}

output "service_observed_generation" {
  description = "Observed generation"
  value       = var.deploy_service ? try(google_cloud_run_v2_service.service[0].observed_generation, null) : null
}

output "service_reconciling" {
  description = "Whether service is reconciling"
  value       = var.deploy_service ? try(google_cloud_run_v2_service.service[0].reconciling, null) : null
}

output "service_etag" {
  description = "Etag of the service"
  value       = var.deploy_service ? try(google_cloud_run_v2_service.service[0].etag, null) : null
}

output "service_update_time" {
  description = "Last update time"
  value       = var.deploy_service ? try(google_cloud_run_v2_service.service[0].update_time, null) : null
}

output "service_create_time" {
  description = "Creation time"
  value       = var.deploy_service ? try(google_cloud_run_v2_service.service[0].create_time, null) : null
}

# Job Information
output "job_name" {
  description = "Name of the Cloud Run Job"
  value       = var.deploy_job ? try(google_cloud_run_v2_job.job[0].name, null) : null
}

output "job_id" {
  description = "ID of the Cloud Run Job"
  value       = var.deploy_job ? try(google_cloud_run_v2_job.job[0].id, null) : null
}

output "job_generation" {
  description = "Generation of the job"
  value       = var.deploy_job ? try(google_cloud_run_v2_job.job[0].generation, null) : null
}

output "job_observed_generation" {
  description = "Observed generation of job"
  value       = var.deploy_job ? try(google_cloud_run_v2_job.job[0].observed_generation, null) : null
}

output "job_etag" {
  description = "Etag of the job"
  value       = var.deploy_job ? try(google_cloud_run_v2_job.job[0].etag, null) : null
}

output "job_latest_created_execution" {
  description = "Latest created execution"
  value       = var.deploy_job ? try(google_cloud_run_v2_job.job[0].latest_created_execution, null) : null
}

# Service Account
output "service_account_email" {
  description = "Service account email"
  value       = local.service_account_email
}

output "service_account_name" {
  description = "Service account name"
  value       = var.create_service_account ? try(google_service_account.service_sa[0].name, null) : null
}

output "service_account_key" {
  description = "Service account key"
  value       = var.create_service_account && var.create_service_account_key ? try(google_service_account_key.service_sa_key[0].private_key, null) : null
  sensitive   = true
}

# Domain Mapping
output "domain_name" {
  description = "Domain name"
  value       = var.deploy_service && var.domain_name != null ? try(google_cloud_run_domain_mapping.domain[0].name, null) : null
}

output "domain_status" {
  description = "Domain status"
  value       = var.deploy_service && var.domain_name != null ? try(google_cloud_run_domain_mapping.domain[0].status, null) : null
}

output "domain_mapped_route" {
  description = "Mapped route name"
  value       = var.deploy_service && var.domain_name != null ? try(google_cloud_run_domain_mapping.domain[0].spec[0].route_name, null) : null
}

output "domain_resource_records" {
  description = "DNS resource records"
  value       = var.deploy_service && var.domain_name != null ? try(google_cloud_run_domain_mapping.domain[0].status[0].resource_records, null) : null
}

# Scheduler
output "job_scheduler_name" {
  description = "Job scheduler name"
  value       = var.deploy_job && var.create_job_scheduler ? try(google_cloud_scheduler_job.job_scheduler[0].name, null) : null
}

output "job_scheduler_id" {
  description = "Job scheduler ID"
  value       = var.deploy_job && var.create_job_scheduler ? try(google_cloud_scheduler_job.job_scheduler[0].id, null) : null
}

# Monitoring
output "monitoring_dashboard_id" {
  description = "Dashboard ID"
  value       = var.deploy_service && var.create_monitoring_dashboard ? try(google_monitoring_dashboard.service_dashboard[0].id, null) : null
}

output "monitoring_alert_policies" {
  description = "Alert policy IDs"
  value = {
    for name, policy in google_monitoring_alert_policy.service_alerts :
    name => {
      id           = policy.id
      name         = policy.name
      display_name = policy.display_name
      enabled      = policy.enabled
    }
  }
}

# Console URLs
output "console_urls" {
  description = "Cloud Console URLs"
  value = {
    service_details = var.deploy_service ? (
      "https://console.cloud.google.com/run/detail/${var.region}/${local.service_name}?project=${var.project_id}"
    ) : null

    service_logs = var.deploy_service ? (
      "https://console.cloud.google.com/logs/query;query=resource.type%3D%22cloud_run_revision%22%20resource.labels.service_name%3D%22${local.service_name}%22?project=${var.project_id}"
    ) : null

    service_metrics = var.deploy_service ? (
      "https://console.cloud.google.com/run/detail/${var.region}/${local.service_name}/metrics?project=${var.project_id}"
    ) : null

    job_details = var.deploy_job ? (
      "https://console.cloud.google.com/run/jobs/details/${var.region}/${var.job_name != null ? var.job_name : \"${local.service_name}-job\"}?project=${var.project_id}"
    ) : null

    job_executions = var.deploy_job ? (
      "https://console.cloud.google.com/run/jobs/executions/${var.region}/${var.job_name != null ? var.job_name : \"${local.service_name}-job\"}?project=${var.project_id}"
    ) : null

    domain_mappings = var.deploy_service ? (
      "https://console.cloud.google.com/run/domains?project=${var.project_id}"
    ) : null
  }
}

# gcloud Commands
output "gcloud_commands" {
  description = "gcloud commands"
  value = {
    describe_service = var.deploy_service ? (
      "gcloud run services describe ${local.service_name} --region=${var.region} --project=${var.project_id}"
    ) : null

    deploy_service = (
      "gcloud run deploy ${local.service_name} --image=${var.container_image} --region=${var.region} --project=${var.project_id}"
    )

    delete_service = var.deploy_service ? (
      "gcloud run services delete ${local.service_name} --region=${var.region} --project=${var.project_id}"
    ) : null

    describe_job = var.deploy_job ? (
      "gcloud run jobs describe ${var.job_name != null ? var.job_name : \"${local.service_name}-job\"} --region=${var.region} --project=${var.project_id}"
    ) : null

    execute_job = var.deploy_job ? (
      "gcloud run jobs execute ${var.job_name != null ? var.job_name : \"${local.service_name}-job\"} --region=${var.region} --project=${var.project_id}"
    ) : null

    list_executions = var.deploy_job ? (
      "gcloud run jobs executions list --job=${var.job_name != null ? var.job_name : \"${local.service_name}-job\"} --region=${var.region} --project=${var.project_id}"
    ) : null

    update_traffic = var.deploy_service ? (
      "gcloud run services update-traffic ${local.service_name} --to-latest --region=${var.region} --project=${var.project_id}"
    ) : null

    get_service_url = var.deploy_service ? (
      "gcloud run services describe ${local.service_name} --region=${var.region} --format='value(status.url)' --project=${var.project_id}"
    ) : null
  }
}

# curl Commands
output "curl_commands" {
  description = "curl commands"
  value = var.deploy_service ? {
    basic = (
      "curl ${try(google_cloud_run_v2_service.service[0].uri, \"\")}"
    )

    with_auth = (
      "curl -H \"Authorization: Bearer $(gcloud auth print-identity-token)\" ${try(google_cloud_run_v2_service.service[0].uri, \"\")}"
    )

    with_data = (
      "curl -X POST -H \"Content-Type: application/json\" -d '{\"key\":\"value\"}' ${try(google_cloud_run_v2_service.service[0].uri, \"\")}"
    )
  } : null
}

# Import Commands
output "import_commands" {
  description = "Terraform import commands"
  value = {
    service = var.deploy_service ? (
      "terraform import google_cloud_run_v2_service.service projects/${var.project_id}/locations/${var.region}/services/${local.service_name}"
    ) : null

    job = var.deploy_job ? (
      "terraform import google_cloud_run_v2_job.job projects/${var.project_id}/locations/${var.region}/jobs/${var.job_name != null ? var.job_name : \"${local.service_name}-job\"}"
    ) : null

    service_account = var.create_service_account ? (
      "terraform import google_service_account.service_sa projects/${var.project_id}/serviceAccounts/${try(google_service_account.service_sa[0].email, \"\")}"
    ) : null

    domain_mapping = var.deploy_service && var.domain_name != null ? (
      "terraform import google_cloud_run_domain_mapping.domain projects/${var.project_id}/locations/${var.region}/domainMappings/${var.domain_name}"
    ) : null
  }
}

# Labels
output "labels" {
  description = "Labels applied"
  value       = local.labels
}