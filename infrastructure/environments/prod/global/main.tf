# Main configuration for production environment global resources
# This manages shared resources across all production regions with enhanced security and reliability

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
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
  }
}

# Provider configurations with additional security
provider "google" {
  project = var.project_id
  region  = var.default_region

  request_timeout = "60s"

  batching {
    enable_batching = true
    send_after      = "10s"
  }
}

provider "google-beta" {
  project = var.project_id
  region  = var.default_region

  request_timeout = "60s"
}

# Local variables for production environment
locals {
  environment = "prod"

  common_labels = {
    environment   = local.environment
    managed_by    = "terraform"
    organization  = var.organization
    cost_center   = "operations"
    business_unit = "platform"
    criticality   = "critical"
    compliance    = "pci-dss"
    data_classification = "sensitive"
  }

  # Network configuration for production
  network_name = "${var.project_id}-${local.environment}-vpc"

  # Production settings - optimized for reliability and performance
  resource_settings = {
    # Compute settings - production grade instances
    default_machine_type = "n2-standard-4"
    preemptible_enabled  = false  # No preemptible in production

    # Database settings - high availability configurations
    db_tier = "db-n1-highmem-4"
    db_high_availability = true
    db_backup_enabled = true
    db_backup_window = "02:00"
    db_point_in_time_recovery = true
    db_backup_retention_days = 30

    # Storage settings
    storage_class = "MULTI_REGIONAL"
    storage_location = "US"

    # Monitoring settings - comprehensive monitoring
    monitoring_interval = "30s"
    log_retention_days = 365  # 1 year for compliance

    # Autoscaling settings - conservative scaling
    min_replicas = 3  # Minimum 3 for high availability
    max_replicas = 100
    target_cpu_utilization = 0.6
  }

  # Multi-region configuration for production
  regions = {
    primary   = "us-central1"
    secondary = "us-east1"
    tertiary  = "europe-west1"
    quaternary = "asia-southeast1"
  }

  # Service accounts for production
  service_accounts = {
    compute    = "compute-prod-sa"
    storage    = "storage-prod-sa"
    network    = "network-prod-sa"
    monitoring = "monitoring-prod-sa"
    security   = "security-prod-sa"
    backup     = "backup-prod-sa"
    disaster_recovery = "dr-prod-sa"
    audit      = "audit-prod-sa"
    ci_cd      = "cicd-prod-sa"
  }

  # Compliance and security tags
  security_tags = {
    pci_compliant = "true"
    sox_compliant = "true"
    gdpr_compliant = "true"
    hipaa_compliant = "false"
    encryption = "aes-256"
    audit_logging = "enabled"
  }
}

# Random suffix for globally unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

# Global IP Addresses for production load balancers with redundancy
resource "google_compute_global_address" "prod_lb_primary" {
  project      = var.project_id
  name         = "${local.environment}-global-lb-ip-primary"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
  labels       = local.common_labels
}

resource "google_compute_global_address" "prod_lb_secondary" {
  project      = var.project_id
  name         = "${local.environment}-global-lb-ip-secondary"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
  labels       = local.common_labels
}

# IPv6 support for future-proofing
resource "google_compute_global_address" "prod_lb_ipv6" {
  project      = var.project_id
  name         = "${local.environment}-global-lb-ip-ipv6"
  address_type = "EXTERNAL"
  ip_version   = "IPV6"
  labels       = local.common_labels
}

# Global Cloud Armor security policy with comprehensive rules
resource "google_compute_security_policy" "prod_comprehensive" {
  project = var.project_id
  name    = "${local.environment}-comprehensive-security-policy"

  description = "Comprehensive security policy for production environment"

  # Adaptive protection for DDoS with advanced configuration
  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = true
      rule_visibility = "PREMIUM"
    }
  }

  # Rate limiting rule - stricter for production
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
        count        = 500  # Higher limit for production
        interval_sec = 60
      }

      ban_duration_sec = 1800  # 30 minutes ban

      enforce_on_key = "IP"
    }
    description = "Rate limiting for production environment"
  }

  # Block known malicious IPs and regions
  rule {
    action   = "deny(403)"
    priority = 100
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.blocked_ip_ranges
      }
    }
    description = "Block known malicious IPs"
  }

  # Geo-blocking rule for restricted countries
  rule {
    action   = "deny(403)"
    priority = 200
    match {
      expr {
        expression = "origin.region_code in ['CN', 'RU', 'KP', 'IR']"
      }
    }
    description = "Geo-blocking for restricted regions"
  }

  # OWASP Top 10 protection rules
  rule {
    action   = "deny(403)"
    priority = 300
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-stable')"
      }
    }
    description = "SQL Injection protection"
  }

  rule {
    action   = "deny(403)"
    priority = 301
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-stable')"
      }
    }
    description = "XSS protection"
  }

  rule {
    action   = "deny(403)"
    priority = 302
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-stable')"
      }
    }
    description = "Local file inclusion protection"
  }

  rule {
    action   = "deny(403)"
    priority = 303
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-stable')"
      }
    }
    description = "Remote code execution protection"
  }

  rule {
    action   = "deny(403)"
    priority = 304
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rfi-stable')"
      }
    }
    description = "Remote file inclusion protection"
  }

  # Scanner and bot detection
  rule {
    action   = "deny(403)"
    priority = 400
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('scannerdetection-stable')"
      }
    }
    description = "Scanner and bot detection"
  }

  # Protocol attack protection
  rule {
    action   = "deny(403)"
    priority = 500
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('protocolattack-stable')"
      }
    }
    description = "Protocol attack protection"
  }

  # Default rule - allow legitimate traffic
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow rule for legitimate traffic"
  }
}

