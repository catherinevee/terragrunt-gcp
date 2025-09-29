# Certificate Manager Module Outputs

# Certificate Outputs
output "certificate_ids" {
  description = "The identifiers for certificates"
  value = {
    for k, v in google_certificate_manager_certificate.certificates : k => v.id
  }
}

output "certificate_names" {
  description = "The names of certificates"
  value = {
    for k, v in google_certificate_manager_certificate.certificates : k => v.name
  }
}

output "certificate_create_times" {
  description = "The creation times of certificates"
  value = {
    for k, v in google_certificate_manager_certificate.certificates : k => v.create_time
  }
}

output "certificate_update_times" {
  description = "The update times of certificates"
  value = {
    for k, v in google_certificate_manager_certificate.certificates : k => v.update_time
  }
}

output "certificate_expire_times" {
  description = "The expiration times of certificates"
  value = {
    for k, v in google_certificate_manager_certificate.certificates : k => v.expire_time
  }
}

output "certificate_san_dnsnames" {
  description = "The SAN DNS names for certificates"
  value = {
    for k, v in google_certificate_manager_certificate.certificates : k => v.san_dnsnames
  }
}

output "certificate_pem_certificates" {
  description = "The PEM-encoded certificates"
  value = {
    for k, v in google_certificate_manager_certificate.certificates : k => v.pem_certificate
  }
  sensitive = true
}

# Certificate Map Outputs
output "certificate_map_ids" {
  description = "The identifiers for certificate maps"
  value = {
    for k, v in google_certificate_manager_certificate_map.certificate_maps : k => v.id
  }
}

output "certificate_map_names" {
  description = "The names of certificate maps"
  value = {
    for k, v in google_certificate_manager_certificate_map.certificate_maps : k => v.name
  }
}

output "certificate_map_create_times" {
  description = "The creation times of certificate maps"
  value = {
    for k, v in google_certificate_manager_certificate_map.certificate_maps : k => v.create_time
  }
}

output "certificate_map_update_times" {
  description = "The update times of certificate maps"
  value = {
    for k, v in google_certificate_manager_certificate_map.certificate_maps : k => v.update_time
  }
}

output "certificate_map_gclb_targets" {
  description = "The GCLB targets for certificate maps"
  value = {
    for k, v in google_certificate_manager_certificate_map.certificate_maps : k => v.gclb_targets
  }
}

# Certificate Map Entry Outputs
output "certificate_map_entry_ids" {
  description = "The identifiers for certificate map entries"
  value = {
    for k, v in google_certificate_manager_certificate_map_entry.certificate_map_entries : k => v.id
  }
}

output "certificate_map_entry_names" {
  description = "The names of certificate map entries"
  value = {
    for k, v in google_certificate_manager_certificate_map_entry.certificate_map_entries : k => v.name
  }
}

output "certificate_map_entry_create_times" {
  description = "The creation times of certificate map entries"
  value = {
    for k, v in google_certificate_manager_certificate_map_entry.certificate_map_entries : k => v.create_time
  }
}

output "certificate_map_entry_update_times" {
  description = "The update times of certificate map entries"
  value = {
    for k, v in google_certificate_manager_certificate_map_entry.certificate_map_entries : k => v.update_time
  }
}

output "certificate_map_entry_states" {
  description = "The states of certificate map entries"
  value = {
    for k, v in google_certificate_manager_certificate_map_entry.certificate_map_entries : k => v.state
  }
}

# DNS Authorization Outputs
output "dns_authorization_ids" {
  description = "The identifiers for DNS authorizations"
  value = {
    for k, v in google_certificate_manager_dns_authorization.dns_authorizations : k => v.id
  }
}

output "dns_authorization_names" {
  description = "The names of DNS authorizations"
  value = {
    for k, v in google_certificate_manager_dns_authorization.dns_authorizations : k => v.name
  }
}

output "dns_authorization_dns_resource_records" {
  description = "The DNS resource records for DNS authorizations"
  value = {
    for k, v in google_certificate_manager_dns_authorization.dns_authorizations : k => v.dns_resource_record
  }
}

# Certificate Issuance Config Outputs
output "certificate_issuance_config_ids" {
  description = "The identifiers for certificate issuance configs"
  value = {
    for k, v in google_certificate_manager_certificate_issuance_config.issuance_configs : k => v.id
  }
}

