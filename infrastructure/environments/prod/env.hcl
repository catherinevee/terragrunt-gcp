# Production environment configuration

locals {
  environment = "prod"
  region      = "europe-west1"
  zone        = "europe-west1-d"
  
  # Environment-specific project (optional - can use same project with env prefix)
  project_suffix = "prod"
  project_id = "acme-ecommerce-platform-prod"  # ACME E-commerce Platform Production Environment
  
  # Networking
  vpc_cidr = "10.20.0.0/16"
  
  # Kubernetes configuration
  gke_config = {
    min_nodes = 3
    max_nodes = 20
    machine_type = "n1-standard-8"
    preemptible = false
    disk_size_gb = 100
    auto_repair = true
    auto_upgrade = false  # Manual upgrades in production
  }
  
  # Cloud Run configuration
  cloud_run_config = {
    max_instances = 100
    min_instances = 3
    cpu_limit = "4"
    memory_limit = "2Gi"
    timeout_seconds = 300
    max_concurrent_requests = 250
  }
  
  # Database configuration
  database_config = {
    tier = "db-n1-standard-4"
    high_availability = true
    backup_enabled = true
    backup_start_time = "01:00"
    maintenance_window_day = 7
    maintenance_window_hour = 1
    deletion_protection = true
  }
  
  # Storage configuration
  storage_config = {
    storage_class = "STANDARD"
    lifecycle_age_days = 365
    versioning = true
  }
  
  # Monitoring and alerting
  monitoring_config = {
    log_retention_days = 90
    metrics_retention_days = 365
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
    "prod",
    "production"
  ]
  
  # Environment labels
  environment_labels = {
    environment = local.environment
    business_unit = "ecommerce"
    application = "ecommerce-platform"
    region = local.region
    cost_center = "production"
    data_classification = "highly-confidential"
  }
}