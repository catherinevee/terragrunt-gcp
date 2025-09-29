# GKE Cluster Module Outputs

# Cluster Information
output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.cluster.name
}

output "cluster_id" {
  description = "The ID of the GKE cluster"
  value       = google_container_cluster.cluster.id
}

output "cluster_self_link" {
  description = "The self link of the GKE cluster"
  value       = google_container_cluster.cluster.self_link
}

output "cluster_endpoint" {
  description = "The endpoint for the GKE cluster"
  value       = google_container_cluster.cluster.endpoint
  sensitive   = true
}

output "cluster_master_version" {
  description = "The master version of the GKE cluster"
  value       = google_container_cluster.cluster.master_version
}

output "cluster_location" {
  description = "The location of the GKE cluster"
  value       = google_container_cluster.cluster.location
}

output "cluster_region" {
  description = "The region of the GKE cluster"
  value = try(
    regex("^[a-z]+-[a-z]+[0-9]+", google_container_cluster.cluster.location),
    google_container_cluster.cluster.location
  )
}

output "cluster_zones" {
  description = "The zones where the cluster is deployed"
  value       = google_container_cluster.cluster.node_locations
}

# Network Information
output "cluster_network" {
  description = "The network the cluster is attached to"
  value       = google_container_cluster.cluster.network
}

output "cluster_subnetwork" {
  description = "The subnetwork the cluster is attached to"
  value       = google_container_cluster.cluster.subnetwork
}

output "cluster_ipv4_cidr" {
  description = "The IP address range of pods in the cluster"
  value       = google_container_cluster.cluster.cluster_ipv4_cidr
}

output "services_ipv4_cidr" {
  description = "The IP address range of services in the cluster"
  value       = google_container_cluster.cluster.services_ipv4_cidr
}

output "master_ipv4_cidr_block" {
  description = "The IP range in CIDR notation for the master"
  value       = try(google_container_cluster.cluster.private_cluster_config[0].master_ipv4_cidr_block, null)
}

# Private Cluster Information
output "is_private_cluster" {
  description = "Whether this is a private cluster"
  value       = try(google_container_cluster.cluster.private_cluster_config[0].enable_private_nodes, false)
}

output "is_private_endpoint" {
  description = "Whether the master endpoint is private"
  value       = try(google_container_cluster.cluster.private_cluster_config[0].enable_private_endpoint, false)
}

output "public_endpoint" {
  description = "The public endpoint for the cluster"
  value       = try(google_container_cluster.cluster.private_cluster_config[0].public_endpoint, google_container_cluster.cluster.endpoint)
  sensitive   = true
}

output "private_endpoint" {
  description = "The private endpoint for the cluster"
  value       = try(google_container_cluster.cluster.private_cluster_config[0].private_endpoint, null)
  sensitive   = true
}

output "peering_name" {
  description = "The name of the peering connection"
  value       = try(google_container_cluster.cluster.private_cluster_config[0].peering_name, null)
}