output "certificate_issuance_config_names" {
  description = "The names of certificate issuance configs"
  value = {
    for k, v in google_certificate_manager_certificate_issuance_config.issuance_configs : k => v.name
  }
}

output "certificate_issuance_config_create_times" {
  description = "The creation times of certificate issuance configs"
  value = {
    for k, v in google_certificate_manager_certificate_issuance_config.issuance_configs : k => v.create_time
  }
}

output "certificate_issuance_config_update_times" {
  description = "The update times of certificate issuance configs"
  value = {
    for k, v in google_certificate_manager_certificate_issuance_config.issuance_configs : k => v.update_time
  }
}

# Trust Config Outputs
output "trust_config_ids" {
  description = "The identifiers for trust configs"
  value = {
    for k, v in google_certificate_manager_trust_config.trust_configs : k => v.id
  }
}

output "trust_config_names" {
  description = "The names of trust configs"
  value = {
    for k, v in google_certificate_manager_trust_config.trust_configs : k => v.name
  }
}

output "trust_config_create_times" {
  description = "The creation times of trust configs"
  value = {
    for k, v in google_certificate_manager_trust_config.trust_configs : k => v.create_time
  }
}

output "trust_config_update_times" {
  description = "The update times of trust configs"
  value = {
    for k, v in google_certificate_manager_trust_config.trust_configs : k => v.update_time
  }
}

# Classic SSL Certificate Outputs
output "classic_ssl_certificate_ids" {
  description = "The identifiers for classic SSL certificates"
  value = {
    for k, v in google_compute_ssl_certificate.classic_certificates : k => v.id
  }
}

output "classic_ssl_certificate_names" {
  description = "The names of classic SSL certificates"
  value = {
    for k, v in google_compute_ssl_certificate.classic_certificates : k => v.name
  }
}

output "classic_ssl_certificate_self_links" {
  description = "The self links of classic SSL certificates"
  value = {
    for k, v in google_compute_ssl_certificate.classic_certificates : k => v.self_link
  }
}

output "classic_ssl_certificate_creation_timestamps" {
  description = "The creation timestamps of classic SSL certificates"
  value = {
    for k, v in google_compute_ssl_certificate.classic_certificates : k => v.creation_timestamp
  }
}

output "classic_ssl_certificate_expiration_timestamps" {
  description = "The expiration timestamps of classic SSL certificates"
  value = {
    for k, v in google_compute_ssl_certificate.classic_certificates : k => v.expiration
  }
}

# Classic Managed SSL Certificate Outputs
output "classic_managed_ssl_certificate_ids" {
  description = "The identifiers for classic managed SSL certificates"
  value = {
    for k, v in google_compute_managed_ssl_certificate.classic_managed_certificates : k => v.id
  }
}

output "classic_managed_ssl_certificate_names" {
  description = "The names of classic managed SSL certificates"
  value = {
    for k, v in google_compute_managed_ssl_certificate.classic_managed_certificates : k => v.name
  }
}

output "classic_managed_ssl_certificate_self_links" {
  description = "The self links of classic managed SSL certificates"
  value = {
    for k, v in google_compute_managed_ssl_certificate.classic_managed_certificates : k => v.self_link
  }
}

output "classic_managed_ssl_certificate_creation_timestamps" {
  description = "The creation timestamps of classic managed SSL certificates"
  value = {
    for k, v in google_compute_managed_ssl_certificate.classic_managed_certificates : k => v.creation_timestamp
  }
}

output "classic_managed_ssl_certificate_statuses" {
  description = "The statuses of classic managed SSL certificates"
  value = {
    for k, v in google_compute_managed_ssl_certificate.classic_managed_certificates : k => v.status
  }
}

output "classic_managed_ssl_certificate_domain_statuses" {
  description = "The domain statuses of classic managed SSL certificates"
  value = {
    for k, v in google_compute_managed_ssl_certificate.classic_managed_certificates : k => v.managed[0].domain_status
  }
}

# SSL Policy Outputs
output "ssl_policy_ids" {
  description = "The identifiers for SSL policies"
  value = {
    for k, v in google_compute_ssl_policy.ssl_policies : k => v.id
  }
}

output "ssl_policy_names" {
  description = "The names of SSL policies"
  value = {
    for k, v in google_compute_ssl_policy.ssl_policies : k => v.name
  }
}

output "ssl_policy_self_links" {
  description = "The self links of SSL policies"
  value = {
    for k, v in google_compute_ssl_policy.ssl_policies : k => v.self_link
  }
}

