# BigQuery Configuration for Production - US Central 1
# Enterprise data warehouse with datasets, tables, views, ML models, and data governance

terraform {
  source = "${get_repo_root()}/modules/data/bigquery"
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

# BigQuery depends on KMS for encryption
dependency "kms" {
  config_path = "../../security/kms"

  mock_outputs = {
    keys = {
      bigquery = {
        id = "mock-key-id"
        self_link = "projects/mock/locations/us-central1/keyRings/mock/cryptoKeys/mock"
      }
    }
  }
}

# BigQuery depends on IAM for service accounts
dependency "iam" {
  config_path = "../../security/iam"

  mock_outputs = {
    service_accounts = {
      bigquery = {
        email = "bigquery-sa@project.iam.gserviceaccount.com"
        id = "bigquery-sa"
      }
      dataflow = {
        email = "dataflow-sa@project.iam.gserviceaccount.com"
        id = "dataflow-sa"
      }
    }
  }
}

locals {
  # Extract configuration from includes
  env_config    = include.env.locals
  region_config = include.region.locals

  # Dataset naming prefix
  dataset_prefix = "${local.env_config.environment}_${replace(local.region_config.region_short, "-", "_")}"

  # BigQuery datasets configuration
  datasets = {
    # Raw data landing zone
    raw_data = {
      dataset_id = "${local.dataset_prefix}_raw_data"
      friendly_name = "Raw Data Landing Zone"
      description = "Landing zone for raw, unprocessed data from various sources"
      location = local.region_config.bigquery_location
      default_table_expiration_ms = local.env_config.environment == "prod" ? null : 7776000000  # 90 days for non-prod

      default_partition_expiration_ms = local.env_config.environment == "prod" ? 31536000000 : 7776000000  # 1 year for prod, 90 days for non-prod

      default_encryption_configuration = {
        kms_key_name = dependency.kms.outputs.keys.bigquery.self_link
      }

      access = [
        {
          role = "OWNER"
          user_by_email = dependency.iam.outputs.service_accounts.bigquery.email
        },
        {
          role = "WRITER"
          user_by_email = dependency.iam.outputs.service_accounts.dataflow.email
        },
        {
          role = "READER"
          group_by_email = "data-analysts@${local.env_config.organization_domain}"
        }
      ]

      labels = {
        data_classification = "raw"
        retention_policy = "standard"
        cost_center = "data_engineering"
      }

      # Tables in raw dataset
      tables = {
        events = {
          table_id = "events"
          description = "Raw event data from application"

          schema = jsonencode([
            {
              name = "event_id"
              type = "STRING"
              mode = "REQUIRED"
              description = "Unique event identifier"
            },
            {
              name = "timestamp"
              type = "TIMESTAMP"
              mode = "REQUIRED"
              description = "Event timestamp"
            },
            {
              name = "user_id"
              type = "STRING"
              mode = "NULLABLE"
              description = "User identifier"
            },
            {
              name = "event_type"
              type = "STRING"
              mode = "REQUIRED"
              description = "Type of event"
            },
            {
              name = "properties"
              type = "JSON"
              mode = "NULLABLE"
              description = "Event properties as JSON"
            },
            {
              name = "session_id"
              type = "STRING"
              mode = "NULLABLE"
              description = "Session identifier"
            },
            {
              name = "device_info"
              type = "RECORD"
              mode = "NULLABLE"
              description = "Device information"
              fields = [
                {
                  name = "device_type"
                  type = "STRING"
                  mode = "NULLABLE"
                },
                {
                  name = "os"
                  type = "STRING"
                  mode = "NULLABLE"
                },
                {
                  name = "browser"
                  type = "STRING"
                  mode = "NULLABLE"
                },
                {
                  name = "ip_address"
                  type = "STRING"
                  mode = "NULLABLE"
                }
              ]
            },
            {
              name = "geo_location"
              type = "GEOGRAPHY"
              mode = "NULLABLE"
              description = "Geographic location"
            }
          ])

          time_partitioning = {
            type = "DAY"
            field = "timestamp"
            expiration_ms = local.env_config.environment == "prod" ? 94608000000 : 31536000000  # 3 years for prod, 1 year for non-prod
          }

          clustering = ["event_type", "user_id", "timestamp"]

          range_partitioning = null

          require_partition_filter = true

          encryption_configuration = {
            kms_key_name = dependency.kms.outputs.keys.bigquery.self_link
          }
        }

        transactions = {
          table_id = "transactions"
          description = "Raw transaction data"

          schema = jsonencode([
            {
              name = "transaction_id"
              type = "STRING"
              mode = "REQUIRED"
            },
            {
              name = "timestamp"
              type = "TIMESTAMP"
              mode = "REQUIRED"
            },
            {
              name = "user_id"
              type = "STRING"
              mode = "REQUIRED"
            },
            {
              name = "amount"
              type = "NUMERIC"
              mode = "REQUIRED"
            },
            {
              name = "currency"
              type = "STRING"
              mode = "REQUIRED"
            },
            {
              name = "status"
              type = "STRING"
              mode = "REQUIRED"
            },
            {
              name = "payment_method"
              type = "STRING"
              mode = "NULLABLE"
            },
            {
              name = "metadata"
              type = "JSON"
              mode = "NULLABLE"
            }
          ])

          time_partitioning = {
            type = "MONTH"
            field = "timestamp"
            expiration_ms = local.env_config.environment == "prod" ? null : 31536000000
          }

          clustering = ["status", "user_id"]
        }

        logs = {
          table_id = "application_logs"
          description = "Application logs"

          schema = jsonencode([
            {
              name = "log_timestamp"
              type = "TIMESTAMP"
              mode = "REQUIRED"
            },
            {
              name = "severity"
              type = "STRING"
              mode = "REQUIRED"
            },
            {
              name = "message"
              type = "STRING"
              mode = "REQUIRED"
            },
            {
              name = "resource"
              type = "JSON"
              mode = "NULLABLE"
            },
            {
              name = "labels"
              type = "JSON"
              mode = "NULLABLE"
            },
            {
              name = "trace_id"
              type = "STRING"
              mode = "NULLABLE"
            }
          ])

          time_partitioning = {
            type = "HOUR"
            field = "log_timestamp"
            expiration_ms = 2592000000  # 30 days
          }

          clustering = ["severity", "trace_id"]
        }
      }

      # External tables (data lake integration)
      external_tables = {
        cloud_storage_data = {
          table_id = "external_gcs_data"
          description = "External table reading from Cloud Storage"

          external_data_configuration = {
            source_uris = [
              "gs://${var.project_id}-${local.env_config.environment}-data-lake/raw/*.parquet"
            ]

            source_format = "PARQUET"

            autodetect = false

            parquet_options = {
              enum_as_string = true
              enable_list_inference = true
            }

            hive_partitioning_options = {
              mode = "AUTO"
              source_uri_prefix = "gs://${var.project_id}-${local.env_config.environment}-data-lake/raw/"
              require_partition_filter = true
            }
          }
        }
      }
    }

    # Staging/processing dataset
    staging = {
      dataset_id = "${local.dataset_prefix}_staging"
      friendly_name = "Staging and Processing"
      description = "Intermediate processing and staging area"
      location = local.region_config.bigquery_location

      default_encryption_configuration = {
        kms_key_name = dependency.kms.outputs.keys.bigquery.self_link
      }

      labels = {
        data_classification = "internal"
        pipeline_stage = "processing"
      }

      tables = {
        events_cleaned = {
          table_id = "events_cleaned"
          description = "Cleaned and validated event data"

          view = {
            query = <<-SQL
              SELECT
                event_id,
                timestamp,
                user_id,
                event_type,
                JSON_VALUE(properties, '$.category') as category,
                JSON_VALUE(properties, '$.action') as action,
                JSON_VALUE(properties, '$.label') as label,
                CAST(JSON_VALUE(properties, '$.value') AS FLOAT64) as value,
                session_id,
                device_info.device_type,
                device_info.os,
                device_info.browser,
                ST_GEOGPOINT(
                  CAST(JSON_VALUE(properties, '$.longitude') AS FLOAT64),
                  CAST(JSON_VALUE(properties, '$.latitude') AS FLOAT64)
                ) as location
              FROM `${var.project_id}.${local.dataset_prefix}_raw_data.events`
              WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
                AND event_id IS NOT NULL
                AND event_type IN ('page_view', 'click', 'conversion', 'error')
            SQL
            use_legacy_sql = false
          }
        }

        user_aggregations = {
          table_id = "user_aggregations"
          description = "User-level aggregations"

          materialized_view = {
            query = <<-SQL
              SELECT
                user_id,
                DATE(timestamp) as date,
                COUNT(DISTINCT session_id) as sessions,
                COUNT(*) as total_events,
                COUNT(DISTINCT event_type) as unique_event_types,
                MAX(timestamp) as last_activity,
                MIN(timestamp) as first_activity
              FROM `${var.project_id}.${local.dataset_prefix}_raw_data.events`
              WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
              GROUP BY user_id, date
            SQL

            enable_refresh = true
            refresh_interval_minutes = 60
          }
        }
      }

      # Scheduled queries for ETL
      scheduled_queries = {
        daily_aggregation = {
          display_name = "Daily Data Aggregation"
          schedule = "every day 02:00"
          time_zone = "America/New_York"

          query = <<-SQL
            INSERT INTO `${var.project_id}.${local.dataset_prefix}_warehouse.daily_metrics`
            SELECT
              CURRENT_DATE() as date,
              COUNT(DISTINCT user_id) as daily_active_users,
              COUNT(*) as total_events,
              SUM(CASE WHEN event_type = 'conversion' THEN 1 ELSE 0 END) as conversions
            FROM `${var.project_id}.${local.dataset_prefix}_staging.events_cleaned`
            WHERE DATE(timestamp) = CURRENT_DATE() - 1
          SQL

          notification_pubsub_topic = "projects/${var.project_id}/topics/bigquery-scheduled-query-results"
        }
      }
    }

    # Data warehouse (business-ready data)
    warehouse = {
      dataset_id = "${local.dataset_prefix}_warehouse"
      friendly_name = "Data Warehouse"
      description = "Business-ready data warehouse with clean, aggregated data"
      location = local.region_config.bigquery_location

      default_encryption_configuration = {
        kms_key_name = dependency.kms.outputs.keys.bigquery.self_link
      }

      access = [
        {
          role = "OWNER"
          user_by_email = dependency.iam.outputs.service_accounts.bigquery.email
        },
        {
          role = "READER"
          group_by_email = "business-analysts@${local.env_config.organization_domain}"
        },
        {
          role = "READER"
          group_by_email = "data-scientists@${local.env_config.organization_domain}"
        }
      ]

      labels = {
        data_classification = "confidential"
        business_critical = "true"
      }

      tables = {
        dim_users = {
          table_id = "dim_users"
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
              name = "updated_at"
              type = "TIMESTAMP"
              mode = "REQUIRED"
            },
            {
              name = "user_attributes"
              type = "JSON"
              mode = "NULLABLE"
            },
            {
              name = "lifetime_value"
              type = "NUMERIC"
              mode = "NULLABLE"
            },
            {
              name = "churn_probability"
              type = "FLOAT64"
              mode = "NULLABLE"
            },
            {
              name = "segment"
              type = "STRING"
              mode = "NULLABLE"
            }
          ])

          clustering = ["segment", "created_at"]
        }

        fact_transactions = {
          table_id = "fact_transactions"
          description = "Transaction fact table"

          schema = jsonencode([
            {
              name = "transaction_id"
              type = "STRING"
              mode = "REQUIRED"
            },
            {
              name = "transaction_date"
              type = "DATE"
              mode = "REQUIRED"
            },
            {
              name = "user_id"
              type = "STRING"
              mode = "REQUIRED"
            },
            {
              name = "amount_usd"
              type = "NUMERIC"
              mode = "REQUIRED"
            },
            {
              name = "transaction_type"
              type = "STRING"
              mode = "REQUIRED"
            },
            {
              name = "status"
              type = "STRING"
              mode = "REQUIRED"
            }
          ])

          time_partitioning = {
            type = "DAY"
            field = "transaction_date"
          }

          clustering = ["user_id", "transaction_type", "status"]
        }

        daily_metrics = {
          table_id = "daily_metrics"
          description = "Daily aggregated metrics"

          schema = jsonencode([
            {
              name = "date"
              type = "DATE"
              mode = "REQUIRED"
            },
            {
              name = "daily_active_users"
              type = "INT64"
              mode = "REQUIRED"
            },
            {
              name = "total_events"
              type = "INT64"
              mode = "REQUIRED"
            },
            {
              name = "conversions"
              type = "INT64"
              mode = "REQUIRED"
            },
            {
              name = "revenue"
              type = "NUMERIC"
              mode = "NULLABLE"
            }
          ])

          time_partitioning = {
            type = "DAY"
            field = "date"
          }
        }
      }
    }

    # Machine Learning dataset
    ml_datasets = {
      dataset_id = "${local.dataset_prefix}_ml"
      friendly_name = "Machine Learning"
      description = "Dataset for ML models and features"
      location = local.region_config.bigquery_location

      labels = {
        purpose = "machine_learning"
        data_classification = "sensitive"
      }

      # ML models
      models = {
        user_churn_model = {
          model_id = "user_churn_prediction"
          model_type = "LOGISTIC_REG"
          description = "Predict user churn probability"

          training_query = <<-SQL
            SELECT
              churn_label,
              days_since_last_activity,
              total_sessions,
              average_session_duration,
              total_transactions,
              total_revenue
            FROM `${var.project_id}.${local.dataset_prefix}_ml.training_data`
            WHERE DATE(created_at) < CURRENT_DATE() - 30
          SQL

          options = {
            model_type = "LOGISTIC_REG"
            input_label_cols = ["churn_label"]
            max_iterations = 20
            learn_rate_strategy = "LINE_SEARCH"
            early_stop = true
            data_split_method = "AUTO_SPLIT"
            l1_reg = 0.1
            l2_reg = 0.1
          }
        }

        revenue_forecast = {
          model_id = "revenue_forecast"
          model_type = "ARIMA_PLUS"
          description = "Forecast revenue trends"

          training_query = <<-SQL
            SELECT
              date,
              daily_revenue
            FROM `${var.project_id}.${local.dataset_prefix}_warehouse.daily_metrics`
            WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR)
          SQL

          options = {
            model_type = "ARIMA_PLUS"
            time_series_timestamp_col = "date"
            time_series_data_col = "daily_revenue"
            horizon = 30
            auto_arima = true
            decompose_time_series = true
            clean_spikes_and_dips = true
          }
        }

        anomaly_detection = {
          model_id = "anomaly_detection"
          model_type = "KMEANS"
          description = "Detect anomalous patterns"

          training_query = <<-SQL
            SELECT
              event_count,
              unique_users,
              average_value,
              error_rate
            FROM `${var.project_id}.${local.dataset_prefix}_ml.hourly_metrics`
          SQL

          options = {
            model_type = "KMEANS"
            num_clusters = 5
            standardize_features = true
            init_method = "KMEANS++"
          }
        }
      }

      # Feature store tables
      tables = {
        user_features = {
          table_id = "user_features"
          description = "User feature store for ML"

          schema = jsonencode([
            {
              name = "user_id"
              type = "STRING"
              mode = "REQUIRED"
            },
            {
              name = "feature_timestamp"
              type = "TIMESTAMP"
              mode = "REQUIRED"
            },
            {
              name = "features"
              type = "RECORD"
              mode = "REPEATED"
              fields = [
                {
                  name = "feature_name"
                  type = "STRING"
                  mode = "REQUIRED"
                },
                {
                  name = "feature_value"
                  type = "FLOAT64"
                  mode = "REQUIRED"
                }
              ]
            }
          ])

          time_partitioning = {
            type = "DAY"
            field = "feature_timestamp"
          }

          clustering = ["user_id"]
        }
      }
    }

    # Compliance and audit dataset
    audit = {
      dataset_id = "${local.dataset_prefix}_audit"
      friendly_name = "Audit and Compliance"
      description = "Audit logs and compliance data"
      location = local.region_config.bigquery_location

      default_table_expiration_ms = null  # Never expire audit data

      access = [
        {
          role = "OWNER"
          user_by_email = dependency.iam.outputs.service_accounts.bigquery.email
        },
        {
          role = "READER"
          group_by_email = "compliance-team@${local.env_config.organization_domain}"
        }
      ]

      labels = {
        data_classification = "highly_confidential"
        compliance_required = "true"
        retention_years = "7"
      }

      tables = {
        data_access_logs = {
          table_id = "data_access_logs"
          description = "Logs of all data access"

          schema = jsonencode([
            {
              name = "access_timestamp"
              type = "TIMESTAMP"
              mode = "REQUIRED"
            },
            {
              name = "user_email"
              type = "STRING"
              mode = "REQUIRED"
            },
            {
              name = "dataset_id"
              type = "STRING"
              mode = "REQUIRED"
            },
            {
              name = "table_id"
              type = "STRING"
              mode = "NULLABLE"
            },
            {
              name = "query"
              type = "STRING"
              mode = "NULLABLE"
            },
            {
              name = "bytes_processed"
              type = "INT64"
              mode = "NULLABLE"
            },
            {
              name = "slot_ms"
              type = "INT64"
              mode = "NULLABLE"
            }
          ])

          time_partitioning = {
            type = "DAY"
            field = "access_timestamp"
          }

          clustering = ["user_email", "dataset_id"]
        }
      }
    }
  }

  # Data Transfer Service configurations
  data_transfers = {
    # Cloud Storage to BigQuery
    gcs_to_bq = {
      display_name = "GCS to BigQuery Transfer"
      data_source_id = "google_cloud_storage"
      destination_dataset_id = "${local.dataset_prefix}_raw_data"
      schedule = "every day 01:00"

      params = {
        data_path_template = "gs://${var.project_id}-${local.env_config.environment}-data-lake/daily/{{run_date}}/*.json"
        destination_table_name_template = "events_{{run_date}}"
        file_format = "JSON"
        max_bad_records = 100
        write_disposition = "WRITE_APPEND"
      }
    }

    # Scheduled query transfer
    scheduled_query = {
      display_name = "Daily Aggregation Query"
      data_source_id = "scheduled_query"
      schedule = "every day 03:00"

      query = <<-SQL
        EXPORT DATA OPTIONS(
          uri='gs://${var.project_id}-${local.env_config.environment}-exports/daily/*.csv',
          format='CSV',
          overwrite=true
        ) AS
        SELECT * FROM `${var.project_id}.${local.dataset_prefix}_warehouse.daily_metrics`
        WHERE date = CURRENT_DATE() - 1
      SQL
    }
  }

  # BigQuery connections for external data sources
  connections = {
    cloud_sql = {
      connection_id = "${local.env_config.environment}-cloudsql-connection"
      location = local.region_config.region
      friendly_name = "Cloud SQL Connection"
      description = "Connection to Cloud SQL for federated queries"

      cloud_sql = {
        instance_id = "${var.project_id}:${local.region_config.region}:${local.env_config.environment}-postgres-main"
        database = "production"
        type = "POSTGRES"
        credential = {
          username = "bigquery_user"
          password = "PLACEHOLDER"  # Use Secret Manager in production
        }
      }
    }

    bigtable = {
      connection_id = "${local.env_config.environment}-bigtable-connection"
      location = local.region_config.region
      friendly_name = "Bigtable Connection"
      description = "Connection to Bigtable for real-time data"

      cloud_bigtable = {
        instance_id = "${local.env_config.environment}-bigtable"
        project_id = var.project_id
        app_profile_id = "default"
      }
    }
  }

  # Data governance configuration
  data_governance = {
    # Column-level security
    column_level_security = {
      pii_columns = [
        "email",
        "phone_number",
        "ssn",
        "credit_card",
        "ip_address"
      ]

      masking_rules = {
        email = "HASH"
        phone_number = "DEFAULT_MASKING"
        ssn = "ALWAYS_NULL"
        credit_card = "FIRST_FOUR"
      }
    }

    # Row-level security policies
    row_level_security = {
      user_data_policy = {
        dataset_id = "${local.dataset_prefix}_warehouse"
        table_id = "dim_users"

        filter = "user_id IN (SELECT user_id FROM authorized_users WHERE email = SESSION_USER())"
      }
    }

    # Data classification
    data_classification = {
      public = ["aggregated_metrics", "public_reports"]
      internal = ["staging_data", "intermediate_results"]
      confidential = ["user_data", "transaction_data"]
      highly_confidential = ["pii_data", "financial_data", "audit_logs"]
    }

    # Retention policies
    retention_policies = {
      raw_data = local.env_config.environment == "prod" ? "3 years" : "90 days"
      staging_data = local.env_config.environment == "prod" ? "1 year" : "30 days"
      warehouse_data = local.env_config.environment == "prod" ? "7 years" : "1 year"
      audit_data = "7 years"  # Regulatory requirement
    }
  }

  # Monitoring and alerting
  monitoring_config = {
    alerts = {
      high_slot_usage = {
        display_name = "High BigQuery Slot Usage"
        conditions = {
          threshold_percent = 80
          duration = "300s"
        }
      }

      query_failure = {
        display_name = "BigQuery Query Failures"
        conditions = {
          threshold_count = 10
          duration = "600s"
        }
      }

      data_freshness = {
        display_name = "Stale Data Alert"
        conditions = {
          max_staleness_hours = 24
        }
      }

      cost_anomaly = {
        display_name = "BigQuery Cost Anomaly"
        conditions = {
          threshold_increase_percent = 150
          duration = "86400s"
        }
      }
    }

    metrics = {
      slot_utilization = {
        metric = "bigquery.googleapis.com/slots/total_allocated"
        aggregation = "ALIGN_MEAN"
      }

      query_count = {
        metric = "bigquery.googleapis.com/query/count"
        aggregation = "ALIGN_RATE"
      }

      bytes_processed = {
        metric = "bigquery.googleapis.com/query/scanned_bytes"
        aggregation = "ALIGN_DELTA"
      }
    }
  }

  # Cost optimization configuration
  cost_optimization = {
    # Reservation and capacity commitments
    reservations = local.env_config.environment == "prod" ? {
      slot_capacity = 500
      commitment_plan = "ANNUAL"
    } : {
      slot_capacity = 100
      commitment_plan = "FLEX"
    }

    # Query optimization
    query_optimization = {
      require_partition_filter = true
      use_materialized_views = true
      enable_standard_sql_geography = true
      use_query_cache = true
    }

    # Storage optimization
    storage_optimization = {
      table_expiration_days = local.env_config.environment == "prod" ? null : 90
      partition_expiration_days = local.env_config.environment == "prod" ? 365 : 30
      enable_physical_storage_billing = true
    }
  }
}

