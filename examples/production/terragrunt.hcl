# Production-grade configuration example
# Demonstrates enterprise-level setup with comprehensive security,
# monitoring, backup, and disaster recovery configurations

include "root" {
  path = find_in_parent_folders()
}

locals {
  # Environment configuration
  environment = "production"
  project     = "enterprise-app"
  region      = "us-east1"
  zones       = ["us-east1-a", "us-east1-b", "us-east1-c"]

  # Multi-region setup for disaster recovery
  regions = {
    primary = {
      name  = "us-east1"
      zones = ["us-east1-a", "us-east1-b", "us-east1-c"]
    }
    secondary = {
      name  = "us-west1"
      zones = ["us-west1-a", "us-west1-b", "us-west1-c"]
    }
  }

  # Application configuration
  app_name    = "enterprise-webapp"
  app_version = "v2.1.0"

  # Common labels for all resources
  common_labels = {
    environment     = local.environment
    project        = local.project
    managed_by     = "terragrunt"
    app_name       = local.app_name
    app_version    = local.app_version
    cost_center    = "engineering"
    business_unit  = "product"
    compliance     = "pci-dss"
    data_classification = "confidential"
  }

  # Security configuration
  security_config = {
    # Enable all security features
    enable_os_login             = true
    enable_shielded_vm          = true
    enable_confidential_vm      = true
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true

    # Network security
    enable_private_google_access = true
    enable_flow_logs            = true
    enable_firewall_logging     = true

    # Encryption
    enable_disk_encryption = true
    kms_key_ring          = "production-keyring"
    kms_crypto_key        = "application-key"

    # Access control
    allowed_ip_ranges = [
      "10.0.0.0/8",     # Private networks
      "172.16.0.0/12",  # Private networks
      "192.168.0.0/16", # Private networks
    ]

    # Certificate management
    ssl_certificates = {
      primary = {
        domains = ["app.company.com", "api.company.com"]
        type    = "MANAGED"
      }
      wildcard = {
        domains = ["*.company.com"]
        type    = "MANAGED"
      }
    }
  }

  # Network architecture
  network_config = {
    # Primary VPC
    primary_vpc = {
      name = "production-vpc"
      cidr = "10.0.0.0/16"

      subnets = {
        # Web tier subnets (public)
        web_primary = {
          cidr                = "10.0.1.0/24"
          region             = local.regions.primary.name
          enable_flow_logs   = true
          private_google_access = false
        }

        # Application tier subnets (private)
        app_primary = {
          cidr                = "10.0.2.0/24"
          region             = local.regions.primary.name
          enable_flow_logs   = true
          private_google_access = true
        }

        # Database tier subnets (private)
        db_primary = {
          cidr                = "10.0.3.0/24"
          region             = local.regions.primary.name
          enable_flow_logs   = true
          private_google_access = true
        }

        # Management subnet (restricted access)
        mgmt_primary = {
          cidr                = "10.0.4.0/24"
          region             = local.regions.primary.name
          enable_flow_logs   = true
          private_google_access = true
        }

        # GKE cluster subnet
        gke_primary = {
          cidr                = "10.0.10.0/24"
          region             = local.regions.primary.name
          enable_flow_logs   = true
          private_google_access = true

          secondary_ranges = {
            pods     = "10.1.0.0/16"
            services = "10.2.0.0/16"
          }
        }
      }
    }

    # Secondary VPC for disaster recovery
    secondary_vpc = {
      name = "production-dr-vpc"
      cidr = "10.100.0.0/16"

      subnets = {
        web_secondary = {
          cidr                = "10.100.1.0/24"
          region             = local.regions.secondary.name
          enable_flow_logs   = true
          private_google_access = false
        }

        app_secondary = {
          cidr                = "10.100.2.0/24"
          region             = local.regions.secondary.name
          enable_flow_logs   = true
          private_google_access = true
        }

        db_secondary = {
          cidr                = "10.100.3.0/24"
          region             = local.regions.secondary.name
          enable_flow_logs   = true
          private_google_access = true
        }
      }
    }

    # VPC peering between primary and secondary
    vpc_peering = {
      enable = true
      auto_create_routes = true
    }

    # Cloud NAT configuration for private subnets
    cloud_nat = {
      primary = {
        region = local.regions.primary.name
        router_name = "production-router-primary"
      }
      secondary = {
        region = local.regions.secondary.name
        router_name = "production-router-secondary"
      }
    }

    # Private Service Connect
    private_service_connect = {
      enable_google_apis = true
      enable_all_apis   = false
      enabled_apis = [
        "sqladmin.googleapis.com",
        "storage.googleapis.com",
        "secretmanager.googleapis.com",
        "monitoring.googleapis.com",
        "logging.googleapis.com"
      ]
    }
  }

  # Compute configuration
  compute_config = {
    # Web tier
    web_tier = {
      machine_type     = "e2-standard-4"
      min_replicas     = 6
      max_replicas     = 50
      target_cpu_util  = 0.6
      disk_size_gb     = 50
      disk_type        = "pd-ssd"
      preemptible      = false

      # Multi-zone distribution
      zones = local.zones

      # Auto-scaling configuration
      autoscaling = {
        cpu_utilization    = 0.6
        load_balancing_utilization = 0.7
        custom_metrics = [
          {
            name   = "custom.googleapis.com/application/requests_per_second"
            target = 1000
          }
        ]
      }
    }

    # Application tier
    app_tier = {
      machine_type     = "e2-standard-8"
      min_replicas     = 9
      max_replicas     = 100
      target_cpu_util  = 0.7
      disk_size_gb     = 100
      disk_type        = "pd-ssd"
      preemptible      = false

      zones = local.zones

      autoscaling = {
        cpu_utilization    = 0.7
        memory_utilization = 0.8
        custom_metrics = [
          {
            name   = "custom.googleapis.com/application/queue_depth"
            target = 10
          }
        ]
      }
    }

    # Data processing tier
    data_tier = {
      machine_type     = "c2-standard-16"
      min_replicas     = 3
      max_replicas     = 20
      target_cpu_util  = 0.8
      disk_size_gb     = 500
      disk_type        = "pd-ssd"
      preemptible      = false

      zones = local.zones
    }
  }

  # Database configuration
  database_config = {
    # Primary MySQL cluster
    mysql_primary = {
      version           = "MYSQL_8_0"
      tier             = "db-n1-highmem-8"
      disk_size        = 1000
      disk_type        = "PD_SSD"
      availability_type = "REGIONAL"
      backup_enabled   = true
      backup_start_time = "03:00"
      point_in_time_recovery = true

      # Maintenance window
      maintenance_window = {
        day  = 1  # Sunday
        hour = 4  # 4 AM
      }

      # Read replicas
      read_replicas = [
        {
          name         = "mysql-read-replica-1"
          tier         = "db-n1-highmem-4"
          region       = local.regions.primary.name
        },
        {
          name         = "mysql-read-replica-2"
          tier         = "db-n1-highmem-4"
          region       = local.regions.secondary.name
        }
      ]

      # Database flags
      database_flags = [
        {
          name  = "slow_query_log"
          value = "on"
        },
        {
          name  = "log_output"
          value = "FILE"
        },
        {
          name  = "innodb_buffer_pool_size"
          value = "75"  # Percentage
        }
      ]
    }

    # Redis cluster for caching
    redis_primary = {
      memory_size_gb    = 32
      tier             = "STANDARD_HA"
      auth_enabled     = true
      transit_encryption_mode = "SERVER_AUTHENTICATION"
      connect_mode     = "PRIVATE_SERVICE_ACCESS"

      # Maintenance policy
      maintenance_policy = {
        weekly_maintenance_window = {
          day       = "SUNDAY"
          start_time = {
            hours   = 4
            minutes = 0
          }
        }
      }
    }
  }

  # Storage configuration
  storage_config = {
    # Application data bucket
    app_data = {
      name          = "prod-app-data-${random_id.bucket_suffix.hex}"
      location      = "US"
      storage_class = "STANDARD"
      versioning   = true

      # Lifecycle management
      lifecycle_rules = [
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

      # CORS configuration
      cors = [
        {
          origin          = ["https://app.company.com"]
          method          = ["GET", "POST", "PUT"]
          response_header = ["*"]
          max_age_seconds = 3600
        }
      ]

      # Retention policy
      retention_policy = {
        retention_period = 2592000  # 30 days
        is_locked       = true
      }
    }

    # Backup bucket
    backups = {
      name          = "prod-backups-${random_id.bucket_suffix.hex}"
      location      = "US"
      storage_class = "COLDLINE"
      versioning   = true

      lifecycle_rules = [
        {
          action = {
            type = "SetStorageClass"
            storage_class = "ARCHIVE"
          }
          condition = {
            age = 90
          }
        },
        {
          action = {
            type = "Delete"
          }
          condition = {
            age = 2555  # 7 years
          }
        }
      ]
    }

    # Logs bucket
    logs = {
      name          = "prod-logs-${random_id.bucket_suffix.hex}"
      location      = "US"
      storage_class = "NEARLINE"
      versioning   = false

      lifecycle_rules = [
        {
          action = {
            type = "SetStorageClass"
            storage_class = "COLDLINE"
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
    }
  }

  # Load balancer configuration
  load_balancer_config = {
    # Global HTTPS load balancer
    global_https = {
      name = "production-global-lb"
      ip_version = "IPV4"
      load_balancing_scheme = "EXTERNAL"

      # Backend services
      backend_services = {
        web = {
          port_name   = "https"
          protocol    = "HTTPS"
          timeout_sec = 30
          enable_cdn  = true

          # Health check
          health_check = {
            check_interval_sec  = 10
            timeout_sec         = 5
            healthy_threshold   = 2
            unhealthy_threshold = 3
            request_path        = "/health"
            port                = 443
          }

          # CDN configuration
          cdn_policy = {
            cache_mode = "CACHE_ALL_STATIC"
            default_ttl = 3600
            max_ttl     = 86400
            client_ttl  = 3600

            cache_key_policy = {
              include_host         = true
              include_protocol     = true
              include_query_string = false
            }
          }

          # IAP (Identity-Aware Proxy) configuration
          iap = {
            enabled = true
            oauth2_client_id     = "your-oauth2-client-id"
            oauth2_client_secret = "your-oauth2-client-secret"
          }
        }

        api = {
          port_name   = "https"
          protocol    = "HTTPS"
          timeout_sec = 60
          enable_cdn  = false

          health_check = {
            check_interval_sec  = 10
            timeout_sec         = 5
            healthy_threshold   = 2
            unhealthy_threshold = 3
            request_path        = "/api/health"
            port                = 443
          }
        }
      }

      # URL map configuration
      url_map = {
        default_service = "web"

        path_matchers = [
          {
            name = "api-matcher"
            default_service = "api"
            path_rules = [
              {
                paths   = ["/api/*"]
                service = "api"
              }
            ]
          }
        ]

        host_rules = [
          {
            hosts        = ["api.company.com"]
            path_matcher = "api-matcher"
          }
        ]
      }

      # Security policy
      security_policy = {
        name = "production-security-policy"

        # DDoS protection
        adaptive_protection_config = {
          layer_7_ddos_defense_config = {
            enable = true
          }
        }

        # Rate limiting
        rate_limit_threshold_config = {
          count        = 1000
          interval_sec = 60
        }

        # Geographic restrictions
        geo_restriction_config = {
          action = "DENY"
          countries = ["CN", "RU"]  # Example restrictions
        }
      }
    }

    # Internal load balancer for backend communication
    internal = {
      name = "production-internal-lb"
      load_balancing_scheme = "INTERNAL"

      backend_service = {
        protocol    = "HTTP"
        port_name   = "http"
        timeout_sec = 30

        health_check = {
          check_interval_sec  = 10
          timeout_sec         = 5
          healthy_threshold   = 2
          unhealthy_threshold = 3
          request_path        = "/internal/health"
          port                = 8080
        }
      }
    }
  }

  # Monitoring and alerting configuration
  monitoring_config = {
    # Enable advanced monitoring
    enable_uptime_checks     = true
    enable_synthetic_monitoring = true
    enable_apm              = true
    enable_profiler         = true

    # Notification channels
    notification_channels = [
      {
        type         = "email"
        display_name = "Production Alerts - Primary"
        labels = {
          email_address = "alerts-primary@company.com"
        }
        enabled = true
      },
      {
        type         = "email"
        display_name = "Production Alerts - Secondary"
        labels = {
          email_address = "alerts-secondary@company.com"
        }
        enabled = true
      },
      {
        type         = "slack"
        display_name = "Production Slack Alerts"
        labels = {
          channel_name = "#production-alerts"
          url         = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
        }
        enabled = true
      },
      {
        type         = "pagerduty"
        display_name = "Production PagerDuty"
        labels = {
          service_key = "your-pagerduty-service-key"
        }
        enabled = true
      }
    ]

    # Alert policies
    alert_policies = [
      {
        display_name = "High Error Rate"
        conditions = [
          {
            display_name = "Error rate > 5%"
            condition_threshold = {
              filter          = "resource.type=\"gce_instance\""
              comparison      = "COMPARISON_GREATER_THAN"
              threshold_value = 0.05
              duration        = "300s"
            }
          }
        ]
        notification_channels = ["all"]
        alert_strategy = {
          auto_close = "1800s"
        }
      },
      {
        display_name = "High CPU Usage"
        conditions = [
          {
            display_name = "CPU > 85%"
            condition_threshold = {
              filter          = "resource.type=\"gce_instance\""
              comparison      = "COMPARISON_GREATER_THAN"
              threshold_value = 0.85
              duration        = "600s"
            }
          }
        ]
        notification_channels = ["primary", "slack"]
      },
      {
        display_name = "High Memory Usage"
        conditions = [
          {
            display_name = "Memory > 90%"
            condition_threshold = {
              filter          = "resource.type=\"gce_instance\""
              comparison      = "COMPARISON_GREATER_THAN"
              threshold_value = 0.90
              duration        = "300s"
            }
          }
        ]
        notification_channels = ["all"]
      },
      {
        display_name = "Database Connection Failures"
        conditions = [
          {
            display_name = "DB connection failures"
            condition_threshold = {
              filter          = "resource.type=\"cloudsql_database\""
              comparison      = "COMPARISON_GREATER_THAN"
              threshold_value = 10
              duration        = "300s"
            }
          }
        ]
        notification_channels = ["all"]
      },
      {
        display_name = "Load Balancer 5xx Errors"
        conditions = [
          {
            display_name = "LB 5xx errors > 50/min"
            condition_threshold = {
              filter          = "resource.type=\"https_lb_rule\""
              comparison      = "COMPARISON_GREATER_THAN"
              threshold_value = 50
              duration        = "300s"
            }
          }
        ]
        notification_channels = ["all"]
      }
    ]

    # SLO configuration
    service_level_objectives = [
      {
        display_name = "Application Availability"
        service_level_indicator = {
          request_based = {
            good_total_ratio = {
              total_service_filter = "resource.type=\"https_lb_rule\""
              good_service_filter  = "resource.type=\"https_lb_rule\" AND metric.labels.response_code!~\"5.*\""
            }
          }
        }
        goal = 0.999  # 99.9% availability
        rolling_period = "30d"
      },
      {
        display_name = "API Response Time"
        service_level_indicator = {
          request_based = {
            distribution_cut = {
              distribution_filter = "resource.type=\"https_lb_rule\""
              range = {
                max = 1000  # 1 second
              }
            }
          }
        }
        goal = 0.95  # 95% of requests under 1 second
        rolling_period = "7d"
      }
    ]

    # Custom dashboards
    dashboards = [
      {
        display_name = "Production Overview"
        grid_layout = {
          widgets = [
            {
              title = "Request Volume"
              xy_chart = {
                data_sets = [
                  {
                    time_series_query = {
                      time_series_filter = {
                        filter = "resource.type=\"https_lb_rule\""
                      }
                    }
                  }
                ]
              }
            },
            {
              title = "Error Rate"
              xy_chart = {
                data_sets = [
                  {
                    time_series_query = {
                      time_series_filter = {
                        filter = "resource.type=\"https_lb_rule\" AND metric.labels.response_code=~\"5.*\""
                      }
                    }
                  }
                ]
              }
            },
            {
              title = "Response Time"
              xy_chart = {
                data_sets = [
                  {
                    time_series_query = {
                      time_series_filter = {
                        filter = "resource.type=\"https_lb_rule\""
                      }
                    }
                  }
                ]
              }
            }
          ]
        }
      }
    ]
  }

  # Backup and disaster recovery configuration
  backup_config = {
    # Database backups
    database_backups = {
      schedule       = "0 2 * * *"  # Daily at 2 AM
      retention_days = 30
      backup_type    = "PHYSICAL"

      # Cross-region backup
      cross_region_backup = {
        enabled = true
        regions = [local.regions.secondary.name]
      }
    }

    # Instance snapshots
    instance_snapshots = {
      schedule       = "0 3 * * *"  # Daily at 3 AM
      retention_days = 14

      # Snapshot storage location
      storage_locations = [
        local.regions.primary.name,
        local.regions.secondary.name
      ]
    }

    # Application data backups
    application_data = {
      schedule       = "0 1 * * *"  # Daily at 1 AM
      retention_days = 90

      # Backup to multiple regions
      destinations = [
        "gs://prod-backups-primary/app-data",
        "gs://prod-backups-secondary/app-data"
      ]
    }

    # Configuration backups
    configuration_backup = {
      schedule       = "0 4 * * 0"  # Weekly on Sunday at 4 AM
      retention_weeks = 52

      # Include Terraform state, configurations, etc.
      backup_types = [
        "terraform_state",
        "kubernetes_configs",
        "application_configs",
        "ssl_certificates",
        "dns_records"
      ]
    }
  }

  # Compliance and security scanning
  compliance_config = {
    # Enable security scanning
    enable_vulnerability_scanning = true
    enable_config_scanning       = true
    enable_binary_scanning       = true

    # Compliance frameworks
    frameworks = [
      "SOC2",
      "PCI-DSS",
      "ISO27001",
      "GDPR"
    ]

    # Security policies
    security_policies = {
      require_mfa = true
      require_vpn = true

      password_policy = {
        min_length        = 12
        require_uppercase = true
        require_lowercase = true
        require_numbers   = true
        require_symbols   = true
      }

      access_review = {
        frequency = "quarterly"
        approvers = ["security-team@company.com"]
      }
    }
  }

  # Cost optimization
  cost_optimization = {
    # Reserved instances for predictable workloads
    committed_use_discounts = {
      enable = true
      term   = "1-year"
      type   = "memory-optimized"
    }

    # Preemptible instances for batch workloads
    preemptible_instances = {
      data_processing = {
        percentage = 70  # 70% preemptible for cost savings
      }
    }

    # Scheduled scaling
    scheduled_scaling = [
      {
        name     = "business-hours-scale-up"
        schedule = "0 8 * * 1-5"  # Scale up Mon-Fri at 8 AM
        min_size = 10
        max_size = 100
      },
      {
        name     = "off-hours-scale-down"
        schedule = "0 20 * * 1-5"  # Scale down Mon-Fri at 8 PM
        min_size = 6
        max_size = 20
      },
      {
        name     = "weekend-scale-down"
        schedule = "0 20 * * 6,0"  # Scale down weekends
        min_size = 3
        max_size = 10
      }
    ]

    # Resource tagging for cost allocation
    cost_allocation_tags = {
      cost_center   = "engineering"
      department    = "product"
      owner         = "platform-team"
      billing_code  = "PROD-2024"
    }
  }
}

# Generate random suffix for globally unique resources
resource "random_id" "bucket_suffix" {
  byte_length = 4
}