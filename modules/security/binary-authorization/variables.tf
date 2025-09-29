# Binary Authorization Module - Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "enable_apis" {
  description = "Whether to enable required GCP APIs"
  type        = bool
  default     = true
}

variable "global_policy_evaluation_mode" {
  description = "Mode for global policy evaluation. Options: 'ENABLE', 'DISABLE', 'DRY_RUN'"
  type        = string
  default     = "ENABLE"
  validation {
    condition     = contains(["ENABLE", "DISABLE", "DRY_RUN"], var.global_policy_evaluation_mode)
    error_message = "Global policy evaluation mode must be 'ENABLE', 'DISABLE', or 'DRY_RUN'"
  }
}

variable "policy_description" {
  description = "Description of the Binary Authorization policy"
  type        = string
  default     = "Binary Authorization policy for container image verification"
}

variable "admission_whitelist_patterns" {
  description = "List of image name patterns to whitelist in admission policy"
  type        = list(string)
  default     = []
}

variable "default_admission_rule" {
  description = "Default admission rule configuration"
  type = object({
    evaluation_mode  = string
    enforcement_mode = string
    require_attestations_by = list(string)
  })
  default = {
    evaluation_mode  = "REQUIRE_ATTESTATION"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = []
  }
}

variable "cluster_admission_rules" {
  description = "Admission rules for specific GKE clusters"
  type = map(object({
    cluster_resource_name = string
    evaluation_mode       = string
    enforcement_mode      = string
    require_attestations_by = list(string)
  }))
  default = {}
}

variable "kubernetes_namespace_admission_rules" {
  description = "Admission rules for specific Kubernetes namespaces"
  type = map(object({
    cluster_resource_name = string
    namespace_name        = string
    evaluation_mode       = string
    enforcement_mode      = string
    require_attestations_by = list(string)
  }))
  default = {}
}

variable "kubernetes_service_account_admission_rules" {
  description = "Admission rules for specific Kubernetes service accounts"
  type = map(object({
    cluster_resource_name = string
    namespace_name        = string
    service_account_name  = string
    evaluation_mode       = string
    enforcement_mode      = string
    require_attestations_by = list(string)
  }))
  default = {}
}

variable "cloud_run_admission_rules" {
  description = "Admission rules for Cloud Run services"
  type = map(object({
    location         = string
    service_name     = string
    evaluation_mode  = string
    enforcement_mode = string
    require_attestations_by = list(string)
  }))
  default = {}
}

variable "attestors" {
  description = "Configuration for Binary Authorization attestors"
  type = map(object({
    description = string
    attestation_authority_note = object({
      note_reference = string
      public_keys = list(object({
        id                = string
        ascii_armored_pgp = optional(string)
        pkix_public_key = optional(object({
          public_key_pem     = string
          signature_algorithm = string
        }))
        comment = optional(string)
      }))
      delegation_service_account_email = optional(string)
    })
    user_owned_grafeas_note = optional(object({
      note_reference = string
      public_keys = list(object({
        id                = string
        ascii_armored_pgp = optional(string)
        pkix_public_key = optional(object({
          public_key_pem     = string
          signature_algorithm = string
        }))
        comment = optional(string)
      }))
      delegation_service_account_email = optional(string)
    }))
  }))
  default = {}
}

variable "container_analysis_notes" {
  description = "Container Analysis notes for attestations"
  type = map(object({
    short_description = string
    long_description  = optional(string)
    expiration_time   = optional(string)
    related_urls = optional(list(object({
      url   = string
      label = optional(string)
    })))
    attestation = object({
      hint = object({
        human_readable_name = string
      })
    })
    related_note_names = optional(list(string))
  }))
  default = {}
}

variable "enable_vulnerability_scanning" {
  description = "Whether to enable vulnerability scanning integration"
  type        = bool
  default     = true
}

variable "vulnerability_scanning_config" {
  description = "Configuration for vulnerability scanning"
  type = object({
    severity_threshold   = string
    cvss_threshold      = number
    max_unfixable_severity = string
    allowed_cve_ids     = list(string)
    blocked_cve_ids     = list(string)
    scan_timeout        = string
  })
  default = {
    severity_threshold   = "MEDIUM"
    cvss_threshold      = 7.0
    max_unfixable_severity = "MEDIUM"
    allowed_cve_ids     = []
    blocked_cve_ids     = []
    scan_timeout        = "300s"
  }
}

variable "enable_continuous_validation" {
  description = "Whether to enable continuous validation for deployed images"
  type        = bool
  default     = true
}

variable "continuous_validation_config" {
  description = "Configuration for continuous validation"
  type = object({
    enabled                        = bool
    check_frequency               = string
    enforce_policy               = bool
    notification_config = optional(object({
      pubsub_topic = string
    }))
  })
  default = {
    enabled                        = true
    check_frequency               = "86400s"
    enforce_policy               = true
    notification_config = null
  }
}

variable "enable_platform_policies" {
  description = "Whether to enable platform-specific policies"
  type        = bool
  default     = true
}

