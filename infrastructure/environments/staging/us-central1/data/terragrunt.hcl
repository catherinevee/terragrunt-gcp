# Data infrastructure configuration for staging us-central1 region
# Manages BigQuery, Pub/Sub, Dataflow, and other data services

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("env.hcl")
}

terraform {
  source = "../../../../../modules/data/bigquery"
}

dependency "network" {
  config_path = "../networking"

  mock_outputs = {
    vpc_id        = "mock-vpc-id"
    vpc_self_link = "mock-vpc-self-link"
  }
}

locals {
  environment = "staging"
  region      = "us-central1"

  # Staging data configuration - optimized for cost and development
  data_config = {
    bigquery = {
      location                 = "US"  # Multi-region for staging
      default_table_expiration = 7776000000  # 90 days in milliseconds
      default_partition_expiration = 2592000000  # 30 days in milliseconds
      delete_contents_on_destroy = true  # Allow cleanup in staging
    }

    pubsub = {
      message_retention_duration = "86400s"  # 1 day
      ack_deadline_seconds      = 20
      retain_acked_messages     = false
      enable_message_ordering   = false
      enable_exactly_once_delivery = false  # Disable for cost savings
    }

    dataflow = {
      machine_type     = "n1-standard-1"  # Smaller instances
      max_workers      = 3  # Limited workers
      disk_size_gb     = 30
      enable_streaming_engine = false  # Disable for cost savings
    }
  }
}

