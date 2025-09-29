# Anthos Service Mesh Module - Outputs

# GKE Hub Membership outputs
output "cluster_membership_ids" {
  description = "IDs of GKE Hub cluster memberships"
  value = {
    for k, v in google_gke_hub_membership.cluster_memberships : k => v.membership_id
  }
}

output "cluster_membership_names" {
  description = "Names of GKE Hub cluster memberships"
  value = {
    for k, v in google_gke_hub_membership.cluster_memberships : k => v.name
  }
}

output "cluster_membership_details" {
  description = "Detailed information about GKE Hub cluster memberships"
  value = {
    for k, v in google_gke_hub_membership.cluster_memberships : k => {
      membership_id = v.membership_id
      name         = v.name
      project      = v.project
      endpoint     = v.endpoint
      authority    = v.authority
      labels       = v.labels
      state        = v.state
    }
  }
}

# Service Mesh Feature outputs
output "service_mesh_feature_id" {
  description = "ID of the Service Mesh feature"
  value       = var.enable_service_mesh ? google_gke_hub_feature.service_mesh[0].name : null
}

output "service_mesh_feature_details" {
  description = "Detailed information about the Service Mesh feature"
  value = var.enable_service_mesh ? {
    name     = google_gke_hub_feature.service_mesh[0].name
    project  = google_gke_hub_feature.service_mesh[0].project
    location = google_gke_hub_feature.service_mesh[0].location
    spec     = google_gke_hub_feature.service_mesh[0].spec
    state    = google_gke_hub_feature.service_mesh[0].state
  } : null
}

# Service Mesh Membership outputs
output "service_mesh_membership_ids" {
  description = "IDs of service mesh memberships"
  value = {
    for k, v in google_gke_hub_feature_membership.service_mesh_memberships : k => v.membership
  }
}

output "service_mesh_membership_details" {
  description = "Detailed information about service mesh memberships"
  value = {
    for k, v in google_gke_hub_feature_membership.service_mesh_memberships : k => {
      location      = v.location
      feature       = v.feature
      membership    = v.membership
      project       = v.project
      mesh          = v.mesh
      configmanagement = v.configmanagement
    }
  }
}

# Istio Namespace outputs
output "istio_namespace_names" {
  description = "Names of created Istio namespaces"
  value = [
    for k, v in kubernetes_namespace.istio_system : v.metadata[0].name
  ]
}

output "istio_namespace_details" {
  description = "Detailed information about Istio namespaces"
  value = {
    for k, v in kubernetes_namespace.istio_system : k => {
      name        = v.metadata[0].name
      labels      = v.metadata[0].labels
      annotations = v.metadata[0].annotations
    }
  }
}

# Istio Control Plane outputs
output "istio_control_plane_names" {
  description = "Names of Istio control plane configurations"
  value = {
    for k, v in kubernetes_manifest.istio_control_plane : k => v.manifest.metadata.name
  }
}

output "istio_control_plane_details" {
  description = "Detailed information about Istio control plane configurations"
  value = {
    for k, v in kubernetes_manifest.istio_control_plane : k => {
      name      = v.manifest.metadata.name
      namespace = v.manifest.metadata.namespace
      hub       = v.manifest.spec.hub
      tag       = v.manifest.spec.tag
      revision  = v.manifest.spec.revision
      mesh_id   = v.manifest.spec.values.global.meshID
      network   = v.manifest.spec.values.global.network
      trust_domain = v.manifest.spec.values.global.trustDomain
    }
  }
}

# Gateway outputs
output "istio_gateway_names" {
  description = "Names of Istio Gateways"
  value = {
    for k, v in kubernetes_manifest.istio_gateways : k => v.manifest.metadata.name
  }
}

output "istio_gateway_details" {
  description = "Detailed information about Istio Gateways"
  value = {
    for k, v in kubernetes_manifest.istio_gateways : k => {
      name      = v.manifest.metadata.name
      namespace = v.manifest.metadata.namespace
      selector  = v.manifest.spec.selector
      servers   = v.manifest.spec.servers
      labels    = v.manifest.metadata.labels
    }
  }
}

