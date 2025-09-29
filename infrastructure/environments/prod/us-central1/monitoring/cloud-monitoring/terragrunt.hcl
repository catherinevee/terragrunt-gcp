# Terragrunt configuration for Cloud Monitoring Stack - Production us-central1

terraform {
  source = "../../../../../../modules/monitoring/cloud-monitoring"
}

include "root" {
  path = find_in_parent_folders()
}

include "region" {
  path = find_in_parent_folders("region.hcl")
}

include "env" {
  path = find_in_parent_folders("env.hcl")
}

dependency "vpc" {
  config_path = "../../networking/vpc"
  mock_outputs = {
    network_name         = "mock-vpc-network"
    network_self_link    = "https://www.googleapis.com/compute/v1/projects/mock-project/global/networks/mock-vpc"
    subnets_names        = ["mock-subnet-1", "mock-subnet-2"]
    subnets_self_links   = ["https://www.googleapis.com/compute/v1/projects/mock-project/regions/us-central1/subnetworks/mock-subnet-1"]
  }
}

dependency "gke" {
  config_path = "../../compute/gke"
  mock_outputs = {
    cluster_name     = "mock-gke-cluster"
    cluster_endpoint = "https://mock-cluster-endpoint"
    cluster_ca_certificate = "mock-ca-cert"
  }
}

dependency "cloud_sql" {
  config_path = "../../data/cloud-sql"
  mock_outputs = {
    instance_names           = ["mock-sql-instance"]
    instance_connection_names = ["mock-project:us-central1:mock-sql-instance"]
    private_ip_addresses     = ["10.0.0.100"]
  }
}

dependency "gcs" {
  config_path = "../../storage/cloud-storage"
  mock_outputs = {
    bucket_names = ["mock-logs-bucket", "mock-metrics-bucket"]
    bucket_urls  = ["gs://mock-logs-bucket", "gs://mock-metrics-bucket"]
  }
}

locals {
  # Environment configuration
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.env_vars.locals.environment
  project_id = local.env_vars.locals.project_id

  # Region configuration
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  region = local.region_vars.locals.region

  # Common labels
  common_labels = {
    environment = local.environment
    region      = local.region
    terraform   = "true"
    component   = "monitoring"
  }
}

