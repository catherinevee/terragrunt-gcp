# Main configuration for staging environment global resources
# This manages shared resources across all staging regions

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1"
    }
  }
}

# Provider configurations
provider "google" {
  project = var.project_id
  region  = var.default_region
}

provider "google-beta" {
  project = var.project_id
  region  = var.default_region
}

# Local variables for staging environment
locals {
  environment = "staging"

  common_labels = {
    environment   = local.environment
    managed_by    = "terraform"
    organization  = var.organization
    cost_center   = "engineering"
    business_unit = "platform"
  }

  # Network configuration
  network_name = "${var.project_id}-${local.environment}-vpc"

  # Staging-specific settings (reduced from production)
  resource_settings = {
    # Compute settings - use smaller instances
    default_machine_type = "e2-medium"
    preemptible_enabled  = true

    # Database settings - smaller configurations
    db_tier              = "db-g1-small"
    db_high_availability = false
    db_backup_enabled    = true
    db_backup_window     = "03:00"

    # Storage settings
    storage_class = "STANDARD"

    # Monitoring settings - less aggressive
    monitoring_interval = "60s"
    log_retention_days  = 30

    # Autoscaling settings - aggressive scaling
    min_replicas           = 1
    max_replicas           = 10
    target_cpu_utilization = 0.8
  }

  # Regional configuration
  regions = {
    primary   = var.default_region
    secondary = "us-east1" # Secondary region for staging
  }

  # Service accounts
  service_accounts = {
    compute    = "compute-staging-sa"
    storage    = "storage-staging-sa"
    network    = "network-staging-sa"
    monitoring = "monitoring-staging-sa"
    ci_cd      = "cicd-staging-sa"
  }
}

# Random suffix for unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

# Global IP Address for staging load balancer
resource "google_compute_global_address" "staging_lb" {
  project      = var.project_id
  name         = "${local.environment}-global-lb-ip"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
  labels       = local.common_labels
}

# Global Cloud Armor security policy
resource "google_compute_security_policy" "staging_default" {
  project = var.project_id
  name    = "${local.environment}-default-security-policy"

  description = "Default security policy for staging environment"

  # Default rule - allow all traffic initially
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow rule"
  }

  # Rate limiting rule for staging
  rule {
    action   = "rate_based_ban"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"

      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }

      ban_duration_sec = 600 # 10 minutes ban
    }
    description = "Rate limiting for staging environment"
  }

  # Block known malicious IPs
  rule {
    action   = "deny(403)"
    priority = 100
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = [
          "192.0.2.0/24",    # TEST-NET-1
          "198.51.100.0/24", # TEST-NET-2
          "203.0.113.0/24"   # TEST-NET-3
        ]
      }
    }
    description = "Block test networks"
  }

  # Adaptive protection for DDoS
  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable          = true
      rule_visibility = "STANDARD"
    }
  }
}

# Global SSL certificate for staging
resource "google_compute_managed_ssl_certificate" "staging" {
  project = var.project_id
  name    = "${local.environment}-ssl-cert"

  managed {
    domains = [var.staging_domain]
  }
}

# Service accounts for staging environment
resource "google_service_account" "staging_accounts" {
  for_each = local.service_accounts

  project      = var.project_id
  account_id   = each.value
  display_name = "Staging ${each.key} Service Account"
  description  = "Service account for ${each.key} services in staging environment"
}

# IAM bindings for service accounts
resource "google_project_iam_member" "compute_sa_permissions" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin"
  member  = "serviceAccount:${google_service_account.staging_accounts["compute"].email}"
}

resource "google_project_iam_member" "storage_sa_permissions" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.staging_accounts["storage"].email}"
}

resource "google_project_iam_member" "network_sa_permissions" {
  project = var.project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:${google_service_account.staging_accounts["network"].email}"
}

resource "google_project_iam_member" "monitoring_sa_permissions" {
  for_each = toset([
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.staging_accounts["monitoring"].email}"
}

# Global KMS keyring for staging
resource "google_kms_key_ring" "staging_global" {
  project  = var.project_id
  name     = "${local.environment}-global-keyring"
  location = "global"
}

# KMS keys for different purposes
resource "google_kms_crypto_key" "staging_keys" {
  for_each = toset([
    "storage-encryption",
    "database-encryption",
    "secret-encryption",
    "backup-encryption"
  ])

  name     = "${local.environment}-${each.value}-key"
  key_ring = google_kms_key_ring.staging_global.id

  rotation_period = "7776000s" # 90 days for staging

  lifecycle {
    prevent_destroy = false # Allow destruction in staging
  }

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "SOFTWARE"
  }

  labels = local.common_labels
}

