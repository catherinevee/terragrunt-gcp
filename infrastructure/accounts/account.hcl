# Account-level configuration
# This file contains organization-wide settings that apply to all environments

locals {
  # Organization details
  organization = "yanka"  # Changed from default - this should match your organization name
  billing_account = "XXXXXX-XXXXXX-XXXXXX"  # Your GCP billing account ID
  
  # Project naming convention: {organization}-{environment}-project
  # This will be overridden by environment-specific configurations
  project_id = "${local.organization}-${local.environment}-project"
  
  # Default domain for the organization
  domain = "${local.organization}.com"
  
  # Organization-wide tags
  organization_tags = {
    organization = local.organization
    cost_center  = "engineering"
    team         = "platform"
  }
  
  # Notification settings
  notification_channels = {
    email = "alerts@${local.domain}"
    slack = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
  }
  
  # Compliance and governance settings
  compliance = {
    data_residency     = "US"  # US, EU, ASIA
    encryption_type    = "GOOGLE_MANAGED"  # GOOGLE_MANAGED or CMEK
    retention_days     = 90
    audit_log_enabled  = true
  }
  
  # Backup configuration
  backup = {
    enabled              = true
    retention_days       = 30
    cross_region_enabled = true
    backup_regions       = ["us-west1", "us-east1"]
  }
  
  # Security settings
  security = {
    enable_vpc_flow_logs    = true
    enable_firewall_logging = true
    enable_audit_logs       = true
    enable_dlp              = false  # Data Loss Prevention
    enable_binary_auth      = false  # Binary Authorization for GKE
  }
  
  # Network configuration
  network = {
    enable_private_google_access = true
    enable_private_ip_google_apis = true
    nat_ip_allocate_option       = "AUTO_ONLY"
    nat_source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  }
  
  # Default resource quotas
  quotas = {
    max_nodes_per_cluster = 100
    max_instances_per_zone = 50
    max_storage_tb = 10
  }
  
  # Cost management
  budget = {
    alert_spent_percents = [50, 75, 90, 100]
    alert_pubsub_topic   = "budget-alerts"
  }
}