inputs = {
  project_id = local.project_id
  region     = local.region

  # Enable all monitoring APIs
  enable_apis = true

  # Service account configuration
  create_service_account = true
  service_account_id      = "monitoring-stack-sa"
  service_account_roles = [
    "roles/monitoring.admin",
    "roles/logging.admin",
    "roles/cloudtrace.admin",
    "roles/clouddebugger.admin",
    "roles/cloudprofiler.admin",
    "roles/errorreporting.admin",
    "roles/storage.objectAdmin",
    "roles/bigquery.dataEditor",
    "roles/pubsub.publisher",
    "roles/secretmanager.secretAccessor"
  ]

  # Workspaces configuration
  monitoring_workspaces = {
    prod-monitoring = {
      display_name = "Production Monitoring Workspace"
      description  = "Primary monitoring workspace for production environment"
      labels = merge(local.common_labels, {
        workspace_type = "primary"
      })
    }

    security-monitoring = {
      display_name = "Security Monitoring Workspace"
      description  = "Dedicated workspace for security monitoring and compliance"
      labels = merge(local.common_labels, {
        workspace_type = "security"
      })
    }

    application-monitoring = {
      display_name = "Application Monitoring Workspace"
      description  = "Application-specific monitoring and APM"
      labels = merge(local.common_labels, {
        workspace_type = "application"
      })
    }
  }

  # Notification channels
  notification_channels = {
    email-critical = {
      type         = "email"
      display_name = "Critical Alerts Email"
      description  = "Email notifications for critical alerts"
      labels = {
        email_address = "alerts-critical@company.com"
      }
      user_labels = local.common_labels
      enabled = true
    }

    email-warning = {
      type         = "email"
      display_name = "Warning Alerts Email"
      description  = "Email notifications for warning alerts"
      labels = {
        email_address = "alerts-warning@company.com"
      }
      user_labels = local.common_labels
      enabled = true
    }

    slack-critical = {
      type         = "slack"
      display_name = "Critical Alerts Slack"
      description  = "Slack notifications for critical alerts"
      labels = {
        channel_name = "#alerts-critical"
        url          = "https://hooks.slack.com/services/your/webhook/url"
      }
      user_labels = local.common_labels
      enabled = true
    }

    pagerduty-critical = {
      type         = "pagerduty"
      display_name = "PagerDuty Critical"
      description  = "PagerDuty integration for critical alerts"
      labels = {
        service_key = "your-pagerduty-service-key"
      }
      user_labels = local.common_labels
      enabled = true
    }

    webhook-automation = {
      type         = "webhook_tokenauth"
      display_name = "Automation Webhook"
      description  = "Webhook for automated incident response"
      labels = {
        url   = "https://automation.company.com/webhook/monitoring"
        token = "automation-webhook-token"
      }
      user_labels = local.common_labels
      enabled = true
    }
  }

  # Alert policies - Infrastructure
  alert_policies = {
    # Compute alerts
    gke-cluster-down = {
      display_name = "GKE Cluster Down"
      combiner     = "OR"
      conditions = [{
        display_name = "Cluster not ready"
        condition_threshold = {
          filter          = "resource.type=\"k8s_cluster\" AND metric.type=\"kubernetes.io/cluster/up\""
          duration        = "300s"
          comparison      = "COMPARISON_LT"
          threshold_value = 1
          aggregations = [{
            alignment_period     = "60s"
            per_series_aligner   = "ALIGN_MEAN"
            cross_series_reducer = "REDUCE_MEAN"
            group_by_fields      = ["resource.label.cluster_name"]
          }]
        }
      }]
      notification_channels = ["email-critical", "slack-critical", "pagerduty-critical"]
      alert_strategy = {
        auto_close = "1800s"
        notification_rate_limit = {
          period = "300s"
        }
      }
      documentation = {
        content = "GKE cluster is down or not responding. Check cluster status and node health."
      }
      severity = "CRITICAL"
    }

    gke-node-not-ready = {
      display_name = "GKE Node Not Ready"
      combiner     = "OR"
      conditions = [{
        display_name = "Node not ready"
        condition_threshold = {
          filter          = "resource.type=\"k8s_node\" AND metric.type=\"kubernetes.io/node/ready\""
          duration        = "300s"
          comparison      = "COMPARISON_LT"
          threshold_value = 1
          aggregations = [{
            alignment_period     = "60s"
            per_series_aligner   = "ALIGN_MEAN"
            cross_series_reducer = "REDUCE_MEAN"
            group_by_fields      = ["resource.label.node_name"]
          }]
        }
      }]
      notification_channels = ["email-critical", "slack-critical"]
      alert_strategy = {
        auto_close = "1800s"
      }
      documentation = {
        content = "GKE node is not in ready state. Check node status and resource utilization."
      }
      severity = "HIGH"
    }

    high-cpu-usage = {
      display_name = "High CPU Usage"
      combiner     = "OR"
      conditions = [{
        display_name = "CPU usage above 80%"
        condition_threshold = {
          filter          = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
          duration        = "300s"
          comparison      = "COMPARISON_GT"
          threshold_value = 0.8
          aggregations = [{
            alignment_period     = "60s"
            per_series_aligner   = "ALIGN_MEAN"
            cross_series_reducer = "REDUCE_MEAN"
            group_by_fields      = ["resource.label.instance_id"]
          }]
        }
      }]
      notification_channels = ["email-warning", "slack-critical"]
      alert_strategy = {
        auto_close = "1800s"
      }
      documentation = {
        content = "Instance CPU usage is above 80%. Consider scaling or investigating high load."
      }
      severity = "MEDIUM"
    }

    high-memory-usage = {
      display_name = "High Memory Usage"
      combiner     = "OR"
      conditions = [{
        display_name = "Memory usage above 85%"
        condition_threshold = {
          filter          = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/memory/utilization\""
          duration        = "300s"
          comparison      = "COMPARISON_GT"
          threshold_value = 0.85
          aggregations = [{
            alignment_period     = "60s"
            per_series_aligner   = "ALIGN_MEAN"
            cross_series_reducer = "REDUCE_MEAN"
            group_by_fields      = ["resource.label.instance_id"]
          }]
        }
      }]
      notification_channels = ["email-warning", "slack-critical"]
      alert_strategy = {
        auto_close = "1800s"
      }
      documentation = {
        content = "Instance memory usage is above 85%. Check for memory leaks or scale instances."
      }
      severity = "MEDIUM"
    }

    disk-space-low = {
      display_name = "Low Disk Space"
      combiner     = "OR"
      conditions = [{
        display_name = "Disk usage above 90%"
        condition_threshold = {
          filter          = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/disk/utilization\""
          duration        = "300s"
          comparison      = "COMPARISON_GT"
          threshold_value = 0.9
          aggregations = [{
            alignment_period     = "60s"
            per_series_aligner   = "ALIGN_MEAN"
            cross_series_reducer = "REDUCE_MEAN"
            group_by_fields      = ["resource.label.instance_id", "metric.label.device_name"]
          }]
        }
      }]
      notification_channels = ["email-warning", "slack-critical"]
      alert_strategy = {
        auto_close = "1800s"
      }
      documentation = {
        content = "Disk usage is above 90%. Clean up disk space or increase disk size."
      }
      severity = "HIGH"
    }

    # Database alerts
    cloudsql-cpu-high = {
      display_name = "Cloud SQL High CPU"
      combiner     = "OR"
      conditions = [{
        display_name = "Database CPU above 80%"
        condition_threshold = {
          filter          = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\""
          duration        = "300s"
          comparison      = "COMPARISON_GT"
          threshold_value = 0.8
          aggregations = [{
            alignment_period     = "60s"
            per_series_aligner   = "ALIGN_MEAN"
            cross_series_reducer = "REDUCE_MEAN"
            group_by_fields      = ["resource.label.database_id"]
          }]
        }
      }]
      notification_channels = ["email-critical", "slack-critical"]
      alert_strategy = {
        auto_close = "1800s"
      }
      documentation = {
        content = "Cloud SQL CPU usage is high. Check for long-running queries or consider scaling."
      }
      severity = "HIGH"
    }

    cloudsql-memory-high = {
      display_name = "Cloud SQL High Memory"
      combiner     = "OR"
      conditions = [{
        display_name = "Database memory above 85%"
        condition_threshold = {
          filter          = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/memory/utilization\""
          duration        = "300s"
          comparison      = "COMPARISON_GT"
          threshold_value = 0.85
          aggregations = [{
            alignment_period     = "60s"
            per_series_aligner   = "ALIGN_MEAN"
            cross_series_reducer = "REDUCE_MEAN"
            group_by_fields      = ["resource.label.database_id"]
          }]
        }
      }]
      notification_channels = ["email-critical", "slack-critical"]
      alert_strategy = {
        auto_close = "1800s"
      }
      documentation = {
        content = "Cloud SQL memory usage is high. Consider optimizing queries or scaling."
      }
      severity = "HIGH"
    }

    cloudsql-connections-high = {
      display_name = "Cloud SQL High Connections"
      combiner     = "OR"
      conditions = [{
        display_name = "Connection count above 80% of limit"
        condition_threshold = {
          filter          = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/network/connections\""
          duration        = "300s"
          comparison      = "COMPARISON_GT"
          threshold_value = 80
          aggregations = [{
            alignment_period     = "60s"
            per_series_aligner   = "ALIGN_MEAN"
            cross_series_reducer = "REDUCE_MEAN"
            group_by_fields      = ["resource.label.database_id"]
          }]
        }
      }]
      notification_channels = ["email-warning", "slack-critical"]
      alert_strategy = {
        auto_close = "1800s"
      }
      documentation = {
        content = "Cloud SQL connection count is high. Check for connection leaks or increase limits."
      }
      severity = "MEDIUM"
    }

    # Network alerts
    load-balancer-high-latency = {
      display_name = "Load Balancer High Latency"
      combiner     = "OR"
      conditions = [{
        display_name = "Backend latency above 2s"
        condition_threshold = {
          filter          = "resource.type=\"https_lb_rule\" AND metric.type=\"loadbalancing.googleapis.com/https/backend_latencies\""
          duration        = "300s"
          comparison      = "COMPARISON_GT"
          threshold_value = 2000
          aggregations = [{
            alignment_period     = "60s"
            per_series_aligner   = "ALIGN_DELTA"
            cross_series_reducer = "REDUCE_PERCENTILE_95"
            group_by_fields      = ["resource.label.backend_service_name"]
          }]
        }
      }]
      notification_channels = ["email-warning", "slack-critical"]
      alert_strategy = {
        auto_close = "1800s"
      }
      documentation = {
        content = "Load balancer backend latency is high. Check backend health and performance."
      }
      severity = "MEDIUM"
    }

    load-balancer-error-rate = {
      display_name = "Load Balancer High Error Rate"
      combiner     = "OR"
      conditions = [{
        display_name = "5xx error rate above 5%"
        condition_threshold = {
          filter          = "resource.type=\"https_lb_rule\" AND metric.type=\"loadbalancing.googleapis.com/https/request_count\""
          duration        = "300s"
          comparison      = "COMPARISON_GT"
          threshold_value = 0.05
          aggregations = [{
            alignment_period     = "60s"
            per_series_aligner   = "ALIGN_RATE"
            cross_series_reducer = "REDUCE_SUM"
            group_by_fields      = ["resource.label.backend_service_name", "metric.label.response_code_class"]
          }]
        }
      }]
      notification_channels = ["email-critical", "slack-critical"]
      alert_strategy = {
        auto_close = "1800s"
      }
      documentation = {
        content = "Load balancer 5xx error rate is high. Check backend health and application errors."
      }
      severity = "HIGH"
    }

    # Application alerts
    pod-crash-looping = {
      display_name = "Pod Crash Looping"
      combiner     = "OR"
      conditions = [{
        display_name = "Pod restart count high"
        condition_threshold = {
          filter          = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/restart_count\""
          duration        = "300s"
          comparison      = "COMPARISON_GT"
          threshold_value = 5
          aggregations = [{
            alignment_period     = "60s"
            per_series_aligner   = "ALIGN_DELTA"
            cross_series_reducer = "REDUCE_SUM"
            group_by_fields      = ["resource.label.pod_name", "resource.label.namespace_name"]
          }]
        }
      }]
      notification_channels = ["email-critical", "slack-critical"]
      alert_strategy = {
        auto_close = "1800s"
      }
      documentation = {
        content = "Pod is crash looping. Check application logs and resource limits."
      }
      severity = "HIGH"
    }

    application-error-rate = {
      display_name = "Application High Error Rate"
      combiner     = "OR"
      conditions = [{
        display_name = "Application 5xx rate above 1%"
        condition_threshold = {
          filter          = "resource.type=\"k8s_container\" AND metric.type=\"logging.googleapis.com/user/application_errors\""
          duration        = "300s"
          comparison      = "COMPARISON_GT"
          threshold_value = 0.01
          aggregations = [{
            alignment_period     = "60s"
            per_series_aligner   = "ALIGN_RATE"
            cross_series_reducer = "REDUCE_SUM"
            group_by_fields      = ["resource.label.namespace_name", "resource.label.pod_name"]
          }]
        }
      }]
      notification_channels = ["email-critical", "slack-critical"]
      alert_strategy = {
        auto_close = "1800s"
      }
      documentation = {
        content = "Application error rate is high. Check application logs and dependencies."
      }
      severity = "HIGH"
    }
  }

  # Dashboards configuration
  monitoring_dashboards = {
    infrastructure-overview = {
      display_name = "Infrastructure Overview"
      grid_layout = {
        columns = 12
        widgets = [
          {
            title = "GKE Cluster Health"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"k8s_cluster\" AND metric.type=\"kubernetes.io/cluster/up\""
                  }
                  unit_override = "1"
                }
                plot_type = "LINE"
                target_axis = "Y1"
              }]
              y_axis = {
                label = "Cluster Up"
                scale = "LINEAR"
              }
            }
            width  = 6
            height = 4
          },
          {
            title = "Node CPU Utilization"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"k8s_node\" AND metric.type=\"kubernetes.io/node/cpu/allocatable_utilization\""
                  }
                  unit_override = "1"
                }
                plot_type = "LINE"
                target_axis = "Y1"
              }]
              y_axis = {
                label = "CPU Utilization"
                scale = "LINEAR"
              }
            }
            width  = 6
            height = 4
          },
          {
            title = "Pod Count by Namespace"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"k8s_pod\" AND metric.type=\"kubernetes.io/pod/count\""
                  }
                  unit_override = "1"
                }
                plot_type = "STACKED_AREA"
                target_axis = "Y1"
              }]
              y_axis = {
                label = "Pod Count"
                scale = "LINEAR"
              }
            }
            width  = 12
            height = 4
          }
        ]
      }
      labels = local.common_labels
    }

    database-monitoring = {
      display_name = "Database Monitoring"
      grid_layout = {
        columns = 12
        widgets = [
          {
            title = "Cloud SQL CPU Usage"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\""
                  }
                  unit_override = "1"
                }
                plot_type = "LINE"
                target_axis = "Y1"
              }]
              y_axis = {
                label = "CPU Utilization"
                scale = "LINEAR"
              }
            }
            width  = 6
            height = 4
          },
          {
            title = "Cloud SQL Memory Usage"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/memory/utilization\""
                  }
                  unit_override = "1"
                }
                plot_type = "LINE"
                target_axis = "Y1"
              }]
              y_axis = {
                label = "Memory Utilization"
                scale = "LINEAR"
              }
            }
            width  = 6
            height = 4
          },
          {
            title = "Database Connections"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/network/connections\""
                  }
                  unit_override = "1"
                }
                plot_type = "LINE"
                target_axis = "Y1"
              }]
              y_axis = {
                label = "Connection Count"
                scale = "LINEAR"
              }
            }
            width  = 6
            height = 4
          },
          {
            title = "Query Performance"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/mysql/queries\""
                  }
                  unit_override = "1/s"
                }
                plot_type = "LINE"
                target_axis = "Y1"
              }]
              y_axis = {
                label = "Queries/sec"
                scale = "LINEAR"
              }
            }
            width  = 6
            height = 4
          }
        ]
      }
      labels = local.common_labels
    }

    application-performance = {
      display_name = "Application Performance"
      grid_layout = {
        columns = 12
        widgets = [
          {
            title = "Request Rate"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"https_lb_rule\" AND metric.type=\"loadbalancing.googleapis.com/https/request_count\""
                  }
                  unit_override = "1/s"
                }
                plot_type = "LINE"
                target_axis = "Y1"
              }]
              y_axis = {
                label = "Requests/sec"
                scale = "LINEAR"
              }
            }
            width  = 6
            height = 4
          },
          {
            title = "Response Latency (95th percentile)"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"https_lb_rule\" AND metric.type=\"loadbalancing.googleapis.com/https/backend_latencies\""
                  }
                  unit_override = "ms"
                }
                plot_type = "LINE"
                target_axis = "Y1"
              }]
              y_axis = {
                label = "Latency (ms)"
                scale = "LINEAR"
              }
            }
            width  = 6
            height = 4
          },
          {
            title = "Error Rate by Response Code"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"https_lb_rule\" AND metric.type=\"loadbalancing.googleapis.com/https/request_count\""
                  }
                  unit_override = "1/s"
                }
                plot_type = "STACKED_AREA"
                target_axis = "Y1"
              }]
              y_axis = {
                label = "Requests/sec"
                scale = "LINEAR"
              }
            }
            width  = 12
            height = 4
          }
        ]
      }
      labels = local.common_labels
    }

    security-monitoring = {
      display_name = "Security Monitoring"
      grid_layout = {
        columns = 12
        widgets = [
          {
            title = "Failed Authentication Attempts"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"gce_instance\" AND metric.type=\"logging.googleapis.com/user/auth_failures\""
                  }
                  unit_override = "1/s"
                }
                plot_type = "LINE"
                target_axis = "Y1"
              }]
              y_axis = {
                label = "Failed Attempts/sec"
                scale = "LINEAR"
              }
            }
            width  = 6
            height = 4
          },
          {
            title = "Suspicious Network Activity"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/firewall/dropped_packets_count\""
                  }
                  unit_override = "1/s"
                }
                plot_type = "LINE"
                target_axis = "Y1"
              }]
              y_axis = {
                label = "Dropped Packets/sec"
                scale = "LINEAR"
              }
            }
            width  = 6
            height = 4
          },
          {
            title = "Binary Authorization Violations"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"k8s_cluster\" AND metric.type=\"binary_authorization.googleapis.com/violation_count\""
                  }
                  unit_override = "1"
                }
                plot_type = "LINE"
                target_axis = "Y1"
              }]
              y_axis = {
                label = "Violations"
                scale = "LINEAR"
              }
            }
            width  = 6
            height = 4
          },
          {
            title = "Policy Controller Violations"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"k8s_cluster\" AND metric.type=\"gatekeeper.sh/violations\""
                  }
                  unit_override = "1"
                }
                plot_type = "LINE"
                target_axis = "Y1"
              }]
              y_axis = {
                label = "Policy Violations"
                scale = "LINEAR"
              }
            }
            width  = 6
            height = 4
          }
        ]
      }
      labels = local.common_labels
    }
  }

  # Uptime checks
  uptime_checks = {
    website-health = {
      display_name = "Website Health Check"
      timeout      = "10s"
      period       = "60s"
      http_check = {
        path         = "/health"
        port         = 443
        use_ssl      = true
        validate_ssl = true
        headers = {
          "User-Agent" = "Google-Cloud-Uptime-Check"
        }
      }
      monitored_resource = {
        type = "uptime_url"
        labels = {
          project_id = local.project_id
          host       = "api.company.com"
        }
      }
      content_matchers = [{
        content = "healthy"
        matcher = "CONTAINS_STRING"
      }]
      checker_type = "STATIC_IP_CHECKERS"
      selected_regions = [
        "USA",
        "EUROPE",
        "ASIA_PACIFIC"
      ]
    }

    api-endpoint = {
      display_name = "API Endpoint Check"
      timeout      = "10s"
      period       = "300s"
      http_check = {
        path    = "/api/v1/health"
        port    = 443
        use_ssl = true
        headers = {
          "Authorization" = "Bearer health-check-token"
        }
      }
      monitored_resource = {
        type = "uptime_url"
        labels = {
          project_id = local.project_id
          host       = "api.company.com"
        }
      }
      content_matchers = [{
        content = "\"status\":\"ok\""
        matcher = "CONTAINS_STRING"
      }]
      checker_type = "STATIC_IP_CHECKERS"
      selected_regions = ["USA"]
    }

    database-connectivity = {
      display_name = "Database Connectivity Check"
      timeout      = "10s"
      period       = "300s"
      tcp_check = {
        port = 5432
      }
      monitored_resource = {
        type = "uptime_url"
        labels = {
          project_id = local.project_id
          host       = dependency.cloud_sql.outputs.private_ip_addresses[0]
        }
      }
      checker_type = "STATIC_IP_CHECKERS"
      selected_regions = ["USA"]
    }
  }

  # SLOs configuration
  service_level_objectives = {
    api-availability = {
      display_name = "API Availability SLO"
      goal         = 0.99
      rolling_period_days = 30
      service_level_indicator = {
        request_based = {
          good_total_ratio = {
            good_service_filter  = "resource.type=\"https_lb_rule\" AND metric.type=\"loadbalancing.googleapis.com/https/request_count\" AND metric.label.response_code!~\"5.*\""
            total_service_filter = "resource.type=\"https_lb_rule\" AND metric.type=\"loadbalancing.googleapis.com/https/request_count\""
          }
        }
      }
    }

    api-latency = {
      display_name = "API Latency SLO"
      goal         = 0.95
      rolling_period_days = 30
      service_level_indicator = {
        request_based = {
          distribution_cut = {
            range = {
              max = 2000
            }
          }
        }
      }
    }

    database-availability = {
      display_name = "Database Availability SLO"
      goal         = 0.999
      rolling_period_days = 30
      service_level_indicator = {
        request_based = {
          good_total_ratio = {
            good_service_filter  = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/up\""
            total_service_filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/up\""
          }
        }
      }
    }
  }

  # Log-based metrics
  log_based_metrics = {
    application-errors = {
      name   = "application_errors"
      filter = "resource.type=\"k8s_container\" AND jsonPayload.level=\"ERROR\""
      label_extractors = {
        pod_name   = "EXTRACT(resource.labels.pod_name)"
        namespace  = "EXTRACT(resource.labels.namespace_name)"
        error_type = "EXTRACT(jsonPayload.error_type)"
      }
      metric_descriptor = {
        metric_kind = "GAUGE"
        value_type  = "INT64"
        unit        = "1"
        display_name = "Application Errors"
      }
    }

    security-events = {
      name   = "security_events"
      filter = "resource.type=\"gce_instance\" AND jsonPayload.event_type=\"security_violation\""
      label_extractors = {
        instance_id = "EXTRACT(resource.labels.instance_id)"
        event_type  = "EXTRACT(jsonPayload.event_type)"
        severity    = "EXTRACT(jsonPayload.severity)"
      }
      metric_descriptor = {
        metric_kind = "GAUGE"
        value_type  = "INT64"
        unit        = "1"
        display_name = "Security Events"
      }
    }

    auth-failures = {
      name   = "auth_failures"
      filter = "resource.type=\"gce_instance\" AND jsonPayload.auth_result=\"failure\""
      label_extractors = {
        source_ip = "EXTRACT(jsonPayload.source_ip)"
        user      = "EXTRACT(jsonPayload.user)"
      }
      metric_descriptor = {
        metric_kind = "GAUGE"
        value_type  = "INT64"
        unit        = "1"
        display_name = "Authentication Failures"
      }
    }
  }

  # Enable advanced monitoring features
  enable_monitoring = true
  enable_logging    = true
  enable_tracing    = true
  enable_profiler   = true
  enable_debugger   = true

  # Cloud Trace configuration
  trace_config = {
    sampling_rate = 0.1
    span_kind_filters = ["SERVER", "CLIENT"]
    trace_service_filters = ["frontend", "backend", "database"]
  }

  # Cloud Profiler configuration
  profiler_config = {
    enable_cpu_profiling    = true
    enable_heap_profiling   = true
    enable_mutex_profiling  = false
    enable_goroutine_profiling = true
    profiling_interval      = "60s"
  }

  # Stackdriver integration
  stackdriver_config = {
    enable_kubernetes_monitoring = true
    enable_istio_monitoring      = true
    enable_knative_monitoring    = false
    cluster_name                 = dependency.gke.outputs.cluster_name
    cluster_location            = local.region
  }

  # Custom metric descriptors
  custom_metrics = {
    business-metrics = {
      type         = "custom.googleapis.com/business/revenue"
      display_name = "Business Revenue"
      description  = "Revenue generated by the application"
      metric_kind  = "GAUGE"
      value_type   = "DOUBLE"
      unit         = "USD"
      labels = [
        {
          key         = "product"
          value_type  = "STRING"
          description = "Product name"
        },
        {
          key         = "region"
          value_type  = "STRING"
          description = "Geographic region"
        }
      ]
    }

    performance-metrics = {
      type         = "custom.googleapis.com/performance/transaction_time"
      display_name = "Transaction Processing Time"
      description  = "Time taken to process business transactions"
      metric_kind  = "GAUGE"
      value_type   = "DOUBLE"
      unit         = "ms"
      labels = [
        {
          key         = "transaction_type"
          value_type  = "STRING"
          description = "Type of transaction"
        }
      ]
    }
  }

  # Export destinations
  enable_export_to_bigquery = true
  bigquery_dataset_id       = "monitoring_exports"

  enable_export_to_pubsub = true
  pubsub_topic_name      = "monitoring-events"

  # Integration with existing resources
  vpc_network    = dependency.vpc.outputs.network_name
  gke_cluster    = dependency.gke.outputs.cluster_name
  storage_bucket = dependency.gcs.outputs.bucket_names[0]

  # Common labels for all monitoring resources
  labels = local.common_labels
}