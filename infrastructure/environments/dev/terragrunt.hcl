# Root configuration for dev environment
remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "acme-ecommerce-dev-tfstate-456370864766"
    prefix         = "${path_relative_to_include()}"
    project        = "acme-ecommerce-platform-dev"
    location       = "us"
    enable_bucket_policy_only = true
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents = <<PROVIDER
provider "google" {
  project = local.project_id
  region  = local.region
}

provider "google-beta" {
  project = local.project_id
  region  = local.region
}
PROVIDER
}

locals {
  project_id  = "acme-ecommerce-platform-dev"
  environment = "dev"
  region      = "us-central1"

  # Environment labels
  environment_labels = {
    environment = local.environment
    business_unit = "ecommerce"
    application = "ecommerce-platform"
    region = local.region
    cost_center = "development"
    data_classification = "internal"
  }
}

inputs = {
  project_id  = local.project_id
  environment = local.environment
  region      = local.region
  common_labels = local.environment_labels
}
