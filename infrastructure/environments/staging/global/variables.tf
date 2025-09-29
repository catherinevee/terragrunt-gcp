# Variables for staging environment global configuration

variable "project_id" {
  description = "The GCP project ID for staging environment"
  type        = string
}

variable "billing_account" {
  description = "The billing account ID"
  type        = string
}

variable "organization" {
  description = "Organization name"
  type        = string
  default     = "acme-corp"
}

variable "default_region" {
  description = "Default region for staging resources"
  type        = string
  default     = "us-central1"
}

variable "staging_domain" {
  description = "Domain name for staging environment"
  type        = string
  default     = "staging.acme-corp.com"
}

variable "staging_notification_email" {
  description = "Email for staging environment notifications"
  type        = string
  default     = "staging-alerts@acme-corp.com"
}

variable "enable_apis" {
  description = "List of APIs to enable for staging environment"
  type        = list(string)
  default = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "pubsub.googleapis.com",
    "cloudsql.googleapis.com",
    "cloudkms.googleapis.com",
    "secretmanager.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "iam.googleapis.com",
    "dns.googleapis.com",
    "servicenetworking.googleapis.com",
    "vpcaccess.googleapis.com",
    "redis.googleapis.com",
    "dataflow.googleapis.com",
    "dataproc.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudrun.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudtasks.googleapis.com",
    "firestore.googleapis.com",
    "composer.googleapis.com",
    "spanner.googleapis.com",
    "artifactregistry.googleapis.com",
    "binaryauthorization.googleapis.com",
    "containeranalysis.googleapis.com",
    "appengine.googleapis.com",
    "apigateway.googleapis.com",
    "servicecontrol.googleapis.com",
    "servicemanagement.googleapis.com",
    "cloudbuild.googleapis.com",
    "sourcerepo.googleapis.com"
  ]
}

variable "staging_budget_amount" {
  description = "Monthly budget amount for staging environment in USD"
  type        = number
  default     = 5000
}

variable "staging_budget_alert_thresholds" {
  description = "Budget alert thresholds as percentages"
  type        = list(number)
  default     = [0.5, 0.75, 0.9, 1.0]
}

variable "kms_rotation_period" {
  description = "Rotation period for KMS keys in seconds"
  type        = string
  default     = "7776000s"  # 90 days
}

variable "artifact_retention_days" {
  description = "Number of days to retain artifacts in registry"
  type        = number
  default     = 30
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

variable "pubsub_message_retention" {
  description = "Message retention duration for Pub/Sub topics"
  type        = string
  default     = "86400s"  # 1 day
}

variable "dlq_message_retention" {
  description = "Message retention duration for dead letter queue"
  type        = string
  default     = "604800s"  # 7 days
}

variable "rate_limit_threshold" {
  description = "Rate limit threshold for Cloud Armor"
  type = object({
    count        = number
    interval_sec = number
  })
  default = {
    count        = 100
    interval_sec = 60
  }
}

variable "rate_limit_ban_duration" {
  description = "Ban duration in seconds for rate limit violations"
  type        = number
  default     = 600  # 10 minutes
}

variable "enable_adaptive_protection" {
  description = "Enable adaptive protection for DDoS defense"
  type        = bool
  default     = true
}

variable "staging_regions" {
  description = "Regions to deploy staging resources"
  type = map(object({
    enabled = bool
    zones   = list(string)
  }))
  default = {
    "us-central1" = {
      enabled = true
      zones   = ["us-central1-a", "us-central1-b", "us-central1-c"]
    }
    "us-east1" = {
      enabled = true
      zones   = ["us-east1-b", "us-east1-c"]
    }
  }
}

variable "staging_network_config" {
  description = "Network configuration for staging environment"
  type = object({
    vpc_name               = string
    auto_create_subnetworks = bool
    routing_mode           = string
    mtu                    = number
    enable_flow_logs       = bool
  })
  default = {
    vpc_name               = "staging-vpc"
    auto_create_subnetworks = false
    routing_mode           = "REGIONAL"
    mtu                    = 1460
    enable_flow_logs       = true
  }
}

variable "staging_compute_defaults" {
  description = "Default compute settings for staging"
  type = object({
    machine_type           = string
    preemptible           = bool
    automatic_restart     = bool
    on_host_maintenance   = string
    provisioning_model    = string
  })
  default = {
    machine_type         = "e2-medium"
    preemptible         = true
    automatic_restart   = false
    on_host_maintenance = "TERMINATE"
    provisioning_model  = "SPOT"
  }
}

variable "staging_database_defaults" {
  description = "Default database settings for staging"
  type = object({
    tier                = string
    availability_type   = string
    backup_enabled      = bool
    backup_start_time   = string
    point_in_time_recovery = bool
  })
  default = {
    tier                = "db-g1-small"
    availability_type   = "ZONAL"
    backup_enabled      = true
    backup_start_time   = "03:00"
    point_in_time_recovery = false
  }
}

variable "staging_autoscaling_defaults" {
  description = "Default autoscaling settings for staging"
  type = object({
    min_replicas            = number
    max_replicas            = number
    cpu_utilization_target  = number
    scale_down_control = object({
      max_scaled_down_replicas = number
      time_window_sec         = number
    })
  })
  default = {
    min_replicas           = 1
    max_replicas           = 10
    cpu_utilization_target = 0.8
    scale_down_control = {
      max_scaled_down_replicas = 2
      time_window_sec         = 300
    }
  }
}

variable "staging_monitoring_config" {
  description = "Monitoring configuration for staging"
  type = object({
    metrics_interval     = string
    log_sampling_ratio   = number
    trace_sampling_ratio = number
    profiler_enabled     = bool
  })
  default = {
    metrics_interval     = "60s"
    log_sampling_ratio   = 0.5
    trace_sampling_ratio = 0.1
    profiler_enabled     = false
  }
}

variable "labels" {
  description = "Default labels to apply to all staging resources"
  type        = map(string)
  default = {
    environment   = "staging"
    managed_by    = "terraform"
    cost_center   = "engineering"
    business_unit = "platform"
    criticality   = "medium"
  }
}

variable "tags" {
  description = "Network tags for staging resources"
  type        = list(string)
  default = [
    "staging",
    "allow-health-checks",
    "allow-internal"
  ]
}