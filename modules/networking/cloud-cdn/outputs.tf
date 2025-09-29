# Cloud CDN Module Outputs

# Backend Service Outputs
output "backend_service_ids" {
  description = "The identifiers for backend services"
  value = {
    for k, v in google_compute_backend_service.backend_services : k => v.id
  }
}

output "backend_service_names" {
  description = "The names of backend services"
  value = {
    for k, v in google_compute_backend_service.backend_services : k => v.name
  }
}

output "backend_service_self_links" {
  description = "The self links of backend services"
  value = {
    for k, v in google_compute_backend_service.backend_services : k => v.self_link
  }
}

output "backend_service_fingerprints" {
  description = "The fingerprints of backend services"
  value = {
    for k, v in google_compute_backend_service.backend_services : k => v.fingerprint
  }
}

output "backend_service_generated_ids" {
  description = "The generated IDs of backend services"
  value = {
    for k, v in google_compute_backend_service.backend_services : k => v.generated_id
  }
}

output "backend_service_cdn_enabled" {
  description = "CDN enablement status for backend services"
  value = {
    for k, v in google_compute_backend_service.backend_services : k => v.enable_cdn
  }
}

# Health Check Outputs
output "health_check_ids" {
  description = "The identifiers for health checks"
  value = {
    for k, v in google_compute_health_check.health_checks : k => v.id
  }
}

output "health_check_names" {
  description = "The names of health checks"
  value = {
    for k, v in google_compute_health_check.health_checks : k => v.name
  }
}

output "health_check_self_links" {
  description = "The self links of health checks"
  value = {
    for k, v in google_compute_health_check.health_checks : k => v.self_link
  }
}

# Instance Group Outputs
output "instance_group_ids" {
  description = "The identifiers for instance groups"
  value = {
    for k, v in google_compute_instance_group.backend_groups : k => v.id
  }
}

output "instance_group_names" {
  description = "The names of instance groups"
  value = {
    for k, v in google_compute_instance_group.backend_groups : k => v.name
  }
}

output "instance_group_self_links" {
  description = "The self links of instance groups"
  value = {
    for k, v in google_compute_instance_group.backend_groups : k => v.self_link
  }
}

# Security Policy Outputs
output "security_policy_ids" {
  description = "The identifiers for security policies"
  value = {
    for k, v in google_compute_security_policy.security_policies : k => v.id
  }
}

output "security_policy_names" {
  description = "The names of security policies"
  value = {
    for k, v in google_compute_security_policy.security_policies : k => v.name
  }
}

output "security_policy_self_links" {
  description = "The self links of security policies"
  value = {
    for k, v in google_compute_security_policy.security_policies : k => v.self_link
  }
}

output "security_policy_fingerprints" {
  description = "The fingerprints of security policies"
  value = {
    for k, v in google_compute_security_policy.security_policies : k => v.fingerprint
  }
}

# SSL Certificate Outputs
output "managed_ssl_certificate_ids" {
  description = "The identifiers for managed SSL certificates"
  value = {
    for k, v in google_compute_managed_ssl_certificate.ssl_certificates : k => v.id
  }
}

output "managed_ssl_certificate_names" {
  description = "The names of managed SSL certificates"
  value = {
    for k, v in google_compute_managed_ssl_certificate.ssl_certificates : k => v.name
  }
}

output "managed_ssl_certificate_domains" {
  description = "The domains for managed SSL certificates"
  value = {
    for k, v in google_compute_managed_ssl_certificate.ssl_certificates : k => v.managed[0].domains
  }
}

output "managed_ssl_certificate_domain_status" {
  description = "The domain status for managed SSL certificates"
  value = {
    for k, v in google_compute_managed_ssl_certificate.ssl_certificates : k => v.managed[0].domain_status
  }
}

output "self_managed_ssl_certificate_ids" {
  description = "The identifiers for self-managed SSL certificates"
  value = {
    for k, v in google_compute_ssl_certificate.self_managed_ssl_certificates : k => v.id
  }
}

output "self_managed_ssl_certificate_names" {
  description = "The names of self-managed SSL certificates"
  value = {
    for k, v in google_compute_ssl_certificate.self_managed_ssl_certificates : k => v.name
  }
}

output "self_managed_ssl_certificate_fingerprints" {
  description = "The fingerprints of self-managed SSL certificates"
  value = {
    for k, v in google_compute_ssl_certificate.self_managed_ssl_certificates : k => v.certificate_id
  }
}

# URL Map Outputs
output "url_map_ids" {
  description = "The identifiers for URL maps"
  value = {
    for k, v in google_compute_url_map.url_maps : k => v.id
  }
}

output "url_map_names" {
  description = "The names of URL maps"
  value = {
    for k, v in google_compute_url_map.url_maps : k => v.name
  }
}

output "url_map_self_links" {
  description = "The self links of URL maps"
  value = {
    for k, v in google_compute_url_map.url_maps : k => v.self_link
  }
}