variable "platform_policies" {
  description = "Platform-specific Binary Authorization policies"
  type = object({
    gke = optional(object({
      enabled                = bool
      deployment_platforms   = list(string)
      required_attestations  = list(string)
    }))
    cloud_run = optional(object({
      enabled                = bool
      deployment_platforms   = list(string)
      required_attestations  = list(string)
    }))
    compute_engine = optional(object({
      enabled                = bool
      deployment_platforms   = list(string)
      required_attestations  = list(string)
    }))
  })
  default = {
    gke = {
      enabled                = true
      deployment_platforms   = ["GKE"]
      required_attestations  = []
    }
    cloud_run = {
      enabled                = true
      deployment_platforms   = ["CLOUD_RUN"]
      required_attestations  = []
    }
    compute_engine = {
      enabled                = false
      deployment_platforms   = []
      required_attestations  = []
    }
  }
}

variable "enable_kms_signing" {
  description = "Whether to enable KMS-based signing for attestations"
  type        = bool
  default     = true
}

variable "kms_config" {
  description = "KMS configuration for attestation signing"
  type = object({
    keyring_location = string
    keyring_name     = string
    key_name         = string
    key_algorithm    = string
    protection_level = string
    rotation_period  = string
  })
  default = {
    keyring_location = "global"
    keyring_name     = "binary-authorization-keyring"
    key_name         = "attestation-signing-key"
    key_algorithm    = "RSA_SIGN_PSS_2048_SHA256"
    protection_level = "SOFTWARE"
    rotation_period  = "7776000s"
  }
}

variable "enable_breakglass" {
  description = "Whether to enable break-glass access for emergency deployments"
  type        = bool
  default     = true
}

variable "breakglass_config" {
  description = "Configuration for break-glass access"
  type = object({
    justification_required = bool
    audit_logging         = bool
    notification_emails   = list(string)
    allowed_users        = list(string)
    expiration_duration  = string
  })
  default = {
    justification_required = true
    audit_logging         = true
    notification_emails   = []
    allowed_users        = []
    expiration_duration  = "3600s"
  }
}

variable "trusted_registries" {
  description = "List of trusted container registries"
  type        = list(string)
  default = [
    "gcr.io/*",
    "*.gcr.io/*",
    "*.pkg.dev/*"
  ]
}

variable "blocked_registries" {
  description = "List of blocked container registries"
  type        = list(string)
  default = []
}

variable "trusted_directory_patterns" {
  description = "List of trusted directory patterns for images"
  type        = list(string)
  default = []
}

variable "image_signing_config" {
  description = "Configuration for image signing requirements"
  type = object({
    require_signed_images = bool
    allowed_signers      = list(string)
    signature_algorithms = list(string)
    key_versions        = list(string)
  })
  default = {
    require_signed_images = true
    allowed_signers      = []
    signature_algorithms = ["RSA_PSS", "ECDSA_P256_SHA256"]
    key_versions        = []
  }
}

variable "enable_monitoring" {
  description = "Whether to enable monitoring for Binary Authorization"
  type        = bool
  default     = true
}

variable "monitoring_config" {
  description = "Configuration for monitoring and alerting"
  type = object({
    enable_metrics      = bool
    enable_logging      = bool
    log_severity_filter = string
    metrics_namespace   = string
    alert_policies = list(object({
      display_name = string
      condition    = string
      threshold    = number
      duration     = string
    }))
  })
  default = {
    enable_metrics      = true
    enable_logging      = true
    log_severity_filter = "WARNING"
    metrics_namespace   = "binary_authorization"
    alert_policies     = []
  }
}

variable "enable_policy_bindings" {
  description = "Whether to enable IAM policy bindings for Binary Authorization"
  type        = bool
  default     = true
}

variable "policy_bindings" {
  description = "IAM policy bindings for Binary Authorization"
  type = map(object({
    role    = string
    members = list(string)
    condition = optional(object({
      title       = string
      description = string
      expression  = string
    }))
  }))
  default = {}
}

variable "enable_supply_chain_validation" {
  description = "Whether to enable supply chain validation"
  type        = bool
  default     = false
}

variable "supply_chain_validation_config" {
  description = "Configuration for supply chain validation"
  type = object({
    require_provenance = bool
    require_sbom       = bool
    trusted_builders   = list(string)
    verification_config = object({
      signature_algorithm = string
      public_key         = string
    })
  })
  default = {
    require_provenance = true
    require_sbom       = false
    trusted_builders   = ["cloud-build"]
    verification_config = {
      signature_algorithm = "RSA_PSS"
      public_key         = ""
    }
  }
}

variable "enable_admission_controller_webhook" {
  description = "Whether to enable admission controller webhook"
  type        = bool
  default     = false
}

variable "admission_webhook_config" {
  description = "Configuration for admission controller webhook"
  type = object({
    endpoint_url    = string
    timeout_seconds = number
    failure_policy  = string
    namespace_selector = object({
      match_labels      = map(string)
      match_expressions = list(object({
        key      = string
        operator = string
        values   = list(string)
      }))
    })
  })
  default = null
}