# Module inputs
inputs = {
  # Project configuration
  project_id = var.project_id
  region     = local.region_config.region
  location   = local.region_config.bigquery_location

  # Datasets configuration
  datasets = local.datasets

  # Data transfers
  data_transfers = local.data_transfers

  # Connections
  connections = local.connections

  # Data governance
  data_governance = local.data_governance

  # Encryption configuration
  encryption_config = {
    kms_key_name = dependency.kms.outputs.keys.bigquery.self_link
  }

  # IAM configuration
  dataset_iam = {
    "${local.dataset_prefix}_warehouse" = {
      "roles/bigquery.dataViewer" = [
        "group:business-analysts@${local.env_config.organization_domain}"
      ]
      "roles/bigquery.dataEditor" = [
        "serviceAccount:${dependency.iam.outputs.service_accounts.dataflow.email}"
      ]
    }
  }

  # Monitoring configuration
  monitoring_config = local.monitoring_config
  enable_monitoring = true
  create_monitoring_dashboard = local.env_config.environment == "prod"
  create_monitoring_alerts = local.env_config.environment != "dev"

  # Cost optimization
  cost_optimization = local.cost_optimization

  # Labels
  labels = merge(
    var.common_labels,
    {
      component = "data"
      service   = "bigquery"
      tier      = "analytics"
    }
  )

  # Dependencies
  depends_on = [dependency.kms, dependency.iam]
}