inputs = {
  project_id  = "acme-staging-platform"
  region      = local.region
  environment = local.environment

  # BigQuery Datasets
  datasets = [
    {
      dataset_id                 = "${local.environment}_raw_data"
      friendly_name              = "Staging Raw Data"
      description                = "Raw data ingestion for staging environment"
      location                   = local.data_config.bigquery.location
      default_table_expiration_ms = local.data_config.bigquery.default_table_expiration
      default_partition_expiration_ms = local.data_config.bigquery.default_partition_expiration
      delete_contents_on_destroy = local.data_config.bigquery.delete_contents_on_destroy

      labels = {
        environment = local.environment
        data_type   = "raw"
      }

      access = [
        {
          role          = "OWNER"
          user_by_email = "data-team@acme-corp.com"
        },
        {
          role           = "READER"
          group_by_email = "analytics@acme-corp.com"
        }
      ]

      tables = [
        {
          table_id    = "events"
          description = "Raw event data"

          time_partitioning = {
            type                     = "DAY"
            field                    = "event_timestamp"
            expiration_ms           = local.data_config.bigquery.default_partition_expiration
            require_partition_filter = false  # Not required in staging
          }

          clustering = ["user_id", "event_type"]

          schema = jsonencode([
            {
              name = "event_id"
              type = "STRING"
              mode = "REQUIRED"
            },
            {
              name = "event_timestamp"
              type = "TIMESTAMP"
              mode = "REQUIRED"
            },
            {
              name = "user_id"
              type = "STRING"
              mode = "NULLABLE"
            },
            {
              name = "event_type"
              type = "STRING"
              mode = "REQUIRED"
            },
            {
              name = "event_data"
              type = "JSON"
              mode = "NULLABLE"
            }
          ])
        },
        {
          table_id    = "users"
          description = "User dimension table"

          schema = jsonencode([
            {
              name = "user_id"
              type = "STRING"
              mode = "REQUIRED"
            },
            {
              name = "created_at"
              type = "TIMESTAMP"
              mode = "REQUIRED"
            },
            {
              name = "email"
              type = "STRING"
              mode = "NULLABLE"
            },
            {
              name = "attributes"
              type = "JSON"
              mode = "NULLABLE"
            }
          ])
        }
      ]

      views = [
        {
          view_id = "daily_active_users"
          query   = <<-SQL
            SELECT
              DATE(event_timestamp) as date,
              COUNT(DISTINCT user_id) as active_users
            FROM
              `acme-staging-platform.${local.environment}_raw_data.events`
            WHERE
              DATE(event_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
            GROUP BY
              date
            ORDER BY
              date DESC
          SQL

          labels = {
            view_type = "aggregate"
          }
        }
      ]
    },
    {
      dataset_id                 = "${local.environment}_processed_data"
      friendly_name              = "Staging Processed Data"
      description                = "Processed and transformed data for staging"
      location                   = local.data_config.bigquery.location
      default_table_expiration_ms = local.data_config.bigquery.default_table_expiration
      delete_contents_on_destroy = true

      labels = {
        environment = local.environment
        data_type   = "processed"
      }

      tables = [
        {
          table_id    = "user_metrics"
          description = "Aggregated user metrics"

          time_partitioning = {
            type          = "DAY"
            field         = "date"
            expiration_ms = local.data_config.bigquery.default_partition_expiration
          }

          clustering = ["user_segment"]

          schema = jsonencode([
            {
              name = "date"
              type = "DATE"
              mode = "REQUIRED"
            },
            {
              name = "user_id"
              type = "STRING"
              mode = "REQUIRED"
            },
            {
              name = "user_segment"
              type = "STRING"
              mode = "NULLABLE"
            },
            {
              name = "events_count"
              type = "INTEGER"
              mode = "NULLABLE"
            },
            {
              name = "session_duration_seconds"
              type = "FLOAT"
              mode = "NULLABLE"
            }
          ])
        }
      ]
    }
  ]

  # BigQuery scheduled queries
  scheduled_queries = [
    {
      display_name = "staging_daily_aggregation"
      schedule     = "every day 02:00"
      time_zone    = "America/Chicago"

      query = <<-SQL
        INSERT INTO `acme-staging-platform.${local.environment}_processed_data.user_metrics`
        SELECT
          CURRENT_DATE() as date,
          user_id,
          'standard' as user_segment,
          COUNT(*) as events_count,
          SUM(session_duration) as session_duration_seconds
        FROM
          `acme-staging-platform.${local.environment}_raw_data.events`
        WHERE
          DATE(event_timestamp) = CURRENT_DATE() - 1
        GROUP BY
          user_id
      SQL

      destination_dataset_id = "${local.environment}_processed_data"
      write_disposition     = "WRITE_APPEND"
    }
  ]

  # BigQuery reservations (minimal for staging)
  create_reservation = false  # No reservations in staging to save costs

  # Data Transfer configurations
  data_transfers = []  # Configure as needed

  # Pub/Sub configurations (handled separately by pubsub module)
  # Included here for reference of what topics/subscriptions are needed
  required_pubsub_topics = [
    "staging-events-ingestion",
    "staging-events-processing",
    "staging-events-deadletter"
  ]

  # Dataflow job configurations (handled separately by dataflow module)
  # Included here for reference
  dataflow_jobs = [
    {
      name             = "staging-stream-processing"
      template_gcs_path = "gs://dataflow-templates/latest/Stream_BigQuery"
      temp_gcs_location = "gs://acme-staging-dataflow-temp/temp"
      max_workers       = local.data_config.dataflow.max_workers
      machine_type      = local.data_config.dataflow.machine_type

      parameters = {
        inputTopic      = "projects/acme-staging-platform/topics/staging-events-ingestion"
        outputTableSpec = "acme-staging-platform:staging_raw_data.events"
      }
    }
  ]

  # Labels
  labels = {
    environment = local.environment
    region      = local.region
    managed_by  = "terraform"
    component   = "data-platform"
    cost_center = "engineering"
  }

  # Monitoring and alerts
  monitoring_alerts = [
    {
      display_name = "Staging BigQuery Slot Usage"
      condition_display_name = "High slot usage"

      filter = <<-FILTER
        resource.type="bigquery_project"
        metric.type="bigquery.googleapis.com/slots/total_allocated"
      FILTER

      threshold_value = 500  # Lower threshold for staging
      comparison      = "COMPARISON_GT"
      duration        = "300s"
    },
    {
      display_name = "Staging Query Errors"
      condition_display_name = "Query error rate"

      filter = <<-FILTER
        resource.type="bigquery_project"
        metric.type="bigquery.googleapis.com/job/num_failed_jobs"
      FILTER

      threshold_value = 5  # Alert on fewer errors in staging
      comparison      = "COMPARISON_GT"
      duration        = "60s"
    }
  ]
}