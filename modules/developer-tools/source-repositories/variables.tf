# Cloud Source Repositories Module - Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "enable_apis" {
  description = "Whether to enable required GCP APIs"
  type        = bool
  default     = true
}

variable "create_service_account" {
  description = "Whether to create a service account for Source Repositories operations"
  type        = bool
  default     = true
}

variable "service_account_id" {
  description = "The service account ID for Source Repositories operations"
  type        = string
  default     = "source-repos-sa"
}

variable "service_account_roles" {
  description = "Roles to assign to the Source Repositories service account"
  type        = list(string)
  default = [
    "roles/source.reader",
    "roles/source.writer",
    "roles/cloudbuild.builds.builder",
    "roles/storage.objectAdmin",
    "roles/pubsub.publisher",
    "roles/secretmanager.secretAccessor",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter"
  ]
}

# Repository Configuration
variable "repositories" {
  description = "Configuration for Cloud Source Repositories"
  type = map(object({
    description = optional(string)
  }))
  default = {}
}

variable "repository_iam_bindings" {
  description = "IAM bindings for Source Repositories"
  type = map(object({
    repository_name = string
    role           = string
    members        = list(string)
  }))
  default = {}
}

# Cloud Build Integration
variable "enable_cloud_build_integration" {
  description = "Whether to enable Cloud Build integration"
  type        = bool
  default     = true
}

variable "cloud_build_triggers" {
  description = "Configuration for Cloud Build triggers"
  type = map(object({
    repository_name = string
    description    = string
    branch_name    = optional(string)
    tag_name       = optional(string)
    commit_sha     = optional(string)
    dir            = optional(string)
    invert_regex   = optional(bool, false)
    build_config = optional(object({
      steps = list(object({
        name       = string
        args       = optional(list(string))
        env        = optional(list(string))
        id         = optional(string)
        entrypoint = optional(string)
        dir        = optional(string)
        secret_env = optional(list(string))
        timeout    = optional(string)
        timing     = optional(string)
        wait_for   = optional(list(string))
        volumes = optional(list(object({
          name = string
          path = string
        })))
      }))
      timeout         = optional(string)
      images          = optional(list(string))
      substitutions   = optional(map(string))
      tags            = optional(list(string))
      logs_bucket     = optional(string)
      machine_type    = optional(string)
      disk_size_gb    = optional(number)
      source_provenance_hash = optional(list(string))
      artifacts = optional(object({
        images = optional(list(string))
        objects = optional(object({
          location = string
          paths    = list(string)
        }))
      }))
      options = optional(object({
        disk_size_gb                = optional(number)
        machine_type               = optional(string)
        requested_verify_option    = optional(string)
        source_provenance_hash     = optional(list(string))
        substitution_option        = optional(string)
        dynamic_substitutions      = optional(bool)
        log_streaming_option       = optional(string)
        worker_pool                = optional(string)
        logging                    = optional(string)
        env                        = optional(list(string))
        secret_env                 = optional(list(string))
        volumes = optional(list(object({
          name = string
          path = string
        })))
      }))
      secrets = optional(list(object({
        kms_key_name = string
        secret_env   = map(string)
      })))
      available_secrets = optional(object({
        secret_manager = optional(list(object({
          env          = string
          version_name = string
        })))
      }))
    }))
    filename       = optional(string)
    ignored_files  = optional(list(string))
    included_files = optional(list(string))
    disabled       = optional(bool, false)
    substitutions  = optional(map(string))
    service_account = optional(string)
    tags           = optional(list(string))
  }))
  default = {}
}

# Pub/Sub Configuration
variable "enable_pubsub_notifications" {
  description = "Whether to enable Pub/Sub notifications for repository events"
  type        = bool
  default     = false
}

variable "pubsub_topics" {
  description = "Configuration for Pub/Sub topics"
  type = map(object({
    message_storage_policy = optional(object({
      allowed_persistence_regions = list(string)
    }))
    message_retention_duration = optional(string, "604800s")
    kms_key_name              = optional(string)
    labels                    = optional(map(string), {})
  }))
  default = {}
}

