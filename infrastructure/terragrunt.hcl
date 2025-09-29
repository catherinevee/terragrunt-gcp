# Root Terragrunt Configuration
# This is the root configuration file that is included by all child terragrunt.hcl files
# It provides centralized configuration for backend, providers, and common settings

# Prevent running Terragrunt in the root directory
skip = true

locals {
  # Load shared configurations
  backend_config   = read_terragrunt_config("${get_terragrunt_dir()}/_shared/backend.hcl", { locals = {} })
  providers_config = read_terragrunt_config("${get_terragrunt_dir()}/_shared/providers.hcl", { locals = {} })
  common_config    = read_terragrunt_config("${get_terragrunt_dir()}/_shared/common.hcl", { locals = {} })

  # Parse account configuration if it exists
  account_vars = read_terragrunt_config(
    find_in_parent_folders("account.hcl", "account.hcl"),
    { locals = {} }
  )

  # Parse environment configuration if it exists
  env_vars = read_terragrunt_config(
    find_in_parent_folders("env.hcl", "env.hcl"),
    { locals = {} }
  )

  # Parse region configuration if it exists
  region_vars = read_terragrunt_config(
    find_in_parent_folders("region.hcl", "region.hcl"),
    { locals = {} }
  )

  # Environment detection with validation
  environment_path = try(
    regex(".*environments/([^/]+).*", get_terragrunt_dir())[0],
    "default"
  )

  valid_environments = ["dev", "staging", "prod"]
  environment = contains(local.valid_environments, local.environment_path) ? local.environment_path : "default"

  # Region detection with smart defaults
  region_path = try(
    regex(".*environments/[^/]+/([^/]+).*", get_terragrunt_dir())[1],
    "global"
  )

  region = local.region_path != "global" ? local.region_path : try(local.region_vars.locals.region, "us-central1")

  # Service detection
  service = try(
    regex(".*environments/[^/]+/[^/]+/([^/]+).*", get_terragrunt_dir())[2],
    ""
  )

  # Resource detection
  resource = try(
    regex(".*environments/[^/]+/[^/]+/[^/]+/([^/]+).*", get_terragrunt_dir())[3],
    ""
  )

  # Project configuration with environment-specific overrides
  project_id = try(
    local.account_vars.locals.project_id,
    get_env("GCP_PROJECT_ID_${upper(local.environment)}", get_env("GCP_PROJECT_ID", ""))
  )

  project_name = try(
    local.account_vars.locals.project_name,
    "${title(local.environment)} Project"
  )

  project_number = try(
    local.account_vars.locals.project_number,
    get_env("GCP_PROJECT_NUMBER_${upper(local.environment)}", "")
  )

  # Organization configuration
  organization_id = try(
    local.account_vars.locals.organization_id,
    get_env("GCP_ORG_ID", "")
  )

  organization_domain = try(
    local.account_vars.locals.organization_domain,
    get_env("GCP_ORG_DOMAIN", "company.com")
  )

  billing_account = try(
    local.account_vars.locals.billing_account,
    get_env("GCP_BILLING_ACCOUNT", "")
  )

  # Folder structure
  folder_id = try(
    local.account_vars.locals.folder_structure.parent_folder_id,
    get_env("GCP_FOLDER_ID_${upper(local.environment)}", "")
  )

  # State bucket configuration with environment isolation
  state_bucket_prefix = get_env("TF_STATE_BUCKET_PREFIX", local.organization_domain)
  state_bucket = format(
    "%s-%s-%s-terraform-state",
    replace(local.state_bucket_prefix, ".", "-"),
    local.project_id,
    local.environment
  )

  state_bucket_location = local.environment == "prod" ? "US" : local.region

  # Common labels to apply to all resources
  common_labels = merge(
    {
      # Mandatory labels
      environment         = local.environment
      region             = local.region
      managed_by         = "terragrunt"
      terraform_managed  = "true"
      project_id         = local.project_id
      organization_id    = local.organization_id

      # Metadata labels
      created_date       = formatdate("YYYY-MM-DD", timestamp())
      created_by         = get_env("USER", "terragrunt")
      terraform_version  = run_cmd("--terragrunt-quiet", "terraform", "version", "-json")
      terragrunt_version = run_cmd("--terragrunt-quiet", "terragrunt", "--version")

      # Source control labels
      git_repository     = get_env("GITHUB_REPOSITORY", "terragrunt-gcp")
      git_branch         = get_env("GITHUB_REF_NAME", run_cmd("--terragrunt-quiet", "git", "rev-parse", "--abbrev-ref", "HEAD"))
      git_commit         = get_env("GITHUB_SHA", run_cmd("--terragrunt-quiet", "git", "rev-parse", "HEAD"))
      git_author         = run_cmd("--terragrunt-quiet", "git", "config", "user.email")

      # Cost tracking labels
      cost_center        = try(local.account_vars.locals.account_labels.cost_center, "engineering")
      business_unit      = try(local.account_vars.locals.account_labels.business_unit, "platform")
      team               = try(local.account_vars.locals.account_labels.team, "infrastructure")

      # Compliance labels
      data_classification = try(local.account_vars.locals.account_labels.data_classification, "internal")
      compliance_level   = try(local.account_vars.locals.account_labels.compliance_level, "standard")
      backup_required    = try(local.account_vars.locals.account_labels.backup_required, "false")

      # Service labels
      service            = local.service
      resource           = local.resource
    },
    # Environment-specific label overrides
    local.environment == "prod" ? {
      sla_tier          = "platinum"
      monitoring_level  = "comprehensive"
      change_control    = "required"
      automation_enabled = "true"
      dr_enabled        = "true"
    } : {},
    local.environment == "staging" ? {
      sla_tier          = "gold"
      monitoring_level  = "enhanced"
      change_control    = "recommended"
      automation_enabled = "true"
      dr_enabled        = "false"
    } : {
      sla_tier          = "bronze"
      monitoring_level  = "basic"
      change_control    = "optional"
      automation_enabled = "false"
      dr_enabled        = "false"
    },
    # Include account-specific labels if they exist
    try(local.account_vars.locals.account_labels, {}),
    # Include environment-specific labels if they exist
    try(local.env_vars.locals.environment_labels, {}),
    # Include region-specific labels if they exist
    try(local.region_vars.locals.region_labels, {})
  )

  # Terraform backend encryption configuration
  encryption_key = local.environment == "prod" ?
    "projects/${local.project_id}/locations/${local.state_bucket_location}/keyRings/terraform-state/cryptoKeys/state-key" :
    null

  # Service account for state management
  terraform_service_account = try(
    local.account_vars.locals.terraform_service_account,
    "terraform-${local.environment}@${local.project_id}.iam.gserviceaccount.com"
  )
}

