# Cloud Armor Module Outputs

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

output "security_policy_types" {
  description = "The types of security policies"
  value = {
    for k, v in google_compute_security_policy.security_policies : k => v.type
  }
}

# Edge Security Policy Outputs
output "edge_security_policy_ids" {
  description = "The identifiers for edge security policies"
  value = {
    for k, v in google_compute_security_policy.edge_security_policies : k => v.id
  }
}

output "edge_security_policy_names" {
  description = "The names of edge security policies"
  value = {
    for k, v in google_compute_security_policy.edge_security_policies : k => v.name
  }
}

output "edge_security_policy_self_links" {
  description = "The self links of edge security policies"
  value = {
    for k, v in google_compute_security_policy.edge_security_policies : k => v.self_link
  }
}

# WAF Exclusion Policy Outputs
output "waf_exclusion_policy_ids" {
  description = "The identifiers for WAF exclusion policies"
  value = {
    for k, v in google_compute_security_policy.waf_exclusions : k => v.id
  }
}

output "waf_exclusion_policy_names" {
  description = "The names of WAF exclusion policies"
  value = {
    for k, v in google_compute_security_policy.waf_exclusions : k => v.name
  }
}

output "waf_exclusion_policy_self_links" {
  description = "The self links of WAF exclusion policies"
  value = {
    for k, v in google_compute_security_policy.waf_exclusions : k => v.self_link
  }
}

# Backend Service Outputs
output "backend_service_with_security_policy_ids" {
  description = "The identifiers for backend services with security policies"
  value = {
    for k, v in google_compute_backend_service.backend_service_with_security_policy : k => v.id
  }
}

output "backend_service_with_security_policy_names" {
  description = "The names of backend services with security policies"
  value = {
    for k, v in google_compute_backend_service.backend_service_with_security_policy : k => v.name
  }
}

output "backend_service_security_policies" {
  description = "The security policies attached to backend services"
  value = {
    for k, v in google_compute_backend_service.backend_service_with_security_policy : k => v.security_policy
  }
}

# Service Account Outputs
output "service_account_email" {
  description = "The email of the created service account"
  value       = var.create_service_account ? google_service_account.armor[0].email : null
}

output "service_account_id" {
  description = "The unique id of the service account"
  value       = var.create_service_account ? google_service_account.armor[0].unique_id : null
}

output "service_account_name" {
  description = "The fully-qualified name of the service account"
  value       = var.create_service_account ? google_service_account.armor[0].name : null
}

output "service_account_member" {
  description = "The IAM member format for the service account"
  value       = var.create_service_account ? "serviceAccount:${google_service_account.armor[0].email}" : null
}

# Monitoring Outputs
output "monitoring_alert_policy_ids" {
  description = "IDs of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.armor_alerts : k => v.id
  }
}

output "monitoring_alert_policy_names" {
  description = "Names of created monitoring alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.armor_alerts : k => v.name
  }
}

output "monitoring_dashboard_id" {
  description = "ID of the monitoring dashboard"
  value       = var.create_monitoring_dashboard ? google_monitoring_dashboard.armor[0].id : null
}

# Log Metrics Outputs
output "log_metric_names" {
  description = "Names of created log-based metrics"
  value = {
    for k, v in google_logging_metric.security_metrics : k => v.name
  }
}

output "log_metric_ids" {
  description = "IDs of created log-based metrics"
  value = {
    for k, v in google_logging_metric.security_metrics : k => v.id
  }
}

# Notification Channel Outputs
output "notification_channel_ids" {
  description = "IDs of created notification channels"
  value = {
    for k, v in google_monitoring_notification_channel.security_notifications : k => v.id
  }
}

output "notification_channel_names" {
  description = "Names of created notification channels"
  value = {
    for k, v in google_monitoring_notification_channel.security_notifications : k => v.name
  }
}

# Security Response Function Outputs
output "security_response_function_ids" {
  description = "IDs of created security response functions"
  value = {
    for k, v in google_cloudfunctions_function.security_response : k => v.id
  }
}

output "security_response_function_names" {
  description = "Names of created security response functions"
  value = {
    for k, v in google_cloudfunctions_function.security_response : k => v.name
  }
}

output "security_response_function_trigger_urls" {
  description = "Trigger URLs for security response functions"
  value = {
    for k, v in google_cloudfunctions_function.security_response : k => v.https_trigger_url
    if v.https_trigger_url != null
  }
}

