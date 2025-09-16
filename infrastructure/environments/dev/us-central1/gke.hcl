terraform {
  # Source from Terraform Registry - Google Kubernetes Engine Module
  source = "tfr:///terraform-google-modules/kubernetes-engine/google?version=29.0.0"
}

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("env.hcl")
}

dependency "network" {
  config_path = "../network"
  
  mock_outputs = {
    network_name = "mock-network"
    subnets_names = ["mock-subnet"]
    subnets_secondary_ranges = [
      [
        {
          range_name    = "gke-pods"
          ip_cidr_range = "10.1.0.0/16"
        },
        {
          range_name    = "gke-services"
          ip_cidr_range = "10.2.0.0/16"
        }
      ]
    ]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.env_vars.locals.environment
  region = "us-central1"
}

inputs = {
  project_id = "acme-ecommerce-platform-${local.environment}"
  name       = "acme-customer-api-gke-${local.environment}"
  region     = local.region
  zones      = ["${local.region}-a", "${local.region}-b", "${local.region}-c"]

  network           = dependency.network.outputs.network_name
  subnetwork        = dependency.network.outputs.subnets_names[0]
  ip_range_pods     = "gke-pods"
  ip_range_services = "gke-services"

  # Node pool configuration
  remove_default_node_pool = true
  initial_node_count       = 1

  node_pools = [
    {
      name               = "acme-customer-api-node-pool"
      machine_type       = "e2-standard-4"
      min_count          = 1
      max_count          = 3
      disk_size_gb       = 100
      disk_type          = "pd-standard"
      image_type         = "COS_CONTAINERD"
      auto_repair        = true
      auto_upgrade       = true
      preemptible        = local.environment != "prod"
      initial_node_count = 1
    }
  ]

  node_pools_oauth_scopes = {
    all = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  node_pools_labels = {
    all = {
      environment = local.environment
      region      = local.region
    }
  }

  node_pools_tags = {
    all = [
      "${local.environment}-gke-node"
    ]
  }

  # Security settings
  enable_private_nodes    = true
  enable_private_endpoint = false
  master_ipv4_cidr_block = "172.16.0.0/28"

  # Features
  horizontal_pod_autoscaling = true
  http_load_balancing        = true
  network_policy             = true
  enable_binary_authorization = false
  
  # Monitoring
  monitoring_service = "monitoring.googleapis.com/kubernetes"
  logging_service    = "logging.googleapis.com/kubernetes"
}