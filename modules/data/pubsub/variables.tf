# Pub/Sub Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "topic_name" {
  description = "Name of the Pub/Sub topic"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Topic Configuration
variable "message_retention_duration" {
  description = "How long to retain messages in the topic"
  type        = string
  default     = null
}

variable "kms_key_name" {
  description = "KMS key name for topic encryption"
  type        = string
  default     = null
}

variable "allowed_persistence_regions" {
  description = "List of regions where messages may be persisted"
  type        = list(string)
  default     = null
}

variable "topic_labels" {
  description = "Labels for the topic"
  type        = map(string)
  default     = {}
}

# Schema Configuration
variable "create_schema" {
  description = "Create a Pub/Sub schema"
  type        = bool
  default     = false
}

variable "schema_name" {
  description = "Name of the schema"
  type        = string
  default     = null
}

variable "schema_type" {
  description = "Type of schema (PROTOCOL_BUFFER or AVRO)"
  type        = string
  default     = "PROTOCOL_BUFFER"

  validation {
    condition     = contains(["PROTOCOL_BUFFER", "AVRO"], var.schema_type)
    error_message = "schema_type must be PROTOCOL_BUFFER or AVRO"
  }
}

variable "schema_definition" {
  description = "The schema definition"
  type        = string
  default     = null
}

variable "existing_schema_name" {
  description = "Name of existing schema to use"
  type        = string
  default     = null
}

variable "schema_encoding" {
  description = "Encoding for schema (JSON or BINARY)"
  type        = string
  default     = "JSON"

  validation {
    condition     = contains(["JSON", "BINARY"], var.schema_encoding)
    error_message = "schema_encoding must be JSON or BINARY"
  }
}

# Dead Letter Configuration
variable "create_dead_letter_topic" {
  description = "Create a dead letter topic"
  type        = bool
  default     = false
}

variable "dead_letter_topic_name" {
  description = "Name of the dead letter topic"
  type        = string
  default     = null
}

variable "dead_letter_message_retention_duration" {
  description = "Message retention for dead letter topic"
  type        = string
  default     = "604800s" # 7 days
}

variable "dead_letter_kms_key_name" {
  description = "KMS key for dead letter topic"
  type        = string
  default     = null
}

variable "dead_letter_max_delivery_attempts" {
  description = "Default max delivery attempts for dead letter policy"
  type        = number
  default     = 5
}

variable "create_dead_letter_monitoring_subscription" {
  description = "Create monitoring subscription for dead letter topic"
  type        = bool
  default     = true
}

# Subscriptions
variable "subscriptions" {
  description = "Map of subscriptions to create"
  type = map(object({
    labels                       = optional(map(string))
    ack_deadline_seconds         = optional(number)
    message_retention_duration   = optional(string)
    retain_acked_messages        = optional(bool)
    ttl                          = optional(string)
    enable_dead_letter_policy    = optional(bool)
    dead_letter_topic            = optional(string)
    max_delivery_attempts        = optional(number)
    enable_exactly_once_delivery = optional(bool)
    enable_message_ordering      = optional(bool)
    filter                       = optional(string)

    retry_policy = optional(object({
      minimum_backoff = optional(string)
      maximum_backoff = optional(string)
    }))

    push_config = optional(object({
      push_endpoint = string
      attributes    = optional(map(string))
      oidc_token = optional(object({
        service_account_email = string
        audience              = optional(string)
      }))
      no_wrapper = optional(object({
        write_metadata = bool
      }))
    }))

    bigquery_config = optional(object({
      table                 = string
      use_topic_schema      = optional(bool)
      write_metadata        = optional(bool)
      drop_unknown_fields   = optional(bool)
      use_table_schema      = optional(bool)
      service_account_email = optional(string)
    }))

    cloud_storage_config = optional(object({
      bucket                   = string
      filename_prefix          = optional(string)
      filename_suffix          = optional(string)
      filename_datetime_format = optional(string)
      max_duration             = optional(string)
      max_bytes                = optional(number)
      state                    = optional(string)
      service_account_email    = optional(string)
      avro_config = optional(object({
        write_metadata   = optional(bool)
        use_topic_schema = optional(bool)
      }))
    }))
  }))
  default = {}
}

variable "subscription_labels" {
  description = "Default labels for subscriptions"
  type        = map(string)
  default     = {}
}

