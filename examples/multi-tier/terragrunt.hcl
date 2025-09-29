# Multi-tier architecture example
# Demonstrates a complete 3-tier web application setup

include "root" {
  path = find_in_parent_folders()
}

# This is the root configuration for the multi-tier setup
# Individual tiers are configured in subdirectories

locals {
  # Common configuration
  environment = "staging"
  project     = "multi-tier-example"
  region      = "us-central1"

  # Application configuration
  app_name    = "webapp"
  app_version = "v1.0.0"

  # Common labels
  common_labels = {
    environment = local.environment
    project     = local.project
    managed_by  = "terragrunt"
    app_name    = local.app_name
    app_version = local.app_version
  }

  # Tier configuration
  tiers = {
    web = {
      name          = "web-tier"
      instance_type = "e2-medium"
      min_replicas  = 2
      max_replicas  = 10
      disk_size     = 20
      ports         = [80, 443]
    }

    app = {
      name          = "app-tier"
      instance_type = "e2-standard-2"
      min_replicas  = 3
      max_replicas  = 20
      disk_size     = 50
      ports         = [8080, 8443]
    }

    data = {
      name          = "data-tier"
      instance_type = "e2-standard-4"
      min_replicas  = 2
      max_replicas  = 5
      disk_size     = 100
      ports         = [3306, 5432]
    }
  }

  # Network configuration
  network_config = {
    vpc_cidr = "10.0.0.0/16"

    subnets = {
      web = {
        cidr    = "10.0.1.0/24"
        zone    = "us-central1-a"
        public  = true
      }
      app = {
        cidr    = "10.0.2.0/24"
        zone    = "us-central1-b"
        public  = false
      }
      data = {
        cidr    = "10.0.3.0/24"
        zone    = "us-central1-c"
        public  = false
      }
      management = {
        cidr    = "10.0.4.0/24"
        zone    = "us-central1-a"
        public  = true
      }
    }
  }

  # Security configuration
  security_config = {
    enable_os_login = true
    enable_shielded_vm = true
    enable_confidential_vm = false

    # Firewall rules
    firewall_rules = {
      web_public = {
        direction     = "INGRESS"
        priority     = 1000
        source_ranges = ["0.0.0.0/0"]
        target_tags   = ["web-tier"]
        ports        = ["80", "443"]
        protocol     = "tcp"
      }

      app_from_web = {
        direction     = "INGRESS"
        priority     = 1100
        source_tags   = ["web-tier"]
        target_tags   = ["app-tier"]
        ports        = ["8080", "8443"]
        protocol     = "tcp"
      }

      data_from_app = {
        direction     = "INGRESS"
        priority     = 1200
        source_tags   = ["app-tier"]
        target_tags   = ["data-tier"]
        ports        = ["3306", "5432"]
        protocol     = "tcp"
      }

      management_ssh = {
        direction     = "INGRESS"
        priority     = 1300
        source_ranges = ["0.0.0.0/0"]  # Restrict in production
        target_tags   = ["management"]
        ports        = ["22"]
        protocol     = "tcp"
      }

      health_checks = {
        direction     = "INGRESS"
        priority     = 1400
        source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
        target_tags   = ["web-tier", "app-tier"]
        ports        = ["80", "8080"]
        protocol     = "tcp"
      }
    }
  }

  # Load balancer configuration
  load_balancer_config = {
    web_lb = {
      type                = "EXTERNAL"
      load_balancing_scheme = "EXTERNAL"
      backend_service = {
        protocol                        = "HTTP"
        port                           = 80
        timeout_sec                    = 30
        connection_draining_timeout_sec = 300

        health_check = {
          type                = "HTTP"
          port                = 80
          request_path        = "/health"
          check_interval_sec  = 10
          timeout_sec         = 5
          healthy_threshold   = 2
          unhealthy_threshold = 3
        }
      }
    }

    app_lb = {
      type                = "INTERNAL"
      load_balancing_scheme = "INTERNAL"
      backend_service = {
        protocol                        = "HTTP"
        port                           = 8080
        timeout_sec                    = 30
        connection_draining_timeout_sec = 300

        health_check = {
          type                = "HTTP"
          port                = 8080
          request_path        = "/health"
          check_interval_sec  = 10
          timeout_sec         = 5
          healthy_threshold   = 2
          unhealthy_threshold = 3
        }
      }
    }
  }

  # Database configuration
  database_config = {
    mysql = {
      version       = "MYSQL_8_0"
      tier          = "db-n1-standard-2"
      disk_size     = 100
      disk_type     = "PD_SSD"
      backup_enabled = true
      backup_start_time = "03:00"

      database_flags = [
        {
          name  = "slow_query_log"
          value = "on"
        },
        {
          name  = "log_output"
          value = "FILE"
        }
      ]

      user_labels = merge(local.common_labels, {
        database_type = "mysql"
        tier         = "data"
      })
    }
  }

  # Monitoring configuration
  monitoring_config = {
    enable_uptime_checks = true
    enable_alerting     = true
    notification_channels = [
      {
        type         = "email"
        display_name = "DevOps Team"
        labels = {
          email_address = "devops@company.com"
        }
      }
    ]

    alert_policies = [
      {
        display_name = "High CPU Usage"
        conditions = [
          {
            display_name = "CPU > 80%"
            condition_threshold = {
              filter          = "resource.type=\"gce_instance\""
              comparison      = "COMPARISON_GREATER_THAN"
              threshold_value = 0.8
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
      }
    ]
  }

  # Backup configuration
  backup_config = {
    instance_snapshots = {
      schedule = "0 2 * * *"  # Daily at 2 AM
      retention_days = 7
    }

    database_backups = {
      schedule = "0 1 * * *"  # Daily at 1 AM
      retention_days = 30
    }

    application_data = {
      schedule = "0 3 * * *"  # Daily at 3 AM
      retention_days = 14
    }
  }
}