# Include all shared configurations
include "backend" {
  path = "${get_terragrunt_dir()}/_shared/backend.hcl"
  expose = true
}

include "providers" {
  path = "${get_terragrunt_dir()}/_shared/providers.hcl"
  expose = true
}

include "common" {
  path = "${get_terragrunt_dir()}/_shared/common.hcl"
  expose = true
}

# Configure Terraform behavior
terraform {
  # Set Terraform version constraints
  required_version = ">= 1.5.0, < 2.0.0"

  # Force Terraform to keep trying to acquire a lock for up to 20 minutes
  extra_arguments "retry_lock" {
    commands = get_terraform_commands_that_need_locking()
    arguments = [
      "-lock-timeout=20m"
    ]
  }

  # Pass common variables to all Terraform commands
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()
    arguments = [
      "-compact-warnings"
    ]
  }

  # Environment-specific var files
  extra_arguments "env_vars" {
    commands = get_terraform_commands_that_need_vars()

    optional_var_files = [
      "${get_terragrunt_dir()}/terraform.tfvars",
      "${get_parent_terragrunt_dir()}/environments/${local.environment}/terraform.tfvars",
      "${get_parent_terragrunt_dir()}/environments/${local.environment}/${local.region}/terraform.tfvars",
      "${get_terragrunt_dir()}/terraform.${local.environment}.tfvars",
      "${get_terragrunt_dir()}/secrets.tfvars"
    ]
  }

  # Auto-approve for non-production environments
  extra_arguments "auto_approve" {
    commands = ["apply", "destroy"]
    arguments = local.environment == "dev" ? ["-auto-approve"] : []
  }

  # Detailed plan output
  extra_arguments "plan_out" {
    commands = ["plan"]
    arguments = [
      "-out=${get_terragrunt_dir()}/tfplan.binary",
      "-detailed-exitcode"
    ]
  }

  # Parallelism configuration based on environment
  extra_arguments "parallelism" {
    commands = get_terraform_commands_that_need_parallelism()
    arguments = [
      "-parallelism=${local.environment == "prod" ? 10 : local.environment == "staging" ? 20 : 30}"
    ]
  }

  # Enable JSON output for better parsing
  extra_arguments "json_output" {
    commands = ["output", "show"]
    arguments = ["-json"]
  }

  # Refresh configuration
  extra_arguments "refresh" {
    commands = ["plan", "apply", "destroy"]
    arguments = local.environment == "prod" ? [] : ["-refresh=false"]
  }

  # Target specific resources in dev (useful for debugging)
  extra_arguments "target" {
    commands = ["plan", "apply", "destroy"]
    env_vars = {
      TF_CLI_ARGS_plan    = get_env("TF_TARGET", "")
      TF_CLI_ARGS_apply   = get_env("TF_TARGET", "")
      TF_CLI_ARGS_destroy = get_env("TF_TARGET", "")
    }
  }

  # Before hooks
  before_hook "before_plan" {
    commands = ["plan"]
    execute = ["echo", "Running Terraform plan for ${local.environment} environment in ${local.region} region"]
  }

  before_hook "before_apply" {
    commands = ["apply"]
    execute = ["echo", "Applying Terraform changes for ${local.environment} environment in ${local.region} region"]
  }

  before_hook "validate_environment" {
    commands = ["apply", "destroy"]
    execute = local.environment == "prod" ?
      ["bash", "-c", "echo 'WARNING: Running in PRODUCTION environment. Confirm to proceed.' && read -p 'Continue? (yes/no): ' confirm && [[ $confirm == 'yes' ]]"] :
      ["echo", "Running in ${local.environment} environment"]
  }

  # After hooks
  after_hook "after_apply_success" {
    commands = ["apply"]
    execute = ["echo", "Terraform apply completed successfully"]
    run_on_error = false
  }

  after_hook "after_apply_failure" {
    commands = ["apply"]
    execute = ["echo", "Terraform apply failed. Review the errors above."]
    run_on_error = true
  }

  after_hook "cleanup_plan_files" {
    commands = ["apply", "destroy"]
    execute = ["bash", "-c", "rm -f ${get_terragrunt_dir()}/tfplan.binary"]
  }

  # Error hooks for production
  error_hook "on_error" {
    commands = ["apply", "destroy"]
    execute = local.environment == "prod" ?
      ["bash", "-c", "echo 'ERROR: Terraform operation failed in production!' | tee -a ${get_terragrunt_dir()}/terraform-errors.log"] :
      ["echo", "Error occurred in ${local.environment}"]
    on_errors = [".*"]
  }
}

