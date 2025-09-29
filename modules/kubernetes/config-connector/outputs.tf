# Config Connector Module - Outputs

# Config Management Feature outputs
output "config_management_feature_name" {
  description = "Name of the Config Management feature"
  value       = var.enable_config_connector ? google_gke_hub_feature.config_management[0].name : null
}

output "config_management_feature_details" {
  description = "Detailed information about the Config Management feature"
  value = var.enable_config_connector ? {
    name     = google_gke_hub_feature.config_management[0].name
    project  = google_gke_hub_feature.config_management[0].project
    location = google_gke_hub_feature.config_management[0].location
    state    = google_gke_hub_feature.config_management[0].state
  } : null
}

# Config Connector Membership outputs
output "config_connector_membership_ids" {
  description = "IDs of Config Connector memberships"
  value = {
    for k, v in google_gke_hub_feature_membership.config_connector_memberships : k => v.membership
  }
}

output "config_connector_membership_details" {
  description = "Detailed information about Config Connector memberships"
  value = {
    for k, v in google_gke_hub_feature_membership.config_connector_memberships : k => {
      location         = v.location
      feature          = v.feature
      membership       = v.membership
      project          = v.project
      configmanagement = v.configmanagement
    }
  }
}

# Namespace outputs
output "config_connector_namespace_name" {
  description = "Name of the Config Connector namespace"
  value       = var.create_config_connector_namespace ? kubernetes_namespace.config_connector_system[0].metadata[0].name : null
}

output "config_connector_namespace_details" {
  description = "Detailed information about the Config Connector namespace"
  value = var.create_config_connector_namespace ? {
    name        = kubernetes_namespace.config_connector_system[0].metadata[0].name
    labels      = kubernetes_namespace.config_connector_system[0].metadata[0].labels
    annotations = kubernetes_namespace.config_connector_system[0].metadata[0].annotations
  } : null
}

# Config Connector Operator outputs
output "config_connector_operator_name" {
  description = "Name of the Config Connector operator"
  value       = var.install_config_connector_operator ? kubernetes_manifest.config_connector_operator[0].manifest.metadata.name : null
}

output "config_connector_operator_details" {
  description = "Detailed information about the Config Connector operator"
  value = var.install_config_connector_operator ? {
    name                     = kubernetes_manifest.config_connector_operator[0].manifest.metadata.name
    mode                     = kubernetes_manifest.config_connector_operator[0].manifest.spec.mode
    google_service_account   = kubernetes_manifest.config_connector_operator[0].manifest.spec.googleServiceAccount
    credential_secret_name   = kubernetes_manifest.config_connector_operator[0].manifest.spec.credentialSecretName
    state_into_spec         = kubernetes_manifest.config_connector_operator[0].manifest.spec.stateIntoSpec
    actuation_mode          = kubernetes_manifest.config_connector_operator[0].manifest.spec.actuationMode
  } : null
}

# Config Connector Context outputs
output "config_connector_context_names" {
  description = "Names of Config Connector contexts"
  value = {
    for k, v in kubernetes_manifest.config_connector_contexts : k => v.manifest.metadata.name
  }
}

output "config_connector_context_details" {
  description = "Detailed information about Config Connector contexts"
  value = {
    for k, v in kubernetes_manifest.config_connector_contexts : k => {
      name                     = v.manifest.metadata.name
      namespace                = v.manifest.metadata.namespace
      google_service_account   = v.manifest.spec.googleServiceAccount
      billing_project          = v.manifest.spec.billingProject
      request_project_policy   = v.manifest.spec.requestProjectPolicy
      credential_secret_name   = v.manifest.spec.credentialSecretName
      state_into_spec         = v.manifest.spec.stateIntoSpec
      actuation_mode          = v.manifest.spec.actuationMode
    }
  }
}

# Service Account outputs
output "service_account_email" {
  description = "Email of the Config Connector service account"
  value       = var.create_service_account ? google_service_account.config_connector_sa[0].email : null
}

