# Test Terragrunt Configuration
terraform {
  source = "tfr:///terraform-google-modules/network/google?version=9.0.0"
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite"
  contents = <<EOF
terraform {
  backend "gcs" {
    bucket = "acme-ecommerce-platform-dev-tfstate"
    prefix = "test/network"
  }
}
EOF
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents = <<EOF
provider "google" {
  project = "acme-ecommerce-platform-dev"
  region  = "us-central1"
}

provider "google-beta" {
  project = "acme-ecommerce-platform-dev"
  region  = "us-central1"
}
EOF
}

inputs = {
  project_id   = "acme-ecommerce-platform-dev"
  network_name = "test-network"
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name           = "test-subnet"
      subnet_ip             = "10.200.0.0/24"
      subnet_region         = "us-central1"
      subnet_private_access = "true"
    }
  ]

  firewall_rules = []
}