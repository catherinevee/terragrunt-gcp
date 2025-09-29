# Shared Backend Configuration for Terragrunt
# This file defines the remote state backend configuration used across all environments
# It supports environment-specific state isolation and locking mechanisms

# Generate backend configuration dynamically based on environment
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<EOF
terraform {
  backend "gcs" {
    # State bucket configuration
    bucket = "${get_env("TF_STATE_BUCKET", "${get_env("GCP_PROJECT_ID", "terraform-state")}-terraform-state")}"
    prefix = "${path_relative_to_include()}"

    # State file location within bucket
    # Format: <environment>/<region>/<service>/<resource>/terraform.tfstate

    # Enable versioning for state history
    # Versioning is handled at the bucket level

    # Encryption
    # Customer-managed encryption keys (CMEK) are configured at the bucket level
    encryption_key = ${get_env("TF_STATE_ENCRYPTION_KEY", "null")}

    # Access credentials
    # Uses Application Default Credentials (ADC) or service account key
    credentials = ${get_env("GOOGLE_CREDENTIALS", "null")}

    # Impersonation for enhanced security
    impersonate_service_account = ${get_env("TF_STATE_SERVICE_ACCOUNT", "null")}

    # Additional backend configuration
    project = "${get_env("GCP_PROJECT_ID", "")}"
    location = "${get_env("TF_STATE_LOCATION", "US")}"
  }
}

# Backend configuration validation
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
  }
}
EOF
}

# Locals for backend configuration
locals {
  # Environment detection
  environment = try(
    regex(".*environments/([^/]+).*", get_terragrunt_dir())[0],
    "default"
  )

  # Region detection
  region = try(
    regex(".*environments/[^/]+/([^/]+).*", get_terragrunt_dir())[1],
    "global"
  )

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

  # State file naming convention
  state_file_prefix = join("/", compact([
    local.environment,
    local.region,
    local.service,
    local.resource
  ]))

  # State bucket configuration
  state_bucket_name = format(
    "%s-%s-terraform-state",
    get_env("GCP_PROJECT_ID", "terraform"),
    local.environment
  )

  # Bucket location based on environment
  state_bucket_location = local.environment == "prod" ? "MULTI-REGION-US" : "US"

  # Encryption configuration
  encryption_key_name = local.environment == "prod" ?
    "projects/${get_env("GCP_PROJECT_ID", "")}/locations/us/keyRings/terraform-state/cryptoKeys/state-encryption" :
    null

  # Lifecycle configuration for state files
  lifecycle_rules = local.environment == "prod" ? [
    {
      action = {
        type = "SetStorageClass"
        storage_class = "NEARLINE"
      }
      condition = {
        age = 30
        with_state = "ANY"
      }
    },
    {
      action = {
        type = "SetStorageClass"
        storage_class = "COLDLINE"
      }
      condition = {
        age = 90
        with_state = "ANY"
      }
    },
    {
      action = {
        type = "SetStorageClass"
        storage_class = "ARCHIVE"
      }
      condition = {
        age = 365
        with_state = "ANY"
      }
    }
  ] : [
    {
      action = {
        type = "Delete"
      }
      condition = {
        age = 90
        with_state = "ANY"
      }
    }
  ]

  # Versioning configuration
  versioning_enabled = true
  version_retention = local.environment == "prod" ? 100 : 30

  # Access control
  uniform_bucket_level_access = true
  public_access_prevention = "enforced"

  # Backup configuration for production state
  backup_configuration = local.environment == "prod" ? {
    enabled = true
    backup_bucket = "${local.state_bucket_name}-backup"
    backup_location = "US"
    backup_schedule = "0 2 * * *"  # Daily at 2 AM
    retention_days = 365
    cross_region_replication = {
      enabled = true
      destination_bucket = "${local.state_bucket_name}-dr"
      destination_location = "EU"
    }
  } : {
    enabled = false
  }

  # Monitoring and alerting for state operations
  monitoring_config = {
    enable_access_logs = true
    access_logs_bucket = "${local.state_bucket_name}-logs"
    enable_data_access_logs = local.environment == "prod"

    alerts = local.environment == "prod" ? {
      unauthorized_access = {
        enabled = true
        threshold = 1
        duration = "60s"
      }
      state_lock_duration = {
        enabled = true
        threshold = 300  # 5 minutes
        duration = "60s"
      }
      concurrent_modifications = {
        enabled = true
        threshold = 2
        duration = "60s"
      }
    } : {}
  }

  # State locking configuration
  state_locking = {
    enabled = true
    lock_timeout = "5m"
    lock_table = "${local.state_bucket_name}-locks"

    # DynamoDB-style locking for GCS (using Firestore)
    firestore_config = {
      database = "(default)"
      collection = "terraform-state-locks"
      ttl_seconds = 3600  # 1 hour TTL for abandoned locks
    }
  }

  # IAM configuration for state bucket
  state_bucket_iam = {
    # Terraform service accounts by environment
    terraform_service_accounts = {
      dev = [
        "terraform-dev@${get_env("GCP_PROJECT_ID", "")}.iam.gserviceaccount.com"
      ]
      staging = [
        "terraform-staging@${get_env("GCP_PROJECT_ID_STAGING", "")}.iam.gserviceaccount.com"
      ]
      prod = [
        "terraform-prod@${get_env("GCP_PROJECT_ID_PROD", "")}.iam.gserviceaccount.com"
      ]
    }

    # Read-only access for specific teams
    readonly_members = {
      dev = [
        "group:developers@company.com"
      ]
      staging = [
        "group:qa-team@company.com",
        "group:developers@company.com"
      ]
      prod = [
        "group:sre-team@company.com",
        "group:security-team@company.com",
        "group:audit-team@company.com"
      ]
    }

    # Admin access (should be minimal)
    admin_members = {
      dev = [
        "group:platform-team@company.com"
      ]
      staging = [
        "group:platform-team@company.com"
      ]
      prod = [
        "group:platform-leads@company.com",
        "user:terraform-admin@company.com"
      ]
    }
  }

  # Compliance and governance
  compliance_config = {
    enable_cmek = local.environment == "prod"
    enable_dlp_scanning = local.environment == "prod"
    enable_access_transparency = local.environment == "prod"

    retention_policy = local.environment == "prod" ? {
      retention_period_days = 2555  # 7 years for compliance
      is_locked = true
    } : null

    audit_configs = local.environment == "prod" ? [
      {
        service = "storage.googleapis.com"
        audit_log_configs = [
          {
            log_type = "ADMIN_READ"
          },
          {
            log_type = "DATA_READ"
          },
          {
            log_type = "DATA_WRITE"
          }
        ]
      }
    ] : []

    labels = merge(
      {
        environment = local.environment
        terraform = "true"
        managed_by = "terragrunt"
        purpose = "terraform-state"
      },
      local.environment == "prod" ? {
        compliance = "required"
        data_classification = "internal"
        backup_required = "true"
        encryption = "cmek"
      } : {}
    )
  }
}