# Retry configuration for transient errors
retry_max_attempts       = 3
retry_sleep_interval_sec = 5

# Configure Terragrunt to retry on specific errors
retryable_errors = [
  "(?s).*Error creating Service: googleapi: Error 409.*",
  "(?s).*Error creating Project: googleapi: Error 409.*",
  "(?s).*Error 409: Requested entity already exists.*",
  "(?s).*Error 429: Quota exceeded.*",
  "(?s).*Error 503: Service temporarily unavailable.*",
  "(?s).*Error: operation timed out.*",
  "(?s).*net/http: TLS handshake timeout.*"
]

# IAM role configuration for the Terraform service account
iam_role = local.environment == "prod" ? "roles/owner" : "roles/editor"

# Configure default inputs that will be passed to all modules
inputs = merge(
  # Core inputs
  {
    project_id         = local.project_id
    project_name       = local.project_name
    project_number     = local.project_number
    region             = local.region
    environment        = local.environment
    organization_id    = local.organization_id
    billing_account    = local.billing_account
    folder_id          = local.folder_id

    # Labels
    labels             = local.common_labels
    common_labels      = local.common_labels

    # Naming
    name_prefix        = "${local.environment}-${local.region}"
    resource_suffix    = get_env("RESOURCE_SUFFIX", "")

    # Network
    network_name       = try(local.region_vars.locals.vpc_name, "${local.environment}-${local.region}-vpc")
    subnet_name        = try(local.region_vars.locals.subnet_name, "${local.environment}-${local.region}-subnet")

    # Service Account
    terraform_service_account = local.terraform_service_account

    # Features based on environment
    enable_apis        = true
    activate_apis      = try(local.account_vars.locals.required_apis, [])

    # Security
    enable_cmek        = local.environment != "dev"
    kms_key_ring      = try(local.region_vars.locals.security_config.kms.key_ring, "${local.environment}-${local.region}-keyring")
    kms_crypto_key    = try(local.region_vars.locals.security_config.kms.keys.default, "${local.environment}-${local.region}-key")

    # Monitoring
    enable_monitoring  = true
    enable_logging    = true
    log_retention_days = local.environment == "prod" ? 90 : 30

    # Backup
    enable_backup     = local.environment != "dev"
    backup_retention  = local.environment == "prod" ? 90 : 30

    # High Availability
    enable_ha         = local.environment == "prod"

    # Cost Management
    enable_budget_alerts = local.environment != "dev"
    budget_amount     = local.environment == "prod" ? 50000 : local.environment == "staging" ? 10000 : 5000
  },

  # Include account variables if they exist
  try(local.account_vars.locals, {}),

  # Include environment variables if they exist
  try(local.env_vars.locals, {}),

  # Include region variables if they exist
  try(local.region_vars.locals, {})
)

