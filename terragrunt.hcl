# Root Terragrunt Configuration
# Provides common configuration for all Terragrunt modules

# -----------------------------------------------------------------------------
# TERRAFORM VERSION CONSTRAINTS
# -----------------------------------------------------------------------------
terraform_version_constraint  = ">= 1.0"
terragrunt_version_constraint = ">= 0.48.0"

# -----------------------------------------------------------------------------
# GLOBAL LOCALS
# -----------------------------------------------------------------------------
locals {
  # Parse account and region from hierarchy
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl", "account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl", "region.hcl"), {})
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl", "env.hcl"))

  # Extract values
  account_name = local.account_vars.locals.account_name
  account_id   = local.account_vars.locals.account_id
  project_id   = local.account_vars.locals.project_id
  region       = try(local.region_vars.locals.region, "us-central1")
  environment  = local.env_vars.locals.environment

  # Common tags/labels
  common_labels = {
    managed_by     = "terragrunt"
    environment    = local.environment
    project        = local.project_id
    region         = local.region
    terraform      = "true"
    creation_date  = formatdate("YYYY-MM-DD", timestamp())
  }

  # Backend configuration
  backend_bucket_name    = "${local.project_id}-terraform-state"
  backend_bucket_region  = local.region
  backend_dynamodb_table = "${local.project_id}-terraform-locks"
}