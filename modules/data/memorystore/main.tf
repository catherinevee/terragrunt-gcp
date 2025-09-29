# Memorystore Module
# Provides comprehensive Memorystore (Redis and Memcached) management with high availability and monitoring

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
  name_prefix = var.name_prefix != null ? var.name_prefix : "memorystore"
  environment = var.environment != null ? var.environment : "dev"

  # Common labels to apply to all resources
  default_labels = merge(var.labels, {
    module      = "memorystore"
    environment = local.environment
    managed_by  = "terraform"
  })

  # Redis instances configuration with defaults
  redis_instances = {
    for name, config in var.redis_instances : name => merge({
      tier                    = "STANDARD_HA"
      memory_size_gb          = 1
      redis_version           = "REDIS_6_X"
      display_name            = "${local.name_prefix}-${name}-${local.environment}"
      reserved_ip_range       = null
      connect_mode            = "DIRECT_PEERING"
      auth_enabled            = true
      transit_encryption_mode = "SERVER_AUTHENTICATION"
      persistence_config = {
        persistence_mode        = "RDB"
        rdb_snapshot_period     = "TWENTY_FOUR_HOURS"
        rdb_snapshot_start_time = "02:00"
      }
      maintenance_policy = {
        weekly_maintenance_window = [{
          day = "SUNDAY"
          start_time = {
            hours   = 3
            minutes = 0
            seconds = 0
            nanos   = 0
          }
          duration = "3600s"
        }]
      }
      redis_configs = {}
    }, config)
  }

  # Memcached instances configuration with defaults
  memcached_instances = {
    for name, config in var.memcached_instances : name => merge({
      node_count = 1
      node_config = [{
        cpu_count      = 1
        memory_size_mb = 1024
      }]
      memcache_version    = "MEMCACHE_1_5"
      display_name        = "${local.name_prefix}-${name}-${local.environment}"
      zones               = []
      memcache_parameters = {}
    }, config)
  }
}

# Data source for available zones
data "google_compute_zones" "available" {
  project = var.project_id
  region  = var.region
}

# Data source for network
data "google_compute_network" "vpc" {
  count = var.network_name != null ? 1 : 0

  project = var.project_id
  name    = var.network_name
}

# Data source for subnetwork
data "google_compute_subnetwork" "subnet" {
  count = var.subnetwork_name != null ? 1 : 0

  project = var.project_id
  region  = var.region
  name    = var.subnetwork_name
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "redis.googleapis.com",
    "memcache.googleapis.com",
    "servicenetworking.googleapis.com"
  ])

  project = var.project_id
  service = each.key

  disable_dependent_services = false
  disable_on_destroy         = false
}

# Service account for Memorystore operations
resource "google_service_account" "memorystore" {
  count = var.create_service_account ? 1 : 0

  project      = var.project_id
  account_id   = var.service_account_name != null ? var.service_account_name : "${local.name_prefix}-${local.environment}"
  display_name = "Memorystore Service Account for ${title(local.environment)}"
  description  = "Service account for Memorystore operations in ${local.environment} environment"
}

# IAM role bindings for service account
resource "google_project_iam_member" "memorystore_roles" {
  for_each = var.create_service_account && var.grant_service_account_roles ? toset(var.service_account_roles) : toset([])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.memorystore[0].email}"

  depends_on = [google_service_account.memorystore]
}

# Private service access for VPC peering
resource "google_compute_global_address" "private_ip_address" {
  count = var.enable_private_service_access ? 1 : 0

  project       = var.project_id
  name          = "${local.name_prefix}-private-ip-${local.environment}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.private_ip_prefix_length
  network       = var.network_name != null ? data.google_compute_network.vpc[0].id : null

  depends_on = [google_project_service.apis]
}

# VPC peering connection
resource "google_service_networking_connection" "private_vpc_connection" {
  count = var.enable_private_service_access ? 1 : 0

  network                 = var.network_name != null ? data.google_compute_network.vpc[0].id : null
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address[0].name]

  depends_on = [
    google_compute_global_address.private_ip_address,
    google_project_service.apis
  ]
}

