# Config Connector Module - Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "enable_apis" {
  description = "Whether to enable required GCP APIs"
  type        = bool
  default     = true
}

# Config Connector Core Configuration
variable "enable_config_connector" {
  description = "Whether to enable Config Connector"
  type        = bool
  default     = true
}

variable "config_connector_mode" {
  description = "Config Connector mode (cluster or namespaced)"
  type        = string
  default     = "cluster"
  validation {
    condition     = contains(["cluster", "namespaced"], var.config_connector_mode)
    error_message = "Config Connector mode must be 'cluster' or 'namespaced'"
  }
}

variable "config_connector_namespace" {
  description = "Namespace for Config Connector"
  type        = string
  default     = "cnrm-system"
}

variable "create_config_connector_namespace" {
  description = "Whether to create the Config Connector namespace"
  type        = bool
  default     = true
}

variable "namespace_annotations" {
  description = "Annotations to add to the Config Connector namespace"
  type        = map(string)
  default     = {}
}

variable "install_config_connector_operator" {
  description = "Whether to install the Config Connector operator"
  type        = bool
  default     = true
}

# Config Connector Memberships
variable "config_connector_memberships" {
  description = "Configuration for Config Connector memberships"
  type = map(object({
    membership_name                   = string
    config_management_version         = optional(string, "1.15.1")
    config_sync_enabled               = optional(bool, true)
    source_format                     = optional(string, "hierarchy")
    sync_repo                         = optional(string)
    sync_branch                       = optional(string, "main")
    policy_dir                        = optional(string, "config")
    sync_wait_secs                    = optional(number, 15)
    secret_type                       = optional(string, "none")
    https_proxy                       = optional(string)
    gcp_service_account_email         = optional(string)
    prevent_drift                     = optional(bool, true)
    metrics_gcp_service_account_email = optional(string)
    policy_controller_enabled         = optional(bool, true)
    template_library_installed        = optional(bool, true)
    audit_interval_seconds            = optional(number, 60)
    exemptable_namespaces             = optional(list(string), ["kube-system"])
    log_denies_enabled                = optional(bool, true)
    mutation_enabled                  = optional(bool, true)
    referential_rules_enabled         = optional(bool, true)
    policy_controller_monitoring = optional(object({
      backends = list(string)
    }))
    hierarchy_controller_enabled       = optional(bool, true)
    enable_pod_tree_labels             = optional(bool, true)
    enable_hierarchical_resource_quota = optional(bool, false)
    binauthz_enabled                   = optional(bool, false)
  }))
  default = {}
}

# Service Account Configuration
variable "create_service_account" {
  description = "Whether to create a service account for Config Connector"
  type        = bool
  default     = true
}

variable "service_account_id" {
  description = "The service account ID for Config Connector"
  type        = string
  default     = "config-connector-sa"
}

variable "service_account_roles" {
  description = "Roles to assign to the Config Connector service account"
  type        = list(string)
  default = [
    "roles/owner"
  ]
}

variable "google_service_account_email" {
  description = "Email of existing Google Service Account to use"
  type        = string
  default     = ""
}

# Workload Identity Configuration
variable "enable_workload_identity" {
  description = "Whether to enable Workload Identity"
  type        = bool
  default     = true
}

variable "create_kubernetes_service_account" {
  description = "Whether to create Kubernetes service account"
  type        = bool
  default     = true
}

variable "kubernetes_service_account_name" {
  description = "Name of the Kubernetes service account"
  type        = string
  default     = "cnrm-controller-manager"
}

# Config Connector Operator Configuration
variable "credential_secret_name" {
  description = "Name of the credential secret"
  type        = string
  default     = ""
}

variable "state_into_spec" {
  description = "Whether to enable state-into-spec"
  type        = string
  default     = "Absent"
}

variable "actuation_mode" {
  description = "Actuation mode for Config Connector"
  type        = string
  default     = "Reconciling"
}

variable "webhook_failure_policy" {
  description = "Failure policy for admission webhooks"
  type        = string
  default     = "Fail"
}

