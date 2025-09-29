# Basic example Terragrunt configuration
# This demonstrates a simple setup for development environments

# Include the root terragrunt.hcl configuration
include "root" {
  path = find_in_parent_folders()
}

# Configure Terraform settings
terraform {
  source = "../../modules/compute/instance"
}

# Dependencies - ensure networking is deployed first
dependencies {
  paths = ["../networking"]
}

# Input variables for the Terraform module
inputs = {
  # Instance configuration
  instance_name = "web-server-dev"
  machine_type  = "e2-micro"
  zone         = "us-central1-a"

  # Boot disk configuration
  boot_disk = {
    size_gb     = 20
    type        = "pd-standard"
    image       = "projects/debian-cloud/global/images/family/debian-11"
    auto_delete = true
  }

  # Network configuration
  network_interfaces = [
    {
      network    = dependency.networking.outputs.network_self_link
      subnetwork = dependency.networking.outputs.subnet_self_link
      access_config = [
        {
          nat_ip       = null
          network_tier = "STANDARD"
        }
      ]
    }
  ]

  # Metadata
  metadata = {
    "startup-script" = <<-EOF
      #!/bin/bash
      apt-get update
      apt-get install -y nginx
      systemctl start nginx
      systemctl enable nginx
    EOF
  }

  # Labels for resource organization
  labels = {
    environment = "development"
    project     = "basic-example"
    team        = "devops"
    managed_by  = "terragrunt"
  }

  # Service account configuration
  service_account = {
    email  = dependency.iam.outputs.compute_service_account_email
    scopes = ["cloud-platform"]
  }

  # Firewall tags
  tags = ["web-server", "http-server"]

  # Enable OS Login for better security
  enable_oslogin = true

  # Deletion protection
  deletion_protection = false
}