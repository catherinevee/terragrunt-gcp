# VPC Network Configuration for Production - US Central 1
# This is the primary VPC network for the production environment

terraform {
  source = "${get_repo_root()}/modules/networking/vpc"
}

# Include root configuration
include "root" {
  path = find_in_parent_folders()
}

# Include environment configuration
include "env" {
  path = find_in_parent_folders("env.hcl")
  expose = true
}

# Include region configuration
include "region" {
  path = find_in_parent_folders("region.hcl")
  expose = true
}

# VPC depends on nothing - it's the foundation
dependencies {
  paths = []
}

# Prevent accidental destruction of production VPC
prevent_destroy = true

locals {
  # Extract configuration from includes
  env_config    = include.env.locals
  region_config = include.region.locals

  # Network configuration from region.hcl
  network_config = region_config.network_config
  subnets        = region_config.network_config.subnets

  # Build subnet configurations
  subnet_configs = {
    for subnet_name, subnet in local.subnets : subnet_name => {
      subnet_name                      = "${local.env_config.environment}-${local.region_config.region_short}-${subnet_name}"
      subnet_ip                        = subnet.cidr
      subnet_region                    = local.region_config.region
      subnet_private_access           = try(subnet.private_ip_google_access, true)
      subnet_private_ipv6_access      = try(subnet.private_ipv6_google_access, false)
      subnet_flow_logs                = try(subnet.flow_logs, true)
      subnet_flow_logs_interval       = try(subnet.flow_logs_interval, "INTERVAL_5_MIN")
      subnet_flow_logs_sampling       = try(subnet.flow_logs_sampling, 0.5)
      subnet_flow_logs_metadata       = try(subnet.flow_logs_metadata, "INCLUDE_ALL")
      subnet_flow_logs_filter         = try(subnet.flow_logs_filter, "all")
      description                      = "Subnet for ${subnet.purpose} in ${local.region_config.region}"
      purpose                          = try(subnet.purpose, "PRIVATE")
      role                            = try(subnet.role, null)
      secondary_ip_range              = try(subnet.secondary_ranges, [])
      log_aggregation_interval        = try(subnet.log_aggregation_interval, "INTERVAL_5_MIN")
      stack_type                      = try(subnet.stack_type, "IPV4_ONLY")
    }
  }

  # Firewall rules
  firewall_rules = {
    # Allow internal communication
    allow-internal = {
      description = "Allow internal communication between all subnets"
      direction   = "INGRESS"
      priority    = 1000
      ranges      = [local.network_config.vpc_cidr_primary, local.network_config.vpc_cidr_secondary]
      allow = [{
        protocol = "all"
        ports    = []
      }]
      deny = []
      source_tags = []
      target_tags = []
      log_config = {
        metadata = "INCLUDE_ALL"
      }
    }

    # Allow health checks
    allow-health-checks = {
      description = "Allow Google Cloud health checks"
      direction   = "INGRESS"
      priority    = 1001
      ranges      = ["35.191.0.0/16", "130.211.0.0/22", "209.85.152.0/22", "209.85.204.0/22"]
      allow = [{
        protocol = "tcp"
        ports    = []
      }]
      deny = []
      source_tags = []
      target_tags = ["allow-health-checks"]
      log_config = {
        metadata = "INCLUDE_ALL"
      }
    }

    # Allow IAP for SSH
    allow-iap-ssh = {
      description = "Allow SSH from Identity-Aware Proxy"
      direction   = "INGRESS"
      priority    = 1002
      ranges      = ["35.235.240.0/20"]
      allow = [{
        protocol = "tcp"
        ports    = ["22"]
      }]
      deny = []
      source_tags = []
      target_tags = ["allow-iap-ssh"]
      log_config = {
        metadata = "INCLUDE_ALL"
      }
    }

    # Allow HTTPS from load balancers
    allow-https-lb = {
      description = "Allow HTTPS from load balancers"
      direction   = "INGRESS"
      priority    = 1003
      ranges      = ["0.0.0.0/0"]
      allow = [{
        protocol = "tcp"
        ports    = ["443"]
      }]
      deny = []
      source_tags = []
      target_tags = ["https-server"]
      log_config = {
        metadata = "INCLUDE_ALL"
      }
    }

    # Deny all other traffic (implicit deny)
    deny-all-ingress = {
      description = "Deny all other ingress traffic"
      direction   = "INGRESS"
      priority    = 65534
      ranges      = ["0.0.0.0/0"]
      allow = []
      deny = [{
        protocol = "all"
        ports    = []
      }]
      source_tags = []
      target_tags = []
      log_config = {
        metadata = "INCLUDE_ALL"
      }
    }
  }

  # Routes configuration
  routes = {
    # Route to internet via Cloud NAT
    internet-egress = {
      description      = "Route to internet via Cloud NAT"
      destination_range = "0.0.0.0/0"
      next_hop_gateway = "default-internet-gateway"
      priority         = 1000
      tags            = ["internet-egress"]
    }
  }
}

