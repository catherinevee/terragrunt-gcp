# Certificate Manager Module - Main Configuration
# Manages SSL/TLS certificates, certificate maps, and DNS authorizations

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

# Local variables
locals {
  environment = var.environment != null ? var.environment : "dev"
  name_prefix = var.name_prefix != null ? var.name_prefix : "cert-manager"

  default_labels = merge(
    {
      environment = local.environment
      managed_by  = "terraform"
      module      = "certificate-manager"
      created_at  = formatdate("YYYY-MM-DD", timestamp())
    },
    var.labels
  )

  # Certificate configurations
  certificates = {
    for k, v in var.certificates : k => merge(
      v,
      {
        name        = v.name != null ? v.name : "${local.name_prefix}-${k}-cert"
        description = v.description != null ? v.description : "Certificate for ${k}"
      }
    )
  }

  # Certificate map configurations
  certificate_maps = {
    for k, v in var.certificate_maps : k => merge(
      v,
      {
        name        = v.name != null ? v.name : "${local.name_prefix}-${k}-map"
        description = v.description != null ? v.description : "Certificate map for ${k}"
      }
    )
  }

  # Certificate map entries configurations
  certificate_map_entries = {
    for k, v in var.certificate_map_entries : k => merge(
      v,
      {
        name        = v.name != null ? v.name : "${local.name_prefix}-${k}-entry"
        description = v.description != null ? v.description : "Certificate map entry for ${k}"
      }
    )
  }

  # DNS authorization configurations
  dns_authorizations = {
    for k, v in var.dns_authorizations : k => merge(
      v,
      {
        name        = v.name != null ? v.name : "${local.name_prefix}-${k}-dns-auth"
        description = v.description != null ? v.description : "DNS authorization for ${k}"
      }
    )
  }

  # Certificate issuance configs
  certificate_issuance_configs = {
    for k, v in var.certificate_issuance_configs : k => merge(
      v,
      {
        name        = v.name != null ? v.name : "${local.name_prefix}-${k}-issuance"
        description = v.description != null ? v.description : "Certificate issuance config for ${k}"
      }
    )
  }

  # Trust configs
  trust_configs = {
    for k, v in var.trust_configs : k => merge(
      v,
      {
        name        = v.name != null ? v.name : "${local.name_prefix}-${k}-trust"
        description = v.description != null ? v.description : "Trust config for ${k}"
      }
    )
  }
}

# Enable required APIs
resource "google_project_service" "certificate_manager_api" {
  project = var.project_id
  service = "certificatemanager.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "compute_api" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

# Service Account for Certificate Manager
resource "google_service_account" "cert_manager" {
  count = var.create_service_account ? 1 : 0

  account_id   = var.service_account_name != null ? var.service_account_name : "${local.name_prefix}-sa"
  display_name = "Certificate Manager Service Account"
  description  = "Service account for Certificate Manager operations"
  project      = var.project_id
}

# IAM roles for service account
resource "google_project_iam_member" "cert_manager_roles" {
  for_each = var.create_service_account && var.grant_service_account_roles ? toset(var.service_account_roles) : []

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cert_manager[0].email}"

  depends_on = [google_service_account.cert_manager]
}

# DNS Authorizations
resource "google_certificate_manager_dns_authorization" "dns_authorizations" {
  for_each = local.dns_authorizations

  name        = each.value.name
  description = each.value.description
  domain      = each.value.domain
  location    = each.value.location != null ? each.value.location : "global"
  project     = var.project_id

  labels = merge(
    local.default_labels,
    each.value.labels != null ? each.value.labels : {}
  )

  depends_on = [google_project_service.certificate_manager_api]
}

# Certificate Issuance Configs
resource "google_certificate_manager_certificate_issuance_config" "issuance_configs" {
  for_each = local.certificate_issuance_configs
  provider = google-beta

  name        = each.value.name
  description = each.value.description
  location    = each.value.location != null ? each.value.location : "global"
  project     = var.project_id

  rotation_window_percentage = each.value.rotation_window_percentage != null ? each.value.rotation_window_percentage : 66
  key_algorithm              = each.value.key_algorithm != null ? each.value.key_algorithm : "RSA_2048"
  lifetime                   = each.value.lifetime != null ? each.value.lifetime : "2592000s" # 30 days

  certificate_authority_config {
    dynamic "certificate_authority_service_config" {
      for_each = each.value.ca_pool != null ? [1] : []

      content {
        ca_pool = each.value.ca_pool
      }
    }
  }

  labels = merge(
    local.default_labels,
    each.value.labels != null ? each.value.labels : {}
  )

  depends_on = [google_project_service.certificate_manager_api]
}