output "service_account_id" {
  description = "ID of the Config Connector service account"
  value       = var.create_service_account ? google_service_account.config_connector_sa[0].account_id : null
}

output "service_account_unique_id" {
  description = "Unique ID of the Config Connector service account"
  value       = var.create_service_account ? google_service_account.config_connector_sa[0].unique_id : null
}

# Kubernetes Service Account outputs
output "kubernetes_service_account_name" {
  description = "Name of the Kubernetes service account"
  value       = var.create_kubernetes_service_account ? kubernetes_service_account.config_connector_ksa[0].metadata[0].name : null
}

output "kubernetes_service_account_details" {
  description = "Detailed information about the Kubernetes service account"
  value = var.create_kubernetes_service_account ? {
    name        = kubernetes_service_account.config_connector_ksa[0].metadata[0].name
    namespace   = kubernetes_service_account.config_connector_ksa[0].metadata[0].namespace
    labels      = kubernetes_service_account.config_connector_ksa[0].metadata[0].labels
    annotations = kubernetes_service_account.config_connector_ksa[0].metadata[0].annotations
  } : null
}

# Custom Resource Definition outputs
output "custom_resource_names" {
  description = "Names of custom resources"
  value = {
    for k, v in kubernetes_manifest.config_connector_crds : k => v.manifest.metadata.name
  }
}

output "custom_resource_details" {
  description = "Detailed information about custom resources"
  value = {
    for k, v in kubernetes_manifest.config_connector_crds : k => {
      name        = v.manifest.metadata.name
      namespace   = v.manifest.metadata.namespace
      api_version = v.manifest.apiVersion
      kind        = v.manifest.kind
      labels      = v.manifest.metadata.labels
      annotations = v.manifest.metadata.annotations
    }
  }
}

# Policy Controller outputs
output "policy_constraint_names" {
  description = "Names of policy constraints"
  value = {
    for k, v in kubernetes_manifest.policy_constraints : k => v.manifest.metadata.name
  }
}

output "policy_constraint_details" {
  description = "Detailed information about policy constraints"
  value = {
    for k, v in kubernetes_manifest.policy_constraints : k => {
      name        = v.manifest.metadata.name
      api_version = v.manifest.apiVersion
      kind        = v.manifest.kind
      labels      = v.manifest.metadata.labels
      spec        = v.manifest.spec
    }
  }
}

output "constraint_template_names" {
  description = "Names of constraint templates"
  value = {
    for k, v in kubernetes_manifest.constraint_templates : k => v.manifest.metadata.name
  }
}

output "constraint_template_details" {
  description = "Detailed information about constraint templates"
  value = {
    for k, v in kubernetes_manifest.constraint_templates : k => {
      name    = v.manifest.metadata.name
      labels  = v.manifest.metadata.labels
      crd     = v.manifest.spec.crd
      targets = v.manifest.spec.targets
    }
  }
}

# Config Sync outputs
output "config_sync_secret_names" {
  description = "Names of Config Sync secrets"
  value = {
    for k, v in kubernetes_secret.config_sync_secret : k => v.metadata[0].name
  }
}

output "config_sync_secret_details" {
  description = "Detailed information about Config Sync secrets"
  value = {
    for k, v in kubernetes_secret.config_sync_secret : k => {
      name      = v.metadata[0].name
      namespace = v.metadata[0].namespace
      type      = v.type
      labels    = v.metadata[0].labels
    }
  }
  sensitive = true
}

# Hierarchy Controller outputs
output "hierarchy_config_names" {
  description = "Names of hierarchy configurations"
  value = {
    for k, v in kubernetes_manifest.hierarchy_configs : k => v.manifest.metadata.name
  }
}

output "hierarchy_config_details" {
  description = "Detailed information about hierarchy configurations"
  value = {
    for k, v in kubernetes_manifest.hierarchy_configs : k => {
      name      = v.manifest.metadata.name
      namespace = v.manifest.metadata.namespace
      kind      = v.manifest.kind
      labels    = v.manifest.metadata.labels
      spec      = v.manifest.spec
    }
  }
}

