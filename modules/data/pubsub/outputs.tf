# Pub/Sub Module Outputs

# Topic Information
output "topic_name" {
  description = "Name of the Pub/Sub topic"
  value       = google_pubsub_topic.topic.name
}

output "topic_id" {
  description = "ID of the Pub/Sub topic"
  value       = google_pubsub_topic.topic.id
}

output "topic_labels" {
  description = "Labels attached to the topic"
  value       = google_pubsub_topic.topic.labels
}

output "topic_kms_key_name" {
  description = "KMS key used for topic encryption"
  value       = google_pubsub_topic.topic.kms_key_name
}

output "topic_message_retention_duration" {
  description = "Message retention duration for the topic"
  value       = google_pubsub_topic.topic.message_retention_duration
}

output "topic_schema_settings" {
  description = "Schema settings for the topic"
  value       = try(google_pubsub_topic.topic.schema_settings, null)
}

output "topic_message_storage_policy" {
  description = "Message storage policy for the topic"
  value       = try(google_pubsub_topic.topic.message_storage_policy, null)
}

# Schema Information
output "schema_name" {
  description = "Name of the Pub/Sub schema"
  value       = try(google_pubsub_schema.schema[0].name, null)
}

output "schema_id" {
  description = "ID of the Pub/Sub schema"
  value       = try(google_pubsub_schema.schema[0].id, null)
}

output "schema_type" {
  description = "Type of the schema"
  value       = try(google_pubsub_schema.schema[0].type, null)
}

output "schema_definition" {
  description = "Schema definition"
  value       = try(google_pubsub_schema.schema[0].definition, null)
  sensitive   = true
}

# Dead Letter Topic Information
output "dead_letter_topic_name" {
  description = "Name of the dead letter topic"
  value       = try(google_pubsub_topic.dead_letter_topic[0].name, null)
}

output "dead_letter_topic_id" {
  description = "ID of the dead letter topic"
  value       = try(google_pubsub_topic.dead_letter_topic[0].id, null)
}

output "dead_letter_monitoring_subscription_name" {
  description = "Name of the dead letter monitoring subscription"
  value       = try(google_pubsub_subscription.dead_letter_subscription[0].name, null)
}

output "dead_letter_monitoring_subscription_id" {
  description = "ID of the dead letter monitoring subscription"
  value       = try(google_pubsub_subscription.dead_letter_subscription[0].id, null)
}

# Subscription Information
output "subscriptions" {
  description = "Map of all subscriptions and their details"
  value = {
    for sub_name, sub in google_pubsub_subscription.subscriptions : sub_name => {
      id                           = sub.id
      name                         = sub.name
      topic                        = sub.topic
      ack_deadline_seconds         = sub.ack_deadline_seconds
      message_retention_duration   = sub.message_retention_duration
      retain_acked_messages        = sub.retain_acked_messages
      enable_exactly_once_delivery = sub.enable_exactly_once_delivery
      enable_message_ordering      = sub.enable_message_ordering
      filter                       = sub.filter
      labels                       = sub.labels

      expiration_policy = try({
        ttl = sub.expiration_policy[0].ttl
      }, null)

      retry_policy = try({
        minimum_backoff = sub.retry_policy[0].minimum_backoff
        maximum_backoff = sub.retry_policy[0].maximum_backoff
      }, null)

      dead_letter_policy = try({
        dead_letter_topic     = sub.dead_letter_policy[0].dead_letter_topic
        max_delivery_attempts = sub.dead_letter_policy[0].max_delivery_attempts
      }, null)

      push_config = try({
        push_endpoint = sub.push_config[0].push_endpoint
        attributes    = sub.push_config[0].attributes
        oidc_token = try({
          service_account_email = sub.push_config[0].oidc_token[0].service_account_email
          audience             = sub.push_config[0].oidc_token[0].audience
        }, null)
      }, null)

      bigquery_config = try({
        table                 = sub.bigquery_config[0].table
        use_topic_schema      = sub.bigquery_config[0].use_topic_schema
        write_metadata        = sub.bigquery_config[0].write_metadata
        drop_unknown_fields   = sub.bigquery_config[0].drop_unknown_fields
        use_table_schema      = sub.bigquery_config[0].use_table_schema
        service_account_email = sub.bigquery_config[0].service_account_email
      }, null)

      cloud_storage_config = try({
        bucket                   = sub.cloud_storage_config[0].bucket
        filename_prefix          = sub.cloud_storage_config[0].filename_prefix
        filename_suffix          = sub.cloud_storage_config[0].filename_suffix
        filename_datetime_format = sub.cloud_storage_config[0].filename_datetime_format
        max_duration            = sub.cloud_storage_config[0].max_duration
        max_bytes               = sub.cloud_storage_config[0].max_bytes
        state                   = sub.cloud_storage_config[0].state
        service_account_email   = sub.cloud_storage_config[0].service_account_email
      }, null)
    }
  }
}

