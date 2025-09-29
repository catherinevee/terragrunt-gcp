# Web tier configuration for multi-tier architecture
# Handles frontend web servers with load balancing

include "root" {
  path = find_in_parent_folders()
}

# Include the multi-tier configuration
include "multi_tier" {
  path = "../terragrunt.hcl"
}

terraform {
  source = "../../../modules/compute/instance-group"
}

dependencies {
  paths = ["../networking", "../iam", "../load-balancer"]
}

inputs = {
  # Instance group configuration
  name        = "web-tier-ig"
  description = "Web tier instance group for multi-tier application"

  # Instance template configuration
  instance_template = {
    name_prefix  = "web-tier-template-"
    description  = "Instance template for web tier"

    machine_type = local.tiers.web.instance_type
    region       = local.region

    # Boot disk
    disk = [
      {
        source_image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2004-lts"
        auto_delete  = true
        boot         = true
        disk_size_gb = local.tiers.web.disk_size
        disk_type    = "pd-standard"
        disk_encryption_key = null
      }
    ]

    # Network configuration
    network_interface = [
      {
        network    = dependency.networking.outputs.network_self_link
        subnetwork = dependency.networking.outputs.web_subnet_self_link
        access_config = [
          {
            nat_ip       = null
            network_tier = "STANDARD"
          }
        ]
      }
    ]

    # Service account
    service_account = {
      email  = dependency.iam.outputs.web_service_account_email
      scopes = ["cloud-platform"]
    }

    # Metadata and startup script
    metadata = {
      "startup-script" = templatefile("${get_terragrunt_dir()}/web-startup.sh", {
        app_lb_ip = dependency.load-balancer.outputs.app_lb_ip
      })

      # Enable OS Login
      "enable-oslogin" = "TRUE"

      # Custom metadata
      "tier"        = "web"
      "environment" = local.environment
      "app-name"    = local.app_name
      "app-version" = local.app_version
    }

    # Labels
    labels = merge(local.common_labels, {
      tier = "web"
      role = "frontend"
    })

    # Network tags for firewall rules
    tags = ["web-tier", "http-server", "https-server"]

    # Shielded VM configuration
    shielded_instance_config = {
      enable_secure_boot          = true
      enable_vtpm                 = true
      enable_integrity_monitoring = true
    }

    # Scheduling configuration
    scheduling = {
      automatic_restart   = true
      on_host_maintenance = "MIGRATE"
      preemptible        = false
    }
  }

  # Managed instance group configuration
  target_size = local.tiers.web.min_replicas

  # Health check for instance group
  health_check = {
    type                = "HTTP"
    initial_delay_sec   = 30
    check_interval_sec  = 10
    timeout_sec         = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3

    http_health_check = {
      port         = 80
      request_path = "/health"
      host         = null
      proxy_header = "NONE"
    }
  }

  # Auto healing configuration
  auto_healing_policies = {
    health_check      = null  # Will use the health check defined above
    initial_delay_sec = 300
  }

  # Distribution policy (for multi-zone deployment)
  distribution_policy_zones = [
    "us-central1-a",
    "us-central1-b",
    "us-central1-c"
  ]

  # Update policy
  update_policy = {
    type                           = "PROACTIVE"
    instance_redistribution_type   = "PROACTIVE"
    minimal_action                 = "REPLACE"
    max_surge_fixed                = 3
    max_unavailable_fixed          = 1
    min_ready_sec                  = 30
    replacement_method             = "SUBSTITUTE"
  }

  # Named ports for load balancer backend
  named_ports = [
    {
      name = "http"
      port = 80
    },
    {
      name = "https"
      port = 443
    }
  ]

  # Auto scaling configuration
  autoscaler = {
    max_replicas    = local.tiers.web.max_replicas
    min_replicas    = local.tiers.web.min_replicas
    cooldown_period = 60

    # CPU utilization scaling
    cpu_utilization = {
      target = 0.7
    }

    # Load balancing utilization scaling
    load_balancing_utilization = {
      target = 0.8
    }

    # Custom metric scaling (example)
    metric = [
      {
        name   = "custom.googleapis.com/application/requests_per_second"
        target = 100
        type   = "GAUGE"
      }
    ]
  }

  # Instance lifecycle
  instance_lifecycle_policy = {
    default_action_on_failure = "REPAIR"
  }
}