# Remote state configuration for accessing other states
remote_state {
  backend = "gcs"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket = local.state_bucket_name
    prefix = local.state_file_prefix

    # Encryption
    encryption_key = local.encryption_key_name

    # Credentials
    credentials = get_env("GOOGLE_CREDENTIALS", null)
    impersonate_service_account = get_env("TF_STATE_SERVICE_ACCOUNT", null)

    # Project configuration
    project = get_env("GCP_PROJECT_ID", "")
    location = local.state_bucket_location
  }

  # Enable state locking
  disable_bucket_update = false
  enable_bucket_policy_only = true

  # Skip bucket creation if it exists
  skip_bucket_creation = get_env("TF_STATE_SKIP_BUCKET_CREATION", "false") == "true"
  skip_bucket_accesslogging = false
  skip_bucket_public_access_prevention = false
  skip_bucket_versioning = false

  # Custom bucket configuration
  gcs_bucket_labels = local.compliance_config.labels

  # Bucket lifecycle rules
  gcs_bucket_lifecycle_rules = local.lifecycle_rules

  # Enable versioning
  enable_bucket_versioning = local.versioning_enabled

  # Set uniform bucket-level access
  enable_bucket_policy_only = local.uniform_bucket_level_access
}

# Function to create state bucket if it doesn't exist
# This is typically run once during initial setup
terraform_remote_state_bucket_commands = {
  init = <<-EOT
    #!/bin/bash
    set -e

    BUCKET_NAME="${local.state_bucket_name}"
    LOCATION="${local.state_bucket_location}"
    PROJECT="${get_env("GCP_PROJECT_ID", "")}"

    # Check if bucket exists
    if ! gsutil ls -b gs://$${BUCKET_NAME} &>/dev/null; then
      echo "Creating state bucket: $${BUCKET_NAME}"

      # Create bucket
      gsutil mb -p $${PROJECT} -l $${LOCATION} -b on gs://$${BUCKET_NAME}

      # Enable versioning
      gsutil versioning set on gs://$${BUCKET_NAME}

      # Set lifecycle rules
      cat > /tmp/lifecycle.json <<EOF
      {
        "lifecycle": {
          "rule": ${jsonencode(local.lifecycle_rules)}
        }
      }
    EOF
      gsutil lifecycle set /tmp/lifecycle.json gs://$${BUCKET_NAME}

      # Set uniform bucket-level access
      gsutil iam set -f gs://$${BUCKET_NAME}

      # Enable public access prevention
      gsutil pap set enforced gs://$${BUCKET_NAME}

      # Set labels
      ${join(" ", [for k, v in local.compliance_config.labels : "gsutil label ch -l ${k}:${v} gs://$${BUCKET_NAME}"])}

      echo "State bucket created successfully"
    else
      echo "State bucket already exists: $${BUCKET_NAME}"
    fi

    # Create backup bucket for production
    if [[ "${local.environment}" == "prod" ]] && ${local.backup_configuration.enabled}; then
      BACKUP_BUCKET="${local.backup_configuration.backup_bucket}"

      if ! gsutil ls -b gs://$${BACKUP_BUCKET} &>/dev/null; then
        echo "Creating backup bucket: $${BACKUP_BUCKET}"
        gsutil mb -p $${PROJECT} -l ${local.backup_configuration.backup_location} -b on gs://$${BACKUP_BUCKET}
        gsutil versioning set on gs://$${BACKUP_BUCKET}
        gsutil lifecycle set /tmp/lifecycle.json gs://$${BACKUP_BUCKET}
        echo "Backup bucket created successfully"
      fi
    fi
  EOT

  validate = <<-EOT
    #!/bin/bash
    set -e

    BUCKET_NAME="${local.state_bucket_name}"

    echo "Validating state bucket configuration..."

    # Check versioning
    if [[ $(gsutil versioning get gs://$${BUCKET_NAME} | grep -c "Enabled") -eq 0 ]]; then
      echo "ERROR: Versioning is not enabled"
      exit 1
    fi

    # Check lifecycle rules
    if [[ $(gsutil lifecycle get gs://$${BUCKET_NAME} | grep -c "rule") -eq 0 ]]; then
      echo "WARNING: No lifecycle rules configured"
    fi

    # Check public access prevention
    if [[ $(gsutil pap get gs://$${BUCKET_NAME} | grep -c "enforced") -eq 0 ]]; then
      echo "ERROR: Public access prevention is not enforced"
      exit 1
    fi

    echo "State bucket validation completed successfully"
  EOT
}