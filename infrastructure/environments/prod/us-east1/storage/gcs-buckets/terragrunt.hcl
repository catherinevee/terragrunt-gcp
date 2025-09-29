# Production GCS Buckets Configuration - US East 1 (Disaster Recovery)
# This configuration creates Cloud Storage buckets for disaster recovery

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("env.hcl")
}

include "region" {
  path = find_in_parent_folders("region.hcl")
}

terraform {
  source = "../../../../../../modules/storage/gcs-buckets"
}

dependency "kms" {
  config_path = "../../security/kms"
  mock_outputs = {
    crypto_keys = {
      storage = "projects/mock-project/locations/us-east1/keyRings/mock/cryptoKeys/storage"
    }
  }
}

inputs = {
  project_id = "your-prod-project-id"
  region     = local.region

  # Storage buckets for disaster recovery
  buckets = {
    # Static assets with cross-region replication
    static_assets = {
      name          = "your-prod-project-id-static-assets-${local.region_short}"
      location      = local.region
      storage_class = local.storage_config.buckets.static_assets.storage_class
      versioning    = local.storage_config.buckets.static_assets.versioning

      # Cross-region replication from primary
      cross_region_replication = local.storage_config.buckets.static_assets.cross_region_replication

      # Turbo replication for faster DR
      turbo_replication = local.storage_config.buckets.static_assets.turbo_replication

      # Uniform bucket-level access for security
      uniform_bucket_level_access = local.storage_config.buckets.static_assets.uniform_bucket_level_access

      # Enable CDN
      enable_cdn = local.storage_config.buckets.static_assets.enable_cdn

      # Lifecycle rules
      lifecycle_rules = local.storage_config.buckets.static_assets.lifecycle_rules

      # CORS configuration for web applications
      cors = [
        {
          origin          = ["https://your-domain.com", "https://www.your-domain.com"]
          method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
          response_header = ["*"]
          max_age_seconds = 3600
        }
      ]

      # Website configuration
      website = {
        main_page_suffix = "index.html"
        not_found_page   = "404.html"
      }

      # Encryption
      encryption = {
        default_kms_key_name = dependency.kms.outputs.crypto_keys.storage
      }

      # Labels
      labels = {
        environment = "production"
        region = local.region_short
        purpose = "static-assets"
        replication = "cross-region"
        dr_role = "secondary"
        content_type = "web-assets"
      }

      # IAM bindings
      iam_members = [
        {
          role   = "roles/storage.objectViewer"
          member = "allUsers"
        },
        {
          role   = "roles/storage.admin"
          member = "serviceAccount:cdn-service@your-prod-project-id.iam.gserviceaccount.com"
        }
      ]

      # Retention policy
      retention_policy = {
        retention_period = 86400  # 24 hours minimum
        is_locked       = false
      }

      # Logging
      logging = {
        log_bucket        = "your-prod-project-id-access-logs-${local.region_short}"
        log_object_prefix = "static-assets/"
      }

      # Event notifications
      notification_configs = [
        {
          topic_name = "projects/your-prod-project-id/topics/storage-events"
          payload_format = "JSON_API_V1"
          event_types = [
            "OBJECT_FINALIZE",
            "OBJECT_DELETE"
          ]
        }
      ]
    }

    # Application data with disaster recovery
    application_data = {
      name          = "your-prod-project-id-application-data-${local.region_short}"
      location      = local.region
      storage_class = local.storage_config.buckets.application_data.storage_class
      versioning    = local.storage_config.buckets.application_data.versioning

      # Cross-region replication configuration
      cross_region_replication = local.storage_config.buckets.application_data.cross_region_replication
      turbo_replication = local.storage_config.buckets.application_data.turbo_replication

      # Security settings
      uniform_bucket_level_access = true
      public_access_prevention = "enforced"

      # Encryption with CMEK
      encryption = {
        default_kms_key_name = dependency.kms.outputs.crypto_keys.storage
      }

      # Retention policy for compliance
      retention_policy = local.storage_config.buckets.application_data.retention_policy

      # Lifecycle management
      lifecycle_rules = [
        {
          action = {
            type = "SetStorageClass"
            storage_class = "NEARLINE"
          }
          condition = {
            age = 30
            matches_storage_class = ["STANDARD"]
          }
        },
        {
          action = {
            type = "SetStorageClass"
            storage_class = "COLDLINE"
          }
          condition = {
            age = 90
            matches_storage_class = ["NEARLINE"]
          }
        },
        {
          action = {
            type = "SetStorageClass"
            storage_class = "ARCHIVE"
          }
          condition = {
            age = 365
            matches_storage_class = ["COLDLINE"]
          }
        }
      ]

      # Labels
      labels = {
        environment = "production"
        region = local.region_short
        purpose = "application-data"
        classification = "internal"
        backup_required = "true"
        encryption = "cmek"
        dr_role = "secondary"
      }

      # IAM bindings
      iam_members = [
        {
          role   = "roles/storage.objectAdmin"
          member = "serviceAccount:app-service@your-prod-project-id.iam.gserviceaccount.com"
        },
        {
          role   = "roles/storage.objectViewer"
          member = "serviceAccount:backup-service@your-prod-project-id.iam.gserviceaccount.com"
        }
      ]
    }

    # Backup storage with long-term retention
    backups = {
      name          = "your-prod-project-id-backups-${local.region_short}"
      location      = local.region
      storage_class = local.storage_config.buckets.backups.storage_class
      versioning    = local.storage_config.buckets.backups.versioning

      # Geo-redundant configuration
      geo_redundant = local.storage_config.buckets.backups.geo_redundant
      dual_region_configuration = local.storage_config.buckets.backups.dual_region_configuration

      # Uniform bucket-level access
      uniform_bucket_level_access = true
      public_access_prevention = "enforced"

      # Retention policy - locked for compliance
      retention_policy = local.storage_config.buckets.backups.retention_policy

      # Lifecycle rules for cost optimization
      lifecycle_rules = local.storage_config.buckets.backups.lifecycle_rules

      # Encryption
      encryption = {
        default_kms_key_name = dependency.kms.outputs.crypto_keys.storage
      }

      # Labels
      labels = {
        environment = "production"
        region = local.region_short
        purpose = "backups"
        retention = "long-term"
        compliance = "required"
        encryption = "cmek"
        dr_role = "secondary"
        immutable = "true"
      }

      # IAM bindings
      iam_members = [
        {
          role   = "roles/storage.objectCreator"
          member = "serviceAccount:backup-service@your-prod-project-id.iam.gserviceaccount.com"
        },
        {
          role   = "roles/storage.objectViewer"
          member = "serviceAccount:restore-service@your-prod-project-id.iam.gserviceaccount.com"
        }
      ]

      # Object hold configuration
      default_event_based_hold = false
      temporary_hold = false
    }

    # Disaster recovery specific storage
    disaster_recovery = {
      name          = "your-prod-project-id-disaster-recovery-${local.region_short}"
      location      = local.storage_config.buckets.disaster_recovery.location
      storage_class = local.storage_config.buckets.disaster_recovery.storage_class
      versioning    = local.storage_config.buckets.disaster_recovery.versioning

      # Multi-regional for high availability
      location_type = "MULTI-REGION"

      # Turbo replication for immediate consistency
      turbo_replication = local.storage_config.buckets.disaster_recovery.turbo_replication
      immediate_consistency = local.storage_config.buckets.disaster_recovery.immediate_consistency
      strong_consistency = local.storage_config.buckets.disaster_recovery.strong_consistency

      # Security settings
      uniform_bucket_level_access = true
      public_access_prevention = "enforced"

      # Retention policy
      retention_policy = local.storage_config.buckets.disaster_recovery.retention_policy

      # Encryption
      encryption = {
        default_kms_key_name = dependency.kms.outputs.crypto_keys.storage
      }

      # Labels
      labels = {
        environment = "production"
        region = "multi-region"
        purpose = "disaster-recovery"
        tier = "critical"
        availability = "high"
        consistency = "strong"
        dr_role = "primary"
      }

      # IAM bindings for DR operations
      iam_members = [
        {
          role   = "roles/storage.admin"
          member = "serviceAccount:dr-orchestrator@your-prod-project-id.iam.gserviceaccount.com"
        },
        {
          role   = "roles/storage.objectViewer"
          member = "group:disaster-recovery-team@your-company.com"
        }
      ]

      # Event notifications for DR events
      notification_configs = [
        {
          topic_name = "projects/your-prod-project-id/topics/dr-events"
          payload_format = "JSON_API_V1"
          event_types = [
            "OBJECT_FINALIZE",
            "OBJECT_DELETE",
            "OBJECT_METADATA_UPDATE"
          ]
        }
      ]
    }

    # Logs archive storage
    logs_archive = {
      name          = "your-prod-project-id-logs-archive-${local.region_short}"
      location      = local.region
      storage_class = "NEARLINE"
      versioning    = true

      # Uniform bucket-level access
      uniform_bucket_level_access = true
      public_access_prevention = "enforced"

      # Lifecycle rules for log retention
      lifecycle_rules = [
        {
          action = {
            type = "SetStorageClass"
            storage_class = "COLDLINE"
          }
          condition = {
            age = 90
            matches_storage_class = ["NEARLINE"]
          }
        },
        {
          action = {
            type = "SetStorageClass"
            storage_class = "ARCHIVE"
          }
          condition = {
            age = 365
            matches_storage_class = ["COLDLINE"]
          }
        },
        {
          action = {
            type = "Delete"
          }
          condition = {
            age = 2555  # 7 years
          }
        }
      ]

      # Encryption
      encryption = {
        default_kms_key_name = dependency.kms.outputs.crypto_keys.storage
      }

      # Labels
      labels = {
        environment = "production"
        region = local.region_short
        purpose = "logs-archive"
        retention = "7-years"
        compliance = "required"
        dr_role = "secondary"
      }

      # IAM bindings
      iam_members = [
        {
          role   = "roles/storage.objectCreator"
          member = "serviceAccount:log-sink@your-prod-project-id.iam.gserviceaccount.com"
        },
        {
          role   = "roles/storage.objectViewer"
          member = "group:compliance-team@your-company.com"
        }
      ]
    }

    # Terraform state backup
    terraform_state_backup = {
      name          = "your-prod-project-id-tf-state-backup-${local.region_short}"
      location      = local.region
      storage_class = "STANDARD"
      versioning    = true

      # Security settings
      uniform_bucket_level_access = true
      public_access_prevention = "enforced"

      # Retention policy
      retention_policy = {
        retention_period = 7776000  # 90 days
        is_locked       = true
      }

      # Lifecycle rules
      lifecycle_rules = [
        {
          action = {
            type = "SetStorageClass"
            storage_class = "NEARLINE"
          }
          condition = {
            age = 30
          }
        }
      ]

      # Encryption
      encryption = {
        default_kms_key_name = dependency.kms.outputs.crypto_keys.storage
      }

      # Labels
      labels = {
        environment = "production"
        region = local.region_short
        purpose = "terraform-state"
        backup = "true"
        critical = "true"
        dr_role = "secondary"
      }

      # IAM bindings
      iam_members = [
        {
          role   = "roles/storage.admin"
          member = "serviceAccount:terraform-state@your-prod-project-id.iam.gserviceaccount.com"
        }
      ]
    }

    # Container image registry backup
    container_registry_backup = {
      name          = "your-prod-project-id-registry-backup-${local.region_short}"
      location      = local.region
      storage_class = "STANDARD"
      versioning    = true

      # Security settings
      uniform_bucket_level_access = true
      public_access_prevention = "enforced"

      # Lifecycle rules for image retention
      lifecycle_rules = [
        {
          action = {
            type = "SetStorageClass"
            storage_class = "NEARLINE"
          }
          condition = {
            age = 60
            matches_storage_class = ["STANDARD"]
          }
        },
        {
          action = {
            type = "SetStorageClass"
            storage_class = "COLDLINE"
          }
          condition = {
            age = 180
            matches_storage_class = ["NEARLINE"]
          }
        },
        {
          action = {
            type = "Delete"
          }
          condition = {
            age = 365
            matches_prefix = ["tmp/", "cache/"]
          }
        }
      ]

      # Encryption
      encryption = {
        default_kms_key_name = dependency.kms.outputs.crypto_keys.storage
      }

      # Labels
      labels = {
        environment = "production"
        region = local.region_short
        purpose = "container-registry"
        backup = "true"
        dr_role = "secondary"
      }

      # IAM bindings
      iam_members = [
        {
          role   = "roles/storage.admin"
          member = "serviceAccount:registry-backup@your-prod-project-id.iam.gserviceaccount.com"
        }
      ]
    }

    # Access logs storage
    access_logs = {
      name          = "your-prod-project-id-access-logs-${local.region_short}"
      location      = local.region
      storage_class = "STANDARD"
      versioning    = false

      # Security settings
      uniform_bucket_level_access = true
      public_access_prevention = "enforced"

      # Lifecycle rules for log management
      lifecycle_rules = [
        {
          action = {
            type = "SetStorageClass"
            storage_class = "NEARLINE"
          }
          condition = {
            age = 30
          }
        },
        {
          action = {
            type = "SetStorageClass"
            storage_class = "COLDLINE"
          }
          condition = {
            age = 90
          }
        },
        {
          action = {
            type = "Delete"
          }
          condition = {
            age = 365
          }
        }
      ]

      # Encryption
      encryption = {
        default_kms_key_name = dependency.kms.outputs.crypto_keys.storage
      }

      # Labels
      labels = {
        environment = "production"
        region = local.region_short
        purpose = "access-logs"
        retention = "1-year"
        dr_role = "secondary"
      }

      # IAM bindings
      iam_members = [
        {
          role   = "roles/storage.legacyBucketWriter"
          member = "group:cloud-storage-analytics@google.com"
        }
      ]
    }
  }

  # Filestore instances from region configuration
  filestore_instances = local.storage_config.filestore_instances

  # Cross-region replication configuration
  cross_region_replication = {
    enable_replication = true
    primary_region = "us-central1"

    replication_rules = [
      {
        source_bucket = "your-prod-project-id-static-assets-usc1"
        destination_bucket = "your-prod-project-id-static-assets-${local.region_short}"
        replication_time = "15m"
        delete_sync = true
      },
      {
        source_bucket = "your-prod-project-id-application-data-usc1"
        destination_bucket = "your-prod-project-id-application-data-${local.region_short}"
        replication_time = "15m"
        delete_sync = false
      }
    ]
  }

  # Storage Transfer Service for automated replication
  storage_transfer_jobs = {
    static_assets_replication = {
      description = "Replicate static assets from primary to DR region"
      status = "ENABLED"

      schedule = {
        schedule_start_date = "2024-01-01"
        start_time_of_day = {
          hours = 2
          minutes = 0
          seconds = 0
        }
        repeat_interval = "86400s"  # Daily
      }

      transfer_spec = {
        gcs_data_source = {
          bucket_name = "your-prod-project-id-static-assets-usc1"
        }
        gcs_data_sink = {
          bucket_name = "your-prod-project-id-static-assets-${local.region_short}"
        }
        transfer_options = {
          overwrite_objects_already_existing_in_sink = false
          delete_objects_unique_in_sink = false
          delete_objects_from_source_after_transfer = false
        }
      }

      notification_config = {
        pubsub_topic = "projects/your-prod-project-id/topics/storage-transfer-events"
        event_types = ["TRANSFER_OPERATION_SUCCESS", "TRANSFER_OPERATION_FAILED"]
        payload_format = "JSON"
      }
    }

    application_data_replication = {
      description = "Replicate application data from primary to DR region"
      status = "ENABLED"

      schedule = {
        schedule_start_date = "2024-01-01"
        start_time_of_day = {
          hours = 1
          minutes = 0
          seconds = 0
        }
        repeat_interval = "3600s"  # Hourly
      }

      transfer_spec = {
        gcs_data_source = {
          bucket_name = "your-prod-project-id-application-data-usc1"
        }
        gcs_data_sink = {
          bucket_name = "your-prod-project-id-application-data-${local.region_short}"
        }
        transfer_options = {
          overwrite_objects_already_existing_in_sink = true
          delete_objects_unique_in_sink = false
          delete_objects_from_source_after_transfer = false
        }
      }
    }
  }

  # Storage monitoring and alerting
  monitoring_config = {
    # Custom metrics
    custom_metrics = [
      {
        name = "storage_replication_lag"
        metric_kind = "GAUGE"
        value_type = "DOUBLE"
        description = "Storage replication lag in minutes"
      },
      {
        name = "storage_capacity_utilization"
        metric_kind = "GAUGE"
        value_type = "DOUBLE"
        description = "Storage capacity utilization percentage"
      }
    ]

    # Alert policies
    alert_policies = [
      {
        display_name = "Storage Replication Failure"
        conditions = [{
          display_name = "Replication job failed"
          condition_threshold = {
            filter = "resource.type=\"storage_transfer_job\""
            comparison = "COMPARISON_EQUAL"
            threshold_value = 1
            duration = "300s"
          }
        }]
        notification_channels = ["projects/your-prod-project-id/notificationChannels/pagerduty-critical"]
      }
    ]
  }

  # Integration with existing resources
  kms_crypto_key = dependency.kms.outputs.crypto_keys.storage

  # Tags for resource organization
  tags = {
    Environment = "production"
    Region = local.region
    RegionShort = local.region_short
    RegionType = "disaster-recovery"
    Team = "platform"
    Component = "storage"
    CostCenter = "engineering"
    Compliance = "required"
    DataClassification = "internal"
    BackupRequired = "true"
    MonitoringRequired = "true"
    DRRole = "secondary"
    DRPriority = "1"
    EncryptionEnabled = "true"
    ReplicationEnabled = "true"
    RetentionEnabled = "true"
  }
}