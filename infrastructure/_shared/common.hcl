# Shared Common Variables Configuration for Terragrunt
# This file defines common variables and configurations used across all environments
# It provides a centralized location for shared settings and standards

# Generate common variables
generate "variables" {
  path      = "variables.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<EOF
# Common Variables for all Terraform configurations

# Project Variables
variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "${local.project_id}"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, lowercase letters, digits, hyphens."
  }
}

variable "project_name" {
  description = "The GCP project name"
  type        = string
  default     = "${local.project_name}"
}

variable "project_number" {
  description = "The GCP project number"
  type        = string
  default     = "${local.project_number}"
}

# Location Variables
variable "region" {
  description = "The default GCP region"
  type        = string
  default     = "${local.region}"

  validation {
    condition = contains([
      "us-central1", "us-east1", "us-east4", "us-west1", "us-west2", "us-west3", "us-west4",
      "europe-west1", "europe-west2", "europe-west3", "europe-west4", "europe-west6", "europe-north1",
      "asia-southeast1", "asia-southeast2", "asia-northeast1", "asia-northeast2", "asia-northeast3",
      "asia-south1", "asia-south2", "asia-east1", "asia-east2",
      "australia-southeast1", "australia-southeast2",
      "southamerica-east1", "southamerica-west1",
      "northamerica-northeast1", "northamerica-northeast2",
      "me-west1", "me-central1", "africa-south1", "global"
    ], var.region)
    error_message = "Region must be a valid GCP region or 'global'."
  }
}

variable "zone" {
  description = "The default GCP zone"
  type        = string
  default     = "${local.zone}"

  validation {
    condition     = var.zone == null || can(regex("^[a-z]+-[a-z]+[0-9]+-[a-z]$", var.zone))
    error_message = "Zone must be a valid GCP zone (e.g., us-central1-a)."
  }
}

variable "zones" {
  description = "List of GCP zones for multi-zone deployments"
  type        = list(string)
  default     = ${jsonencode(local.zones)}
}

variable "multi_region" {
  description = "Multi-region configuration for global deployments"
  type = object({
    enabled           = bool
    primary_region    = string
    secondary_regions = list(string)
  })
  default = ${jsonencode(local.multi_region)}
}

# Environment Variables
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "${local.environment}"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "environment_config" {
  description = "Environment-specific configuration"
  type        = map(any)
  default     = ${jsonencode(local.environment_config[local.environment])}
}

# Organization Variables
variable "organization_id" {
  description = "The GCP organization ID"
  type        = string
  default     = "${local.organization_id}"
  sensitive   = true
}

variable "billing_account" {
  description = "The GCP billing account ID"
  type        = string
  default     = "${local.billing_account}"
  sensitive   = true
}

variable "folder_id" {
  description = "The GCP folder ID for resource organization"
  type        = string
  default     = "${local.folder_id}"
}

# Naming Convention Variables
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "${local.name_prefix}"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,61}$", var.name_prefix))
    error_message = "Name prefix must start with a letter and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "name_suffix" {
  description = "Suffix for resource names"
  type        = string
  default     = "${local.name_suffix}"
}

variable "resource_naming" {
  description = "Resource naming convention configuration"
  type = object({
    separator           = string
    use_random_suffix   = bool
    random_suffix_length = number
    include_environment = bool
    include_region      = bool
  })
  default = ${jsonencode(local.resource_naming)}
}

# Network Configuration Variables
variable "network_config" {
  description = "Network configuration settings"
  type        = map(any)
  default     = ${jsonencode(local.network_config)}
}

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "${local.vpc_name}"
}

variable "subnet_config" {
  description = "Subnet configuration"
  type = map(object({
    cidr                    = string
    secondary_ranges        = map(string)
    private_google_access   = bool
    private_ip_google_access = bool
    flow_logs              = bool
  }))
  default = ${jsonencode(local.subnet_config)}
}

# Security Variables
variable "security_config" {
  description = "Security configuration settings"
  type        = map(any)
  default     = ${jsonencode(local.security_config)}
}

variable "kms_key_ring" {
  description = "KMS key ring for encryption"
  type        = string
  default     = "${local.kms_key_ring}"
}

