# Cloud Asset Inventory Module - Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "org_id" {
  description = "The GCP organization ID (required for organization-level feeds)"
  type        = string
  default     = null
}

variable "enable_apis" {
  description = "Whether to enable required GCP APIs"
  type        = bool
  default     = true
}

variable "create_service_account" {
  description = "Whether to create a service account for asset inventory operations"
  type        = bool
  default     = true
}

variable "service_account_id" {
  description = "The service account ID for asset inventory operations"
  type        = string
  default     = "cloud-asset-inventory-sa"
}

variable "service_account_roles" {
  description = "Roles to assign to the asset inventory service account"
  type        = list(string)
  default = [
    "roles/cloudasset.viewer",
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
    "roles/storage.objectAdmin",
    "roles/pubsub.publisher",
    "roles/pubsub.subscriber",
    "roles/cloudfunctions.invoker",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter"
  ]
}

# Asset Feed Configuration
variable "asset_feeds" {
  description = "Configuration for project-level asset feeds"
  type = map(object({
    content_type = string
    asset_types  = optional(list(string))
    asset_names  = optional(list(string))
    pubsub_topic = string
    condition = optional(object({
      expression  = string
      title       = string
      description = optional(string)
      location    = optional(string)
    }))
    relationship_types = optional(list(string))
  }))
  default = {}
}

variable "org_asset_feeds" {
  description = "Configuration for organization-level asset feeds"
  type = map(object({
    content_type = string
    asset_types  = optional(list(string))
    asset_names  = optional(list(string))
    pubsub_topic = string
    condition = optional(object({
      expression  = string
      title       = string
      description = optional(string)
      location    = optional(string)
    }))
    relationship_types = optional(list(string))
  }))
  default = {}
}

variable "folder_asset_feeds" {
  description = "Configuration for folder-level asset feeds"
  type = map(object({
    folder_id    = string
    content_type = string
    asset_types  = optional(list(string))
    asset_names  = optional(list(string))
    pubsub_topic = string
    condition = optional(object({
      expression  = string
      title       = string
      description = optional(string)
      location    = optional(string)
    }))
    relationship_types = optional(list(string))
  }))
  default = {}
}

# Pub/Sub Configuration
variable "create_pubsub_topics" {
  description = "Whether to create Pub/Sub topics for asset feeds"
  type        = bool
  default     = true
}

variable "pubsub_topics" {
  description = "Configuration for Pub/Sub topics"
  type = map(object({
    message_storage_policy = optional(object({
      allowed_persistence_regions = list(string)
    }))
    message_retention_duration = optional(string, "604800s")
    kms_key_name               = optional(string)
    labels                     = optional(map(string), {})
  }))
  default = {}
}

variable "create_pubsub_subscriptions" {
  description = "Whether to create Pub/Sub subscriptions for asset feeds"
  type        = bool
  default     = true
}