# Module inputs
inputs = {
  # Network name and description
  network_name = "${local.env_config.environment}-${local.region_config.region_short}-vpc"
  description  = "Production VPC network for ${local.region_config.region}"

  # Routing mode
  routing_mode = "REGIONAL"

  # Shared VPC configuration
  shared_vpc_host = local.env_config.environment == "prod"

  # Auto-create subnetworks (disabled for custom subnets)
  auto_create_subnetworks = false

  # Delete default routes
  delete_default_internet_gateway_routes = true

  # MTU configuration
  mtu = 1460

  # Enable internal IPv6
  enable_ula_internal_ipv6 = false
  internal_ipv6_range      = null

  # Subnets configuration
  subnets = [
    for subnet_key, subnet_config in local.subnet_configs : subnet_config
  ]

  # Secondary ranges (for GKE pods and services)
  secondary_ranges = {
    for subnet_name, subnet in local.subnets :
    "${local.env_config.environment}-${local.region_config.region_short}-${subnet_name}" => [
      for range_name, range_cidr in try(subnet.secondary_ranges, {}) : {
        range_name    = range_name
        ip_cidr_range = range_cidr
      }
    ] if length(try(subnet.secondary_ranges, {})) > 0
  }

  # Firewall rules
  firewall_rules = local.firewall_rules

  # Routes
  routes = local.routes

  # VPC Flow Logs configuration
  vpc_flow_logs_config = {
    aggregation_interval = "INTERVAL_5_MIN"
    flow_sampling       = 0.5
    metadata           = "INCLUDE_ALL"
    filter_expr        = null
  }

  # Network peering configuration
  peering_config = local.network_config.enable_vpc_peering ? {
    peer_networks = local.network_config.peer_networks
    export_custom_routes = true
    import_custom_routes = true
    export_subnet_routes_with_public_ip = true
    import_subnet_routes_with_public_ip = false
  } : null

  # Private Service Connect configuration
  private_service_connect_config = local.network_config.enable_private_service_connect ? {
    enable_private_service_connect = true
    psc_service_attachments = {}
    psc_nat_subnets = {
      "${local.env_config.environment}-${local.region_config.region_short}-psc-nat" = {
        subnet_name = "${local.env_config.environment}-${local.region_config.region_short}-psc-nat"
        subnet_ip   = cidrsubnet(local.network_config.vpc_cidr_primary, 8, 250)
        subnet_region = local.region_config.region
        purpose = "PRIVATE_SERVICE_CONNECT"
      }
    }
  } : null

  # Cloud Armor configuration
  cloud_armor_enabled = local.network_config.enable_cloud_armor

  # Cloud CDN configuration
  cloud_cdn_enabled = local.network_config.enable_cloud_cdn

  # DNS configuration
  dns_config = try(local.network_config.dns_config, null)

  # NAT configuration (created separately)
  create_nat = false

  # VPN configuration (created separately)
  create_vpn = false

  # Interconnect configuration (created separately)
  create_interconnect = false

  # Labels
  labels = merge(
    var.common_labels,
    {
      component = "networking"
      service   = "vpc"
      tier      = "network"
    }
  )

  # Enable APIs
  enable_apis = true
  activate_apis = [
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
    "networkmanagement.googleapis.com",
    "networksecurity.googleapis.com"
  ]

  # Project ID (inherited from root)
  project_id = var.project_id

  # Additional production-specific settings
  enable_flow_logs = true
  enable_private_google_access = true
  enable_cloud_nat = false  # Created separately for better control

  # Network security
  enable_firewall_logging = true
  enable_firewall_insights = true

  # Service networking
  service_networking_config = {
    enable_service_networking = true
    allocated_ip_ranges = [
      {
        name         = "${local.env_config.environment}-${local.region_config.region_short}-service-networking"
        description  = "IP range for service networking"
        address      = "10.100.0.0"
        prefix_length = 16
        purpose      = "VPC_PEERING"
        network      = "${local.env_config.environment}-${local.region_config.region_short}-vpc"
      }
    ]
    private_vpc_connection = {
      service = "servicenetworking.googleapis.com"
      reserved_peering_ranges = ["${local.env_config.environment}-${local.region_config.region_short}-service-networking"]
      delete_default_routes_on_create = true
    }
  }

  # Network connectivity center
  network_connectivity_center = local.network_config.enable_interconnect ? {
    enable = true
    hub_name = "${local.env_config.environment}-${local.region_config.region_short}-hub"
    hub_description = "Network connectivity hub for ${local.region_config.region}"
    spokes = {}
  } : null
}