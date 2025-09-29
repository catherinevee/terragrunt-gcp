# Cloud Composer Module
# Provides comprehensive Cloud Composer (Apache Airflow) environment management

terraform {
  required_version = ">= 1.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.0"
    }
  }
}

# Local values for resource naming and configuration
locals {
  name_prefix = var.name_prefix != null ? var.name_prefix : "composer"
  environment = var.environment != null ? var.environment : "dev"

  # Common labels to apply to all resources
  default_labels = merge(var.labels, {
    module      = "cloud-composer"
    environment = local.environment
    managed_by  = "terraform"
  })

  # Environment configuration with defaults
  environment_config = merge({
    name         = "${local.name_prefix}-${local.environment}"
    node_count   = 3
    machine_type = "n1-standard-1"
    disk_size_gb = 100

    # Composer 2 configuration
    composer_version = "composer-2-airflow-2"
    python_version   = "3"

    # Airflow configuration
    airflow_config_overrides = {}
    pypi_packages            = {}
    env_variables            = {}

    # Network configuration
    enable_private_ip_google_access = true
    enable_ip_alias                 = true

    # Security configuration
    enable_private_endpoint = true
    master_ipv4_cidr_block  = "172.16.0.0/28"

    # Web server configuration
    web_server_access_control = {
      allowed_ip_ranges = [{
        value       = "0.0.0.0/0"
        description = "Allow all IPs"
      }]
    }

    # Database configuration
    database_machine_type = "db-n1-standard-2"

    # Web server configuration
    web_server_machine_type = "composer-n1-webserver-2"
  }, var.environment_config)

  # Software configuration with defaults
  software_config = merge({
    image_version  = "composer-2-airflow-2"
    python_version = "3"
    scheduler = {
      cpu     = 0.5
      memory  = 1.875
      storage = 1
      count   = 1
    }
    web_server = {
      cpu     = 0.5
      memory  = 1.875
      storage = 1
    }
    worker = {
      cpu       = 0.5
      memory    = 1.875
      storage   = 1
      min_count = 1
      max_count = 3
    }
  }, var.software_config)

  # Node configuration with defaults
  node_config = merge({
    zone         = var.zone
    machine_type = "n1-standard-1"
    disk_size_gb = 100
    disk_type    = "pd-standard"

    # Network configuration
    network    = var.network_name
    subnetwork = var.subnetwork_name

    # Service account
    service_account = var.node_service_account

    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Tags
    tags = ["composer-worker"]

    # Enable IP alias
    enable_ip_alias = true

    # Maximum pods per node
    max_pods_per_node = 110
  }, var.node_config)

  # Private cluster configuration
  private_cluster_config = merge({
    enable_private_nodes    = true
    master_ipv4_cidr_block  = "172.16.0.0/28"
    enable_private_endpoint = true
  }, var.private_cluster_config)

  # Web server network access control
  web_server_network_access_control = var.web_server_network_access_control != null ? var.web_server_network_access_control : {
    allowed_ip_ranges = [{
      value       = "0.0.0.0/0"
      description = "Allow all IPs (consider restricting in production)"
    }]
  }

  # Database configuration
  database_config = merge({
    machine_type = "db-n1-standard-2"
    zone         = var.zone
  }, var.database_config)

  # Web server configuration
  web_server_config = merge({
    machine_type = "composer-n1-webserver-2"
  }, var.web_server_config)

  # Encryption configuration
  encryption_config = var.encryption_config != null ? var.encryption_config : {}
}

# Data sources
data "google_project" "current" {
  project_id = var.project_id
}

data "google_compute_zones" "available" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "composer.googleapis.com",
    "container.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com"
  ])

  project = var.project_id
  service = each.key

  disable_dependent_services = false
  disable_on_destroy         = false
}

# Service account for Composer environment
resource "google_service_account" "composer" {
  count = var.create_service_account ? 1 : 0

  project      = var.project_id
  account_id   = var.service_account_name != null ? var.service_account_name : "${local.name_prefix}-${local.environment}"
  display_name = "Cloud Composer Service Account for ${title(local.environment)}"
  description  = "Service account for Cloud Composer environment in ${local.environment}"
}

# IAM role bindings for service account
resource "google_project_iam_member" "composer_roles" {
  for_each = var.create_service_account && var.grant_service_account_roles ? toset(var.service_account_roles) : toset([])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.composer[0].email}"

  depends_on = [google_service_account.composer]
}

# Cloud Storage bucket for DAGs and other files
resource "google_storage_bucket" "composer_bucket" {
  count = var.create_composer_bucket ? 1 : 0

  project  = var.project_id
  name     = "${local.name_prefix}-${local.environment}-${random_id.bucket_suffix.hex}"
  location = var.region

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = var.bucket_lifecycle_age_days
    }
    action {
      type = "Delete"
    }
  }

  uniform_bucket_level_access = true

  labels = merge(local.default_labels, {
    purpose = "composer-storage"
  })
}

