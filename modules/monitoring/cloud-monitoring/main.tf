# Cloud Monitoring Module
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.45.2"
    }
  }
}

# Alert Policies
resource "google_monitoring_alert_policy" "alert_policies" {
  for_each = var.alert_policies

  display_name = each.value.display_name
  project      = var.project_id
  combiner     = try(each.value.combiner, "OR") # Default to OR if not specified

  documentation {
    content   = each.value.documentation.content
    mime_type = each.value.documentation.mime_type
  }

  conditions {
    display_name = each.value.conditions[0].display_name
    condition_threshold {
      filter          = each.value.conditions[0].condition_threshold.filter
      comparison      = each.value.conditions[0].condition_threshold.comparison
      threshold_value = each.value.conditions[0].condition_threshold.threshold_value
      duration        = each.value.conditions[0].condition_threshold.duration
      aggregations {
        alignment_period   = each.value.conditions[0].condition_threshold.aggregations[0].alignment_period
        per_series_aligner = each.value.conditions[0].condition_threshold.aggregations[0].per_series_aligner
      }
    }
  }

  notification_channels = each.value.notification_channels

  depends_on = [google_project_service.monitoring_api]
}

# Monitoring Services
resource "google_monitoring_service" "monitoring_services" {
  for_each = var.monitoring_services

  service_id   = each.key
  display_name = each.value.display_name
  project      = var.project_id

  basic_service {
    service_type   = each.value.service_type
    service_labels = each.value.service_labels
  }

  depends_on = [google_project_service.monitoring_api]
}

# SLOs
resource "google_monitoring_slo" "slos" {
  for_each = var.slos

  service      = google_monitoring_service.monitoring_services[each.value.service].service_id
  slo_id       = each.key
  display_name = each.value.display_name
  goal         = each.value.goal
  project      = var.project_id

  rolling_period_days = each.value.rolling_period_days

  request_based_sli {
    good_total_ratio {
      total_service_filter = each.value.sli.request_based.good_total_ratio.total_service_filter
      good_service_filter  = each.value.sli.request_based.good_total_ratio.good_service_filter
    }
  }

  depends_on = [google_project_service.monitoring_api]
}

# Enable Monitoring API
resource "google_project_service" "monitoring_api" {
  project = var.project_id
  service = "monitoring.googleapis.com"

  disable_on_destroy = false
}

