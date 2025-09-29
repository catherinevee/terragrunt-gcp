# Production Cloud Logging Configuration
# This configuration provides comprehensive logging, log routing, analysis, and alerting capabilities

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
  source = "../../../../../../modules/logging/cloud-logging"
}

dependency "vpc" {
  config_path = "../../networking/vpc"
  mock_outputs = {
    network_self_link = "projects/mock-project/global/networks/mock-network"
    network_name = "mock-network"
  }
}

dependency "gke" {
  config_path = "../../kubernetes/gke-cluster"
  mock_outputs = {
    cluster_name = "mock-cluster"
    cluster_endpoint = "https://mock-endpoint"
    cluster_ca_certificate = "mock-cert"
  }
}

dependency "cloud_sql" {
  config_path = "../../database/cloud-sql"
  mock_outputs = {
    instance_name = "mock-instance"
    instance_connection_name = "mock-project:us-central1:mock-instance"
  }
}

dependency "gcs" {
  config_path = "../../storage/gcs-buckets"
  mock_outputs = {
    bucket_names = ["mock-bucket-1", "mock-bucket-2"]
  }
}

dependency "monitoring" {
  config_path = "../cloud-monitoring"
  mock_outputs = {
    notification_channels = {
      email = "projects/mock-project/notificationChannels/mock-channel"
    }
  }
}

