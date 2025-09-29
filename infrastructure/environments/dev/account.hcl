# Development Account Configuration
# Contains account-level settings for development environment

locals {
  account_name = "development"
  account_id   = "dev-account-001"

  # GCP project configuration
  project_id     = get_env("GCP_PROJECT_ID", "my-dev-project")
  project_name   = "Development Project"
  project_number = get_env("GCP_PROJECT_NUMBER", "123456789012")

  # Organization settings
  organization_id = get_env("GCP_ORG_ID", "123456789")
  billing_account = get_env("GCP_BILLING_ACCOUNT", "01ABCD-23EFGH-45IJKL")

  # Default regions and zones
  default_regions = ["us-central1", "us-east1", "europe-west1"]
  default_zones   = ["us-central1-a", "us-central1-b", "us-central1-c"]

  # Account-wide labels
  account_labels = {
    environment    = "development"
    managed_by     = "terragrunt"
    cost_center    = "engineering"
    compliance     = "none"
    data_classification = "internal"
  }

  # Account-wide IAM settings
  admin_users = [
    "admin@example.com",
    "devops@example.com"
  ]

  developer_users = [
    "dev1@example.com",
    "dev2@example.com",
    "dev3@example.com"
  ]

  # Service account configuration
  terraform_service_account = "terraform@${local.project_id}.iam.gserviceaccount.com"

  # API services to enable
  required_apis = [
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "iam.googleapis.com",
    "compute.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudkms.googleapis.com",
    "secretmanager.googleapis.com"
  ]

  # Security settings
  security_config = {
    enable_vpc_flow_logs          = true
    enable_cloud_armor           = false
    enable_private_google_access = true
    enable_cloud_nat             = true
    require_ssl                  = false
    enable_binary_authorization  = false
  }

  # Cost management
  budget_config = {
    budget_amount   = 5000
    budget_currency = "USD"
    alert_thresholds = [0.5, 0.75, 0.9, 1.0]
    notification_channels = ["budget-alerts@example.com"]
  }

  # Backup and DR settings
  backup_config = {
    enable_backups        = true
    backup_retention_days = 7
    backup_schedule       = "0 2 * * *"
    backup_location       = "us-central1"
  }
}