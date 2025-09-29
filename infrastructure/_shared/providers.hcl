# Shared Provider Configuration for Terragrunt
# This file defines the provider configurations used across all environments
# It includes authentication, default settings, and provider features

# Generate provider configuration dynamically
generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<EOF
# Google Cloud Provider Configuration
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.10.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.10.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.0"
    }
  }
}

# Primary Google Provider
provider "google" {
  # Project configuration
  project = var.project_id
  region  = var.region
  zone    = var.zone

  # Authentication
  credentials = ${get_env("GOOGLE_CREDENTIALS", "null")}

  # Service account impersonation for enhanced security
  impersonate_service_account = ${get_env("GOOGLE_IMPERSONATE_SERVICE_ACCOUNT", "null")}

  # Access token for short-lived authentication
  access_token = ${get_env("GOOGLE_OAUTH_ACCESS_TOKEN", "null")}

  # User project override for quota and billing
  user_project_override = ${get_env("GOOGLE_USER_PROJECT_OVERRIDE", "true") == "true"}
  billing_project       = ${get_env("GOOGLE_BILLING_PROJECT", get_env("GCP_PROJECT_ID", ""))}

  # Request configuration
  request_timeout = "${get_env("GOOGLE_REQUEST_TIMEOUT", "120s")}"
  request_reason  = "${get_env("GOOGLE_REQUEST_REASON", "Managed by Terragrunt")}"

  # Batching configuration for API calls
  batching {
    send_after      = "${get_env("GOOGLE_BATCHING_SEND_AFTER", "3s")}"
    enable_batching = ${get_env("GOOGLE_ENABLE_BATCHING", "true") == "true"}
  }

  # Default labels applied to all resources
  default_labels = {
    environment         = "${local.environment}"
    region             = "${local.region}"
    managed_by         = "terragrunt"
    terraform_version  = "${replace(terraform.version, "/[^0-9.]/", "")}"
    created_by         = "${get_env("USER", "terragrunt")}"
    cost_center        = "${local.cost_center}"
    project            = "${local.project_name}"
    team               = "${local.team}"
    repository         = "${get_env("GITHUB_REPOSITORY", "terragrunt-gcp")}"
    branch             = "${get_env("GITHUB_REF_NAME", "main")}"
    commit             = "${get_env("GITHUB_SHA", "local")}"
    last_modified      = "${timestamp()}"
  }

  # Scopes for authentication (when using service account key)
  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/userinfo.email"
  ]

  # Add custom endpoints for private Google Access
  ${local.private_google_access_endpoints}
}

# Google Beta Provider for preview features
provider "google-beta" {
  # Project configuration
  project = var.project_id
  region  = var.region
  zone    = var.zone

  # Authentication (same as primary provider)
  credentials = ${get_env("GOOGLE_CREDENTIALS", "null")}
  impersonate_service_account = ${get_env("GOOGLE_IMPERSONATE_SERVICE_ACCOUNT", "null")}
  access_token = ${get_env("GOOGLE_OAUTH_ACCESS_TOKEN", "null")}

  # User project override
  user_project_override = ${get_env("GOOGLE_USER_PROJECT_OVERRIDE", "true") == "true"}
  billing_project       = ${get_env("GOOGLE_BILLING_PROJECT", get_env("GCP_PROJECT_ID", ""))}

  # Request configuration
  request_timeout = "${get_env("GOOGLE_REQUEST_TIMEOUT", "120s")}"
  request_reason  = "${get_env("GOOGLE_REQUEST_REASON", "Managed by Terragrunt - Beta Features")}"

  # Batching configuration
  batching {
    send_after      = "${get_env("GOOGLE_BATCHING_SEND_AFTER", "3s")}"
    enable_batching = ${get_env("GOOGLE_ENABLE_BATCHING", "true") == "true"}
  }

  # Default labels (same as primary provider)
  default_labels = {
    environment         = "${local.environment}"
    region             = "${local.region}"
    managed_by         = "terragrunt"
    terraform_version  = "${replace(terraform.version, "/[^0-9.]/", "")}"
    created_by         = "${get_env("USER", "terragrunt")}"
    cost_center        = "${local.cost_center}"
    project            = "${local.project_name}"
    team               = "${local.team}"
    repository         = "${get_env("GITHUB_REPOSITORY", "terragrunt-gcp")}"
    branch             = "${get_env("GITHUB_REF_NAME", "main")}"
    commit             = "${get_env("GITHUB_SHA", "local")}"
    last_modified      = "${timestamp()}"
    beta_feature       = "true"
  }

  # Scopes
  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/userinfo.email"
  ]

  # Add custom endpoints for private Google Access
  ${local.private_google_access_endpoints}
}

