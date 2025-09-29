# Google Cloud Pub/Sub Module
# Manages Pub/Sub topics, subscriptions, and schemas with comprehensive configuration

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

locals {
  # Topic configuration
  topic_name = var.topic_name

  # Labels with defaults
  topic_labels = merge(
    var.topic_labels,
    {
      managed_by  = "terraform"
      module      = "pubsub"
      environment = var.environment
      created_at  = formatdate("YYYY-MM-DD", timestamp())
    }
  )

  # Subscription labels
  subscription_labels = merge(
    var.subscription_labels,
    {
      managed_by  = "terraform"
      module      = "pubsub"
      topic       = local.topic_name
    }
  )

  # Message retention duration
  message_retention_duration = var.message_retention_duration != null ? var.message_retention_duration : "604800s"  # 7 days default

  # Schema settings
  schema_type = var.schema_type != null ? var.schema_type : "PROTOCOL_BUFFER"

  # Dead letter policy defaults
  dead_letter_max_delivery_attempts = var.dead_letter_max_delivery_attempts != null ? var.dead_letter_max_delivery_attempts : 5
}

# Pub/Sub Schema (optional)
resource "google_pubsub_schema" "schema" {
  count = var.create_schema ? 1 : 0

  project = var.project_id
  name    = var.schema_name != null ? var.schema_name : "${local.topic_name}-schema"
  type    = local.schema_type

  definition = var.schema_definition
}

# Pub/Sub Topic
resource "google_pubsub_topic" "topic" {
  project = var.project_id
  name    = local.topic_name

  labels = local.topic_labels

  # Message retention
  message_retention_duration = local.message_retention_duration

  # KMS encryption
  kms_key_name = var.kms_key_name

  # Schema settings
  dynamic "schema_settings" {
    for_each = var.create_schema || var.existing_schema_name != null ? [1] : []
    content {
      schema   = var.create_schema ? google_pubsub_schema.schema[0].id : var.existing_schema_name
      encoding = var.schema_encoding
    }
  }

  # Message storage policy
  dynamic "message_storage_policy" {
    for_each = var.allowed_persistence_regions != null ? [1] : []
    content {
      allowed_persistence_regions = var.allowed_persistence_regions
    }
  }

  depends_on = [google_pubsub_schema.schema]
}

# Dead Letter Topic (optional)
resource "google_pubsub_topic" "dead_letter_topic" {
  count = var.create_dead_letter_topic ? 1 : 0

  project = var.project_id
  name    = var.dead_letter_topic_name != null ? var.dead_letter_topic_name : "${local.topic_name}-dead-letter"

  labels = merge(
    local.topic_labels,
    {
      type = "dead-letter"
      parent_topic = local.topic_name
    }
  )

  message_retention_duration = var.dead_letter_message_retention_duration

  kms_key_name = var.dead_letter_kms_key_name != null ? var.dead_letter_kms_key_name : var.kms_key_name

  dynamic "message_storage_policy" {
    for_each = var.allowed_persistence_regions != null ? [1] : []
    content {
      allowed_persistence_regions = var.allowed_persistence_regions
    }
  }
}

# Dead Letter Subscription for monitoring
resource "google_pubsub_subscription" "dead_letter_subscription" {
  count = var.create_dead_letter_topic && var.create_dead_letter_monitoring_subscription ? 1 : 0

  project = var.project_id
  name    = "${google_pubsub_topic.dead_letter_topic[0].name}-monitoring"
  topic   = google_pubsub_topic.dead_letter_topic[0].name

  message_retention_duration = "604800s"  # 7 days
  retain_acked_messages     = true
  ack_deadline_seconds      = 600  # 10 minutes

  expiration_policy {
    ttl = ""  # Never expire
  }

  labels = merge(
    local.subscription_labels,
    {
      type    = "monitoring"
      purpose = "dead-letter-monitoring"
    }
  )
}

