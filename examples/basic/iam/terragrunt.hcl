# Basic IAM configuration
# Creates service accounts and IAM bindings for compute instances

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/security/iam"
}

inputs = {
  # Project ID
  project_id = get_env("GCP_PROJECT_ID")

  # Service accounts to create
  service_accounts = [
    {
      account_id   = "compute-instance-sa"
      display_name = "Compute Instance Service Account"
      description  = "Service account for compute instances in basic example"
      disabled     = false
    }
  ]

  # Custom roles (if needed)
  custom_roles = [
    {
      role_id     = "basic_compute_operator"
      title       = "Basic Compute Operator"
      description = "Custom role for basic compute operations"
      stage       = "GA"
      permissions = [
        "compute.instances.get",
        "compute.instances.list",
        "compute.instances.start",
        "compute.instances.stop",
        "logging.logEntries.create",
        "monitoring.metricDescriptors.get",
        "monitoring.metricDescriptors.list",
        "monitoring.timeSeries.create"
      ]
    }
  ]

  # IAM policy bindings
  iam_bindings = [
    # Grant the compute service account basic monitoring permissions
    {
      role    = "roles/monitoring.metricWriter"
      members = ["serviceAccount:compute-instance-sa@${get_env("GCP_PROJECT_ID")}.iam.gserviceaccount.com"]
    },
    {
      role    = "roles/logging.logWriter"
      members = ["serviceAccount:compute-instance-sa@${get_env("GCP_PROJECT_ID")}.iam.gserviceaccount.com"]
    },
    # Grant custom role
    {
      role    = "projects/${get_env("GCP_PROJECT_ID")}/roles/basic_compute_operator"
      members = ["serviceAccount:compute-instance-sa@${get_env("GCP_PROJECT_ID")}.iam.gserviceaccount.com"]
    }
  ]

  # Conditional IAM bindings (for advanced scenarios)
  conditional_bindings = []

  # Service account keys (use sparingly, prefer workload identity)
  service_account_keys = []

  # Workload identity bindings (for GKE workloads)
  workload_identity_bindings = []

  # Labels for resource organization
  labels = {
    environment = "development"
    project     = "basic-example"
    team        = "devops"
    managed_by  = "terragrunt"
  }

  # IAM audit configuration
  audit_config = {
    service = "allServices"
    audit_log_configs = [
      {
        log_type         = "ADMIN_READ"
        exempted_members = []
      },
      {
        log_type         = "DATA_READ"
        exempted_members = []
      },
      {
        log_type         = "DATA_WRITE"
        exempted_members = []
      }
    ]
  }
}