variable "webhook_timeout_seconds" {
  description = "Timeout for admission webhooks in seconds"
  type        = number
  default     = 10
}

variable "watch_fleet_workloads" {
  description = "Whether to watch fleet workloads"
  type        = bool
  default     = false
}

variable "watch_fleet_workload_identity" {
  description = "Whether to watch fleet workload identity"
  type        = bool
  default     = false
}

# Config Connector Contexts
variable "config_connector_contexts" {
  description = "Configuration for Config Connector contexts"
  type = map(object({
    namespace                    = string
    google_service_account_email = string
    billing_project              = optional(string)
    request_project_policy       = optional(string, "REQUEST_PROJECT_POLICY_UNSPECIFIED")
    credential_secret_name       = optional(string)
    state_into_spec              = optional(string, "Absent")
    actuation_mode               = optional(string, "Reconciling")
    labels                       = optional(map(string), {})
  }))
  default = {}
}

# Custom Resource Definitions
variable "enable_custom_resources" {
  description = "Whether to enable custom resource definitions"
  type        = bool
  default     = false
}

variable "custom_resource_definitions" {
  description = "Custom resource definitions to create"
  type = map(object({
    api_version = string
    kind        = string
    namespace   = string
    labels      = optional(map(string), {})
    annotations = optional(map(string), {})
    spec        = any
  }))
  default = {}
}

# Policy Controller Configuration
variable "enable_policy_controller" {
  description = "Whether to enable Policy Controller"
  type        = bool
  default     = false
}

variable "policy_constraints" {
  description = "Policy constraints to create"
  type = map(object({
    api_version = string
    kind        = string
    labels      = optional(map(string), {})
    spec        = any
  }))
  default = {}
}

variable "constraint_templates" {
  description = "Constraint templates to create"
  type = map(object({
    crd_kind          = string
    validation_schema = any
    targets           = list(any)
    labels            = optional(map(string), {})
  }))
  default = {}
}

# Config Sync Configuration
variable "enable_config_sync" {
  description = "Whether to enable Config Sync"
  type        = bool
  default     = false
}

variable "config_sync_secrets" {
  description = "Secrets for Config Sync"
  type = map(object({
    namespace   = string
    secret_type = string
    data        = map(string)
  }))
  default   = {}
  sensitive = true
}

# Hierarchy Controller Configuration
variable "enable_hierarchy_controller" {
  description = "Whether to enable Hierarchy Controller"
  type        = bool
  default     = false
}

variable "hierarchy_configurations" {
  description = "Hierarchy configurations to create"
  type = map(object({
    kind      = string
    namespace = string
    labels    = optional(map(string), {})
    spec      = any
  }))
  default = {}
}

# Resource Quotas
variable "enable_resource_quotas" {
  description = "Whether to enable resource quotas"
  type        = bool
  default     = false
}

variable "resource_quotas" {
  description = "Resource quotas to create"
  type = map(object({
    namespace   = string
    hard_limits = map(string)
    scopes      = optional(list(string))
    scope_selector_match_expressions = optional(list(object({
      scope_name = string
      operator   = string
      values     = list(string)
    })), [])
  }))
  default = {}
}

# Network Policies
variable "enable_network_policies" {
  description = "Whether to enable network policies"
  type        = bool
  default     = false
}

variable "network_policies" {
  description = "Network policies to create"
  type = map(object({
    namespace                 = string
    pod_selector_match_labels = map(string)
    policy_types              = list(string)
    ingress_rules = optional(list(object({
      ports = optional(list(object({
        port     = optional(string)
        protocol = optional(string)
      })), [])
      from_rules = optional(list(object({
        namespace_selector = optional(object({
          match_labels = map(string)
        }))
        pod_selector = optional(object({
          match_labels = map(string)
        }))
        ip_block = optional(object({
          cidr   = string
          except = optional(list(string))
        }))
      })), [])
    })), [])
    egress_rules = optional(list(object({
      ports = optional(list(object({
        port     = optional(string)
        protocol = optional(string)
      })), [])
      to_rules = optional(list(object({
        namespace_selector = optional(object({
          match_labels = map(string)
        }))
        pod_selector = optional(object({
          match_labels = map(string)
        }))
        ip_block = optional(object({
          cidr   = string
          except = optional(list(string))
        }))
      })), [])
    })), [])
  }))
  default = {}
}

