# GKE Module Outputs

output "cluster_id" {
  description = "The ID of the GKE cluster"
  value       = google_container_cluster.cluster.id
}

output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.cluster.name
}

output "cluster_endpoint" {
  description = "The endpoint for the GKE cluster"
  value       = google_container_cluster.cluster.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "The cluster CA certificate"
  value       = google_container_cluster.cluster.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "The location of the GKE cluster"
  value       = google_container_cluster.cluster.location
}

output "cluster_region" {
  description = "The region of the GKE cluster"
  value       = var.regional ? var.region : regex("^(.*)-[a-z]$", var.zone)[0]
}

output "cluster_zones" {
  description = "The zones where the cluster is deployed"
  value       = google_container_cluster.cluster.node_locations
}

output "master_version" {
  description = "The Kubernetes master version"
  value       = google_container_cluster.cluster.master_version
}

output "node_pools" {
  description = "List of node pool names"
  value       = [for np in google_container_node_pool.node_pools : np.name]
}

output "node_pools_details" {
  description = "Details of all node pools"
  value = {
    for k, v in google_container_node_pool.node_pools : k => {
      name               = v.name
      initial_node_count = v.initial_node_count
      min_node_count    = v.autoscaling[0].min_node_count
      max_node_count    = v.autoscaling[0].max_node_count
      machine_type      = v.node_config[0].machine_type
      disk_size_gb      = v.node_config[0].disk_size_gb
      preemptible       = v.node_config[0].preemptible
    }
  }
}

output "service_account" {
  description = "The service account used by nodes"
  value       = var.service_account
}

output "workload_identity_pool" {
  description = "Workload Identity pool ID"
  value       = var.enable_workload_identity ? "${var.project_id}.svc.id.goog" : null
}