# Pub/Sub Subscriptions
resource "google_pubsub_subscription" "subscriptions" {
  for_each = var.subscriptions

  project = var.project_id
  name    = each.key
  topic   = google_pubsub_topic.topic.name

  labels = merge(
    local.subscription_labels,
    lookup(each.value, "labels", {})
  )

  # Acknowledgement deadline
  ack_deadline_seconds = lookup(each.value, "ack_deadline_seconds", 10)

  # Message retention
  message_retention_duration = lookup(each.value, "message_retention_duration", local.message_retention_duration)
  retain_acked_messages     = lookup(each.value, "retain_acked_messages", false)

  # Expiration policy
  dynamic "expiration_policy" {
    for_each = lookup(each.value, "ttl", null) != null ? [1] : []
    content {
      ttl = each.value.ttl
    }
  }

  # Retry policy
  dynamic "retry_policy" {
    for_each = lookup(each.value, "retry_policy", null) != null ? [each.value.retry_policy] : []
    content {
      minimum_backoff = lookup(retry_policy.value, "minimum_backoff", "10s")
      maximum_backoff = lookup(retry_policy.value, "maximum_backoff", "600s")
    }
  }

  # Dead letter policy
  dynamic "dead_letter_policy" {
    for_each = (var.create_dead_letter_topic || lookup(each.value, "dead_letter_topic", null) != null) &&
               lookup(each.value, "enable_dead_letter_policy", true) ? [1] : []
    content {
      dead_letter_topic     = lookup(each.value, "dead_letter_topic", null) != null ? each.value.dead_letter_topic : google_pubsub_topic.dead_letter_topic[0].id
      max_delivery_attempts = lookup(each.value, "max_delivery_attempts", local.dead_letter_max_delivery_attempts)
    }
  }

  # Push configuration
  dynamic "push_config" {
    for_each = lookup(each.value, "push_config", null) != null ? [each.value.push_config] : []
    content {
      push_endpoint = push_config.value.push_endpoint
      attributes    = lookup(push_config.value, "attributes", {})

      # OIDC token
      dynamic "oidc_token" {
        for_each = lookup(push_config.value, "oidc_token", null) != null ? [push_config.value.oidc_token] : []
        content {
          service_account_email = oidc_token.value.service_account_email
          audience             = lookup(oidc_token.value, "audience", null)
        }
      }

      # No wrapper
      dynamic "no_wrapper" {
        for_each = lookup(push_config.value, "no_wrapper", null) != null ? [push_config.value.no_wrapper] : []
        content {
          write_metadata = no_wrapper.value.write_metadata
        }
      }
    }
  }

  # BigQuery configuration
  dynamic "bigquery_config" {
    for_each = lookup(each.value, "bigquery_config", null) != null ? [each.value.bigquery_config] : []
    content {
      table               = bigquery_config.value.table
      use_topic_schema    = lookup(bigquery_config.value, "use_topic_schema", false)
      write_metadata      = lookup(bigquery_config.value, "write_metadata", false)
      drop_unknown_fields = lookup(bigquery_config.value, "drop_unknown_fields", false)
      use_table_schema    = lookup(bigquery_config.value, "use_table_schema", false)
      service_account_email = lookup(bigquery_config.value, "service_account_email", null)
    }
  }

  # Cloud Storage configuration
  dynamic "cloud_storage_config" {
    for_each = lookup(each.value, "cloud_storage_config", null) != null ? [each.value.cloud_storage_config] : []
    content {
      bucket                   = cloud_storage_config.value.bucket
      filename_prefix          = lookup(cloud_storage_config.value, "filename_prefix", null)
      filename_suffix          = lookup(cloud_storage_config.value, "filename_suffix", null)
      filename_datetime_format = lookup(cloud_storage_config.value, "filename_datetime_format", null)
      max_duration            = lookup(cloud_storage_config.value, "max_duration", "300s")
      max_bytes               = lookup(cloud_storage_config.value, "max_bytes", 1000000000)
      state                   = lookup(cloud_storage_config.value, "state", null)
      service_account_email   = lookup(cloud_storage_config.value, "service_account_email", null)

      dynamic "avro_config" {
        for_each = lookup(cloud_storage_config.value, "avro_config", null) != null ? [cloud_storage_config.value.avro_config] : []
        content {
          write_metadata        = lookup(avro_config.value, "write_metadata", false)
          use_topic_schema     = lookup(avro_config.value, "use_topic_schema", false)
        }
      }
    }
  }

  # Enable exactly once delivery
  enable_exactly_once_delivery = lookup(each.value, "enable_exactly_once_delivery", false)

  # Enable message ordering
  enable_message_ordering = lookup(each.value, "enable_message_ordering", false)

  # Filter
  filter = lookup(each.value, "filter", null)

  depends_on = [
    google_pubsub_topic.topic,
    google_pubsub_topic.dead_letter_topic
  ]
}

