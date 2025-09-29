# Production Cloud Logging Configuration - US East 1 (Disaster Recovery)
# This configuration provides comprehensive logging for the disaster recovery region

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
  }
}

dependency "cloud_sql" {
  config_path = "../../database/cloud-sql"
  mock_outputs = {
    instance_name = "mock-instance"
    instance_connection_name = "mock-project:us-east1:mock-instance"
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
  region     = local.region

  # Log Routing Configuration for DR region
  log_sinks = {
    # DR-specific infrastructure logs
    dr_infrastructure_logs = {
      description = "DR infrastructure logs for disaster recovery analysis"
      destination = "bigquery.googleapis.com/projects/your-prod-project-id/datasets/dr_infrastructure_logs"
      filter = <<-EOT
        resource.type=("gce_instance" OR "k8s_cluster" OR "k8s_node" OR "k8s_pod" OR "k8s_container") AND
        resource.labels.region="${local.region}" AND
        (severity >= "INFO" OR protoPayload.serviceName="compute.googleapis.com")
      EOT
      unique_writer_identity = true
      bigquery_options = {
        use_partitioned_tables = true
        partition_expiration_ms = 7776000000  # 90 days
      }
    }

    # DR application logs
    dr_application_logs = {
      description = "DR application logs for debugging and analysis"
      destination = "bigquery.googleapis.com/projects/your-prod-project-id/datasets/dr_application_logs"
      filter = <<-EOT
        resource.type=("k8s_container" OR "cloud_run_revision" OR "gae_app") AND
        resource.labels.region="${local.region}" AND
        (severity >= "INFO" OR jsonPayload.type="application")
      EOT
      unique_writer_identity = true
      bigquery_options = {
        use_partitioned_tables = true
        partition_expiration_ms = 2592000000  # 30 days
      }
    }

    # DR security and audit logs
    dr_security_logs = {
      description = "DR security and audit logs for compliance"
      destination = "storage.googleapis.com/your-prod-project-id-dr-security-logs"
      filter = <<-EOT
        resource.labels.region="${local.region}" AND
        (protoPayload.serviceName=("cloudresourcemanager.googleapis.com" OR "iam.googleapis.com" OR "admin.googleapis.com") OR
        protoPayload.methodName=("SetIamPolicy" OR "CreateServiceAccount" OR "DeleteServiceAccount") OR
        severity >= "WARNING")
      EOT
      unique_writer_identity = true
    }

    # Cross-region replication logs
    cross_region_replication_logs = {
      description = "Cross-region replication and DR synchronization logs"
      destination = "bigquery.googleapis.com/projects/your-prod-project-id/datasets/cross_region_replication_logs"
      filter = <<-EOT
        (resource.type="storage_transfer_job" OR
         resource.type="cloudsql_database" OR
         protoPayload.serviceName="storage.googleapis.com") AND
        (jsonPayload.transfer_type="cross_region" OR
         jsonPayload.operation_type="replication" OR
         protoPayload.methodName=~".*[Rr]eplicat.*")
      EOT
      unique_writer_identity = true
      bigquery_options = {
        use_partitioned_tables = true
        partition_expiration_ms = 5184000000  # 60 days
      }
    }

    # DR failover and testing logs
    dr_failover_logs = {
      description = "DR failover and testing event logs"
      destination = "pubsub.googleapis.com/projects/your-prod-project-id/topics/dr-failover-logs"
      filter = <<-EOT
        resource.labels.region="${local.region}" AND
        (jsonPayload.event_type="failover" OR
         jsonPayload.event_type="failback" OR
         jsonPayload.event_type="dr_test" OR
         jsonPayload.operation_type="disaster_recovery")
      EOT
      unique_writer_identity = true
    }

    # Network connectivity logs between regions
    cross_region_network_logs = {
      description = "Network connectivity logs between primary and DR regions"
      destination = "bigquery.googleapis.com/projects/your-prod-project-id/datasets/cross_region_network_logs"
      filter = <<-EOT
        resource.type=("gce_subnetwork" OR "vpn_tunnel" OR "gce_route") AND
        (resource.labels.region="${local.region}" OR
         jsonPayload.peer_region="us-central1") AND
        severity >= "INFO"
      EOT
      unique_writer_identity = true
      bigquery_options = {
        use_partitioned_tables = true
        partition_expiration_ms = 7776000000  # 90 days
      }
    }

    # Backup and restore operation logs
    backup_restore_logs = {
      description = "Backup and restore operation logs for DR"
      destination = "storage.googleapis.com/your-prod-project-id-backup-logs"
      filter = <<-EOT
        resource.labels.region="${local.region}" AND
        (jsonPayload.operation_type=~".*backup.*" OR
         jsonPayload.operation_type=~".*restore.*" OR
         protoPayload.methodName=~".*[Bb]ackup.*" OR
         protoPayload.methodName=~".*[Rr]estore.*")
      EOT
      unique_writer_identity = true
    }
  }

  # DR-specific Log-based Metrics
  log_metrics = {
    # DR failover events
    dr_failover_events = {
      description = "Count of DR failover events"
      filter = <<-EOT
        resource.labels.region="${local.region}" AND
        jsonPayload.event_type="failover"
      EOT
      metric_descriptor = {
        metric_kind = "GAUGE"
        value_type  = "INT64"
        display_name = "DR Failover Events"
      }
      label_extractors = {
        failover_type = "EXTRACT(jsonPayload.failover_type)"
        trigger_reason = "EXTRACT(jsonPayload.trigger_reason)"
      }
    }

    # Cross-region replication lag
    cross_region_replication_lag = {
      description = "Cross-region replication lag metrics"
      filter = <<-EOT
        resource.type="cloudsql_database" AND
        resource.labels.region="${local.region}" AND
        jsonPayload.replication_lag_seconds > 0
      EOT
      metric_descriptor = {
        metric_kind = "GAUGE"
        value_type  = "DOUBLE"
        display_name = "Cross-Region Replication Lag"
      }
      label_extractors = {
        database_id = "EXTRACT(resource.labels.database_id)"
        master_region = "EXTRACT(jsonPayload.master_region)"
      }
      value_extractor = "EXTRACT(jsonPayload.replication_lag_seconds)"
    }

    # DR test success rate
    dr_test_success_rate = {
      description = "DR test success rate metrics"
      filter = <<-EOT
        resource.labels.region="${local.region}" AND
        jsonPayload.event_type="dr_test"
      EOT
      metric_descriptor = {
        metric_kind = "GAUGE"
        value_type  = "DOUBLE"
        display_name = "DR Test Success Rate"
      }
      label_extractors = {
        test_type = "EXTRACT(jsonPayload.test_type)"
        test_scenario = "EXTRACT(jsonPayload.test_scenario)"
      }
    }

    # Storage replication failures
    storage_replication_failures = {
      description = "Storage replication failure events"
      filter = <<-EOT
        resource.type="storage_transfer_job" AND
        severity="ERROR" AND
        jsonPayload.transfer_type="cross_region"
      EOT
      metric_descriptor = {
        metric_kind = "GAUGE"
        value_type  = "INT64"
        display_name = "Storage Replication Failures"
      }
      label_extractors = {
        source_bucket = "EXTRACT(jsonPayload.source_bucket)"
        destination_bucket = "EXTRACT(jsonPayload.destination_bucket)"
        error_type = "EXTRACT(jsonPayload.error_type)"
      }
    }

    # Network partition events
    network_partition_events = {
      description = "Network partition events between regions"
      filter = <<-EOT
        resource.type="vpn_tunnel" AND
        severity="ERROR" AND
        (jsonPayload.event_type="tunnel_down" OR
         jsonPayload.event_type="connectivity_lost")
      EOT
      metric_descriptor = {
        metric_kind = "GAUGE"
        value_type  = "INT64"
        display_name = "Network Partition Events"
      }
      label_extractors = {
        tunnel_name = "EXTRACT(resource.labels.tunnel_name)"
        peer_region = "EXTRACT(jsonPayload.peer_region)"
      }
    }

    # RTO/RPO compliance metrics
    rto_rpo_compliance = {
      description = "RTO/RPO compliance metrics for DR"
      filter = <<-EOT
        resource.labels.region="${local.region}" AND
        jsonPayload.metric_type=~".*rto.*|.*rpo.*"
      EOT
      metric_descriptor = {
        metric_kind = "GAUGE"
        value_type  = "DOUBLE"
        display_name = "RTO/RPO Compliance"
      }
      label_extractors = {
        metric_type = "EXTRACT(jsonPayload.metric_type)"
        service = "EXTRACT(jsonPayload.service)"
      }
      value_extractor = "EXTRACT(jsonPayload.compliance_percentage)"
    }
  }

  # Log Buckets for DR region with appropriate retention
  log_buckets = {
    # Default bucket for DR region
    _Default = {
      retention_days = local.monitoring_config.log_buckets._Default
      locked = false
    }

    # DR events bucket with extended retention
    dr_events = {
      retention_days = local.monitoring_config.log_buckets.dr_events
      locked = true
      description = "DR events and failover logs with extended retention"
    }

    # Infrastructure logs bucket
    dr_infrastructure = {
      retention_days = 180
      locked = false
      description = "DR infrastructure logs for operational analysis"
    }

    # Application logs bucket
    dr_application = {
      retention_days = 90
      locked = false
      description = "DR application logs for debugging and analysis"
    }

    # Security logs bucket
    dr_security = {
      retention_days = 2555  # 7 years for compliance
      locked = true
      description = "DR security and audit logs with extended retention"
    }

    # Cross-region logs bucket
    cross_region = {
      retention_days = 365
      locked = false
      description = "Cross-region replication and connectivity logs"
    }
  }

  # Log Views for access control in DR region
  log_views = {
    # DR operations team view
    dr_operations_view = {
      bucket = "dr_events"
      description = "DR operations team access to failover and DR event logs"
      filter = <<-EOT
        resource.labels.region="${local.region}" AND
        (jsonPayload.event_type="failover" OR
         jsonPayload.event_type="failback" OR
         jsonPayload.event_type="dr_test")
      EOT
    }

    # Cross-region monitoring view
    cross_region_view = {
      bucket = "cross_region"
      description = "Cross-region monitoring and replication logs"
      filter = <<-EOT
        (jsonPayload.transfer_type="cross_region" OR
         jsonPayload.operation_type="replication" OR
         resource.type="vpn_tunnel")
      EOT
    }

    # DR security view
    dr_security_view = {
      bucket = "dr_security"
      description = "DR security team access to security and audit logs"
      filter = <<-EOT
        resource.labels.region="${local.region}" AND
        (protoPayload.serviceName=("iam.googleapis.com" OR "cloudresourcemanager.googleapis.com") OR
         severity >= "WARNING")
      EOT
    }

    # Infrastructure monitoring view
    dr_infrastructure_view = {
      bucket = "dr_infrastructure"
      description = "DR infrastructure monitoring and operations logs"
      filter = <<-EOT
        resource.labels.region="${local.region}" AND
        resource.type=("gce_instance" OR "k8s_cluster" OR "k8s_node")
      EOT
    }
  }

  # Exclusion Filters for DR region to optimize costs
  exclusion_filters = {
    # Exclude routine health checks in DR region
    dr_health_check_exclusions = {
      description = "Exclude routine health check logs in DR region"
      filter = <<-EOT
        resource.labels.region="${local.region}" AND
        resource.type="http_load_balancer" AND
        httpRequest.requestUrl=~"/health" AND
        httpRequest.status = 200
      EOT
      disabled = false
    }

    # Exclude verbose kube-system logs in DR
    dr_kube_system_exclusions = {
      description = "Exclude verbose kube-system namespace logs in DR region"
      filter = <<-EOT
        resource.labels.region="${local.region}" AND
        resource.type="k8s_container" AND
        resource.labels.namespace_name="kube-system" AND
        severity < "WARNING"
      EOT
      disabled = false
    }

    # Exclude routine cross-region sync logs
    routine_sync_exclusions = {
      description = "Exclude routine cross-region sync logs"
      filter = <<-EOT
        resource.labels.region="${local.region}" AND
        jsonPayload.operation_type="sync" AND
        severity="INFO" AND
        jsonPayload.status="success"
      EOT
      disabled = false
    }
  }

  # BigQuery Datasets for DR log analysis
  bigquery_datasets = {
    dr_infrastructure_logs = {
      description = "DR infrastructure logs dataset"
      location = "US"
      default_table_expiration_ms = 7776000000  # 90 days
      labels = {
        environment = "production"
        region = local.region_short
        purpose = "dr-infrastructure"
        log_type = "infrastructure"
      }
      access = [
        {
          role = "OWNER"
          user_by_email = "dr-operations@your-company.com"
        },
        {
          role = "READER"
          group_by_email = "infrastructure-team@your-company.com"
        }
      ]
    }

    dr_application_logs = {
      description = "DR application logs dataset"
      location = "US"
      default_table_expiration_ms = 2592000000  # 30 days
      labels = {
        environment = "production"
        region = local.region_short
        purpose = "dr-application"
        log_type = "application"
      }
      access = [
        {
          role = "OWNER"
          user_by_email = "development-team@your-company.com"
        }
      ]
    }

    cross_region_replication_logs = {
      description = "Cross-region replication logs dataset"
      location = "US"
      default_table_expiration_ms = 5184000000  # 60 days
      labels = {
        environment = "production"
        purpose = "cross-region-replication"
        log_type = "replication"
      }
      access = [
        {
          role = "OWNER"
          user_by_email = "dr-operations@your-company.com"
        }
      ]
    }

    cross_region_network_logs = {
      description = "Cross-region network logs dataset"
      location = "US"
      default_table_expiration_ms = 7776000000  # 90 days
      labels = {
        environment = "production"
        purpose = "cross-region-network"
        log_type = "network"
      }
      access = [
        {
          role = "OWNER"
          user_by_email = "network-team@your-company.com"
        }
      ]
    }
  }

  # Pub/Sub Topics for real-time DR log processing
  pubsub_topics = {
    dr_failover_logs = {
      description = "Topic for DR failover and testing logs"
      message_retention_duration = "1209600s"  # 14 days
      labels = {
        environment = "production"
        region = local.region_short
        purpose = "dr-failover"
      }
    }

    cross_region_alerts = {
      description = "Topic for cross-region connectivity and replication alerts"
      message_retention_duration = "604800s"  # 7 days
      labels = {
        environment = "production"
        purpose = "cross-region-alerts"
      }
    }

    dr_compliance_events = {
      description = "Topic for DR compliance and audit events"
      message_retention_duration = "2592000s"  # 30 days
      labels = {
        environment = "production"
        purpose = "dr-compliance"
      }
    }
  }

  # Pub/Sub Subscriptions for DR log processing
  pubsub_subscriptions = {
    dr_failover_processor = {
      topic = "dr_failover_logs"
      push_config = {
        push_endpoint = "https://dr-failover-processor.run.app/process-events"
        attributes = {
          x-goog-version = "v1"
          region = local.region
        }
      }
      ack_deadline_seconds = 120
      retry_policy = {
        minimum_backoff = "30s"
        maximum_backoff = "1800s"
      }
    }

    cross_region_alert_processor = {
      topic = "cross_region_alerts"
      push_config = {
        push_endpoint = "https://cross-region-processor.run.app/process-alerts"
        attributes = {
          x-goog-version = "v1"
          region = local.region
        }
      }
      ack_deadline_seconds = 60
      retry_policy = {
        minimum_backoff = "10s"
        maximum_backoff = "600s"
      }
    }

    dr_compliance_archiver = {
      topic = "dr_compliance_events"
      push_config = {
        push_endpoint = "https://compliance-archiver.run.app/archive-dr-events"
        attributes = {
          x-goog-version = "v1"
          region = local.region
        }
      }
      ack_deadline_seconds = 300
      retry_policy = {
        minimum_backoff = "30s"
        maximum_backoff = "1800s"
      }
    }
  }

  # Cloud Storage Buckets for DR log archival
  storage_buckets = {
    dr_security_logs_archive = {
      name = "your-prod-project-id-dr-security-logs"
      location = local.region
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
        retention_period = 220752000  # 7 years
        is_locked = true
      }

      labels = {
        environment = "production"
        region = local.region_short
        purpose = "dr-security-logs"
        compliance = "required"
      }
    }

    backup_logs_archive = {
      name = "your-prod-project-id-backup-logs"
      location = local.region
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
            age = 365
          }
        }
      ]

      labels = {
        environment = "production"
        region = local.region_short
        purpose = "backup-logs"
      }
    }
  }

  # Log Analytics Saved Queries for DR
  saved_queries = {
    # DR failover analysis
    dr_failover_analysis = {
      description = "Analyze DR failover events and patterns"
      query = <<-EOT
        SELECT
          jsonPayload.failover_type,
          jsonPayload.trigger_reason,
          COUNT(*) as failover_count,
          AVG(CAST(jsonPayload.failover_duration_seconds AS FLOAT64)) as avg_duration,
          MIN(timestamp) as first_failover,
          MAX(timestamp) as last_failover
        FROM `your-prod-project-id.dr_infrastructure_logs.cloudaudit_googleapis_com_*`
        WHERE
          _PARTITIONTIME >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
          AND jsonPayload.event_type = "failover"
          AND resource.labels.region = "${local.region}"
        GROUP BY 1, 2
        ORDER BY failover_count DESC
      EOT
    }

    # Cross-region replication health
    cross_region_replication_health = {
      description = "Analyze cross-region replication health and performance"
      query = <<-EOT
        SELECT
          resource.labels.database_id,
          AVG(CAST(jsonPayload.replication_lag_seconds AS FLOAT64)) as avg_lag,
          MAX(CAST(jsonPayload.replication_lag_seconds AS FLOAT64)) as max_lag,
          COUNT(CASE WHEN CAST(jsonPayload.replication_lag_seconds AS FLOAT64) > 300 THEN 1 END) as high_lag_events
        FROM `your-prod-project-id.cross_region_replication_logs.cloudsql_googleapis_com_*`
        WHERE
          _PARTITIONTIME >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
          AND resource.labels.region = "${local.region}"
        GROUP BY 1
        ORDER BY avg_lag DESC
      EOT
    }

    # DR test success analysis
    dr_test_success_analysis = {
      description = "Analyze DR test success rates and patterns"
      query = <<-EOT
        SELECT
          jsonPayload.test_type,
          jsonPayload.test_scenario,
          COUNT(*) as total_tests,
          COUNT(CASE WHEN jsonPayload.test_result = "success" THEN 1 END) as successful_tests,
          SAFE_DIVIDE(
            COUNT(CASE WHEN jsonPayload.test_result = "success" THEN 1 END),
            COUNT(*)
          ) * 100 as success_rate_percent
        FROM `your-prod-project-id.dr_infrastructure_logs.cloudaudit_googleapis_com_*`
        WHERE
          _PARTITIONTIME >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
          AND jsonPayload.event_type = "dr_test"
          AND resource.labels.region = "${local.region}"
        GROUP BY 1, 2
        ORDER BY success_rate_percent ASC
      EOT
    }

    # Network partition impact analysis
    network_partition_impact = {
      description = "Analyze network partition events and their impact"
      query = <<-EOT
        SELECT
          resource.labels.tunnel_name,
          jsonPayload.peer_region,
          COUNT(*) as partition_events,
          AVG(CAST(jsonPayload.duration_seconds AS FLOAT64)) as avg_duration,
          SUM(CAST(jsonPayload.affected_services AS INT64)) as total_affected_services
        FROM `your-prod-project-id.cross_region_network_logs.compute_googleapis_com_*`
        WHERE
          _PARTITIONTIME >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
          AND severity = "ERROR"
          AND jsonPayload.event_type = "connectivity_lost"
        GROUP BY 1, 2
        ORDER BY partition_events DESC
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
    Region = local.region
    RegionShort = local.region_short
    RegionType = "disaster-recovery"
    Team = "platform"
    Component = "logging"
    CostCenter = "engineering"
    Compliance = "required"
    DataClassification = "internal"
    BackupRequired = "true"
    MonitoringRequired = "true"
    DRRole = "secondary"
    DRPriority = "1"
    LogRetentionEnabled = "true"
    CrossRegionLogging = "enabled"
    ComplianceLogging = "enabled"
  }
}