output "ssl_policy_fingerprints" {
  description = "The fingerprints of SSL policies"
  value = {
    for k, v in google_compute_ssl_policy.ssl_policies : k => v.fingerprint
  }
}

output "ssl_policy_enabled_features" {
  description = "The enabled features of SSL policies"
  value = {
    for k, v in google_compute_ssl_policy.ssl_policies : k => v.enabled_features
  }
}

# Target HTTPS Proxy Outputs
output "target_https_proxy_ids" {
  description = "The identifiers for target HTTPS proxies"
  value = {
    for k, v in google_compute_target_https_proxy.proxies_with_cert_maps : k => v.id
  }
}

output "target_https_proxy_names" {
  description = "The names of target HTTPS proxies"
  value = {
    for k, v in google_compute_target_https_proxy.proxies_with_cert_maps : k => v.name
  }
}

output "target_https_proxy_self_links" {
  description = "The self links of target HTTPS proxies"
  value = {
    for k, v in google_compute_target_https_proxy.proxies_with_cert_maps : k => v.self_link
  }
}

output "target_https_proxy_creation_timestamps" {
  description = "The creation timestamps of target HTTPS proxies"
  value = {
    for k, v in google_compute_target_https_proxy.proxies_with_cert_maps : k => v.creation_timestamp
  }
}

output "target_https_proxy_proxy_ids" {
  description = "The proxy IDs of target HTTPS proxies"
  value = {
    for k, v in google_compute_target_https_proxy.proxies_with_cert_maps : k => v.proxy_id
  }
}

# Service Account Outputs
output "service_account_email" {
  description = "The email of the created service account"
  value       = var.create_service_account ? google_service_account.cert_manager[0].email : null
}

output "service_account_id" {
  description = "The unique id of the service account"
  value       = var.create_service_account ? google_service_account.cert_manager[0].unique_id : null
}

output "service_account_name" {
  description = "The fully-qualified name of the service account"
  value       = var.create_service_account ? google_service_account.cert_manager[0].name : null
}

output "service_account_member" {
  description = "The IAM member format for the service account"
  value       = var.create_service_account ? "serviceAccount:${google_service_account.cert_manager[0].email}" : null
}

# Monitoring Outputs
output "monitoring_alert_policy_ids" {
  description = "IDs of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.cert_alerts : k => v.id
  }
}

output "monitoring_alert_policy_names" {
  description = "Names of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.cert_alerts : k => v.name
  }
}

output "monitoring_dashboard_id" {
  description = "ID of the monitoring dashboard"
  value       = var.create_monitoring_dashboard ? google_monitoring_dashboard.cert_dashboard[0].id : null
}

# Notification Channel Outputs
output "notification_channel_ids" {
  description = "IDs of notification channels"
  value = {
    for k, v in google_monitoring_notification_channel.cert_notifications : k => v.id
  }
}

output "notification_channel_names" {
  description = "Names of notification channels"
  value = {
    for k, v in google_monitoring_notification_channel.cert_notifications : k => v.name
  }
}

output "notification_channel_verification_statuses" {
  description = "Verification statuses of notification channels"
  value = {
    for k, v in google_monitoring_notification_channel.cert_notifications : k => v.verification_status
  }
}

# Auto-rotation Outputs
output "rotation_function_id" {
  description = "ID of the certificate rotation function"
  value       = var.enable_auto_rotation ? google_cloudfunctions2_function.cert_rotation[0].id : null
}

output "rotation_function_uri" {
  description = "URI of the certificate rotation function"
  value       = var.enable_auto_rotation ? google_cloudfunctions2_function.cert_rotation[0].service_config[0].uri : null
}

output "rotation_schedule_id" {
  description = "ID of the certificate rotation schedule"
  value       = var.enable_auto_rotation ? google_cloud_scheduler_job.cert_rotation_schedule[0].id : null
}

output "rotation_schedule_name" {
  description = "Name of the certificate rotation schedule"
  value       = var.enable_auto_rotation ? google_cloud_scheduler_job.cert_rotation_schedule[0].name : null
}

