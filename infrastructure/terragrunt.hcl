# Root Terragrunt configuration
# This file is included by all child terragrunt.hcl files

locals {
  # Parse the account configuration
  account_vars = read_terragrunt_config(find_in_parent_folders("accounts/account.hcl"))
  
  # Parse the environment configuration
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl", "env.hcl"))
  
  # Extract commonly used variables
  organization = local.account_vars.locals.organization
  project_id   = local.account_vars.locals.project_id
  region       = local.env_vars.locals.region
  environment  = local.env_vars.locals.environment
  
  # Common labels to apply to all resources
  common_labels = {
    organization = local.organization
    environment  = local.environment
    managed_by   = "terragrunt"
    project      = local.project_id
    region       = local.region
  }
  
  # State bucket name
  state_bucket = "${local.organization}-terraform-state-${local.environment}"
}

# Configure remote state storage in GCS
remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = local.state_bucket
    prefix         = "${path_relative_to_include()}/terraform.tfstate"
    project        = local.project_id
    location       = local.region
    
    # Enable state locking
    enable_bucket_policy_only = true
    
    # Encryption
    encryption_key = null  # Uses Google-managed encryption
    
    # Versioning (bucket should have versioning enabled)
    skip_bucket_creation     = false
    skip_bucket_versioning   = false
    skip_bucket_public_access_prevention = false
  }
}

# Generate provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "google" {
  project = "${local.project_id}"
  region  = "${local.region}"
}

provider "google-beta" {
  project = "${local.project_id}"
  region  = "${local.region}"
}
EOF
}

# Generate versions configuration (only if not using Terraform Registry modules)
generate "versions" {
  path      = "versions.tf"
  if_exists = "skip"
  contents  = <<EOF
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}
EOF
}

# Configure Terragrunt behavior
terraform {
  # Force Terraform to keep trying to acquire a lock for up to 10 minutes
  # if someone else already has the lock
  extra_arguments "retry_lock" {
    commands = get_terraform_commands_that_need_locking()
    arguments = [
      "-lock-timeout=10m"
    ]
  }

  # Pass common variables to all Terraform commands
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()
    arguments = [
      "-compact-warnings",
    ]
  }

  # Auto-approve for non-production environments during apply
  extra_arguments "auto_approve" {
    commands = ["apply"]
    arguments = concat(
      local.environment != "prod" ? ["-auto-approve"] : [],
      []
    )
  }
}

# Retry behavior is handled by Terraform's built-in retry logic

# Configure inputs that will be passed to all Terraform modules
inputs = {
  project_id   = local.project_id
  region       = local.region
  environment  = local.environment
  organization = local.organization
  labels       = local.common_labels
}