# Certificates
resource "google_certificate_manager_certificate" "certificates" {
  for_each = local.certificates

  name        = each.value.name
  description = each.value.description
  scope       = each.value.scope != null ? each.value.scope : "DEFAULT"
  location    = each.value.location != null ? each.value.location : "global"
  project     = var.project_id

  # Managed certificate configuration
  dynamic "managed" {
    for_each = each.value.managed != null ? [each.value.managed] : []

    content {
      domains = managed.value.domains

      dynamic "dns_authorizations" {
        for_each = managed.value.dns_authorization_keys != null ? managed.value.dns_authorization_keys : []

        content {
          dns_authorization = google_certificate_manager_dns_authorization.dns_authorizations[dns_authorizations.value].id
        }
      }

      issuance_config = managed.value.issuance_config_key != null ? (
        google_certificate_manager_certificate_issuance_config.issuance_configs[managed.value.issuance_config_key].id
      ) : null
    }
  }

  # Self-managed certificate configuration
  dynamic "self_managed" {
    for_each = each.value.self_managed != null ? [each.value.self_managed] : []

    content {
      pem_certificate = self_managed.value.pem_certificate
      pem_private_key = self_managed.value.pem_private_key
    }
  }

  labels = merge(
    local.default_labels,
    each.value.labels != null ? each.value.labels : {}
  )

  depends_on = [
    google_project_service.certificate_manager_api,
    google_certificate_manager_dns_authorization.dns_authorizations,
    google_certificate_manager_certificate_issuance_config.issuance_configs
  ]
}

# Certificate Maps
resource "google_certificate_manager_certificate_map" "certificate_maps" {
  for_each = local.certificate_maps

  name        = each.value.name
  description = each.value.description
  project     = var.project_id

  labels = merge(
    local.default_labels,
    each.value.labels != null ? each.value.labels : {}
  )

  depends_on = [google_project_service.certificate_manager_api]
}

# Certificate Map Entries
resource "google_certificate_manager_certificate_map_entry" "certificate_map_entries" {
  for_each = local.certificate_map_entries

  name        = each.value.name
  description = each.value.description
  map = each.value.certificate_map_key != null ? (
    google_certificate_manager_certificate_map.certificate_maps[each.value.certificate_map_key].name
  ) : each.value.certificate_map

  certificates = each.value.certificate_keys != null ? [
    for cert_key in each.value.certificate_keys :
    google_certificate_manager_certificate.certificates[cert_key].id
  ] : each.value.certificates

  hostname = each.value.hostname
  matcher = each.value.matcher != null ? each.value.matcher : (
    each.value.hostname != null ? "PRIMARY" : null
  )

  project = var.project_id

  labels = merge(
    local.default_labels,
    each.value.labels != null ? each.value.labels : {}
  )

  depends_on = [
    google_certificate_manager_certificate_map.certificate_maps,
    google_certificate_manager_certificate.certificates
  ]
}

# Trust Configs
resource "google_certificate_manager_trust_config" "trust_configs" {
  for_each = local.trust_configs
  provider = google-beta

  name        = each.value.name
  description = each.value.description
  location    = each.value.location != null ? each.value.location : "global"
  project     = var.project_id

  dynamic "trust_stores" {
    for_each = each.value.trust_stores != null ? each.value.trust_stores : []

    content {
      dynamic "trust_anchors" {
        for_each = trust_stores.value.trust_anchors != null ? trust_stores.value.trust_anchors : []

        content {
          pem_certificate = trust_anchors.value.pem_certificate
        }
      }

      dynamic "intermediate_cas" {
        for_each = trust_stores.value.intermediate_cas != null ? trust_stores.value.intermediate_cas : []

        content {
          pem_certificate = intermediate_cas.value.pem_certificate
        }
      }
    }
  }

  labels = merge(
    local.default_labels,
    each.value.labels != null ? each.value.labels : {}
  )

  depends_on = [google_project_service.certificate_manager_api]
}

# Classic SSL Certificates (for backward compatibility)
resource "google_compute_ssl_certificate" "classic_certificates" {
  for_each = var.classic_ssl_certificates

  name        = each.value.name != null ? each.value.name : "${local.name_prefix}-${each.key}-ssl"
  description = each.value.description
  private_key = each.value.private_key
  certificate = each.value.certificate

  name_prefix = each.value.name_prefix
  project     = var.project_id

  lifecycle {
    create_before_destroy = true
  }
}