# Certificate Configuration Summary
output "certificate_configuration_summary" {
  description = "Summary of certificate configuration"
  value = {
    total_certificates            = length(local.certificates)
    total_certificate_maps        = length(local.certificate_maps)
    total_certificate_map_entries = length(local.certificate_map_entries)
    total_dns_authorizations      = length(local.dns_authorizations)
    total_issuance_configs        = length(local.certificate_issuance_configs)
    total_trust_configs           = length(local.trust_configs)

    certificates_by_type = {
      managed      = length([for k, v in local.certificates : k if v.managed != null])
      self_managed = length([for k, v in local.certificates : k if v.self_managed != null])
    }

    certificates_by_scope = {
      default     = length([for k, v in local.certificates : k if v.scope == "DEFAULT" || v.scope == null])
      edge_cache  = length([for k, v in local.certificates : k if v.scope == "EDGE_CACHE"])
      all_regions = length([for k, v in local.certificates : k if v.scope == "ALL_REGIONS"])
    }

    classic_certificates = {
      unmanaged = length(var.classic_ssl_certificates)
      managed   = length(var.classic_managed_ssl_certificates)
    }
  }
}

# SSL Policy Configuration Summary
output "ssl_policy_configuration_summary" {
  description = "Summary of SSL policy configuration"
  value = {
    total_ssl_policies         = length(var.ssl_policies)
    total_target_https_proxies = length(var.target_https_proxies)

    ssl_policies_by_profile = {
      compatible = length([for k, v in var.ssl_policies : k if v.profile == "COMPATIBLE"])
      modern     = length([for k, v in var.ssl_policies : k if v.profile == "MODERN" || v.profile == null])
      restricted = length([for k, v in var.ssl_policies : k if v.profile == "RESTRICTED"])
      custom     = length([for k, v in var.ssl_policies : k if v.profile == "CUSTOM"])
    }

    ssl_policies_by_min_tls = {
      tls_1_0 = length([for k, v in var.ssl_policies : k if v.min_tls_version == "TLS_1_0"])
      tls_1_1 = length([for k, v in var.ssl_policies : k if v.min_tls_version == "TLS_1_1"])
      tls_1_2 = length([for k, v in var.ssl_policies : k if v.min_tls_version == "TLS_1_2" || v.min_tls_version == null])
    }

    proxies_with_quic = {
      enabled  = length([for k, v in var.target_https_proxies : k if v.quic_override == "ENABLE"])
      disabled = length([for k, v in var.target_https_proxies : k if v.quic_override == "DISABLE"])
      default  = length([for k, v in var.target_https_proxies : k if v.quic_override == "NONE" || v.quic_override == null])
    }
  }
}

# DNS Authorization Summary
output "dns_authorization_summary" {
  description = "Summary of DNS authorization configuration"
  value = {
    total_dns_authorizations = length(local.dns_authorizations)

    dns_authorizations_by_domain = {
      for domain in distinct([for v in local.dns_authorizations : v.domain]) :
      domain => length([
        for k, v in local.dns_authorizations : k
        if v.domain == domain
      ])
    }

    dns_records_to_create = {
      for k, v in google_certificate_manager_dns_authorization.dns_authorizations : k => {
        name = v.dns_resource_record[0].name
        type = v.dns_resource_record[0].type
        data = v.dns_resource_record[0].data
      }
    }
  }
}

# Certificate Expiry Summary
output "certificate_expiry_summary" {
  description = "Summary of certificate expiration dates"
  value = {
    managed_certificates = {
      for k, v in google_certificate_manager_certificate.certificates : k => v.expire_time
      if v.managed != null
    }

    classic_certificates = {
      for k, v in google_compute_ssl_certificate.classic_certificates : k => v.expiration
    }
  }
}

# Validation Configuration Summary
output "validation_configuration_summary" {
  description = "Summary of validation configuration"
  value = {
    ocsp_validation_enabled = var.validation_config.enable_ocsp_validation
    crl_validation_enabled  = var.validation_config.enable_crl_validation
    strict_validation       = var.validation_config.strict_validation
    minimum_key_size        = var.validation_config.minimum_key_size
    maximum_validity_days   = var.validation_config.maximum_validity_days
  }
}

# Compliance Configuration Summary
output "compliance_configuration_summary" {
  description = "Summary of compliance configuration"
  value = {
    cap_baseline_enforced     = var.compliance_config.enforce_cap_baseline
    mozilla_policy_enforced   = var.compliance_config.enforce_mozilla_policy
    chrome_ct_policy_enforced = var.compliance_config.enforce_chrome_ct_policy
    sct_required              = var.compliance_config.require_sct
    caa_check_required        = var.compliance_config.require_caa_check
    audit_logging_enabled     = var.compliance_config.audit_logging_enabled
  }
}

