# Terraform variable values for production environment global configuration

# Core project configuration
project_id      = "acme-prod-platform"
project_number  = "123456789012"
billing_account = "012345-6789AB-CDEF01"
organization    = "acme-corp"
default_region  = "us-central1"

# Domain and notifications
prod_domain         = "acme-corp.com"
prod_critical_email = "prod-critical@acme-corp.com"
prod_warning_email  = "prod-warning@acme-corp.com"

# PagerDuty integration
pagerduty_service_key = "REPLACE_WITH_ACTUAL_SERVICE_KEY"
pagerduty_auth_token  = "REPLACE_WITH_ACTUAL_AUTH_TOKEN"

# Slack integration
slack_webhook_critical = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"

# SMS alerts for critical incidents
sms_numbers = [
  # "+1234567890",  # On-call primary
  # "+0987654321"   # On-call secondary
]

# VPC Service Controls
enable_vpc_sc    = true
access_policy_id = "YOUR_ACCESS_POLICY_ID"
access_level_id  = "YOUR_ACCESS_LEVEL_ID"

# Security - IP ranges to block
blocked_ip_ranges = [
  "192.0.2.0/24",     # TEST-NET-1
  "198.51.100.0/24",  # TEST-NET-2
  "203.0.113.0/24",   # TEST-NET-3
]

# Budget configuration
prod_budget_amount = 50000  # $50,000 per month

# Multi-region deployment configuration
prod_regions = {
  "us-central1" = {
    enabled  = true
    zones    = ["us-central1-a", "us-central1-b", "us-central1-c", "us-central1-f"]
    priority = 1
  }
  "us-east1" = {
    enabled  = true
    zones    = ["us-east1-b", "us-east1-c", "us-east1-d"]
    priority = 2
  }
  "europe-west1" = {
    enabled  = true
    zones    = ["europe-west1-b", "europe-west1-c", "europe-west1-d"]
    priority = 3
  }
  "asia-southeast1" = {
    enabled  = true
    zones    = ["asia-southeast1-a", "asia-southeast1-b", "asia-southeast1-c"]
    priority = 4
  }
}

# Network configuration
prod_network_config = {
  vpc_name                = "prod-vpc"
  auto_create_subnetworks = false
  routing_mode           = "GLOBAL"
  mtu                    = 1500
  enable_flow_logs       = true
  flow_log_sampling      = 1.0  # 100% sampling for security
}

# Compute defaults - production grade
prod_compute_defaults = {
  machine_type               = "n2-standard-4"
  preemptible               = false
  automatic_restart         = true
  on_host_maintenance       = "MIGRATE"
  provisioning_model        = "STANDARD"
  enable_shielded_vm        = true
  enable_secure_boot        = true
  enable_vtpm               = true
  enable_integrity_monitoring = true
}

# Database configuration - high availability
prod_database_defaults = {
  tier                    = "db-n1-highmem-4"
  availability_type       = "REGIONAL"
  backup_enabled         = true
  backup_start_time      = "02:00"
  point_in_time_recovery = true
  transaction_log_retention_days = 7
  backup_retention_count  = 30
  maintenance_window_day  = 7  # Sunday
  maintenance_window_hour = 3   # 3 AM
  maintenance_window_update_track = "stable"
  database_flags = {
    slow_query_log = "on"
    log_output     = "FILE"
    general_log    = "on"
  }
}

# Storage configuration - multi-regional with versioning
prod_storage_defaults = {
  location      = "US"
  storage_class = "MULTI_REGIONAL"
  versioning    = true
  lifecycle_rules = [
    {
      age        = 90
      type       = "Delete"
      with_state = "ARCHIVED"
    },
    {
      age        = 365
      type       = "Delete"
      with_state = "ANY"
    }
  ]
  encryption = {
    default_kms_key_name = null  # Set dynamically
  }
  uniform_bucket_level_access = true
  public_access_prevention   = "enforced"
  retention_policy_days      = 30
}

# Autoscaling configuration - conservative for stability
prod_autoscaling_defaults = {
  min_replicas           = 3   # HA minimum
  max_replicas           = 100
  cpu_utilization_target = 0.6
  scale_down_control = {
    max_scaled_down_replicas = 10
    time_window_sec         = 600
  }
  scale_up_control = {
    max_scaled_up_replicas = 20
    time_window_sec       = 60
  }
}

# Monitoring configuration - comprehensive
prod_monitoring_config = {
  metrics_interval       = "30s"
  log_sampling_ratio    = 1.0
  trace_sampling_ratio  = 0.5
  profiler_enabled      = true
  debugger_enabled      = false
  error_reporting_enabled = true
  uptime_check_interval = "60s"
  alert_auto_close      = "86400s"
  notification_rate_limit = "300s"
}

# Security configuration - maximum security
prod_security_config = {
  enable_private_google_access = true
  enable_private_service_connect = true
  enable_binary_authorization = true
  enable_vulnerability_scanning = true
  enable_security_command_center = true
  enable_access_transparency = true
  enable_data_access_logs = true
  require_ssl_database = true
  enable_cmek_encryption = true
  enable_application_layer_encryption = true
}

# Compliance configuration
prod_compliance_config = {
  enable_audit_logs = true
  log_retention_days = 365
  enable_data_residency = true
  data_residency_regions = ["us-central1", "us-east1"]
  enable_hipaa_compliance = false
  enable_pci_compliance = true
  enable_sox_compliance = true
  enable_gdpr_compliance = true
  enable_iso27001_compliance = true
}

# Disaster recovery configuration
prod_disaster_recovery = {
  enable_cross_region_backup = true
  backup_regions = ["us-east1", "europe-west1"]
  rto_hours = 4
  rpo_hours = 1
  enable_automated_failover = true
  failover_grace_period_seconds = 300
}

# Resource labels
labels = {
  environment   = "production"
  managed_by    = "terraform"
  cost_center   = "operations"
  business_unit = "platform"
  criticality   = "critical"
  compliance    = "pci-sox-gdpr"
  data_classification = "sensitive"
  dr_tier = "tier-1"
}

# Network tags
tags = [
  "production",
  "allow-health-checks",
  "allow-internal",
  "allow-google-apis",
  "allow-load-balancer"
]