# Binary Authorization Module - Outputs

# Policy outputs
output "policy_id" {
  description = "The ID of the Binary Authorization policy"
  value       = google_binary_authorization_policy.policy.id
}

output "policy_global_evaluation_mode" {
  description = "The global evaluation mode of the policy"
  value       = google_binary_authorization_policy.policy.global_policy_evaluation_mode
}

output "policy_description" {
  description = "The description of the Binary Authorization policy"
  value       = google_binary_authorization_policy.policy.description
}

output "policy_etag" {
  description = "The etag of the Binary Authorization policy"
  value       = google_binary_authorization_policy.policy.etag
}

# Attestor outputs
output "attestor_names" {
  description = "Names of all created attestors"
  value = {
    for k, v in google_binary_authorization_attestor.attestors : k => v.name
  }
}

output "attestor_ids" {
  description = "IDs of all created attestors"
  value = {
    for k, v in google_binary_authorization_attestor.attestors : k => v.id
  }
}

output "attestor_details" {
  description = "Detailed information about all attestors"
  value = {
    for k, v in google_binary_authorization_attestor.attestors : k => {
      name        = v.name
      id          = v.id
      description = v.description
      project     = v.project
    }
  }
}

# Container Analysis Notes outputs
output "container_analysis_note_names" {
  description = "Names of Container Analysis notes"
  value = {
    for k, v in google_container_analysis_note.attestation_notes : k => v.name
  }
}

output "container_analysis_note_ids" {
  description = "IDs of Container Analysis notes"
  value = {
    for k, v in google_container_analysis_note.attestation_notes : k => v.id
  }
}

output "container_analysis_note_details" {
  description = "Detailed information about Container Analysis notes"
  value = {
    for k, v in google_container_analysis_note.attestation_notes : k => {
      name              = v.name
      id                = v.id
      short_description = v.short_description
      long_description  = v.long_description
      kind              = v.kind
      project           = v.project
    }
  }
}

# KMS outputs
output "kms_keyring_id" {
  description = "The ID of the KMS keyring for attestation signing"
  value       = var.enable_kms_signing ? google_kms_key_ring.attestation_keyring[0].id : null
}

output "kms_keyring_location" {
  description = "The location of the KMS keyring"
  value       = var.enable_kms_signing ? google_kms_key_ring.attestation_keyring[0].location : null
}

output "kms_crypto_key_id" {
  description = "The ID of the KMS crypto key for attestation signing"
  value       = var.enable_kms_signing ? google_kms_crypto_key.attestation_key[0].id : null
}

output "kms_crypto_key_name" {
  description = "The name of the KMS crypto key"
  value       = var.enable_kms_signing ? google_kms_crypto_key.attestation_key[0].name : null
}

# Service Account outputs
output "attestation_service_account_email" {
  description = "Email of the attestation service account"
  value       = google_service_account.attestation_sa.email
}

output "attestation_service_account_id" {
  description = "ID of the attestation service account"
  value       = google_service_account.attestation_sa.account_id
}

output "attestation_service_account_unique_id" {
  description = "Unique ID of the attestation service account"
  value       = google_service_account.attestation_sa.unique_id
}

# Cloud Build outputs
output "cloud_build_trigger_ids" {
  description = "IDs of Cloud Build triggers for automated attestation"
  value = {
    for k, v in google_cloudbuild_trigger.attestation_triggers : k => v.id
  }
}

output "cloud_build_trigger_names" {
  description = "Names of Cloud Build triggers"
  value = {
    for k, v in google_cloudbuild_trigger.attestation_triggers : k => v.name
  }
}

output "cloud_build_trigger_details" {
  description = "Detailed information about Cloud Build triggers"
  value = {
    for k, v in google_cloudbuild_trigger.attestation_triggers : k => {
      id          = v.id
      name        = v.name
      description = v.description
      project     = v.project
      location    = v.location
    }
  }
}

# Monitoring outputs
output "monitoring_dashboard_id" {
  description = "ID of the Binary Authorization monitoring dashboard"
  value       = var.enable_monitoring ? google_monitoring_dashboard.binary_auth_dashboard[0].id : null
}