# Random Provider for generating random values
provider "random" {
  # No configuration needed
}

# Time Provider for time-based resources
provider "time" {
  # No configuration needed
}

# Null Provider for running local provisioners
provider "null" {
  # No configuration needed
}

# Local Provider for local file operations
provider "local" {
  # No configuration needed
}

# Archive Provider for creating archives
provider "archive" {
  # No configuration needed
}

# Template Provider for template rendering
provider "template" {
  # No configuration needed
}

# HTTP Provider for making HTTP requests
provider "http" {
  # No configuration needed
}

# External Provider for external data sources
provider "external" {
  # No configuration needed
}

# TLS Provider for TLS/SSL operations
provider "tls" {
  # No configuration needed
}

# Provider feature flags
locals {
  # Enable provider features based on environment
  provider_features = {
    # Virtual machine features
    compute_features = {
      enable_oslogin                 = ${local.environment == "prod" ? "true" : "false"}
      enable_osconfig                 = ${local.environment == "prod" ? "true" : "false"}
      enable_shielded_vm             = ${local.environment == "prod" ? "true" : "false"}
      enable_secure_boot             = ${local.environment == "prod" ? "true" : "false"}
      enable_vtpm                    = ${local.environment == "prod" ? "true" : "false"}
      enable_integrity_monitoring    = ${local.environment == "prod" ? "true" : "false"}
      enable_confidential_compute    = ${local.environment == "prod" ? "true" : "false"}
    }

    # Container features
    container_features = {
      enable_workload_identity       = "true"
      enable_binary_authorization    = ${local.environment == "prod" ? "true" : "false"}
      enable_shielded_nodes         = ${local.environment == "prod" ? "true" : "false"}
      enable_private_cluster        = ${local.environment != "dev" ? "true" : "false"}
      enable_private_endpoint       = ${local.environment == "prod" ? "true" : "false"}
      enable_network_policy         = "true"
      enable_pod_security_policy    = ${local.environment == "prod" ? "true" : "false"}
      enable_cluster_autoscaling    = "true"
      enable_node_auto_upgrade      = ${local.environment == "dev" ? "true" : "false"}
      enable_node_auto_repair       = "true"
    }

    # Security features
    security_features = {
      enable_cmek                   = ${local.environment != "dev" ? "true" : "false"}
      enable_dlp                    = ${local.environment == "prod" ? "true" : "false"}
      enable_vpc_service_controls  = ${local.environment == "prod" ? "true" : "false"}
      enable_private_google_access  = "true"
      enable_cloud_armor           = ${local.environment != "dev" ? "true" : "false"}
      enable_cloud_ids             = ${local.environment == "prod" ? "true" : "false"}
      enable_security_command_center = ${local.environment == "prod" ? "true" : "false"}
      enable_access_transparency    = ${local.environment == "prod" ? "true" : "false"}
      enable_data_access_logs      = ${local.environment == "prod" ? "true" : "false"}
      enable_audit_logs            = "true"
    }

    # Networking features
    networking_features = {
      enable_private_service_connect = ${local.environment != "dev" ? "true" : "false"}
      enable_cloud_nat              = "true"
      enable_cloud_cdn              = ${local.environment != "dev" ? "true" : "false"}
      enable_global_load_balancing  = ${local.environment == "prod" ? "true" : "false"}
      enable_traffic_director       = ${local.environment == "prod" ? "true" : "false"}
      enable_service_mesh          = ${local.environment == "prod" ? "true" : "false"}
      enable_shared_vpc            = ${local.environment == "prod" ? "true" : "false"}
      network_tier                 = ${local.environment == "prod" ? "PREMIUM" : "STANDARD"}
    }

    # Monitoring features
    monitoring_features = {
      enable_cloud_monitoring       = "true"
      enable_cloud_logging         = "true"
      enable_cloud_trace           = "true"
      enable_cloud_profiler        = ${local.environment != "dev" ? "true" : "false"}
      enable_cloud_debugger        = ${local.environment == "dev" ? "true" : "false"}
      enable_error_reporting       = "true"
      enable_uptime_checks        = ${local.environment != "dev" ? "true" : "false"}
      enable_custom_metrics       = "true"
      enable_log_based_metrics    = "true"
      enable_synthetic_monitoring  = ${local.environment == "prod" ? "true" : "false"}
    }

    # Data features
    data_features = {
      enable_data_catalog          = ${local.environment == "prod" ? "true" : "false"}
      enable_data_loss_prevention  = ${local.environment == "prod" ? "true" : "false"}
      enable_data_fusion          = ${local.environment == "prod" ? "true" : "false"}
      enable_dataprep             = ${local.environment != "dev" ? "true" : "false"}
      enable_dataflow_flex_template = ${local.environment != "dev" ? "true" : "false"}
    }
  }
}
EOF
}

