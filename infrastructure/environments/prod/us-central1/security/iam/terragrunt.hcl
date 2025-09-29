# IAM (Identity and Access Management) Configuration for Production - US Central 1
# Enterprise-grade IAM with service accounts, workload identity, custom roles, and organization policies

terraform {
  source = "${get_repo_root()}/modules/security/iam"
}

# Include root configuration
include "root" {
  path = find_in_parent_folders()
}

# Include environment configuration
include "env" {
  path = find_in_parent_folders("env.hcl")
  expose = true
}

# Include region configuration
include "region" {
  path = find_in_parent_folders("region.hcl")
  expose = true
}

# IAM depends on KMS for encryption
dependency "kms" {
  config_path = "../kms"
  skip_outputs = true
  mock_outputs = {
    keyring_id = "mock-keyring-id"
    keys = {
      default = {
        id = "mock-key-id"
        self_link = "projects/mock-project/locations/us-central1/keyRings/mock-keyring/cryptoKeys/mock-key"
      }
    }
  }
}

# Prevent accidental destruction of production IAM resources
prevent_destroy = true

locals {
  # Extract configuration from includes
  env_config    = include.env.locals
  region_config = include.region.locals

  # Service account naming convention
  sa_prefix = "${local.env_config.environment}-${local.region_config.region_short}"

  # Service Accounts Configuration
  service_accounts = {
    # Terraform service account
    terraform = {
      account_id   = "${local.sa_prefix}-terraform-sa"
      display_name = "Terraform Service Account - ${local.env_config.environment}"
      description  = "Service account for Terraform deployments in ${local.env_config.environment}"

      iam_bindings = {
        "roles/iam.serviceAccountUser" = [
          "group:platform-team@${local.env_config.organization_domain}"
        ]
        "roles/iam.serviceAccountTokenCreator" = [
          "group:ci-cd@${local.env_config.organization_domain}"
        ]
      }

      keys = {
        rotation_period_days = 90
        key_algorithm = "KEY_ALG_RSA_2048"
        public_key_type = "TYPE_X509_PEM_FILE"
      }

      labels = {
        purpose = "infrastructure"
        managed_by = "terragrunt"
      }
    }

    # GKE workload identity service account
    gke_workload = {
      account_id   = "${local.sa_prefix}-gke-workload-sa"
      display_name = "GKE Workload Identity Service Account"
      description  = "Service account for GKE workload identity in ${local.env_config.environment}"

      iam_bindings = {
        "roles/iam.workloadIdentityUser" = [
          "serviceAccount:${var.project_id}.svc.id.goog[default/default]",
          "serviceAccount:${var.project_id}.svc.id.goog[production/backend]",
          "serviceAccount:${var.project_id}.svc.id.goog[production/frontend]"
        ]
      }

      workload_identity_config = {
        kubernetes_namespace = "production"
        kubernetes_service_account = "default"
      }

      labels = {
        purpose = "gke"
        workload_identity = "enabled"
      }
    }

    # Cloud Run service account
    cloud_run = {
      account_id   = "${local.sa_prefix}-cloud-run-sa"
      display_name = "Cloud Run Service Account"
      description  = "Service account for Cloud Run services in ${local.env_config.environment}"

      iam_bindings = {
        "roles/run.invoker" = [
          "allUsers"  # For public endpoints, restrict as needed
        ]
      }

      labels = {
        purpose = "cloud-run"
        serverless = "true"
      }
    }

    # Cloud SQL service account
    cloud_sql = {
      account_id   = "${local.sa_prefix}-cloud-sql-sa"
      display_name = "Cloud SQL Service Account"
      description  = "Service account for Cloud SQL instances in ${local.env_config.environment}"

      iam_bindings = {
        "roles/cloudsql.client" = [
          "serviceAccount:${local.sa_prefix}-gke-workload-sa@${var.project_id}.iam.gserviceaccount.com",
          "serviceAccount:${local.sa_prefix}-cloud-run-sa@${var.project_id}.iam.gserviceaccount.com"
        ]
      }

      labels = {
        purpose = "database"
        service = "cloud-sql"
      }
    }

    # BigQuery service account
    bigquery = {
      account_id   = "${local.sa_prefix}-bigquery-sa"
      display_name = "BigQuery Service Account"
      description  = "Service account for BigQuery operations in ${local.env_config.environment}"

      iam_bindings = {
        "roles/bigquery.jobUser" = [
          "serviceAccount:${local.sa_prefix}-dataflow-sa@${var.project_id}.iam.gserviceaccount.com"
        ]
      }

      labels = {
        purpose = "analytics"
        service = "bigquery"
      }
    }

    # Dataflow service account
    dataflow = {
      account_id   = "${local.sa_prefix}-dataflow-sa"
      display_name = "Dataflow Service Account"
      description  = "Service account for Dataflow jobs in ${local.env_config.environment}"

      labels = {
        purpose = "data-processing"
        service = "dataflow"
      }
    }

    # Cloud Functions service account
    cloud_functions = {
      account_id   = "${local.sa_prefix}-cloud-functions-sa"
      display_name = "Cloud Functions Service Account"
      description  = "Service account for Cloud Functions in ${local.env_config.environment}"

      iam_bindings = {
        "roles/cloudfunctions.invoker" = local.env_config.environment == "prod" ? [
          "serviceAccount:${local.sa_prefix}-scheduler-sa@${var.project_id}.iam.gserviceaccount.com"
        ] : ["allUsers"]
      }

      labels = {
        purpose = "serverless"
        service = "cloud-functions"
      }
    }

    # Pub/Sub service account
    pubsub = {
      account_id   = "${local.sa_prefix}-pubsub-sa"
      display_name = "Pub/Sub Service Account"
      description  = "Service account for Pub/Sub operations in ${local.env_config.environment}"

      iam_bindings = {
        "roles/pubsub.publisher" = [
          "serviceAccount:${local.sa_prefix}-cloud-functions-sa@${var.project_id}.iam.gserviceaccount.com"
        ]
        "roles/pubsub.subscriber" = [
          "serviceAccount:${local.sa_prefix}-dataflow-sa@${var.project_id}.iam.gserviceaccount.com"
        ]
      }

      labels = {
        purpose = "messaging"
        service = "pubsub"
      }
    }

    # Cloud Scheduler service account
    scheduler = {
      account_id   = "${local.sa_prefix}-scheduler-sa"
      display_name = "Cloud Scheduler Service Account"
      description  = "Service account for Cloud Scheduler jobs in ${local.env_config.environment}"

      labels = {
        purpose = "automation"
        service = "scheduler"
      }
    }

    # Monitoring service account
    monitoring = {
      account_id   = "${local.sa_prefix}-monitoring-sa"
      display_name = "Monitoring Service Account"
      description  = "Service account for monitoring and alerting in ${local.env_config.environment}"

      iam_bindings = {
        "roles/monitoring.metricWriter" = [
          "serviceAccount:${local.sa_prefix}-gke-workload-sa@${var.project_id}.iam.gserviceaccount.com"
        ]
      }

      labels = {
        purpose = "observability"
        service = "monitoring"
      }
    }

    # Backup service account
    backup = {
      account_id   = "${local.sa_prefix}-backup-sa"
      display_name = "Backup Service Account"
      description  = "Service account for backup operations in ${local.env_config.environment}"

      iam_bindings = {
        "roles/storage.objectAdmin" = [
          "serviceAccount:${var.terraform_service_account}"
        ]
      }

      labels = {
        purpose = "backup"
        critical = "true"
      }
    }

    # CI/CD service account
    cicd = {
      account_id   = "${local.sa_prefix}-cicd-sa"
      display_name = "CI/CD Service Account"
      description  = "Service account for CI/CD pipelines in ${local.env_config.environment}"

      iam_bindings = {
        "roles/cloudbuild.builds.editor" = [
          "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com"
        ]
      }

      labels = {
        purpose = "automation"
        service = "cicd"
      }
    }

    # Security scanner service account
    security_scanner = {
      account_id   = "${local.sa_prefix}-security-scanner-sa"
      display_name = "Security Scanner Service Account"
      description  = "Service account for security scanning in ${local.env_config.environment}"

      iam_bindings = {
        "roles/securitycenter.findingsViewer" = [
          "group:security-team@${local.env_config.organization_domain}"
        ]
      }

      labels = {
        purpose = "security"
        service = "scanner"
      }
    }
  }

  # Custom IAM Roles
  custom_roles = {
    # Developer role with limited permissions
    developer = {
      role_id     = "${local.env_config.environment}_developer_role"
      title       = "${title(local.env_config.environment)} Developer Role"
      description = "Custom role for developers in ${local.env_config.environment}"
      stage       = "GA"

      permissions = [
        # Compute
        "compute.instances.get",
        "compute.instances.list",
        "compute.instances.start",
        "compute.instances.stop",
        "compute.instances.reset",

        # Storage
        "storage.buckets.get",
        "storage.buckets.list",
        "storage.objects.create",
        "storage.objects.delete",
        "storage.objects.get",
        "storage.objects.list",
        "storage.objects.update",

        # Cloud SQL
        "cloudsql.instances.get",
        "cloudsql.instances.list",
        "cloudsql.databases.get",
        "cloudsql.databases.list",

        # Logging
        "logging.logEntries.list",
        "logging.logs.list",
        "logging.privateLogEntries.list",

        # Monitoring
        "monitoring.metricDescriptors.get",
        "monitoring.metricDescriptors.list",
        "monitoring.timeSeries.list",

        # Cloud Run
        "run.services.get",
        "run.services.list",
        "run.routes.get",
        "run.routes.list"
      ]
    }

    # SRE role with operational permissions
    sre = {
      role_id     = "${local.env_config.environment}_sre_role"
      title       = "${title(local.env_config.environment)} SRE Role"
      description = "Custom role for SRE team in ${local.env_config.environment}"
      stage       = "GA"

      permissions = [
        # All developer permissions
        "compute.instances.*",
        "compute.disks.*",
        "compute.snapshots.*",

        # Kubernetes Engine
        "container.clusters.get",
        "container.clusters.list",
        "container.clusters.update",
        "container.nodes.*",
        "container.pods.*",
        "container.services.*",

        # Load Balancing
        "compute.backendServices.*",
        "compute.healthChecks.*",
        "compute.targetPools.*",

        # Monitoring and Logging
        "monitoring.*",
        "logging.*",

        # Cloud SQL Admin
        "cloudsql.*",

        # Networking
        "compute.networks.get",
        "compute.networks.list",
        "compute.subnetworks.get",
        "compute.subnetworks.list",
        "compute.firewalls.get",
        "compute.firewalls.list"
      ]
    }

    # Data Engineer role
    data_engineer = {
      role_id     = "${local.env_config.environment}_data_engineer_role"
      title       = "${title(local.env_config.environment)} Data Engineer Role"
      description = "Custom role for data engineers in ${local.env_config.environment}"
      stage       = "GA"

      permissions = [
        # BigQuery
        "bigquery.*",

        # Dataflow
        "dataflow.*",

        # Pub/Sub
        "pubsub.*",

        # Storage
        "storage.buckets.*",
        "storage.objects.*",

        # Dataproc
        "dataproc.clusters.*",
        "dataproc.jobs.*",
        "dataproc.operations.*",

        # Cloud Composer
        "composer.environments.get",
        "composer.environments.list",
        "composer.operations.get",
        "composer.operations.list"
      ]
    }

    # Security Auditor role
    security_auditor = {
      role_id     = "${local.env_config.environment}_security_auditor_role"
      title       = "${title(local.env_config.environment)} Security Auditor Role"
      description = "Custom role for security auditors in ${local.env_config.environment}"
      stage       = "GA"

      permissions = [
        # IAM
        "iam.roles.get",
        "iam.roles.list",
        "iam.serviceAccounts.get",
        "iam.serviceAccounts.list",
        "iam.serviceAccountKeys.list",

        # Resource Manager
        "resourcemanager.projects.get",
        "resourcemanager.projects.getIamPolicy",

        # Security Center
        "securitycenter.*",

        # Cloud KMS
        "cloudkms.cryptoKeys.get",
        "cloudkms.cryptoKeys.list",
        "cloudkms.keyRings.get",
        "cloudkms.keyRings.list",

        # VPC Service Controls
        "accesscontextmanager.*",

        # Binary Authorization
        "binaryauthorization.*",

        # Cloud Armor
        "compute.securityPolicies.get",
        "compute.securityPolicies.list"
      ]
    }

    # Cost Administrator role
    cost_admin = {
      role_id     = "${local.env_config.environment}_cost_admin_role"
      title       = "${title(local.env_config.environment)} Cost Administrator Role"
      description = "Custom role for cost management in ${local.env_config.environment}"
      stage       = "GA"

      permissions = [
        # Billing
        "billing.accounts.get",
        "billing.accounts.list",
        "billing.budgets.*",
        "billing.credits.*",

        # Recommender
        "recommender.computeInstanceGroupManagerMachineTypeRecommendations.*",
        "recommender.computeInstanceMachineTypeRecommendations.*",
        "recommender.computeInstanceIdleResourceRecommendations.*",

        # Cost Management
        "billing.accounts.getSpendingInformation",
        "billing.accounts.getUsageExportSpec",
        "billing.resourceCosts.get",

        # Committed Use Discounts
        "compute.commitments.get",
        "compute.commitments.list"
      ]
    }
  }

  # Project-level IAM bindings
  project_iam_bindings = {
    # Viewer role
    "roles/viewer" = [
      "group:all-users@${local.env_config.organization_domain}"
    ]

    # Editor role (restricted in production)
    "roles/editor" = local.env_config.environment == "prod" ? [] : [
      "group:developers@${local.env_config.organization_domain}"
    ]

    # Owner role (highly restricted)
    "roles/owner" = [
      "group:platform-admins@${local.env_config.organization_domain}"
    ]

    # Security Admin
    "roles/securityAdmin" = [
      "group:security-team@${local.env_config.organization_domain}"
    ]

    # Network Admin
    "roles/compute.networkAdmin" = [
      "group:network-team@${local.env_config.organization_domain}"
    ]

    # Storage Admin
    "roles/storage.admin" = [
      "group:storage-admins@${local.env_config.organization_domain}",
      "serviceAccount:${local.sa_prefix}-backup-sa@${var.project_id}.iam.gserviceaccount.com"
    ]

    # BigQuery Admin
    "roles/bigquery.admin" = [
      "group:data-team@${local.env_config.organization_domain}"
    ]

    # GKE Admin
    "roles/container.admin" = [
      "group:platform-team@${local.env_config.organization_domain}"
    ]

    # Cloud SQL Admin
    "roles/cloudsql.admin" = [
      "group:database-admins@${local.env_config.organization_domain}"
    ]

    # Monitoring Admin
    "roles/monitoring.admin" = [
      "group:sre-team@${local.env_config.organization_domain}"
    ]

    # Logging Admin
    "roles/logging.admin" = [
      "group:sre-team@${local.env_config.organization_domain}"
    ]

    # Service Account Admin
    "roles/iam.serviceAccountAdmin" = [
      "group:security-team@${local.env_config.organization_domain}"
    ]

    # Custom roles
    "projects/${var.project_id}/roles/${local.env_config.environment}_developer_role" = [
      "group:developers@${local.env_config.organization_domain}"
    ]

    "projects/${var.project_id}/roles/${local.env_config.environment}_sre_role" = [
      "group:sre-team@${local.env_config.organization_domain}"
    ]

    "projects/${var.project_id}/roles/${local.env_config.environment}_data_engineer_role" = [
      "group:data-team@${local.env_config.organization_domain}"
    ]

    "projects/${var.project_id}/roles/${local.env_config.environment}_security_auditor_role" = [
      "group:security-auditors@${local.env_config.organization_domain}"
    ]

    "projects/${var.project_id}/roles/${local.env_config.environment}_cost_admin_role" = [
      "group:finance-team@${local.env_config.organization_domain}"
    ]
  }

  # Workload Identity Pool configuration (for external identity providers)
  workload_identity_pools = local.env_config.environment == "prod" ? {
    github_actions = {
      pool_id     = "${local.env_config.environment}-github-actions-pool"
      display_name = "GitHub Actions Workload Identity Pool"
      description  = "Workload identity pool for GitHub Actions CI/CD"
      disabled     = false

      providers = {
        github = {
          provider_id = "github-provider"
          display_name = "GitHub Provider"
          description = "OIDC provider for GitHub Actions"

          oidc = {
            issuer_uri = "https://token.actions.githubusercontent.com"
            allowed_audiences = ["https://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/${local.env_config.environment}-github-actions-pool/providers/github-provider"]
          }

          attribute_mapping = {
            "google.subject" = "assertion.sub"
            "attribute.repository" = "assertion.repository"
            "attribute.repository_owner" = "assertion.repository_owner"
            "attribute.ref" = "assertion.ref"
          }

          attribute_condition = "assertion.repository_owner == '${local.env_config.organization_name}'"
        }
      }
    }

    aws = {
      pool_id     = "${local.env_config.environment}-aws-pool"
      display_name = "AWS Workload Identity Pool"
      description  = "Workload identity pool for AWS integration"
      disabled     = false

      providers = {
        aws = {
          provider_id = "aws-provider"
          display_name = "AWS Provider"
          description = "AWS provider for cross-cloud integration"

          aws = {
            account_id = get_env("AWS_ACCOUNT_ID", "")
            sts_audience = ["iam.googleapis.com"]
          }

          attribute_mapping = {
            "google.subject" = "assertion.arn"
            "attribute.aws_role" = "assertion.arn.extract(\"assumed-role/{role}/\")"
            "attribute.aws_account" = "assertion.account"
          }

          attribute_condition = "attribute.aws_account == '${get_env("AWS_ACCOUNT_ID", "")}'"
        }
      }
    }

    azure = {
      pool_id     = "${local.env_config.environment}-azure-pool"
      display_name = "Azure Workload Identity Pool"
      description  = "Workload identity pool for Azure integration"
      disabled     = true  # Enable when needed

      providers = {
        azure = {
          provider_id = "azure-provider"
          display_name = "Azure Provider"
          description = "Azure AD provider for cross-cloud integration"

          oidc = {
            issuer_uri = "https://login.microsoftonline.com/${get_env("AZURE_TENANT_ID", "")}/v2.0"
            allowed_audiences = ["api://AzureADTokenExchange"]
          }

          attribute_mapping = {
            "google.subject" = "assertion.sub"
            "attribute.azure_tenant" = "assertion.tid"
            "attribute.azure_app" = "assertion.appid"
          }
        }
      }
    }
  } : {}

  # Conditional IAM bindings based on environment
  conditional_bindings = {
    time_based_access = {
      role = "roles/compute.instanceAdmin"
      members = ["group:oncall@${local.env_config.organization_domain}"]
      condition = {
        title = "Time-based access for on-call"
        description = "Grant access only during business hours"
        expression = "request.time.getHours(\"America/New_York\") >= 9 && request.time.getHours(\"America/New_York\") <= 17"
      }
    }

    resource_based_access = {
      role = "roles/compute.instanceAdmin"
      members = ["group:contractors@${local.env_config.organization_domain}"]
      condition = {
        title = "Resource-based access"
        description = "Grant access only to specific resources"
        expression = "resource.name.startsWith(\"projects/${var.project_id}/zones/us-central1-a/instances/dev-\")"
      }
    }

    ip_based_access = local.env_config.environment == "prod" ? {
      role = "roles/viewer"
      members = ["group:external-auditors@${local.env_config.organization_domain}"]
      condition = {
        title = "IP-based access restriction"
        description = "Allow access only from office IP ranges"
        expression = "request.auth.access_levels.in([\"projects/${var.project_number}/accessPolicies/policy/accessLevels/office_ips\"])"
      }
    } : null
  }

  # IAM policy constraints
  policy_constraints = {
    # Restrict service account key creation
    restrict_sa_key_creation = {
      constraint = "iam.disableServiceAccountKeyCreation"
      enforce = local.env_config.environment == "prod"
    }

    # Restrict service account key upload
    restrict_sa_key_upload = {
      constraint = "iam.disableServiceAccountKeyUpload"
      enforce = true
    }

    # Require specific key algorithms
    allowed_key_algorithms = {
      constraint = "iam.allowedPolicyMemberDomains"
      allow = ["KEY_ALG_RSA_2048", "KEY_ALG_RSA_4096"]
    }

    # Audit logging requirements
    audit_log_configs = {
      log_type = "DATA_READ"
      exempted_members = []
    }

    # Restrict cross-project service account usage
    restrict_cross_project_sa = {
      constraint = "iam.disableCrossProjectServiceAccountUsage"
      enforce = local.env_config.environment == "prod"
    }
  }

  # IAM monitoring and alerting
  iam_monitoring = {
    alerts = {
      excessive_permission_grants = {
        display_name = "Excessive IAM Permission Grants"
        conditions = {
          threshold_count = 10
          duration = "300s"
        }
      }

      service_account_key_creation = {
        display_name = "Service Account Key Created"
        conditions = {
          alert_immediately = true
        }
      }

      privileged_role_assignment = {
        display_name = "Privileged Role Assignment"
        conditions = {
          roles = ["roles/owner", "roles/editor", "roles/iam.securityAdmin"]
          alert_immediately = true
        }
      }

      external_user_access = {
        display_name = "External User Access Granted"
        conditions = {
          domain_filter = "@${local.env_config.organization_domain}"
          alert_on_mismatch = true
        }
      }
    }

    # Metrics to track
    metrics = {
      iam_policy_changes = {
        metric = "iam.googleapis.com/policy/changes_count"
        aggregation = "ALIGN_RATE"
      }
      service_account_usage = {
        metric = "iam.googleapis.com/service_account/authn_events_count"
        aggregation = "ALIGN_RATE"
      }
    }
  }

  # Access Context Manager configuration (VPC Service Controls)
  access_context_manager = local.env_config.environment == "prod" ? {
    access_policy = {
      title = "${local.env_config.environment} Access Policy"
      scopes = ["projects/${var.project_number}"]
    }

    access_levels = {
      office_ips = {
        title = "Office IP Addresses"
        description = "Access from office IP ranges"
        basic = {
          conditions = [{
            ip_subnetworks = [
              "203.0.113.0/24",  # Replace with actual office IPs
              "198.51.100.0/24"
            ]
          }]
        }
      }

      trusted_devices = {
        title = "Trusted Devices"
        description = "Access from corp-managed devices"
        basic = {
          conditions = [{
            device_policy = {
              require_screen_lock = true
              require_admin_approval = true
              allowed_encryption_statuses = ["ENCRYPTED"]
              os_constraints = [{
                os_type = "DESKTOP_CHROME_OS"
                require_verified_chrome_os = true
              }]
            }
          }]
        }
      }

      mfa_required = {
        title = "MFA Required"
        description = "Multi-factor authentication required"
        custom = {
          expr = {
            expression = "request.auth.claims[\"mfa\"] == true"
            title = "MFA Check"
          }
        }
      }
    }

    service_perimeters = {
      main = {
        title = "${local.env_config.environment} Main Perimeter"
        description = "Main VPC Service Control perimeter"

        status = {
          resources = ["projects/${var.project_number}"]

          restricted_services = [
            "storage.googleapis.com",
            "bigquery.googleapis.com",
            "bigtable.googleapis.com",
            "cloudkms.googleapis.com",
            "pubsub.googleapis.com",
            "spanner.googleapis.com",
            "sqladmin.googleapis.com",
            "healthcare.googleapis.com",
            "secretmanager.googleapis.com"
          ]

          access_levels = ["office_ips", "trusted_devices", "mfa_required"]

          vpc_accessible_services = {
            enable_restriction = true
            allowed_services = ["storage.googleapis.com", "bigquery.googleapis.com"]
          }
        }

        ingress_policies = [{
          ingress_from = {
            identities = ["serviceAccount:${local.sa_prefix}-terraform-sa@${var.project_id}.iam.gserviceaccount.com"]
            sources = [{
              access_level = "office_ips"
            }]
          }

          ingress_to = {
            resources = ["*"]
            operations = [{
              service_name = "storage.googleapis.com"
              method_selectors = [{
                method = "google.storage.objects.create"
              }]
            }]
          }
        }]

        egress_policies = [{
          egress_from = {
            identities = ["serviceAccount:${local.sa_prefix}-dataflow-sa@${var.project_id}.iam.gserviceaccount.com"]
          }

          egress_to = {
            resources = ["projects/external-project"]
            operations = [{
              service_name = "bigquery.googleapis.com"
              method_selectors = [{
                method = "google.cloud.bigquery.v2.TableService.GetTable"
              }]
            }]
          }
        }]
      }
    }
  } : null
}

