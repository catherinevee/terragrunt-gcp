# Staging environment configuration

locals {
  environment = "staging"
  region      = "europe-west1"
  zone        = "europe-west1-c"
  
  # Environment-specific project (optional - can use same project with env prefix)
  project_suffix = "staging"
  project_id = "acme-ecommerce-platform-staging"  # ACME E-commerce Platform Staging Environment
  
  # Networking
  vpc_cidr = "10.10.0.0/16"
  
  # Kubernetes configuration
  gke_config = {
    min_nodes = 2
    max_nodes = 5
    machine_type = "n1-standard-4"
    preemptible = false
    disk_size_gb = 50
    auto_repair = true
    auto_upgrade = true
  }
  
  # Cloud Run configuration
  cloud_run_config = {
    max_instances = 50
    min_instances = 1
    cpu_limit = "2"
    memory_limit = "1Gi"
    timeout_seconds = 300
    max_concurrent_requests = 100
  }
  
  # Database configuration
  database_config = {
    tier = "db-n1-standard-1"
    high_availability = true
    backup_enabled = true
    backup_start_time = "02:00"
    maintenance_window_day = 7
    maintenance_window_hour = 2
    deletion_protection = true
  }
  
  # Storage configuration
  storage_config = {
    storage_class = "STANDARD"
    lifecycle_age_days = 90
    versioning = true
  }
  
  # Monitoring and alerting
  monitoring_config = {
    log_retention_days = 30
    metrics_retention_days = 90
    alerting_enabled = true
    error_reporting_enabled = true
  }
  
  # Cost optimization
  cost_optimization = {
    use_preemptible_nodes = false
    use_spot_instances = false
    auto_shutdown_enabled = false
    shutdown_time = ""
    startup_time = ""
  }
  
  # Security settings
  security_config = {
    enable_private_google_access = true
    enable_private_ip_google_access = true
    enable_flow_logs = true
    enable_cloud_armor = true
    enable_binary_authorization = true
  }
  
  # Environment tags
  environment_tags = [
    "staging",
    "pre-production"
  ]
  
  # Environment labels
  environment_labels = {
    environment = local.environment
    business_unit = "ecommerce"
    application = "ecommerce-platform"
    region = local.region
    cost_center = "staging"
    data_classification = "confidential"
  }
}