# Locals for provider configuration
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

  # Project configuration based on environment
  project_config = {
    dev = {
      project_id     = get_env("GCP_PROJECT_ID_DEV", "my-dev-project")
      project_name   = "Development Project"
      project_number = get_env("GCP_PROJECT_NUMBER_DEV", "123456789012")
      cost_center    = "engineering"
      team           = "platform-dev"
    }
    staging = {
      project_id     = get_env("GCP_PROJECT_ID_STAGING", "my-staging-project")
      project_name   = "Staging Project"
      project_number = get_env("GCP_PROJECT_NUMBER_STAGING", "234567890123")
      cost_center    = "engineering"
      team           = "platform-staging"
    }
    prod = {
      project_id     = get_env("GCP_PROJECT_ID_PROD", "my-production-project")
      project_name   = "Production Project"
      project_number = get_env("GCP_PROJECT_NUMBER_PROD", "345678901234")
      cost_center    = "operations"
      team           = "platform-prod"
    }
  }

  # Extract project details
  project_id     = local.project_config[local.environment].project_id
  project_name   = local.project_config[local.environment].project_name
  project_number = local.project_config[local.environment].project_number
  cost_center    = local.project_config[local.environment].cost_center
  team           = local.project_config[local.environment].team

  # API activation settings
  api_activation = {
    disable_services_on_destroy = local.environment == "dev"
    disable_dependent_services  = false
  }

  # Provider timeout settings by environment
  timeout_settings = {
    dev = {
      create = "20m"
      update = "20m"
      delete = "20m"
    }
    staging = {
      create = "30m"
      update = "30m"
      delete = "30m"
    }
    prod = {
      create = "45m"
      update = "45m"
      delete = "45m"
    }
  }

  # Retry settings for API calls
  retry_settings = {
    max_retries              = local.environment == "prod" ? 5 : 3
    retry_on_exit_codes      = [409, 429, 500, 502, 503, 504]
    retry_multiplier         = 2
    retry_max_delay_seconds  = 120
    retry_base_delay_seconds = 1
  }

  # Private Google Access endpoints for airgapped environments
  private_google_access_endpoints = local.environment == "prod" ? <<-EOT
    # Custom endpoints for Private Google Access
    compute_custom_endpoint         = "https://compute.googleapis.com"
    container_custom_endpoint       = "https://container.googleapis.com"
    storage_custom_endpoint         = "https://storage.googleapis.com"
    sql_custom_endpoint            = "https://sqladmin.googleapis.com"
    pubsub_custom_endpoint         = "https://pubsub.googleapis.com"
    bigquery_custom_endpoint       = "https://bigquery.googleapis.com"
    cloudresourcemanager_custom_endpoint = "https://cloudresourcemanager.googleapis.com"
    iam_custom_endpoint            = "https://iam.googleapis.com"
    iamcredentials_custom_endpoint = "https://iamcredentials.googleapis.com"
    serviceusage_custom_endpoint   = "https://serviceusage.googleapis.com"
    cloudkms_custom_endpoint       = "https://cloudkms.googleapis.com"
    logging_custom_endpoint        = "https://logging.googleapis.com"
    monitoring_custom_endpoint     = "https://monitoring.googleapis.com"
  EOT : ""

  # Rate limiting configuration
  rate_limiting = {
    compute_operations_per_second = local.environment == "prod" ? 20 : 10
    global_operations_per_second  = local.environment == "prod" ? 100 : 50
    read_operations_per_second    = local.environment == "prod" ? 300 : 100
    list_operations_per_second    = local.environment == "prod" ? 100 : 50
  }

  # Provider validation rules
  validation_rules = {
    validate_project_id = {
      condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", local.project_id))
      error_message = "Project ID must be 6-30 characters, lowercase letters, digits, hyphens"
    }

    validate_region = {
      condition = contains([
        "us-central1", "us-east1", "us-east4", "us-west1", "us-west2", "us-west3", "us-west4",
        "europe-west1", "europe-west2", "europe-west3", "europe-west4", "europe-west6", "europe-north1",
        "asia-southeast1", "asia-southeast2", "asia-northeast1", "asia-northeast2", "asia-northeast3",
        "asia-south1", "asia-south2", "asia-east1", "asia-east2",
        "australia-southeast1", "australia-southeast2",
        "southamerica-east1", "southamerica-west1",
        "northamerica-northeast1", "northamerica-northeast2",
        "me-west1", "me-central1",
        "africa-south1",
        "global"
      ], local.region)
      error_message = "Region must be a valid GCP region"
    }
  }

  # Quota management
  quota_config = {
    check_quota_before_apply     = local.environment == "prod"
    fail_on_quota_exceeded      = local.environment == "prod"
    request_quota_increase      = false
    quota_increase_buffer_percent = 20
  }

  # Cost management
  cost_config = {
    enable_cost_estimation      = true
    cost_estimation_currency    = "USD"
    fail_on_cost_exceeded      = local.environment == "prod"
    max_estimated_monthly_cost  = local.environment == "prod" ? 50000 : local.environment == "staging" ? 10000 : 5000
    enable_budget_alerts       = local.environment != "dev"
    budget_alert_thresholds    = [50, 75, 90, 100, 110]
  }

  # Change management
  change_config = {
    require_approval           = local.environment == "prod"
    approval_timeout_hours     = 24
    auto_rollback_on_failure   = local.environment == "prod"
    enable_drift_detection     = local.environment != "dev"
    drift_detection_frequency  = local.environment == "prod" ? "hourly" : "daily"
    enable_change_tracking     = true
    change_tracking_table      = "${local.project_id}.terraform_changes"
  }

  # Provider aliases for multi-region deployments
  provider_aliases = {
    us_central1 = {
      region = "us-central1"
      zone   = "us-central1-a"
    }
    us_east1 = {
      region = "us-east1"
      zone   = "us-east1-b"
    }
    europe_west1 = {
      region = "europe-west1"
      zone   = "europe-west1-b"
    }
    asia_southeast1 = {
      region = "asia-southeast1"
      zone   = "asia-southeast1-a"
    }
    australia_southeast1 = {
      region = "australia-southeast1"
      zone   = "australia-southeast1-a"
    }
  }
}