# Random ID for bucket suffix
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Cloud Composer Environment
resource "google_composer_environment" "composer" {
  provider = google-beta

  project = var.project_id
  region  = var.region
  name    = local.environment_config.name

  labels = local.default_labels

  config {
    # Node configuration
    node_config {
      zone         = local.node_config.zone
      machine_type = local.node_config.machine_type
      disk_size_gb = local.node_config.disk_size_gb
      # disk_type is not supported in current provider version
      # disk_type    = local.node_config.disk_type

      network    = local.node_config.network
      subnetwork = local.node_config.subnetwork

      service_account = var.create_service_account ? google_service_account.composer[0].email : local.node_config.service_account
      oauth_scopes    = local.node_config.oauth_scopes
      tags            = local.node_config.tags

      # enable_ip_alias is not supported in current provider version
      # enable_ip_alias   = local.node_config.enable_ip_alias
      max_pods_per_node = local.node_config.max_pods_per_node
    }

    # Software configuration
    software_config {
      image_version  = local.software_config.image_version
      python_version = local.software_config.python_version

      airflow_config_overrides = merge(
        local.environment_config.airflow_config_overrides,
        var.airflow_config_overrides
      )

      pypi_packages = merge(
        local.environment_config.pypi_packages,
        var.pypi_packages
      )

      env_variables = merge(
        local.environment_config.env_variables,
        var.env_variables
      )

      # scheduler_count should be set directly, not as a dynamic block
      scheduler_count = try(local.software_config.scheduler.count, 1)

      dynamic "cloud_data_lineage_integration" {
        for_each = var.enable_cloud_data_lineage ? [1] : []
        content {
          enabled = true
        }
      }
    }

    # Private cluster configuration
    dynamic "private_environment_config" {
      for_each = var.enable_private_environment ? [1] : []
      content {
        enable_private_endpoint                = local.private_cluster_config.enable_private_endpoint
        master_ipv4_cidr_block                 = local.private_cluster_config.master_ipv4_cidr_block
        cloud_sql_ipv4_cidr_block              = var.cloud_sql_ipv4_cidr_block
        cloud_composer_network_ipv4_cidr_block = var.composer_network_ipv4_cidr_block
        enable_privately_used_public_ips       = var.enable_privately_used_public_ips
        cloud_composer_connection_subnetwork   = var.composer_connection_subnetwork

        # web_server_network_access_control is not supported in current configuration
        # Removed due to provider compatibility issues
      }
    }

    # Database configuration
    dynamic "database_config" {
      for_each = var.enable_database_config ? [1] : []
      content {
        machine_type = local.database_config.machine_type
        zone         = local.database_config.zone
      }
    }

    # Web server configuration
    dynamic "web_server_config" {
      for_each = var.enable_web_server_config ? [1] : []
      content {
        machine_type = local.web_server_config.machine_type
      }
    }

    # Encryption configuration
    dynamic "encryption_config" {
      for_each = length(local.encryption_config) > 0 ? [1] : []
      content {
        kms_key_name = local.encryption_config.kms_key_name
      }
    }

    # Environment size (Composer 2)
    # environment_size is set directly as an argument
    environment_size = var.environment_size

    # Workloads configuration (Composer 2)
    dynamic "workloads_config" {
      for_each = var.enable_workloads_config ? [1] : []
      content {
        dynamic "scheduler" {
          for_each = local.software_config.scheduler != null ? [1] : []
          content {
            cpu        = local.software_config.scheduler.cpu
            memory_gb  = local.software_config.scheduler.memory
            storage_gb = local.software_config.scheduler.storage
            count      = local.software_config.scheduler.count
          }
        }

        dynamic "web_server" {
          for_each = local.software_config.web_server != null ? [1] : []
          content {
            cpu        = local.software_config.web_server.cpu
            memory_gb  = local.software_config.web_server.memory
            storage_gb = local.software_config.web_server.storage
          }
        }

        dynamic "worker" {
          for_each = local.software_config.worker != null ? [1] : []
          content {
            cpu        = local.software_config.worker.cpu
            memory_gb  = local.software_config.worker.memory
            storage_gb = local.software_config.worker.storage
            min_count  = local.software_config.worker.min_count
            max_count  = local.software_config.worker.max_count
          }
        }
      }
    }

    # Maintenance window
    dynamic "maintenance_window" {
      for_each = var.maintenance_window != null ? [1] : []
      content {
        start_time = var.maintenance_window.start_time
        end_time   = var.maintenance_window.end_time
        recurrence = var.maintenance_window.recurrence
      }
    }
  }

  depends_on = [
    google_project_service.apis,
    google_service_account.composer
  ]

  timeouts {
    create = var.create_timeout
    update = var.update_timeout
    delete = var.delete_timeout
  }
}

# IAM bindings for Composer environment
# Note: google_composer_environment_iam_member is not available in current provider
# Use google_project_iam_member instead for environment-level permissions
resource "google_project_iam_member" "environment_iam" {
  for_each = var.environment_iam_bindings

  project = var.project_id
  role    = each.value.role
  member  = each.value.member

  depends_on = [google_composer_environment.composer]
}

# Cloud Storage bucket IAM for DAGs bucket (if using external bucket)
resource "google_storage_bucket_iam_member" "dags_bucket_iam" {
  for_each = var.dags_bucket_iam_bindings

  bucket = each.value.bucket_name
  role   = each.value.role
  member = each.value.member
}

