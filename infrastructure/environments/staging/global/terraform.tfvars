# Terraform variable values for staging environment global configuration

# Core project configuration
project_id                 = "acme-staging-platform"
billing_account           = "012345-6789AB-CDEF01"
organization              = "acme-corp"
default_region            = "us-central1"

# Domain and notifications
staging_domain             = "staging.acme-corp.com"
staging_notification_email = "staging-alerts@acme-corp.com"

# Budget configuration
staging_budget_amount      = 5000
staging_budget_alert_thresholds = [0.5, 0.75, 0.9, 1.0]

# Security and encryption
kms_rotation_period       = "7776000s"  # 90 days
rate_limit_threshold = {
  count        = 100
  interval_sec = 60
}
rate_limit_ban_duration   = 600
enable_adaptive_protection = true

# Retention policies
artifact_retention_days   = 30
log_retention_days       = 30
pubsub_message_retention = "86400s"   # 1 day
dlq_message_retention    = "604800s"  # 7 days

# Regional configuration
staging_regions = {
  "us-central1" = {
    enabled = true
    zones   = ["us-central1-a", "us-central1-b", "us-central1-c"]
  }
  "us-east1" = {
    enabled = true
    zones   = ["us-east1-b", "us-east1-c"]
  }
}

# Network configuration
staging_network_config = {
  vpc_name               = "staging-vpc"
  auto_create_subnetworks = false
  routing_mode           = "REGIONAL"
  mtu                    = 1460
  enable_flow_logs       = true
}

# Compute defaults for cost optimization
staging_compute_defaults = {
  machine_type         = "e2-medium"
  preemptible         = true
  automatic_restart   = false
  on_host_maintenance = "TERMINATE"
  provisioning_model  = "SPOT"
}

# Database configuration
staging_database_defaults = {
  tier                   = "db-g1-small"
  availability_type      = "ZONAL"
  backup_enabled         = true
  backup_start_time      = "03:00"
  point_in_time_recovery = false
}

# Autoscaling configuration
staging_autoscaling_defaults = {
  min_replicas           = 1
  max_replicas           = 10
  cpu_utilization_target = 0.8
  scale_down_control = {
    max_scaled_down_replicas = 2
    time_window_sec         = 300
  }
}

# Monitoring configuration
staging_monitoring_config = {
  metrics_interval     = "60s"
  log_sampling_ratio   = 0.5
  trace_sampling_ratio = 0.1
  profiler_enabled     = false
}

# Resource labels
labels = {
  environment   = "staging"
  managed_by    = "terraform"
  cost_center   = "engineering"
  business_unit = "platform"
  criticality   = "medium"
  data_classification = "internal"
}

# Network tags
tags = [
  "staging",
  "allow-health-checks",
  "allow-internal",
  "allow-ssh-from-bastion"
]