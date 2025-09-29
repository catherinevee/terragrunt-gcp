# Secret Manager Configuration for Production - US Central 1
# Enterprise-grade secret management with automatic rotation, versioning, and audit logging

terraform {
  source = "${get_repo_root()}/modules/security/secret-manager"
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

# Secret Manager depends on KMS for encryption
dependency "kms" {
  config_path = "../kms"

  mock_outputs = {
    keyring_id = "mock-keyring-id"
    keys = {
      secret_manager = {
        id = "mock-key-id"
        self_link = "projects/mock-project/locations/us-central1/keyRings/mock-keyring/cryptoKeys/mock-key"
      }
    }
  }
}

# Secret Manager depends on IAM for service accounts
dependency "iam" {
  config_path = "../iam"
  skip_outputs = true

  mock_outputs = {
    service_accounts = {
      terraform = {
        email = "terraform-sa@project.iam.gserviceaccount.com"
      }
      gke_workload = {
        email = "gke-workload-sa@project.iam.gserviceaccount.com"
      }
      cloud_run = {
        email = "cloud-run-sa@project.iam.gserviceaccount.com"
      }
    }
  }
}

# Prevent accidental destruction of production secrets
prevent_destroy = true

locals {
  # Extract configuration from includes
  env_config    = include.env.locals
  region_config = include.region.locals

  # Secret naming prefix
  secret_prefix = "${local.env_config.environment}-${local.region_config.region_short}"

  # Replication policy based on environment
  replication_policy = local.env_config.environment == "prod" ? {
    automatic = true
    user_managed = {
      replicas = [
        {
          location = "us-central1"
          customer_managed_encryption = {
            kms_key_name = dependency.kms.outputs.keys.secret_manager.self_link
          }
        },
        {
          location = "us-east1"
          customer_managed_encryption = {
            kms_key_name = dependency.kms.outputs.keys.secret_manager.self_link
          }
        },
        {
          location = "europe-west1"
          customer_managed_encryption = {
            kms_key_name = dependency.kms.outputs.keys.secret_manager.self_link
          }
        }
      ]
    }
  } : {
    automatic = false
    user_managed = {
      replicas = [
        {
          location = local.region_config.region
          customer_managed_encryption = {
            kms_key_name = dependency.kms.outputs.keys.secret_manager.self_link
          }
        }
      ]
    }
  }

  # Secrets configuration
  secrets = {
    # Database credentials
    database_credentials = {
      secret_id = "${local.secret_prefix}-db-credentials"
      description = "Database credentials for ${local.env_config.environment}"

      labels = {
        type = "database"
        rotation = "automatic"
        environment = local.env_config.environment
      }

      replication = local.replication_policy

      rotation = {
        rotation_period = "2592000s" # 30 days
        next_rotation_time = timeadd(timestamp(), "720h") # 30 days from now
      }

      versions = {
        v1 = {
          secret_data = jsonencode({
            username = "dbadmin"
            password = get_env("DB_PASSWORD", "")
            host     = "10.0.3.10"
            port     = 5432
            database = "production"
            ssl_mode = "require"
          })
          enabled = true
        }
      }

      iam_bindings = {
        "roles/secretmanager.secretAccessor" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.gke_workload.email}",
          "serviceAccount:${dependency.iam.outputs.service_accounts.cloud_run.email}"
        ]
        "roles/secretmanager.viewer" = [
          "group:developers@${local.env_config.organization_domain}"
        ]
      }

      topics = ["database-rotation-topic"]

      expire_time = null
      ttl = null

      annotations = {
        managed_by = "terraform"
        rotation_lambda = "secret-rotation-function"
      }
    }

    # API keys
    api_keys = {
      secret_id = "${local.secret_prefix}-api-keys"
      description = "External API keys for ${local.env_config.environment}"

      labels = {
        type = "api_key"
        rotation = "manual"
        sensitivity = "high"
      }

      replication = local.replication_policy

      rotation = {
        rotation_period = "7776000s" # 90 days
        next_rotation_time = timeadd(timestamp(), "2160h")
      }

      versions = {
        v1 = {
          secret_data = jsonencode({
            stripe_key = get_env("STRIPE_API_KEY", "")
            sendgrid_key = get_env("SENDGRID_API_KEY", "")
            twilio_key = get_env("TWILIO_API_KEY", "")
            datadog_api_key = get_env("DATADOG_API_KEY", "")
            datadog_app_key = get_env("DATADOG_APP_KEY", "")
            pagerduty_key = get_env("PAGERDUTY_API_KEY", "")
            slack_webhook = get_env("SLACK_WEBHOOK_URL", "")
          })
          enabled = true
        }
      }

      iam_bindings = {
        "roles/secretmanager.secretAccessor" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.cloud_run.email}",
          "serviceAccount:${dependency.iam.outputs.service_accounts.cloud_functions.email}"
        ]
      }
    }

    # OAuth credentials
    oauth_credentials = {
      secret_id = "${local.secret_prefix}-oauth-credentials"
      description = "OAuth 2.0 credentials for ${local.env_config.environment}"

      labels = {
        type = "oauth"
        provider = "google"
        rotation = "automatic"
      }

      replication = local.replication_policy

      rotation = {
        rotation_period = "2592000s" # 30 days
        next_rotation_time = timeadd(timestamp(), "720h")
      }

      versions = {
        v1 = {
          secret_data = jsonencode({
            client_id = get_env("OAUTH_CLIENT_ID", "")
            client_secret = get_env("OAUTH_CLIENT_SECRET", "")
            redirect_uris = [
              "https://app.example.com/oauth/callback",
              "https://api.example.com/oauth/callback"
            ]
            javascript_origins = [
              "https://app.example.com",
              "https://api.example.com"
            ]
            auth_uri = "https://accounts.google.com/o/oauth2/auth"
            token_uri = "https://oauth2.googleapis.com/token"
          })
          enabled = true
        }
      }

      iam_bindings = {
        "roles/secretmanager.secretAccessor" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.cloud_run.email}"
        ]
      }
    }

    # SSL certificates and keys
    ssl_certificates = {
      secret_id = "${local.secret_prefix}-ssl-certificates"
      description = "SSL certificates and private keys for ${local.env_config.environment}"

      labels = {
        type = "certificate"
        rotation = "manual"
        expiry_tracking = "enabled"
      }

      replication = local.replication_policy

      versions = {
        v1 = {
          secret_data = jsonencode({
            cert = get_env("TLS_CERT", "")
            key = get_env("TLS_KEY", "")
            chain = get_env("TLS_CERT", "")
            expiry = "2025-01-01T00:00:00Z"
          })
          enabled = true
        }
      }

      iam_bindings = {
        "roles/secretmanager.secretAccessor" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.terraform.email}"
        ]
      }

      expire_time = "2025-01-01T00:00:00Z"
    }

    # Service account keys
    service_account_keys = {
      secret_id = "${local.secret_prefix}-sa-keys"
      description = "Service account keys for ${local.env_config.environment}"

      labels = {
        type = "service_account"
        rotation = "automatic"
        compliance = "required"
      }

      replication = local.replication_policy

      rotation = {
        rotation_period = "7776000s" # 90 days
        next_rotation_time = timeadd(timestamp(), "2160h")
      }

      versions = {
        v1 = {
          secret_data = jsonencode({
            type = "service_account"
            project_id = var.project_id
            private_key_id = get_env("GCP_SERVICE_ACCOUNT_ID", "")
            private_key = get_env("GCP_SERVICE_ACCOUNT_KEY", "")
            client_email = "service-account@${var.project_id}.iam.gserviceaccount.com"
            client_id = get_env("GCP_CLIENT_ID", "")
            auth_uri = "https://accounts.google.com/o/oauth2/auth"
            token_uri = "https://oauth2.googleapis.com/token"
            auth_provider_x509_cert_url = "https://www.googleapis.com/oauth2/v1/certs"
          })
          enabled = true
        }
      }

      iam_bindings = {
        "roles/secretmanager.secretAccessor" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.terraform.email}"
        ]
      }
    }

    # Encryption keys
    encryption_keys = {
      secret_id = "${local.secret_prefix}-encryption-keys"
      description = "Application-level encryption keys for ${local.env_config.environment}"

      labels = {
        type = "encryption"
        algorithm = "aes256"
        rotation = "automatic"
      }

      replication = local.replication_policy

      rotation = {
        rotation_period = "2592000s" # 30 days
        next_rotation_time = timeadd(timestamp(), "720h")
      }

      versions = {
        v1 = {
          secret_data = jsonencode({
            master_key = get_env("MASTER_ENCRYPTION_KEY", "")
            data_key = get_env("DATA_ENCRYPTION_KEY", "")
            token_key = get_env("TOKEN_SIGNING_KEY", "")
            session_key = get_env("SESSION_ENCRYPTION_KEY", "")
          })
          enabled = true
        }
      }

      iam_bindings = {
        "roles/secretmanager.secretAccessor" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.gke_workload.email}",
          "serviceAccount:${dependency.iam.outputs.service_accounts.cloud_run.email}"
        ]
      }
    }

    # JWT signing keys
    jwt_keys = {
      secret_id = "${local.secret_prefix}-jwt-keys"
      description = "JWT signing keys for ${local.env_config.environment}"

      labels = {
        type = "jwt"
        algorithm = "RS256"
        rotation = "automatic"
      }

      replication = local.replication_policy

      rotation = {
        rotation_period = "604800s" # 7 days
        next_rotation_time = timeadd(timestamp(), "168h")
      }

      versions = {
        v1 = {
          secret_data = jsonencode({
            private_key = get_env("GCP_SERVICE_ACCOUNT_KEY", "")
            public_key = get_env("JWT_PUBLIC_KEY", "")
            kid = "2024-01-01"
            algorithm = "RS256"
            issued_at = timestamp()
          })
          enabled = true
        }
      }

      iam_bindings = {
        "roles/secretmanager.secretAccessor" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.gke_workload.email}",
          "serviceAccount:${dependency.iam.outputs.service_accounts.cloud_run.email}"
        ]
      }
    }

    # SSH keys
    ssh_keys = {
      secret_id = "${local.secret_prefix}-ssh-keys"
      description = "SSH keys for ${local.env_config.environment}"

      labels = {
        type = "ssh"
        rotation = "manual"
        purpose = "compute_access"
      }

      replication = local.replication_policy

      versions = {
        v1 = {
          secret_data = jsonencode({
            private_key = get_env("SSH_PRIVATE_KEY", "")
            public_key = get_env("SSH_PUBLIC_KEY", "")
            fingerprint = get_env("SSH_FINGERPRINT", "")
            comment = "admin@${local.env_config.environment}"
          })
          enabled = true
        }
      }

      iam_bindings = {
        "roles/secretmanager.secretAccessor" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.terraform.email}"
        ]
      }
    }

    # VPN credentials
    vpn_credentials = {
      secret_id = "${local.secret_prefix}-vpn-credentials"
      description = "VPN credentials for ${local.env_config.environment}"

      labels = {
        type = "vpn"
        rotation = "automatic"
        protocol = "ipsec"
      }

      replication = local.replication_policy

      rotation = {
        rotation_period = "7776000s" # 90 days
        next_rotation_time = timeadd(timestamp(), "2160h")
      }

      versions = {
        v1 = {
          secret_data = jsonencode({
            preshared_key = get_env("VPN_PSK", "")
            peer_ip = "203.0.113.1"
            peer_id = "vpn-peer-prod"
            local_id = "vpn-local-prod"
            ike_version = "2"
            phase1_encryption = "aes256"
            phase1_integrity = "sha256"
            phase1_dh_group = "modp2048"
            phase2_encryption = "aes256"
            phase2_integrity = "sha256"
            phase2_dh_group = "modp2048"
          })
          enabled = true
        }
      }

      iam_bindings = {
        "roles/secretmanager.secretAccessor" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.terraform.email}"
        ]
      }
    }

    # GitHub tokens
    github_tokens = {
      secret_id = "${local.secret_prefix}-github-tokens"
      description = "GitHub tokens for CI/CD in ${local.env_config.environment}"

      labels = {
        type = "vcs"
        provider = "github"
        rotation = "automatic"
      }

      replication = local.replication_policy

      rotation = {
        rotation_period = "2592000s" # 30 days
        next_rotation_time = timeadd(timestamp(), "720h")
      }

      versions = {
        v1 = {
          secret_data = jsonencode({
            personal_access_token = get_env("GITHUB_PERSONAL_ACCESS_TOKEN", "")
            app_id = "123456"
            app_private_key = get_env("GCP_SERVICE_ACCOUNT_KEY", "")
            webhook_secret = get_env("GITHUB_WEBHOOK_SECRET", "")
            oauth_client_id = get_env("GCP_CLIENT_ID", "")
            oauth_client_secret = get_env("OAUTH_CLIENT_SECRET", "")
          })
          enabled = true
        }
      }

      iam_bindings = {
        "roles/secretmanager.secretAccessor" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.cicd.email}"
        ]
      }
    }

    # Docker registry credentials
    docker_credentials = {
      secret_id = "${local.secret_prefix}-docker-credentials"
      description = "Docker registry credentials for ${local.env_config.environment}"

      labels = {
        type = "registry"
        provider = "docker"
        rotation = "automatic"
      }

      replication = local.replication_policy

      rotation = {
        rotation_period = "7776000s" # 90 days
        next_rotation_time = timeadd(timestamp(), "2160h")
      }

      versions = {
        v1 = {
          secret_data = jsonencode({
            registry_url = "gcr.io"
            username = "_json_key"
            password = jsonencode({
              type = "service_account"
              project_id = var.project_id
              private_key_id = get_env("GCP_SERVICE_ACCOUNT_ID", "")
              private_key = get_env("GCP_SERVICE_ACCOUNT_KEY", "")
              client_email = "gcr-service@${var.project_id}.iam.gserviceaccount.com"
              client_id = get_env("GCP_CLIENT_ID", "")
            })
            email = "gcr-service@${var.project_id}.iam.gserviceaccount.com"
          })
          enabled = true
        }
      }

      iam_bindings = {
        "roles/secretmanager.secretAccessor" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.cicd.email}",
          "serviceAccount:${dependency.iam.outputs.service_accounts.gke_workload.email}"
        ]
      }
    }

    # Monitoring credentials
    monitoring_credentials = {
      secret_id = "${local.secret_prefix}-monitoring-credentials"
      description = "Monitoring service credentials for ${local.env_config.environment}"

      labels = {
        type = "monitoring"
        rotation = "automatic"
      }

      replication = local.replication_policy

      rotation = {
        rotation_period = "7776000s" # 90 days
        next_rotation_time = timeadd(timestamp(), "2160h")
      }

      versions = {
        v1 = {
          secret_data = jsonencode({
            datadog_api_key = get_env("DATADOG_API_KEY", "")
            datadog_app_key = get_env("DATADOG_APP_KEY", "")
            new_relic_license_key = get_env("NEW_RELIC_LICENSE_KEY", "")
            new_relic_api_key = get_env("NEW_RELIC_API_KEY", "")
            prometheus_remote_write_url = "https://prometheus.example.com/api/v1/write"
            prometheus_remote_write_username = get_env("PROMETHEUS_REMOTE_WRITE_USERNAME", "")
            prometheus_remote_write_password = get_env("PROMETHEUS_REMOTE_WRITE_PASSWORD", "")
            grafana_api_key = get_env("GRAFANA_API_KEY", "")
            elastic_cloud_id = get_env("ELASTIC_CLOUD_ID", "")
            elastic_api_key = get_env("ELASTIC_API_KEY", "")
          })
          enabled = true
        }
      }

      iam_bindings = {
        "roles/secretmanager.secretAccessor" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.monitoring.email}"
        ]
      }
    }
  }

  # Secret rotation configuration
  rotation_config = {
    enable_automatic_rotation = true
    rotation_window_percentage = 50  # Start rotation at 50% of the rotation period

    # Notification settings
    notification_config = {
      enable_notifications = true
      notify_days_before_expiry = [30, 14, 7, 1]

      pubsub_topics = {
        rotation = "projects/${var.project_id}/topics/secret-rotation"
        expiry = "projects/${var.project_id}/topics/secret-expiry"
        access = "projects/${var.project_id}/topics/secret-access"
      }

      notification_channels = local.env_config.environment == "prod" ? [
        "projects/${var.project_id}/notificationChannels/slack-security",
        "projects/${var.project_id}/notificationChannels/pagerduty-security"
      ] : []
    }

    # Rotation functions
    rotation_functions = {
      database = "projects/${var.project_id}/locations/${local.region_config.region}/functions/rotate-db-credentials"
      api_keys = "projects/${var.project_id}/locations/${local.region_config.region}/functions/rotate-api-keys"
      certificates = "projects/${var.project_id}/locations/${local.region_config.region}/functions/rotate-certificates"
    }
  }

  # Access policies
  access_policies = {
    require_justification = local.env_config.environment == "prod"
    require_approval = local.env_config.environment == "prod"

    approval_config = {
      approvers = [
        "group:security-team@${local.env_config.organization_domain}",
        "group:platform-leads@${local.env_config.organization_domain}"
      ]
      min_approvals = 2
      approval_timeout = "3600s"
    }

    access_justification_config = {
      require_reason = true
      require_ticket_id = true
      allowed_reasons = [
        "CUSTOMER_ISSUE",
        "SECURITY_INCIDENT",
        "MAINTENANCE",
        "DEBUGGING"
      ]
    }
  }

  # Monitoring and alerting
  monitoring_config = {
    alerts = {
      secret_access_spike = {
        display_name = "Unusual Secret Access Pattern"
        conditions = {
          threshold_increase_percent = 200
          duration = "300s"
        }
      }

      secret_rotation_failed = {
        display_name = "Secret Rotation Failed"
        conditions = {
          alert_immediately = true
          severity = "critical"
        }
      }

      secret_expiry_warning = {
        display_name = "Secret Expiring Soon"
        conditions = {
          days_before_expiry = 30
        }
      }

      unauthorized_access_attempt = {
        display_name = "Unauthorized Secret Access Attempt"
        conditions = {
          threshold_count = 3
          duration = "60s"
          severity = "high"
        }
      }

      secret_version_destroyed = {
        display_name = "Secret Version Destroyed"
        conditions = {
          alert_immediately = true
          severity = "warning"
        }
      }
    }

    metrics = {
      access_count = {
        metric = "secretmanager.googleapis.com/secret/access_count"
        aggregation = "ALIGN_RATE"
      }
      version_count = {
        metric = "secretmanager.googleapis.com/secret/version_count"
        aggregation = "ALIGN_MEAN"
      }
    }

    dashboard = {
      display_name = "Secret Manager Dashboard - ${local.env_config.environment}"
      widgets = [
        {
          title = "Secret Access Rate"
          metric = "access_count"
          chart_type = "LINE"
        },
        {
          title = "Active Secret Versions"
          metric = "version_count"
          chart_type = "STACKED_AREA"
        },
        {
          title = "Rotation Status"
          metric = "rotation_status"
          chart_type = "SCORECARD"
        }
      ]
    }
  }

  # Compliance configuration
  compliance_config = {
    standards = local.env_config.environment == "prod" ? [
      "PCI_DSS",
      "SOC2",
      "ISO_27001",
      "NIST_800_53"
    ] : []

    audit_requirements = {
      log_all_access = true
      log_all_changes = true
      retain_logs_days = local.env_config.environment == "prod" ? 2555 : 365
    }

    encryption_requirements = {
      require_cmek = true
      require_hsm = local.env_config.environment == "prod"
      allowed_algorithms = ["AES256_GCM", "RSA_OAEP_4096_SHA256"]
    }

    access_requirements = {
      require_mfa = local.env_config.environment == "prod"
      require_approval = local.env_config.environment == "prod"
      max_access_duration = "3600s"
    }
  }

  # Disaster recovery configuration
  dr_config = {
    enable_cross_region_replication = local.env_config.environment == "prod"
    backup_regions = local.env_config.environment == "prod" ? [
      "us-east1",
      "europe-west1"
    ] : []

    backup_schedule = {
      frequency = "daily"
      retention_days = local.env_config.environment == "prod" ? 90 : 30
    }

    recovery_config = {
      rto_seconds = local.env_config.environment == "prod" ? 300 : 3600
      rpo_seconds = local.env_config.environment == "prod" ? 60 : 300
    }
  }
}

# Module inputs
inputs = {
  # Project configuration
  project_id = var.project_id
  location   = local.region_config.region

  # Secrets configuration
  secrets = local.secrets

  # Rotation configuration
  rotation_config = local.rotation_config

  # Access policies
  access_policies = local.access_policies

  # Encryption configuration
  encryption_config = {
    cmek_key = dependency.kms.outputs.keys.secret_manager.self_link
    require_cmek = true
  }

  # Monitoring configuration
  monitoring_config = local.monitoring_config
  enable_monitoring = true
  create_monitoring_dashboard = local.env_config.environment == "prod"
  create_monitoring_alerts = local.env_config.environment != "dev"

  # Compliance configuration
  compliance_config = local.compliance_config

  # Disaster recovery configuration
  dr_config = local.dr_config

  # Audit configuration
  audit_config = {
    enable_audit_logs = true
    audit_log_config = {
      log_type = "ALL"
      exempted_members = []
    }
  }

  # Labels
  labels = merge(
    var.common_labels,
    {
      component = "security"
      service   = "secret-manager"
      tier      = "secrets"
    }
  )

  # Dependencies
  depends_on = [dependency.kms, dependency.iam]
}