# Artifact Registry for container images
resource "google_artifact_registry_repository" "staging_images" {
  project       = var.project_id
  location      = var.default_region
  repository_id = "${local.environment}-images"
  format        = "DOCKER"

  description = "Container images for staging environment"

  labels = local.common_labels

  cleanup_policies {
    id     = "keep-recent-versions"
    action = "KEEP"

    most_recent_versions {
      keep_count = 10
    }
  }

  cleanup_policies {
    id     = "delete-old-versions"
    action = "DELETE"

    condition {
      older_than = "2592000s" # 30 days
    }
  }
}

# Pub/Sub topics for staging event processing
resource "google_pubsub_topic" "staging_events" {
  for_each = toset([
    "deployments",
    "alerts",
    "audits",
    "backups",
    "scaling-events"
  ])

  project = var.project_id
  name    = "${local.environment}-${each.value}"

  message_retention_duration = "86400s" # 1 day for staging

  labels = local.common_labels
}

# Dead letter topic for failed messages
resource "google_pubsub_topic" "staging_dlq" {
  project = var.project_id
  name    = "${local.environment}-dead-letter-queue"

  message_retention_duration = "604800s" # 7 days

  labels = local.common_labels
}

# Staging monitoring notification channel
resource "google_monitoring_notification_channel" "staging_email" {
  project      = var.project_id
  display_name = "Staging Email Notifications"
  type         = "email"

  labels = {
    email_address = var.staging_notification_email
  }

  user_labels = local.common_labels
}

# Staging monitoring dashboard
resource "google_monitoring_dashboard" "staging_overview" {
  project = var.project_id

  dashboard_json = jsonencode({
    displayName = "Staging Environment Overview"

    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Resource Utilization"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" resource.type=\"gce_instance\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_MEAN"
                        groupByFields      = ["resource.zone"]
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                }
              ]
              yAxis = {
                label = "CPU Utilization"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          widget = {
            title = "Request Rate"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"loadbalancing.googleapis.com/https/request_count\" resource.type=\"https_lb_rule\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["resource.url_map_name"]
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                }
              ]
              yAxis = {
                label = "Requests/sec"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          yPos   = 4
          widget = {
            title = "Error Rate"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"logging.googleapis.com/user/error_count\" resource.type=\"global\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                }
              ]
              yAxis = {
                label = "Errors/sec"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          yPos   = 4
          widget = {
            title = "Storage Usage"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"storage.googleapis.com/storage/total_bytes\" resource.type=\"gcs_bucket\""
                      aggregation = {
                        alignmentPeriod    = "3600s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["resource.bucket_name"]
                      }
                    }
                  }
                  plotType   = "STACKED_AREA"
                  targetAxis = "Y1"
                }
              ]
              yAxis = {
                label = "Storage (bytes)"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 12
          height = 4
          yPos   = 8
          widget = {
            title = "Staging Environment Costs"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"billing.googleapis.com/project/cost\" resource.type=\"global\""
                      aggregation = {
                        alignmentPeriod    = "86400s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.service_name"]
                      }
                    }
                  }
                  plotType   = "STACKED_BAR"
                  targetAxis = "Y1"
                }
              ]
              yAxis = {
                label = "Cost (USD)"
                scale = "LINEAR"
              }
            }
          }
        }
      ]
    }
  })
}

# Budget alert for staging environment
resource "google_billing_budget" "staging_budget" {
  billing_account = var.billing_account
  display_name    = "Staging Environment Budget"

  budget_filter {
    projects               = ["projects/${var.project_id}"]
    credit_types_treatment = "INCLUDE_ALL_CREDITS"

    labels = {
      environment = local.environment
    }
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = "5000" # $5000 per month for staging
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }

  threshold_rules {
    threshold_percent = 0.75
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.9
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [
      google_monitoring_notification_channel.staging_email.id
    ]

    disable_default_iam_recipients = false
  }
}

# Outputs for other modules to reference
output "staging_service_accounts" {
  value = {
    for k, v in google_service_account.staging_accounts : k => v.email
  }
  description = "Map of service account emails for staging environment"
}

output "staging_kms_keys" {
  value = {
    for k, v in google_kms_crypto_key.staging_keys : k => v.id
  }
  description = "Map of KMS key IDs for staging environment"
}

output "staging_artifact_registry" {
  value       = google_artifact_registry_repository.staging_images.id
  description = "Artifact Registry repository ID for staging"
}

output "staging_global_ip" {
  value       = google_compute_global_address.staging_lb.address
  description = "Global IP address for staging load balancer"
}

output "staging_security_policy" {
  value       = google_compute_security_policy.staging_default.id
  description = "Default security policy ID for staging"
}

output "staging_ssl_certificate" {
  value       = google_compute_managed_ssl_certificate.staging.id
  description = "SSL certificate ID for staging"
}