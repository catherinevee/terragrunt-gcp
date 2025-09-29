# Basic networking configuration
# Creates a simple VPC with subnet and firewall rules

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/networking/vpc"
}

inputs = {
  # VPC Network configuration
  network_name                  = "basic-vpc"
  description                   = "Basic VPC network for development"
  auto_create_subnetworks       = false
  routing_mode                  = "REGIONAL"
  delete_default_routes_on_create = false
  mtu                          = 1460

  # Subnet configuration
  subnets = [
    {
      subnet_name           = "basic-subnet"
      subnet_ip             = "10.0.1.0/24"
      subnet_region         = "us-central1"
      description           = "Basic subnet for development workloads"

      # Secondary IP ranges for GKE pods/services (if needed)
      secondary_ranges = []

      # Enable private Google access for instances without external IPs
      private_ip_google_access = true

      # Enable flow logs for network monitoring
      enable_flow_logs = true
      flow_logs_config = {
        aggregation_interval = "INTERVAL_5_SEC"
        flow_sampling        = 0.5
        metadata            = "INCLUDE_ALL_METADATA"
        filter_expr         = "true"
      }
    }
  ]

  # Firewall rules
  firewall_rules = [
    {
      name      = "basic-allow-ssh"
      direction = "INGRESS"
      priority  = 1000

      allow = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]

      source_ranges = ["0.0.0.0/0"]  # Restrict this in production
      target_tags   = ["ssh-server"]

      description = "Allow SSH access from anywhere"
      disabled    = false

      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    },
    {
      name      = "basic-allow-http"
      direction = "INGRESS"
      priority  = 1000

      allow = [
        {
          protocol = "tcp"
          ports    = ["80", "8080"]
        }
      ]

      source_ranges = ["0.0.0.0/0"]
      target_tags   = ["http-server"]

      description = "Allow HTTP traffic"
      disabled    = false

      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    },
    {
      name      = "basic-allow-https"
      direction = "INGRESS"
      priority  = 1000

      allow = [
        {
          protocol = "tcp"
          ports    = ["443"]
        }
      ]

      source_ranges = ["0.0.0.0/0"]
      target_tags   = ["https-server"]

      description = "Allow HTTPS traffic"
      disabled    = false

      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    },
    {
      name      = "basic-allow-internal"
      direction = "INGRESS"
      priority  = 65534

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

      source_ranges = ["10.0.0.0/8"]

      description = "Allow internal traffic within VPC"
      disabled    = false
    }
  ]

  # Routes (if custom routes are needed)
  routes = []

  # Labels for resource organization
  labels = {
    environment = "development"
    project     = "basic-example"
    team        = "devops"
    managed_by  = "terragrunt"
  }
}