# Security Configuration Summary
output "security_configuration_summary" {
  description = "Summary of security configuration"
  value = {
    service_account_created = var.create_service_account
    service_account_roles   = var.create_service_account ? var.service_account_roles : []

    hsm_protection_enabled           = var.security_config.enable_hsm_protection
    private_ca_enabled               = var.security_config.enable_private_ca
    certificate_transparency_enabled = var.security_config.enable_certificate_transparency
    key_rotation_enabled             = var.security_config.enable_key_rotation
    key_rotation_period_days         = var.security_config.key_rotation_period_days
    backup_certificates_enabled      = var.security_config.enable_backup_certificates
  }
}

# Monitoring Configuration Summary
output "monitoring_configuration_summary" {
  description = "Summary of monitoring configuration"
  value = {
    alerts_enabled        = var.create_monitoring_alerts
    dashboard_enabled     = var.create_monitoring_dashboard
    auto_rotation_enabled = var.enable_auto_rotation

    alert_policies_count        = var.create_monitoring_alerts ? length(var.monitoring_alerts) : 0
    notification_channels_count = length(var.notification_channels)

    rotation_configuration = var.enable_auto_rotation ? {
      schedule           = var.rotation_schedule
      time_zone          = var.rotation_time_zone
      days_before_expiry = var.rotation_days_before_expiry
    } : null
  }
}

# Rate Limiting Summary
output "rate_limiting_summary" {
  description = "Summary of rate limiting configuration"
  value = {
    enabled                      = var.rate_limiting_config.enable_rate_limiting
    max_certificates_per_hour    = var.rate_limiting_config.max_certificates_per_hour
    max_renewals_per_day         = var.rate_limiting_config.max_renewals_per_day
    max_dns_validations_per_hour = var.rate_limiting_config.max_dns_validations_per_hour
  }
}

# Cost Optimization Summary
output "cost_optimization_summary" {
  description = "Summary of cost optimization configuration"
  value = {
    unused_cert_cleanup_enabled    = var.cost_optimization_config.enable_unused_cert_cleanup
    cleanup_age_days               = var.cost_optimization_config.cleanup_age_days
    wildcard_consolidation_enabled = var.cost_optimization_config.enable_wildcard_consolidation
    managed_certificates_preferred = var.cost_optimization_config.prefer_managed_certificates
    certificate_sharing_enabled    = var.cost_optimization_config.enable_certificate_sharing
  }
}

# Connection Information
output "connection_info" {
  description = "Connection information for certificate resources"
  value = {
    project_id = var.project_id
    region     = var.region

    certificates = {
      for k, v in google_certificate_manager_certificate.certificates : k => {
        id       = v.id
        name     = v.name
        scope    = v.scope
        location = v.location
        domains  = v.san_dnsnames
      }
    }

    certificate_maps = {
      for k, v in google_certificate_manager_certificate_map.certificate_maps : k => {
        id   = v.id
        name = v.name
      }
    }

    dns_authorizations = {
      for k, v in google_certificate_manager_dns_authorization.dns_authorizations : k => {
        id     = v.id
        name   = v.name
        domain = v.domain
        dns_record = {
          name = v.dns_resource_record[0].name
          type = v.dns_resource_record[0].type
          data = v.dns_resource_record[0].data
        }
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
    auto_rotation_enabled   = var.enable_auto_rotation
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
    certificates                 = length(var.certificates)
    certificate_maps             = length(var.certificate_maps)
    certificate_map_entries      = length(var.certificate_map_entries)
    dns_authorizations           = length(var.dns_authorizations)
    certificate_issuance_configs = length(var.certificate_issuance_configs)
    trust_configs                = length(var.trust_configs)
    classic_ssl_certificates     = length(var.classic_ssl_certificates)
    classic_managed_certificates = length(var.classic_managed_ssl_certificates)
    ssl_policies                 = length(var.ssl_policies)
    target_https_proxies         = length(var.target_https_proxies)
    service_accounts             = var.create_service_account ? 1 : 0
    alert_policies               = var.create_monitoring_alerts ? length(var.monitoring_alerts) : 0
    dashboards                   = var.create_monitoring_dashboard ? 1 : 0
    notification_channels        = length(var.notification_channels)
    rotation_functions           = var.enable_auto_rotation ? 1 : 0
    rotation_schedules           = var.enable_auto_rotation ? 1 : 0
  }
}