# Security Configuration Summary
output "security_configuration_summary" {
  description = "Summary of security configuration"
  value = {
    total_security_policies     = length(local.security_policies)
    edge_security_policies     = length(local.edge_security_policies)
    waf_exclusion_policies     = length(var.waf_exclusion_policies)
    policy_attachments         = length(local.policy_attachments)

    features_enabled = {
      ddos_protection     = var.enable_ddos_protection
      bot_management      = var.enable_bot_management
      rate_limiting       = var.enable_rate_limiting
      geo_blocking        = var.enable_geo_blocking
      owasp_rules        = var.enable_owasp_rules
      adaptive_protection = var.advanced_security_config.enable_adaptive_protection
    }

    compliance_features = {
      pci_dss_compliance = var.compliance_config.pci_dss_compliance
      gdpr_compliance   = var.compliance_config.gdpr_compliance
      hipaa_compliance  = var.compliance_config.hipaa_compliance
      sox_compliance    = var.compliance_config.sox_compliance
      audit_logging     = var.compliance_config.audit_logging_enabled
    }
  }
}

# Rule Summary by Policy
output "security_rules_summary" {
  description = "Summary of security rules by policy"
  value = {
    for policy_name, policy in local.security_policies : policy_name => {
      default_action           = policy.default_rule.action
      rate_limit_rules_count  = length(policy.rate_limit_rules)
      geo_rules_count         = length(policy.geo_rules)
      ip_rules_count          = length(policy.ip_rules)
      custom_rules_count      = length(policy.custom_rules)
      owasp_rules_count       = length(policy.owasp_rules)
      bot_management_rules_count = length(policy.bot_management_rules)

      adaptive_protection = {
        layer_7_ddos_enabled = policy.adaptive_protection_config.layer_7_ddos_defense_config.enable
        rule_visibility     = policy.adaptive_protection_config.layer_7_ddos_defense_config.rule_visibility
      }

      advanced_options = {
        json_parsing = policy.advanced_options_config.json_parsing
        log_level   = policy.advanced_options_config.log_level
      }
    }
  }
}

# IP Management Summary
output "ip_management_summary" {
  description = "Summary of IP allowlists and blocklists"
  value = {
    allowlists = {
      for name, config in var.ip_allowlists : name => {
        priority  = config.priority
        ip_count = length(config.ip_ranges)
        action   = config.action
      }
    }

    blocklists = {
      for name, config in var.ip_blocklists : name => {
        priority  = config.priority
        ip_count = length(config.ip_ranges)
        action   = config.action
      }
    }

    geographic_blocking = {
      enabled          = var.enable_geo_blocking
      blocked_countries = var.blocked_countries
      allowed_countries = var.allowed_countries
    }
  }
}

# Rate Limiting Summary
output "rate_limiting_summary" {
  description = "Summary of rate limiting configuration"
  value = {
    enabled = var.enable_rate_limiting
    default_config = {
      requests_per_minute = var.default_rate_limit.requests_per_minute
      burst_capacity     = var.default_rate_limit.burst_capacity
      ban_duration_sec   = var.default_rate_limit.ban_duration_sec
    }

    custom_rate_limits = {
      for policy_name, policy in local.security_policies : policy_name => {
        rate_limit_rules = [
          for rule in policy.rate_limit_rules : {
            priority     = rule.priority
            action      = rule.action
            threshold   = rule.rate_limit_options.rate_limit_threshold
            ban_duration = rule.rate_limit_options.ban_duration_sec
          }
        ]
      }
      if length(policy.rate_limit_rules) > 0
    }
  }
}

# Security Monitoring Summary
output "security_monitoring_summary" {
  description = "Summary of security monitoring configuration"
  value = {
    monitoring_enabled = var.create_monitoring_alerts
    dashboard_created  = var.create_monitoring_dashboard
    log_metrics_enabled = var.create_log_metrics

    alert_policies_count    = var.create_monitoring_alerts ? length(var.monitoring_alerts) : 0
    log_metrics_count      = var.create_log_metrics ? length(var.log_metrics) : 0
    notification_channels_count = length(var.notification_channels)

    integration_status = {
      cloud_logging   = var.integration_config.cloud_logging_enabled
      cloud_monitoring = var.integration_config.cloud_monitoring_enabled
      security_command_center = var.integration_config.security_command_center
      third_party_siem = var.integration_config.third_party_siem.enabled
    }
  }
}

