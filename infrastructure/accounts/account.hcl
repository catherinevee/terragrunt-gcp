# Account-level configuration

locals {
  # Organization details
  organization = "acme"  # Change this to your organization name
  
  # GCP Account/Project configuration
  project_id = get_env("GCP_PROJECT_ID", "acme-platform-prod")
  
  # Billing account
  billing_account = get_env("GCP_BILLING_ACCOUNT", "")
  
  # Organization ID (if using organization-level resources)
  org_id = get_env("GCP_ORG_ID", "")
  
  # Default settings
  default_region = "europe-west1"
  default_zone   = "europe-west1-b"
  
  # Account-wide labels
  account_labels = {
    organization = local.organization
    cost_center  = "platform"
    team         = "infrastructure"
  }
  
  # Service account for Terraform/Terragrunt operations
  terraform_service_account = "terraform@${local.project_id}.iam.gserviceaccount.com"
  
  # Enable APIs list
  enabled_apis = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "run.googleapis.com",
    "cloudfunctions.googleapis.com",
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com",
    "pubsub.googleapis.com",
    "redis.googleapis.com",
    "servicenetworking.googleapis.com",
    "vpcaccess.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudbilling.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudasset.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudtasks.googleapis.com"
  ]
  
  # Notification channels for alerts
  notification_channels = {
    email = get_env("ALERT_EMAIL", "platform-team@acme.com")
    slack = get_env("SLACK_WEBHOOK", "")
  }
  
  # Cost management
  budget_alert_thresholds = [0.5, 0.75, 0.9, 1.0, 1.2]
  
  # Compliance and governance
  compliance_standards = ["cis", "pci-dss", "hipaa"]
  
  # Data residency requirements (European regions)
  allowed_regions = [
    "europe-west1",  # Belgium
    "europe-west2",  # London
    "europe-west3",  # Frankfurt
    "europe-west4",  # Netherlands
    "europe-north1", # Finland
    "europe-central2" # Warsaw
  ]
}