output "subscription_names" {
  description = "List of all subscription names"
  value       = [for sub_name, sub in google_pubsub_subscription.subscriptions : sub.name]
}

output "subscription_ids" {
  description = "Map of subscription names to IDs"
  value       = {for sub_name, sub in google_pubsub_subscription.subscriptions : sub_name => sub.id}
}

output "push_subscription_endpoints" {
  description = "Map of push subscription endpoints"
  value = {
    for sub_name, sub in google_pubsub_subscription.subscriptions :
    sub_name => try(sub.push_config[0].push_endpoint, null)
    if try(sub.push_config[0], null) != null
  }
}

output "bigquery_subscription_tables" {
  description = "Map of BigQuery subscription tables"
  value = {
    for sub_name, sub in google_pubsub_subscription.subscriptions :
    sub_name => try(sub.bigquery_config[0].table, null)
    if try(sub.bigquery_config[0], null) != null
  }
}

output "cloud_storage_subscription_buckets" {
  description = "Map of Cloud Storage subscription buckets"
  value = {
    for sub_name, sub in google_pubsub_subscription.subscriptions :
    sub_name => try(sub.cloud_storage_config[0].bucket, null)
    if try(sub.cloud_storage_config[0], null) != null
  }
}

# Snapshots
output "snapshots" {
  description = "Map of all snapshots"
  value = {
    for snap_name, snap in google_pubsub_snapshot.snapshots : snap_name => {
      id           = snap.id
      name         = snap.name
      topic        = snap.topic
      subscription = snap.subscription
      expire_time  = snap.expire_time
      labels       = snap.labels
    }
  }
}

output "snapshot_names" {
  description = "List of all snapshot names"
  value       = [for snap_name, snap in google_pubsub_snapshot.snapshots : snap.name]
}

# Pub/Sub Lite Information
output "lite_topic_name" {
  description = "Name of the Pub/Sub Lite topic"
  value       = try(google_pubsub_lite_topic.lite_topic[0].name, null)
}

output "lite_topic_id" {
  description = "ID of the Pub/Sub Lite topic"
  value       = try(google_pubsub_lite_topic.lite_topic[0].id, null)
}

output "lite_topic_region" {
  description = "Region of the Pub/Sub Lite topic"
  value       = try(google_pubsub_lite_topic.lite_topic[0].region, null)
}

output "lite_topic_zone" {
  description = "Zone of the Pub/Sub Lite topic"
  value       = try(google_pubsub_lite_topic.lite_topic[0].zone, null)
}

output "lite_topic_partition_count" {
  description = "Number of partitions in the Lite topic"
  value       = try(google_pubsub_lite_topic.lite_topic[0].partition_config[0].count, null)
}

output "lite_subscription_name" {
  description = "Name of the Pub/Sub Lite subscription"
  value       = try(google_pubsub_lite_subscription.lite_subscription[0].name, null)
}

output "lite_subscription_id" {
  description = "ID of the Pub/Sub Lite subscription"
  value       = try(google_pubsub_lite_subscription.lite_subscription[0].id, null)
}

# Monitoring
output "monitoring_alert_policies" {
  description = "Map of monitoring alert policies"
  value = {
    for alert_name, alert in google_monitoring_alert_policy.pubsub_alerts : alert_name => {
      id                    = alert.id
      name                  = alert.name
      display_name          = alert.display_name
      combiner              = alert.combiner
      enabled               = alert.enabled
      notification_channels = alert.notification_channels
      user_labels          = alert.user_labels
      creation_record      = alert.creation_record
    }
  }
}

output "monitoring_dashboard_id" {
  description = "ID of the monitoring dashboard"
  value       = try(google_monitoring_dashboard.pubsub_dashboard[0].id, null)
}

# IAM
output "topic_iam_policy_etag" {
  description = "Etag of the topic IAM policy"
  value       = try(google_pubsub_topic_iam_policy.topic_policy[0].etag, null)
}

output "topic_iam_bindings" {
  description = "Map of topic IAM bindings"
  value = {
    for role, binding in google_pubsub_topic_iam_binding.topic_bindings : role => {
      role      = binding.role
      members   = binding.members
      condition = binding.condition
    }
  }
}

output "topic_iam_members" {
  description = "Map of individual topic IAM members"
  value = {
    for key, member in google_pubsub_topic_iam_member.topic_members : key => {
      role      = member.role
      member    = member.member
      condition = member.condition
    }
  }
}

output "subscription_iam_members" {
  description = "Map of subscription IAM members"
  value = {
    for key, member in google_pubsub_subscription_iam_member.subscription_members : key => {
      subscription = member.subscription
      role        = member.role
      member      = member.member
      condition   = member.condition
    }
  }
}

