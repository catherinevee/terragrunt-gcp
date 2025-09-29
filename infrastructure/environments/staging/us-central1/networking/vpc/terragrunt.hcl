# Staging VPC Configuration - US Central 1
# This configuration creates the staging VPC infrastructure with cost optimizations

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("env.hcl")
}

include "region" {
  path = find_in_parent_folders("region.hcl")
}

terraform {
  source = "../../../../../../modules/networking/vpc"
}

inputs = {
  project_id = local.project_id
  region     = "us-central1"

  # VPC Configuration for staging
  vpc_name        = "staging-usc1-vpc"
  vpc_description = "Staging VPC for testing and validation"

  # Auto create subnetworks disabled for custom configuration
  auto_create_subnetworks = false

  # Basic flow logs (cost optimized)
  enable_flow_logs = local.security_config.enable_flow_logs

  # MTU configuration
  mtu = 1460

  # Network routing mode
  routing_mode = "REGIONAL"

  # Staging-optimized subnet configurations
  subnets = {
    # Private subnet for applications
    private = {
      subnet_name           = "staging-usc1-private"
      subnet_ip             = local.vpc_cidr
      subnet_region         = "us-central1"
      description           = "Private subnet for staging applications"

      # Secondary ranges for GKE
      secondary_ip_range = [
        {
          range_name    = "pods"
          ip_cidr_range = "10.10.64.0/18"
        },
        {
          range_name    = "services"
          ip_cidr_range = "10.10.128.0/20"
        }
      ]

      private_ip_google_access = local.security_config.enable_private_google_access
      enable_flow_logs = local.security_config.enable_flow_logs
      flow_logs_config = {
        aggregation_interval = "INTERVAL_10_SEC"
        flow_sampling       = 0.1  # Reduced sampling for cost
        metadata           = "EXCLUDE_ALL_METADATA"  # Minimal metadata
      }
    }

    # Public subnet for load balancers
    public = {
      subnet_name           = "staging-usc1-public"
      subnet_ip             = "10.10.2.0/24"
      subnet_region         = "us-central1"
      description           = "Public subnet for load balancers"

      private_ip_google_access = false
      enable_flow_logs = false  # Disabled for cost optimization
    }

    # Database subnet
    database = {
      subnet_name           = "staging-usc1-database"
      subnet_ip             = "10.10.3.0/24"
      subnet_region         = "us-central1"
      description           = "Database subnet for staging"

      private_ip_google_access = true
      enable_flow_logs = false  # Disabled for cost optimization
    }
  }

  # Basic routing for staging
  routes = [
    {
      name                   = "staging-usc1-internet-gateway"
      description            = "Route to internet via default gateway"
      destination_range      = "0.0.0.0/0"
      tags                   = ["public", "internet"]
      next_hop_gateway       = "default-internet-gateway"
      priority              = 1000
    }
  ]

  # Simplified firewall rules for staging
  firewall_rules = [
    # Allow internal communication
    {
      name      = "staging-usc1-allow-internal"
      direction = "INGRESS"
      allow = [
        {
          protocol = "tcp"
          ports    = ["0-65535"]
        },
        {
          protocol = "udp"
          ports    = ["0-65535"]
        },
        {
          protocol = "icmp"
        }
      ]
      source_ranges = [local.vpc_cidr]
      target_tags = ["internal"]
    },

    # Allow SSH from anywhere (for debugging)
    {
      name      = "staging-usc1-allow-ssh"
      direction = "INGRESS"
      allow = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
      source_ranges = ["0.0.0.0/0"]
      target_tags   = ["ssh-allowed"]
    },

    # Allow HTTPS traffic
    {
      name      = "staging-usc1-allow-https"
      direction = "INGRESS"
      allow = [
        {
          protocol = "tcp"
          ports    = ["443"]
        }
      ]
      source_ranges = ["0.0.0.0/0"]
      target_tags   = ["https-server"]
    },

    # Allow HTTP traffic
    {
      name      = "staging-usc1-allow-http"
      direction = "INGRESS"
      allow = [
        {
          protocol = "tcp"
          ports    = ["80"]
        }
      ]
      source_ranges = ["0.0.0.0/0"]
      target_tags   = ["http-server"]
    },

    # Allow load balancer health checks
    {
      name      = "staging-usc1-allow-health-checks"
      direction = "INGRESS"
      allow = [
        {
          protocol = "tcp"
          ports    = ["80", "443", "8080"]
        }
      ]
      source_ranges = [
        "130.211.0.0/22",
        "35.191.0.0/16"
      ]
      target_tags = ["lb-health-check"]
    },

    # Database access from application subnets
    {
      name      = "staging-usc1-allow-database"
      direction = "INGRESS"
      allow = [
        {
          protocol = "tcp"
          ports    = ["3306", "5432"]
        }
      ]
      source_ranges = [local.vpc_cidr]
      target_tags = ["database"]
    }
  ]

  # Basic NAT Gateway for outbound traffic
  nat_gateways = {
    primary_nat = {
      name                               = "staging-usc1-nat"
      router_name                        = "staging-usc1-router"
      region                            = "us-central1"
      nat_ip_allocate_option            = "AUTO_ONLY"  # Auto-allocate for cost savings
      source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

      min_ports_per_vm = 64
      enable_endpoint_independent_mapping = false  # Disable for cost savings

      log_config = {
        enable = false  # Disabled for cost optimization
        filter = "ERRORS_ONLY"
      }
    }
  }

  # Basic Cloud Router
  cloud_routers = {
    primary_router = {
      name        = "staging-usc1-router"
      description = "Cloud router for staging NAT"
      region      = "us-central1"

      bgp = {
        asn               = 64514
        advertise_mode    = "DEFAULT"
        keepalive_interval = 20
      }
    }
  }

  # Basic DNS configuration
  dns_config = {
    enable_dns = true

    private_zones = {
      internal = {
        name        = "staging-usc1-internal"
        dns_name    = "internal.staging.usc1."
        description = "Internal DNS zone for staging"
      }
    }
  }

  # Basic network security
  network_security = {
    enable_ddos_protection = false  # Disabled for cost optimization
    enable_cloud_armor = local.security_config.enable_cloud_armor
    enable_vpc_flow_logs = local.security_config.enable_flow_logs
    enable_private_google_access = local.security_config.enable_private_google_access
  }

  # Tags for resource organization
  tags = {
    Environment = "staging"
    Region = "us-central1"
    RegionShort = "usc1"
    Team = "platform"
    Component = "networking"
    CostCenter = "staging"
    Purpose = "testing"
    AutoShutdown = "enabled"
    CostOptimized = "true"
  }
}