# Redis instances
resource "google_redis_instance" "redis" {
  for_each = local.redis_instances

  project        = var.project_id
  region         = var.region
  name           = each.value.display_name
  tier           = each.value.tier
  memory_size_gb = each.value.memory_size_gb
  redis_version  = each.value.redis_version
  display_name   = each.value.display_name

  location_id             = var.location_id
  alternative_location_id = var.alternative_location_id
  reserved_ip_range       = each.value.reserved_ip_range
  connect_mode            = each.value.connect_mode
  auth_enabled            = each.value.auth_enabled
  transit_encryption_mode = each.value.transit_encryption_mode

  authorized_network = var.network_name != null ? data.google_compute_network.vpc[0].id : null

  dynamic "persistence_config" {
    for_each = each.value.persistence_config != null ? [1] : []
    content {
      persistence_mode        = each.value.persistence_config.persistence_mode
      rdb_snapshot_period     = each.value.persistence_config.rdb_snapshot_period
      rdb_snapshot_start_time = each.value.persistence_config.rdb_snapshot_start_time
    }
  }

  dynamic "maintenance_policy" {
    for_each = each.value.maintenance_policy != null ? [1] : []
    content {
      dynamic "weekly_maintenance_window" {
        for_each = each.value.maintenance_policy.weekly_maintenance_window
        content {
          day = weekly_maintenance_window.value.day
          start_time {
            hours   = weekly_maintenance_window.value.start_time.hours
            minutes = weekly_maintenance_window.value.start_time.minutes
            seconds = weekly_maintenance_window.value.start_time.seconds
            nanos   = weekly_maintenance_window.value.start_time.nanos
          }
          duration = weekly_maintenance_window.value.duration
        }
      }
    }
  }

  redis_configs = each.value.redis_configs
  labels        = merge(local.default_labels, each.value.labels != null ? each.value.labels : {})

  depends_on = [
    google_project_service.apis,
    google_service_networking_connection.private_vpc_connection
  ]
}

# Memcached instances
resource "google_memcache_instance" "memcached" {
  for_each = local.memcached_instances

  project          = var.project_id
  region           = var.region
  name             = each.value.display_name
  node_count       = each.value.node_count
  memcache_version = each.value.memcache_version
  display_name     = each.value.display_name

  authorized_network = var.network_name != null ? data.google_compute_network.vpc[0].id : null

  dynamic "node_config" {
    for_each = each.value.node_config
    content {
      cpu_count      = node_config.value.cpu_count
      memory_size_mb = node_config.value.memory_size_mb
    }
  }

  zones = length(each.value.zones) > 0 ? each.value.zones : data.google_compute_zones.available.names

  dynamic "memcache_parameters" {
    for_each = length(each.value.memcache_parameters) > 0 ? [1] : []
    content {
      params = each.value.memcache_parameters
    }
  }

  labels = merge(local.default_labels, each.value.labels != null ? each.value.labels : {})

  depends_on = [
    google_project_service.apis,
    google_service_networking_connection.private_vpc_connection
  ]
}

# Firewall rules for Memorystore access
resource "google_compute_firewall" "memorystore_access" {
  count = var.create_firewall_rules ? 1 : 0

  project = var.project_id
  name    = "${local.name_prefix}-allow-memorystore-${local.environment}"
  network = var.network_name

  description = "Allow access to Memorystore instances"

  allow {
    protocol = "tcp"
    ports    = ["6379", "11211"] # Redis and Memcached default ports
  }

  source_ranges = var.allowed_source_ranges
  target_tags   = var.firewall_target_tags

  depends_on = [google_project_service.apis]
}