variable "enable_cloud_build_integration" {
  description = "Whether to enable Cloud Build integration for automated attestations"
  type        = bool
  default     = true
}

variable "cloud_build_config" {
  description = "Configuration for Cloud Build integration"
  type = object({
    trigger_name        = string
    trigger_description = string
    github_config = optional(object({
      owner  = string
      name   = string
      branch = string
    }))
    build_config = object({
      attestor_name = string
      kms_key      = string
      notes_reference = string
    })
    included_files = list(string)
    ignored_files  = list(string)
  })
  default = null
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_dry_run" {
  description = "Whether to enable dry-run mode for testing policies"
  type        = bool
  default     = false
}

variable "dry_run_config" {
  description = "Configuration for dry-run mode"
  type = object({
    log_violations_only = bool
    test_namespaces    = list(string)
    test_clusters      = list(string)
    duration           = string
  })
  default = {
    log_violations_only = true
    test_namespaces    = ["test", "staging"]
    test_clusters      = []
    duration           = "86400s"
  }
}

variable "compliance_standards" {
  description = "Compliance standards to enforce"
  type = object({
    cis_benchmark    = bool
    pci_dss         = bool
    hipaa           = bool
    nist_800_53     = bool
    iso_27001       = bool
    custom_policies = list(object({
      name        = string
      description = string
      rules       = list(string)
    }))
  })
  default = {
    cis_benchmark    = false
    pci_dss         = false
    hipaa           = false
    nist_800_53     = false
    iso_27001       = false
    custom_policies = []
  }
}

variable "image_freshness_config" {
  description = "Configuration for image freshness validation"
  type = object({
    enabled               = bool
    max_image_age_days    = number
    exempted_images      = list(string)
    check_frequency      = string
  })
  default = {
    enabled               = false
    max_image_age_days    = 30
    exempted_images      = []
    check_frequency      = "86400s"
  }
}

variable "attestation_authority_iam_bindings" {
  description = "IAM bindings for attestation authorities"
  type = map(object({
    attestor = string
    bindings = list(object({
      role    = string
      members = list(string)
    }))
  }))
  default = {}
}

variable "enable_policy_data_sync" {
  description = "Whether to enable policy data synchronization"
  type        = bool
  default     = false
}

variable "policy_data_sync_config" {
  description = "Configuration for policy data synchronization"
  type = object({
    destination_bucket = string
    sync_frequency    = string
    include_audit_logs = bool
    retention_days    = number
  })
  default = null
}

variable "exemption_config" {
  description = "Configuration for policy exemptions"
  type = object({
    enabled              = bool
    max_exemption_duration = string
    require_approval     = bool
    approvers           = list(string)
    exemption_reasons   = list(string)
  })
  default = {
    enabled              = false
    max_exemption_duration = "604800s"
    require_approval     = true
    approvers           = []
    exemption_reasons   = ["EMERGENCY_FIX", "SECURITY_PATCH", "ROLLBACK"]
  }
}

variable "enable_cross_project_attestation" {
  description = "Whether to enable cross-project attestation"
  type        = bool
  default     = false
}

variable "cross_project_config" {
  description = "Configuration for cross-project attestation"
  type = object({
    trusted_projects = list(string)
    attestor_projects = map(string)
    shared_kms_keys  = list(string)
  })
  default = {
    trusted_projects = []
    attestor_projects = {}
    shared_kms_keys  = []
  }
}

variable "enable_automated_remediation" {
  description = "Whether to enable automated remediation for policy violations"
  type        = bool
  default     = false
}

variable "remediation_config" {
  description = "Configuration for automated remediation"
  type = object({
    auto_quarantine     = bool
    auto_patch         = bool
    notification_topic = string
    remediation_steps  = list(object({
      violation_type = string
      action        = string
      parameters    = map(string)
    }))
  })
  default = null
}

variable "network_policy_config" {
  description = "Network policy configuration for Binary Authorization"
  type = object({
    enable_private_endpoints = bool
    allowed_networks        = list(string)
    denied_networks         = list(string)
    enable_vpc_flow_logs    = bool
  })
  default = {
    enable_private_endpoints = false
    allowed_networks        = []
    denied_networks         = []
    enable_vpc_flow_logs    = false
  }
}

variable "custom_attestor_validation_rules" {
  description = "Custom validation rules for attestors"
  type = map(object({
    rule_name   = string
    description = string
    expression  = string
    error_message = string
  }))
  default = {}
}

variable "enable_cost_optimization" {
  description = "Whether to enable cost optimization features"
  type        = bool
  default     = false
}

variable "cost_optimization_config" {
  description = "Configuration for cost optimization"
  type = object({
    cache_attestations     = bool
    cache_duration        = string
    batch_verification    = bool
    batch_size           = number
    optimize_kms_calls    = bool
  })
  default = {
    cache_attestations     = true
    cache_duration        = "3600s"
    batch_verification    = true
    batch_size           = 10
    optimize_kms_calls    = true
  }
}