variable "pubsub_subscriptions" {
  description = "Configuration for Pub/Sub subscriptions"
  type = map(object({
    topic_name                 = string
    ack_deadline_seconds       = optional(number, 20)
    message_retention_duration = optional(string, "604800s")
    retain_acked_messages      = optional(bool, false)
    enable_message_ordering    = optional(bool, false)
    filter                     = optional(string)
    expiration_policy = optional(object({
      ttl = string
    }))
    push_config = optional(object({
      push_endpoint = string
      attributes    = optional(map(string))
      oidc_token = optional(object({
        service_account_email = string
        audience              = optional(string)
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

# BigQuery Configuration
variable "enable_bigquery_export" {
  description = "Whether to enable BigQuery export for asset inventory"
  type        = bool
  default     = true
}

variable "bigquery_dataset_id" {
  description = "BigQuery dataset ID for asset inventory"
  type        = string
  default     = "cloud_asset_inventory"
}

variable "bigquery_location" {
  description = "Location for BigQuery dataset"
  type        = string
  default     = "US"
}

variable "bigquery_table_expiration_ms" {
  description = "Default table expiration in milliseconds"
  type        = number
  default     = null
}

variable "bigquery_partition_expiration_ms" {
  description = "Default partition expiration in milliseconds"
  type        = number
  default     = null
}

variable "delete_dataset_on_destroy" {
  description = "Whether to delete dataset contents on destroy"
  type        = bool
  default     = false
}

variable "bigquery_dataset_access" {
  description = "Access configuration for BigQuery dataset"
  type = list(object({
    role           = optional(string)
    user_by_email  = optional(string)
    group_by_email = optional(string)
    domain         = optional(string)
    special_group  = optional(string)
    dataset = optional(object({
      project_id   = string
      dataset_id   = string
      target_types = list(string)
    }))
    routine = optional(object({
      project_id = string
      dataset_id = string
      routine_id = string
    }))
    view = optional(object({
      project_id = string
      dataset_id = string
      table_id   = string
    }))
  }))
  default = []
}

variable "bigquery_dataset_labels" {
  description = "Labels for BigQuery dataset"
  type        = map(string)
  default     = {}
}

variable "bigquery_tables" {
  description = "Configuration for BigQuery tables"
  type = map(object({
    description = string
    schema      = string
    time_partitioning = optional(object({
      type                     = string
      expiration_ms            = optional(number)
      field                    = optional(string)
      require_partition_filter = optional(bool, false)
    }))
    range_partitioning = optional(object({
      field = string
      range = object({
        start    = number
        end      = number
        interval = number
      })
    }))
    clustering = optional(object({
      fields = list(string)
    }))
    labels = optional(map(string), {})
  }))
  default = {}
}

# Cloud Storage Configuration
variable "enable_storage_export" {
  description = "Whether to enable Cloud Storage export for asset inventory"
  type        = bool
  default     = true
}

variable "storage_bucket_name" {
  description = "Name of the Cloud Storage bucket for asset exports"
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
  default     = false
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
      created_before             = optional(string)
      with_state                 = optional(string)
      matches_storage_class      = optional(list(string))
      num_newer_versions         = optional(number)
      custom_time_before         = optional(string)
      days_since_custom_time     = optional(number)
      days_since_noncurrent_time = optional(number)
      noncurrent_time_before     = optional(string)
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

# Cloud Functions Configuration
variable "enable_cloud_functions" {
  description = "Whether to enable Cloud Functions for asset processing"
  type        = bool
  default     = false
}

variable "cloud_functions" {
  description = "Configuration for Cloud Functions"
  type = map(object({
    region                = string
    description           = string
    runtime               = string
    memory_mb             = optional(number, 256)
    timeout               = optional(number, 60)
    entry_point           = string
    service_account_email = optional(string)
    source_bucket         = string
    source_object         = string
    event_trigger = optional(object({
      event_type           = string
      resource             = string
      failure_policy_retry = optional(bool, false)
    }))
    https_trigger_enabled = optional(bool, false)
    https_security_level  = optional(string, "SECURE_ALWAYS")
    environment_variables = optional(map(string), {})
    labels                = optional(map(string), {})
  }))
  default = {}
}

# Cloud Scheduler Configuration
variable "enable_scheduled_exports" {
  description = "Whether to enable scheduled asset exports"
  type        = bool
  default     = false
}

variable "scheduled_export_jobs" {
  description = "Configuration for scheduled export jobs"
  type = map(object({
    region      = string
    schedule    = string
    time_zone   = optional(string, "UTC")
    description = string
    pubsub_target = optional(object({
      topic_name = string
      data       = optional(string)
      attributes = optional(map(string))
    }))
    http_target = optional(object({
      uri         = string
      http_method = optional(string, "POST")
      body        = optional(string)
      headers     = optional(map(string))
      oauth_token = optional(object({
        service_account_email = string
        scope                 = optional(string)
      }))
      oidc_token = optional(object({
        service_account_email = string
        audience              = optional(string)
      }))
    }))
    retry_config = optional(object({
      retry_count          = optional(number, 3)
      max_retry_duration   = optional(string, "0s")
      min_backoff_duration = optional(string, "5s")
      max_backoff_duration = optional(string, "3600s")
      max_doublings        = optional(number, 16)
    }))
  }))
  default = {}
}

# Monitoring Configuration
variable "enable_monitoring" {
  description = "Whether to enable monitoring for asset inventory"
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
  default     = "Cloud Asset Inventory Dashboard"
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
    combiner               = optional(string, "OR")
    enabled                = optional(bool, true)
    documentation          = optional(string)
    condition_display_name = string
    filter                 = string
    duration               = string
    comparison             = string
    threshold_value        = number
    alignment_period       = optional(string, "60s")
    per_series_aligner     = optional(string, "ALIGN_RATE")
    cross_series_reducer   = optional(string, "REDUCE_SUM")
    group_by_fields        = optional(list(string), [])
    trigger_count          = optional(number)
    trigger_percent        = optional(number)
    notification_channels  = optional(list(string), [])
    auto_close_duration    = optional(string, "86400s")
    rate_limit             = optional(string)
  }))
  default = {}
}

# IAM Configuration
variable "bigquery_dataset_iam_bindings" {
  description = "IAM bindings for BigQuery dataset"
  type = map(object({
    role    = string
    members = list(string)
  }))
  default = {}
}

variable "storage_bucket_iam_bindings" {
  description = "IAM bindings for Cloud Storage bucket"
  type = map(object({
    role    = string
    members = list(string)
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

# Logging Configuration
variable "enable_audit_logging" {
  description = "Whether to enable audit logging for asset inventory"
  type        = bool
  default     = true
}

variable "audit_log_sink_name" {
  description = "Name of the audit log sink"
  type        = string
  default     = "asset-inventory-audit-sink"
}

variable "audit_log_destination" {
  description = "Destination for audit logs (e.g., Cloud Storage bucket, BigQuery dataset)"
  type        = string
  default     = ""
}

# Security Center Integration
variable "enable_security_center_integration" {
  description = "Whether to enable Security Command Center integration"
  type        = bool
  default     = false
}

variable "security_center_source_name" {
  description = "Name of the Security Command Center source"
  type        = string
  default     = "cloud-asset-inventory-findings"
}

# Advanced Configuration
variable "enable_compliance_monitoring" {
  description = "Whether to enable compliance monitoring features"
  type        = bool
  default     = false
}

variable "compliance_policies" {
  description = "Compliance policies to monitor"
  type = map(object({
    policy_name        = string
    policy_description = string
    asset_filters      = list(string)
    compliance_rules = list(object({
      rule_name       = string
      rule_expression = string
      severity        = string
    }))
    notification_config = optional(object({
      enable_notifications  = bool
      notification_channels = list(string)
    }))
  }))
  default = {}
}

variable "enable_data_governance" {
  description = "Whether to enable data governance features"
  type        = bool
  default     = false
}

variable "data_governance_config" {
  description = "Configuration for data governance"
  type = object({
    enable_data_classification = bool
    enable_data_lineage        = bool
    enable_access_monitoring   = bool
    classification_rules = optional(list(object({
      rule_name            = string
      asset_filter         = string
      classification_level = string
      tags                 = map(string)
    })))
    lineage_tracking = optional(object({
      track_data_movement   = bool
      track_transformations = bool
      retention_days        = number
    }))
  })
  default = {
    enable_data_classification = false
    enable_data_lineage        = false
    enable_access_monitoring   = false
  }
}

variable "enable_cost_analysis" {
  description = "Whether to enable cost analysis features"
  type        = bool
  default     = false
}

variable "cost_analysis_config" {
  description = "Configuration for cost analysis"
  type = object({
    enable_resource_utilization = bool
    enable_cost_optimization    = bool
    enable_rightsizing          = bool
    analysis_frequency          = optional(string, "DAILY")
    cost_thresholds = optional(object({
      daily_threshold   = optional(number)
      monthly_threshold = optional(number)
      project_threshold = optional(number)
    }))
  })
  default = {
    enable_resource_utilization = false
    enable_cost_optimization    = false
    enable_rightsizing          = false
  }
}

variable "enable_security_insights" {
  description = "Whether to enable security insights features"
  type        = bool
  default     = false
}

variable "security_insights_config" {
  description = "Configuration for security insights"
  type = object({
    enable_vulnerability_scanning = bool
    enable_misconfig_detection    = bool
    enable_access_analysis        = bool
    enable_threat_detection       = bool
    security_standards            = optional(list(string), [])
    scan_frequency                = optional(string, "DAILY")
    severity_levels               = optional(list(string), ["HIGH", "CRITICAL"])
  })
  default = {
    enable_vulnerability_scanning = false
    enable_misconfig_detection    = false
    enable_access_analysis        = false
    enable_threat_detection       = false
  }
}

variable "enable_resource_hierarchy_analysis" {
  description = "Whether to enable resource hierarchy analysis"
  type        = bool
  default     = false
}

variable "resource_hierarchy_config" {
  description = "Configuration for resource hierarchy analysis"
  type = object({
    track_organizational_changes = bool
    track_project_changes        = bool
    track_folder_changes         = bool
    track_iam_changes            = bool
    change_detection_rules = optional(list(object({
      rule_name   = string
      scope       = string
      event_types = list(string)
      conditions  = list(string)
    })))
  })
  default = {
    track_organizational_changes = false
    track_project_changes        = false
    track_folder_changes         = false
    track_iam_changes            = false
  }
}

variable "enable_automation" {
  description = "Whether to enable automation features"
  type        = bool
  default     = false
}

variable "automation_config" {
  description = "Configuration for automation"
  type = object({
    enable_auto_remediation     = bool
    enable_policy_enforcement   = bool
    enable_automated_tagging    = bool
    enable_lifecycle_management = bool
    remediation_rules = optional(list(object({
      rule_name    = string
      trigger      = string
      action       = string
      target_scope = string
    })))
    tagging_rules = optional(list(object({
      rule_name  = string
      scope      = string
      tags       = map(string)
      conditions = list(string)
    })))
  })
  default = {
    enable_auto_remediation     = false
    enable_policy_enforcement   = false
    enable_automated_tagging    = false
    enable_lifecycle_management = false
  }
}

variable "export_formats" {
  description = "Export formats to support"
  type = object({
    enable_json_export    = bool
    enable_csv_export     = bool
    enable_parquet_export = bool
    enable_avro_export    = bool
    compression_enabled   = optional(bool, true)
    compression_format    = optional(string, "GZIP")
  })
  default = {
    enable_json_export    = true
    enable_csv_export     = false
    enable_parquet_export = false
    enable_avro_export    = false
  }
}

variable "data_retention_config" {
  description = "Configuration for data retention"
  type = object({
    raw_data_retention_days       = number
    processed_data_retention_days = number
    audit_log_retention_days      = number
    enable_automatic_cleanup      = bool
    cleanup_schedule              = optional(string, "0 2 * * *")
  })
  default = {
    raw_data_retention_days       = 365
    processed_data_retention_days = 90
    audit_log_retention_days      = 30
    enable_automatic_cleanup      = true
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
    data_mapping   = optional(map(string))
    sync_frequency = optional(string, "HOURLY")
    enabled        = optional(bool, true)
  }))
  default = {}
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

variable "custom_asset_types" {
  description = "Custom asset types to monitor"
  type = list(object({
    asset_type        = string
    description       = string
    api_version       = string
    resource_name     = string
    collection_method = string
  }))
  default = []
}

variable "notification_config" {
  description = "Global notification configuration"
  type = object({
    enable_email_notifications   = bool
    enable_slack_notifications   = bool
    enable_webhook_notifications = bool
    email_recipients             = optional(list(string))
    slack_webhook_url            = optional(string)
    custom_webhooks = optional(list(object({
      name    = string
      url     = string
      headers = optional(map(string))
    })))
  })
  default = {
    enable_email_notifications   = false
    enable_slack_notifications   = false
    enable_webhook_notifications = false
  }
}