# Global SSL certificates for production with managed certificates
resource "google_compute_managed_ssl_certificate" "prod_primary" {
  project = var.project_id
  name    = "${local.environment}-ssl-cert-primary"

  managed {
    domains = [var.prod_domain, "www.${var.prod_domain}"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_managed_ssl_certificate" "prod_api" {
  project = var.project_id
  name    = "${local.environment}-ssl-cert-api"

  managed {
    domains = ["api.${var.prod_domain}"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_managed_ssl_certificate" "prod_admin" {
  project = var.project_id
  name    = "${local.environment}-ssl-cert-admin"

  managed {
    domains = ["admin.${var.prod_domain}"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Service accounts for production environment with granular permissions
resource "google_service_account" "prod_accounts" {
  for_each = local.service_accounts

  project      = var.project_id
  account_id   = each.value
  display_name = "Production ${each.key} Service Account"
  description  = "Service account for ${each.key} services in production environment"
}

# IAM bindings for service accounts with least privilege
resource "google_project_iam_member" "compute_sa_permissions" {
  for_each = toset([
    "roles/compute.instanceAdmin.v1",
    "roles/compute.loadBalancerAdmin",
    "roles/compute.securityAdmin"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.prod_accounts["compute"].email}"
}

resource "google_project_iam_member" "storage_sa_permissions" {
  for_each = toset([
    "roles/storage.admin",
    "roles/storage.objectAdmin"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.prod_accounts["storage"].email}"
}

resource "google_project_iam_member" "network_sa_permissions" {
  project = var.project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:${google_service_account.prod_accounts["network"].email}"
}

resource "google_project_iam_member" "monitoring_sa_permissions" {
  for_each = toset([
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
    "roles/cloudtrace.agent",
    "roles/cloudprofiler.agent",
    "roles/errorreporting.writer"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.prod_accounts["monitoring"].email}"
}

resource "google_project_iam_member" "security_sa_permissions" {
  for_each = toset([
    "roles/cloudkms.admin",
    "roles/secretmanager.admin",
    "roles/iam.securityAdmin"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.prod_accounts["security"].email}"
}

resource "google_project_iam_member" "backup_sa_permissions" {
  for_each = toset([
    "roles/storage.admin",
    "roles/compute.storageAdmin",
    "roles/cloudsql.admin"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.prod_accounts["backup"].email}"
}

resource "google_project_iam_member" "audit_sa_permissions" {
  for_each = toset([
    "roles/logging.viewer",
    "roles/monitoring.viewer",
    "roles/iam.securityReviewer"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.prod_accounts["audit"].email}"
}

# Global KMS keyrings for production with HSM protection
resource "google_kms_key_ring" "prod_global" {
  project  = var.project_id
  name     = "${local.environment}-global-keyring"
  location = "global"
}

resource "google_kms_key_ring" "prod_multiregion" {
  project  = var.project_id
  name     = "${local.environment}-us-keyring"
  location = "us"
}

# KMS keys for different purposes with rotation
resource "google_kms_crypto_key" "prod_keys" {
  for_each = toset([
    "storage-encryption",
    "database-encryption",
    "secret-encryption",
    "backup-encryption",
    "application-encryption",
    "communication-encryption"
  ])

  name     = "${local.environment}-${each.value}-key"
  key_ring = google_kms_key_ring.prod_multiregion.id

  rotation_period = "2592000s"  # 30 days for production

  lifecycle {
    prevent_destroy = true  # Prevent accidental deletion in production
  }

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "HSM"  # Hardware security module for production
  }

  labels = merge(local.common_labels, {
    purpose = each.value
  })
}

# Artifact Registry for container images with vulnerability scanning
resource "google_artifact_registry_repository" "prod_images" {
  project       = var.project_id
  location      = "us"  # Multi-region
  repository_id = "${local.environment}-images"
  format        = "DOCKER"

  description = "Production container images repository"

  labels = local.common_labels

  cleanup_policies {
    id     = "keep-production-versions"
    action = "KEEP"

    most_recent_versions {
      keep_count = 50  # Keep more versions in production
    }
  }

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"

    condition {
      tag_state = "UNTAGGED"
      older_than = "604800s"  # 7 days
    }
  }

  cleanup_policies {
    id     = "keep-tagged-releases"
    action = "KEEP"

    condition {
      tag_prefixes = ["v", "release", "prod"]
    }
  }
}

# Pub/Sub topics for production event processing
resource "google_pubsub_topic" "prod_events" {
  for_each = toset([
    "deployments",
    "alerts-critical",
    "alerts-warning",
    "audits",
    "backups",
    "scaling-events",
    "security-events",
    "compliance-events",
    "disaster-recovery"
  ])

  project = var.project_id
  name    = "${local.environment}-${each.value}"

  message_retention_duration = "604800s"  # 7 days for production

  message_storage_policy {
    allowed_persistence_regions = ["us-central1", "us-east1"]  # Multi-region
  }

  labels = local.common_labels
}

# Dead letter topics with extended retention
resource "google_pubsub_topic" "prod_dlq" {
  project = var.project_id
  name    = "${local.environment}-dead-letter-queue"

  message_retention_duration = "2678400s"  # 31 days

  message_storage_policy {
    allowed_persistence_regions = ["us-central1", "us-east1"]
  }

  labels = local.common_labels
}

# Production monitoring notification channels
resource "google_monitoring_notification_channel" "prod_email_critical" {
  project      = var.project_id
  display_name = "Production Critical Alerts Email"
  type         = "email"

  labels = {
    email_address = var.prod_critical_email
  }

  user_labels = merge(local.common_labels, {
    severity = "critical"
  })
}

resource "google_monitoring_notification_channel" "prod_email_warning" {
  project      = var.project_id
  display_name = "Production Warning Alerts Email"
  type         = "email"

  labels = {
    email_address = var.prod_warning_email
  }

  user_labels = merge(local.common_labels, {
    severity = "warning"
  })
}

resource "google_monitoring_notification_channel" "prod_pagerduty" {
  project      = var.project_id
  display_name = "Production PagerDuty Integration"
  type         = "pagerduty"

  labels = {
    service_key = var.pagerduty_service_key
  }

  user_labels = merge(local.common_labels, {
    severity = "critical"
  })

  sensitive_labels {
    auth_token = var.pagerduty_auth_token
  }
}

resource "google_monitoring_notification_channel" "prod_slack_critical" {
  project      = var.project_id
  display_name = "Production Slack Critical"
  type         = "slack"

  labels = {
    channel_name = "#prod-alerts-critical"
    url          = var.slack_webhook_critical
  }

  user_labels = merge(local.common_labels, {
    severity = "critical"
  })
}

resource "google_monitoring_notification_channel" "prod_sms" {
  count = length(var.sms_numbers) > 0 ? length(var.sms_numbers) : 0

  project      = var.project_id
  display_name = "Production SMS Alert ${count.index + 1}"
  type         = "sms"

  labels = {
    number = var.sms_numbers[count.index]
  }

  user_labels = merge(local.common_labels, {
    severity = "critical"
  })
}

# Production monitoring dashboard with comprehensive metrics
resource "google_monitoring_dashboard" "prod_executive" {
  project = var.project_id

  dashboard_json = jsonencode({
    displayName = "Production Executive Dashboard"

    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 4
          height = 4
          widget = {
            title = "System Health Score"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"custom.googleapis.com/health/score\" resource.type=\"global\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_MEAN"
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_LINE"
              }
              thresholds = [
                {
                  value = 95
                  color = "GREEN"
                },
                {
                  value = 90
                  color = "YELLOW"
                },
                {
                  value = 0
                  color = "RED"
                }
              ]
            }
          }
        },
        {
          width  = 4
          height = 4
          xPos   = 4
          widget = {
            title = "Global Request Rate"
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
                        groupByFields      = ["resource.region"]
                      }
                    }
                  }
                  plotType = "STACKED_AREA"
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
          width  = 4
          height = 4
          xPos   = 8
          widget = {
            title = "Error Rate"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"loadbalancing.googleapis.com/https/request_count\" resource.type=\"https_lb_rule\" metric.label.\"response_code_class\"=\"5xx\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                      }
                    }
                  }
                  plotType = "LINE"
                  targetAxis = "Y1"
                }
              ]
              yAxis = {
                label = "Errors/sec"
                scale = "LINEAR"
              }
              thresholds = [
                {
                  value = 10
                  direction = "ABOVE"
                  color = "RED"
                }
              ]
            }
          }
        },
        {
          width  = 6
          height = 4
          yPos   = 4
          widget = {
            title = "Latency Percentiles"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"loadbalancing.googleapis.com/https/backend_latencies\" resource.type=\"https_lb_rule\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_DELTA"
                        crossSeriesReducer = "REDUCE_PERCENTILE_50"
                      }
                    }
                  }
                  plotType = "LINE"
                  legendTemplate = "P50"
                },
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"loadbalancing.googleapis.com/https/backend_latencies\" resource.type=\"https_lb_rule\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_DELTA"
                        crossSeriesReducer = "REDUCE_PERCENTILE_95"
                      }
                    }
                  }
                  plotType = "LINE"
                  legendTemplate = "P95"
                },
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"loadbalancing.googleapis.com/https/backend_latencies\" resource.type=\"https_lb_rule\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_DELTA"
                        crossSeriesReducer = "REDUCE_PERCENTILE_99"
                      }
                    }
                  }
                  plotType = "LINE"
                  legendTemplate = "P99"
                }
              ]
              yAxis = {
                label = "Latency (ms)"
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
            title = "Infrastructure Costs"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"billing.googleapis.com/project/cost\" resource.type=\"global\""
                      aggregation = {
                        alignmentPeriod    = "3600s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.service_name"]
                      }
                    }
                  }
                  plotType = "STACKED_BAR"
                }
              ]
              yAxis = {
                label = "Cost (USD)"
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
            title = "Global Resource Utilization"
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
                  plotType = "HEATMAP"
                }
              ]
            }
          }
        }
      ]
    }
  })
}