# RBAC Configuration
variable "enable_rbac" {
  description = "Whether to enable RBAC configuration"
  type        = bool
  default     = false
}

variable "cluster_roles" {
  description = "Cluster roles to create"
  type = map(object({
    rules = list(object({
      api_groups        = optional(list(string))
      resources         = optional(list(string))
      resource_names    = optional(list(string))
      verbs             = list(string)
      non_resource_urls = optional(list(string))
    }))
  }))
  default = {}
}

variable "cluster_role_bindings" {
  description = "Cluster role bindings to create"
  type = map(object({
    cluster_role_name = string
    subjects = list(object({
      kind      = string
      name      = string
      namespace = optional(string)
      api_group = optional(string)
    }))
  }))
  default = {}
}

# Monitoring Configuration
variable "enable_monitoring" {
  description = "Whether to enable monitoring for Config Connector"
  type        = bool
  default     = true
}

variable "create_dashboard" {
  description = "Whether to create a monitoring dashboard"
  type        = bool
  default     = true
}

variable "dashboard_display_name" {
  description = "Display name for the monitoring dashboard"
  type        = string
  default     = "Config Connector Dashboard"
}

variable "notification_channels" {
  description = "List of notification channel IDs for alerts"
  type        = list(string)
  default     = []
}

variable "alert_policies" {
  description = "Alert policies configuration"
  type = map(object({
    display_name           = string
    combiner               = optional(string, "OR")
    enabled                = optional(bool, true)
    documentation          = optional(string)
    condition_display_name = string
    filter                 = string
    duration               = string
    comparison             = string
    threshold_value        = number
    alignment_period       = optional(string, "60s")
    per_series_aligner     = optional(string, "ALIGN_RATE")
    cross_series_reducer   = optional(string, "REDUCE_SUM")
    group_by_fields        = optional(list(string), [])
    trigger_count          = optional(number)
    trigger_percent        = optional(number)
    notification_channels  = optional(list(string), [])
    auto_close_duration    = optional(string, "86400s")
    rate_limit             = optional(string)
  }))
  default = {}
}

# Logging Configuration
variable "enable_audit_logging" {
  description = "Whether to enable audit logging for Config Connector"
  type        = bool
  default     = true
}

variable "audit_log_sink_name" {
  description = "Name of the audit log sink"
  type        = string
  default     = "config-connector-audit-sink"
}

variable "audit_log_destination" {
  description = "Destination for audit logs (e.g., Cloud Storage bucket, BigQuery dataset)"
  type        = string
  default     = ""
}

# Backup Configuration
variable "enable_backup" {
  description = "Whether to enable backup for Config Connector state"
  type        = bool
  default     = false
}

variable "backup_configurations" {
  description = "Backup configurations"
  type = map(object({
    namespace       = string
    backup_schedule = string
    retention_days  = number
    backup_location = string
    encryption_key  = optional(string)
  }))
  default = {}
}

# Advanced Configuration
variable "enable_drift_detection" {
  description = "Whether to enable drift detection"
  type        = bool
  default     = true
}

variable "drift_detection_config" {
  description = "Drift detection configuration"
  type = object({
    detection_interval_minutes = number
    auto_remediation           = bool
    notification_channels      = list(string)
    excluded_resources         = list(string)
  })
  default = {
    detection_interval_minutes = 60
    auto_remediation           = false
    notification_channels      = []
    excluded_resources         = []
  }
}

variable "enable_resource_validation" {
  description = "Whether to enable resource validation"
  type        = bool
  default     = true
}

