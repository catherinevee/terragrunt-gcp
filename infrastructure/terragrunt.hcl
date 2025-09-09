# Root Terragrunt configuration

locals {
  # Parse account and region from path
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl", "accounts/account.hcl"))
  
  # Extract organization and project information
  organization = local.account_vars.locals.organization
  project_id   = local.account_vars.locals.project_id
  
  # Common labels for all resources
  common_labels = {
    managed_by   = "terragrunt"
    organization = local.organization
    project      = local.project_id
    created_by   = "platform-team"
  }
  
  # Default region if not specified
  default_region = "europe-west1"
}

# Configure remote state storage in GCS
remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "${local.organization}-terraform-state-${local.project_id}"
    prefix         = "${path_relative_to_include()}/terraform.tfstate"
    project        = local.project_id
    location       = local.default_region
    
    # Enable state locking
    enable_bucket_policy_only = true
    
    # Encryption
    encryption_key = null  # Uses Google-managed encryption
  }
}

# Generate provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "google" {
  project = "${local.project_id}"
  region  = "${local.default_region}"
}

provider "google-beta" {
  project = "${local.project_id}"
  region  = "${local.default_region}"
}

terraform {
  required_version = ">= 1.3.0"
  
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

# Default inputs available to all configurations
inputs = {
  project_id = local.project_id
  region     = local.default_region
  labels     = local.common_labels
}

# Terragrunt settings
terraform {
  # Force Terraform to keep trying to acquire a lock for up to 20 minutes
  # if someone else already has the lock
  extra_arguments "retry_lock" {
    commands = get_terraform_commands_that_need_locking()
    arguments = [
      "-lock-timeout=20m"
    ]
  }
  
  # Automatically create missing resource providers
  extra_arguments "auto_approve" {
    commands = ["apply", "destroy"]
    arguments = concat(
      get_env("CI", "false") == "true" ? ["-auto-approve"] : [],
      []
    )
  }
  
  # Custom plan output
  extra_arguments "custom_plan" {
    commands = ["plan"]
    arguments = [
      "-out=tfplan.binary"
    ]
  }
}

# Retry configuration for transient errors
retry_configuration {
  retry_on_exit_codes = [1]
  retry_attempts      = 3
  retry_sleep_interval_sec = 5
}