output "url_map_fingerprints" {
  description = "The fingerprints of URL maps"
  value = {
    for k, v in google_compute_url_map.url_maps : k => v.fingerprint
  }
}

output "url_map_map_ids" {
  description = "The map IDs of URL maps"
  value = {
    for k, v in google_compute_url_map.url_maps : k => v.map_id
  }
}

# Target HTTPS Proxy Outputs
output "target_https_proxy_ids" {
  description = "The identifiers for target HTTPS proxies"
  value = {
    for k, v in google_compute_target_https_proxy.target_https_proxies : k => v.id
  }
}

output "target_https_proxy_names" {
  description = "The names of target HTTPS proxies"
  value = {
    for k, v in google_compute_target_https_proxy.target_https_proxies : k => v.name
  }
}

output "target_https_proxy_self_links" {
  description = "The self links of target HTTPS proxies"
  value = {
    for k, v in google_compute_target_https_proxy.target_https_proxies : k => v.self_link
  }
}

output "target_https_proxy_proxy_ids" {
  description = "The proxy IDs of target HTTPS proxies"
  value = {
    for k, v in google_compute_target_https_proxy.target_https_proxies : k => v.proxy_id
  }
}

# Global IP Address Outputs
output "global_ip_addresses" {
  description = "The global IP addresses"
  value = {
    for k, v in google_compute_global_address.global_ips : k => v.address
  }
}

output "global_ip_ids" {
  description = "The identifiers for global IP addresses"
  value = {
    for k, v in google_compute_global_address.global_ips : k => v.id
  }
}

output "global_ip_names" {
  description = "The names of global IP addresses"
  value = {
    for k, v in google_compute_global_address.global_ips : k => v.name
  }
}

output "global_ip_self_links" {
  description = "The self links of global IP addresses"
  value = {
    for k, v in google_compute_global_address.global_ips : k => v.self_link
  }
}

# Global Forwarding Rule Outputs
output "global_forwarding_rule_ids" {
  description = "The identifiers for global forwarding rules"
  value = {
    for k, v in google_compute_global_forwarding_rule.global_forwarding_rules : k => v.id
  }
}

output "global_forwarding_rule_names" {
  description = "The names of global forwarding rules"
  value = {
    for k, v in google_compute_global_forwarding_rule.global_forwarding_rules : k => v.name
  }
}

output "global_forwarding_rule_self_links" {
  description = "The self links of global forwarding rules"
  value = {
    for k, v in google_compute_global_forwarding_rule.global_forwarding_rules : k => v.self_link
  }
}

output "global_forwarding_rule_ip_addresses" {
  description = "The IP addresses of global forwarding rules"
  value = {
    for k, v in google_compute_global_forwarding_rule.global_forwarding_rules : k => v.ip_address
  }
}

output "global_forwarding_rule_labels" {
  description = "The labels of global forwarding rules"
  value = {
    for k, v in google_compute_global_forwarding_rule.global_forwarding_rules : k => v.labels
  }
}

# Service Account Outputs
output "service_account_email" {
  description = "The email of the created service account"
  value       = var.create_service_account ? google_service_account.cdn[0].email : null
}

output "service_account_id" {
  description = "The unique id of the service account"
  value       = var.create_service_account ? google_service_account.cdn[0].unique_id : null
}

output "service_account_name" {
  description = "The fully-qualified name of the service account"
  value       = var.create_service_account ? google_service_account.cdn[0].name : null
}

output "service_account_member" {
  description = "The IAM member format for the service account"
  value       = var.create_service_account ? "serviceAccount:${google_service_account.cdn[0].email}" : null
}

# Monitoring Outputs
output "monitoring_alert_policy_ids" {
  description = "IDs of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.cdn_alerts : k => v.id
  }
}

output "monitoring_alert_policy_names" {
  description = "Names of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.cdn_alerts : k => v.name
  }
}

output "monitoring_dashboard_id" {
  description = "ID of the monitoring dashboard"
  value       = var.create_monitoring_dashboard ? google_monitoring_dashboard.cdn[0].id : null
}

# CDN Configuration Summary
output "cdn_configuration" {
  description = "Summary of CDN configuration"
  value = {
    backend_services_count = length(local.backend_services)
    cdn_enabled_services = length([
      for k, v in local.backend_services : k if v.enable_cdn
    ])
    security_policies_count = length(local.security_policies)
    ssl_certificates_count = length(local.ssl_certificates)
    url_maps_count        = length(local.url_maps)
    origins_count         = length(local.origins)
  }
}

# Cache Policy Summary
output "cache_policies" {
  description = "Summary of cache policies for each backend service"
  value = {
    for k, v in local.backend_services : k => {
      cache_mode         = v.cdn_policy.cache_mode
      default_ttl        = v.cdn_policy.default_ttl
      max_ttl           = v.cdn_policy.max_ttl
      client_ttl        = v.cdn_policy.client_ttl
      negative_caching  = v.cdn_policy.negative_caching
      serve_while_stale = v.cdn_policy.serve_while_stale
    } if v.enable_cdn
  }
}