# Authentication
output "cluster_ca_certificate" {
  description = "The base64 encoded CA certificate"
  value       = google_container_cluster.cluster.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "master_auth" {
  description = "The master auth configuration"
  value       = google_container_cluster.cluster.master_auth
  sensitive   = true
}

# Node Pool Information
output "node_pools" {
  description = "List of node pools and their configurations"
  value = [
    for np in google_container_cluster.cluster.node_pool : {
      name               = np.name
      initial_node_count = np.initial_node_count
      node_count         = np.node_count
      version            = np.version
      max_pods_per_node  = np.max_pods_per_node
      node_locations     = np.node_locations

      autoscaling = try({
        min_node_count       = np.autoscaling[0].min_node_count
        max_node_count       = np.autoscaling[0].max_node_count
        total_min_node_count = np.autoscaling[0].total_min_node_count
        total_max_node_count = np.autoscaling[0].total_max_node_count
        location_policy      = np.autoscaling[0].location_policy
      }, null)

      node_config = {
        machine_type    = np.node_config[0].machine_type
        disk_size_gb    = np.node_config[0].disk_size_gb
        disk_type       = np.node_config[0].disk_type
        preemptible     = np.node_config[0].preemptible
        spot            = np.node_config[0].spot
        image_type      = np.node_config[0].image_type
        service_account = np.node_config[0].service_account
        oauth_scopes    = np.node_config[0].oauth_scopes
        tags            = np.node_config[0].tags
        labels          = np.node_config[0].labels
        metadata        = np.node_config[0].metadata
      }

      management = {
        auto_repair  = np.management[0].auto_repair
        auto_upgrade = np.management[0].auto_upgrade
      }
    }
  ]
}

output "node_pool_names" {
  description = "Names of all node pools"
  value       = [for np in google_container_cluster.cluster.node_pool : np.name]
}

output "default_node_pool_name" {
  description = "Name of the default node pool"
  value       = try(google_container_cluster.cluster.node_pool[0].name, null)
}

# Workload Identity
output "workload_identity_config" {
  description = "Workload identity configuration"
  value       = google_container_cluster.cluster.workload_identity_config
}

output "identity_namespace" {
  description = "The workload identity namespace"
  value = try(
    google_container_cluster.cluster.workload_identity_config[0].workload_pool,
    null
  )
}

# Service Accounts
output "service_account" {
  description = "The service account used by nodes"
  value       = try(google_container_cluster.cluster.node_config[0].service_account, null)
}

# Addons Configuration
output "addons_config" {
  description = "The addons configuration"
  value       = google_container_cluster.cluster.addons_config
}

output "http_load_balancing_enabled" {
  description = "Whether HTTP load balancing is enabled"
  value       = !google_container_cluster.cluster.addons_config[0].http_load_balancing[0].disabled
}

output "horizontal_pod_autoscaling_enabled" {
  description = "Whether horizontal pod autoscaling is enabled"
  value       = !google_container_cluster.cluster.addons_config[0].horizontal_pod_autoscaling[0].disabled
}

output "network_policy_enabled" {
  description = "Whether network policy is enabled"
  value       = google_container_cluster.cluster.network_policy[0].enabled
}

output "istio_enabled" {
  description = "Whether Istio is enabled"
  value       = try(!google_container_cluster.cluster.addons_config[0].istio_config[0].disabled, false)
}

output "dns_cache_enabled" {
  description = "Whether NodeLocal DNSCache is enabled"
  value       = try(google_container_cluster.cluster.addons_config[0].dns_cache_config[0].enabled, false)
}

# Autoscaling
output "cluster_autoscaling_enabled" {
  description = "Whether cluster autoscaling is enabled"
  value       = try(google_container_cluster.cluster.cluster_autoscaling[0].enabled, false)
}

output "vertical_pod_autoscaling_enabled" {
  description = "Whether vertical pod autoscaling is enabled"
  value       = google_container_cluster.cluster.vertical_pod_autoscaling[0].enabled
}

# Maintenance
output "maintenance_policy" {
  description = "The maintenance policy configuration"
  value       = google_container_cluster.cluster.maintenance_policy
}

# Monitoring and Logging
output "logging_service" {
  description = "The logging service being used"
  value       = google_container_cluster.cluster.logging_service
}

output "monitoring_service" {
  description = "The monitoring service being used"
  value       = google_container_cluster.cluster.monitoring_service
}

output "monitoring_config" {
  description = "The monitoring configuration"
  value       = try(google_container_cluster.cluster.monitoring_config, null)
}

output "logging_config" {
  description = "The logging configuration"
  value       = try(google_container_cluster.cluster.logging_config, null)
}

# Security
output "binary_authorization" {
  description = "Binary authorization configuration"
  value       = try(google_container_cluster.cluster.binary_authorization, null)
}

output "shielded_nodes_enabled" {
  description = "Whether shielded nodes is enabled"
  value       = google_container_cluster.cluster.enable_shielded_nodes
}

output "database_encryption" {
  description = "Database encryption configuration"
  value       = try(google_container_cluster.cluster.database_encryption, null)
}

output "confidential_nodes" {
  description = "Confidential nodes configuration"
  value       = try(google_container_cluster.cluster.confidential_nodes, null)
}

# Resource Usage Export
output "resource_usage_export_config" {
  description = "Resource usage export configuration"
  value       = try(google_container_cluster.cluster.resource_usage_export_config, null)
}

# Labels and Resource Labels
output "cluster_labels" {
  description = "The cluster labels"
  value       = google_container_cluster.cluster.resource_labels
}

output "label_fingerprint" {
  description = "The fingerprint of the cluster labels"
  value       = google_container_cluster.cluster.label_fingerprint
}

# kubectl Commands
output "get_credentials_command" {
  description = "gcloud command to get credentials for the cluster"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.cluster.name} --location ${google_container_cluster.cluster.location} --project ${var.project_id}"
}