# Virtual Service outputs
output "virtual_service_names" {
  description = "Names of Istio Virtual Services"
  value = {
    for k, v in kubernetes_manifest.virtual_services : k => v.manifest.metadata.name
  }
}

output "virtual_service_details" {
  description = "Detailed information about Istio Virtual Services"
  value = {
    for k, v in kubernetes_manifest.virtual_services : k => {
      name      = v.manifest.metadata.name
      namespace = v.manifest.metadata.namespace
      hosts     = v.manifest.spec.hosts
      gateways  = v.manifest.spec.gateways
      http      = v.manifest.spec.http
      tcp       = v.manifest.spec.tcp
      tls       = v.manifest.spec.tls
      labels    = v.manifest.metadata.labels
    }
  }
}

# Destination Rule outputs
output "destination_rule_names" {
  description = "Names of Istio Destination Rules"
  value = {
    for k, v in kubernetes_manifest.destination_rules : k => v.manifest.metadata.name
  }
}

output "destination_rule_details" {
  description = "Detailed information about Istio Destination Rules"
  value = {
    for k, v in kubernetes_manifest.destination_rules : k => {
      name           = v.manifest.metadata.name
      namespace      = v.manifest.metadata.namespace
      host           = v.manifest.spec.host
      traffic_policy = v.manifest.spec.trafficPolicy
      subsets        = v.manifest.spec.subsets
      export_to      = v.manifest.spec.exportTo
      labels         = v.manifest.metadata.labels
    }
  }
}

# Service Entry outputs
output "service_entry_names" {
  description = "Names of Istio Service Entries"
  value = {
    for k, v in kubernetes_manifest.service_entries : k => v.manifest.metadata.name
  }
}

output "service_entry_details" {
  description = "Detailed information about Istio Service Entries"
  value = {
    for k, v in kubernetes_manifest.service_entries : k => {
      name              = v.manifest.metadata.name
      namespace         = v.manifest.metadata.namespace
      hosts             = v.manifest.spec.hosts
      ports             = v.manifest.spec.ports
      location          = v.manifest.spec.location
      resolution        = v.manifest.spec.resolution
      addresses         = v.manifest.spec.addresses
      endpoints         = v.manifest.spec.endpoints
      workload_selector = v.manifest.spec.workloadSelector
      labels            = v.manifest.metadata.labels
    }
  }
}

# Sidecar outputs
output "sidecar_config_names" {
  description = "Names of Istio Sidecar configurations"
  value = {
    for k, v in kubernetes_manifest.sidecars : k => v.manifest.metadata.name
  }
}

output "sidecar_config_details" {
  description = "Detailed information about Istio Sidecar configurations"
  value = {
    for k, v in kubernetes_manifest.sidecars : k => {
      name                    = v.manifest.metadata.name
      namespace               = v.manifest.metadata.namespace
      workload_selector       = v.manifest.spec.workloadSelector
      ingress                 = v.manifest.spec.ingress
      egress                  = v.manifest.spec.egress
      outbound_traffic_policy = v.manifest.spec.outboundTrafficPolicy
      labels                  = v.manifest.metadata.labels
    }
  }
}

# Security Policy outputs
output "peer_authentication_names" {
  description = "Names of Istio Peer Authentication policies"
  value = {
    for k, v in kubernetes_manifest.peer_authentications : k => v.manifest.metadata.name
  }
}

output "peer_authentication_details" {
  description = "Detailed information about Istio Peer Authentication policies"
  value = {
    for k, v in kubernetes_manifest.peer_authentications : k => {
      name             = v.manifest.metadata.name
      namespace        = v.manifest.metadata.namespace
      selector         = v.manifest.spec.selector
      mtls             = v.manifest.spec.mtls
      port_level_mtls  = v.manifest.spec.portLevelMtls
      labels           = v.manifest.metadata.labels
    }
  }
}

