# KMS (Key Management Service) Configuration for Production - US Central 1
# Enterprise-grade encryption key management with CMEK, key rotation, and HSM support

terraform {
  source = "${get_repo_root()}/modules/security/kms"
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

# KMS has minimal dependencies
dependencies {
  paths = []
}

# Prevent accidental destruction of production encryption keys
prevent_destroy = true

locals {
  # Extract configuration from includes
  env_config    = include.env.locals
  region_config = include.region.locals

  # KMS keyring name
  keyring_name = "${local.env_config.environment}-${local.region_config.region_short}-keyring"

  # Key rotation periods (in seconds)
  rotation_periods = {
    default = "7776000"   # 90 days
    sensitive = "2592000" # 30 days
    compliance = "86400"  # 1 day for testing, normally would be longer
  }

  # Key algorithms based on purpose
  key_algorithms = {
    encryption = "GOOGLE_SYMMETRIC_ENCRYPTION"
    signing = "RSA_SIGN_PSS_4096_SHA512"
    mac = "HMAC_SHA256"
  }

  # Protection levels
  protection_levels = {
    software = "SOFTWARE"
    hsm = local.env_config.environment == "prod" ? "HSM" : "SOFTWARE"
    external = "EXTERNAL"
  }

  # Crypto keys configuration
  crypto_keys = {
    # Default encryption key for general use
    default = {
      name = "${local.env_config.environment}-${local.region_config.region_short}-default-key"
      purpose = "ENCRYPT_DECRYPT"
      rotation_period = local.rotation_periods.default
      algorithm = local.key_algorithms.encryption
      protection_level = local.protection_levels.software

      labels = {
        usage = "general"
        data_classification = "internal"
      }

      # IAM bindings
      iam_bindings = {
        "roles/cloudkms.cryptoKeyEncrypterDecrypter" = [
          "serviceAccount:${var.terraform_service_account}",
          "serviceAccount:${var.project_number}-compute@developer.gserviceaccount.com"
        ]
        "roles/cloudkms.viewer" = [
          "group:security-team@${local.env_config.organization_domain}",
          "group:platform-team@${local.env_config.organization_domain}"
        ]
      }

      # Version template
      version_template = {
        algorithm = local.key_algorithms.encryption
        protection_level = local.protection_levels.software
      }

      # Auto-rotation configuration
      lifecycle_state = "ENABLED"
      skip_initial_version_creation = false
      import_only = false

      # Key policy
      key_policy = {
        allow_plaintext_backup = false
        allow_generate_random = true
      }
    }

    # Cloud SQL encryption key
    cloud_sql = {
      name = "${local.env_config.environment}-${local.region_config.region_short}-cloud-sql-key"
      purpose = "ENCRYPT_DECRYPT"
      rotation_period = local.rotation_periods.sensitive
      algorithm = local.key_algorithms.encryption
      protection_level = local.protection_levels.hsm

      labels = {
        usage = "cloud-sql"
        data_classification = "highly-confidential"
        compliance = "pci-dss"
      }

      iam_bindings = {
        "roles/cloudkms.cryptoKeyEncrypterDecrypter" = [
          "serviceAccount:service-${var.project_number}@gcp-sa-cloud-sql.iam.gserviceaccount.com"
        ]
      }

      version_template = {
        algorithm = local.key_algorithms.encryption
        protection_level = local.protection_levels.hsm
      }
    }

    # GKE encryption key
    gke = {
      name = "${local.env_config.environment}-${local.region_config.region_short}-gke-key"
      purpose = "ENCRYPT_DECRYPT"
      rotation_period = local.rotation_periods.default
      algorithm = local.key_algorithms.encryption
      protection_level = local.protection_levels.hsm

      labels = {
        usage = "gke"
        data_classification = "confidential"
      }

      iam_bindings = {
        "roles/cloudkms.cryptoKeyEncrypterDecrypter" = [
          "serviceAccount:service-${var.project_number}@container-engine-robot.iam.gserviceaccount.com"
        ]
      }
    }

    # Storage bucket encryption key
    storage = {
      name = "${local.env_config.environment}-${local.region_config.region_short}-storage-key"
      purpose = "ENCRYPT_DECRYPT"
      rotation_period = local.rotation_periods.default
      algorithm = local.key_algorithms.encryption
      protection_level = local.protection_levels.software

      labels = {
        usage = "storage"
        data_classification = "internal"
      }

      iam_bindings = {
        "roles/cloudkms.cryptoKeyEncrypterDecrypter" = [
          "serviceAccount:service-${var.project_number}@gs-project-accounts.iam.gserviceaccount.com"
        ]
      }
    }

    # BigQuery encryption key
    bigquery = {
      name = "${local.env_config.environment}-${local.region_config.region_short}-bigquery-key"
      purpose = "ENCRYPT_DECRYPT"
      rotation_period = local.rotation_periods.sensitive
      algorithm = local.key_algorithms.encryption
      protection_level = local.protection_levels.hsm

      labels = {
        usage = "bigquery"
        data_classification = "highly-confidential"
        compliance = "gdpr"
      }

      iam_bindings = {
        "roles/cloudkms.cryptoKeyEncrypterDecrypter" = [
          "serviceAccount:bq-${var.project_number}@bigquery-encryption.iam.gserviceaccount.com"
        ]
      }
    }

    # Pub/Sub encryption key
    pubsub = {
      name = "${local.env_config.environment}-${local.region_config.region_short}-pubsub-key"
      purpose = "ENCRYPT_DECRYPT"
      rotation_period = local.rotation_periods.default
      algorithm = local.key_algorithms.encryption
      protection_level = local.protection_levels.software

      labels = {
        usage = "pubsub"
        data_classification = "confidential"
      }

      iam_bindings = {
        "roles/cloudkms.cryptoKeyEncrypterDecrypter" = [
          "serviceAccount:service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
        ]
      }
    }

    # Compute disk encryption key
    compute = {
      name = "${local.env_config.environment}-${local.region_config.region_short}-compute-key"
      purpose = "ENCRYPT_DECRYPT"
      rotation_period = local.rotation_periods.default
      algorithm = local.key_algorithms.encryption
      protection_level = local.protection_levels.software

      labels = {
        usage = "compute"
        data_classification = "internal"
      }

      iam_bindings = {
        "roles/cloudkms.cryptoKeyEncrypterDecrypter" = [
          "serviceAccount:${var.project_number}-compute@developer.gserviceaccount.com",
          "serviceAccount:service-${var.project_number}@compute-system.iam.gserviceaccount.com"
        ]
      }
    }

    # Artifact Registry encryption key
    artifact_registry = {
      name = "${local.env_config.environment}-${local.region_config.region_short}-artifact-registry-key"
      purpose = "ENCRYPT_DECRYPT"
      rotation_period = local.rotation_periods.default
      algorithm = local.key_algorithms.encryption
      protection_level = local.protection_levels.software

      labels = {
        usage = "artifact-registry"
        data_classification = "internal"
      }

      iam_bindings = {
        "roles/cloudkms.cryptoKeyEncrypterDecrypter" = [
          "serviceAccount:service-${var.project_number}@gcp-sa-artifactregistry.iam.gserviceaccount.com"
        ]
      }
    }

    # Secret Manager encryption key
    secret_manager = {
      name = "${local.env_config.environment}-${local.region_config.region_short}-secret-manager-key"
      purpose = "ENCRYPT_DECRYPT"
      rotation_period = local.rotation_periods.sensitive
      algorithm = local.key_algorithms.encryption
      protection_level = local.protection_levels.hsm

      labels = {
        usage = "secret-manager"
        data_classification = "highly-confidential"
        compliance = "sox"
      }

      iam_bindings = {
        "roles/cloudkms.cryptoKeyEncrypterDecrypter" = [
          "serviceAccount:service-${var.project_number}@gcp-sa-secretmanager.iam.gserviceaccount.com"
        ]
      }
    }

    # Logging encryption key
    logging = {
      name = "${local.env_config.environment}-${local.region_config.region_short}-logging-key"
      purpose = "ENCRYPT_DECRYPT"
      rotation_period = local.rotation_periods.default
      algorithm = local.key_algorithms.encryption
      protection_level = local.protection_levels.software

      labels = {
        usage = "logging"
        data_classification = "confidential"
        compliance = "audit"
      }

      iam_bindings = {
        "roles/cloudkms.cryptoKeyEncrypterDecrypter" = [
          "serviceAccount:service-${var.project_number}@gcp-sa-logging.iam.gserviceaccount.com"
        ]
      }
    }

    # Backup encryption key
    backup = {
      name = "${local.env_config.environment}-${local.region_config.region_short}-backup-key"
      purpose = "ENCRYPT_DECRYPT"
      rotation_period = "31536000" # 1 year for backups
      algorithm = local.key_algorithms.encryption
      protection_level = local.protection_levels.hsm

      labels = {
        usage = "backup"
        data_classification = "highly-confidential"
        retention = "long-term"
      }

      iam_bindings = {
        "roles/cloudkms.cryptoKeyEncrypterDecrypter" = [
          "serviceAccount:${var.terraform_service_account}",
          "serviceAccount:backup-service@${var.project_id}.iam.gserviceaccount.com"
        ]
      }
    }

    # Application-specific signing key
    app_signing = {
      name = "${local.env_config.environment}-${local.region_config.region_short}-app-signing-key"
      purpose = "ASYMMETRIC_SIGN"
      algorithm = local.key_algorithms.signing
      protection_level = local.protection_levels.hsm

      labels = {
        usage = "application-signing"
        data_classification = "public"
        purpose = "code-signing"
      }

      iam_bindings = {
        "roles/cloudkms.signer" = [
          "serviceAccount:app-signer@${var.project_id}.iam.gserviceaccount.com"
        ]
        "roles/cloudkms.publicKeyViewer" = [
          "allUsers"
        ]
      }

      version_template = {
        algorithm = local.key_algorithms.signing
        protection_level = local.protection_levels.hsm
      }
    }

    # MAC key for data integrity
    mac = {
      name = "${local.env_config.environment}-${local.region_config.region_short}-mac-key"
      purpose = "MAC"
      algorithm = local.key_algorithms.mac
      protection_level = local.protection_levels.hsm

      labels = {
        usage = "data-integrity"
        data_classification = "internal"
      }

      iam_bindings = {
        "roles/cloudkms.signerVerifier" = [
          "serviceAccount:integrity-checker@${var.project_id}.iam.gserviceaccount.com"
        ]
      }

      version_template = {
        algorithm = local.key_algorithms.mac
        protection_level = local.protection_levels.hsm
      }
    }
  }

  # Import jobs for existing keys (if any)
  import_jobs = local.env_config.environment == "prod" ? {
    external_hsm = {
      name = "${local.env_config.environment}-${local.region_config.region_short}-import-job"
      import_method = "RSA_OAEP_4096_SHA256"
      protection_level = "HSM"
      state = "ACTIVE"
    }
  } : {}

  # Key administration configuration
  key_admin_config = {
    # Auto-rotation settings
    enable_auto_rotation = true
    rotation_reminder_days = 14

    # Key destruction settings
    scheduled_destroy_days = local.env_config.environment == "prod" ? 30 : 7
    prevent_destroy = local.env_config.environment == "prod"

    # Key versioning
    max_versions_to_keep = 10
    auto_delete_old_versions = false

    # Audit settings
    enable_audit_logs = true
    log_retention_days = local.env_config.environment == "prod" ? 2555 : 365
  }

  # Monitoring and alerting configuration
  monitoring_config = {
    alerts = {
      key_rotation_due = {
        display_name = "KMS Key Rotation Due"
        conditions = {
          threshold_days = 7
        }
      }
      key_access_denied = {
        display_name = "KMS Access Denied"
        conditions = {
          threshold_count = 5
          duration = "300s"
        }
      }
      key_usage_spike = {
        display_name = "Unusual KMS Key Usage"
        conditions = {
          threshold_increase_percent = 200
          duration = "600s"
        }
      }
      key_destruction_requested = {
        display_name = "KMS Key Destruction Requested"
        conditions = {
          alert_immediately = true
        }
      }
      hsm_error = {
        display_name = "HSM Error Detected"
        conditions = {
          alert_immediately = true
          severity = "critical"
        }
      }
    }

    # Metrics to track
    metrics = {
      key_operations = {
        metric = "cloudkms.googleapis.com/crypto_key/request_count"
        aggregation = "ALIGN_RATE"
      }
      key_errors = {
        metric = "cloudkms.googleapis.com/crypto_key/error_count"
        aggregation = "ALIGN_RATE"
      }
      key_latency = {
        metric = "cloudkms.googleapis.com/crypto_key/request_latencies"
        aggregation = "ALIGN_MEAN"
      }
    }
  }

  # Compliance configuration
  compliance_config = {
    # Compliance standards
    standards = local.env_config.environment == "prod" ? [
      "PCI_DSS",
      "HIPAA",
      "SOX",
      "GDPR",
      "FIPS_140_2_LEVEL_3"
    ] : ["FIPS_140_2_LEVEL_1"]

    # Data residency requirements
    location_restriction = local.region_config.region
    multi_region_allowed = false

    # Audit requirements
    audit_logging_required = true
    audit_log_retention_years = local.env_config.environment == "prod" ? 7 : 1

    # Access control requirements
    require_two_person_approval = local.env_config.environment == "prod"
    require_cryptographic_attestation = local.env_config.environment == "prod"
  }

  # EKM (External Key Management) configuration - Production only
  ekm_config = local.env_config.environment == "prod" ? {
    enabled = false  # Set to true if using external key management
    ekm_connection_name = "${local.env_config.environment}-ekm-connection"
    ekm_uri = "https://ekm.example.com/v1/keys"
    service_directory_service = "projects/${var.project_id}/locations/${local.region_config.region}/namespaces/ekm/services/external-kms"

    crypto_space_path = "projects/${var.project_id}/locations/${local.region_config.region}/cryptoSpaces/external"
    key_management_mode = "CLOUD_KMS"

    credentials = {
      type = "OAUTH2"
      oauth2_client_id = get_env("EKM_CLIENT_ID", "")
      oauth2_client_secret = get_env("EKM_CLIENT_SECRET", "")
    }
  } : null
}

# Module inputs
inputs = {
  # Project configuration
  project_id = var.project_id
  location   = local.region_config.region

  # Keyring configuration
  keyring_name = local.keyring_name
  keyring_labels = merge(
    var.common_labels,
    {
      component = "security"
      service   = "kms"
      tier      = "encryption"
    }
  )

  # Crypto keys configuration
  crypto_keys = local.crypto_keys

  # Import jobs configuration
  import_jobs = local.import_jobs

  # Key administration settings
  key_admin_config = local.key_admin_config

  # IAM configuration
  keyring_iam_bindings = {
    "roles/cloudkms.admin" = [
      "group:security-admins@${local.env_config.organization_domain}"
    ]
    "roles/cloudkms.viewer" = [
      "group:platform-team@${local.env_config.organization_domain}",
      "group:security-team@${local.env_config.organization_domain}"
    ]
  }

  # Monitoring configuration
  monitoring_config = local.monitoring_config
  enable_monitoring = true
  create_monitoring_dashboard = local.env_config.environment == "prod"
  create_monitoring_alerts = local.env_config.environment != "dev"

  # Compliance configuration
  compliance_config = local.compliance_config

  # EKM configuration
  ekm_config = local.ekm_config

  # High availability configuration
  ha_config = {
    enable_multi_region_keys = local.env_config.environment == "prod"
    replica_locations = local.env_config.environment == "prod" ? [
      "us-east1",
      "europe-west1"
    ] : []
  }

  # Performance configuration
  performance_config = {
    enable_caching = true
    cache_ttl_seconds = 300
    max_concurrent_operations = 1000
  }

  # Security configuration
  security_config = {
    enable_key_access_justification = local.env_config.environment == "prod"
    require_attestation = local.env_config.environment == "prod"
    enable_crypto_key_verification = true
    enable_integrity_verification = true
  }

  # Cost optimization
  cost_optimization = {
    enable_key_lifecycle_management = true
    auto_delete_unused_keys_days = local.env_config.environment == "dev" ? 90 : 0
    consolidate_similar_keys = local.env_config.environment == "dev"
  }

  # Backup and disaster recovery
  backup_config = {
    enable_key_backup = local.env_config.environment == "prod"
    backup_location = local.env_config.environment == "prod" ? "us" : null
    backup_retention_days = 90
    enable_cross_region_backup = local.env_config.environment == "prod"
  }

  # Labels
  labels = merge(
    var.common_labels,
    {
      component = "security"
      service   = "kms"
      tier      = "encryption"
    }
  )
}