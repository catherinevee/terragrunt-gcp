# Networking configuration for staging us-central1 region
# Manages VPC, subnets, firewall rules, and network connectivity

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("env.hcl")
}

terraform {
  source = "../../../../../modules/networking/vpc"
}

locals {
  environment = "staging"
  region      = "us-central1"

  network_config = {
    cidr_ranges = {
      public  = ["10.20.0.0/24", "10.20.1.0/24", "10.20.2.0/24"]
      private = ["10.20.10.0/24", "10.20.11.0/24", "10.20.12.0/24"]
      database = ["10.20.20.0/24"]
      gke      = ["10.20.30.0/22"]  # Larger range for GKE pods
      services = ["10.20.40.0/22"]  # For GKE services
    }
  }
}

inputs = {
  project_id  = "acme-staging-platform"
  region      = local.region
  environment = local.environment

  # VPC configuration
  vpc_name                        = "${local.environment}-${local.region}-vpc"
  auto_create_subnetworks        = false
  routing_mode                   = "REGIONAL"
  delete_default_routes_on_create = true
  mtu                           = 1460

  # Subnet configurations
  subnets = [
    # Public subnets for load balancers
    {
      name                     = "${local.environment}-${local.region}-public-subnet-1"
      ip_cidr_range           = local.network_config.cidr_ranges.public[0]
      region                  = local.region
      private_ip_google_access = true
      flow_logs               = true
      flow_logs_interval      = "INTERVAL_5_MIN"
      flow_logs_sampling      = 0.5
      flow_logs_metadata      = "INCLUDE_ALL_METADATA"

      secondary_ip_ranges = []
    },
    {
      name                     = "${local.environment}-${local.region}-public-subnet-2"
      ip_cidr_range           = local.network_config.cidr_ranges.public[1]
      region                  = local.region
      private_ip_google_access = true
      flow_logs               = true
      flow_logs_interval      = "INTERVAL_5_MIN"
      flow_logs_sampling      = 0.5
      flow_logs_metadata      = "INCLUDE_ALL_METADATA"

      secondary_ip_ranges = []
    },
    {
      name                     = "${local.environment}-${local.region}-public-subnet-3"
      ip_cidr_range           = local.network_config.cidr_ranges.public[2]
      region                  = local.region
      private_ip_google_access = true
      flow_logs               = true
      flow_logs_interval      = "INTERVAL_5_MIN"
      flow_logs_sampling      = 0.5
      flow_logs_metadata      = "INCLUDE_ALL_METADATA"

      secondary_ip_ranges = []
    },

    # Private subnets for compute instances
    {
      name                     = "${local.environment}-${local.region}-private-subnet-1"
      ip_cidr_range           = local.network_config.cidr_ranges.private[0]
      region                  = local.region
      private_ip_google_access = true
      flow_logs               = true
      flow_logs_interval      = "INTERVAL_10_MIN"
      flow_logs_sampling      = 0.25
      flow_logs_metadata      = "INCLUDE_ALL_METADATA"

      secondary_ip_ranges = []
    },
    {
      name                     = "${local.environment}-${local.region}-private-subnet-2"
      ip_cidr_range           = local.network_config.cidr_ranges.private[1]
      region                  = local.region
      private_ip_google_access = true
      flow_logs               = true
      flow_logs_interval      = "INTERVAL_10_MIN"
      flow_logs_sampling      = 0.25
      flow_logs_metadata      = "INCLUDE_ALL_METADATA"

      secondary_ip_ranges = []
    },
    {
      name                     = "${local.environment}-${local.region}-private-subnet-3"
      ip_cidr_range           = local.network_config.cidr_ranges.private[2]
      region                  = local.region
      private_ip_google_access = true
      flow_logs               = true
      flow_logs_interval      = "INTERVAL_10_MIN"
      flow_logs_sampling      = 0.25
      flow_logs_metadata      = "INCLUDE_ALL_METADATA"

      secondary_ip_ranges = []
    },

    # Database subnet with private service access
    {
      name                     = "${local.environment}-${local.region}-database-subnet"
      ip_cidr_range           = local.network_config.cidr_ranges.database[0]
      region                  = local.region
      private_ip_google_access = true
      flow_logs               = false  # Disable for database subnet to reduce costs

      secondary_ip_ranges = []
    },

    # GKE subnet with secondary ranges
    {
      name                     = "${local.environment}-${local.region}-gke-subnet"
      ip_cidr_range           = local.network_config.cidr_ranges.gke[0]
      region                  = local.region
      private_ip_google_access = true
      flow_logs               = true
      flow_logs_interval      = "INTERVAL_10_MIN"
      flow_logs_sampling      = 0.1
      flow_logs_metadata      = "EXCLUDE_ALL_METADATA"

      secondary_ip_ranges = [
        {
          range_name    = "${local.environment}-${local.region}-gke-pods"
          ip_cidr_range = "10.21.0.0/16"  # Pod IP range
        },
        {
          range_name    = "${local.environment}-${local.region}-gke-services"
          ip_cidr_range = "10.22.0.0/20"  # Service IP range
        }
      ]
    }
  ]

  # Firewall rules
  firewall_rules = [
    # Allow internal communication
    {
      name          = "${local.environment}-allow-internal"
      description   = "Allow internal communication between all resources"
      direction     = "INGRESS"
      priority      = 1000
      source_ranges = ["10.20.0.0/16"]

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

    # Allow health checks
    {
      name          = "${local.environment}-allow-health-checks"
      description   = "Allow Google Cloud health checks"
      direction     = "INGRESS"
      priority      = 900
      source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]

      allow = [
        {
          protocol = "tcp"
          ports    = ["80", "443", "8080", "8443"]
        }
      ]

      deny = []
      target_tags = ["allow-health-checks"]
    },

    # Allow SSH from IAP
    {
      name          = "${local.environment}-allow-iap-ssh"
      description   = "Allow SSH through Identity-Aware Proxy"
      direction     = "INGRESS"
      priority      = 800
      source_ranges = ["35.235.240.0/20"]

      allow = [
        {
          protocol = "tcp"
          ports    = ["22", "3389"]
        }
      ]

      deny = []
      target_tags = ["allow-iap"]
    },

    # Allow HTTP/HTTPS from load balancers
    {
      name          = "${local.environment}-allow-lb-traffic"
      description   = "Allow HTTP/HTTPS traffic from load balancers"
      direction     = "INGRESS"
      priority      = 700
      source_ranges = ["0.0.0.0/0"]

      allow = [
        {
          protocol = "tcp"
          ports    = ["80", "443"]
        }
      ]

      deny = []
      target_tags = ["http-server", "https-server"]
    },

    # Deny all other inbound traffic (implicit deny rule)
    {
      name          = "${local.environment}-deny-all-ingress"
      description   = "Deny all other ingress traffic"
      direction     = "INGRESS"
      priority      = 65534
      source_ranges = ["0.0.0.0/0"]

      allow = []

      deny = [
        {
          protocol = "all"
          ports    = []
        }
      ]

      target_tags = []
    }
  ]

  # Cloud NAT configuration for private instances
  create_cloud_nat = true
  nat_name         = "${local.environment}-${local.region}-nat"
  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  nat_subnetworks = [
    {
      name                    = "${local.environment}-${local.region}-private-subnet-1"
      source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
    },
    {
      name                    = "${local.environment}-${local.region}-private-subnet-2"
      source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
    },
    {
      name                    = "${local.environment}-${local.region}-private-subnet-3"
      source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
    },
    {
      name                    = "${local.environment}-${local.region}-gke-subnet"
      source_ip_ranges_to_nat = ["PRIMARY_IP_RANGE"]
    }
  ]

  nat_log_config = {
    enable = true
    filter = "ERRORS_ONLY"
  }

  # Private Service Connect configuration
  create_private_service_connect = true
  private_service_connect_configs = [
    {
      name              = "${local.environment}-${local.region}-psc-google-apis"
      ip_address        = "10.20.254.1"
      network           = "${local.environment}-${local.region}-vpc"
      target            = "all-apis"
      forwarding_rule_target = "all-apis"
    }
  ]

  # VPC Peering configurations
  vpc_peerings = []  # No peerings in staging initially

  # Shared VPC configuration (if needed)
  shared_vpc_host = false
  shared_vpc_service_projects = []

  # DNS configuration
  create_dns_zones = true
  dns_zones = [
    {
      name        = "${local.environment}-internal"
      dns_name    = "staging.internal."
      description = "Internal DNS zone for staging environment"
      visibility  = "private"

      private_visibility_config_networks = ["${local.environment}-${local.region}-vpc"]
    }
  ]

  # Labels
  labels = {
    environment = local.environment
    region      = local.region
    managed_by  = "terraform"
    component   = "networking"
  }

  # Network tags
  network_tags = [
    "staging",
    "us-central1"
  ]
}