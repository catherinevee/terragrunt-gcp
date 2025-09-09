# VPC Network Configuration for Development Environment

terraform {
  source = "../../modules/networking/vpc"
}

include "root" {
  path = find_in_parent_folders()
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  common_vars = read_terragrunt_config(find_in_parent_folders("terragrunt.hcl"))
}

inputs = {
  name = "${local.env_vars.locals.environment}-${local.env_vars.locals.region}-vpc"
  
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  mtu                     = 1460
  
  delete_default_routes_on_create = false
  
  description = "VPC network for ${local.env_vars.locals.environment} environment in ${local.env_vars.locals.region}"
  
  # Subnets configuration
  subnets = [
    {
      subnet_name           = "${local.env_vars.locals.environment}-${local.env_vars.locals.region}-subnet-main"
      subnet_ip             = "10.0.1.0/24"
      subnet_region         = local.env_vars.locals.region
      subnet_private_access = true
      subnet_flow_logs      = local.env_vars.locals.security_config.enable_flow_logs
      description           = "Main subnet for ${local.env_vars.locals.environment}"
    },
    {
      subnet_name           = "${local.env_vars.locals.environment}-${local.env_vars.locals.region}-subnet-gke"
      subnet_ip             = "10.0.2.0/24"
      subnet_region         = local.env_vars.locals.region
      subnet_private_access = true
      subnet_flow_logs      = local.env_vars.locals.security_config.enable_flow_logs
      description           = "GKE subnet for ${local.env_vars.locals.environment}"
    },
    {
      subnet_name           = "${local.env_vars.locals.environment}-${local.env_vars.locals.region}-subnet-db"
      subnet_ip             = "10.0.3.0/24"
      subnet_region         = local.env_vars.locals.region
      subnet_private_access = true
      subnet_flow_logs      = false
      description           = "Database subnet for ${local.env_vars.locals.environment}"
    }
  ]
  
  # Secondary ranges for GKE
  secondary_ranges = {
    "${local.env_vars.locals.environment}-${local.env_vars.locals.region}-subnet-gke" = [
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
  
  # Firewall rules
  firewall_rules = [
    {
      name        = "${local.env_vars.locals.environment}-allow-internal"
      description = "Allow internal traffic"
      direction   = "INGRESS"
      priority    = 1000
      
      source_ranges = ["10.0.0.0/16"]
      
      allow = [{
        protocol = "tcp"
        ports    = []
      },
      {
        protocol = "udp"
        ports    = []
      },
      {
        protocol = "icmp"
        ports    = []
      }]
    },
    {
      name        = "${local.env_vars.locals.environment}-allow-ssh-iap"
      description = "Allow SSH from IAP"
      direction   = "INGRESS"
      priority    = 1001
      
      source_ranges = ["35.235.240.0/20"]  # IAP IP range
      
      allow = [{
        protocol = "tcp"
        ports    = ["22"]
      }]
      
      target_tags = ["allow-ssh"]
    },
    {
      name        = "${local.env_vars.locals.environment}-allow-health-checks"
      description = "Allow GCP health checks"
      direction   = "INGRESS"
      priority    = 1002
      
      source_ranges = [
        "35.191.0.0/16",   # Google Cloud health checks
        "130.211.0.0/22"   # Google Cloud health checks
      ]
      
      allow = [{
        protocol = "tcp"
        ports    = []
      }]
      
      target_tags = ["allow-health-checks"]
    }
  ]
  
  # Cloud NAT configuration
  enable_cloud_nat = true
  nat_config = {
    name                               = "${local.env_vars.locals.environment}-${local.env_vars.locals.region}-nat"
    source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
    min_ports_per_vm                   = 64
    max_ports_per_vm                   = 2048
    tcp_established_idle_timeout_sec   = 1200
    tcp_transitory_idle_timeout_sec    = 30
    enable_endpoint_independent_mapping = false
  }
  
  # VPC Connector for serverless
  enable_vpc_connector = true
  vpc_connector_config = {
    name          = "${local.env_vars.locals.environment}-${local.env_vars.locals.region}-connector"
    ip_cidr_range = "10.0.4.0/28"
    min_instances = 2
    max_instances = 3
    machine_type  = "f1-micro"
  }
  
  labels = merge(
    local.common_vars.locals.common_labels,
    local.env_vars.locals.environment_labels,
    {
      component = "networking"
      resource  = "vpc"
    }
  )
  
  tags = local.env_vars.locals.environment_tags
}