# Resource Quota outputs
output "resource_quota_names" {
  description = "Names of resource quotas"
  value = {
    for k, v in kubernetes_resource_quota.config_connector_quotas : k => v.metadata[0].name
  }
}

output "resource_quota_details" {
  description = "Detailed information about resource quotas"
  value = {
    for k, v in kubernetes_resource_quota.config_connector_quotas : k => {
      name       = v.metadata[0].name
      namespace  = v.metadata[0].namespace
      hard       = v.spec[0].hard
      scopes     = v.spec[0].scopes
      labels     = v.metadata[0].labels
    }
  }
}

# Network Policy outputs
output "network_policy_names" {
  description = "Names of network policies"
  value = {
    for k, v in kubernetes_network_policy.config_connector_network_policies : k => v.metadata[0].name
  }
}

output "network_policy_details" {
  description = "Detailed information about network policies"
  value = {
    for k, v in kubernetes_network_policy.config_connector_network_policies : k => {
      name         = v.metadata[0].name
      namespace    = v.metadata[0].namespace
      policy_types = v.spec[0].policy_types
      pod_selector = v.spec[0].pod_selector
      labels       = v.metadata[0].labels
    }
  }
}

# RBAC outputs
output "cluster_role_names" {
  description = "Names of cluster roles"
  value = {
    for k, v in kubernetes_cluster_role.config_connector_roles : k => v.metadata[0].name
  }
}

output "cluster_role_details" {
  description = "Detailed information about cluster roles"
  value = {
    for k, v in kubernetes_cluster_role.config_connector_roles : k => {
      name   = v.metadata[0].name
      labels = v.metadata[0].labels
      rules  = v.rule
    }
  }
}

output "cluster_role_binding_names" {
  description = "Names of cluster role bindings"
  value = {
    for k, v in kubernetes_cluster_role_binding.config_connector_role_bindings : k => v.metadata[0].name
  }
}

output "cluster_role_binding_details" {
  description = "Detailed information about cluster role bindings"
  value = {
    for k, v in kubernetes_cluster_role_binding.config_connector_role_bindings : k => {
      name     = v.metadata[0].name
      labels   = v.metadata[0].labels
      role_ref = v.role_ref
      subject  = v.subject
    }
  }
}

# Monitoring outputs
output "monitoring_dashboard_id" {
  description = "ID of the Config Connector monitoring dashboard"
  value       = var.enable_monitoring && var.create_dashboard ? google_monitoring_dashboard.config_connector_dashboard[0].id : null
}

output "monitoring_dashboard_url" {
  description = "URL to the Config Connector monitoring dashboard"
  value = var.enable_monitoring && var.create_dashboard ? (
    "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.config_connector_dashboard[0].id}?project=${var.project_id}"
  ) : null
}

output "alert_policy_ids" {
  description = "IDs of created alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.config_connector_alerts : k => v.id
  }
}

output "alert_policy_names" {
  description = "Names of created alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.config_connector_alerts : k => v.display_name
  }
}

# Backup outputs
output "backup_config_names" {
  description = "Names of backup configurations"
  value = {
    for k, v in kubernetes_manifest.config_connector_backup : k => v.manifest.metadata.name
  }
}

output "backup_config_details" {
  description = "Detailed information about backup configurations"
  value = {
    for k, v in kubernetes_manifest.config_connector_backup : k => {
      name            = v.manifest.metadata.name
      namespace       = v.manifest.metadata.namespace
      backup_schedule = v.manifest.data.backup_schedule
      retention_days  = v.manifest.data.retention_days
      backup_location = v.manifest.data.backup_location
    }
  }
}

