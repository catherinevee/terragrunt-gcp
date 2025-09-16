# Cloud Monitoring Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "alert_policies" {
  description = "Alert policies to create"
  type = map(object({
    display_name = string
    documentation = object({
      content  = string
      mime_type = string
    })
    conditions = list(object({
      display_name = string
      condition_threshold = object({
        filter          = string
        comparison      = string
        threshold_value = number
        duration        = string
        aggregations = list(object({
          alignment_period   = string
          per_series_aligner = string
        }))
      })
    }))
    notification_channels = list(string)
  }))
  default = {}
}

variable "monitoring_services" {
  description = "Monitoring services to create"
  type = map(object({
    display_name = string
    service_type = string
    service_labels = map(string)
  }))
  default = {}
}

variable "slos" {
  description = "SLOs to create"
  type = map(object({
    display_name = string
    goal = number
    service = string
    rolling_period_days = number
    sli = object({
      request_based = object({
        good_total_ratio = object({
          total_service_filter = string
          good_service_filter  = string
        })
      })
    })
  }))
  default = {}
}
