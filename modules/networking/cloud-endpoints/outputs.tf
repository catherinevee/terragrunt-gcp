# Cloud Endpoints Module - Outputs

# Service outputs
output "service_names" {
  description = "Map of service names for all configured endpoints"
  value = merge(
    { for k, v in google_endpoints_service.openapi_services : k => v.service_name },
    { for k, v in google_endpoints_service.grpc_services : k => v.service_name }
  )
}

output "service_configs" {
  description = "Configuration IDs for all services"
  value = merge(
    { for k, v in google_endpoints_service.openapi_services : k => v.config_id },
    { for k, v in google_endpoints_service.grpc_services : k => v.config_id }
  )
}

output "service_endpoints" {
  description = "Service endpoints for all configured APIs"
  value = merge(
    { for k, v in google_endpoints_service.openapi_services : k => "https://${v.service_name}" },
    { for k, v in google_endpoints_service.grpc_services : k => v.service_name }
  )
}

# API Gateway outputs
output "api_gateway_urls" {
  description = "URLs for deployed API Gateways"
  value = {
    for k, v in google_api_gateway_gateway.gateway_deployments :
    k => "https://${v.gateway_id}-${substr(v.api_config, -8, -1)}.${v.region}.gateway.dev"
  }
}

output "api_gateway_ids" {
  description = "API Gateway resource IDs"
  value = {
    for k, v in google_api_gateway_gateway.gateway_deployments :
    k => v.id
  }
}

output "api_gateway_configs" {
  description = "API Gateway configuration IDs"
  value = {
    for k, v in google_api_gateway_api_config.gateway_configs :
    k => v.id
  }
}

# API Keys outputs
output "api_key_ids" {
  description = "API key resource IDs"
  value = {
    for k, v in google_apikeys_key.api_keys :
    k => v.id
  }
  sensitive = true
}

output "api_key_strings" {
  description = "API key strings for authentication"
  value = {
    for k, v in google_apikeys_key.api_keys :
    k => v.key_string
  }
  sensitive = true
}

# Service account outputs
output "service_account_email" {
  description = "Email of the Endpoints service account"
  value       = var.create_service_account ? google_service_account.endpoints_sa[0].email : null
}

output "service_account_id" {
  description = "ID of the Endpoints service account"
  value       = var.create_service_account ? google_service_account.endpoints_sa[0].account_id : null
}

# Monitoring outputs
output "dashboard_url" {
  description = "URL to the monitoring dashboard"
  value = var.enable_monitoring && var.create_dashboard ? (
    "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.api_dashboard[0].id}?project=${var.project_id}"
  ) : null
}

output "alert_policy_ids" {
  description = "IDs of created alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.api_alerts :
    k => v.id
  }
}

# Service details
output "openapi_service_details" {
  description = "Detailed information about OpenAPI services"
  value = {
    for k, v in google_endpoints_service.openapi_services : k => {
      service_name = v.service_name
      config_id    = v.config_id
      dns_address  = v.dns_address
      endpoints    = v.endpoints
      project      = v.project
    }
  }
}

output "grpc_service_details" {
  description = "Detailed information about gRPC services"
  value = {
    for k, v in google_endpoints_service.grpc_services : k => {
      service_name = v.service_name
      config_id    = v.config_id
      dns_address  = v.dns_address
      endpoints    = v.endpoints
      project      = v.project
    }
  }
}

# Quota override outputs
output "quota_overrides" {
  description = "Applied quota overrides"
  value = {
    for k, v in google_service_management_consumer_quota_override.quota_overrides :
    k => {
      metric         = v.metric
      limit          = v.limit
      override_value = v.override_value
    }
  }
}

# IAM outputs
output "service_iam_bindings" {
  description = "IAM bindings for services"
  value = {
    for k, v in google_endpoints_service_iam_binding.service_bindings :
    k => {
      service_name = v.service_name
      role         = v.role
      members      = v.members
    }
  }
}

output "consumer_iam_bindings" {
  description = "IAM bindings for consumers"
  value = {
    for k, v in google_endpoints_service_consumers_iam_binding.consumer_bindings :
    k => {
      service_name  = v.service_name
      consumer_name = v.consumer_name
      role          = v.role
      members       = v.members
    }
  }
}

# Configuration metadata
output "configuration_metadata" {
  description = "Metadata about the Endpoints configuration"
  value = {
    project_id                   = var.project_id
    monitoring_enabled           = var.enable_monitoring
    logging_enabled              = var.enable_logging
    api_gateway_enabled          = var.enable_api_gateway
    vpc_service_controls_enabled = var.enable_vpc_service_controls
    quota_management_enabled     = var.enable_quota
    controlled_rollout_enabled   = var.enable_controlled_rollout
    total_openapi_services       = length(google_endpoints_service.openapi_services)
    total_grpc_services          = length(google_endpoints_service.grpc_services)
    total_api_gateways           = length(google_api_gateway_gateway.gateway_deployments)
    total_api_keys               = length(google_apikeys_key.api_keys)
    total_alert_policies         = length(google_monitoring_alert_policy.api_alerts)
  }
}

# Management URLs
output "management_urls" {
  description = "URLs for managing the endpoints"
  value = {
    endpoints_console   = "https://console.cloud.google.com/endpoints?project=${var.project_id}"
    api_gateway_console = var.enable_api_gateway ? "https://console.cloud.google.com/api-gateway?project=${var.project_id}" : null
    service_management  = "https://console.cloud.google.com/apis/api/servicemanagement.googleapis.com?project=${var.project_id}"
    api_keys_console    = "https://console.cloud.google.com/apis/credentials?project=${var.project_id}"
    monitoring_console  = var.enable_monitoring ? "https://console.cloud.google.com/monitoring?project=${var.project_id}" : null
  }
}

# Service discovery
output "service_discovery" {
  description = "Service discovery information for clients"
  value = {
    openapi_services = {
      for k, v in local.openapi_specs : k => {
        endpoint    = "https://${v.service_name}"
        backend_url = var.openapi_services[k].backend_url
        api_version = coalesce(var.openapi_services[k].api_version, "v1")
      }
    }
    grpc_services = {
      for k, v in local.grpc_configs : k => {
        endpoint            = v.service_name
        backend_address     = v.service_config.backend_address
        backend_port        = v.service_config.backend_port
        transcoding_enabled = v.service_config.transcoding_enabled
      }
    }
  }
}

# Rollout status
output "rollout_status" {
  description = "Current rollout status for services"
  value = merge(
    {
      for k, v in google_endpoints_service.openapi_services : k => {
        service_name    = v.service_name
        current_config  = v.config_id
        rollout_enabled = var.enable_controlled_rollout
      }
    },
    {
      for k, v in google_endpoints_service.grpc_services : k => {
        service_name    = v.service_name
        current_config  = v.config_id
        rollout_enabled = var.enable_controlled_rollout
      }
    }
  )
}

# Security configuration
output "security_configuration" {
  description = "Security configuration details"
  value = {
    authentication_enabled = var.authentication_config != null
    vpc_service_controls = var.enable_vpc_service_controls ? {
      enabled        = true
      perimeter_name = var.vpc_service_perimeter_name
      access_levels  = var.vpc_access_levels
    } : null
    api_keys_configured = length(var.api_keys) > 0
  }
}