# Budget alerts for production with multiple thresholds
resource "google_billing_budget" "prod_budget" {
  billing_account = var.billing_account
  display_name    = "Production Environment Budget"

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
      units        = tostring(var.prod_budget_amount)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }

  threshold_rules {
    threshold_percent = 0.75
    spend_basis      = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.9
    spend_basis      = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.95
    spend_basis      = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis      = "FORECASTED_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.1
    spend_basis      = "CURRENT_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [
      google_monitoring_notification_channel.prod_email_critical.id,
      google_monitoring_notification_channel.prod_pagerduty.id,
      google_monitoring_notification_channel.prod_slack_critical.id
    ]

    disable_default_iam_recipients = false

    pubsub_topic = google_pubsub_topic.prod_events["alerts-critical"].id
  }
}

# Outputs for other modules
output "prod_service_accounts" {
  value = {
    for k, v in google_service_account.prod_accounts : k => v.email
  }
  description = "Map of service account emails for production"
}

output "prod_kms_keys" {
  value = {
    for k, v in google_kms_crypto_key.prod_keys : k => v.id
  }
  description = "Map of KMS key IDs for production"
}

output "prod_artifact_registry" {
  value = google_artifact_registry_repository.prod_images.id
  description = "Artifact Registry repository ID for production"
}

output "prod_global_ips" {
  value = {
    primary   = google_compute_global_address.prod_lb_primary.address
    secondary = google_compute_global_address.prod_lb_secondary.address
    ipv6      = google_compute_global_address.prod_lb_ipv6.address
  }
  description = "Global IP addresses for production"
}

output "prod_security_policy" {
  value = google_compute_security_policy.prod_comprehensive.id
  description = "Comprehensive security policy ID for production"
}

output "prod_ssl_certificates" {
  value = {
    primary = google_compute_managed_ssl_certificate.prod_primary.id
    api     = google_compute_managed_ssl_certificate.prod_api.id
    admin   = google_compute_managed_ssl_certificate.prod_admin.id
  }
  description = "SSL certificate IDs for production"
}

output "prod_notification_channels" {
  value = {
    email_critical = google_monitoring_notification_channel.prod_email_critical.id
    email_warning  = google_monitoring_notification_channel.prod_email_warning.id
    pagerduty      = google_monitoring_notification_channel.prod_pagerduty.id
    slack_critical = google_monitoring_notification_channel.prod_slack_critical.id
  }
  description = "Notification channel IDs for production"
}