# IAM Configuration
variable "topic_iam_policy" {
  description = "IAM policy document for the topic"
  type        = string
  default     = null
}

variable "topic_iam_bindings" {
  description = "IAM role bindings for the topic"
  type        = map(list(string))
  default     = {}
}

variable "topic_iam_binding_conditions" {
  description = "Conditions for topic IAM bindings"
  type = map(object({
    title       = string
    description = optional(string)
    expression  = string
  }))
  default = {}
}

variable "topic_iam_members" {
  description = "Individual IAM member bindings for the topic"
  type = map(object({
    role   = string
    member = string
    condition = optional(object({
      title       = string
      description = optional(string)
      expression  = string
    }))
  }))
  default = {}
}

variable "subscription_iam_members" {
  description = "Individual IAM member bindings for subscriptions"
  type = map(object({
    subscription = string
    role         = string
    member       = string
    condition = optional(object({
      title       = string
      description = optional(string)
      expression  = string
    }))
  }))
  default = {}
}

# Monitoring
variable "create_monitoring_alerts" {
  description = "Create monitoring alert policies"
  type        = bool
  default     = false
}

variable "monitoring_alerts" {
  description = "Map of monitoring alert policies"
  type = map(object({
    display_name           = string
    condition_display_name = string
    filter                 = string
    threshold_value        = number
    combiner               = optional(string)
    enabled                = optional(bool)
    duration               = optional(string)
    comparison             = optional(string)
    alignment_period       = optional(string)
    per_series_aligner     = optional(string)
    cross_series_reducer   = optional(string)
    group_by_fields        = optional(list(string))
    trigger_count          = optional(number)
    trigger_percent        = optional(number)
    notification_channels  = optional(list(string))
    auto_close             = optional(string)
    rate_limit = optional(object({
      period = string
    }))
    documentation_content   = optional(string)
    documentation_mime_type = optional(string)
    documentation_subject   = optional(string)
    labels                  = optional(map(string))
  }))
  default = {}
}

variable "create_monitoring_dashboard" {
  description = "Create monitoring dashboard"
  type        = bool
  default     = false
}

# Snapshots
variable "snapshots" {
  description = "Map of snapshots to create"
  type = map(object({
    subscription = string
    labels       = optional(map(string))
  }))
  default = {}
}

# Pub/Sub Lite Configuration
variable "create_lite_topic" {
  description = "Create a Pub/Sub Lite topic"
  type        = bool
  default     = false
}

variable "lite_topic_name" {
  description = "Name of the Pub/Sub Lite topic"
  type        = string
  default     = null
}

variable "lite_topic_region" {
  description = "Region for Pub/Sub Lite topic"
  type        = string
  default     = null
}

variable "lite_topic_zone" {
  description = "Zone ID for Pub/Sub Lite topic"
  type        = string
  default     = null
}

variable "lite_partition_count" {
  description = "Number of partitions for Lite topic"
  type        = number
  default     = 1
}

variable "lite_publish_capacity_mib_per_sec" {
  description = "Publishing capacity in MiB per second"
  type        = number
  default     = 4
}

variable "lite_subscribe_capacity_mib_per_sec" {
  description = "Subscribe capacity in MiB per second"
  type        = number
  default     = 8
}

variable "lite_retention_bytes_per_partition" {
  description = "Retention bytes per partition"
  type        = string
  default     = "32212254720" # 30 GiB
}

variable "lite_retention_period" {
  description = "Retention period for Lite topic"
  type        = string
  default     = "86400s" # 1 day
}

variable "lite_throughput_reservation" {
  description = "Throughput reservation name"
  type        = string
  default     = null
}

variable "create_lite_subscription" {
  description = "Create a Pub/Sub Lite subscription"
  type        = bool
  default     = false
}

variable "lite_subscription_name" {
  description = "Name of the Pub/Sub Lite subscription"
  type        = string
  default     = null
}

variable "lite_delivery_requirement" {
  description = "Delivery requirement (DELIVER_IMMEDIATELY or DELIVER_AFTER_STORED)"
  type        = string
  default     = "DELIVER_IMMEDIATELY"

  validation {
    condition     = contains(["DELIVER_IMMEDIATELY", "DELIVER_AFTER_STORED"], var.lite_delivery_requirement)
    error_message = "lite_delivery_requirement must be DELIVER_IMMEDIATELY or DELIVER_AFTER_STORED"
  }
}