# VPC configuration for development environment

terraform {
  source = "../../modules//networking/vpc"
}

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("env.hcl")
  expose = true
}

locals {
  env_vars = include.env.locals
}

inputs = {
  name = "${local.env_vars.environment}-vpc"
  
  auto_create_subnetworks = false
  routing_mode = "REGIONAL"
  mtu = 1460
  
  description = "VPC network for ${local.env_vars.environment} environment"
  
  subnets = [
    {
      subnet_name           = "${local.env_vars.environment}-subnet-public"
      subnet_ip             = local.env_vars.network_config.public_subnet_cidr
      subnet_region         = local.env_vars.region
      subnet_private_access = true
      subnet_flow_logs      = true
      description          = "Public subnet for ${local.env_vars.environment}"
    },
    {
      subnet_name           = "${local.env_vars.environment}-subnet-private"
      subnet_ip             = local.env_vars.network_config.private_subnet_cidr
      subnet_region         = local.env_vars.region
      subnet_private_access = true
      subnet_flow_logs      = true
      description          = "Private subnet for ${local.env_vars.environment}"
    }
  ]
  
  secondary_ranges = {
    "${local.env_vars.environment}-subnet-private" = [
      {
        range_name    = "pods"
        ip_cidr_range = local.env_vars.network_config.pods_subnet_cidr
      },
      {
        range_name    = "services"
        ip_cidr_range = local.env_vars.network_config.services_subnet_cidr
      }
    ]
  }
  
  firewall_rules = [
    {
      name        = "allow-internal"
      description = "Allow internal traffic"
      direction   = "INGRESS"
      priority    = 1000
      source_ranges = [local.env_vars.network_config.vpc_cidr]
      allow = [
        {
          protocol = "icmp"
        },
        {
          protocol = "tcp"
          ports    = ["0-65535"]
        },
        {
          protocol = "udp"
          ports    = ["0-65535"]
        }
      ]
    },
    {
      name        = "allow-ssh-iap"
      description = "Allow SSH from IAP"
      direction   = "INGRESS"
      priority    = 1000
      source_ranges = ["35.235.240.0/20"]  # IAP IP range
      target_tags = ["ssh"]
      allow = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    },
    {
      name        = "allow-health-checks"
      description = "Allow health checks from GCP"
      direction   = "INGRESS"
      priority    = 1000
      source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]  # GCP health check ranges
      target_tags = ["health-check"]
      allow = [
        {
          protocol = "tcp"
          ports    = ["80", "443"]
        }
      ]
    }
  ]
  
  enable_cloud_nat = true
  
  nat_config = {
    name = "${local.env_vars.environment}-nat-gateway"
    source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
    subnetworks = [
      {
        name = "${local.env_vars.environment}-subnet-private"
        source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
      }
    ]
    min_ports_per_vm = 64
    max_ports_per_vm = 2048
    tcp_established_idle_timeout_sec = 1200
    tcp_transitory_idle_timeout_sec = 30
    enable_endpoint_independent_mapping = false
  }
  
  enable_vpc_connector = false  # Will enable when needed for serverless
  
  enable_private_service_connection = true
  
  labels = merge(
    local.env_vars.environment_tags,
    {
      component = "networking"
      resource  = "vpc"
    }
  )
}