output "kubectl_config" {
  description = "kubectl configuration commands"
  value = {
    set_context = "kubectl config set-context ${google_container_cluster.cluster.name} --cluster=gke_${var.project_id}_${google_container_cluster.cluster.location}_${google_container_cluster.cluster.name}"

    use_context = "kubectl config use-context ${google_container_cluster.cluster.name}"

    get_nodes = "kubectl get nodes"

    get_pods = "kubectl get pods --all-namespaces"

    describe_cluster = "kubectl cluster-info"
  }
}

# Console URLs
output "console_urls" {
  description = "Google Cloud Console URLs for the cluster"
  value = {
    cluster = "https://console.cloud.google.com/kubernetes/clusters/details/${google_container_cluster.cluster.location}/${google_container_cluster.cluster.name}?project=${var.project_id}"

    workloads = "https://console.cloud.google.com/kubernetes/workload?project=${var.project_id}&location=${google_container_cluster.cluster.location}&cluster=${google_container_cluster.cluster.name}"

    services = "https://console.cloud.google.com/kubernetes/discovery?project=${var.project_id}&location=${google_container_cluster.cluster.location}&cluster=${google_container_cluster.cluster.name}"

    storage = "https://console.cloud.google.com/kubernetes/storage?project=${var.project_id}&location=${google_container_cluster.cluster.location}&cluster=${google_container_cluster.cluster.name}"

    monitoring = "https://console.cloud.google.com/monitoring/dashboards?project=${var.project_id}&dashboardId=gke"
  }
}

# API Endpoints
output "api_endpoints" {
  description = "API endpoints for cluster management"
  value = {
    container_api = "https://container.googleapis.com/v1/projects/${var.project_id}/locations/${google_container_cluster.cluster.location}/clusters/${google_container_cluster.cluster.name}"

    kubernetes_api = "https://${google_container_cluster.cluster.endpoint}"
  }
  sensitive = true
}

# Features Status
output "features" {
  description = "Status of various cluster features"
  value = {
    autopilot               = google_container_cluster.cluster.enable_autopilot
    kubernetes_alpha        = google_container_cluster.cluster.enable_kubernetes_alpha
    tpu                     = google_container_cluster.cluster.enable_tpu
    legacy_abac             = google_container_cluster.cluster.enable_legacy_abac
    intranode_visibility    = google_container_cluster.cluster.enable_intranode_visibility
    l4_ilb_subsetting       = google_container_cluster.cluster.enable_l4_ilb_subsetting
    datapath_provider       = google_container_cluster.cluster.datapath_provider
    network_policy_provider = try(google_container_cluster.cluster.network_policy[0].provider, null)
    default_snat_disabled   = try(google_container_cluster.cluster.default_snat_status[0].disabled, false)
  }
}

# Notification Configuration
output "notification_config" {
  description = "Notification configuration"
  value       = try(google_container_cluster.cluster.notification_config, null)
}

# Status Information
output "cluster_status" {
  description = "The current status of the cluster"
  value       = google_container_cluster.cluster.status
}

output "cluster_status_message" {
  description = "Additional information about the cluster status"
  value       = google_container_cluster.cluster.status_message
}

output "operation" {
  description = "The operation currently running on the cluster"
  value       = google_container_cluster.cluster.operation
}

# Import Commands
output "import_command" {
  description = "Terraform import command for the cluster"
  value       = "terraform import google_container_cluster.cluster projects/${var.project_id}/locations/${google_container_cluster.cluster.location}/clusters/${google_container_cluster.cluster.name}"
}