# Cloud Run Configuration for Production - US Central 1
# Serverless container deployment with auto-scaling, traffic management, and service mesh integration

terraform {
  source = "${get_repo_root()}/modules/compute/cloud-run"
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

# Cloud Run depends on VPC for private connectivity
dependency "vpc" {
  config_path = "../../networking/vpc"

  mock_outputs = {
    network_id = "mock-network-id"
    network_name = "mock-network-name"
    connector_id = "mock-connector-id"
    subnets = {
      serverless = {
        id = "mock-subnet-id"
        name = "mock-subnet-name"
        ip_cidr_range = "10.8.0.0/28"
      }
    }
  }
}

# Cloud Run depends on IAM for service accounts
dependency "iam" {
  config_path = "../../security/iam"

  mock_outputs = {
    service_accounts = {
      cloud_run = {
        email = "cloud-run-sa@project.iam.gserviceaccount.com"
        id = "cloud-run-sa"
      }
    }
  }
}

# Cloud Run depends on Secret Manager
dependency "secret_manager" {
  config_path = "../../security/secret-manager"
  skip_outputs = true

  mock_outputs = {
    secrets = {
      api_keys = {
        id = "api-keys-secret"
        secret_id = "api-keys"
      }
      database_credentials = {
        id = "db-credentials-secret"
        secret_id = "db-credentials"
      }
    }
  }
}

# Cloud Run depends on KMS for encryption
dependency "kms" {
  config_path = "../../security/kms"

  mock_outputs = {
    keys = {
      default = {
        id = "mock-key-id"
        self_link = "projects/mock/locations/us-central1/keyRings/mock/cryptoKeys/mock"
      }
    }
  }
}

locals {
  # Extract configuration from includes
  env_config    = include.env.locals
  region_config = include.region.locals

  # Service naming prefix
  service_prefix = "${local.env_config.environment}-${local.region_config.region_short}"

  # Container registry configuration
  container_registry = {
    location = local.region_config.region
    repository = "${local.region_config.region}-docker.pkg.dev/${var.project_id}/${local.env_config.environment}"
  }

  # Cloud Run services configuration
  services = {
    # Main API service
    api = {
      name = "${local.service_prefix}-api"
      description = "Main API service for ${local.env_config.environment}"
      location = local.region_config.region

      # Container configuration
      template = {
        metadata = {
          annotations = {
            "autoscaling.knative.dev/minScale" = local.env_config.environment == "prod" ? "3" : "1"
            "autoscaling.knative.dev/maxScale" = local.env_config.environment == "prod" ? "1000" : "100"
            "autoscaling.knative.dev/target" = "100"
            "autoscaling.knative.dev/targetUtilizationPercentage" = "70"
            "run.googleapis.com/cpu-throttling" = "false"
            "run.googleapis.com/execution-environment" = local.env_config.environment == "prod" ? "gen2" : "gen1"
            "run.googleapis.com/vpc-access-connector" = dependency.vpc.outputs.connector_id
            "run.googleapis.com/vpc-access-egress" = "private-ranges-only"
            "run.googleapis.com/cloudsql-instances" = "${var.project_id}:${local.region_config.region}:${local.env_config.environment}-postgres-main"
            "run.googleapis.com/sandbox" = "gvisor"
            "run.googleapis.com/launch-stage" = "GA"
            "run.googleapis.com/network-interfaces" = jsonencode([{
              network = dependency.vpc.outputs.network_name
              subnetwork = dependency.vpc.outputs.subnets.serverless.name
            }])
          }

          labels = {
            service = "api"
            version = "v1"
            environment = local.env_config.environment
          }
        }

        spec = {
          container_concurrency = 1000
          timeout_seconds = 300
          service_account_name = dependency.iam.outputs.service_accounts.cloud_run.email

          containers = [
            {
              name = "api-container"
              image = "${local.container_registry.repository}/api:latest"

              # Resource limits
              resources = {
                limits = {
                  cpu = local.env_config.environment == "prod" ? "4" : "2"
                  memory = local.env_config.environment == "prod" ? "8Gi" : "4Gi"
                }
                requests = {
                  cpu = local.env_config.environment == "prod" ? "2" : "1"
                  memory = local.env_config.environment == "prod" ? "4Gi" : "2Gi"
                }
              }

              # Environment variables
              env = [
                {
                  name = "ENVIRONMENT"
                  value = local.env_config.environment
                },
                {
                  name = "REGION"
                  value = local.region_config.region
                },
                {
                  name = "PROJECT_ID"
                  value = var.project_id
                },
                {
                  name = "LOG_LEVEL"
                  value = local.env_config.environment == "prod" ? "INFO" : "DEBUG"
                },
                {
                  name = "MAX_WORKERS"
                  value = "8"
                },
                {
                  name = "ENABLE_METRICS"
                  value = "true"
                },
                {
                  name = "ENABLE_TRACING"
                  value = "true"
                },
                {
                  name = "CORS_ORIGINS"
                  value = local.env_config.environment == "prod" ? "https://example.com,https://www.example.com" : "*"
                }
              ]

              # Secret environment variables
              env_from = [
                {
                  secret_ref = {
                    name = dependency.secret_manager.outputs.secrets.api_keys.secret_id
                  }
                },
                {
                  secret_ref = {
                    name = dependency.secret_manager.outputs.secrets.database_credentials.secret_id
                  }
                }
              ]

              # Volume mounts
              volume_mounts = [
                {
                  name = "config"
                  mount_path = "/etc/config"
                  read_only = true
                },
                {
                  name = "secrets"
                  mount_path = "/etc/secrets"
                  read_only = true
                },
                {
                  name = "cloudsql"
                  mount_path = "/cloudsql"
                }
              ]

              # Startup probe
              startup_probe = {
                initial_delay_seconds = 10
                timeout_seconds = 5
                period_seconds = 10
                failure_threshold = 3
                tcp_socket = {
                  port = 8080
                }
              }

              # Liveness probe
              liveness_probe = {
                initial_delay_seconds = 30
                timeout_seconds = 5
                period_seconds = 30
                failure_threshold = 3
                http_get = {
                  path = "/health/live"
                  port = 8080
                  http_headers = [
                    {
                      name = "X-Health-Check"
                      value = "liveness"
                    }
                  ]
                }
              }

              # Readiness probe
              readiness_probe = {
                initial_delay_seconds = 20
                timeout_seconds = 5
                period_seconds = 10
                failure_threshold = 3
                success_threshold = 2
                http_get = {
                  path = "/health/ready"
                  port = 8080
                  http_headers = [
                    {
                      name = "X-Health-Check"
                      value = "readiness"
                    }
                  ]
                }
              }

              # Port configuration
              ports = [
                {
                  name = "http1"
                  container_port = 8080
                  protocol = "TCP"
                }
              ]

              # Command and arguments
              command = ["/app/server"]
              args = [
                "--port=8080",
                "--workers=${local.env_config.environment == "prod" ? "8" : "4"}",
                "--graceful-timeout=30s"
              ]
            }
          ]

          # Volumes
          volumes = [
            {
              name = "config"
              config_map = {
                name = "${local.service_prefix}-api-config"
                items = [
                  {
                    key = "app.yaml"
                    path = "app.yaml"
                  }
                ]
              }
            },
            {
              name = "secrets"
              secret = {
                secret_name = "${local.service_prefix}-api-secrets"
                items = [
                  {
                    key = "credentials.json"
                    path = "credentials.json"
                  }
                ]
              }
            },
            {
              name = "cloudsql"
              empty_dir = {
                medium = "Memory"
                size_limit = "256Mi"
              }
            }
          ]
        }
      }

      # Traffic configuration
      traffic = [
        {
          percent = 100
          latest_revision = true
          tag = "latest"
        }
      ]

      # Autoscaling configuration
      autoscaling = {
        min_instances = local.env_config.environment == "prod" ? 3 : 1
        max_instances = local.env_config.environment == "prod" ? 1000 : 100

        metrics = [
          {
            type = "cpu_utilization"
            target = 0.7
          },
          {
            type = "memory_utilization"
            target = 0.8
          },
          {
            type = "request_count"
            target = 100
          },
          {
            type = "request_latency"
            target = "500ms"
          }
        ]

        scale_down_control = {
          max_scale_down_rate = 10
          scale_down_delay = "60s"
        }

        scale_up_control = {
          max_scale_up_rate = 100
          scale_up_delay = "10s"
        }
      }

      # IAM bindings
      iam_bindings = {
        "roles/run.invoker" = local.env_config.environment == "prod" ? [
          "serviceAccount:${dependency.iam.outputs.service_accounts.cloud_run.email}"
        ] : ["allUsers"]

        "roles/run.viewer" = [
          "group:developers@${local.env_config.organization_domain}"
        ]
      }

      # Binary authorization
      binary_authorization = local.env_config.environment == "prod" ? {
        use_default = false
        policy = "${var.project_id}.${local.env_config.environment}-policy"
        attestation_required = true
      } : null
    }

    # Web application service
    webapp = {
      name = "${local.service_prefix}-webapp"
      description = "Web application service for ${local.env_config.environment}"
      location = local.region_config.region

      template = {
        metadata = {
          annotations = {
            "autoscaling.knative.dev/minScale" = local.env_config.environment == "prod" ? "2" : "0"
            "autoscaling.knative.dev/maxScale" = local.env_config.environment == "prod" ? "500" : "50"
            "run.googleapis.com/execution-environment" = "gen2"
          }
        }

        spec = {
          container_concurrency = 500
          timeout_seconds = 60
          service_account_name = dependency.iam.outputs.service_accounts.cloud_run.email

          containers = [
            {
              name = "webapp-container"
              image = "${local.container_registry.repository}/webapp:latest"

              resources = {
                limits = {
                  cpu = "2"
                  memory = "2Gi"
                }
              }

              env = [
                {
                  name = "API_URL"
                  value = "https://api-${local.service_prefix}.a.run.app"
                },
                {
                  name = "ENABLE_CDN"
                  value = "true"
                }
              ]

              ports = [
                {
                  container_port = 3000
                }
              ]
            }
          ]
        }
      }

      traffic = [
        {
          percent = 100
          latest_revision = true
        }
      ]

      iam_bindings = {
        "roles/run.invoker" = ["allUsers"]  # Public web app
      }
    }

    # Background jobs service
    jobs = {
      name = "${local.service_prefix}-jobs"
      description = "Background jobs processor for ${local.env_config.environment}"
      location = local.region_config.region

      template = {
        metadata = {
          annotations = {
            "autoscaling.knative.dev/minScale" = "0"
            "autoscaling.knative.dev/maxScale" = local.env_config.environment == "prod" ? "200" : "20"
            "run.googleapis.com/cpu-throttling" = "true"
          }
        }

        spec = {
          container_concurrency = 1  # Process one job at a time
          timeout_seconds = 900  # 15 minutes for long-running jobs

          containers = [
            {
              name = "jobs-container"
              image = "${local.container_registry.repository}/jobs:latest"

              resources = {
                limits = {
                  cpu = "4"
                  memory = "8Gi"
                }
              }

              env = [
                {
                  name = "JOB_QUEUE"
                  value = "${local.env_config.environment}-jobs"
                },
                {
                  name = "MAX_RETRIES"
                  value = "3"
                }
              ]
            }
          ]
        }
      }

      iam_bindings = {
        "roles/run.invoker" = [
          "serviceAccount:${dependency.iam.outputs.service_accounts.scheduler.email}"
        ]
      }
    }

    # WebSocket service
    websocket = {
      name = "${local.service_prefix}-websocket"
      description = "WebSocket service for real-time communication"
      location = local.region_config.region

      template = {
        metadata = {
          annotations = {
            "autoscaling.knative.dev/minScale" = local.env_config.environment == "prod" ? "2" : "1"
            "autoscaling.knative.dev/maxScale" = local.env_config.environment == "prod" ? "100" : "10"
            "run.googleapis.com/sessionAffinity" = "true"  # Sticky sessions for WebSocket
          }
        }

        spec = {
          container_concurrency = 1000
          timeout_seconds = 3600  # 1 hour for WebSocket connections

          containers = [
            {
              name = "websocket-container"
              image = "${local.container_registry.repository}/websocket:latest"

              resources = {
                limits = {
                  cpu = "2"
                  memory = "4Gi"
                }
              }

              env = [
                {
                  name = "WEBSOCKET_PORT"
                  value = "8080"
                },
                {
                  name = "ENABLE_COMPRESSION"
                  value = "true"
                },
                {
                  name = "MAX_CONNECTIONS"
                  value = "10000"
                }
              ]

              ports = [
                {
                  container_port = 8080
                }
              ]
            }
          ]
        }
      }

      iam_bindings = {
        "roles/run.invoker" = ["allUsers"]
      }
    }

    # GraphQL service
    graphql = {
      name = "${local.service_prefix}-graphql"
      description = "GraphQL API service"
      location = local.region_config.region

      template = {
        metadata = {
          annotations = {
            "autoscaling.knative.dev/minScale" = local.env_config.environment == "prod" ? "2" : "0"
            "autoscaling.knative.dev/maxScale" = local.env_config.environment == "prod" ? "200" : "20"
          }
        }

        spec = {
          container_concurrency = 500
          timeout_seconds = 120

          containers = [
            {
              name = "graphql-container"
              image = "${local.container_registry.repository}/graphql:latest"

              resources = {
                limits = {
                  cpu = "2"
                  memory = "4Gi"
                }
              }

              env = [
                {
                  name = "GRAPHQL_PLAYGROUND"
                  value = local.env_config.environment == "prod" ? "false" : "true"
                },
                {
                  name = "INTROSPECTION"
                  value = local.env_config.environment == "prod" ? "false" : "true"
                },
                {
                  name = "DEPTH_LIMIT"
                  value = "10"
                },
                {
                  name = "COMPLEXITY_LIMIT"
                  value = "1000"
                }
              ]

              ports = [
                {
                  container_port = 4000
                }
              ]
            }
          ]
        }
      }

      iam_bindings = {
        "roles/run.invoker" = local.env_config.environment == "prod" ? [
          "serviceAccount:${dependency.iam.outputs.service_accounts.cloud_run.email}"
        ] : ["allUsers"]
      }
    }
  }

  # Cloud Run Jobs configuration
  jobs_config = {
    # Data processing job
    data_processor = {
      name = "${local.service_prefix}-data-processor-job"
      description = "Batch data processing job"
      location = local.region_config.region

      template = {
        metadata = {
          annotations = {
            "run.googleapis.com/vpc-access-connector" = dependency.vpc.outputs.connector_id
            "run.googleapis.com/vpc-access-egress" = "private-ranges-only"
          }
        }

        spec = {
          template = {
            spec = {
              service_account_name = dependency.iam.outputs.service_accounts.cloud_run.email
              timeout_seconds = 3600
              max_retries = 3
              parallelism = 10
              task_count = 100

              containers = [
                {
                  name = "processor"
                  image = "${local.container_registry.repository}/data-processor:latest"

                  resources = {
                    limits = {
                      cpu = "4"
                      memory = "16Gi"
                    }
                  }

                  env = [
                    {
                      name = "BATCH_SIZE"
                      value = "1000"
                    },
                    {
                      name = "PARALLEL_WORKERS"
                      value = "4"
                    }
                  ]
                }
              ]
            }
          }
        }
      }

      schedule = {
        schedule = "0 2 * * *"  # Daily at 2 AM
        time_zone = "America/New_York"
        retry_config = {
          retry_count = 3
          max_retry_duration = "3600s"
          min_backoff_duration = "60s"
          max_backoff_duration = "3600s"
        }
      }
    }

    # Report generator job
    report_generator = {
      name = "${local.service_prefix}-report-generator-job"
      description = "Generate and send reports"
      location = local.region_config.region

      template = {
        spec = {
          template = {
            spec = {
              service_account_name = dependency.iam.outputs.service_accounts.cloud_run.email
              timeout_seconds = 1800
              max_retries = 2

              containers = [
                {
                  name = "reporter"
                  image = "${local.container_registry.repository}/report-generator:latest"

                  resources = {
                    limits = {
                      cpu = "2"
                      memory = "4Gi"
                    }
                  }

                  env = [
                    {
                      name = "REPORT_TYPE"
                      value = "DAILY"
                    },
                    {
                      name = "SEND_EMAIL"
                      value = "true"
                    }
                  ]
                }
              ]
            }
          }
        }
      }

      schedule = {
        schedule = "0 6 * * 1-5"  # Weekdays at 6 AM
        time_zone = "America/New_York"
      }
    }

    # Cleanup job
    cleanup = {
      name = "${local.service_prefix}-cleanup-job"
      description = "Clean up old resources"
      location = local.region_config.region

      template = {
        spec = {
          template = {
            spec = {
              service_account_name = dependency.iam.outputs.service_accounts.cloud_run.email
              timeout_seconds = 600

              containers = [
                {
                  name = "cleanup"
                  image = "${local.container_registry.repository}/cleanup:latest"

                  env = [
                    {
                      name = "RETENTION_DAYS"
                      value = local.env_config.environment == "prod" ? "90" : "30"
                    },
                    {
                      name = "DRY_RUN"
                      value = "false"
                    }
                  ]
                }
              ]
            }
          }
        }
      }

      schedule = {
        schedule = "0 3 * * 0"  # Weekly on Sunday at 3 AM
        time_zone = "America/New_York"
      }
    }
  }

  # Traffic management configuration
  traffic_management = {
    # Blue-green deployment
    blue_green = {
      enabled = local.env_config.environment == "prod"
      traffic_split_duration = "3600s"
      rollback_on_failure = true
    }

    # Canary deployment
    canary = {
      enabled = local.env_config.environment == "prod"
      initial_traffic_percent = 10
      increment_percent = 10
      increment_interval = "600s"
      max_error_rate = 0.01
    }

    # A/B testing
    ab_testing = {
      enabled = false
      experiments = []
    }
  }

  # Monitoring and alerting
  monitoring_config = {
    alerts = {
      high_latency = {
        display_name = "High Latency - Cloud Run"
        conditions = {
          threshold_ms = 1000
          duration = "300s"
        }
      }

      high_error_rate = {
        display_name = "High Error Rate - Cloud Run"
        conditions = {
          threshold_percent = 1
          duration = "300s"
        }
      }

      scaling_issues = {
        display_name = "Scaling Issues - Cloud Run"
        conditions = {
          min_instances = 0
          duration = "600s"
        }
      }

      memory_pressure = {
        display_name = "Memory Pressure - Cloud Run"
        conditions = {
          threshold_percent = 90
          duration = "300s"
        }
      }

      cold_starts = {
        display_name = "Excessive Cold Starts - Cloud Run"
        conditions = {
          threshold_count = 100
          duration = "300s"
        }
      }
    }

    metrics = {
      request_count = {
        metric = "run.googleapis.com/request_count"
        aggregation = "ALIGN_RATE"
      }

      request_latencies = {
        metric = "run.googleapis.com/request_latencies"
        aggregation = "ALIGN_DELTA"
      }

      container_cpu_utilization = {
        metric = "run.googleapis.com/container/cpu/utilizations"
        aggregation = "ALIGN_MEAN"
      }

      container_memory_utilization = {
        metric = "run.googleapis.com/container/memory/utilizations"
        aggregation = "ALIGN_MEAN"
      }

      container_startup_latencies = {
        metric = "run.googleapis.com/container/startup_latencies"
        aggregation = "ALIGN_DELTA"
      }
    }

    dashboard = {
      display_name = "Cloud Run Dashboard - ${local.env_config.environment}"

      widgets = [
        {
          title = "Request Rate"
          metric = "request_count"
          chart_type = "LINE"
        },
        {
          title = "Latency Distribution"
          metric = "request_latencies"
          chart_type = "HEATMAP"
        },
        {
          title = "CPU Utilization"
          metric = "container_cpu_utilization"
          chart_type = "LINE"
        },
        {
          title = "Memory Utilization"
          metric = "container_memory_utilization"
          chart_type = "LINE"
        },
        {
          title = "Cold Start Latency"
          metric = "container_startup_latencies"
          chart_type = "HISTOGRAM"
        }
      ]
    }
  }

  # Service mesh configuration (Istio/Anthos Service Mesh)
  service_mesh = local.env_config.environment == "prod" ? {
    enabled = true
    type = "ANTHOS_SERVICE_MESH"

    traffic_management = {
      circuit_breaking = {
        max_connections = 1000
        max_pending_requests = 100
        max_requests = 1000
        max_retries = 3
      }

      retry_policy = {
        attempts = 3
        per_try_timeout = "30s"
        retry_on = "5xx,reset,connect-failure,refused-stream"
      }

      timeout_policy = {
        timeout = "60s"
      }
    }

    security = {
      mtls_mode = "STRICT"
      authorization_policies = [
        {
          name = "allow-internal"
          rules = [
            {
              from = {
                source = {
                  principals = ["cluster.local/ns/production/sa/*"]
                }
              }
              to = {
                operation = {
                  methods = ["GET", "POST", "PUT", "DELETE"]
                }
              }
            }
          ]
        }
      ]
    }

    observability = {
      enable_metrics = true
      enable_tracing = true
      enable_access_logs = true

      tracing_sampling = 0.1  # 10% sampling in production
    }
  } : null

  # Cost optimization configuration
  cost_optimization = {
    # Use minimum instances only in production
    use_min_instances = local.env_config.environment == "prod"

    # CPU allocation
    cpu_idle = local.env_config.environment != "prod"

    # Startup CPU boost
    startup_cpu_boost = true

    # Session affinity for WebSocket/streaming
    use_session_affinity = false

    # Execution environment
    use_gen2_environment = local.env_config.environment == "prod"

    # Concurrency tuning
    optimize_concurrency = true
    target_concurrency = 100

    # Cold start mitigation
    warm_up_requests = local.env_config.environment == "prod"
    min_instances_warm = local.env_config.environment == "prod" ? 1 : 0
  }
}

# Module inputs
inputs = {
  # Project configuration
  project_id = var.project_id
  region     = local.region_config.region

  # Cloud Run services
  services = local.services

  # Cloud Run Jobs
  jobs = local.jobs_config

  # Network configuration
  network_config = {
    vpc_connector = dependency.vpc.outputs.connector_id
    vpc_network = dependency.vpc.outputs.network_name
    egress = "PRIVATE_RANGES_ONLY"
  }

  # Container registry
  container_registry = local.container_registry

  # Traffic management
  traffic_management = local.traffic_management

  # Service mesh configuration
  service_mesh = local.service_mesh

  # Security configuration
  security_config = {
    service_account = dependency.iam.outputs.service_accounts.cloud_run.email
    encryption_key = dependency.kms.outputs.keys.default.self_link
    binary_authorization = local.env_config.environment == "prod"
    vpc_sc_enabled = local.env_config.environment == "prod"
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
      component = "compute"
      service   = "cloud-run"
      tier      = "serverless"
    }
  )

  # Dependencies
  depends_on = [dependency.vpc, dependency.iam, dependency.secret_manager, dependency.kms]
}