output "authorization_policy_names" {
  description = "Names of Istio Authorization policies"
  value = {
    for k, v in kubernetes_manifest.authorization_policies : k => v.manifest.metadata.name
  }
}

output "authorization_policy_details" {
  description = "Detailed information about Istio Authorization policies"
  value = {
    for k, v in kubernetes_manifest.authorization_policies : k => {
      name      = v.manifest.metadata.name
      namespace = v.manifest.metadata.namespace
      selector  = v.manifest.spec.selector
      action    = v.manifest.spec.action
      rules     = v.manifest.spec.rules
      labels    = v.manifest.metadata.labels
    }
  }
}

# Telemetry outputs
output "telemetry_config_names" {
  description = "Names of Istio Telemetry configurations"
  value = {
    for k, v in kubernetes_manifest.telemetry_configs : k => v.manifest.metadata.name
  }
}

output "telemetry_config_details" {
  description = "Detailed information about Istio Telemetry configurations"
  value = {
    for k, v in kubernetes_manifest.telemetry_configs : k => {
      name           = v.manifest.metadata.name
      namespace      = v.manifest.metadata.namespace
      selector       = v.manifest.spec.selector
      metrics        = v.manifest.spec.metrics
      tracing        = v.manifest.spec.tracing
      access_logging = v.manifest.spec.accessLogging
      labels         = v.manifest.metadata.labels
    }
  }
}

# Service Account outputs
output "service_account_email" {
  description = "Email of the ASM service account"
  value       = var.create_service_account ? google_service_account.asm_sa[0].email : null
}

output "service_account_id" {
  description = "ID of the ASM service account"
  value       = var.create_service_account ? google_service_account.asm_sa[0].account_id : null
}

output "service_account_unique_id" {
  description = "Unique ID of the ASM service account"
  value       = var.create_service_account ? google_service_account.asm_sa[0].unique_id : null
}

# Monitoring outputs
output "monitoring_dashboard_id" {
  description = "ID of the ASM monitoring dashboard"
  value       = var.enable_monitoring && var.create_dashboard ? google_monitoring_dashboard.asm_dashboard[0].id : null
}

output "monitoring_dashboard_url" {
  description = "URL to the ASM monitoring dashboard"
  value = var.enable_monitoring && var.create_dashboard ? (
    "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.asm_dashboard[0].id}?project=${var.project_id}"
  ) : null
}

output "alert_policy_ids" {
  description = "IDs of created alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.asm_alerts : k => v.id
  }
}

output "alert_policy_names" {
  description = "Names of created alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.asm_alerts : k => v.display_name
  }
}

# Configuration metadata
output "configuration_metadata" {
  description = "Metadata about the Anthos Service Mesh configuration"
  value = {
    project_id                      = var.project_id
    service_mesh_enabled            = var.enable_service_mesh
    cluster_memberships_count       = length(google_gke_hub_membership.cluster_memberships)
    service_mesh_memberships_count  = length(google_gke_hub_feature_membership.service_mesh_memberships)
    istio_namespaces_count         = length(kubernetes_namespace.istio_system)
    istio_control_planes_count     = length(kubernetes_manifest.istio_control_plane)
    istio_gateways_count           = length(kubernetes_manifest.istio_gateways)
    virtual_services_count         = length(kubernetes_manifest.virtual_services)
    destination_rules_count        = length(kubernetes_manifest.destination_rules)
    service_entries_count          = length(kubernetes_manifest.service_entries)
    sidecar_configs_count          = length(kubernetes_manifest.sidecars)
    peer_authentications_count     = length(kubernetes_manifest.peer_authentications)
    authorization_policies_count   = length(kubernetes_manifest.authorization_policies)
    telemetry_configs_count        = length(kubernetes_manifest.telemetry_configs)
    monitoring_enabled             = var.enable_monitoring
    audit_logging_enabled          = var.enable_audit_logging
    multi_cluster_enabled          = var.enable_multi_cluster
    fleet_workload_identity_enabled = var.enable_fleet_workload_identity
    observability_enabled          = var.enable_observability
    traffic_management_enabled     = var.enable_traffic_management
    security_policies_enabled      = var.enable_security_policies
    total_alert_policies           = length(google_monitoring_alert_policy.asm_alerts)
  }
}