# Module inputs
inputs = {
  # Project configuration
  project_id = var.project_id

  # Service accounts configuration
  service_accounts = local.service_accounts

  # Custom roles configuration
  custom_roles = local.custom_roles

  # Project IAM bindings
  project_iam_bindings = local.project_iam_bindings

  # Conditional IAM bindings
  conditional_bindings = local.conditional_bindings

  # Workload Identity Pools
  workload_identity_pools = local.workload_identity_pools

  # IAM policy constraints
  policy_constraints = local.policy_constraints

  # IAM monitoring configuration
  iam_monitoring = local.iam_monitoring
  enable_monitoring = true
  create_monitoring_dashboard = local.env_config.environment == "prod"
  create_monitoring_alerts = local.env_config.environment != "dev"

  # Access Context Manager
  access_context_manager = local.access_context_manager

  # Service account key rotation
  key_rotation_config = {
    enable_auto_rotation = true
    rotation_period_days = local.env_config.environment == "prod" ? 90 : 180
    notification_days_before_expiry = 14
  }

  # Audit configuration
  audit_config = {
    enable_audit_logs = true
    audit_log_config = [
      {
        log_type = "ADMIN_READ"
      },
      {
        log_type = "DATA_READ"
        exempted_members = []
      },
      {
        log_type = "DATA_WRITE"
        exempted_members = []
      }
    ]
  }

  # Organization policies
  org_policies = {
    inherit_from_parent = true
    policy_for = "project"
  }

  # Security configuration
  security_config = {
    enable_uniform_bucket_level_access = true
    enable_vpc_service_controls = local.env_config.environment == "prod"
    enable_private_google_access = true
    enable_os_login = true
    enable_shielded_vms = true
    require_ssl = true
  }

  # Labels
  labels = merge(
    var.common_labels,
    {
      component = "security"
      service   = "iam"
      tier      = "identity"
    }
  )

  # Dependencies
  depends_on = [dependency.kms]
}