inputs = {
  project_id = "your-prod-project-id"
  region     = "us-central1"

  # Log Routing Configuration
  log_sinks = {
    # Infrastructure Logs to BigQuery
    infrastructure_logs = {
      description = "Infrastructure logs for analysis and compliance"
      destination = "bigquery.googleapis.com/projects/your-prod-project-id/datasets/infrastructure_logs"
      filter = <<-EOT
        resource.type=("gce_instance" OR "k8s_cluster" OR "k8s_node" OR "k8s_pod" OR "k8s_container") AND
        (severity >= "INFO" OR protoPayload.serviceName="compute.googleapis.com")
      EOT
      unique_writer_identity = true
      bigquery_options = {
        use_partitioned_tables = true
        partition_expiration_ms = 7776000000  # 90 days
      }
    }

    # Application Logs to BigQuery
    application_logs = {
      description = "Application logs for debugging and analysis"
      destination = "bigquery.googleapis.com/projects/your-prod-project-id/datasets/application_logs"
      filter = <<-EOT
        resource.type=("k8s_container" OR "cloud_run_revision" OR "gae_app") AND
        (severity >= "INFO" OR jsonPayload.type="application")
      EOT
      unique_writer_identity = true
      bigquery_options = {
        use_partitioned_tables = true
        partition_expiration_ms = 2592000000  # 30 days
      }
    }

    # Security Logs to Cloud Storage
    security_logs = {
      description = "Security and audit logs for compliance"
      destination = "storage.googleapis.com/your-prod-project-id-security-logs"
      filter = <<-EOT
        protoPayload.serviceName=("cloudresourcemanager.googleapis.com" OR "iam.googleapis.com" OR "admin.googleapis.com") OR
        protoPayload.methodName=("SetIamPolicy" OR "CreateServiceAccount" OR "DeleteServiceAccount") OR
        severity >= "WARNING"
      EOT
      unique_writer_identity = true
    }

    # Database Logs to BigQuery
    database_logs = {
      description = "Database logs for performance analysis"
      destination = "bigquery.googleapis.com/projects/your-prod-project-id/datasets/database_logs"
      filter = <<-EOT
        resource.type="cloudsql_database" AND
        (severity >= "INFO" OR jsonPayload.type="slow_query")
      EOT
      unique_writer_identity = true
      bigquery_options = {
        use_partitioned_tables = true
        partition_expiration_ms = 5184000000  # 60 days
      }
    }

    # Network Logs to BigQuery
    network_logs = {
      description = "Network and VPC flow logs for analysis"
      destination = "bigquery.googleapis.com/projects/your-prod-project-id/datasets/network_logs"
      filter = <<-EOT
        resource.type=("gce_subnetwork" OR "http_load_balancer" OR "vpc_flow") AND
        severity >= "INFO"
      EOT
      unique_writer_identity = true
      bigquery_options = {
        use_partitioned_tables = true
        partition_expiration_ms = 7776000000  # 90 days
      }
    }

    # Error Logs to Pub/Sub for real-time processing
    error_logs = {
      description = "Critical errors for immediate alerting"
      destination = "pubsub.googleapis.com/projects/your-prod-project-id/topics/error-logs"
      filter = <<-EOT
        severity >= "ERROR" AND
        NOT protoPayload.serviceName="logging.googleapis.com"
      EOT
      unique_writer_identity = true
    }
  }

  # Log-based Metrics
  log_metrics = {
    # Application Error Rate
    application_error_rate = {
      description = "Rate of application errors per minute"
      filter = <<-EOT
        resource.type="k8s_container" AND
        severity="ERROR" AND
        jsonPayload.type="application"
      EOT
      metric_descriptor = {
        metric_kind = "GAUGE"
        value_type  = "DOUBLE"
        display_name = "Application Error Rate"
      }
      label_extractors = {
        container_name = "EXTRACT(resource.labels.container_name)"
        namespace_name = "EXTRACT(resource.labels.namespace_name)"
        pod_name = "EXTRACT(resource.labels.pod_name)"
      }
    }

    # Authentication Failures
    auth_failures = {
      description = "Failed authentication attempts"
      filter = <<-EOT
        protoPayload.serviceName="iam.googleapis.com" AND
        protoPayload.authenticationInfo.principalEmail!="" AND
        severity="ERROR"
      EOT
      metric_descriptor = {
        metric_kind = "GAUGE"
        value_type  = "INT64"
        display_name = "Authentication Failures"
      }
      label_extractors = {
        principal_email = "EXTRACT(protoPayload.authenticationInfo.principalEmail)"
        service_name = "EXTRACT(protoPayload.serviceName)"
      }
    }

    # High Memory Usage
    high_memory_usage = {
      description = "Pods with high memory usage"
      filter = <<-EOT
        resource.type="k8s_container" AND
        jsonPayload.memory_usage_bytes > 1000000000
      EOT
      metric_descriptor = {
        metric_kind = "GAUGE"
        value_type  = "DOUBLE"
        display_name = "High Memory Usage Events"
      }
      label_extractors = {
        container_name = "EXTRACT(resource.labels.container_name)"
        pod_name = "EXTRACT(resource.labels.pod_name)"
      }
    }

    # Database Slow Queries
    database_slow_queries = {
      description = "Database queries taking longer than threshold"
      filter = <<-EOT
        resource.type="cloudsql_database" AND
        jsonPayload.type="slow_query" AND
        jsonPayload.query_time > 5
      EOT
      metric_descriptor = {
        metric_kind = "GAUGE"
        value_type  = "INT64"
        display_name = "Database Slow Queries"
      }
      label_extractors = {
        database_id = "EXTRACT(resource.labels.database_id)"
        query_type = "EXTRACT(jsonPayload.query_type)"
      }
    }

    # Network Security Events
    network_security_events = {
      description = "Network security related events"
      filter = <<-EOT
        resource.type="gce_subnetwork" AND
        (jsonPayload.connection.src_ip!~"^10\\." AND jsonPayload.connection.src_ip!~"^192\\.168\\.") AND
        jsonPayload.connection.dest_port IN (22, 3389, 1433, 3306, 5432)
      EOT
      metric_descriptor = {
        metric_kind = "GAUGE"
        value_type  = "INT64"
        display_name = "Network Security Events"
      }
      label_extractors = {
        src_ip = "EXTRACT(jsonPayload.connection.src_ip)"
        dest_port = "EXTRACT(jsonPayload.connection.dest_port)"
      }
    }

    # API Rate Limiting
    api_rate_limiting = {
      description = "API requests being rate limited"
      filter = <<-EOT
        resource.type="http_load_balancer" AND
        httpRequest.status = 429
      EOT
      metric_descriptor = {
        metric_kind = "GAUGE"
        value_type  = "INT64"
        display_name = "API Rate Limiting Events"
      }
      label_extractors = {
        backend_service = "EXTRACT(resource.labels.backend_service_name)"
        client_ip = "EXTRACT(httpRequest.remoteIp)"
      }
    }
  }

  # Log Buckets for retention control
  log_buckets = {
    # Default bucket with extended retention
    _Default = {
      retention_days = 400
      locked = false
    }

    # Security logs with long-term retention
    security_bucket = {
      retention_days = 2555  # 7 years for compliance
      locked = true
      description = "Security and audit logs with extended retention"
    }

    # Application logs with medium retention
    application_bucket = {
      retention_days = 90
      locked = false
      description = "Application logs for debugging and analysis"
    }

    # Infrastructure logs with standard retention
    infrastructure_bucket = {
      retention_days = 180
      locked = false
      description = "Infrastructure logs for operational analysis"
    }
  }

  # Log Views for access control
  log_views = {
    # Security team view
    security_view = {
      bucket = "security_bucket"
      description = "Security team access to audit and security logs"
      filter = <<-EOT
        protoPayload.serviceName=("cloudresourcemanager.googleapis.com" OR "iam.googleapis.com") OR
        severity >= "WARNING"
      EOT
    }

    # Development team view
    development_view = {
      bucket = "application_bucket"
      description = "Development team access to application logs"
      filter = <<-EOT
        resource.type=("k8s_container" OR "cloud_run_revision") AND
        resource.labels.namespace_name!="kube-system"
      EOT
    }

    # Operations team view
    operations_view = {
      bucket = "infrastructure_bucket"
      description = "Operations team access to infrastructure logs"
      filter = <<-EOT
        resource.type=("gce_instance" OR "k8s_cluster" OR "k8s_node") OR
        protoPayload.serviceName="compute.googleapis.com"
      EOT
    }
  }

  # Exclusion Filters to reduce costs
  exclusion_filters = {
    # Exclude noisy health check logs
    health_check_exclusions = {
      description = "Exclude routine health check logs"
      filter = <<-EOT
        resource.type="http_load_balancer" AND
        httpRequest.requestUrl=~"/health" AND
        httpRequest.status = 200
      EOT
      disabled = false
    }

    # Exclude verbose kube-system logs
    kube_system_exclusions = {
      description = "Exclude verbose kube-system namespace logs"
      filter = <<-EOT
        resource.type="k8s_container" AND
        resource.labels.namespace_name="kube-system" AND
        severity < "WARNING"
      EOT
      disabled = false
    }

    # Exclude successful authentication logs
    successful_auth_exclusions = {
      description = "Exclude successful authentication events to reduce volume"
      filter = <<-EOT
        protoPayload.serviceName="iam.googleapis.com" AND
        protoPayload.methodName="google.iam.admin.v1.CreateServiceAccountKey" AND
        severity="NOTICE"
      EOT
      disabled = false
    }

    # Exclude routine compute operations
    routine_compute_exclusions = {
      description = "Exclude routine compute operations"
      filter = <<-EOT
        protoPayload.serviceName="compute.googleapis.com" AND
        protoPayload.methodName=~"(get|list)" AND
        severity="INFO"
      EOT
      disabled = false
    }
  }

  # BigQuery Datasets for log analysis
  bigquery_datasets = {
    infrastructure_logs = {
      description = "Infrastructure logs dataset"
      location = "US"
      default_table_expiration_ms = 7776000000  # 90 days
      labels = {
        environment = "production"
        team = "infrastructure"
        log_type = "infrastructure"
      }
      access = [
        {
          role = "OWNER"
          user_by_email = "infrastructure-team@your-company.com"
        },
        {
          role = "READER"
          group_by_email = "engineering@your-company.com"
        }
      ]
    }

    application_logs = {
      description = "Application logs dataset"
      location = "US"
      default_table_expiration_ms = 2592000000  # 30 days
      labels = {
        environment = "production"
        team = "development"
        log_type = "application"
      }
      access = [
        {
          role = "OWNER"
          user_by_email = "development-team@your-company.com"
        },
        {
          role = "READER"
          group_by_email = "engineering@your-company.com"
        }
      ]
    }

    database_logs = {
      description = "Database logs dataset"
      location = "US"
      default_table_expiration_ms = 5184000000  # 60 days
      labels = {
        environment = "production"
        team = "database"
        log_type = "database"
      }
      access = [
        {
          role = "OWNER"
          user_by_email = "database-team@your-company.com"
        },
        {
          role = "READER"
          group_by_email = "engineering@your-company.com"
        }
      ]
    }

    network_logs = {
      description = "Network and VPC logs dataset"
      location = "US"
      default_table_expiration_ms = 7776000000  # 90 days
      labels = {
        environment = "production"
        team = "network"
        log_type = "network"
      }
      access = [
        {
          role = "OWNER"
          user_by_email = "network-team@your-company.com"
        },
        {
          role = "READER"
          group_by_email = "engineering@your-company.com"
        }
      ]
    }
  }

  # Pub/Sub Topics for real-time log processing
  pubsub_topics = {
    error_logs = {
      description = "Topic for critical error logs requiring immediate attention"
      message_retention_duration = "604800s"  # 7 days
      labels = {
        environment = "production"
        purpose = "error-alerting"
      }
    }

    security_alerts = {
      description = "Topic for security-related log events"
      message_retention_duration = "1209600s"  # 14 days
      labels = {
        environment = "production"
        purpose = "security-monitoring"
      }
    }

    audit_trail = {
      description = "Topic for audit trail events requiring tracking"
      message_retention_duration = "2592000s"  # 30 days
      labels = {
        environment = "production"
        purpose = "audit-compliance"
      }
    }
  }

  # Pub/Sub Subscriptions for log processing
  pubsub_subscriptions = {
    error_logs_processor = {
      topic = "error_logs"
      push_config = {
        push_endpoint = "https://your-error-processor.run.app/process-errors"
        attributes = {
          x-goog-version = "v1"
        }
      }
      ack_deadline_seconds = 60
      retry_policy = {
        minimum_backoff = "10s"
        maximum_backoff = "600s"
      }
    }

    security_alerts_processor = {
      topic = "security_alerts"
      push_config = {
        push_endpoint = "https://your-security-processor.run.app/process-security"
        attributes = {
          x-goog-version = "v1"
        }
      }
      ack_deadline_seconds = 120
      retry_policy = {
        minimum_backoff = "15s"
        maximum_backoff = "900s"
      }
    }

    audit_trail_archiver = {
      topic = "audit_trail"
      push_config = {
        push_endpoint = "https://your-audit-archiver.run.app/archive-audit"
        attributes = {
          x-goog-version = "v1"
        }
      }
      ack_deadline_seconds = 300
      retry_policy = {
        minimum_backoff = "30s"
        maximum_backoff = "1800s"
      }
    }
  }

  # Cloud Storage Buckets for log archival
  storage_buckets = {
    security_logs_archive = {
      name = "your-prod-project-id-security-logs"
      location = "US"
      storage_class = "NEARLINE"

      versioning = {
        enabled = true
      }

      lifecycle_rule = [
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
            type = "SetStorageClass"
            storage_class = "ARCHIVE"
          }
          condition = {
            age = 365
          }
        }
      ]

      retention_policy = {
        retention_period = 220752000  # 7 years in seconds
        is_locked = true
      }

      labels = {
        environment = "production"
        purpose = "security-logs"
        compliance = "required"
      }
    }

    application_logs_archive = {
      name = "your-prod-project-id-application-logs"
      location = "US"
      storage_class = "STANDARD"

      lifecycle_rule = [
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
            type = "Delete"
          }
          condition = {
            age = 90
          }
        }
      ]

      labels = {
        environment = "production"
        purpose = "application-logs"
      }
    }
  }

  # Log Analytics Saved Queries
  saved_queries = {
    # Top error sources
    top_error_sources = {
      description = "Find the top sources of errors in the last 24 hours"
      query = <<-EOT
        SELECT
          resource.labels.container_name,
          resource.labels.namespace_name,
          COUNT(*) as error_count
        FROM `your-prod-project-id.application_logs.kubernetes_container_*`
        WHERE
          _PARTITIONTIME >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
          AND severity = "ERROR"
        GROUP BY 1, 2
        ORDER BY error_count DESC
        LIMIT 20
      EOT
    }

    # Security events analysis
    security_events_analysis = {
      description = "Analyze security events and patterns"
      query = <<-EOT
        SELECT
          protoPayload.authenticationInfo.principalEmail,
          protoPayload.serviceName,
          protoPayload.methodName,
          COUNT(*) as event_count,
          MIN(timestamp) as first_seen,
          MAX(timestamp) as last_seen
        FROM `your-prod-project-id.infrastructure_logs.cloudaudit_googleapis_com_*`
        WHERE
          _PARTITIONTIME >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
          AND severity >= "WARNING"
        GROUP BY 1, 2, 3
        ORDER BY event_count DESC
      EOT
    }

    # Database performance analysis
    database_performance = {
      description = "Analyze database performance metrics"
      query = <<-EOT
        SELECT
          resource.labels.database_id,
          AVG(CAST(jsonPayload.query_time AS FLOAT64)) as avg_query_time,
          MAX(CAST(jsonPayload.query_time AS FLOAT64)) as max_query_time,
          COUNT(*) as total_queries,
          COUNT(CASE WHEN CAST(jsonPayload.query_time AS FLOAT64) > 5 THEN 1 END) as slow_queries
        FROM `your-prod-project-id.database_logs.cloudsql_googleapis_com_*`
        WHERE
          _PARTITIONTIME >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
          AND jsonPayload.query_time IS NOT NULL
        GROUP BY 1
        ORDER BY avg_query_time DESC
      EOT
    }

    # Network traffic analysis
    network_traffic_analysis = {
      description = "Analyze network traffic patterns and anomalies"
      query = <<-EOT
        SELECT
          jsonPayload.connection.src_ip,
          jsonPayload.connection.dest_port,
          COUNT(*) as connection_count,
          COUNT(DISTINCT jsonPayload.connection.dest_ip) as unique_destinations
        FROM `your-prod-project-id.network_logs.compute_googleapis_com_vpc_flows_*`
        WHERE
          _PARTITIONTIME >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
          AND NOT REGEXP_CONTAINS(jsonPayload.connection.src_ip, r'^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)')
        GROUP BY 1, 2
        HAVING connection_count > 100
        ORDER BY connection_count DESC
      EOT
    }
  }

  # Integration with existing resources
  network_self_link = dependency.vpc.outputs.network_self_link
  cluster_name = dependency.gke.outputs.cluster_name
  database_instance_name = dependency.cloud_sql.outputs.instance_name
  storage_bucket_names = dependency.gcs.outputs.bucket_names
  notification_channels = dependency.monitoring.outputs.notification_channels

  # Tags for resource organization
  tags = {
    Environment = "production"
    Team = "platform"
    Component = "logging"
    CostCenter = "engineering"
    Compliance = "required"
    DataClassification = "internal"
    BackupRequired = "true"
    MonitoringRequired = "true"
  }
}