# Service mesh configuration summary
output "service_mesh_summary" {
  description = "Summary of service mesh configuration"
  value = {
    mesh_status = {
      enabled         = var.enable_service_mesh
      feature_enabled = var.enable_service_mesh ? google_gke_hub_feature.service_mesh[0].name != "" : false
      memberships     = length(google_gke_hub_feature_membership.service_mesh_memberships)
    }
    control_plane = {
      configurations = length(var.istio_control_plane_configs)
      revisions = [
        for config in var.istio_control_plane_configs : config.revision
      ]
      hubs = [
        for config in var.istio_control_plane_configs : config.hub
      ]
      tags = [
        for config in var.istio_control_plane_configs : config.tag
      ]
    }
    networking = {
      gateways         = length(var.istio_gateways)
      virtual_services = length(var.virtual_services)
      destination_rules = length(var.destination_rules)
      service_entries  = length(var.service_entries)
    }
    security = {
      peer_authentications   = length(var.peer_authentications)
      authorization_policies = length(var.authorization_policies)
      mtls_enabled = length([
        for pa in var.peer_authentications : pa if pa.mtls != null && pa.mtls.mode == "STRICT"
      ]) > 0
    }
    observability = {
      telemetry_configs = length(var.telemetry_configs)
      monitoring_enabled = var.enable_monitoring
      tracing_enabled = var.observability_config.enable_distributed_tracing
      metrics_enabled = var.observability_config.enable_metrics_collection
      access_logging_enabled = var.observability_config.enable_access_logging
    }
  }
}

# Multi-cluster configuration
output "multi_cluster_configuration" {
  description = "Multi-cluster configuration details"
  value = var.enable_multi_cluster ? {
    enabled         = var.enable_multi_cluster
    primary_cluster = var.multi_cluster_config.primary_cluster
    remote_clusters = var.multi_cluster_config.remote_clusters
    network_endpoints = var.multi_cluster_config.network_endpoints
    cross_network_policy = var.multi_cluster_config.cross_network_policy
  } : null
}

# Fleet Workload Identity configuration
output "fleet_workload_identity_configuration" {
  description = "Fleet Workload Identity configuration details"
  value = var.enable_fleet_workload_identity ? {
    enabled                 = var.enable_fleet_workload_identity
    fleet_project_id        = var.fleet_workload_identity_config.fleet_project_id
    workload_identity_pool  = var.fleet_workload_identity_config.workload_identity_pool
    service_account_mapping = var.fleet_workload_identity_config.service_account_mapping
  } : null
}

# Observability configuration
output "observability_configuration" {
  description = "Observability configuration details"
  value = {
    enabled                    = var.enable_observability
    distributed_tracing        = var.observability_config.enable_distributed_tracing
    access_logging            = var.observability_config.enable_access_logging
    metrics_collection        = var.observability_config.enable_metrics_collection
    trace_sampling_rate       = var.observability_config.trace_sampling_rate
    custom_dashboards         = var.observability_config.custom_dashboards
    alerting_rules           = var.observability_config.alerting_rules
  }
}

# Traffic management configuration
output "traffic_management_configuration" {
  description = "Traffic management configuration details"
  value = {
    enabled               = var.enable_traffic_management
    traffic_splitting     = var.traffic_management_config.enable_traffic_splitting
    circuit_breaker       = var.traffic_management_config.enable_circuit_breaker
    retry_policies        = var.traffic_management_config.enable_retry_policies
    timeout_policies      = var.traffic_management_config.enable_timeout_policies
    default_timeout       = var.traffic_management_config.default_timeout
    default_retry_attempts = var.traffic_management_config.default_retry_attempts
  }
}