# Console URLs
output "console_urls" {
  description = "Google Cloud Console URLs"
  value = {
    topic = "https://console.cloud.google.com/cloudpubsub/topic/detail/${google_pubsub_topic.topic.name}?project=${var.project_id}"

    subscriptions = "https://console.cloud.google.com/cloudpubsub/subscription/list?project=${var.project_id}&topic=${google_pubsub_topic.topic.name}"

    schema = var.create_schema ? "https://console.cloud.google.com/cloudpubsub/schema/detail/${google_pubsub_schema.schema[0].name}?project=${var.project_id}" : null

    monitoring = "https://console.cloud.google.com/monitoring/metrics-explorer?project=${var.project_id}&pageState=%7B%22xyChart%22:%7B%22dataSets%22:%5B%7B%22timeSeriesFilter%22:%7B%22filter%22:%22metric.type%3D%5C%22pubsub.googleapis.com%2Ftopic%2Fsend_message_operation_count%5C%22%20resource.type%3D%5C%22pubsub_topic%5C%22%20resource.label.%5C%22topic_id%5C%22%3D%5C%22${google_pubsub_topic.topic.name}%5C%22%22%7D%7D%5D%7D%7D"

    dead_letter_topic = var.create_dead_letter_topic ? "https://console.cloud.google.com/cloudpubsub/topic/detail/${google_pubsub_topic.dead_letter_topic[0].name}?project=${var.project_id}" : null
  }
}

# gcloud Commands
output "gcloud_commands" {
  description = "Useful gcloud commands"
  value = {
    publish_message = "gcloud pubsub topics publish ${google_pubsub_topic.topic.name} --message='Hello World' --project=${var.project_id}"

    pull_messages = length(google_pubsub_subscription.subscriptions) > 0 ?
      "gcloud pubsub subscriptions pull ${element(keys(google_pubsub_subscription.subscriptions), 0)} --auto-ack --limit=10 --project=${var.project_id}" :
      null

    create_snapshot = length(google_pubsub_subscription.subscriptions) > 0 ?
      "gcloud pubsub snapshots create my-snapshot --subscription=${element(keys(google_pubsub_subscription.subscriptions), 0)} --project=${var.project_id}" :
      null

    seek_to_time = length(google_pubsub_subscription.subscriptions) > 0 ?
      "gcloud pubsub subscriptions seek ${element(keys(google_pubsub_subscription.subscriptions), 0)} --time=2024-01-01T00:00:00Z --project=${var.project_id}" :
      null

    describe_topic = "gcloud pubsub topics describe ${google_pubsub_topic.topic.name} --project=${var.project_id}"

    list_subscriptions = "gcloud pubsub subscriptions list --filter='topic:${google_pubsub_topic.topic.name}' --project=${var.project_id}"

    update_subscription = length(google_pubsub_subscription.subscriptions) > 0 ?
      "gcloud pubsub subscriptions update ${element(keys(google_pubsub_subscription.subscriptions), 0)} --ack-deadline=60 --project=${var.project_id}" :
      null
  }
}

# Python Code Examples
output "python_examples" {
  description = "Python code examples for Pub/Sub operations"
  value = {
    publish = <<-EOT
from google.cloud import pubsub_v1

publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path('${var.project_id}', '${google_pubsub_topic.topic.name}')

future = publisher.publish(topic_path, b'Hello World!')
print(f'Published message ID: {future.result()}')
EOT

    subscribe = length(google_pubsub_subscription.subscriptions) > 0 ? <<-EOT
from google.cloud import pubsub_v1

subscriber = pubsub_v1.SubscriberClient()
subscription_path = subscriber.subscription_path('${var.project_id}', '${element(keys(google_pubsub_subscription.subscriptions), 0)}')

def callback(message):
    print(f'Received: {message.data.decode()}')
    message.ack()

streaming_pull_future = subscriber.subscribe(subscription_path, callback=callback)
print(f'Listening for messages on {subscription_path}...')

try:
    streaming_pull_future.result(timeout=30)
except KeyboardInterrupt:
    streaming_pull_future.cancel()
EOT
    : null
  }
}

# Import Commands
output "import_commands" {
  description = "Terraform import commands"
  value = {
    topic = "terraform import google_pubsub_topic.topic projects/${var.project_id}/topics/${google_pubsub_topic.topic.name}"

    schema = var.create_schema ?
      "terraform import google_pubsub_schema.schema projects/${var.project_id}/schemas/${google_pubsub_schema.schema[0].name}" :
      null

    subscription = length(google_pubsub_subscription.subscriptions) > 0 ?
      "terraform import 'google_pubsub_subscription.subscriptions[\"SUBSCRIPTION_NAME\"]' projects/${var.project_id}/subscriptions/SUBSCRIPTION_NAME" :
      null

    snapshot = length(google_pubsub_snapshot.snapshots) > 0 ?
      "terraform import 'google_pubsub_snapshot.snapshots[\"SNAPSHOT_NAME\"]' projects/${var.project_id}/snapshots/SNAPSHOT_NAME" :
      null
  }
}