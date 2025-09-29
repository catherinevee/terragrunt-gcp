# Production VPC Configuration - US East 1 (Disaster Recovery)
# This configuration creates the disaster recovery VPC infrastructure

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
  project_id = "your-prod-project-id"
  region     = local.region

  # VPC Configuration for DR region
  vpc_name        = "prod-${local.region_short}-vpc"
  vpc_description = "Production VPC for US East 1 disaster recovery region"

  # Auto create subnetworks disabled for custom configuration
  auto_create_subnetworks = false

  # Enable flow logs for security monitoring
  enable_flow_logs = true

  # Delete default routes for security
  delete_default_routes_on_create = false

  # MTU configuration for performance
  mtu = 1500

  # Network routing mode
  routing_mode = "REGIONAL"

  # Subnet configurations from region.hcl
  subnets = {
    # Public Load Balancer subnet
    public_lb = {
      subnet_name           = "prod-${local.region_short}-public-lb"
      subnet_ip             = local.network_config.subnets.public_lb.cidr
      subnet_region         = local.region
      description           = "Public subnet for load balancers and ingress"

      # Enable private Google access
      private_ip_google_access = true

      # Enable flow logs
      enable_flow_logs = true
      flow_logs_config = {
        aggregation_interval = "INTERVAL_5_SEC"
        flow_sampling       = 1.0
        metadata           = "INCLUDE_ALL_METADATA"
        filter_expr        = "true"
      }

      # Log configuration
      log_config = {
        aggregation_interval = "INTERVAL_5_SEC"
        flow_sampling       = 1.0
        metadata           = "INCLUDE_ALL_METADATA"
        metadata_fields    = ["src_ip", "dest_ip", "src_port", "dest_port", "protocol"]
      }
    }

    # Public NAT subnet
    public_nat = {
      subnet_name           = "prod-${local.region_short}-public-nat"
      subnet_ip             = local.network_config.subnets.public_nat.cidr
      subnet_region         = local.region
      description           = "Public subnet for NAT gateways"

      private_ip_google_access = true
      enable_flow_logs = true
      flow_logs_config = {
        aggregation_interval = "INTERVAL_5_SEC"
        flow_sampling       = 1.0
        metadata           = "INCLUDE_ALL_METADATA"
      }
    }

    # Private Web Tier subnet
    private_web = {
      subnet_name           = "prod-${local.region_short}-private-web"
      subnet_ip             = local.network_config.subnets.private_web.cidr
      subnet_region         = local.region
      description           = "Private subnet for web tier applications"

      # Secondary ranges for GKE
      secondary_ip_range = [
        {
          range_name    = "pods"
          ip_cidr_range = local.network_config.subnets.private_web.secondary_ranges.pods
        },
        {
          range_name    = "services"
          ip_cidr_range = local.network_config.subnets.private_web.secondary_ranges.services
        }
      ]

      private_ip_google_access = true
      enable_flow_logs = true
      flow_logs_config = {
        aggregation_interval = "INTERVAL_10_SEC"
        flow_sampling       = 0.5
        metadata           = "INCLUDE_ALL_METADATA"
      }
    }

    # Private Application Tier subnet
    private_app = {
      subnet_name           = "prod-${local.region_short}-private-app"
      subnet_ip             = local.network_config.subnets.private_app.cidr
      subnet_region         = local.region
      description           = "Private subnet for application tier"

      # Secondary ranges for GKE
      secondary_ip_range = [
        {
          range_name    = "pods"
          ip_cidr_range = local.network_config.subnets.private_app.secondary_ranges.pods
        },
        {
          range_name    = "services"
          ip_cidr_range = local.network_config.subnets.private_app.secondary_ranges.services
        }
      ]

      private_ip_google_access = true
      enable_flow_logs = true
      flow_logs_config = {
        aggregation_interval = "INTERVAL_10_SEC"
        flow_sampling       = 0.5
        metadata           = "INCLUDE_ALL_METADATA"
      }
    }

    # Private Data Tier subnet
    private_data = {
      subnet_name           = "prod-${local.region_short}-private-data"
      subnet_ip             = local.network_config.subnets.private_data.cidr
      subnet_region         = local.region
      description           = "Private subnet for database and data services"

      private_ip_google_access = true
      enable_flow_logs = true
      flow_logs_config = {
        aggregation_interval = "INTERVAL_5_SEC"
        flow_sampling       = 1.0
        metadata           = "INCLUDE_ALL_METADATA"
      }
    }

    # Management subnet
    management = {
      subnet_name           = "prod-${local.region_short}-management"
      subnet_ip             = local.network_config.subnets.management.cidr
      subnet_region         = local.region
      description           = "Management subnet for administrative access"

      private_ip_google_access = true
      enable_flow_logs = true
      flow_logs_config = {
        aggregation_interval = "INTERVAL_5_SEC"
        flow_sampling       = 1.0
        metadata           = "INCLUDE_ALL_METADATA"
      }
    }

    # DMZ subnet
    dmz = {
      subnet_name           = "prod-${local.region_short}-dmz"
      subnet_ip             = local.network_config.subnets.dmz.cidr
      subnet_region         = local.region
      description           = "DMZ subnet for external-facing services"

      private_ip_google_access = false
      enable_flow_logs = true
      flow_logs_config = {
        aggregation_interval = "INTERVAL_5_SEC"
        flow_sampling       = 1.0
        metadata           = "INCLUDE_ALL_METADATA"
      }
    }

    # Security subnet
    security = {
      subnet_name           = "prod-${local.region_short}-security"
      subnet_ip             = local.network_config.subnets.security.cidr
      subnet_region         = local.region
      description           = "Security subnet for security appliances"

      private_ip_google_access = true
      enable_flow_logs = true
      flow_logs_config = {
        aggregation_interval = "INTERVAL_5_SEC"
        flow_sampling       = 1.0
        metadata           = "INCLUDE_ALL_METADATA"
      }
    }
  }

  # Routes configuration
  routes = [
    {
      name                   = "prod-${local.region_short}-internet-gateway"
      description            = "Route to internet via default gateway"
      destination_range      = "0.0.0.0/0"
      tags                   = ["public", "internet"]
      next_hop_gateway       = "default-internet-gateway"
      priority              = 1000
    },
    {
      name                   = "prod-${local.region_short}-private-access"
      description            = "Route for private Google access"
      destination_range      = "199.36.153.8/30"
      tags                   = ["private", "google-access"]
      next_hop_gateway       = "default-internet-gateway"
      priority              = 1000
    }
  ]

  # Firewall rules for disaster recovery
  firewall_rules = [
    # Allow internal communication
    {
      name      = "prod-${local.region_short}-allow-internal"
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
      source_ranges = [
        local.network_config.vpc_cidr_primary,
        local.network_config.vpc_cidr_secondary,
        "10.0.0.0/16"  # Primary region CIDR
      ]
      target_tags = ["internal"]
    },

    # Allow SSH access from management subnet
    {
      name      = "prod-${local.region_short}-allow-ssh-management"
      direction = "INGRESS"
      allow = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
      source_ranges = [local.network_config.subnets.management.cidr]
      target_tags   = ["ssh-allowed"]
    },

    # Allow HTTPS traffic
    {
      name      = "prod-${local.region_short}-allow-https"
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

    # Allow HTTP traffic (for health checks)
    {
      name      = "prod-${local.region_short}-allow-http"
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
      name      = "prod-${local.region_short}-allow-health-checks"
      direction = "INGRESS"
      allow = [
        {
          protocol = "tcp"
          ports    = ["80", "443", "8080", "8443"]
        }
      ]
      source_ranges = [
        "130.211.0.0/22",
        "35.191.0.0/16",
        "209.85.152.0/22",
        "209.85.204.0/22"
      ]
      target_tags = ["lb-health-check"]
    },

    # Allow GKE master access
    {
      name      = "prod-${local.region_short}-allow-gke-master"
      direction = "INGRESS"
      allow = [
        {
          protocol = "tcp"
          ports    = ["443", "10250"]
        }
      ]
      source_ranges = ["172.17.0.0/16"]  # GKE master CIDR ranges
      target_tags   = ["gke-node"]
    },

    # Database access from application tiers
    {
      name      = "prod-${local.region_short}-allow-database"
      direction = "INGRESS"
      allow = [
        {
          protocol = "tcp"
          ports    = ["3306", "5432", "6379", "27017"]
        }
      ]
      source_ranges = [
        local.network_config.subnets.private_web.cidr,
        local.network_config.subnets.private_app.cidr
      ]
      target_tags = ["database"]
    },

    # Deny all other traffic
    {
      name      = "prod-${local.region_short}-deny-all"
      direction = "INGRESS"
      deny = [
        {
          protocol = "all"
        }
      ]
      source_ranges = ["0.0.0.0/0"]
      priority     = 65534
    }
  ]

  # VPC Peering configurations for cross-region connectivity
  vpc_peering = {
    peer_primary_region = {
      peer_network_name = "prod-usc1-vpc"
      peer_project_id   = "your-prod-project-id"
      export_custom_routes = true
      import_custom_routes = true
      export_subnet_routes_with_public_ip = false
      import_subnet_routes_with_public_ip = false
    }
  }

  # Private Service Connect
  private_service_connect = {
    enable_private_service_connect = true

    endpoints = {
      google_apis = {
        name         = "prod-${local.region_short}-google-apis"
        target       = "all-apis"
        subnet       = "prod-${local.region_short}-private-data"
        address      = "10.1.24.100"
      }
    }
  }

  # NAT Gateway configuration
  nat_gateways = {
    primary_nat = {
      name                               = "prod-${local.region_short}-nat-primary"
      router_name                        = "prod-${local.region_short}-router-primary"
      region                            = local.region
      nat_ip_allocate_option            = "MANUAL_ONLY"
      source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

      subnetworks = [
        {
          name                    = "prod-${local.region_short}-private-web"
          source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
        },
        {
          name                    = "prod-${local.region_short}-private-app"
          source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
        },
        {
          name                    = "prod-${local.region_short}-private-data"
          source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
        }
      ]

      enable_endpoint_independent_mapping = true
      enable_dynamic_port_allocation     = true
      min_ports_per_vm                   = 64
      max_ports_per_vm                   = 65536

      log_config = {
        enable = true
        filter = "ALL"
      }
    }

    secondary_nat = {
      name                               = "prod-${local.region_short}-nat-secondary"
      router_name                        = "prod-${local.region_short}-router-secondary"
      region                            = local.region
      nat_ip_allocate_option            = "AUTO_ONLY"
      source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

      subnetworks = [
        {
          name                    = "prod-${local.region_short}-management"
          source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
        },
        {
          name                    = "prod-${local.region_short}-security"
          source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
        }
      ]

      enable_endpoint_independent_mapping = true
      min_ports_per_vm                   = 64

      log_config = {
        enable = true
        filter = "ERRORS_ONLY"
      }
    }
  }

  # Cloud Router configuration for BGP and VPN
  cloud_routers = {
    primary_router = {
      name        = "prod-${local.region_short}-router-primary"
      description = "Primary cloud router for BGP and NAT"
      region      = local.region

      bgp = {
        asn               = 64512
        advertise_mode    = "CUSTOM"
        keepalive_interval = 20

        advertised_groups = ["ALL_SUBNETS"]

        advertised_ip_ranges = [
          {
            range       = local.network_config.vpc_cidr_primary
            description = "Primary VPC CIDR"
          },
          {
            range       = local.network_config.vpc_cidr_secondary
            description = "Secondary VPC CIDR"
          }
        ]
      }
    }

    secondary_router = {
      name        = "prod-${local.region_short}-router-secondary"
      description = "Secondary cloud router for redundancy"
      region      = local.region

      bgp = {
        asn               = 64513
        advertise_mode    = "DEFAULT"
        keepalive_interval = 20
      }
    }
  }

  # Network Security configurations
  network_security = {
    # DDoS protection
    enable_ddos_protection = true

    # Cloud Armor
    enable_cloud_armor = true

    # VPC Flow Logs
    enable_vpc_flow_logs = true
    flow_logs_config = {
      aggregation_interval = "INTERVAL_5_SEC"
      flow_sampling       = 0.5
      metadata           = "INCLUDE_ALL_METADATA"
    }

    # Private Google Access
    enable_private_google_access = true

    # VPC Service Controls
    enable_vpc_service_controls = true
    service_perimeter = "prod-use1-perimeter"
  }

  # DNS configuration
  dns_config = {
    enable_dns = true

    # Private DNS zones
    private_zones = {
      internal = {
        name        = "prod-${local.region_short}-internal"
        dns_name    = "internal.prod.use1."
        description = "Internal DNS zone for production US East 1"
      }

      gcp_internal = {
        name        = "prod-${local.region_short}-gcp-internal"
        dns_name    = "gcp.internal.prod.use1."
        description = "GCP internal services DNS zone"
      }
    }

    # DNS forwarding
    forwarding_config = {
      target_name_servers = [
        {
          ipv4_address = "8.8.8.8"
        },
        {
          ipv4_address = "8.8.4.4"
        }
      ]
    }
  }

  # Cross-region connectivity
  cross_region_connectivity = {
    enable_interconnect = true

    # VPN tunnels to primary region
    vpn_tunnels = {
      to_primary = {
        peer_ip = "35.199.192.1"  # Primary region VPN gateway IP
        shared_secret = "your-vpn-shared-secret"
        target_vpn_gateway = "prod-usc1-vpn-gateway"
        ike_version = 2

        bgp_session = {
          peer_asn = 64511
          peer_ip  = "169.254.1.1"
          local_ip = "169.254.1.2"
        }
      }
    }
  }

  # Tags for resource organization
  tags = {
    Environment = "production"
    Region = local.region
    RegionShort = local.region_short
    RegionType = "disaster-recovery"
    Team = "platform"
    Component = "networking"
    CostCenter = "engineering"
    Compliance = "required"
    DataClassification = "internal"
    BackupRequired = "true"
    MonitoringRequired = "true"
    DRRole = "secondary"
    DRPriority = "1"
  }
}