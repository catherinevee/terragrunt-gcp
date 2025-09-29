# Root configuration for staging environment
remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "acme-ecommerce-platform-staging-tfstate"
    prefix         = "${path_relative_to_include()}"
    project        = "acme-ecommerce-platform-staging"
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
  project_id  = "acme-ecommerce-platform-staging"
  environment = "staging"
  region      = "us-central1"
}

inputs = {
  project_id  = local.project_id
  environment = local.environment
  region      = local.region
}