# Prevent running certain commands in production without confirmation
prevent_destroy = local.environment == "prod"

# Download Terraform configurations from source
download_dir = "${get_terragrunt_dir()}/.terragrunt-cache"

# Configure how to download Terraform code
terraform_version_constraint = ">= 1.5.0"
terragrunt_version_constraint = ">= 0.48.0"

# Enable caching of providers
provider_cache_dir = "${get_env("HOME", "/tmp")}/.terraform.d/plugin-cache"

# Configure concurrent execution
terraform_parallelism = local.environment == "prod" ? 10 : 20

# Dependencies management
dependencies {
  skip_dependencies_inputs = false

  # Configure how to handle dependency blocks
  config = {
    path = find_in_parent_folders()
  }
}

# Configure output formatting
terraform_stdout_is_json = get_env("TF_OUTPUT_JSON", "false") == "true"

# Logging configuration
log_level = get_env("TG_LOG", local.environment == "dev" ? "debug" : "info")
log_format = get_env("TG_LOG_FORMAT", "json")

# Performance optimizations
disable_checkpoint = true
disable_checkpoint_signature = true

# Error handling
on_error {
  # Clean up temporary files on error
  commands = ["bash", "-c", "find ${get_terragrunt_dir()} -name '*.tmp' -delete"]

  # Send notification on production errors
  notification = local.environment == "prod" ? {
    slack = {
      webhook_url = get_env("SLACK_WEBHOOK_URL", "")
      channel = "#production-alerts"
    }
  } : null
}