# Monitoring alert policies for Composer
resource "google_monitoring_alert_policy" "composer_alerts" {
  for_each = var.create_monitoring_alerts ? var.monitoring_alerts : {}

  project      = var.project_id
  display_name = each.value.display_name
  enabled      = each.value.enabled != null ? each.value.enabled : true
  combiner     = each.value.combiner != null ? each.value.combiner : "OR"

  conditions {
    display_name = each.value.condition_display_name

    condition_threshold {
      filter          = each.value.filter
      duration        = each.value.duration != null ? each.value.duration : "300s"
      comparison      = each.value.comparison != null ? each.value.comparison : "COMPARISON_GREATER_THAN"
      threshold_value = each.value.threshold_value

      aggregations {
        alignment_period     = each.value.alignment_period != null ? each.value.alignment_period : "300s"
        per_series_aligner   = each.value.per_series_aligner != null ? each.value.per_series_aligner : "ALIGN_RATE"
        cross_series_reducer = each.value.cross_series_reducer != null ? each.value.cross_series_reducer : "REDUCE_MEAN"
        group_by_fields      = each.value.group_by_fields
      }

      dynamic "trigger" {
        for_each = each.value.trigger_count != null || each.value.trigger_percent != null ? [1] : []
        content {
          count   = each.value.trigger_count
          percent = each.value.trigger_percent
        }
      }
    }
  }

  # notification_channels is a list argument, not a block
  notification_channels = try(each.value.notification_channels, [])

  # auto_close is not a valid argument, use alert_strategy instead

  dynamic "alert_strategy" {
    for_each = each.value.rate_limit != null ? [1] : []
    content {
      notification_rate_limit {
        period = each.value.rate_limit.period
      }
    }
  }

  dynamic "documentation" {
    for_each = each.value.documentation_content != null ? [1] : []
    content {
      content   = each.value.documentation_content
      mime_type = each.value.documentation_mime_type != null ? each.value.documentation_mime_type : "text/markdown"
      subject   = each.value.documentation_subject
    }
  }

  user_labels = merge(local.default_labels, each.value.labels != null ? each.value.labels : {})
}

# Monitoring dashboard for Composer
resource "google_monitoring_dashboard" "composer" {
  count = var.create_monitoring_dashboard ? 1 : 0

  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "Cloud Composer - ${title(local.environment)}"
    mosaicLayout = {
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "DAG Run Success Rate"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"gce_instance\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"composer.googleapis.com/environment/dag_run/success_count\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.labels.environment_name"]
                    }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          widget = {
            title = "Task Instance Counts"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"gce_instance\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"composer.googleapis.com/environment/task_run/count\""
                    aggregation = {
                      alignmentPeriod    = "300s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.labels.state"]
                    }
                  }
                }
                plotType = "STACKED_AREA"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          yPos   = 4
          widget = {
            title = "Environment Health"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"gce_instance\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"composer.googleapis.com/environment/healthy\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_MEAN"
                    }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          yPos   = 4
          widget = {
            title = "Worker Node CPU Usage"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"gke_container\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"kubernetes.io/container/cpu/core_usage_time\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_MEAN"
                      groupByFields      = ["resource.labels.pod_name"]
                    }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        }
      ]
    }
  })
}

# Log-based metrics for custom monitoring
resource "google_logging_metric" "composer_metrics" {
  for_each = var.create_log_metrics ? var.log_metrics : {}

  project = var.project_id
  name    = each.key
  filter  = each.value.filter

  # label_extractors is a map argument, not a block
  label_extractors = try(each.value.label_extractors, {})

  dynamic "metric_descriptor" {
    for_each = each.value.metric_descriptor != null ? [1] : []
    content {
      metric_kind  = each.value.metric_descriptor.metric_kind
      value_type   = each.value.metric_descriptor.value_type
      unit         = each.value.metric_descriptor.unit
      display_name = each.value.metric_descriptor.display_name

      dynamic "labels" {
        for_each = each.value.metric_descriptor.labels != null ? each.value.metric_descriptor.labels : []
        content {
          key         = labels.value.key
          value_type  = labels.value.value_type
          description = labels.value.description
        }
      }
    }
  }

  dynamic "bucket_options" {
    for_each = each.value.bucket_options != null ? [1] : []
    content {
      dynamic "linear_buckets" {
        for_each = each.value.bucket_options.linear_buckets != null ? [1] : []
        content {
          num_finite_buckets = each.value.bucket_options.linear_buckets.num_finite_buckets
          width              = each.value.bucket_options.linear_buckets.width
          offset             = each.value.bucket_options.linear_buckets.offset
        }
      }

      dynamic "exponential_buckets" {
        for_each = each.value.bucket_options.exponential_buckets != null ? [1] : []
        content {
          num_finite_buckets = each.value.bucket_options.exponential_buckets.num_finite_buckets
          growth_factor      = each.value.bucket_options.exponential_buckets.growth_factor
          scale              = each.value.bucket_options.exponential_buckets.scale
        }
      }
    }
  }
}