variable "pubsub_subscriptions" {
  description = "Configuration for Pub/Sub subscriptions"
  type = map(object({
    topic_name                 = string
    ack_deadline_seconds       = optional(number, 20)
    message_retention_duration = optional(string, "604800s")
    retain_acked_messages     = optional(bool, false)
    enable_message_ordering   = optional(bool, false)
    filter                    = optional(string)
    expiration_policy = optional(object({
      ttl = string
    }))
    push_config = optional(object({
      push_endpoint = string
      attributes    = optional(map(string))
      oidc_token = optional(object({
        service_account_email = string
        audience             = optional(string)
      }))
    }))
    retry_policy = optional(object({
      minimum_backoff = optional(string)
      maximum_backoff = optional(string)
    }))
    dead_letter_policy = optional(object({
      dead_letter_topic     = string
      max_delivery_attempts = optional(number, 5)
    }))
    labels = optional(map(string), {})
  }))
  default = {}
}

variable "pubsub_topic_iam_bindings" {
  description = "IAM bindings for Pub/Sub topics"
  type = map(object({
    topic_name = string
    role       = string
    members    = list(string)
  }))
  default = {}
}

# Cloud Storage Configuration
variable "enable_build_artifacts_storage" {
  description = "Whether to enable Cloud Storage for build artifacts"
  type        = bool
  default     = true
}

variable "build_artifacts_bucket_name" {
  description = "Name of the Cloud Storage bucket for build artifacts"
  type        = string
  default     = ""
}

variable "storage_bucket_location" {
  description = "Location for Cloud Storage bucket"
  type        = string
  default     = "US"
}

variable "force_destroy_bucket" {
  description = "Whether to force destroy bucket with contents"
  type        = bool
  default     = false
}

variable "uniform_bucket_level_access" {
  description = "Whether to enable uniform bucket-level access"
  type        = bool
  default     = true
}

variable "bucket_versioning_enabled" {
  description = "Whether to enable bucket versioning"
  type        = bool
  default     = true
}

variable "bucket_lifecycle_rules" {
  description = "Lifecycle rules for the storage bucket"
  type = list(object({
    action = object({
      type          = string
      storage_class = optional(string)
    })
    condition = object({
      age                        = optional(number)
      created_before            = optional(string)
      with_state                = optional(string)
      matches_storage_class     = optional(list(string))
      num_newer_versions        = optional(number)
      custom_time_before        = optional(string)
      days_since_custom_time    = optional(number)
      days_since_noncurrent_time = optional(number)
      noncurrent_time_before    = optional(string)
    })
  }))
  default = []
}

variable "bucket_retention_policy" {
  description = "Retention policy for the storage bucket"
  type = object({
    is_locked        = bool
    retention_period = number
  })
  default = null
}

variable "bucket_encryption_key" {
  description = "KMS key for bucket encryption"
  type        = string
  default     = null
}

variable "bucket_logging_config" {
  description = "Logging configuration for the bucket"
  type = object({
    log_bucket        = string
    log_object_prefix = optional(string)
  })
  default = null
}

variable "storage_bucket_labels" {
  description = "Labels for Cloud Storage bucket"
  type        = map(string)
  default     = {}
}

variable "storage_bucket_iam_bindings" {
  description = "IAM bindings for Cloud Storage bucket"
  type = map(object({
    role    = string
    members = list(string)
  }))
  default = {}
}

# Secret Management Configuration
variable "enable_secret_management" {
  description = "Whether to enable Secret Manager for repository credentials"
  type        = bool
  default     = false
}

variable "repository_secrets" {
  description = "Configuration for repository secrets"
  type = map(object({
    labels = optional(map(string), {})
    replication_policy = optional(object({
      automatic = optional(object({
        customer_managed_encryption = optional(object({
          kms_key_name = string
        }))
      }))
      user_managed = optional(object({
        replicas = list(object({
          location = string
          customer_managed_encryption = optional(object({
            kms_key_name = string
          }))
        }))
      }))
    }))
  }))
  default = {}
}

variable "repository_secret_versions" {
  description = "Configuration for repository secret versions"
  type = map(object({
    secret_name = string
    secret_data = string
  }))
  default   = {}
  sensitive = true
}

# Webhook Functions Configuration
variable "enable_webhook_functions" {
  description = "Whether to enable Cloud Functions for webhooks"
  type        = bool
  default     = false
}

variable "webhook_functions" {
  description = "Configuration for webhook Cloud Functions"
  type = map(object({
    region      = string
    description = string
    runtime     = string
    memory_mb   = optional(number, 256)
    timeout     = optional(number, 60)
    entry_point = string
    service_account_email = optional(string)
    source_bucket = string
    source_object = string
    event_trigger = optional(object({
      event_type             = string
      resource              = string
      failure_policy_retry  = optional(bool, false)
    }))
    https_trigger_enabled = optional(bool, false)
    https_security_level  = optional(string, "SECURE_ALWAYS")
    environment_variables = optional(map(string), {})
    labels               = optional(map(string), {})
  }))
  default = {}
}