output "monitoring_dashboard_url" {
  description = "URL to the Binary Authorization monitoring dashboard"
  value = var.enable_monitoring ? (
    "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.binary_auth_dashboard[0].id}?project=${var.project_id}"
  ) : null
}

output "alert_policy_ids" {
  description = "IDs of created alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.binary_auth_alerts : k => v.id
  }
}

output "alert_policy_names" {
  description = "Names of created alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.binary_auth_alerts : k => v.display_name
  }
}

# Configuration metadata outputs
output "configuration_metadata" {
  description = "Metadata about the Binary Authorization configuration"
  value = {
    project_id                      = var.project_id
    global_policy_evaluation_mode   = var.global_policy_evaluation_mode
    total_attestors                 = length(google_binary_authorization_attestor.attestors)
    total_container_analysis_notes  = length(google_container_analysis_note.attestation_notes)
    kms_signing_enabled             = var.enable_kms_signing
    vulnerability_scanning_enabled  = var.enable_vulnerability_scanning
    continuous_validation_enabled   = var.continuous_validation_config.enabled
    monitoring_enabled              = var.enable_monitoring
    breakglass_enabled              = var.enable_breakglass
    supply_chain_validation_enabled = var.enable_supply_chain_validation
    cloud_build_integration_enabled = var.enable_cloud_build_integration
    total_cloud_build_triggers      = length(google_cloudbuild_trigger.attestation_triggers)
    total_alert_policies            = length(google_monitoring_alert_policy.binary_auth_alerts)
  }
}

# Policy rule summaries
output "admission_rule_summary" {
  description = "Summary of all admission rules"
  value = {
    default_rule = {
      evaluation_mode  = var.default_admission_rule.evaluation_mode
      enforcement_mode = var.default_admission_rule.enforcement_mode
      attestors_count  = length(var.default_admission_rule.require_attestations_by)
    }
    cluster_rules = {
      for k, v in var.cluster_admission_rules : k => {
        cluster_name     = v.cluster_resource_name
        evaluation_mode  = v.evaluation_mode
        enforcement_mode = v.enforcement_mode
        attestors_count  = length(v.require_attestations_by)
      }
    }
    namespace_rules = {
      for k, v in var.kubernetes_namespace_admission_rules : k => {
        cluster_name     = v.cluster_resource_name
        namespace_name   = v.namespace_name
        evaluation_mode  = v.evaluation_mode
        enforcement_mode = v.enforcement_mode
        attestors_count  = length(v.require_attestations_by)
      }
    }
    service_account_rules = {
      for k, v in var.kubernetes_service_account_admission_rules : k => {
        cluster_name         = v.cluster_resource_name
        namespace_name       = v.namespace_name
        service_account_name = v.service_account_name
        evaluation_mode      = v.evaluation_mode
        enforcement_mode     = v.enforcement_mode
        attestors_count      = length(v.require_attestations_by)
      }
    }
    cloud_run_rules = {
      for k, v in var.cloud_run_admission_rules : k => {
        location         = v.location
        service_name     = v.service_name
        evaluation_mode  = v.evaluation_mode
        enforcement_mode = v.enforcement_mode
        attestors_count  = length(v.require_attestations_by)
      }
    }
  }
}

# Attestation authority outputs
output "attestation_authority_note_names" {
  description = "Note names for attestation authorities"
  value = {
    for k, v in google_binary_authorization_attestor.attestors : k => (
      v.attestation_authority_note != null ? v.attestation_authority_note[0].note_reference : null
    )
  }
}

output "user_owned_grafeas_note_names" {
  description = "Note names for user-owned Grafeas notes"
  value = {
    for k, v in google_binary_authorization_attestor.attestors : k => (
      v.user_owned_grafeas_note != null ? v.user_owned_grafeas_note[0].note_reference : null
    )
  }
}