# Configuration metadata
output "configuration_metadata" {
  description = "Metadata about the Config Connector configuration"
  value = {
    project_id                         = var.project_id
    config_connector_enabled           = var.enable_config_connector
    config_connector_mode             = var.config_connector_mode
    config_connector_namespace        = var.config_connector_namespace
    operator_installed                = var.install_config_connector_operator
    workload_identity_enabled         = var.enable_workload_identity
    memberships_count                 = length(google_gke_hub_feature_membership.config_connector_memberships)
    contexts_count                    = length(kubernetes_manifest.config_connector_contexts)
    custom_resources_count            = length(kubernetes_manifest.config_connector_crds)
    policy_controller_enabled         = var.enable_policy_controller
    config_sync_enabled               = var.enable_config_sync
    hierarchy_controller_enabled      = var.enable_hierarchy_controller
    resource_quotas_enabled           = var.enable_resource_quotas
    network_policies_enabled          = var.enable_network_policies
    rbac_enabled                      = var.enable_rbac
    monitoring_enabled                = var.enable_monitoring
    audit_logging_enabled             = var.enable_audit_logging
    backup_enabled                    = var.enable_backup
    drift_detection_enabled           = var.enable_drift_detection
    resource_validation_enabled       = var.enable_resource_validation
    multi_tenancy_enabled             = var.enable_multi_tenancy
    disaster_recovery_enabled         = var.enable_disaster_recovery
    compliance_monitoring_enabled     = var.enable_compliance_monitoring
    performance_optimization_enabled  = var.enable_performance_optimization
    total_alert_policies              = length(google_monitoring_alert_policy.config_connector_alerts)
  }
}

# Config Connector status summary
output "config_connector_status" {
  description = "Status summary of Config Connector components"
  value = {
    feature_status = var.enable_config_connector ? "enabled" : "disabled"
    operator_status = var.install_config_connector_operator ? "installed" : "not_installed"
    namespace_status = var.create_config_connector_namespace ? "created" : "not_created"
    memberships = {
      total = length(var.config_connector_memberships)
      configured = length(google_gke_hub_feature_membership.config_connector_memberships)
    }
    contexts = {
      total = length(var.config_connector_contexts)
      configured = length(kubernetes_manifest.config_connector_contexts)
    }
    service_accounts = {
      google_sa_created = var.create_service_account
      k8s_sa_created = var.create_kubernetes_service_account
      workload_identity = var.enable_workload_identity
    }
  }
}

# Features configuration summary
output "features_configuration" {
  description = "Configuration summary of enabled features"
  value = {
    policy_controller = {
      enabled = var.enable_policy_controller
      constraints = length(var.policy_constraints)
      templates = length(var.constraint_templates)
    }
    config_sync = {
      enabled = var.enable_config_sync
      secrets = length(var.config_sync_secrets)
    }
    hierarchy_controller = {
      enabled = var.enable_hierarchy_controller
      configurations = length(var.hierarchy_configurations)
    }
    resource_management = {
      quotas_enabled = var.enable_resource_quotas
      network_policies_enabled = var.enable_network_policies
      rbac_enabled = var.enable_rbac
    }
    backup_and_recovery = {
      backup_enabled = var.enable_backup
      disaster_recovery_enabled = var.enable_disaster_recovery
      backup_configs = length(var.backup_configurations)
    }
    security = {
      drift_detection = var.enable_drift_detection
      resource_validation = var.enable_resource_validation
      compliance_monitoring = var.enable_compliance_monitoring
    }
    operational = {
      monitoring_enabled = var.enable_monitoring
      audit_logging_enabled = var.enable_audit_logging
      performance_optimization = var.enable_performance_optimization
    }
  }
}

# Advanced configuration summary
output "advanced_configuration" {
  description = "Advanced configuration details"
  value = {
    multi_tenancy = var.enable_multi_tenancy ? {
      enabled = var.enable_multi_tenancy
      tenant_isolation = var.multi_tenancy_config.tenant_isolation_enabled
      namespace_quotas = length(var.multi_tenancy_config.namespace_quotas)
      rbac_per_tenant = var.multi_tenancy_config.rbac_per_tenant
    } : null

    drift_detection = var.enable_drift_detection ? {
      enabled = var.enable_drift_detection
      interval_minutes = var.drift_detection_config.detection_interval_minutes
      auto_remediation = var.drift_detection_config.auto_remediation
      excluded_resources = length(var.drift_detection_config.excluded_resources)
    } : null

    compliance = var.enable_compliance_monitoring ? {
      enabled = var.enable_compliance_monitoring
      standards = var.compliance_config.compliance_standards
      audit_frequency = var.compliance_config.audit_frequency
      violation_alerts = var.compliance_config.violation_alerts
    } : null

    performance = var.enable_performance_optimization ? {
      enabled = var.enable_performance_optimization
      controller_replicas = var.performance_config.controller_replicas
      parallel_workers = var.performance_config.parallel_workers
      reconciliation_timeout = var.performance_config.reconciliation_timeout
    } : null
  }
}