# Topic IAM Policy
resource "google_pubsub_topic_iam_policy" "topic_policy" {
  count = var.topic_iam_policy != null ? 1 : 0

  project     = var.project_id
  topic       = google_pubsub_topic.topic.name
  policy_data = var.topic_iam_policy
}

# Topic IAM Bindings
resource "google_pubsub_topic_iam_binding" "topic_bindings" {
  for_each = var.topic_iam_bindings

  project = var.project_id
  topic   = google_pubsub_topic.topic.name
  role    = each.key
  members = each.value

  dynamic "condition" {
    for_each = lookup(var.topic_iam_binding_conditions, each.key, null) != null ? [var.topic_iam_binding_conditions[each.key]] : []
    content {
      title       = condition.value.title
      description = lookup(condition.value, "description", null)
      expression  = condition.value.expression
    }
  }
}

# Topic IAM Members
resource "google_pubsub_topic_iam_member" "topic_members" {
  for_each = var.topic_iam_members

  project = var.project_id
  topic   = google_pubsub_topic.topic.name
  role    = each.value.role
  member  = each.value.member

  dynamic "condition" {
    for_each = lookup(each.value, "condition", null) != null ? [each.value.condition] : []
    content {
      title       = condition.value.title
      description = lookup(condition.value, "description", null)
      expression  = condition.value.expression
    }
  }
}

# Subscription IAM Members
resource "google_pubsub_subscription_iam_member" "subscription_members" {
  for_each = var.subscription_iam_members

  project      = var.project_id
  subscription = each.value.subscription
  role         = each.value.role
  member       = each.value.member

  dynamic "condition" {
    for_each = lookup(each.value, "condition", null) != null ? [each.value.condition] : []
    content {
      title       = condition.value.title
      description = lookup(condition.value, "description", null)
      expression  = condition.value.expression
    }
  }

  depends_on = [google_pubsub_subscription.subscriptions]
}

# Monitoring Alert Policies
resource "google_monitoring_alert_policy" "pubsub_alerts" {
  for_each = var.create_monitoring_alerts ? var.monitoring_alerts : {}

  project      = var.project_id
  display_name = each.value.display_name
  combiner     = lookup(each.value, "combiner", "OR")
  enabled      = lookup(each.value, "enabled", true)

  conditions {
    display_name = each.value.condition_display_name

    condition_threshold {
      filter          = each.value.filter
      duration        = lookup(each.value, "duration", "60s")
      comparison      = lookup(each.value, "comparison", "COMPARISON_GT")
      threshold_value = each.value.threshold_value

      aggregations {
        alignment_period     = lookup(each.value, "alignment_period", "60s")
        per_series_aligner   = lookup(each.value, "per_series_aligner", "ALIGN_RATE")
        cross_series_reducer = lookup(each.value, "cross_series_reducer", null)
        group_by_fields      = lookup(each.value, "group_by_fields", null)
      }

      trigger {
        count   = lookup(each.value, "trigger_count", null)
        percent = lookup(each.value, "trigger_percent", null)
      }
    }
  }

  notification_channels = lookup(each.value, "notification_channels", [])

  alert_strategy {
    auto_close = lookup(each.value, "auto_close", "1800s")

    dynamic "rate_limit" {
      for_each = lookup(each.value, "rate_limit", null) != null ? [each.value.rate_limit] : []
      content {
        period = rate_limit.value.period
      }
    }
  }

  documentation {
    content   = lookup(each.value, "documentation_content", "Pub/Sub alert triggered")
    mime_type = lookup(each.value, "documentation_mime_type", "text/markdown")
    subject   = lookup(each.value, "documentation_subject", null)
  }

  user_labels = merge(
    local.topic_labels,
    lookup(each.value, "labels", {})
  )
}