# Public key information
output "attestor_public_keys" {
  description = "Public key information for attestors"
  value = {
    for attestor_key, attestor in var.attestors : attestor_key => {
      attestation_authority_keys = attestor.attestation_authority_note != null ? [
        for key in attestor.attestation_authority_note.public_keys : {
          id      = key.id
          comment = key.comment
          type    = key.ascii_armored_pgp != null ? "PGP" : "PKIX"
        }
      ] : []
      user_owned_grafeas_keys = attestor.user_owned_grafeas_note != null ? [
        for key in attestor.user_owned_grafeas_note.public_keys : {
          id      = key.id
          comment = key.comment
          type    = key.ascii_armored_pgp != null ? "PGP" : "PKIX"
        }
      ] : []
    }
  }
  sensitive = true
}

# Security configuration summary
output "security_configuration" {
  description = "Summary of security configuration"
  value = {
    policy_enforcement = {
      global_mode        = var.global_policy_evaluation_mode
      dry_run_enabled    = var.enable_dry_run
      breakglass_enabled = var.enable_breakglass
    }
    vulnerability_protection = {
      scanning_enabled      = var.enable_vulnerability_scanning
      severity_threshold    = var.vulnerability_scanning_config.severity_threshold
      cvss_threshold        = var.vulnerability_scanning_config.cvss_threshold
      continuous_validation = var.continuous_validation_config.enabled
    }
    image_verification = {
      require_signed_images = var.image_signing_config.require_signed_images
      trusted_registries    = length(var.trusted_registries)
      blocked_registries    = length(var.blocked_registries)
      kms_signing_enabled   = var.enable_kms_signing
    }
    supply_chain = {
      validation_enabled  = var.enable_supply_chain_validation
      provenance_required = var.supply_chain_validation_config.require_provenance
      sbom_required       = var.supply_chain_validation_config.require_sbom
      trusted_builders    = length(var.supply_chain_validation_config.trusted_builders)
    }
    compliance = {
      cis_benchmark   = var.compliance_standards.cis_benchmark
      pci_dss         = var.compliance_standards.pci_dss
      hipaa           = var.compliance_standards.hipaa
      nist_800_53     = var.compliance_standards.nist_800_53
      iso_27001       = var.compliance_standards.iso_27001
      custom_policies = length(var.compliance_standards.custom_policies)
    }
  }
}

# Platform integration outputs
output "platform_integration" {
  description = "Platform integration status"
  value = {
    gke = {
      enabled      = var.platform_policies.gke != null ? var.platform_policies.gke.enabled : false
      platforms    = var.platform_policies.gke != null ? var.platform_policies.gke.deployment_platforms : []
      attestations = var.platform_policies.gke != null ? length(var.platform_policies.gke.required_attestations) : 0
    }
    cloud_run = {
      enabled      = var.platform_policies.cloud_run != null ? var.platform_policies.cloud_run.enabled : false
      platforms    = var.platform_policies.cloud_run != null ? var.platform_policies.cloud_run.deployment_platforms : []
      attestations = var.platform_policies.cloud_run != null ? length(var.platform_policies.cloud_run.required_attestations) : 0
    }
    compute_engine = {
      enabled      = var.platform_policies.compute_engine != null ? var.platform_policies.compute_engine.enabled : false
      platforms    = var.platform_policies.compute_engine != null ? var.platform_policies.compute_engine.deployment_platforms : []
      attestations = var.platform_policies.compute_engine != null ? length(var.platform_policies.compute_engine.required_attestations) : 0
    }
  }
}

# Operational outputs
output "operational_configuration" {
  description = "Operational configuration details"
  value = {
    monitoring = {
      enabled              = var.enable_monitoring
      metrics_enabled      = var.monitoring_config.enable_metrics
      logging_enabled      = var.monitoring_config.enable_logging
      log_severity         = var.monitoring_config.log_severity_filter
      alert_policies_count = length(var.monitoring_config.alert_policies)
    }
    automation = {
      cloud_build_enabled   = var.enable_cloud_build_integration
      automated_remediation = var.enable_automated_remediation
      continuous_validation = var.continuous_validation_config.enabled
      policy_sync_enabled   = var.enable_policy_data_sync
    }
    cost_optimization = {
      enabled            = var.enable_cost_optimization
      cache_enabled      = var.cost_optimization_config.cache_attestations
      batch_verification = var.cost_optimization_config.batch_verification
      kms_optimization   = var.cost_optimization_config.optimize_kms_calls
    }
  }
}

