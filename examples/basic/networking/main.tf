# Basic Networking Example
# This demonstrates a simple VPC setup with public and private subnets

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

# Provider configuration
provider "google" {
  project = var.project_id
  region  = var.region
}

# Use the VPC module
module "vpc" {
  source = "../../../modules/networking/vpc"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  # VPC configuration
  vpc_name                        = "${var.environment}-vpc"
  auto_create_subnetworks        = false
  routing_mode                   = "REGIONAL"
  delete_default_routes_on_create = true
  mtu                           = 1460

  # Subnet configurations
  subnets = [
    {
      name                     = "${var.environment}-public-subnet"
      ip_cidr_range           = "10.0.1.0/24"
      region                  = var.region
      private_ip_google_access = true

      flow_logs = true
      flow_logs_interval = "INTERVAL_10_MIN"
      flow_logs_sampling = 0.5
      flow_logs_metadata = "INCLUDE_ALL_METADATA"

      secondary_ip_ranges = []
    },
    {
      name                     = "${var.environment}-private-subnet"
      ip_cidr_range           = "10.0.10.0/24"
      region                  = var.region
      private_ip_google_access = true

      flow_logs = false

      secondary_ip_ranges = []
    }
  ]

  # Basic firewall rules
  firewall_rules = [
    {
      name          = "allow-internal"
      description   = "Allow internal communication"
      direction     = "INGRESS"
      priority      = 1000
      source_ranges = ["10.0.0.0/16"]

      allow = [
        {
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
        }
      ]

      deny = []
      target_tags = []
    },
    {
      name          = "allow-ssh-iap"
      description   = "Allow SSH from IAP"
      direction     = "INGRESS"
      priority      = 900
      source_ranges = ["35.235.240.0/20"]

      allow = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]

      deny = []
      target_tags = ["allow-iap"]
    },
    {
      name          = "allow-http-https"
      description   = "Allow HTTP and HTTPS"
      direction     = "INGRESS"
      priority      = 800
      source_ranges = ["0.0.0.0/0"]

      allow = [
        {
          protocol = "tcp"
          ports    = ["80", "443"]
        }
      ]

      deny = []
      target_tags = ["web-server"]
    }
  ]

  # Cloud NAT for private instances
  create_cloud_nat = true
  nat_name         = "${var.environment}-nat"
  nat_ip_allocate_option = "AUTO_ONLY"

  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  nat_subnetworks = [
    {
      name                    = "${var.environment}-private-subnet"
      source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
    }
  ]

  # Labels
  labels = {
    environment = var.environment
    example     = "basic"
    managed_by  = "terraform"
  }
}

# Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_name" {
  description = "VPC name"
  value       = module.vpc.vpc_name
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = module.vpc.subnet_ids[0]
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = module.vpc.subnet_ids[1]
}

output "nat_ip" {
  description = "Cloud NAT IP address"
  value       = module.vpc.nat_ip
}