# Monitoring Configuration
variable "enable_monitoring" {
  description = "Whether to enable monitoring for Source Repositories"
  type        = bool
  default     = true
}

variable "create_dashboard" {
  description = "Whether to create a monitoring dashboard"
  type        = bool
  default     = true
}

variable "dashboard_display_name" {
  description = "Display name for the monitoring dashboard"
  type        = string
  default     = "Cloud Source Repositories Dashboard"
}

variable "notification_channels" {
  description = "List of notification channel IDs for alerts"
  type        = list(string)
  default     = []
}

variable "alert_policies" {
  description = "Alert policies configuration"
  type = map(object({
    display_name           = string
    combiner              = optional(string, "OR")
    enabled               = optional(bool, true)
    documentation         = optional(string)
    condition_display_name = string
    filter                = string
    duration              = string
    comparison            = string
    threshold_value       = number
    alignment_period      = optional(string, "60s")
    per_series_aligner    = optional(string, "ALIGN_RATE")
    cross_series_reducer  = optional(string, "REDUCE_SUM")
    group_by_fields       = optional(list(string), [])
    trigger_count         = optional(number)
    trigger_percent       = optional(number)
    notification_channels = optional(list(string), [])
    auto_close_duration   = optional(string, "86400s")
    rate_limit           = optional(string)
  }))
  default = {}
}

# Logging Configuration
variable "enable_audit_logging" {
  description = "Whether to enable audit logging for Source Repositories"
  type        = bool
  default     = true
}

variable "audit_log_sink_name" {
  description = "Name of the audit log sink"
  type        = string
  default     = "source-repos-audit-sink"
}

variable "audit_log_destination" {
  description = "Destination for audit logs (e.g., Cloud Storage bucket, BigQuery dataset)"
  type        = string
  default     = ""
}

# Advanced Configuration
variable "enable_branch_protection" {
  description = "Whether to enable branch protection features"
  type        = bool
  default     = false
}

variable "branch_protection_rules" {
  description = "Branch protection rules configuration"
  type = map(object({
    repository_name = string
    branch_pattern  = string
    protection_rules = object({
      require_pull_request     = bool
      required_status_checks   = list(string)
      require_code_owner_review = bool
      dismiss_stale_reviews    = bool
      require_signed_commits   = bool
      enforce_admins          = bool
      restrictions = optional(object({
        users = list(string)
        teams = list(string)
      }))
    })
  }))
  default = {}
}

variable "enable_code_scanning" {
  description = "Whether to enable code scanning features"
  type        = bool
  default     = false
}

variable "code_scanning_config" {
  description = "Code scanning configuration"
  type = map(object({
    repository_name = string
    scan_types = list(string)
    scan_schedule  = optional(string, "daily")
    exclude_paths  = optional(list(string))
    severity_threshold = optional(string, "medium")
    fail_on_findings   = optional(bool, false)
  }))
  default = {}
}

variable "enable_dependency_scanning" {
  description = "Whether to enable dependency vulnerability scanning"
  type        = bool
  default     = false
}

variable "dependency_scanning_config" {
  description = "Dependency scanning configuration"
  type = object({
    scan_frequency       = string
    auto_update_enabled  = bool
    severity_threshold   = string
    package_ecosystems   = list(string)
    exclude_paths       = optional(list(string))
    notification_config = optional(object({
      enable_notifications = bool
      notification_channels = list(string)
    }))
  })
  default = {
    scan_frequency      = "daily"
    auto_update_enabled = false
    severity_threshold  = "medium"
    package_ecosystems  = ["npm", "pip", "maven", "go"]
  }
}

variable "enable_container_scanning" {
  description = "Whether to enable container vulnerability scanning"
  type        = bool
  default     = false
}

variable "container_scanning_config" {
  description = "Container scanning configuration"
  type = object({
    scan_on_build       = bool
    scan_on_push        = bool
    vulnerability_threshold = string
    fail_on_critical    = bool
    whitelist_cves     = optional(list(string))
    scan_timeout       = optional(string, "300s")
  })
  default = {
    scan_on_build       = true
    scan_on_push        = true
    vulnerability_threshold = "medium"
    fail_on_critical    = true
  }
}

variable "enable_performance_monitoring" {
  description = "Whether to enable performance monitoring for repositories"
  type        = bool
  default     = false
}

