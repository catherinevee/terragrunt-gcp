# API Gateway Module Outputs

# API Outputs
output "api_id" {
  description = "The identifier for the API"
  value       = var.create_api ? google_api_gateway_api.api[0].name : null
}

output "api_name" {
  description = "The resource name of the API"
  value       = var.create_api ? google_api_gateway_api.api[0].name : null
}

output "api_managed_service" {
  description = "The name of the associated managed service"
  value       = var.create_api ? google_api_gateway_api.api[0].managed_service : null
}

# API Config Outputs
output "config_id" {
  description = "The identifier for the API config"
  value       = var.deploy_config && var.create_api ? google_api_gateway_api_config.config[0].api_config_id : null
}

output "config_name" {
  description = "The resource name of the API config"
  value       = var.deploy_config && var.create_api ? google_api_gateway_api_config.config[0].name : null
}

output "config_service_name" {
  description = "The backend service name for this config"
  value       = var.deploy_config && var.create_api ? google_api_gateway_api_config.config[0].service_config_id : null
}

# Gateway Outputs
output "gateway_id" {
  description = "The identifier for the gateway"
  value       = var.deploy_gateway && var.deploy_config && var.create_api ? google_api_gateway_gateway.gateway[0].gateway_id : null
}

output "gateway_name" {
  description = "The resource name of the gateway"
  value       = var.deploy_gateway && var.deploy_config && var.create_api ? google_api_gateway_gateway.gateway[0].name : null
}

output "gateway_url" {
  description = "The default hostname of the gateway for this region"
  value       = var.deploy_gateway && var.deploy_config && var.create_api ? google_api_gateway_gateway.gateway[0].default_hostname : null
}

output "gateway_default_hostname" {
  description = "The default hostname of the gateway"
  value       = var.deploy_gateway && var.deploy_config && var.create_api ? google_api_gateway_gateway.gateway[0].default_hostname : null
}

# Service Account Outputs
output "service_account_email" {
  description = "The email of the service account"
  value       = var.create_service_account ? google_service_account.api_gateway[0].email : null
}

output "service_account_id" {
  description = "The unique id of the service account"
  value       = var.create_service_account ? google_service_account.api_gateway[0].unique_id : null
}

output "service_account_name" {
  description = "The fully-qualified name of the service account"
  value       = var.create_service_account ? google_service_account.api_gateway[0].name : null
}

output "service_account_member" {
  description = "The Identity of the service account in member format"
  value       = var.create_service_account ? "serviceAccount:${google_service_account.api_gateway[0].email}" : null
}

# Cloud Endpoints Outputs
output "endpoints_service_name" {
  description = "The name of the Cloud Endpoints service"
  value       = var.create_endpoints_service ? google_endpoints_service.grpc[0].service_name : null
}

output "endpoints_config_id" {
  description = "The config ID of the Cloud Endpoints service"
  value       = var.create_endpoints_service ? google_endpoints_service.grpc[0].config_id : null
}

output "endpoints_dns_address" {
  description = "The DNS address for the Cloud Endpoints service"
  value       = var.create_endpoints_service ? google_endpoints_service.grpc[0].dns_address : null
}

output "endpoints_apis" {
  description = "List of API objects"
  value       = var.create_endpoints_service ? google_endpoints_service.grpc[0].apis : null
}

output "endpoints_endpoints" {
  description = "List of endpoint objects"
  value       = var.create_endpoints_service ? google_endpoints_service.grpc[0].endpoints : null
}

# Backend Services Outputs
output "backend_service_ids" {
  description = "The unique identifiers for the backend services"
  value = {
    for k, v in google_compute_backend_service.backend : k => v.id
  }
}

output "backend_service_self_links" {
  description = "The URIs of the backend services"
  value = {
    for k, v in google_compute_backend_service.backend : k => v.self_link
  }
}

output "backend_service_fingerprints" {
  description = "Fingerprints of the backend services"
  value = {
    for k, v in google_compute_backend_service.backend : k => v.fingerprint
  }
}

output "backend_service_generated_ids" {
  description = "The generated IDs for the backend services"
  value = {
    for k, v in google_compute_backend_service.backend : k => v.generated_id
  }
}

# Monitoring Outputs
output "monitoring_dashboard_id" {
  description = "The identifier for the monitoring dashboard"
  value       = var.create_monitoring_dashboard ? google_monitoring_dashboard.api_gateway[0].id : null
}

output "monitoring_alert_policy_ids" {
  description = "Map of alert policy names to their identifiers"
  value = {
    for k, v in google_monitoring_alert_policy.alerts : k => v.id
  }
}

output "monitoring_alert_policy_names" {
  description = "Map of alert policy names to their resource names"
  value = {
    for k, v in google_monitoring_alert_policy.alerts : k => v.name
  }
}

# IAM Outputs
output "api_iam_members" {
  description = "IAM members for the API"
  value = {
    for k, v in google_api_gateway_api_iam_member.api_iam : k => {
      role   = v.role
      member = v.member
    }
  }
}

output "gateway_iam_members" {
  description = "IAM members for the gateway"
  value = {
    for k, v in google_api_gateway_gateway_iam_member.gateway_iam : k => {
      role   = v.role
      member = v.member
    }
  }
}

output "endpoints_iam_members" {
  description = "IAM members for the endpoints service"
  value = {
    for k, v in google_endpoints_service_iam_member.endpoints_iam : k => {
      role   = v.role
      member = v.member
    }
  }
}

# Configuration Outputs
output "openapi_config" {
  description = "The OpenAPI configuration used"
  value = var.deploy_config && var.create_api && var.openapi_spec_inline != null ? {
    spec = var.openapi_spec_inline
  } : null
  sensitive = true
}

output "grpc_config" {
  description = "The gRPC configuration used"
  value = length(var.grpc_services) > 0 ? {
    services = var.grpc_services
  } : null
  sensitive = true
}

output "managed_services" {
  description = "List of managed services created"
  value = var.deploy_config && var.create_api ? [
    for idx, config in var.managed_service_configs : {
      path = config.path
    }
  ] : []
}

# State and Metadata
output "api_labels" {
  description = "The labels configured on the API"
  value       = var.create_api ? google_api_gateway_api.api[0].labels : null
}

output "gateway_labels" {
  description = "The labels configured on the gateway"
  value       = var.deploy_gateway && var.deploy_config && var.create_api ? google_api_gateway_gateway.gateway[0].labels : null
}

output "api_gateway_module_version" {
  description = "The version of the API Gateway module"
  value       = "1.0.0"
}

output "region" {
  description = "The region where resources are deployed"
  value       = var.region
}

output "project_id" {
  description = "The project ID where resources are deployed"
  value       = var.project_id
}

output "environment" {
  description = "The environment for the deployment"
  value       = var.environment
}