# Classic Managed SSL Certificates
resource "google_compute_managed_ssl_certificate" "classic_managed_certificates" {
  for_each = var.classic_managed_ssl_certificates

  name        = each.value.name != null ? each.value.name : "${local.name_prefix}-${each.key}-managed-ssl"
  description = each.value.description
  project     = var.project_id

  managed {
    domains = each.value.domains
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_project_service.compute_api]
}

# SSL Policies
resource "google_compute_ssl_policy" "ssl_policies" {
  for_each = var.ssl_policies

  name            = each.value.name != null ? each.value.name : "${local.name_prefix}-${each.key}-policy"
  description     = each.value.description
  profile         = each.value.profile != null ? each.value.profile : "MODERN"
  min_tls_version = each.value.min_tls_version != null ? each.value.min_tls_version : "TLS_1_2"
  custom_features = each.value.custom_features
  project         = var.project_id

  depends_on = [google_project_service.compute_api]
}

# Target HTTPS Proxies with Certificate Maps
resource "google_compute_target_https_proxy" "proxies_with_cert_maps" {
  for_each = var.target_https_proxies

  name        = each.value.name != null ? each.value.name : "${local.name_prefix}-${each.key}-https-proxy"
  description = each.value.description
  url_map     = each.value.url_map

  certificate_map = each.value.certificate_map_key != null ? (
    "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.certificate_maps[each.value.certificate_map_key].id}"
  ) : each.value.certificate_map

  ssl_certificates = each.value.ssl_certificate_keys != null ? [
    for cert_key in each.value.ssl_certificate_keys :
    google_compute_ssl_certificate.classic_certificates[cert_key].self_link
  ] : each.value.ssl_certificates

  ssl_policy = each.value.ssl_policy_key != null ? (
    google_compute_ssl_policy.ssl_policies[each.value.ssl_policy_key].self_link
  ) : each.value.ssl_policy

  quic_override               = each.value.quic_override
  http_keep_alive_timeout_sec = each.value.http_keep_alive_timeout_sec

  project = var.project_id

  depends_on = [
    google_certificate_manager_certificate_map.certificate_maps,
    google_compute_ssl_certificate.classic_certificates,
    google_compute_ssl_policy.ssl_policies
  ]
}

# Monitoring Alert Policies
resource "google_monitoring_alert_policy" "cert_alerts" {
  for_each = var.create_monitoring_alerts ? var.monitoring_alerts : {}

  project      = var.project_id
  display_name = each.value.display_name
  combiner     = each.value.combiner != null ? each.value.combiner : "OR"
  enabled      = each.value.enabled != null ? each.value.enabled : true

  conditions {
    display_name = each.value.condition_display_name

    condition_threshold {
      filter          = each.value.filter
      duration        = each.value.duration != null ? each.value.duration : "60s"
      comparison      = each.value.comparison != null ? each.value.comparison : "COMPARISON_GT"
      threshold_value = each.value.threshold_value

      aggregations {
        alignment_period     = each.value.alignment_period != null ? each.value.alignment_period : "60s"
        per_series_aligner   = each.value.per_series_aligner != null ? each.value.per_series_aligner : "ALIGN_RATE"
        cross_series_reducer = each.value.cross_series_reducer
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

  notification_channels = each.value.notification_channels

  alert_strategy {
    auto_close = each.value.auto_close != null ? each.value.auto_close : "1800s"

    dynamic "notification_rate_limit" {
      for_each = each.value.rate_limit != null ? [each.value.rate_limit] : []

      content {
        period = notification_rate_limit.value.period
      }
    }
  }

  documentation {
    content   = each.value.documentation_content
    mime_type = each.value.documentation_mime_type != null ? each.value.documentation_mime_type : "text/markdown"
    subject   = each.value.documentation_subject
  }

  user_labels = merge(
    local.default_labels,
    each.value.labels != null ? each.value.labels : {}
  )
}

# Monitoring Dashboard
resource "google_monitoring_dashboard" "cert_dashboard" {
  count = var.create_monitoring_dashboard ? 1 : 0

  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "${local.name_prefix}-certificate-dashboard"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Certificate Expiry Status"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"certificatemanager.googleapis.com/Certificate\" metric.type=\"certificatemanager.googleapis.com/certificate/days_to_expiry\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MIN"
                      crossSeriesReducer = "REDUCE_MIN"
                      groupByFields      = ["resource.label.certificate_id"]
                    }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          xPos   = 6
          width  = 6
          height = 4
          widget = {
            title = "Certificate Provisioning Status"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"certificatemanager.googleapis.com/Certificate\" metric.type=\"certificatemanager.googleapis.com/certificate/provisioning_status\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_NEXT_OLDER"
                    crossSeriesReducer = "REDUCE_COUNT"
                    groupByFields      = ["metric.label.status"]
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_LINE"
              }
            }
          }
        },
        {
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "DNS Authorization Status"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"certificatemanager.googleapis.com/DnsAuthorization\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_NEXT_OLDER"
                    crossSeriesReducer = "REDUCE_COUNT"
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_BAR"
              }
            }
          }
        },
        {
          xPos   = 6
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Certificate Renewal Rate"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"certificatemanager.googleapis.com/Certificate\" metric.type=\"certificatemanager.googleapis.com/certificate/renewal_count\""
                    aggregation = {
                      alignmentPeriod    = "3600s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          yPos   = 8
          width  = 12
          height = 4
          widget = {
            title = "Certificate Map Usage"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"certificatemanager.googleapis.com/CertificateMap\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_NEXT_OLDER"
                      crossSeriesReducer = "REDUCE_COUNT"
                      groupByFields      = ["resource.label.certificate_map_id"]
                    }
                  }
                }
                plotType = "STACKED_BAR"
              }]
            }
          }
        }
      ]
    }
  })
}