variable "performance_monitoring_config" {
  description = "Performance monitoring configuration"
  type = object({
    enable_build_metrics     = bool
    enable_clone_metrics     = bool
    enable_api_metrics       = bool
    metrics_retention_days   = optional(number, 30)
    alert_thresholds = optional(object({
      build_duration_threshold_minutes = optional(number, 30)
      clone_time_threshold_seconds     = optional(number, 60)
      api_error_rate_threshold_percent = optional(number, 5)
    }))
  })
  default = {
    enable_build_metrics = true
    enable_clone_metrics = true
    enable_api_metrics   = true
  }
}

variable "enable_compliance_monitoring" {
  description = "Whether to enable compliance monitoring"
  type        = bool
  default     = false
}

variable "compliance_config" {
  description = "Compliance monitoring configuration"
  type = object({
    compliance_standards = list(string)
    audit_frequency     = optional(string, "daily")
    compliance_checks = list(object({
      check_name    = string
      check_type    = string
      target_repos  = list(string)
      severity      = string
    }))
    reporting_config = optional(object({
      generate_reports = bool
      report_frequency = string
      report_recipients = list(string)
    }))
  })
  default = {
    compliance_standards = []
    compliance_checks    = []
  }
}

variable "enable_backup_and_recovery" {
  description = "Whether to enable backup and recovery features"
  type        = bool
  default     = false
}

variable "backup_config" {
  description = "Backup and recovery configuration"
  type = object({
    backup_frequency     = string
    backup_retention_days = number
    backup_destination   = string
    enable_point_in_time_recovery = bool
    cross_region_backup  = optional(bool, false)
    backup_encryption_key = optional(string)
  })
  default = {
    backup_frequency     = "daily"
    backup_retention_days = 30
    backup_destination   = ""
    enable_point_in_time_recovery = false
  }
}

variable "integration_configs" {
  description = "Configuration for third-party integrations"
  type = map(object({
    integration_type = string
    endpoint_url     = string
    authentication = object({
      type        = string
      credentials = map(string)
    })
    sync_frequency = optional(string, "hourly")
    enabled       = optional(bool, true)
    repositories  = optional(list(string))
  }))
  default = {}
}

variable "workflow_templates" {
  description = "Pre-defined workflow templates for common CI/CD patterns"
  type = map(object({
    template_type = string
    description   = string
    build_steps   = list(map(string))
    trigger_config = object({
      branch_patterns = list(string)
      tag_patterns   = optional(list(string))
      file_patterns  = optional(list(string))
    })
    variables = optional(map(string))
  }))
  default = {}
}

variable "enable_automated_testing" {
  description = "Whether to enable automated testing features"
  type        = bool
  default     = false
}

variable "automated_testing_config" {
  description = "Automated testing configuration"
  type = object({
    test_frameworks = list(string)
    test_environments = list(object({
      name        = string
      runtime     = string
      environment_vars = map(string)
    }))
    coverage_threshold = optional(number, 80)
    parallel_testing   = optional(bool, true)
    test_timeout      = optional(string, "600s")
  })
  default = {
    test_frameworks = []
    test_environments = []
  }
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Network tags to apply to resources"
  type        = list(string)
  default     = []
}

# Environment-specific configurations
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "custom_build_environments" {
  description = "Custom build environments configuration"
  type = map(object({
    base_image    = string
    packages      = list(string)
    environment_vars = map(string)
    build_timeout = optional(string, "3600s")
    cpu_count     = optional(number, 1)
    memory_gb     = optional(number, 4)
    disk_size_gb  = optional(number, 100)
  }))
  default = {}
}

variable "notification_config" {
  description = "Global notification configuration"
  type = object({
    enable_email_notifications = bool
    enable_slack_notifications = bool
    enable_webhook_notifications = bool
    email_recipients = optional(list(string))
    slack_webhook_url = optional(string)
    custom_webhooks = optional(list(object({
      name = string
      url  = string
      headers = optional(map(string))
      events  = list(string)
    })))
  })
  default = {
    enable_email_notifications = false
    enable_slack_notifications = false
    enable_webhook_notifications = false
  }
}

variable "repository_templates" {
  description = "Repository templates for standardized project setup"
  type = map(object({
    template_name   = string
    description     = string
    template_source = string
    variables = map(object({
      type        = string
      description = string
      default     = optional(string)
      required    = optional(bool, false)
    }))
    post_creation_hooks = optional(list(string))
  }))
  default = {}
}