# Monitoring Dashboard
resource "google_monitoring_dashboard" "pubsub_dashboard" {
  count = var.create_monitoring_dashboard ? 1 : 0

  project        = var.project_id
  dashboard_json = jsonencode({
    displayName = "${local.topic_name} Pub/Sub Dashboard"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Message Throughput"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"pubsub.googleapis.com/topic/send_message_operation_count\" resource.type=\"pubsub_topic\" resource.label.\"topic_id\"=\"${local.topic_name}\""
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          widget = {
            title = "Subscription Message Count"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\" resource.type=\"pubsub_subscription\" resource.label.\"topic_id\"=\"${local.topic_name}\""
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          yPos   = 4
          widget = {
            title = "Oldest Unacked Message Age"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"pubsub.googleapis.com/subscription/oldest_unacked_message_age\" resource.type=\"pubsub_subscription\" resource.label.\"topic_id\"=\"${local.topic_name}\""
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          yPos   = 4
          widget = {
            title = "Dead Letter Message Count"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"pubsub.googleapis.com/subscription/dead_letter_message_count\" resource.type=\"pubsub_subscription\" resource.label.\"topic_id\"=\"${local.topic_name}\""
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        }
      ]
    }
  })
}

# Snapshot for subscriptions
resource "google_pubsub_snapshot" "snapshots" {
  for_each = var.snapshots

  project      = var.project_id
  name         = each.key
  subscription = each.value.subscription

  labels = merge(
    local.subscription_labels,
    lookup(each.value, "labels", {})
  )

  depends_on = [google_pubsub_subscription.subscriptions]
}

# Lite Topic (for Pub/Sub Lite)
resource "google_pubsub_lite_topic" "lite_topic" {
  count = var.create_lite_topic ? 1 : 0

  project = var.project_id
  name    = var.lite_topic_name != null ? var.lite_topic_name : "${local.topic_name}-lite"
  region  = var.lite_topic_region
  zone    = var.lite_topic_zone

  partition_config {
    count    = var.lite_partition_count
    capacity {
      publish_mib_per_sec   = var.lite_publish_capacity_mib_per_sec
      subscribe_mib_per_sec = var.lite_subscribe_capacity_mib_per_sec
    }
  }

  retention_config {
    per_partition_bytes = var.lite_retention_bytes_per_partition
    period             = var.lite_retention_period
  }

  reservation_config {
    throughput_reservation = var.lite_throughput_reservation
  }
}

# Lite Subscription
resource "google_pubsub_lite_subscription" "lite_subscription" {
  count = var.create_lite_topic && var.create_lite_subscription ? 1 : 0

  project = var.project_id
  name    = var.lite_subscription_name != null ? var.lite_subscription_name : "${local.topic_name}-lite-sub"
  topic   = google_pubsub_lite_topic.lite_topic[0].name
  region  = var.lite_topic_region
  zone    = var.lite_topic_zone

  delivery_config {
    delivery_requirement = var.lite_delivery_requirement
  }

  depends_on = [google_pubsub_lite_topic.lite_topic]
}