# IAM bindings for Redis instances
resource "google_redis_instance_iam_member" "redis_iam" {
  for_each = var.redis_iam_bindings

  project  = var.project_id
  region   = var.region
  instance = google_redis_instance.redis[each.value.instance_name].name
  role     = each.value.role
  member   = each.value.member

  depends_on = [google_redis_instance.redis]
}

# Monitoring alert policies for Memorystore
resource "google_monitoring_alert_policy" "memorystore_alerts" {
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

  dynamic "notification_channels" {
    for_each = each.value.notification_channels != null ? [1] : []
    content {
      notification_channels = each.value.notification_channels
    }
  }

  auto_close = each.value.auto_close != null ? each.value.auto_close : "86400s"

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

# Monitoring dashboard for Memorystore
resource "google_monitoring_dashboard" "memorystore" {
  count = var.create_monitoring_dashboard ? 1 : 0

  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "Memorystore - ${title(local.environment)}"
    mosaicLayout = {
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Redis Memory Usage"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"redis_instance\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"redis.googleapis.com/stats/memory/usage_ratio\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_MEAN"
                      groupByFields      = ["resource.labels.instance_id"]
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
            title = "Redis Operations/sec"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"redis_instance\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"redis.googleapis.com/stats/operations_per_second\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.labels.instance_id"]
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
          yPos   = 4
          widget = {
            title = "Memcached Hit Rate"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"gce_instance\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"memcache.googleapis.com/memcache/hit_ratio\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_MEAN"
                      groupByFields      = ["resource.labels.instance_id"]
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
            title = "Network Bytes"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"redis_instance\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"redis.googleapis.com/stats/network_traffic\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.labels.direction"]
                      }
                    }
                  }
                  plotType = "STACKED_AREA"
                }
              ]
            }
          }
        }
      ]
    }
  })
}

# Log-based metrics for custom monitoring
resource "google_logging_metric" "memorystore_metrics" {
  for_each = var.create_log_metrics ? var.log_metrics : {}

  project = var.project_id
  name    = each.key
  filter  = each.value.filter

  dynamic "label_extractors" {
    for_each = each.value.label_extractors != null ? each.value.label_extractors : {}
    content {
      key   = label_extractors.key
      value = label_extractors.value
    }
  }

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

# Backup configurations for Redis (using Cloud Storage)
resource "google_storage_bucket" "redis_backups" {
  for_each = var.enable_redis_backups ? var.redis_backup_configs : {}

  project  = var.project_id
  name     = "${local.name_prefix}-${each.key}-backups-${local.environment}"
  location = each.value.backup_location

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = each.value.retention_days
    }
    action {
      type = "Delete"
    }
  }

  uniform_bucket_level_access = true

  labels = merge(local.default_labels, {
    purpose = "redis-backups"
  })
}

# Cloud Function for automated Redis backups (optional)
resource "google_cloudfunctions_function" "redis_backup" {
  for_each = var.enable_automated_backups ? var.backup_functions : {}

  project = var.project_id
  region  = var.region
  name    = "${local.name_prefix}-${each.key}-backup-${local.environment}"

  runtime               = each.value.runtime
  entry_point           = each.value.entry_point
  source_archive_bucket = each.value.source_bucket
  source_archive_object = each.value.source_object

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = each.value.trigger_topic
  }

  environment_variables = merge(
    each.value.environment_variables,
    {
      REDIS_INSTANCES = jsonencode([
        for name, instance in google_redis_instance.redis : {
          name = instance.name
          host = instance.host
          port = instance.port
        }
      ])
      BACKUP_BUCKET = var.enable_redis_backups && length(var.redis_backup_configs) > 0 ? google_storage_bucket.redis_backups[keys(var.redis_backup_configs)[0]].name : ""
      PROJECT_ID    = var.project_id
    }
  )

  available_memory_mb = each.value.memory_mb
  timeout             = each.value.timeout_seconds

  labels = merge(local.default_labels, each.value.labels != null ? each.value.labels : {})

  depends_on = [google_redis_instance.redis]
}