variable "resource_validation_config" {
  description = "Resource validation configuration"
  type = object({
    admission_controller_enabled = bool
    validation_webhook_enabled   = bool
    dry_run_enabled              = bool
    fail_on_validation_error     = bool
    custom_validation_rules      = list(string)
  })
  default = {
    admission_controller_enabled = true
    validation_webhook_enabled   = true
    dry_run_enabled              = false
    fail_on_validation_error     = true
    custom_validation_rules      = []
  }
}

variable "enable_multi_tenancy" {
  description = "Whether to enable multi-tenancy features"
  type        = bool
  default     = false
}

variable "multi_tenancy_config" {
  description = "Multi-tenancy configuration"
  type = object({
    tenant_isolation_enabled = bool
    namespace_quotas         = map(string)
    rbac_per_tenant          = bool
    network_policies_enabled = bool
    resource_quotas_enabled  = bool
  })
  default = {
    tenant_isolation_enabled = true
    namespace_quotas         = {}
    rbac_per_tenant          = true
    network_policies_enabled = true
    resource_quotas_enabled  = true
  }
}

variable "enable_disaster_recovery" {
  description = "Whether to enable disaster recovery features"
  type        = bool
  default     = false
}

variable "disaster_recovery_config" {
  description = "Disaster recovery configuration"
  type = object({
    backup_frequency         = string
    cross_region_replication = bool
    backup_encryption        = bool
    recovery_point_objective = string
    recovery_time_objective  = string
  })
  default = {
    backup_frequency         = "daily"
    cross_region_replication = false
    backup_encryption        = true
    recovery_point_objective = "1h"
    recovery_time_objective  = "4h"
  }
}

variable "enable_compliance_monitoring" {
  description = "Whether to enable compliance monitoring"
  type        = bool
  default     = false
}

variable "compliance_config" {
  description = "Compliance monitoring configuration"
  type = object({
    compliance_standards   = list(string)
    audit_frequency        = string
    violation_alerts       = bool
    compliance_reports     = bool
    remediation_automation = bool
  })
  default = {
    compliance_standards   = ["CIS", "PCI-DSS", "SOC2"]
    audit_frequency        = "daily"
    violation_alerts       = true
    compliance_reports     = true
    remediation_automation = false
  }
}

variable "enable_performance_optimization" {
  description = "Whether to enable performance optimization"
  type        = bool
  default     = false
}

variable "performance_config" {
  description = "Performance optimization configuration"
  type = object({
    controller_replicas     = number
    resource_limits         = map(string)
    parallel_workers        = number
    reconciliation_timeout  = string
    webhook_timeout_seconds = number
  })
  default = {
    controller_replicas     = 3
    resource_limits         = {}
    parallel_workers        = 10
    reconciliation_timeout  = "300s"
    webhook_timeout_seconds = 10
  }
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Network tags to apply to resources"
  type        = list(string)
  default     = []
}

# Environment-specific configurations
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "resource_management_config" {
  description = "Resource management configuration"
  type = object({
    enable_resource_limits        = bool
    enable_resource_quotas        = bool
    enable_priority_classes       = bool
    enable_pod_disruption_budgets = bool
    default_resource_limits       = map(string)
  })
  default = {
    enable_resource_limits        = true
    enable_resource_quotas        = true
    enable_priority_classes       = false
    enable_pod_disruption_budgets = false
    default_resource_limits       = {}
  }
}

variable "integration_configs" {
  description = "Integration configurations for external systems"
  type = map(object({
    integration_type = string
    endpoint_url     = string
    authentication   = map(string)
    sync_frequency   = string
    enabled          = bool
  }))
  default = {}
}

variable "custom_admission_controllers" {
  description = "Custom admission controllers configuration"
  type = map(object({
    webhook_url     = string
    failure_policy  = string
    admission_rules = list(string)
    namespaces      = list(string)
  }))
  default = {}
}

variable "resource_templates" {
  description = "Resource templates for common configurations"
  type = map(object({
    template_type = string
    template_spec = any
    parameters    = map(string)
  }))
  default = {}
}