# IAM outputs
output "iam_configuration" {
  description = "IAM configuration for Binary Authorization"
  value = {
    service_account_email  = google_service_account.attestation_sa.email
    policy_bindings_count  = length(var.policy_bindings)
    attestor_iam_bindings  = length(var.attestation_authority_iam_bindings)
    cross_project_enabled  = var.enable_cross_project_attestation
    trusted_projects_count = length(var.cross_project_config.trusted_projects)
  }
}

# API and service status
output "api_status" {
  description = "Status of enabled APIs and services"
  value = {
    apis_enabled             = var.enable_apis
    binary_authorization_api = var.enable_apis
    container_analysis_api   = var.enable_apis
    cloud_kms_api            = var.enable_kms_signing
    cloud_build_api          = var.enable_cloud_build_integration
    monitoring_api           = var.enable_monitoring
  }
}

# Policy validation outputs
output "policy_validation" {
  description = "Policy validation and compliance status"
  value = {
    admission_whitelist_patterns = length(var.admission_whitelist_patterns)
    trusted_registries_count     = length(var.trusted_registries)
    blocked_registries_count     = length(var.blocked_registries)
    image_freshness_enabled      = var.image_freshness_config.enabled
    max_image_age_days           = var.image_freshness_config.max_image_age_days
    exemption_config_enabled     = var.exemption_config.enabled
    custom_validation_rules      = length(var.custom_attestor_validation_rules)
  }
}

# Network security outputs
output "network_security" {
  description = "Network security configuration"
  value = {
    private_endpoints_enabled = var.network_policy_config.enable_private_endpoints
    allowed_networks_count    = length(var.network_policy_config.allowed_networks)
    denied_networks_count     = length(var.network_policy_config.denied_networks)
    vpc_flow_logs_enabled     = var.network_policy_config.enable_vpc_flow_logs
  }
}

# Quota and rate limiting
output "quota_configuration" {
  description = "Quota and rate limiting configuration"
  value = {
    rate_limit_configs              = length(var.rate_limit_configs)
    cors_configs                    = length(var.cors_configs)
    backend_service_configs         = length(var.backend_service_configs)
    vulnerability_scan_timeout      = var.vulnerability_scanning_config.scan_timeout
    continuous_validation_frequency = var.continuous_validation_config.check_frequency
  }
}

# Management URLs
output "management_urls" {
  description = "URLs for managing Binary Authorization resources"
  value = {
    binary_authorization_console = "https://console.cloud.google.com/security/binary-authorization?project=${var.project_id}"
    container_analysis_console   = "https://console.cloud.google.com/gcr/images?project=${var.project_id}"
    kms_console                  = var.enable_kms_signing ? "https://console.cloud.google.com/security/kms?project=${var.project_id}" : null
    cloud_build_console          = var.enable_cloud_build_integration ? "https://console.cloud.google.com/cloud-build?project=${var.project_id}" : null
    monitoring_console           = var.enable_monitoring ? "https://console.cloud.google.com/monitoring?project=${var.project_id}" : null
    audit_logs_console           = "https://console.cloud.google.com/logs/query?project=${var.project_id}"
  }
}

# Resource identifiers for integration
output "resource_identifiers" {
  description = "Resource identifiers for integration with other modules"
  value = {
    policy_resource_name = google_binary_authorization_policy.policy.id
    attestor_resource_names = {
      for k, v in google_binary_authorization_attestor.attestors : k => v.id
    }
    kms_key_resource_name         = var.enable_kms_signing ? google_kms_crypto_key.attestation_key[0].id : null
    service_account_resource_name = google_service_account.attestation_sa.id
    container_analysis_note_names = {
      for k, v in google_container_analysis_note.attestation_notes : k => v.id
    }
  }
}