# Management URLs
output "management_urls" {
  description = "URLs for managing Config Connector resources"
  value = {
    anthos_config_management_console = "https://console.cloud.google.com/kubernetes/config_management?project=${var.project_id}"
    gke_hub_console = "https://console.cloud.google.com/kubernetes/clusters?project=${var.project_id}"
    policy_controller_console = var.enable_policy_controller ? "https://console.cloud.google.com/kubernetes/policy?project=${var.project_id}" : null
    monitoring_console = var.enable_monitoring ? "https://console.cloud.google.com/monitoring?project=${var.project_id}" : null
    logs_console = "https://console.cloud.google.com/logs/query?project=${var.project_id}"
    workload_identity_console = var.enable_workload_identity ? "https://console.cloud.google.com/iam-admin/workload-identity-pools?project=${var.project_id}" : null
  }
}

# Resource identifiers for integration
output "resource_identifiers" {
  description = "Resource identifiers for integration with other modules"
  value = {
    config_management_feature_resource = var.enable_config_connector ? google_gke_hub_feature.config_management[0].name : null
    membership_resources = {
      for k, v in google_gke_hub_feature_membership.config_connector_memberships : k => v.membership
    }
    namespace_resource = var.create_config_connector_namespace ? kubernetes_namespace.config_connector_system[0].metadata[0].name : null
    operator_resource = var.install_config_connector_operator ? kubernetes_manifest.config_connector_operator[0].manifest.metadata.name : null
    context_resources = {
      for k, v in kubernetes_manifest.config_connector_contexts : k => v.manifest.metadata.name
    }
    google_service_account_resource = var.create_service_account ? google_service_account.config_connector_sa[0].email : null
    kubernetes_service_account_resource = var.create_kubernetes_service_account ? kubernetes_service_account.config_connector_ksa[0].metadata[0].name : null
  }
}

# Supported resource types
output "supported_resource_types" {
  description = "List of supported Config Connector resource types"
  value       = local.supported_resource_types
}

# Configuration validation
output "configuration_validation" {
  description = "Configuration validation results"
  value = {
    valid_config_connector_mode = contains(["cluster", "namespaced"], var.config_connector_mode)
    service_account_configured = var.create_service_account || var.google_service_account_email != ""
    workload_identity_properly_configured = var.enable_workload_identity ? (var.create_service_account && var.create_kubernetes_service_account) : true
    monitoring_configured = var.enable_monitoring
    required_apis_enabled = var.enable_apis
    namespace_properly_configured = var.create_config_connector_namespace || length(var.config_connector_contexts) > 0
  }
}

# Operational health indicators
output "operational_health" {
  description = "Operational health indicators"
  value = {
    config_connector_operational = var.enable_config_connector && var.install_config_connector_operator
    memberships_configured = length(google_gke_hub_feature_membership.config_connector_memberships) > 0
    contexts_configured = length(kubernetes_manifest.config_connector_contexts) > 0 || var.config_connector_mode == "cluster"
    service_accounts_configured = (var.create_service_account || var.google_service_account_email != "") && (var.create_kubernetes_service_account || !var.enable_workload_identity)
    monitoring_active = var.enable_monitoring
    security_configured = var.enable_policy_controller || var.enable_rbac || var.enable_network_policies
    backup_configured = var.enable_backup && length(var.backup_configurations) > 0
  }
}