# Security Configuration Summary
output "security_configuration" {
  description = "Summary of security configuration"
  value = {
    cloud_armor_enabled    = length(local.security_policies) > 0
    security_policies = {
      for k, v in local.security_policies : k => {
        type         = v.type
        rules_count  = length(v.rules)
        default_action = v.default_rule.action
      }
    }
    ssl_certificates = {
      managed_count     = length(google_compute_managed_ssl_certificate.ssl_certificates)
      self_managed_count = length(google_compute_ssl_certificate.self_managed_ssl_certificates)
    }
  }
}

# Load Balancing Summary
output "load_balancing_summary" {
  description = "Summary of load balancing configuration"
  value = {
    global_forwarding_rules = {
      for k, v in local.global_forwarding_rules : k => {
        ip_protocol           = v.ip_protocol
        port_range           = v.port_range
        load_balancing_scheme = v.load_balancing_scheme
        network_tier         = v.network_tier
      }
    }
    target_proxies = {
      for k, v in local.target_https_proxies : k => {
        quic_override = v.quic_override
        ssl_certificates_count = length(v.ssl_certificates)
      }
    }
  }
}

# Health Check Summary
output "health_check_summary" {
  description = "Summary of health check configuration"
  value = {
    for k, v in local.origins : k => {
      type                = v.health_check.type
      port               = v.health_check.port
      check_interval_sec = v.health_check.check_interval_sec
      timeout_sec        = v.health_check.timeout_sec
      healthy_threshold  = v.health_check.healthy_threshold
      unhealthy_threshold = v.health_check.unhealthy_threshold
    }
  }
}

# Performance Summary
output "performance_summary" {
  description = "Summary of performance configuration"
  value = {
    http2_enabled = var.performance_config.enable_http2
    http3_enabled = var.performance_config.enable_http3_quic
    connection_pooling_enabled = var.performance_config.enable_connection_pooling
    compression_enabled = var.advanced_cdn_config.enable_gzip_compression
    brotli_enabled     = var.advanced_cdn_config.enable_brotli_compression
  }
}

# Cost Summary
output "cost_summary" {
  description = "Summary of cost-related configuration"
  value = {
    global_ips_count      = length(google_compute_global_address.global_ips)
    premium_tier_rules    = length([
      for k, v in local.global_forwarding_rules : k if v.network_tier == "PREMIUM"
    ])
    standard_tier_rules   = length([
      for k, v in local.global_forwarding_rules : k if v.network_tier == "STANDARD"
    ])
    cost_optimization_enabled = var.cost_optimization_config.enable_cost_optimization
  }
}

# Connection Information
output "connection_info" {
  description = "Connection information for CDN endpoints"
  value = {
    global_ips = {
      for k, v in google_compute_global_address.global_ips : k => {
        ip_address = v.address
        name      = v.name
      }
    }
    forwarding_rules = {
      for k, v in google_compute_global_forwarding_rule.global_forwarding_rules : k => {
        ip_address = v.ip_address
        port_range = v.port_range
        target     = v.target
      }
    }
    ssl_domains = {
      for k, v in google_compute_managed_ssl_certificate.ssl_certificates : k => v.managed[0].domains
    }
  }
  sensitive = false
}

# Module Metadata
output "module_configuration" {
  description = "Module configuration summary"
  value = {
    project_id              = var.project_id
    region                 = var.region
    zone                   = var.zone
    environment            = local.environment
    name_prefix            = local.name_prefix
    service_account_created = var.create_service_account
    instance_groups_created = var.create_instance_groups
    global_ips_created     = var.create_global_ips
    monitoring_enabled     = var.create_monitoring_alerts
    dashboard_created      = var.create_monitoring_dashboard
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
    backend_services        = length(var.backend_services)
    health_checks          = length(var.origins)
    instance_groups        = var.create_instance_groups ? length(var.origins) : 0
    security_policies      = length(var.security_policies)
    managed_ssl_certificates = length([
      for k, v in var.ssl_certificates : k if v.managed != null
    ])
    self_managed_ssl_certificates = length([
      for k, v in var.ssl_certificates : k if v.self_managed != null
    ])
    url_maps               = length(var.url_maps)
    target_https_proxies   = length(var.target_https_proxies)
    global_ip_addresses    = var.create_global_ips ? length(var.global_forwarding_rules) : 0
    global_forwarding_rules = length(var.global_forwarding_rules)
    service_accounts       = var.create_service_account ? 1 : 0
    alert_policies         = var.create_monitoring_alerts ? length(var.monitoring_alerts) : 0
    dashboards            = var.create_monitoring_dashboard ? 1 : 0
  }
}