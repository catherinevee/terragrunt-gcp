# Compute configuration for staging us-central1 region
# Manages compute instances, instance groups, and related resources

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("env.hcl")
}

terraform {
  source = "../../../../../modules/compute/instance-group"
}

dependency "network" {
  config_path = "../networking"

  mock_outputs = {
    vpc_id              = "mock-vpc-id"
    vpc_self_link       = "mock-vpc-self-link"
    private_subnet_ids  = ["mock-subnet-1", "mock-subnet-2", "mock-subnet-3"]
    private_subnet_names = ["staging-private-1", "staging-private-2", "staging-private-3"]
  }
}

locals {
  environment = "staging"
  region      = "us-central1"
  zones       = ["us-central1-a", "us-central1-b", "us-central1-c"]

  # Staging compute configuration - optimized for cost
  instance_config = {
    machine_type     = "e2-medium"  # Cost-effective instance type
    preemptible      = true         # Use preemptible instances
    automatic_restart = false
    on_host_maintenance = "TERMINATE"

    disk = {
      source_image = "debian-cloud/debian-11"
      size_gb      = 20  # Smaller disk for staging
      type         = "pd-standard"  # Standard disk instead of SSD
      auto_delete  = true
    }

    metadata = {
      enable-oslogin = "TRUE"
      startup-script = <<-EOT
        #!/bin/bash
        # Install monitoring agent
        curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
        sudo bash add-google-cloud-ops-agent-repo.sh --also-install

        # Install required packages
        apt-get update
        apt-get install -y nginx docker.io

        # Configure nginx
        systemctl enable nginx
        systemctl start nginx

        # Configure docker
        systemctl enable docker
        systemctl start docker

        # Add monitoring
        echo "Staging instance initialized" | logger
      EOT
    }
  }
}

inputs = {
  project_id  = "acme-staging-platform"
  region      = local.region
  environment = local.environment

  # Instance Template Configuration
  instance_template_name = "${local.environment}-${local.region}-template"
  machine_type          = local.instance_config.machine_type

  # Use preemptible instances for cost savings
  preemptible           = local.instance_config.preemptible
  automatic_restart     = local.instance_config.automatic_restart
  on_host_maintenance   = local.instance_config.on_host_maintenance

  # Network configuration
  network            = dependency.network.outputs.vpc_self_link
  subnetwork         = dependency.network.outputs.private_subnet_names[0]
  can_ip_forward     = false

  # Disk configuration
  source_image = local.instance_config.disk.source_image
  disk_size_gb = local.instance_config.disk.size_gb
  disk_type    = local.instance_config.disk.type
  disk_auto_delete = local.instance_config.disk.auto_delete

  # Additional disks for data
  additional_disks = [
    {
      device_name  = "data-disk"
      size_gb      = 50
      type         = "pd-standard"
      auto_delete  = true
      boot         = false
      disk_encryption_key = null
    }
  ]

  # Service account
  service_account = {
    email  = "compute-staging-sa@acme-staging-platform.iam.gserviceaccount.com"
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/trace.append"
    ]
  }

  # Metadata
  metadata = local.instance_config.metadata

  # Tags
  tags = [
    "staging",
    "allow-health-checks",
    "allow-internal",
    "allow-iap",
    "http-server",
    "https-server"
  ]

  # Labels
  labels = {
    environment = local.environment
    region      = local.region
    managed_by  = "terraform"
    component   = "compute"
    workload    = "web-server"
  }

  # Instance Group Configuration
  instance_group_name = "${local.environment}-${local.region}-ig"
  base_instance_name  = "${local.environment}-instance"

  distribution_policy_zones = local.zones
  target_size              = 2  # Minimal size for staging

  # Auto-healing configuration
  health_check = {
    type                = "http"
    initial_delay_sec   = 300
    check_interval_sec  = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout_sec         = 10
    port                = 80
    request_path        = "/health"
  }

  # Update policy for rolling updates
  update_policy = {
    type                           = "PROACTIVE"
    minimal_action                 = "REPLACE"
    most_disruptive_allowed_action = "REPLACE"
    max_surge_fixed                = 1
    max_unavailable_fixed          = 0
    replacement_method             = "SUBSTITUTE"
  }

  # Auto-scaling configuration
  autoscaling_enabled = true
  autoscaling_config = {
    min_replicas    = 1
    max_replicas    = 5  # Lower max for staging
    cooldown_period = 60

    cpu_utilization = {
      target            = 0.8  # Higher threshold for staging
      predictive_method = "NONE"  # Disable predictive scaling in staging
    }

    scaling_schedules = [
      {
        name                  = "business-hours"
        description          = "Scale up during business hours"
        min_required_replicas = 2
        schedule             = "0 9 * * MON-FRI"
        time_zone           = "America/Chicago"
        duration_sec        = 32400  # 9 hours
        disabled            = false
      }
    ]
  }

  # Load balancer backend configuration
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

  # Stateful disk configuration (if needed)
  stateful_disks = []

  # Stateful IPs (if needed)
  stateful_internal_ips = []
  stateful_external_ips = []

  # Version management
  versions = [
    {
      name              = "v1"
      instance_template = "${local.environment}-${local.region}-template"
      target_size = {
        fixed = 2
      }
    }
  ]

  # All instances configuration
  all_instances_config = {
    metadata = {
      environment = local.environment
      version     = "v1"
    }
    labels = {
      deployment = "canary"
    }
  }
}