# Notification Channels
resource "google_monitoring_notification_channel" "cert_notifications" {
  for_each = var.notification_channels

  display_name = each.value.display_name
  type         = each.value.type # "email", "slack", "pagerduty", "webhook"
  labels       = each.value.labels
  description  = each.value.description
  enabled      = each.value.enabled != null ? each.value.enabled : true
  project      = var.project_id

  user_labels = merge(
    local.default_labels,
    each.value.user_labels != null ? each.value.user_labels : {}
  )

  dynamic "sensitive_labels" {
    for_each = each.value.sensitive_labels != null ? [each.value.sensitive_labels] : []

    content {
      auth_token  = sensitive_labels.value.auth_token
      password    = sensitive_labels.value.password
      service_key = sensitive_labels.value.service_key
    }
  }
}

# Scheduled Certificate Rotation Function
resource "google_cloudfunctions2_function" "cert_rotation" {
  count = var.enable_auto_rotation ? 1 : 0

  name        = "${local.name_prefix}-cert-rotation"
  location    = var.region
  description = "Automated certificate rotation function"
  project     = var.project_id

  build_config {
    runtime     = "python310"
    entry_point = "rotate_certificates"

    source {
      storage_source {
        bucket = var.rotation_function_source_bucket
        object = var.rotation_function_source_object
      }
    }

    environment_variables = {
      PROJECT_ID         = var.project_id
      DAYS_BEFORE_EXPIRY = var.rotation_days_before_expiry != null ? var.rotation_days_before_expiry : "30"
    }
  }

  service_config {
    max_instance_count    = 10
    min_instance_count    = 0
    available_memory      = "256M"
    timeout_seconds       = 60
    service_account_email = var.create_service_account ? google_service_account.cert_manager[0].email : null

    environment_variables = {
      LOG_LEVEL = var.rotation_log_level != null ? var.rotation_log_level : "INFO"
    }
  }

  labels = local.default_labels
}

# Cloud Scheduler for Certificate Rotation
resource "google_cloud_scheduler_job" "cert_rotation_schedule" {
  count = var.enable_auto_rotation ? 1 : 0

  name        = "${local.name_prefix}-cert-rotation-schedule"
  description = "Schedule for automated certificate rotation"
  schedule    = var.rotation_schedule != null ? var.rotation_schedule : "0 2 * * *" # Daily at 2 AM
  time_zone   = var.rotation_time_zone != null ? var.rotation_time_zone : "UTC"
  project     = var.project_id
  region      = var.region

  http_target {
    uri         = google_cloudfunctions2_function.cert_rotation[0].service_config[0].uri
    http_method = "POST"

    oidc_token {
      service_account_email = var.create_service_account ? google_service_account.cert_manager[0].email : null
    }
  }

  retry_config {
    retry_count          = 3
    max_retry_duration   = "600s"
    min_backoff_duration = "5s"
    max_backoff_duration = "60s"
    max_doublings        = 2
  }
}