variable "kms_crypto_key" {
  description = "KMS crypto key for encryption"
  type        = string
  default     = "${local.kms_crypto_key}"
}

variable "enable_cmek" {
  description = "Enable customer-managed encryption keys"
  type        = bool
  default     = ${local.enable_cmek}
}

# IAM Variables
variable "iam_config" {
  description = "IAM configuration"
  type        = map(any)
  default     = ${jsonencode(local.iam_config)}
}

variable "service_account_config" {
  description = "Service account configuration"
  type = map(object({
    account_id   = string
    display_name = string
    description  = string
    roles        = list(string)
  }))
  default = ${jsonencode(local.service_account_config)}
}

# Monitoring Variables
variable "monitoring_config" {
  description = "Monitoring and observability configuration"
  type        = map(any)
  default     = ${jsonencode(local.monitoring_config)}
}

variable "logging_config" {
  description = "Logging configuration"
  type = object({
    retention_days     = number
    include_audit_logs = bool
    log_level         = string
    sink_destinations = list(string)
  })
  default = ${jsonencode(local.logging_config)}
}

variable "alerting_config" {
  description = "Alerting configuration"
  type = object({
    enabled               = bool
    notification_channels = list(string)
    alert_policies       = map(any)
  })
  default = ${jsonencode(local.alerting_config)}
}

# Backup and DR Variables
variable "backup_config" {
  description = "Backup configuration"
  type        = map(any)
  default     = ${jsonencode(local.backup_config)}
}

variable "disaster_recovery_config" {
  description = "Disaster recovery configuration"
  type = object({
    enabled          = bool
    dr_region        = string
    rpo_minutes      = number
    rto_minutes      = number
    test_frequency   = string
  })
  default = ${jsonencode(local.disaster_recovery_config)}
}

# Cost Management Variables
variable "budget_config" {
  description = "Budget and cost management configuration"
  type        = map(any)
  default     = ${jsonencode(local.budget_config)}
}

variable "cost_optimization" {
  description = "Cost optimization settings"
  type = object({
    use_preemptible_vms        = bool
    use_committed_use_discounts = bool
    enable_auto_shutdown       = bool
    enable_rightsizing        = bool
  })
  default = ${jsonencode(local.cost_optimization)}
}

# Compliance Variables
variable "compliance_config" {
  description = "Compliance configuration"
  type        = map(any)
  default     = ${jsonencode(local.compliance_config)}
}

variable "data_classification" {
  description = "Data classification level"
  type        = string
  default     = "${local.data_classification}"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "Data classification must be public, internal, confidential, or restricted."
  }
}

# Labels/Tags Variables
variable "common_labels" {
  description = "Common labels to apply to all resources"
  type        = map(string)
  default     = ${jsonencode(local.common_labels)}
}

variable "required_labels" {
  description = "Required labels that must be present on all resources"
  type        = list(string)
  default     = ${jsonencode(local.required_labels)}
}

# Feature Flags Variables
variable "feature_flags" {
  description = "Feature flags for enabling/disabling functionality"
  type        = map(bool)
  default     = ${jsonencode(local.feature_flags)}
}

# API Enablement Variables
variable "required_apis" {
  description = "List of required Google APIs to enable"
  type        = list(string)
  default     = ${jsonencode(local.required_apis)}
}

# Maintenance Window Variables
variable "maintenance_window" {
  description = "Maintenance window configuration"
  type = object({
    day          = number
    hour         = number
    duration     = string
    update_track = string
  })
  default = ${jsonencode(local.maintenance_window)}
}

# Quota Variables
variable "quota_limits" {
  description = "Resource quota limits"
  type        = map(number)
  default     = ${jsonencode(local.quota_limits)}
}

# Performance Variables
variable "performance_config" {
  description = "Performance configuration settings"
  type        = map(any)
  default     = ${jsonencode(local.performance_config)}
}

# Automation Variables
variable "automation_config" {
  description = "Automation configuration"
  type = object({
    enable_auto_remediation = bool
    enable_auto_scaling    = bool
    enable_auto_backup     = bool
    enable_auto_update     = bool
  })
  default = ${jsonencode(local.automation_config)}
}

