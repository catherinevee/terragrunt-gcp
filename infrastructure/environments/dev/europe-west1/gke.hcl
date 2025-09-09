# GKE Cluster Configuration for Development Environment

terraform {
  source = "../../modules/compute/gke"
}

include "root" {
  path = find_in_parent_folders()
}

dependency "vpc" {
  config_path = "./dev-europe-west1-vpc"
  
  mock_outputs = {
    network_self_link = "mock-network"
    subnet_self_links = {
      "dev-europe-west1-subnet-gke" = "mock-subnet"
    }
  }
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  common_vars = read_terragrunt_config(find_in_parent_folders("terragrunt.hcl"))
}

inputs = {
  name = "${local.env_vars.locals.environment}-${local.env_vars.locals.region}-gke"
  
  regional = true
  region   = local.env_vars.locals.region
  
  network    = dependency.vpc.outputs.network_self_link
  subnetwork = dependency.vpc.outputs.subnet_self_links["${local.env_vars.locals.environment}-${local.env_vars.locals.region}-subnet-gke"]
  
  pods_range_name     = "gke-pods"
  services_range_name = "gke-services"
  
  # Cluster configuration
  kubernetes_version = "1.27"  # Specify version or use "latest"
  
  # Private cluster settings
  enable_private_nodes    = local.env_vars.locals.security_config.enable_private_google_access
  enable_private_endpoint = false  # Keep false for dev to allow external access
  master_ipv4_cidr_block = "172.16.0.0/28"
  master_global_access   = true
  
  # Security
  enable_workload_identity     = true
  enable_binary_authorization  = local.env_vars.locals.security_config.enable_binary_authorization
  enable_shielded_nodes       = true
  enable_secure_boot          = true
  enable_integrity_monitoring = true
  
  # Maintenance window
  maintenance_start_time = "03:00"
  
  # Autoscaling
  enable_cluster_autoscaling = true
  cluster_autoscaling_resource_limits = [
    {
      resource_type = "cpu"
      minimum       = 1
      maximum       = 50
    },
    {
      resource_type = "memory"
      minimum       = 1
      maximum       = 200
    }
  ]
  
  # Network policy
  network_policy_enabled = true
  
  # Addons
  enable_http_load_balancing         = true
  enable_horizontal_pod_autoscaling  = true
  enable_gce_pd_csi_driver           = true
  enable_dns_cache                   = true
  enable_managed_prometheus          = false
  
  # Logging and monitoring
  logging_enabled_components   = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  monitoring_enabled_components = ["SYSTEM_COMPONENTS"]
  
  # Service account (create separately in IAM module)
  service_account = "${local.env_vars.locals.environment}-gke-sa@${local.common_vars.locals.project_id}.iam.gserviceaccount.com"
  
  # Node pools configuration
  node_pools = {
    general = {
      min_nodes    = local.env_vars.locals.gke_config.min_nodes
      max_nodes    = local.env_vars.locals.gke_config.max_nodes
      machine_type = local.env_vars.locals.gke_config.machine_type
      disk_size_gb = local.env_vars.locals.gke_config.disk_size_gb
      disk_type    = "pd-standard"
      preemptible  = local.env_vars.locals.gke_config.preemptible
      auto_repair  = local.env_vars.locals.gke_config.auto_repair
      auto_upgrade = local.env_vars.locals.gke_config.auto_upgrade
      
      labels = {
        pool = "general"
        workload = "mixed"
      }
      
      tags = ["gke-node", "dev"]
    }
    
    spot = {
      min_nodes    = 0
      max_nodes    = 2
      machine_type = "n1-standard-2"
      disk_size_gb = 30
      preemptible  = true
      auto_repair  = true
      auto_upgrade = true
      
      labels = {
        pool = "spot"
        workload = "batch"
      }
      
      taints = [
        {
          key    = "workload"
          value  = "batch"
          effect = "NO_SCHEDULE"
        }
      ]
      
      tags = ["gke-node", "spot", "dev"]
    }
  }
  
  # Master authorized networks (for dev, allow broader access)
  master_authorized_networks = [
    {
      cidr_block   = "0.0.0.0/0"  # In production, restrict this
      display_name = "All networks (dev only)"
    }
  ]
  
  labels = merge(
    local.common_vars.locals.common_labels,
    local.env_vars.locals.environment_labels,
    {
      component = "compute"
      resource  = "gke"
    }
  )
  
  tags = concat(
    local.env_vars.locals.environment_tags,
    ["gke-cluster"]
  )
}