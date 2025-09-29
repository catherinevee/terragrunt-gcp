# Root configuration for prod environment
remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "acme-ecommerce-platform-prod-tfstate"
    prefix         = "${path_relative_to_include()}"
    project        = "acme-ecommerce-platform-prod"
    location       = "us"
    enable_bucket_policy_only = true
    versioning = true
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
  project_id  = "acme-ecommerce-platform-prod"
  environment = "prod"
  region      = "us-central1"
}

inputs = {
  project_id  = local.project_id
  environment = local.environment
  region      = local.region
}