# Integration Variables
variable "integration_config" {
  description = "External integration configuration"
  type        = map(any)
  default     = ${jsonencode(local.integration_config)}
}

# Outputs that should be available everywhere
output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "The GCP region"
  value       = var.region
}

output "environment" {
  description = "The environment name"
  value       = var.environment
}

output "vpc_name" {
  description = "The VPC network name"
  value       = var.vpc_name
}

output "kms_key_ring" {
  description = "The KMS key ring"
  value       = var.kms_key_ring
}

output "common_labels" {
  description = "Common labels applied to resources"
  value       = var.common_labels
}
EOF
}

# Locals for common configuration
locals {
  # Environment detection
  environment = try(
    regex(".*environments/([^/]+).*", get_terragrunt_dir())[0],
    "default"
  )

  # Region detection with fallback to global
  region = try(
    regex(".*environments/[^/]+/([^/]+).*", get_terragrunt_dir())[1],
    "global"
  )

  # Zone detection with smart default
  zone = local.region != "global" ? "${local.region}-a" : null

  # Multi-zone configuration
  zones = local.region != "global" ? [
    "${local.region}-a",
    "${local.region}-b",
    "${local.region}-c"
  ] : []

  # Multi-region configuration
  multi_region = {
    enabled = local.environment == "prod"
    primary_region = local.region
    secondary_regions = local.environment == "prod" ? [
      "us-east1",
      "europe-west1",
      "asia-southeast1"
    ] : []
  }

  # Project configuration
  project_id     = get_env("GCP_PROJECT_ID_${upper(local.environment)}", get_env("GCP_PROJECT_ID", ""))
  project_name   = title("${local.environment} Project")
  project_number = get_env("GCP_PROJECT_NUMBER_${upper(local.environment)}", get_env("GCP_PROJECT_NUMBER", ""))

  # Organization configuration
  organization_id = get_env("GCP_ORG_ID", "")
  billing_account = get_env("GCP_BILLING_ACCOUNT", "")
  folder_id      = get_env("GCP_FOLDER_ID_${upper(local.environment)}", get_env("GCP_FOLDER_ID", ""))

  # Naming convention
  name_prefix = "${local.environment}-${local.region != "global" ? local.region : "glb"}"
  name_suffix = get_env("NAME_SUFFIX", "")

  resource_naming = {
    separator            = "-"
    use_random_suffix    = local.environment == "dev"
    random_suffix_length = 4
    include_environment  = true
    include_region      = local.region != "global"
  }

  # VPC configuration
  vpc_name = "${local.name_prefix}-vpc"

  # Network configuration by environment
  network_config = {
    dev = {
      cidr_base           = "10.10.0.0/16"
      enable_nat         = true
      enable_vpn         = false
      enable_interconnect = false
      enable_peering     = false
      network_tier       = "STANDARD"
    }
    staging = {
      cidr_base           = "10.20.0.0/16"
      enable_nat         = true
      enable_vpn         = true
      enable_interconnect = false
      enable_peering     = true
      network_tier       = "STANDARD"
    }
    prod = {
      cidr_base           = "10.0.0.0/16"
      enable_nat         = true
      enable_vpn         = true
      enable_interconnect = true
      enable_peering     = true
      network_tier       = "PREMIUM"
    }
  }

  # Subnet configuration
  subnet_config = {
    public = {
      cidr                    = cidrsubnet(local.network_config[local.environment].cidr_base, 4, 0)
      secondary_ranges        = {}
      private_google_access   = false
      private_ip_google_access = false
      flow_logs              = local.environment != "dev"
    }
    private = {
      cidr = cidrsubnet(local.network_config[local.environment].cidr_base, 4, 1)
      secondary_ranges = {
        pods     = cidrsubnet(local.network_config[local.environment].cidr_base, 4, 8)
        services = cidrsubnet(local.network_config[local.environment].cidr_base, 4, 9)
      }
      private_google_access   = true
      private_ip_google_access = true
      flow_logs              = true
    }
    database = {
      cidr                    = cidrsubnet(local.network_config[local.environment].cidr_base, 4, 2)
      secondary_ranges        = {}
      private_google_access   = true
      private_ip_google_access = true
      flow_logs              = true
    }
  }

  # Security configuration by environment
  security_config = {
    dev = {
      enable_vpc_flow_logs    = false
      enable_cloud_armor     = false
      enable_cloud_nat       = true
      enable_binary_auth     = false
      enable_vpc_sc         = false
      enable_private_google_access = true
      encryption_at_rest    = "google-managed"
      encryption_in_transit = "optional"
    }
    staging = {
      enable_vpc_flow_logs    = true
      enable_cloud_armor     = true
      enable_cloud_nat       = true
      enable_binary_auth     = true
      enable_vpc_sc         = false
      enable_private_google_access = true
      encryption_at_rest    = "cmek"
      encryption_in_transit = "required"
    }
    prod = {
      enable_vpc_flow_logs    = true
      enable_cloud_armor     = true
      enable_cloud_nat       = true
      enable_binary_auth     = true
      enable_vpc_sc         = true
      enable_private_google_access = true
      encryption_at_rest    = "cmek"
      encryption_in_transit = "required"
    }
  }

  # KMS configuration
  enable_cmek    = local.environment != "dev"
  kms_key_ring   = "${local.name_prefix}-keyring"
  kms_crypto_key = "${local.name_prefix}-key"

  # IAM configuration
  iam_config = {
    terraform_service_account = "terraform-${local.environment}@${local.project_id}.iam.gserviceaccount.com"

    admin_group = "gcp-${local.environment}-admins@company.com"
    developer_group = "gcp-${local.environment}-developers@company.com"
    readonly_group = "gcp-${local.environment}-readonly@company.com"

    enable_workload_identity = true
    enable_uniform_bucket_iam = true
    enable_domain_restricted_sharing = local.environment == "prod"
  }

  # Service account configuration
  service_account_config = {
    compute = {
      account_id   = "${local.name_prefix}-compute-sa"
      display_name = "Compute Service Account"
      description  = "Service account for compute resources"
      roles = [
        "roles/compute.instanceAdmin",
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter"
      ]
    }
    gke = {
      account_id   = "${local.name_prefix}-gke-sa"
      display_name = "GKE Service Account"
      description  = "Service account for GKE nodes"
      roles = [
        "roles/artifactregistry.reader",
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
        "roles/storage.objectViewer"
      ]
    }
    cloudsql = {
      account_id   = "${local.name_prefix}-sql-sa"
      display_name = "Cloud SQL Service Account"
      description  = "Service account for Cloud SQL instances"
      roles = [
        "roles/cloudsql.client",
        "roles/logging.logWriter"
      ]
    }
  }

  # Environment-specific configuration
  environment_config = {
    dev = {
      high_availability = false
      auto_scaling     = false
      backup_enabled   = false
      monitoring_level = "basic"
      sla_tier        = "none"
      change_window   = "anytime"
      retention_days  = 7
    }
    staging = {
      high_availability = true
      auto_scaling     = true
      backup_enabled   = true
      monitoring_level = "enhanced"
      sla_tier        = "standard"
      change_window   = "weekend"
      retention_days  = 30
    }
    prod = {
      high_availability = true
      auto_scaling     = true
      backup_enabled   = true
      monitoring_level = "comprehensive"
      sla_tier        = "premium"
      change_window   = "maintenance"
      retention_days  = 90
    }
  }

  # Monitoring configuration
  monitoring_config = {
    enable_monitoring = true
    enable_logging   = true
    enable_tracing   = local.environment != "dev"
    enable_profiling = local.environment == "prod"
    enable_debugging = local.environment == "dev"

    metrics_retention_days = local.environment == "prod" ? 180 : 30
    logs_retention_days   = local.environment == "prod" ? 90 : 30

    enable_uptime_checks = local.environment != "dev"
    enable_custom_metrics = true
    enable_slo_monitoring = local.environment == "prod"
  }

  # Logging configuration
  logging_config = {
    retention_days     = local.environment == "prod" ? 90 : 30
    include_audit_logs = local.environment != "dev"
    log_level         = local.environment == "dev" ? "DEBUG" : "INFO"
    sink_destinations = local.environment == "prod" ? ["bigquery", "storage", "pubsub"] : ["storage"]
  }

  # Alerting configuration
  alerting_config = {
    enabled = local.environment != "dev"
    notification_channels = local.environment == "prod" ?
      ["email", "sms", "slack", "pagerduty"] :
      ["email", "slack"]
    alert_policies = {
      cpu_utilization = {
        threshold = local.environment == "prod" ? 80 : 90
        duration  = "60s"
      }
      memory_utilization = {
        threshold = local.environment == "prod" ? 85 : 95
        duration  = "60s"
      }
      disk_utilization = {
        threshold = 90
        duration  = "120s"
      }
      error_rate = {
        threshold = local.environment == "prod" ? 0.01 : 0.05
        duration  = "60s"
      }
    }
  }

  # Backup configuration
  backup_config = {
    enabled = local.environment != "dev"
    schedule = local.environment == "prod" ? "0 */4 * * *" : "0 2 * * *"
    retention_days = local.environment == "prod" ? 90 : 30
    location = local.environment == "prod" ? "multi-region" : "regional"

    backup_types = {
      full = {
        frequency = local.environment == "prod" ? "daily" : "weekly"
        retention = local.environment == "prod" ? 30 : 7
      }
      incremental = {
        frequency = local.environment == "prod" ? "hourly" : "daily"
        retention = local.environment == "prod" ? 7 : 3
      }
      snapshot = {
        frequency = local.environment == "prod" ? "hourly" : "daily"
        retention = local.environment == "prod" ? 24 : 12
      }
    }
  }

  # Disaster Recovery configuration
  disaster_recovery_config = {
    enabled = local.environment == "prod"
    dr_region = local.environment == "prod" ? (
      local.region == "us-central1" ? "us-east1" :
      local.region == "europe-west1" ? "europe-west4" :
      local.region == "asia-southeast1" ? "asia-northeast1" :
      "us-central1"
    ) : ""
    rpo_minutes = local.environment == "prod" ? 15 : 1440
    rto_minutes = local.environment == "prod" ? 60 : 2880
    test_frequency = local.environment == "prod" ? "monthly" : "never"
  }

  # Budget configuration
  budget_config = {
    enabled = true
    amount = local.environment == "prod" ? 50000 : local.environment == "staging" ? 10000 : 5000
    currency = "USD"
    threshold_rules = local.environment == "prod" ? [
      { threshold_percent = 50, spend_basis = "CURRENT_SPEND" },
      { threshold_percent = 75, spend_basis = "CURRENT_SPEND" },
      { threshold_percent = 90, spend_basis = "CURRENT_SPEND" },
      { threshold_percent = 100, spend_basis = "CURRENT_SPEND" },
      { threshold_percent = 110, spend_basis = "CURRENT_SPEND" }
    ] : [
      { threshold_percent = 75, spend_basis = "CURRENT_SPEND" },
      { threshold_percent = 100, spend_basis = "CURRENT_SPEND" }
    ]
    notification_channels = local.environment == "prod" ?
      ["email", "pubsub", "webhook"] : ["email"]
  }

  # Cost optimization
  cost_optimization = {
    use_preemptible_vms = local.environment == "dev"
    use_committed_use_discounts = local.environment == "prod"
    enable_auto_shutdown = local.environment == "dev"
    enable_rightsizing = true
  }

  # Compliance configuration
  compliance_config = {
    frameworks = local.environment == "prod" ?
      ["SOC2", "ISO27001", "HIPAA", "PCI-DSS", "GDPR"] :
      local.environment == "staging" ? ["SOC2"] : []

    enable_audit_logs = local.environment != "dev"
    enable_data_residency = local.environment == "prod"
    data_residency_locations = local.environment == "prod" ?
      ["US", "EU"] : ["US"]

    enable_dlp = local.environment == "prod"
    enable_vpc_sc = local.environment == "prod"
    enable_binary_auth = local.environment != "dev"
    enable_container_analysis = local.environment != "dev"
  }

  # Data classification
  data_classification = local.environment == "prod" ? "restricted" :
                       local.environment == "staging" ? "confidential" : "internal"

  # Common labels
  common_labels = merge(
    {
      environment         = local.environment
      region             = local.region
      managed_by         = "terragrunt"
      team               = get_env("TEAM", "platform")
      cost_center        = get_env("COST_CENTER", "engineering")
      project            = local.project_id
      data_classification = local.data_classification
      created_by         = get_env("USER", "terragrunt")
      created_date       = formatdate("YYYY-MM-DD", timestamp())
      git_repo           = get_env("GITHUB_REPOSITORY", "terragrunt-gcp")
      git_branch         = get_env("GITHUB_REF_NAME", "main")
      git_commit         = get_env("GITHUB_SHA", "local")
      terraform_managed  = "true"
    },
    local.environment == "prod" ? {
      sla_tier         = "premium"
      backup_required  = "true"
      monitoring_level = "comprehensive"
      change_control   = "required"
      compliance_scope = "full"
    } : {},
    local.environment == "staging" ? {
      sla_tier         = "standard"
      backup_required  = "true"
      monitoring_level = "enhanced"
      change_control   = "recommended"
      compliance_scope = "limited"
    } : {
      sla_tier         = "none"
      backup_required  = "false"
      monitoring_level = "basic"
      change_control   = "optional"
      compliance_scope = "none"
    }
  )

  # Required labels that must be present
  required_labels = [
    "environment",
    "managed_by",
    "team",
    "cost_center",
    "data_classification"
  ]

  # Feature flags
  feature_flags = {
    enable_vpc_flow_logs = local.environment != "dev"
    enable_private_google_access = true
    enable_cloud_nat = true
    enable_cloud_armor = local.environment != "dev"
    enable_cloud_cdn = local.environment == "prod"
    enable_global_load_balancing = local.environment == "prod"
    enable_workload_identity = true
    enable_binary_authorization = local.environment != "dev"
    enable_container_analysis = local.environment != "dev"
    enable_vulnerability_scanning = local.environment != "dev"
    enable_secret_manager = true
    enable_kms = local.environment != "dev"
    enable_dlp = local.environment == "prod"
    enable_vpc_service_controls = local.environment == "prod"
    enable_private_service_connect = local.environment != "dev"
    enable_shared_vpc = local.environment == "prod"
    enable_gke_autopilot = local.environment == "prod"
    enable_anthos = local.environment == "prod"
    enable_service_mesh = local.environment == "prod"
    enable_api_gateway = local.environment != "dev"
    enable_cloud_run = true
    enable_cloud_functions = true
    enable_cloud_build = true
    enable_artifact_registry = true
    enable_cloud_deploy = local.environment != "dev"
    enable_cloud_composer = local.environment != "dev"
    enable_dataflow = local.environment != "dev"
    enable_dataproc = local.environment != "dev"
    enable_bigquery = true
    enable_pubsub = true
    enable_cloud_sql = true
    enable_firestore = true
    enable_memorystore = local.environment != "dev"
    enable_cloud_spanner = local.environment == "prod"
    enable_bigtable = local.environment == "prod"
  }

  # Required APIs
  required_apis = concat(
    [
      # Core APIs always needed
      "cloudresourcemanager.googleapis.com",
      "serviceusage.googleapis.com",
      "iam.googleapis.com",
      "compute.googleapis.com",
      "storage.googleapis.com",
      "logging.googleapis.com",
      "monitoring.googleapis.com"
    ],
    local.environment != "dev" ? [
      # Additional APIs for non-dev
      "container.googleapis.com",
      "cloudkms.googleapis.com",
      "secretmanager.googleapis.com",
      "cloudbuild.googleapis.com",
      "artifactregistry.googleapis.com",
      "run.googleapis.com",
      "cloudfunctions.googleapis.com",
      "pubsub.googleapis.com",
      "bigquery.googleapis.com",
      "sql-component.googleapis.com",
      "sqladmin.googleapis.com",
      "redis.googleapis.com",
      "firestore.googleapis.com"
    ] : [],
    local.environment == "prod" ? [
      # Additional APIs for production
      "binaryauthorization.googleapis.com",
      "containeranalysis.googleapis.com",
      "containerscanning.googleapis.com",
      "dlp.googleapis.com",
      "accesscontextmanager.googleapis.com",
      "cloudtrace.googleapis.com",
      "cloudprofiler.googleapis.com",
      "clouddebugger.googleapis.com",
      "clouderrorreporting.googleapis.com",
      "servicenetworking.googleapis.com",
      "vpcaccess.googleapis.com",
      "networkmanagement.googleapis.com",
      "networksecurity.googleapis.com",
      "certificatemanager.googleapis.com",
      "networkservices.googleapis.com",
      "trafficdirector.googleapis.com",
      "anthos.googleapis.com",
      "anthosconfigmanagement.googleapis.com",
      "gkehub.googleapis.com",
      "mesh.googleapis.com",
      "apigateway.googleapis.com",
      "servicecontrol.googleapis.com",
      "endpoints.googleapis.com",
      "clouddeploy.googleapis.com",
      "composer.googleapis.com",
      "dataflow.googleapis.com",
      "dataproc.googleapis.com",
      "datacatalog.googleapis.com",
      "dataplex.googleapis.com",
      "spanner.googleapis.com",
      "bigtableadmin.googleapis.com"
    ] : []
  )

  # Maintenance window
  maintenance_window = {
    day = local.environment == "prod" ? 7 : 6  # Sunday for prod, Saturday otherwise
    hour = local.environment == "prod" ? 2 : 3  # 2 AM for prod, 3 AM otherwise
    duration = "4h"
    update_track = local.environment == "prod" ? "stable" : "regular"
  }

  # Quota limits
  quota_limits = {
    max_instances = local.environment == "prod" ? 1000 : local.environment == "staging" ? 100 : 50
    max_cpus = local.environment == "prod" ? 5000 : local.environment == "staging" ? 500 : 100
    max_memory_gb = local.environment == "prod" ? 20000 : local.environment == "staging" ? 2000 : 400
    max_disk_gb = local.environment == "prod" ? 100000 : local.environment == "staging" ? 10000 : 1000
    max_addresses = local.environment == "prod" ? 100 : local.environment == "staging" ? 20 : 10
    max_load_balancers = local.environment == "prod" ? 50 : local.environment == "staging" ? 10 : 5
  }

  # Performance configuration
  performance_config = {
    enable_cdn = local.environment == "prod"
    enable_cache = true
    cache_ttl_seconds = local.environment == "prod" ? 3600 : 600

    enable_compression = true
    compression_level = local.environment == "prod" ? 9 : 6

    enable_http2 = true
    enable_quic = local.environment == "prod"

    connection_draining_timeout = local.environment == "prod" ? 300 : 30
    session_affinity = local.environment == "prod" ? "CLIENT_IP" : "NONE"

    enable_autohealing = local.environment != "dev"
    health_check_interval = local.environment == "prod" ? 10 : 30

    enable_autoscaling = local.environment != "dev"
    min_replicas = local.environment == "prod" ? 3 : 1
    max_replicas = local.environment == "prod" ? 100 : 10
    target_cpu_utilization = local.environment == "prod" ? 60 : 80
  }

  # Automation configuration
  automation_config = {
    enable_auto_remediation = local.environment == "prod"
    enable_auto_scaling = local.environment != "dev"
    enable_auto_backup = local.environment != "dev"
    enable_auto_update = local.environment == "dev"
  }

  # Integration configuration
  integration_config = {
    github = {
      enabled = true
      org = get_env("GITHUB_ORG", "company")
      repo = get_env("GITHUB_REPOSITORY", "terragrunt-gcp")
    }

    slack = {
      enabled = local.environment != "dev"
      webhook_url = get_env("SLACK_WEBHOOK_URL", "")
      channel = local.environment == "prod" ? "#prod-alerts" : "#staging-alerts"
    }

    pagerduty = {
      enabled = local.environment == "prod"
      integration_key = get_env("PAGERDUTY_KEY", "")
      service_id = get_env("PAGERDUTY_SERVICE_ID", "")
    }

    datadog = {
      enabled = local.environment == "prod"
      api_key = get_env("DATADOG_API_KEY", "")
      app_key = get_env("DATADOG_APP_KEY", "")
    }

    prometheus = {
      enabled = local.environment != "dev"
      endpoint = get_env("PROMETHEUS_ENDPOINT", "")
    }

    grafana = {
      enabled = local.environment != "dev"
      endpoint = get_env("GRAFANA_ENDPOINT", "")
    }
  }
}