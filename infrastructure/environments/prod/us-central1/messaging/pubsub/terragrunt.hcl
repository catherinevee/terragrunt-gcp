# Pub/Sub Configuration for Production - US Central 1
# Enterprise messaging system with topics, subscriptions, dead letter queues, and schema management

terraform {
  source = "${get_repo_root()}/modules/messaging/pubsub"
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

# Pub/Sub depends on KMS for encryption
dependency "kms" {
  config_path = "../../security/kms"

  mock_outputs = {
    keys = {
      pubsub = {
        id = "mock-key-id"
        self_link = "projects/mock/locations/us-central1/keyRings/mock/cryptoKeys/mock"
      }
    }
  }
}

# Pub/Sub depends on IAM for service accounts
dependency "iam" {
  config_path = "../../security/iam"

  mock_outputs = {
    service_accounts = {
      pubsub = {
        email = "pubsub-sa@project.iam.gserviceaccount.com"
        id = "pubsub-sa"
      }
      dataflow = {
        email = "dataflow-sa@project.iam.gserviceaccount.com"
        id = "dataflow-sa"
      }
      cloud_functions = {
        email = "cloud-functions-sa@project.iam.gserviceaccount.com"
        id = "cloud-functions-sa"
      }
    }
  }
}

# Pub/Sub depends on BigQuery for streaming
dependency "bigquery" {
  config_path = "../../data/bigquery"
  skip_outputs = true

  mock_outputs = {
    datasets = {
      raw_data = {
        dataset_id = "prod_us_central1_raw_data"
      }
    }
  }
}

locals {
  # Extract configuration from includes
  env_config    = include.env.locals
  region_config = include.region.locals

  # Topic naming prefix
  topic_prefix = "${local.env_config.environment}-${local.region_config.region_short}"

  # Schema registry configuration
  schema_registry = {
    location = local.region_config.region
    project = var.project_id
  }

  # Pub/Sub schemas
  schemas = {
    # Event schema
    event_schema = {
      name = "${local.topic_prefix}-event-schema"
      type = "AVRO"
      definition = jsonencode({
        type = "record"
        name = "Event"
        namespace = "com.example.events"
        fields = [
          {
            name = "event_id"
            type = "string"
            doc = "Unique event identifier"
          },
          {
            name = "timestamp"
            type = "long"
            logicalType = "timestamp-millis"
            doc = "Event timestamp"
          },
          {
            name = "event_type"
            type = {
              type = "enum"
              name = "EventType"
              symbols = ["USER_SIGNUP", "USER_LOGIN", "PURCHASE", "PAGE_VIEW", "CLICK", "ERROR"]
            }
          },
          {
            name = "user_id"
            type = ["null", "string"]
            default = null
          },
          {
            name = "properties"
            type = {
              type = "map"
              values = "string"
            }
          },
          {
            name = "metadata"
            type = {
              type = "record"
              name = "Metadata"
              fields = [
                {
                  name = "source"
                  type = "string"
                },
                {
                  name = "version"
                  type = "string"
                },
                {
                  name = "correlation_id"
                  type = "string"
                }
              ]
            }
          }
        ]
      })
    }

    # Transaction schema
    transaction_schema = {
      name = "${local.topic_prefix}-transaction-schema"
      type = "PROTOCOL_BUFFER"
      definition = <<-PROTO
        syntax = "proto3";
        package com.example.transactions;

        message Transaction {
          string transaction_id = 1;
          int64 timestamp = 2;
          string user_id = 3;
          double amount = 4;
          string currency = 5;

          enum Status {
            PENDING = 0;
            PROCESSING = 1;
            COMPLETED = 2;
            FAILED = 3;
            CANCELLED = 4;
          }
          Status status = 6;

          message PaymentDetails {
            string method = 1;
            string provider = 2;
            string reference_id = 3;
          }
          PaymentDetails payment_details = 7;

          map<string, string> metadata = 8;
        }
      PROTO
    }

    # Notification schema
    notification_schema = {
      name = "${local.topic_prefix}-notification-schema"
      type = "AVRO"
      definition = jsonencode({
        type = "record"
        name = "Notification"
        fields = [
          {
            name = "notification_id"
            type = "string"
          },
          {
            name = "recipient"
            type = {
              type = "record"
              name = "Recipient"
              fields = [
                {
                  name = "user_id"
                  type = "string"
                },
                {
                  name = "email"
                  type = ["null", "string"]
                  default = null
                },
                {
                  name = "phone"
                  type = ["null", "string"]
                  default = null
                }
              ]
            }
          },
          {
            name = "channel"
            type = {
              type = "enum"
              name = "Channel"
              symbols = ["EMAIL", "SMS", "PUSH", "IN_APP"]
            }
          },
          {
            name = "template_id"
            type = "string"
          },
          {
            name = "parameters"
            type = {
              type = "map"
              values = "string"
            }
          },
          {
            name = "priority"
            type = {
              type = "enum"
              name = "Priority"
              symbols = ["LOW", "NORMAL", "HIGH", "CRITICAL"]
            }
          },
          {
            name = "scheduled_at"
            type = ["null", "long"]
            default = null
          }
        ]
      })
    }
  }

  # Pub/Sub topics configuration
  topics = {
    # Event stream topic
    events = {
      name = "${local.topic_prefix}-events"
      description = "Main event stream for ${local.env_config.environment}"

      message_storage_policy = {
        allowed_persistence_regions = [local.region_config.region]
      }

      kms_key_name = dependency.kms.outputs.keys.pubsub.self_link

      message_retention_duration = local.env_config.environment == "prod" ? "604800s" : "86400s"  # 7 days prod, 1 day non-prod

      schema_settings = {
        schema = "${local.schema_registry.project}/schemas/${local.schemas.event_schema.name}"
        encoding = "JSON"
      }

      labels = {
        stream = "events"
        criticality = "high"
        data_classification = "internal"
      }

      iam_bindings = {
        "roles/pubsub.publisher" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.cloud_functions.email}",
          "serviceAccount:${dependency.iam.outputs.service_accounts.cloud_run.email}"
        ]
        "roles/pubsub.viewer" = [
          "group:developers@${local.env_config.organization_domain}"
        ]
      }
    }

    # Transaction topic
    transactions = {
      name = "${local.topic_prefix}-transactions"
      description = "Transaction processing stream"

      message_storage_policy = {
        allowed_persistence_regions = [local.region_config.region]
      }

      kms_key_name = dependency.kms.outputs.keys.pubsub.self_link

      message_retention_duration = "2592000s"  # 30 days for financial data

      schema_settings = {
        schema = "${local.schema_registry.project}/schemas/${local.schemas.transaction_schema.name}"
        encoding = "BINARY"
      }

      labels = {
        stream = "transactions"
        criticality = "critical"
        data_classification = "confidential"
        compliance = "pci-dss"
      }

      iam_bindings = {
        "roles/pubsub.publisher" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.cloud_run.email}"
        ]
      }
    }

    # Notifications topic
    notifications = {
      name = "${local.topic_prefix}-notifications"
      description = "User notification stream"

      message_storage_policy = {
        allowed_persistence_regions = [local.region_config.region]
      }

      message_retention_duration = "86400s"  # 1 day

      schema_settings = {
        schema = "${local.schema_registry.project}/schemas/${local.schemas.notification_schema.name}"
        encoding = "JSON"
      }

      labels = {
        stream = "notifications"
        criticality = "medium"
      }
    }

    # Dead letter topic
    dead_letter = {
      name = "${local.topic_prefix}-dead-letter"
      description = "Dead letter queue for failed messages"

      message_storage_policy = {
        allowed_persistence_regions = [local.region_config.region]
      }

      message_retention_duration = "604800s"  # 7 days

      labels = {
        purpose = "dead_letter"
        requires_investigation = "true"
      }
    }

    # Audit topic
    audit = {
      name = "${local.topic_prefix}-audit"
      description = "Audit log stream"

      message_storage_policy = {
        allowed_persistence_regions = [local.region_config.region]
      }

      kms_key_name = dependency.kms.outputs.keys.pubsub.self_link

      message_retention_duration = "2592000s"  # 30 days

      labels = {
        stream = "audit"
        criticality = "critical"
        data_classification = "highly_confidential"
        compliance = "sox"
      }
    }

    # Metrics topic
    metrics = {
      name = "${local.topic_prefix}-metrics"
      description = "Application metrics stream"

      message_storage_policy = {
        allowed_persistence_regions = [local.region_config.region]
      }

      message_retention_duration = "259200s"  # 3 days

      labels = {
        stream = "metrics"
        purpose = "monitoring"
      }
    }

    # Logs topic
    logs = {
      name = "${local.topic_prefix}-logs"
      description = "Centralized log stream"

      message_storage_policy = {
        allowed_persistence_regions = [local.region_config.region]
      }

      message_retention_duration = "86400s"  # 1 day

      labels = {
        stream = "logs"
        purpose = "observability"
      }
    }

    # Task queue topic
    task_queue = {
      name = "${local.topic_prefix}-task-queue"
      description = "Asynchronous task processing queue"

      message_storage_policy = {
        allowed_persistence_regions = [local.region_config.region]
      }

      message_retention_duration = "604800s"  # 7 days

      labels = {
        purpose = "task_processing"
        processing_type = "async"
      }
    }
  }

  # Pub/Sub subscriptions configuration
  subscriptions = {
    # Event processing subscription
    events_processor = {
      name = "${local.topic_prefix}-events-processor-sub"
      topic = "${local.topic_prefix}-events"
      description = "Process events for analytics"

      message_retention_duration = "604800s"  # 7 days
      retain_acked_messages = false

      ack_deadline_seconds = 60

      expiration_policy = {
        ttl = ""  # Never expire
      }

      retry_policy = {
        minimum_backoff = "10s"
        maximum_backoff = "600s"
        maximum_doublings = 5
      }

      enable_message_ordering = false
      enable_exactly_once_delivery = local.env_config.environment == "prod"

      dead_letter_policy = {
        dead_letter_topic = "projects/${var.project_id}/topics/${local.topic_prefix}-dead-letter"
        max_delivery_attempts = 5
      }

      push_config = null  # Pull subscription

      filter = ""  # No filter, process all messages

      labels = {
        subscriber = "event_processor"
        processing_type = "batch"
      }

      iam_bindings = {
        "roles/pubsub.subscriber" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.dataflow.email}"
        ]
      }
    }

    # BigQuery streaming subscription
    events_to_bigquery = {
      name = "${local.topic_prefix}-events-to-bq-sub"
      topic = "${local.topic_prefix}-events"
      description = "Stream events to BigQuery"

      ack_deadline_seconds = 30

      bigquery_config = {
        table = "${var.project_id}:${dependency.bigquery.outputs.datasets.raw_data.dataset_id}.events"
        use_topic_schema = true
        write_metadata = true
        drop_unknown_fields = false
        state = "ACTIVE"
      }

      labels = {
        subscriber = "bigquery"
        destination = "data_warehouse"
      }
    }

    # Transaction processor subscription
    transaction_processor = {
      name = "${local.topic_prefix}-transaction-processor-sub"
      topic = "${local.topic_prefix}-transactions"
      description = "Process financial transactions"

      message_retention_duration = "2592000s"  # 30 days

      ack_deadline_seconds = 120  # Longer for transaction processing

      enable_exactly_once_delivery = true  # Critical for financial data

      retry_policy = {
        minimum_backoff = "30s"
        maximum_backoff = "600s"
        maximum_doublings = 3
      }

      dead_letter_policy = {
        dead_letter_topic = "projects/${var.project_id}/topics/${local.topic_prefix}-dead-letter"
        max_delivery_attempts = 3
      }

      push_config = {
        push_endpoint = "https://transaction-processor-${local.topic_prefix}.a.run.app/process"

        oidc_token = {
          service_account_email = dependency.iam.outputs.service_accounts.cloud_run.email
          audience = "https://transaction-processor-${local.topic_prefix}.a.run.app"
        }

        attributes = {
          x_goog_version = "v1"
        }
      }

      labels = {
        subscriber = "transaction_processor"
        criticality = "critical"
        requires_exactlyonce = "true"
      }
    }

    # Notification dispatcher subscription
    notification_dispatcher = {
      name = "${local.topic_prefix}-notification-dispatcher-sub"
      topic = "${local.topic_prefix}-notifications"
      description = "Dispatch notifications to users"

      ack_deadline_seconds = 30

      retry_policy = {
        minimum_backoff = "5s"
        maximum_backoff = "300s"
      }

      push_config = {
        push_endpoint = "https://notification-service-${local.topic_prefix}.a.run.app/dispatch"

        oidc_token = {
          service_account_email = dependency.iam.outputs.service_accounts.cloud_run.email
        }
      }

      # Filter by priority
      filter = "attributes.priority = \"HIGH\" OR attributes.priority = \"CRITICAL\""

      labels = {
        subscriber = "notification_dispatcher"
        channel = "high_priority"
      }
    }

    # Audit log subscription
    audit_logger = {
      name = "${local.topic_prefix}-audit-logger-sub"
      topic = "${local.topic_prefix}-audit"
      description = "Store audit logs for compliance"

      message_retention_duration = "2592000s"  # 30 days

      ack_deadline_seconds = 10

      bigquery_config = {
        table = "${var.project_id}:${local.topic_prefix}_audit.audit_logs"
        use_topic_schema = false
        write_metadata = true
      }

      labels = {
        subscriber = "audit_logger"
        compliance = "required"
      }
    }

    # Metrics aggregator subscription
    metrics_aggregator = {
      name = "${local.topic_prefix}-metrics-aggregator-sub"
      topic = "${local.topic_prefix}-metrics"
      description = "Aggregate metrics for monitoring"

      ack_deadline_seconds = 20

      cloud_storage_config = {
        bucket = "${var.project_id}-${local.env_config.environment}-metrics"
        filename_prefix = "metrics/"
        filename_suffix = ".json"
        filename_datetime_format = "YYYY/MM/DD/HH"
        max_duration = "60s"
        max_bytes = 10485760  # 10 MB
        state = "ACTIVE"

        avro_config = {
          write_metadata = true
        }
      }

      labels = {
        subscriber = "metrics_aggregator"
        destination = "cloud_storage"
      }
    }

    # Task worker subscription
    task_worker = {
      name = "${local.topic_prefix}-task-worker-sub"
      topic = "${local.topic_prefix}-task-queue"
      description = "Process background tasks"

      ack_deadline_seconds = 600  # 10 minutes for long-running tasks

      retry_policy = {
        minimum_backoff = "60s"
        maximum_backoff = "3600s"
        maximum_doublings = 5
      }

      enable_message_ordering = true  # Process tasks in order

      dead_letter_policy = {
        dead_letter_topic = "projects/${var.project_id}/topics/${local.topic_prefix}-dead-letter"
        max_delivery_attempts = 3
      }

      push_config = null  # Pull subscription for workers

      labels = {
        subscriber = "task_worker"
        processing_type = "sequential"
      }
    }

    # Dead letter monitoring subscription
    dead_letter_monitor = {
      name = "${local.topic_prefix}-dead-letter-monitor-sub"
      topic = "${local.topic_prefix}-dead-letter"
      description = "Monitor and alert on dead letter messages"

      message_retention_duration = "604800s"  # 7 days

      ack_deadline_seconds = 30

      push_config = {
        push_endpoint = "https://alerting-service-${local.topic_prefix}.a.run.app/dead-letter"

        oidc_token = {
          service_account_email = dependency.iam.outputs.service_accounts.cloud_run.email
        }
      }

      labels = {
        subscriber = "dead_letter_monitor"
        alert_priority = "high"
      }
    }
  }

  # Subscription snapshots for backup/recovery
  snapshots = {
    events_backup = {
      name = "${local.topic_prefix}-events-snapshot"
      subscription = "${local.topic_prefix}-events-processor-sub"
      description = "Daily backup of events subscription"

      labels = {
        purpose = "backup"
        frequency = "daily"
      }
    }

    transaction_backup = {
      name = "${local.topic_prefix}-transaction-snapshot"
      subscription = "${local.topic_prefix}-transaction-processor-sub"
      description = "Hourly backup of transaction subscription"

      labels = {
        purpose = "backup"
        frequency = "hourly"
        criticality = "high"
      }
    }
  }

  # Lite topics and subscriptions (for cost-effective, high-throughput scenarios)
  lite_resources = local.env_config.environment != "prod" ? {} : {
    lite_topics = {
      clickstream = {
        name = "${local.topic_prefix}-clickstream-lite"
        partition_count = 10
        retention_config = {
          per_partition_bytes = 34359738368  # 32 GiB
          period = "86400s"  # 1 day
        }
      }
    }

    lite_subscriptions = {
      clickstream_processor = {
        name = "${local.topic_prefix}-clickstream-processor-lite-sub"
        topic = "${local.topic_prefix}-clickstream-lite"
        delivery_config = {
          delivery_requirement = "DELIVER_AFTER_STORED"
        }
      }
    }
  }

  # Message flow configurations
  message_flows = {
    # Event processing pipeline
    event_pipeline = {
      source = "${local.topic_prefix}-events"

      transformations = [
        {
          name = "enrich_user_data"
          type = "DATAFLOW"
          config = {
            template = "gs://dataflow-templates/latest/PubSub_to_BigQuery"
            parameters = {
              inputTopic = "projects/${var.project_id}/topics/${local.topic_prefix}-events"
              outputTableSpec = "${var.project_id}:${local.topic_prefix}_staging.events_enriched"
            }
          }
        },
        {
          name = "aggregate_metrics"
          type = "CLOUD_FUNCTION"
          config = {
            function_name = "${local.topic_prefix}-metric-aggregator"
            batch_size = 1000
            batch_window = "60s"
          }
        }
      ]

      destinations = [
        "${local.topic_prefix}-metrics",
        "bigquery:${var.project_id}.${local.topic_prefix}_warehouse.events"
      ]
    }

    # Notification flow
    notification_flow = {
      source = "${local.topic_prefix}-notifications"

      routing_rules = [
        {
          condition = "attributes.channel = 'EMAIL'"
          destination = "${local.topic_prefix}-email-queue"
        },
        {
          condition = "attributes.channel = 'SMS'"
          destination = "${local.topic_prefix}-sms-queue"
        },
        {
          condition = "attributes.channel = 'PUSH'"
          destination = "${local.topic_prefix}-push-queue"
        }
      ]

      error_handling = {
        dead_letter_topic = "${local.topic_prefix}-dead-letter"
        max_retries = 3
      }
    }
  }

  # Monitoring and alerting configuration
  monitoring_config = {
    alerts = {
      high_publish_rate = {
        display_name = "High Pub/Sub Publish Rate"
        conditions = {
          threshold_messages_per_second = 10000
          duration = "300s"
        }
      }

      subscription_backlog = {
        display_name = "Subscription Backlog Too High"
        conditions = {
          threshold_messages = 100000
          duration = "600s"
        }
      }

      oldest_unacked_message = {
        display_name = "Old Unacked Messages"
        conditions = {
          threshold_age_seconds = 3600
          duration = "300s"
        }
      }

      dead_letter_messages = {
        display_name = "Messages in Dead Letter Queue"
        conditions = {
          threshold_count = 10
          duration = "300s"
        }
      }

      subscription_quota_exceeded = {
        display_name = "Subscription Quota Exceeded"
        conditions = {
          threshold_percent = 90
          duration = "300s"
        }
      }

      message_size_exceeded = {
        display_name = "Large Messages Detected"
        conditions = {
          threshold_bytes = 9437184  # 9 MB (close to 10 MB limit)
          duration = "60s"
        }
      }
    }

    metrics = {
      publish_rate = {
        metric = "pubsub.googleapis.com/topic/send_message_operation_count"
        aggregation = "ALIGN_RATE"
      }

      subscription_backlog = {
        metric = "pubsub.googleapis.com/subscription/num_undelivered_messages"
        aggregation = "ALIGN_MAX"
      }

      ack_latency = {
        metric = "pubsub.googleapis.com/subscription/ack_latencies"
        aggregation = "ALIGN_DELTA"
      }

      push_latency = {
        metric = "pubsub.googleapis.com/subscription/push_request_latencies"
        aggregation = "ALIGN_DELTA"
      }

      message_size = {
        metric = "pubsub.googleapis.com/topic/message_sizes"
        aggregation = "ALIGN_MAX"
      }
    }

    dashboard = {
      display_name = "Pub/Sub Dashboard - ${local.env_config.environment}"

      widgets = [
        {
          title = "Publish Rate"
          metric = "publish_rate"
          chart_type = "LINE"
        },
        {
          title = "Subscription Backlogs"
          metric = "subscription_backlog"
          chart_type = "STACKED_AREA"
        },
        {
          title = "Acknowledgment Latency"
          metric = "ack_latency"
          chart_type = "HEATMAP"
        },
        {
          title = "Push Endpoint Latency"
          metric = "push_latency"
          chart_type = "LINE"
        },
        {
          title = "Message Size Distribution"
          metric = "message_size"
          chart_type = "HISTOGRAM"
        },
        {
          title = "Dead Letter Messages"
          metric = "dead_letter_count"
          chart_type = "SCORECARD"
        }
      ]
    }
  }

  # Cost optimization configuration
  cost_optimization = {
    # Message batching
    batching = {
      enable_batching = true
      max_messages = 1000
      max_bytes = 10485760  # 10 MB
      max_latency = "100ms"
    }

    # Subscription expiration
    subscription_expiration = {
      enable_auto_cleanup = local.env_config.environment != "prod"
      inactive_duration = "2592000s"  # 30 days
    }

    # Regional configuration
    regional_optimization = {
      use_regional_endpoints = true
      prefer_same_zone = true
    }

    # Compression
    compression = {
      enable_compression = true
      compression_type = "GZIP"
    }

    # Resource consolidation
    consolidation = {
      use_topic_schemas = true  # Reduce duplicate schema definitions
      share_subscriptions = false  # Each service gets its own subscription
    }
  }

  # Compliance and governance
  compliance_config = {
    # Data retention
    retention_policy = {
      message_retention = local.env_config.environment == "prod" ? "604800s" : "86400s"
      acknowledged_message_retention = false
      snapshot_retention = "2592000s"  # 30 days
    }

    # Encryption
    encryption = {
      require_cmek = true
      kms_key = dependency.kms.outputs.keys.pubsub.self_link
    }

    # Access controls
    access_control = {
      require_authentication = true
      require_authorization = true
      allowed_authentication_methods = ["OIDC", "SERVICE_ACCOUNT"]
    }

    # Audit logging
    audit_logging = {
      log_all_operations = true
      log_message_content = false  # Don't log sensitive data
      retention_days = local.env_config.environment == "prod" ? 2555 : 365
    }

    # Data classification
    data_classification = {
      topics = {
        "${local.topic_prefix}-transactions" = "HIGHLY_CONFIDENTIAL"
        "${local.topic_prefix}-audit" = "HIGHLY_CONFIDENTIAL"
        "${local.topic_prefix}-events" = "CONFIDENTIAL"
        "${local.topic_prefix}-metrics" = "INTERNAL"
        "${local.topic_prefix}-logs" = "INTERNAL"
      }
    }
  }

  # Disaster recovery configuration
  dr_config = {
    # Cross-region replication
    replication = local.env_config.environment == "prod" ? {
      enable_replication = true
      replica_regions = ["us-east1", "europe-west1"]
      sync_mode = "ASYNC"
    } : null

    # Backup strategy
    backup = {
      enable_snapshots = true
      snapshot_schedule = local.env_config.environment == "prod" ? "0 */6 * * *" : "0 0 * * *"  # Every 6 hours for prod
      snapshot_retention_days = 7
    }

    # Recovery procedures
    recovery = {
      rto_minutes = local.env_config.environment == "prod" ? 15 : 60
      rpo_minutes = local.env_config.environment == "prod" ? 5 : 30
    }
  }
}

# Module inputs
inputs = {
  # Project configuration
  project_id = var.project_id
  region     = local.region_config.region

  # Schema registry
  schema_registry = local.schema_registry

  # Schemas
  schemas = local.schemas

  # Topics
  topics = local.topics

  # Subscriptions
  subscriptions = local.subscriptions

  # Snapshots
  snapshots = local.snapshots

  # Lite resources
  lite_resources = local.lite_resources

  # Message flows
  message_flows = local.message_flows

  # Encryption configuration
  encryption_config = {
    kms_key_name = dependency.kms.outputs.keys.pubsub.self_link
  }

  # Monitoring configuration
  monitoring_config = local.monitoring_config
  enable_monitoring = true
  create_monitoring_dashboard = local.env_config.environment == "prod"
  create_monitoring_alerts = local.env_config.environment != "dev"

  # Cost optimization
  cost_optimization = local.cost_optimization

  # Compliance configuration
  compliance_config = local.compliance_config

  # Disaster recovery
  dr_config = local.dr_config

  # Labels
  labels = merge(
    var.common_labels,
    {
      component = "messaging"
      service   = "pubsub"
      tier      = "middleware"
    }
  )

  # Dependencies
  depends_on = [dependency.kms, dependency.iam, dependency.bigquery]
}