# Advanced Security Features Summary
output "advanced_security_features" {
  description = "Summary of advanced security features"
  value = {
    adaptive_protection = {
      enabled = var.advanced_security_config.enable_adaptive_protection
      policies_with_adaptive_protection = [
        for policy_name, policy in local.security_policies : policy_name
        if policy.adaptive_protection_config.layer_7_ddos_defense_config.enable
      ]
    }

    preview_mode = {
      enabled = var.advanced_security_config.enable_preview_mode
      policies_in_preview = [
        for policy_name, policy in local.security_policies : policy_name
        if contains([
          for rule in concat(
            policy.rate_limit_rules,
            policy.geo_rules,
            policy.ip_rules,
            policy.custom_rules,
            policy.owasp_rules,
            policy.bot_management_rules
          ) : rule.preview if rule.preview == true
        ], true)
      ]
    }

    json_parsing = {
      enabled = var.advanced_security_config.enable_json_parsing
      policies_with_json_parsing = [
        for policy_name, policy in local.security_policies : policy_name
        if policy.advanced_options_config.json_parsing == "STANDARD"
      ]
    }

    verbose_logging = {
      enabled = var.advanced_security_config.enable_verbose_logging
      policies_with_verbose_logging = [
        for policy_name, policy in local.security_policies : policy_name
        if policy.advanced_options_config.log_level == "VERBOSE"
      ]
    }
  }
}

# WAF Configuration Summary
output "waf_configuration_summary" {
  description = "Summary of WAF configuration"
  value = {
    owasp_rules_enabled = var.enable_owasp_rules
    owasp_sensitivity  = var.owasp_rule_sensitivity

    waf_exclusions = {
      for policy_name, policy in var.waf_exclusion_policies : policy_name => {
        rules_count = length(policy.waf_rules)
        exclusions_per_rule = {
          for idx, rule in policy.waf_rules : idx => length(rule.exclusions)
        }
      }
    }

    policies_with_owasp = [
      for policy_name, policy in local.security_policies : policy_name
      if length(policy.owasp_rules) > 0
    ]
  }
}

# Connection Information
output "connection_info" {
  description = "Connection information for Cloud Armor integration"
  value = {
    project_id = var.project_id
    region    = var.region

    security_policies = {
      for k, v in google_compute_security_policy.security_policies : k => {
        policy_id   = v.id
        policy_name = v.name
        self_link  = v.self_link
        type       = v.type
      }
    }

    edge_policies = {
      for k, v in google_compute_security_policy.edge_security_policies : k => {
        policy_id   = v.id
        policy_name = v.name
        self_link  = v.self_link
        type       = v.type
      }
    }
  }
  sensitive = false
}

# Module Metadata
output "module_configuration" {
  description = "Module configuration summary"
  value = {
    project_id               = var.project_id
    region                  = var.region
    environment             = local.environment
    name_prefix             = local.name_prefix
    service_account_created = var.create_service_account
    monitoring_enabled      = var.create_monitoring_alerts
    dashboard_created       = var.create_monitoring_dashboard
    log_metrics_enabled     = var.create_log_metrics
    response_functions_enabled = var.create_security_response_functions
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
    security_policies           = length(var.security_policies)
    edge_security_policies     = length(var.edge_security_policies)
    waf_exclusion_policies     = length(var.waf_exclusion_policies)
    backend_services_with_policies = length(var.policy_attachments)
    service_accounts           = var.create_service_account ? 1 : 0
    alert_policies            = var.create_monitoring_alerts ? length(var.monitoring_alerts) : 0
    dashboards               = var.create_monitoring_dashboard ? 1 : 0
    log_metrics              = var.create_log_metrics ? length(var.log_metrics) : 0
    notification_channels     = length(var.notification_channels)
    security_response_functions = var.create_security_response_functions ? length(var.security_response_functions) : 0
  }
}

# Cost Summary
output "cost_summary" {
  description = "Summary of cost-related information"
  value = {
    standard_policies_count = length([
      for policy_name, policy in local.security_policies : policy_name
      if policy.type == "CLOUD_ARMOR"
    ])

    edge_policies_count = length([
      for policy_name, policy in local.security_policies : policy_name
      if policy.type == "CLOUD_ARMOR_EDGE"
    ])

    adaptive_protection_policies = length([
      for policy_name, policy in local.security_policies : policy_name
      if policy.adaptive_protection_config.layer_7_ddos_defense_config.enable
    ])

    premium_features = {
      adaptive_protection = var.advanced_security_config.enable_adaptive_protection
      bot_management     = var.enable_bot_management
      advanced_rate_limiting = var.enable_rate_limiting
    }
  }
}