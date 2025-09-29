# Monitoring configuration for staging us-central1 region
# Manages monitoring, logging, alerting, and observability infrastructure

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("env.hcl")
}

terraform {
  source = "../../../../../modules/monitoring/cloud-monitoring"
}

dependency "compute" {
  config_path = "../compute"

  mock_outputs = {
    instance_group_id = "mock-ig-id"
    instance_group_name = "staging-ig"
  }
}

dependency "network" {
  config_path = "../networking"

  mock_outputs = {
    vpc_id = "mock-vpc-id"
    vpc_name = "staging-vpc"
  }
}

locals {
  environment = "staging"
  region      = "us-central1"

  # Staging monitoring configuration - balanced for cost and visibility
  monitoring_config = {
    # Reduced retention for staging
    log_retention_days = 30
    metric_retention_days = 30
    trace_sampling_ratio = 0.1  # Sample 10% of traces

    # Alert thresholds - less sensitive than production
    alert_thresholds = {
      cpu_utilization = 85
      memory_utilization = 85
      disk_utilization = 90
      error_rate = 5
      latency_p95 = 2000  # 2 seconds
      availability = 95   # 95% uptime for staging
    }

    # Notification settings
    notification_rate_limit = "300s"  # Limit notifications to every 5 minutes
    auto_close_duration = "1800s"     # Auto-close after 30 minutes
  }
}

