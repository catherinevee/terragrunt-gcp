# Cloud Storage Configuration for Production - US Central 1
# Enterprise object storage with lifecycle management, versioning, replication, and CDN integration

terraform {
  source = "${get_repo_root()}/modules/storage/cloud-storage"
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

# Cloud Storage depends on KMS for encryption
dependency "kms" {
  config_path = "../../security/kms"

  mock_outputs = {
    keys = {
      storage = {
        id = "mock-key-id"
        self_link = "projects/mock/locations/us-central1/keyRings/mock/cryptoKeys/mock"
      }
      backup = {
        id = "mock-backup-key-id"
        self_link = "projects/mock/locations/us-central1/keyRings/mock/cryptoKeys/backup"
      }
    }
  }
}

# Cloud Storage depends on IAM for service accounts
dependency "iam" {
  config_path = "../../security/iam"

  mock_outputs = {
    service_accounts = {
      storage = {
        email = "storage-sa@project.iam.gserviceaccount.com"
        id = "storage-sa"
      }
      backup = {
        email = "backup-sa@project.iam.gserviceaccount.com"
        id = "backup-sa"
      }
    }
  }
}

# Cloud Storage depends on VPC for Private Service Connect
dependency "vpc" {
  config_path = "../../networking/vpc"
  skip_outputs = true

  mock_outputs = {
    network_id = "mock-network-id"
    private_service_connect_ip = "10.0.0.10"
  }
}

locals {
  # Extract configuration from includes
  env_config    = include.env.locals
  region_config = include.region.locals

  # Bucket naming prefix
  bucket_prefix = "${var.project_id}-${local.env_config.environment}"

  # Storage classes based on access patterns
  storage_classes = {
    hot = "STANDARD"
    warm = "NEARLINE"
    cold = "COLDLINE"
    archive = "ARCHIVE"
  }

  # Cloud Storage buckets configuration
  buckets = {
    # Application data bucket
    application_data = {
      name = "${local.bucket_prefix}-application-data"
      location = local.region_config.region
      storage_class = local.storage_classes.hot

      description = "Application data and user uploads for ${local.env_config.environment}"

      # Versioning configuration
      versioning = {
        enabled = true
        # Keep last 5 versions in production
        max_versions = local.env_config.environment == "prod" ? 5 : 3
      }

      # Lifecycle rules
      lifecycle_rules = [
        {
          action = {
            type = "SetStorageClass"
            storage_class = local.storage_classes.warm
          }
          condition = {
            age = 30
            matches_storage_class = [local.storage_classes.hot]
          }
        },
        {
          action = {
            type = "SetStorageClass"
            storage_class = local.storage_classes.cold
          }
          condition = {
            age = 90
            matches_storage_class = [local.storage_classes.warm]
          }
        },
        {
          action = {
            type = "SetStorageClass"
            storage_class = local.storage_classes.archive
          }
          condition = {
            age = 365
            matches_storage_class = [local.storage_classes.cold]
          }
        },
        {
          action = {
            type = "Delete"
          }
          condition = {
            age = local.env_config.environment == "prod" ? 2555 : 365  # 7 years for prod
            is_live = false
          }
        },
        {
          action = {
            type = "Delete"
          }
          condition = {
            num_newer_versions = local.env_config.environment == "prod" ? 5 : 3
            is_live = false
          }
        },
        {
          action = {
            type = "AbortIncompleteMultipartUpload"
          }
          condition = {
            age = 7
          }
        }
      ]

      # Encryption configuration
      encryption = {
        default_kms_key_name = dependency.kms.outputs.keys.storage.self_link
      }

      # Access control
      uniform_bucket_level_access = true
      public_access_prevention = "enforced"

      # IAM bindings
      iam_bindings = {
        "roles/storage.objectViewer" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.cloud_run.email}"
        ]
        "roles/storage.objectAdmin" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.storage.email}"
        ]
        "roles/storage.legacyBucketReader" = [
          "group:developers@${local.env_config.organization_domain}"
        ]
      }

      # CORS configuration
      cors = [
        {
          origin = local.env_config.environment == "prod" ?
            ["https://example.com", "https://www.example.com"] :
            ["*"]
          method = ["GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS"]
          response_header = ["*"]
          max_age_seconds = 3600
        }
      ]

      # Retention policy
      retention_policy = local.env_config.environment == "prod" ? {
        retention_period = 2592000  # 30 days minimum retention
        is_locked = false  # Can be locked for compliance
      } : null

      # Logging configuration
      logging = {
        log_bucket = "${local.bucket_prefix}-logs"
        log_object_prefix = "storage-logs/application-data/"
      }

      # Website configuration (if serving static content)
      website = {
        main_page_suffix = "index.html"
        not_found_page = "404.html"
      }

      # Autoclass configuration
      autoclass = {
        enabled = true
        terminal_storage_class = "ARCHIVE"
      }

      # Custom metadata
      metadata = {
        environment = local.env_config.environment
        data_classification = "internal"
        compliance = "gdpr"
      }

      labels = {
        data_type = "application"
        cost_center = "engineering"
        retention = "standard"
      }
    }

    # Static assets bucket (CDN origin)
    static_assets = {
      name = "${local.bucket_prefix}-static-assets"
      location = "US"  # Multi-region for CDN
      storage_class = local.storage_classes.hot

      description = "Static assets served via CDN"

      versioning = {
        enabled = true
      }

      lifecycle_rules = [
        {
          action = {
            type = "Delete"
          }
          condition = {
            age = 30
            is_live = false
          }
        },
        {
          action = {
            type = "Delete"
          }
          condition = {
            num_newer_versions = 3
            is_live = false
          }
        }
      ]

      # Public access for CDN
      uniform_bucket_level_access = false

      default_acl = "publicRead"

      iam_bindings = {
        "roles/storage.objectViewer" = ["allUsers"]
        "roles/storage.objectAdmin" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.cicd.email}"
        ]
      }

      cors = [
        {
          origin = ["*"]
          method = ["GET", "HEAD"]
          response_header = ["Content-Type", "Cache-Control", "ETag"]
          max_age_seconds = 3600
        }
      ]

      # CDN configuration
      cdn_policy = {
        cache_mode = "CACHE_ALL_STATIC"
        client_ttl = 3600
        default_ttl = 3600
        max_ttl = 86400
        negative_caching = true
        serve_while_stale = 86400
      }

      website = {
        main_page_suffix = "index.html"
        not_found_page = "404.html"
      }

      labels = {
        data_type = "static_assets"
        cdn_enabled = "true"
        public_access = "true"
      }
    }

    # Backup bucket
    backups = {
      name = "${local.bucket_prefix}-backups"
      location = local.env_config.environment == "prod" ? "US" : local.region_config.region
      storage_class = local.storage_classes.cold

      description = "Backup storage for ${local.env_config.environment}"

      versioning = {
        enabled = true
      }

      lifecycle_rules = [
        {
          action = {
            type = "SetStorageClass"
            storage_class = local.storage_classes.archive
          }
          condition = {
            age = 30
            matches_storage_class = [local.storage_classes.cold]
          }
        },
        {
          action = {
            type = "Delete"
          }
          condition = {
            age = local.env_config.environment == "prod" ? 2555 : 180  # 7 years for prod, 6 months for others
          }
        }
      ]

      encryption = {
        default_kms_key_name = dependency.kms.outputs.keys.backup.self_link
      }

      uniform_bucket_level_access = true
      public_access_prevention = "enforced"

      retention_policy = local.env_config.environment == "prod" ? {
        retention_period = 2592000  # 30 days
        is_locked = true  # Locked for compliance
      } : null

      iam_bindings = {
        "roles/storage.objectCreator" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.backup.email}"
        ]
        "roles/storage.objectViewer" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.terraform.email}"
        ]
      }

      logging = {
        log_bucket = "${local.bucket_prefix}-logs"
        log_object_prefix = "storage-logs/backups/"
      }

      labels = {
        data_type = "backup"
        criticality = "high"
        compliance = "required"
      }
    }

    # Data lake bucket
    data_lake = {
      name = "${local.bucket_prefix}-data-lake"
      location = local.region_config.region
      storage_class = local.storage_classes.hot

      description = "Data lake for analytics and ML"

      versioning = {
        enabled = false  # Not needed for immutable data
      }

      lifecycle_rules = [
        {
          action = {
            type = "SetStorageClass"
            storage_class = local.storage_classes.warm
          }
          condition = {
            age = 7
            matches_storage_class = [local.storage_classes.hot]
          }
        },
        {
          action = {
            type = "SetStorageClass"
            storage_class = local.storage_classes.cold
          }
          condition = {
            age = 30
            matches_storage_class = [local.storage_classes.warm]
          }
        },
        {
          action = {
            type = "Delete"
          }
          condition = {
            age = local.env_config.environment == "prod" ? 1095 : 90  # 3 years for prod
          }
        }
      ]

      uniform_bucket_level_access = true

      iam_bindings = {
        "roles/storage.objectViewer" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.bigquery.email}",
          "serviceAccount:${dependency.iam.outputs.service_accounts.dataflow.email}"
        ]
        "roles/storage.objectCreator" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.dataflow.email}"
        ]
      }

      # Object naming convention for partitioning
      object_naming = {
        prefix_pattern = "data/{dataset}/{year}/{month}/{day}/{hour}/"
      }

      labels = {
        data_type = "data_lake"
        purpose = "analytics"
      }
    }

    # Logs bucket
    logs = {
      name = "${local.bucket_prefix}-logs"
      location = local.region_config.region
      storage_class = local.storage_classes.warm

      description = "Centralized logging bucket"

      versioning = {
        enabled = false
      }

      lifecycle_rules = [
        {
          action = {
            type = "SetStorageClass"
            storage_class = local.storage_classes.cold
          }
          condition = {
            age = 30
          }
        },
        {
          action = {
            type = "Delete"
          }
          condition = {
            age = local.env_config.environment == "prod" ? 365 : 30
          }
        }
      ]

      uniform_bucket_level_access = true
      public_access_prevention = "enforced"

      iam_bindings = {
        "roles/storage.objectCreator" = [
          "group:cloud-storage-analytics@google.com",  # For storage logs
          "serviceAccount:${dependency.iam.outputs.service_accounts.monitoring.email}"
        ]
      }

      labels = {
        data_type = "logs"
        retention = "compliance"
      }
    }

    # Temporary/staging bucket
    temp = {
      name = "${local.bucket_prefix}-temp"
      location = local.region_config.region
      storage_class = local.storage_classes.hot

      description = "Temporary storage for processing"

      versioning = {
        enabled = false
      }

      lifecycle_rules = [
        {
          action = {
            type = "Delete"
          }
          condition = {
            age = 7  # Delete after 7 days
          }
        },
        {
          action = {
            type = "AbortIncompleteMultipartUpload"
          }
          condition = {
            age = 1
          }
        }
      ]

      uniform_bucket_level_access = true

      iam_bindings = {
        "roles/storage.objectAdmin" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.dataflow.email}",
          "serviceAccount:${dependency.iam.outputs.service_accounts.cloud_functions.email}"
        ]
      }

      labels = {
        data_type = "temporary"
        auto_delete = "true"
      }
    }

    # ML models bucket
    ml_models = {
      name = "${local.bucket_prefix}-ml-models"
      location = local.region_config.region
      storage_class = local.storage_classes.hot

      description = "Machine learning models storage"

      versioning = {
        enabled = true
        max_versions = 10  # Keep last 10 model versions
      }

      lifecycle_rules = [
        {
          action = {
            type = "SetStorageClass"
            storage_class = local.storage_classes.warm
          }
          condition = {
            age = 30
            is_live = false  # Only old versions
          }
        }
      ]

      encryption = {
        default_kms_key_name = dependency.kms.outputs.keys.storage.self_link
      }

      uniform_bucket_level_access = true

      iam_bindings = {
        "roles/storage.objectViewer" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.ml.email}"
        ]
        "roles/storage.objectAdmin" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.ml_training.email}"
        ]
      }

      # Model registry metadata
      object_metadata = {
        model_version = "{version}"
        model_framework = "{tensorflow|pytorch|sklearn}"
        training_date = "{date}"
        accuracy = "{metric}"
      }

      labels = {
        data_type = "ml_models"
        purpose = "serving"
        framework = "multi"
      }
    }

    # Disaster recovery bucket
    disaster_recovery = {
      name = "${local.bucket_prefix}-dr"
      location = local.env_config.environment == "prod" ? "US" : local.region_config.region
      storage_class = local.storage_classes.cold

      description = "Disaster recovery storage"

      versioning = {
        enabled = true
      }

      lifecycle_rules = [
        {
          action = {
            type = "SetStorageClass"
            storage_class = local.storage_classes.archive
          }
          condition = {
            age = 90
          }
        }
      ]

      # Turbo replication for critical data
      turbo_replication = local.env_config.environment == "prod"

      # Dual-region configuration for HA
      custom_placement_config = local.env_config.environment == "prod" ? {
        data_locations = ["us-central1", "us-east1"]
      } : null

      retention_policy = local.env_config.environment == "prod" ? {
        retention_period = 7776000  # 90 days
        is_locked = true
      } : null

      labels = {
        data_type = "disaster_recovery"
        criticality = "critical"
        rpo = "15min"
        rto = "1hour"
      }
    }

    # Compliance/audit bucket
    compliance = {
      name = "${local.bucket_prefix}-compliance"
      location = local.env_config.environment == "prod" ? "US" : local.region_config.region
      storage_class = local.storage_classes.cold

      description = "Compliance and audit data"

      versioning = {
        enabled = true
      }

      lifecycle_rules = [
        {
          action = {
            type = "SetStorageClass"
            storage_class = local.storage_classes.archive
          }
          condition = {
            age = 365
          }
        }
      ]

      # Bucket Lock for compliance (WORM - Write Once Read Many)
      retention_policy = {
        retention_period = 2555 * 86400  # 7 years in seconds
        is_locked = true  # Permanent lock for compliance
      }

      encryption = {
        default_kms_key_name = dependency.kms.outputs.keys.storage.self_link
      }

      uniform_bucket_level_access = true
      public_access_prevention = "enforced"

      # Restricted access
      iam_bindings = {
        "roles/storage.objectViewer" = [
          "group:compliance-team@${local.env_config.organization_domain}",
          "group:legal-team@${local.env_config.organization_domain}"
        ]
        "roles/storage.objectCreator" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.audit.email}"
        ]
      }

      # Audit logging
      logging = {
        log_bucket = "${local.bucket_prefix}-logs"
        log_object_prefix = "compliance-access/"
      }

      labels = {
        data_type = "compliance"
        retention = "7years"
        regulatory = "sox_gdpr_hipaa"
        immutable = "true"
      }
    }
  }

  # Bucket notifications configuration
  bucket_notifications = {
    application_data = {
      bucket = "${local.bucket_prefix}-application-data"

      pubsub_notifications = [
        {
          topic = "projects/${var.project_id}/topics/${local.env_config.environment}-storage-events"
          events = ["OBJECT_FINALIZE", "OBJECT_DELETE"]
          object_name_prefix = "uploads/"

          custom_attributes = {
            bucket_name = "${local.bucket_prefix}-application-data"
            environment = local.env_config.environment
          }
        }
      ]
    }

    data_lake = {
      bucket = "${local.bucket_prefix}-data-lake"

      pubsub_notifications = [
        {
          topic = "projects/${var.project_id}/topics/${local.env_config.environment}-data-ingestion"
          events = ["OBJECT_FINALIZE"]
          object_name_prefix = "raw/"
        }
      ]
    }
  }

  # Transfer jobs configuration
  transfer_jobs = {
    # Daily backup to another region
    cross_region_backup = {
      description = "Cross-region backup for disaster recovery"

      transfer_spec = {
        source_gcs_bucket = "${local.bucket_prefix}-application-data"
        sink_gcs_bucket = "${local.bucket_prefix}-dr"

        object_conditions = {
          max_time_elapsed_since_last_modification = "86400s"  # 1 day
          include_prefixes = ["critical/", "important/"]
        }

        transfer_options = {
          overwrite_objects_already_existing_in_sink = false
          delete_objects_from_source_after_transfer = false
          delete_objects_unique_in_sink = false
        }
      }

      schedule = {
        schedule_start_date = {
          year = 2024
          month = 1
          day = 1
        }
        start_time_of_day = {
          hours = 2
          minutes = 0
          seconds = 0
        }
        repeat_interval = "86400s"  # Daily
      }

      status = "ENABLED"
    }

    # Archive old data
    archive_old_data = {
      description = "Move old data to archive storage"

      transfer_spec = {
        source_gcs_bucket = "${local.bucket_prefix}-data-lake"
        sink_gcs_bucket = "${local.bucket_prefix}-data-lake"  # Same bucket, different storage class

        object_conditions = {
          min_time_elapsed_since_last_modification = "7776000s"  # 90 days
        }

        transfer_options = {
          overwrite_objects_already_existing_in_sink = true
        }

        gcs_data_sink = {
          bucket_name = "${local.bucket_prefix}-data-lake"
          path = "archive/"
        }
      }

      schedule = {
        schedule_start_date = {
          year = 2024
          month = 1
          day = 1
        }
        start_time_of_day = {
          hours = 3
          minutes = 0
          seconds = 0
        }
        repeat_interval = "604800s"  # Weekly
      }

      status = "ENABLED"
    }
  }

  # Monitoring and alerting configuration
  monitoring_config = {
    alerts = {
      high_storage_usage = {
        display_name = "High Storage Usage"
        conditions = {
          threshold_bytes = 1099511627776  # 1 TB
          duration = "3600s"
        }
      }

      high_egress_cost = {
        display_name = "High Egress Costs"
        conditions = {
          threshold_gb = 1000
          duration = "86400s"
        }
      }

      bucket_permission_change = {
        display_name = "Bucket Permission Changed"
        conditions = {
          alert_on_iam_change = true
        }
      }

      object_access_anomaly = {
        display_name = "Unusual Object Access Pattern"
        conditions = {
          threshold_increase_percent = 500
          duration = "3600s"
        }
      }

      retention_policy_change = {
        display_name = "Retention Policy Modified"
        conditions = {
          alert_immediately = true
          severity = "critical"
        }
      }
    }

    metrics = {
      storage_bytes = {
        metric = "storage.googleapis.com/storage/total_bytes"
        aggregation = "ALIGN_MEAN"
      }

      object_count = {
        metric = "storage.googleapis.com/storage/object_count"
        aggregation = "ALIGN_MEAN"
      }

      request_count = {
        metric = "storage.googleapis.com/api/request_count"
        aggregation = "ALIGN_RATE"
      }

      network_egress = {
        metric = "storage.googleapis.com/network/sent_bytes_count"
        aggregation = "ALIGN_RATE"
      }
    }

    dashboard = {
      display_name = "Cloud Storage Dashboard - ${local.env_config.environment}"

      widgets = [
        {
          title = "Total Storage Usage"
          metric = "storage_bytes"
          chart_type = "LINE"
        },
        {
          title = "Object Count by Bucket"
          metric = "object_count"
          chart_type = "STACKED_AREA"
        },
        {
          title = "Request Rate"
          metric = "request_count"
          chart_type = "LINE"
        },
        {
          title = "Egress Bandwidth"
          metric = "network_egress"
          chart_type = "LINE"
        },
        {
          title = "Storage Class Distribution"
          metric = "storage_by_class"
          chart_type = "PIE"
        }
      ]
    }
  }

  # Cost optimization configuration
  cost_optimization = {
    # Autoclass for automatic storage class management
    enable_autoclass = true

    # Lifecycle policies
    aggressive_lifecycle = local.env_config.environment != "prod"

    # Regional vs Multi-regional
    use_regional_buckets = true  # Cheaper than multi-regional

    # Requester pays
    requester_pays = {
      enabled = false  # Enable for shared datasets
      buckets = []
    }

    # Storage class recommendations
    analyze_access_patterns = true
    recommend_storage_class = true

    # Compression
    enable_compression = {
      file_types = [".log", ".txt", ".csv", ".json"]
      compression_type = "GZIP"
    }
  }

  # Security configuration
  security_config = {
    # Encryption
    require_cmek = true
    cmek_rotation_period = "7776000s"  # 90 days

    # Access control
    uniform_bucket_level_access = true
    public_access_prevention = "enforced"

    # VPC Service Controls
    vpc_service_controls = local.env_config.environment == "prod" ? {
      perimeter = "${local.env_config.environment}-storage-perimeter"
      access_levels = ["trusted_ips", "trusted_devices"]
    } : null

    # Customer-managed encryption keys per bucket
    bucket_keys = {
      for bucket_name, _ in local.buckets :
      bucket_name => dependency.kms.outputs.keys.storage.self_link
    }

    # Signed URLs configuration
    signed_url_config = {
      enabled = true
      max_age = 3600
      version = "v4"
    }

    # Private Service Connect
    private_service_connect = local.env_config.environment == "prod" ? {
      enabled = true
      endpoint_address = dependency.vpc.outputs.private_service_connect_ip
    } : null
  }

  # Data governance configuration
  data_governance = {
    # Data classification
    classification_labels = {
      public = ["static_assets"]
      internal = ["application_data", "logs", "temp"]
      confidential = ["data_lake", "ml_models"]
      highly_confidential = ["backups", "disaster_recovery", "compliance"]
    }

    # Retention policies by classification
    retention_by_classification = {
      public = 30
      internal = 90
      confidential = 365
      highly_confidential = 2555
    }

    # Access logging
    access_logging = {
      enabled = true
      log_analytics = true
      log_retention_days = local.env_config.environment == "prod" ? 365 : 30
    }

    # DLP scanning
    dlp_scanning = local.env_config.environment == "prod" ? {
      enabled = true
      scan_frequency = "daily"
      info_types = ["EMAIL_ADDRESS", "PHONE_NUMBER", "CREDIT_CARD_NUMBER", "US_SOCIAL_SECURITY_NUMBER"]
    } : null
  }
}

# Module inputs
inputs = {
  # Project configuration
  project_id = var.project_id
  region     = local.region_config.region

  # Buckets configuration
  buckets = local.buckets

  # Bucket notifications
  bucket_notifications = local.bucket_notifications

  # Transfer jobs
  transfer_jobs = local.transfer_jobs

  # Security configuration
  security_config = local.security_config

  # Monitoring configuration
  monitoring_config = local.monitoring_config
  enable_monitoring = true
  create_monitoring_dashboard = local.env_config.environment == "prod"
  create_monitoring_alerts = local.env_config.environment != "dev"

  # Cost optimization
  cost_optimization = local.cost_optimization

  # Data governance
  data_governance = local.data_governance

  # Labels
  labels = merge(
    var.common_labels,
    {
      component = "storage"
      service   = "cloud-storage"
      tier      = "storage"
    }
  )

  # Dependencies
  depends_on = [dependency.kms, dependency.iam, dependency.vpc]
}