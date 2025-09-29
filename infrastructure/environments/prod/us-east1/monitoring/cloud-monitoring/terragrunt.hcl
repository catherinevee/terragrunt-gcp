# Production Cloud Monitoring Configuration - US East 1 (Disaster Recovery)
# This configuration provides comprehensive monitoring for the disaster recovery region

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
  source = "../../../../../../modules/monitoring/cloud-monitoring"
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

inputs = {
  project_id = "your-prod-project-id"
  region     = local.region

  # Notification Channels for DR monitoring
  notification_channels = {
    # Critical alerts for DR operations
    email_critical_dr = {
      type         = "email"
      display_name = "Critical DR Alerts - Email"
      description  = "Email notifications for critical disaster recovery alerts"
      labels = {
        email_address = "dr-critical@your-company.com"
      }
      enabled = true
    }

    # PagerDuty for immediate response
    pagerduty_critical_dr = {
      type         = "pagerduty"
      display_name = "Critical DR Alerts - PagerDuty"
      description  = "PagerDuty notifications for critical DR situations"
      labels = {
        service_key = "your-pagerduty-service-key-dr"
      }
      enabled = true
    }

    # Slack for team coordination
    slack_dr_team = {
      type         = "slack"
      display_name = "DR Team Slack Channel"
      description  = "Slack notifications for DR team coordination"
      labels = {
        channel_name = "#disaster-recovery"
        url = "https://hooks.slack.com/services/your-webhook-url"
      }
      enabled = true
    }

    # Operations team email
    email_ops_dr = {
      type         = "email"
      display_name = "Operations Team - DR Alerts"
      description  = "Email notifications for operations team"
      labels = {
        email_address = "ops-dr@your-company.com"
      }
      enabled = true
    }

    # SMS for critical situations
    sms_critical_dr = {
      type         = "sms"
      display_name = "Critical DR Alerts - SMS"
      description  = "SMS notifications for critical DR alerts"
      labels = {
        number = "+1-555-0123"
      }
      enabled = true
    }
  }

  # DR-specific Alert Policies
  alert_policies = {
    # DR Region Health Monitoring
    dr_region_availability = {
      display_name = "DR Region - Overall Availability"
      description  = "Monitor overall availability of disaster recovery region"
      combiner     = "OR"
      enabled      = true

      conditions = [
        {
          display_name = "DR region services down"
          condition_threshold = {
            filter          = "resource.type=\"gce_instance\" AND resource.labels.region=\"${local.region}\""
            comparison      = "COMPARISON_LT"
            threshold_value = 0.95
            duration        = "300s"
            aggregations = [
              {
                alignment_period   = "60s"
                per_series_aligner = "ALIGN_MEAN"
              }
            ]
          }
        }
      ]

      notification_channels = [
        "projects/your-prod-project-id/notificationChannels/pagerduty-critical-dr",
        "projects/your-prod-project-id/notificationChannels/email-critical-dr",
        "projects/your-prod-project-id/notificationChannels/sms-critical-dr"
      ]

      alert_strategy = {
        auto_close = "1800s"
        notification_rate_limit = {
          period = "300s"
        }
      }
    }

    # Cross-region replication lag
    cross_region_replication_lag = {
      display_name = "Cross-Region Replication Lag"
      description  = "Monitor replication lag between primary and DR regions"
      combiner     = "OR"
      enabled      = true

      conditions = [
        {
          display_name = "Database replication lag > 5 minutes"
          condition_threshold = {
            filter          = "resource.type=\"cloudsql_database\" AND resource.labels.region=\"${local.region}\""
            comparison      = "COMPARISON_GT"
            threshold_value = 300  # 5 minutes
            duration        = "180s"
            aggregations = [
              {
                alignment_period   = "60s"
                per_series_aligner = "ALIGN_MEAN"
              }
            ]
          }
        }
      ]

      notification_channels = [
        "projects/your-prod-project-id/notificationChannels/pagerduty-critical-dr",
        "projects/your-prod-project-id/notificationChannels/slack-dr-team"
      ]
    }

    # Storage replication monitoring
    storage_replication_failure = {
      display_name = "Storage Replication Failure"
      description  = "Monitor storage replication failures to DR region"
      combiner     = "OR"
      enabled      = true

      conditions = [
        {
          display_name = "Storage transfer job failures"
          condition_threshold = {
            filter          = "resource.type=\"storage_transfer_job\""
            comparison      = "COMPARISON_GT"
            threshold_value = 0
            duration        = "60s"
            aggregations = [
              {
                alignment_period   = "60s"
                per_series_aligner = "ALIGN_RATE"
              }
            ]
          }
        }
      ]

      notification_channels = [
        "projects/your-prod-project-id/notificationChannels/email-ops-dr",
        "projects/your-prod-project-id/notificationChannels/slack-dr-team"
      ]
    }

    # GKE cluster health in DR region
    gke_cluster_health_dr = {
      display_name = "GKE Cluster Health - DR Region"
      description  = "Monitor GKE cluster health in disaster recovery region"
      combiner     = "OR"
      enabled      = true

      conditions = [
        {
          display_name = "GKE cluster nodes not ready"
          condition_threshold = {
            filter          = "resource.type=\"k8s_cluster\" AND resource.labels.cluster_name=\"${dependency.gke.outputs.cluster_name}\""
            comparison      = "COMPARISON_LT"
            threshold_value = 0.8  # 80% of nodes ready
            duration        = "300s"
            aggregations = [
              {
                alignment_period   = "60s"
                per_series_aligner = "ALIGN_MEAN"
              }
            ]
          }
        }
      ]

      notification_channels = [
        "projects/your-prod-project-id/notificationChannels/pagerduty-critical-dr",
        "projects/your-prod-project-id/notificationChannels/email-ops-dr"
      ]
    }

    # Network connectivity between regions
    cross_region_connectivity = {
      display_name = "Cross-Region Network Connectivity"
      description  = "Monitor network connectivity between primary and DR regions"
      combiner     = "OR"
      enabled      = true

      conditions = [
        {
          display_name = "VPN tunnel down"
          condition_threshold = {
            filter          = "resource.type=\"vpn_tunnel\" AND resource.labels.tunnel_name=~\".*dr.*\""
            comparison      = "COMPARISON_LT"
            threshold_value = 1
            duration        = "180s"
            aggregations = [
              {
                alignment_period   = "60s"
                per_series_aligner = "ALIGN_MEAN"
              }
            ]
          }
        }
      ]

      notification_channels = [
        "projects/your-prod-project-id/notificationChannels/pagerduty-critical-dr",
        "projects/your-prod-project-id/notificationChannels/email-critical-dr"
      ]
    }

    # DR failover readiness
    dr_failover_readiness = {
      display_name = "DR Failover Readiness"
      description  = "Monitor disaster recovery failover readiness status"
      combiner     = "AND"
      enabled      = true

      conditions = [
        {
          display_name = "DR environment not ready for failover"
          condition_threshold = {
            filter          = "metric.type=\"custom.googleapis.com/dr/failover_readiness\" AND resource.labels.region=\"${local.region}\""
            comparison      = "COMPARISON_LT"
            threshold_value = 1
            duration        = "600s"
            aggregations = [
              {
                alignment_period   = "300s"
                per_series_aligner = "ALIGN_MEAN"
              }
            ]
          }
        }
      ]

      notification_channels = [
        "projects/your-prod-project-id/notificationChannels/email-critical-dr",
        "projects/your-prod-project-id/notificationChannels/slack-dr-team"
      ]
    }

    # Backup validation failures
    backup_validation_failure = {
      display_name = "Backup Validation Failure"
      description  = "Monitor backup validation failures in DR region"
      combiner     = "OR"
      enabled      = true

      conditions = [
        {
          display_name = "Backup validation failed"
          condition_threshold = {
            filter          = "metric.type=\"custom.googleapis.com/backup/validation_status\" AND resource.labels.region=\"${local.region}\""
            comparison      = "COMPARISON_LT"
            threshold_value = 1
            duration        = "300s"
            aggregations = [
              {
                alignment_period   = "60s"
                per_series_aligner = "ALIGN_MEAN"
              }
            ]
          }
        }
      ]

      notification_channels = [
        "projects/your-prod-project-id/notificationChannels/email-ops-dr",
        "projects/your-prod-project-id/notificationChannels/slack-dr-team"
      ]
    }

    # Resource utilization in DR region
    dr_resource_utilization = {
      display_name = "DR Region - High Resource Utilization"
      description  = "Monitor high resource utilization in disaster recovery region"
      combiner     = "OR"
      enabled      = true

      conditions = [
        {
          display_name = "High CPU utilization in DR region"
          condition_threshold = {
            filter          = "resource.type=\"gce_instance\" AND resource.labels.region=\"${local.region}\""
            comparison      = "COMPARISON_GT"
            threshold_value = 0.85
            duration        = "300s"
            aggregations = [
              {
                alignment_period   = "60s"
                per_series_aligner = "ALIGN_MEAN"
              }
            ]
          }
        }
      ]

      notification_channels = [
        "projects/your-prod-project-id/notificationChannels/email-ops-dr"
      ]
    }

    # Security events in DR region
    dr_security_events = {
      display_name = "DR Region - Security Events"
      description  = "Monitor security events and anomalies in disaster recovery region"
      combiner     = "OR"
      enabled      = true

      conditions = [
        {
          display_name = "Unusual authentication patterns"
          condition_threshold = {
            filter          = "resource.labels.region=\"${local.region}\" AND protoPayload.serviceName=\"iam.googleapis.com\""
            comparison      = "COMPARISON_GT"
            threshold_value = 10
            duration        = "300s"
            aggregations = [
              {
                alignment_period   = "60s"
                per_series_aligner = "ALIGN_RATE"
              }
            ]
          }
        }
      ]

      notification_channels = [
        "projects/your-prod-project-id/notificationChannels/pagerduty-critical-dr",
        "projects/your-prod-project-id/notificationChannels/email-critical-dr"
      ]
    }

    # Cost anomalies in DR region
    dr_cost_anomaly = {
      display_name = "DR Region - Cost Anomaly"
      description  = "Monitor unexpected cost increases in disaster recovery region"
      combiner     = "OR"
      enabled      = true

      conditions = [
        {
          display_name = "Cost increase > 50% in DR region"
          condition_threshold = {
            filter          = "metric.type=\"billing.googleapis.com/billing/total_cost\" AND resource.labels.location=\"${local.region}\""
            comparison      = "COMPARISON_GT"
            threshold_value = 1.5  # 50% increase
            duration        = "3600s"  # 1 hour
            aggregations = [
              {
                alignment_period   = "3600s"
                per_series_aligner = "ALIGN_DELTA"
              }
            ]
          }
        }
      ]

      notification_channels = [
        "projects/your-prod-project-id/notificationChannels/email-ops-dr"
      ]
    }
  }

  # DR-specific Dashboards
  dashboards = {
    # Disaster Recovery Overview Dashboard
    dr_overview = {
      display_name = "Disaster Recovery - Overview Dashboard"

      grid_layout = {
        widgets = [
          # DR Region Health Status
          {
            title = "DR Region Health Status"
            xy_chart = {
              data_sets = [
                {
                  time_series_query = {
                    time_series_filter = {
                      filter = "resource.type=\"gce_instance\" AND resource.labels.region=\"${local.region}\""
                      aggregation = {
                        alignment_period   = "60s"
                        per_series_aligner = "ALIGN_MEAN"
                      }
                    }
                  }
                }
              ]
              y_axis = {
                label = "Health Score"
                scale = "LINEAR"
              }
            }
          },

          # Cross-Region Replication Lag
          {
            title = "Cross-Region Replication Lag"
            xy_chart = {
              data_sets = [
                {
                  time_series_query = {
                    time_series_filter = {
                      filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/replica_lag\""
                      aggregation = {
                        alignment_period   = "60s"
                        per_series_aligner = "ALIGN_MEAN"
                      }
                    }
                  }
                }
              ]
              y_axis = {
                label = "Lag (seconds)"
                scale = "LINEAR"
              }
            }
          },

          # Storage Replication Status
          {
            title = "Storage Replication Status"
            scorecard = {
              time_series_query = {
                time_series_filter = {
                  filter = "resource.type=\"storage_transfer_job\""
                  aggregation = {
                    alignment_period   = "300s"
                    per_series_aligner = "ALIGN_MEAN"
                  }
                }
              }
              gauge_view = {
                lower_bound = 0
                upper_bound = 100
              }
            }
          },

          # Network Connectivity Status
          {
            title = "Cross-Region Network Connectivity"
            xy_chart = {
              data_sets = [
                {
                  time_series_query = {
                    time_series_filter = {
                      filter = "resource.type=\"vpn_tunnel\""
                      aggregation = {
                        alignment_period   = "60s"
                        per_series_aligner = "ALIGN_MEAN"
                      }
                    }
                  }
                }
              ]
              y_axis = {
                label = "Tunnel Status"
                scale = "LINEAR"
              }
            }
          },

          # Resource Utilization
          {
            title = "DR Region Resource Utilization"
            xy_chart = {
              data_sets = [
                {
                  time_series_query = {
                    time_series_filter = {
                      filter = "resource.type=\"gce_instance\" AND resource.labels.region=\"${local.region}\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
                      aggregation = {
                        alignment_period   = "60s"
                        per_series_aligner = "ALIGN_MEAN"
                      }
                    }
                  }
                }
              ]
              y_axis = {
                label = "CPU Utilization (%)"
                scale = "LINEAR"
              }
            }
          },

          # Backup Status
          {
            title = "Backup Status"
            scorecard = {
              time_series_query = {
                time_series_filter = {
                  filter = "metric.type=\"custom.googleapis.com/backup/status\" AND resource.labels.region=\"${local.region}\""
                  aggregation = {
                    alignment_period   = "300s"
                    per_series_aligner = "ALIGN_MEAN"
                  }
                }
              }
              gauge_view = {
                lower_bound = 0
                upper_bound = 1
              }
            }
          }
        ]
      }
    }

    # DR Failover Readiness Dashboard
    dr_failover_readiness = {
      display_name = "DR Failover Readiness Dashboard"

      grid_layout = {
        widgets = [
          # Failover Readiness Score
          {
            title = "Overall Failover Readiness"
            scorecard = {
              time_series_query = {
                time_series_filter = {
                  filter = "metric.type=\"custom.googleapis.com/dr/failover_readiness\""
                  aggregation = {
                    alignment_period   = "300s"
                    per_series_aligner = "ALIGN_MEAN"
                  }
                }
              }
              gauge_view = {
                lower_bound = 0
                upper_bound = 1
              }
            }
          },

          # RTO/RPO Tracking
          {
            title = "RTO/RPO Compliance"
            xy_chart = {
              data_sets = [
                {
                  time_series_query = {
                    time_series_filter = {
                      filter = "metric.type=\"custom.googleapis.com/dr/rto_compliance\""
                      aggregation = {
                        alignment_period   = "300s"
                        per_series_aligner = "ALIGN_MEAN"
                      }
                    }
                  }
                },
                {
                  time_series_query = {
                    time_series_filter = {
                      filter = "metric.type=\"custom.googleapis.com/dr/rpo_compliance\""
                      aggregation = {
                        alignment_period   = "300s"
                        per_series_aligner = "ALIGN_MEAN"
                      }
                    }
                  }
                }
              ]
              y_axis = {
                label = "Compliance %"
                scale = "LINEAR"
              }
            }
          },

          # DR Test Results
          {
            title = "DR Test Success Rate"
            xy_chart = {
              data_sets = [
                {
                  time_series_query = {
                    time_series_filter = {
                      filter = "metric.type=\"custom.googleapis.com/dr/test_success_rate\""
                      aggregation = {
                        alignment_period   = "86400s"  # Daily
                        per_series_aligner = "ALIGN_MEAN"
                      }
                    }
                  }
                }
              ]
              y_axis = {
                label = "Success Rate %"
                scale = "LINEAR"
              }
            }
          }
        ]
      }
    }

    # Cross-Region Latency Dashboard
    cross_region_latency = {
      display_name = "Cross-Region Latency Dashboard"

      grid_layout = {
        widgets = [
          # Network Latency
          {
            title = "Network Latency Between Regions"
            xy_chart = {
              data_sets = [
                {
                  time_series_query = {
                    time_series_filter = {
                      filter = "metric.type=\"compute.googleapis.com/instance/network/received_bytes_count\""
                      aggregation = {
                        alignment_period   = "60s"
                        per_series_aligner = "ALIGN_RATE"
                      }
                    }
                  }
                }
              ]
              y_axis = {
                label = "Latency (ms)"
                scale = "LINEAR"
              }
            }
          },

          # Database Replication Latency
          {
            title = "Database Replication Latency"
            xy_chart = {
              data_sets = [
                {
                  time_series_query = {
                    time_series_filter = {
                      filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/replica_lag\""
                      aggregation = {
                        alignment_period   = "60s"
                        per_series_aligner = "ALIGN_MEAN"
                      }
                    }
                  }
                }
              ]
              y_axis = {
                label = "Replication Lag (seconds)"
                scale = "LINEAR"
              }
            }
          }
        ]
      }
    }
  }

  # DR-specific Uptime Checks
  uptime_checks = {
    # DR region health endpoint
    dr_health_check = {
      display_name = "DR Region Health Check"
      timeout      = "10s"
      period       = "60s"

      http_check = {
        path         = "/health"
        port         = 443
        use_ssl      = true
        validate_ssl = true
      }

      monitored_resource = {
        type = "uptime_url"
        labels = {
          project_id = "your-prod-project-id"
          host       = "dr.your-domain.com"
        }
      }

      checker_type = "STATIC_IP_CHECKERS"
    }

    # Cross-region connectivity check
    cross_region_connectivity_check = {
      display_name = "Cross-Region Connectivity Check"
      timeout      = "30s"
      period       = "300s"

      tcp_check = {
        port = 443
      }

      monitored_resource = {
        type = "uptime_url"
        labels = {
          project_id = "your-prod-project-id"
          host       = "api.your-domain.com"
        }
      }

      checker_type = "STATIC_IP_CHECKERS"
    }
  }

  # SLOs for DR region
  slos = local.monitoring_config.slo_configs

  # Integration with existing resources
  network_self_link = dependency.vpc.outputs.network_self_link
  cluster_name = dependency.gke.outputs.cluster_name
  database_instance_name = dependency.cloud_sql.outputs.instance_name
  storage_bucket_names = dependency.gcs.outputs.bucket_names

  # Tags for resource organization
  tags = {
    Environment = "production"
    Region = local.region
    RegionShort = local.region_short
    RegionType = "disaster-recovery"
    Team = "platform"
    Component = "monitoring"
    CostCenter = "engineering"
    Compliance = "required"
    DataClassification = "internal"
    BackupRequired = "true"
    MonitoringRequired = "true"
    DRRole = "secondary"
    DRPriority = "1"
    AlertingEnabled = "true"
    DashboardsEnabled = "true"
    UptimeChecksEnabled = "true"
    SLOsEnabled = "true"
  }
}