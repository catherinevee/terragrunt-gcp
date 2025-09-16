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
  project_id   = "acme-ecommerce-platform-${local.environment}"
  network_name = "acme-ecommerce-platform-vpc-${local.environment}"
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name           = "acme-ecommerce-web-tier-${local.environment}"
      subnet_ip             = "10.0.1.0/24"
      subnet_region         = local.region
      subnet_private_access = "true"
      subnet_flow_logs      = "true"
      description           = "Main subnet for ${local.environment} in ${local.region}"
    },
    {
      subnet_name           = "acme-ecommerce-app-tier-${local.environment}"
      subnet_ip             = "10.0.2.0/24"
      subnet_region         = local.region
      subnet_private_access = "true"
      subnet_flow_logs      = "true"
      description           = "Secondary subnet for ${local.environment} in ${local.region}"
    }
  ]

  secondary_ranges = {
    "acme-ecommerce-web-tier-${local.environment}" = [
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
      name        = "acme-ecommerce-allow-internal-${local.environment}"
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