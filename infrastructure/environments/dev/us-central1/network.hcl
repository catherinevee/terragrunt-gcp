terraform {
  # Source from Terraform Registry - Google Network Module
  source = "tfr:///terraform-google-modules/network/google?version=9.0.0"
}

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("env.hcl")
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.env_vars.locals.environment
  region = "us-central1"
}

inputs = {
  project_id   = "${local.environment}-project"
  network_name = "${local.environment}-${local.region}-vpc"
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name           = "${local.environment}-${local.region}-subnet-01"
      subnet_ip             = "10.0.1.0/24"
      subnet_region         = local.region
      subnet_private_access = "true"
      subnet_flow_logs      = "true"
      description           = "Main subnet for ${local.environment} in ${local.region}"
    },
    {
      subnet_name           = "${local.environment}-${local.region}-subnet-02"
      subnet_ip             = "10.0.2.0/24"
      subnet_region         = local.region
      subnet_private_access = "true"
      subnet_flow_logs      = "true"
      description           = "Secondary subnet for ${local.environment} in ${local.region}"
    }
  ]

  secondary_ranges = {
    "${local.environment}-${local.region}-subnet-01" = [
      {
        range_name    = "gke-pods"
        ip_cidr_range = "10.1.0.0/16"
      },
      {
        range_name    = "gke-services"
        ip_cidr_range = "10.2.0.0/16"
      }
    ]
  }

  routes = []
  
  firewall_rules = [
    {
      name        = "${local.environment}-allow-internal"
      description = "Allow internal traffic"
      direction   = "INGRESS"
      priority    = 1000
      ranges      = ["10.0.0.0/8"]
      allow = [{
        protocol = "all"
        ports    = []
      }]
    }
  ]
}