inputs = {
  project_id  = "acme-staging-platform"
  region      = local.region
  environment = local.environment

  # Uptime checks configuration
  uptime_checks = [
    {
      display_name = "${local.environment}-web-health"

      monitored_resource = {
        type = "uptime_url"
        labels = {
          project_id = "acme-staging-platform"
          host       = "staging.acme-corp.com"
        }
      }

      http_check = {
        path         = "/health"
        port         = "443"
        use_ssl      = true
        validate_ssl = true

        accepted_response_status_codes = [
          {
            status_class = "STATUS_CLASS_2XX"
          }
        ]
      }

      timeout = "10s"
      period  = "300s"  # Check every 5 minutes in staging

      selected_regions = ["USA"]

      content_matchers = [
        {
          content = "healthy"
          matcher = "CONTAINS_STRING"
        }
      ]
    },
    {
      display_name = "${local.environment}-api-health"

      monitored_resource = {
        type = "uptime_url"
        labels = {
          project_id = "acme-staging-platform"
          host       = "api-staging.acme-corp.com"
        }
      }

      http_check = {
        path    = "/api/health"
        port    = "443"
        use_ssl = true

        headers = {
          "User-Agent" = "GoogleStackdriver-UptimeCheck"
        }
      }

      timeout = "5s"
      period  = "300s"

      selected_regions = ["USA", "EUROPE"]
    }
  ]

  # Alert policies
  alert_policies = [
    # High CPU utilization
    {
      display_name = "${local.environment} High CPU Usage"
      enabled      = true
      combiner     = "OR"

      conditions = [
        {
          display_name = "CPU usage above ${local.monitoring_config.alert_thresholds.cpu_utilization}%"

          condition_threshold = {
            filter = <<-EOT
              metric.type="compute.googleapis.com/instance/cpu/utilization"
              resource.type="gce_instance"
              metadata.user_labels."environment"="${local.environment}"
            EOT

            comparison      = "COMPARISON_GT"
            threshold_value = local.monitoring_config.alert_thresholds.cpu_utilization / 100
            duration        = "300s"

            aggregations = [
              {
                alignment_period     = "60s"
                per_series_aligner   = "ALIGN_MEAN"
                cross_series_reducer = "REDUCE_MEAN"
                group_by_fields      = ["resource.instance_id"]
              }
            ]
          }
        }
      ]

      notification_channels = ["staging-email", "staging-slack"]

      alert_strategy = {
        auto_close = local.monitoring_config.auto_close_duration

        notification_rate_limit = {
          period = local.monitoring_config.notification_rate_limit
        }
      }

      documentation = {
        content = "CPU usage is above ${local.monitoring_config.alert_thresholds.cpu_utilization}% on staging instances. Check for runaway processes or consider scaling."
        mime_type = "text/markdown"
      }
    },

    # High memory usage
    {
      display_name = "${local.environment} High Memory Usage"
      enabled      = true

      conditions = [
        {
          display_name = "Memory usage above ${local.monitoring_config.alert_thresholds.memory_utilization}%"

          condition_threshold = {
            filter = <<-EOT
              metric.type="agent.googleapis.com/memory/percent_used"
              resource.type="gce_instance"
              metadata.user_labels."environment"="${local.environment}"
            EOT

            comparison      = "COMPARISON_GT"
            threshold_value = local.monitoring_config.alert_thresholds.memory_utilization
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

      notification_channels = ["staging-email"]
    },

    # High error rate
    {
      display_name = "${local.environment} High Error Rate"
      enabled      = true

      conditions = [
        {
          display_name = "Error rate above ${local.monitoring_config.alert_thresholds.error_rate}%"

          condition_threshold = {
            filter = <<-EOT
              metric.type="loadbalancing.googleapis.com/https/request_count"
              resource.type="https_lb_rule"
              metric.label."response_code_class"="5xx"
            EOT

            comparison      = "COMPARISON_GT"
            threshold_value = local.monitoring_config.alert_thresholds.error_rate
            duration        = "60s"

            aggregations = [
              {
                alignment_period     = "60s"
                per_series_aligner   = "ALIGN_RATE"
                cross_series_reducer = "REDUCE_SUM"
              }
            ]
          }
        }
      ]

      notification_channels = ["staging-email", "staging-pagerduty"]
    },

    # Uptime check failures
    {
      display_name = "${local.environment} Uptime Check Failed"
      enabled      = true

      conditions = [
        {
          display_name = "Uptime check failure"

          condition_threshold = {
            filter = <<-EOT
              metric.type="monitoring.googleapis.com/uptime_check/check_passed"
              resource.type="uptime_url"
            EOT

            comparison      = "COMPARISON_LT"
            threshold_value = 1
            duration        = "60s"

            aggregations = [
              {
                alignment_period     = "60s"
                per_series_aligner   = "ALIGN_FRACTION_TRUE"
                cross_series_reducer = "REDUCE_MEAN"
                group_by_fields      = ["resource.host"]
              }
            ]
          }
        }
      ]

      notification_channels = ["staging-slack"]
    },

    # Disk space warning
    {
      display_name = "${local.environment} Low Disk Space"
      enabled      = true

      conditions = [
        {
          display_name = "Disk usage above ${local.monitoring_config.alert_thresholds.disk_utilization}%"

          condition_threshold = {
            filter = <<-EOT
              metric.type="agent.googleapis.com/disk/percent_used"
              resource.type="gce_instance"
              metadata.user_labels."environment"="${local.environment}"
              metric.label."state"="used"
            EOT

            comparison      = "COMPARISON_GT"
            threshold_value = local.monitoring_config.alert_thresholds.disk_utilization
            duration        = "300s"

            aggregations = [
              {
                alignment_period   = "60s"
                per_series_aligner = "ALIGN_MAX"
              }
            ]
          }
        }
      ]

      notification_channels = ["staging-email"]
    }
  ]

  # Notification channels
  notification_channels = [
    {
      type         = "email"
      display_name = "staging-email"

      labels = {
        email_address = "staging-alerts@acme-corp.com"
      }
    },
    {
      type         = "slack"
      display_name = "staging-slack"

      labels = {
        channel_name = "#staging-alerts"
        url          = "https://hooks.slack.com/services/STAGING/WEBHOOK/URL"
      }

      sensitive_labels = {
        auth_token = "xoxb-staging-slack-token"
      }
    },
    {
      type         = "pagerduty"
      display_name = "staging-pagerduty"
      enabled      = false  # Disabled for staging

      labels = {
        service_key = "staging-pagerduty-service-key"
      }
    }
  ]

  # Custom dashboards
  dashboards = [
    {
      display_name = "${local.environment} Overview Dashboard"

      dashboard_json = jsonencode({
        displayName = "${local.environment} Environment Overview"

        mosaicLayout = {
          columns = 12
          tiles = [
            # Request rate
            {
              width  = 6
              height = 4
              widget = {
                title = "Request Rate"
                xyChart = {
                  dataSets = [
                    {
                      timeSeriesQuery = {
                        timeSeriesFilter = {
                          filter = "metric.type=\"loadbalancing.googleapis.com/https/request_count\" resource.type=\"https_lb_rule\""
                        }
                      }
                      plotType = "LINE"
                    }
                  ]
                }
              }
            },
            # Error rate
            {
              width  = 6
              height = 4
              xPos   = 6
              widget = {
                title = "Error Rate"
                xyChart = {
                  dataSets = [
                    {
                      timeSeriesQuery = {
                        timeSeriesFilter = {
                          filter = "metric.type=\"loadbalancing.googleapis.com/https/request_count\" resource.type=\"https_lb_rule\" metric.label.\"response_code_class\"=\"5xx\""
                        }
                      }
                      plotType = "LINE"
                    }
                  ]
                }
              }
            },
            # CPU utilization
            {
              width  = 6
              height = 4
              yPos   = 4
              widget = {
                title = "CPU Utilization"
                xyChart = {
                  dataSets = [
                    {
                      timeSeriesQuery = {
                        timeSeriesFilter = {
                          filter = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" resource.type=\"gce_instance\""
                        }
                      }
                      plotType = "LINE"
                    }
                  ]
                }
              }
            },
            # Memory utilization
            {
              width  = 6
              height = 4
              xPos   = 6
              yPos   = 4
              widget = {
                title = "Memory Utilization"
                xyChart = {
                  dataSets = [
                    {
                      timeSeriesQuery = {
                        timeSeriesFilter = {
                          filter = "metric.type=\"agent.googleapis.com/memory/percent_used\" resource.type=\"gce_instance\""
                        }
                      }
                      plotType = "LINE"
                    }
                  ]
                }
              }
            }
          ]
        }
      })
    }
  ]

  # Log metrics
  log_metrics = [
    {
      name        = "${local.environment}_error_count"
      description = "Count of ERROR level logs in staging"

      filter = "severity=\"ERROR\" AND labels.\"environment\"=\"${local.environment}\""

      metric_descriptor = {
        metric_kind = "DELTA"
        value_type  = "INT64"
        unit        = "1"

        labels = [
          {
            key         = "service"
            value_type  = "STRING"
            description = "The service that generated the error"
          }
        ]
      }

      label_extractors = {
        "service" = "EXTRACT(labels.service)"
      }
    },
    {
      name        = "${local.environment}_slow_requests"
      description = "Count of slow requests (>1s) in staging"

      filter = "httpRequest.latency>\"1s\" AND labels.\"environment\"=\"${local.environment}\""

      metric_descriptor = {
        metric_kind = "DELTA"
        value_type  = "INT64"
      }
    }
  ]

  # Log sinks for export
  log_sinks = [
    {
      name        = "${local.environment}-bigquery-sink"
      destination = "bigquery.googleapis.com/projects/acme-staging-platform/datasets/${local.environment}_logs"

      filter = "labels.\"environment\"=\"${local.environment}\""

      unique_writer_identity = true
      bigquery_options = {
        use_partitioned_tables = true
      }
    }
  ]

  # Labels
  labels = {
    environment = local.environment
    region      = local.region
    managed_by  = "terraform"
    component   = "monitoring"
  }
}