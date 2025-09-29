#!/bin/bash
# create-root-terragrunt.sh - Creates root terragrunt.hcl for all environments

set -e

echo "Creating root terragrunt.hcl configurations..."

# Dev environment
cat > infrastructure/environments/dev/terragrunt.hcl << 'EOF'
# Root configuration for dev environment
remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "acme-ecommerce-platform-dev-tfstate"
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
}

inputs = {
  project_id  = local.project_id
  environment = local.environment
  region      = local.region
}
EOF

# Staging environment
cat > infrastructure/environments/staging/terragrunt.hcl << 'EOF'
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
EOF

# Prod environment
cat > infrastructure/environments/prod/terragrunt.hcl << 'EOF'
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
EOF

echo "✅ Root terragrunt.hcl files created for all environments"