# Security policy configuration
output "security_policy_configuration" {
  description = "Security policy configuration details"
  value = {
    enabled               = var.enable_security_policies
    default_deny_all      = var.security_policy_config.default_deny_all
    mtls_strict           = var.security_policy_config.enable_mtls_strict
    authorization_enabled = var.security_policy_config.enable_authorization
    custom_ca_certificates = length(var.security_policy_config.custom_ca_certificates)
    jwt_policies          = length(var.security_policy_config.jwt_policies)
  }
}

# Certificate configuration
output "certificate_configuration" {
  description = "Certificate configuration details"
  value = var.enable_service_mesh_certificates ? {
    enabled              = var.enable_service_mesh_certificates
    ca_pool              = var.certificate_config.ca_pool
    certificate_lifetime = var.certificate_config.certificate_lifetime
    key_algorithm        = var.certificate_config.key_algorithm
    key_size            = var.certificate_config.key_size
    automatic_renewal    = var.certificate_config.automatic_renewal
  } : null
}

# Management URLs
output "management_urls" {
  description = "URLs for managing Anthos Service Mesh resources"
  value = {
    anthos_console = "https://console.cloud.google.com/anthos?project=${var.project_id}"
    gke_hub_console = "https://console.cloud.google.com/kubernetes/clusters?project=${var.project_id}"
    service_mesh_console = "https://console.cloud.google.com/anthos/services?project=${var.project_id}"
    monitoring_console = var.enable_monitoring ? "https://console.cloud.google.com/monitoring?project=${var.project_id}" : null
    logs_console = "https://console.cloud.google.com/logs/query?project=${var.project_id}"
    security_console = "https://console.cloud.google.com/security?project=${var.project_id}"
    istio_dashboard = var.enable_monitoring && var.create_dashboard ? google_monitoring_dashboard.asm_dashboard[0].id : null
  }
}

# Resource identifiers for integration
output "resource_identifiers" {
  description = "Resource identifiers for integration with other modules"
  value = {
    cluster_membership_resources = {
      for k, v in google_gke_hub_membership.cluster_memberships : k => v.name
    }
    service_mesh_feature_resource = var.enable_service_mesh ? google_gke_hub_feature.service_mesh[0].name : null
    service_mesh_membership_resources = {
      for k, v in google_gke_hub_feature_membership.service_mesh_memberships : k => v.membership
    }
    istio_control_plane_resources = {
      for k, v in kubernetes_manifest.istio_control_plane : k => v.manifest.metadata.name
    }
    gateway_resources = {
      for k, v in kubernetes_manifest.istio_gateways : k => v.manifest.metadata.name
    }
    service_account_resource = var.create_service_account ? google_service_account.asm_sa[0].email : null
  }
}

# Istio configuration versions
output "istio_versions" {
  description = "Istio versions and configurations"
  value = {
    for k, v in var.istio_control_plane_configs : k => {
      hub      = v.hub
      tag      = v.tag
      revision = v.revision
      mesh_id  = v.mesh_id
      network  = v.network
    }
  }
}

# Network and connectivity summary
output "network_connectivity_summary" {
  description = "Network and connectivity configuration summary"
  value = {
    total_gateways = length(var.istio_gateways)
    gateway_configurations = {
      for k, v in var.istio_gateways : k => {
        namespace = v.namespace
        servers_count = length(v.servers)
        tls_enabled = length([for server in v.servers : server if server.tls != null]) > 0
      }
    }
    external_services = length(var.service_entries)
    traffic_policies = length(var.destination_rules)
    virtual_services = length(var.virtual_services)
  }
}

# Health and status indicators
output "health_status" {
  description = "Health and status indicators for the service mesh"
  value = {
    service_mesh_feature_status = var.enable_service_mesh ? "enabled" : "disabled"
    cluster_memberships_healthy = length(local.all_cluster_memberships) == length(google_gke_hub_membership.cluster_memberships)
    control_plane_configured = length(var.istio_control_plane_configs) > 0
    security_policies_configured = length(var.peer_authentications) > 0 || length(var.authorization_policies) > 0
    monitoring_configured = var.enable_monitoring
    observability_configured = var.enable_observability
  }
}