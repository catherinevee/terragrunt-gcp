# Development environment configuration

locals {
  environment = "dev"
  region      = "europe-west1"
  zone        = "europe-west1-b"
  
  # Environment-specific project (optional - can use same project with env prefix)
  project_suffix = "dev"
  
  # Networking
  vpc_cidr = "10.0.0.0/16"
  
  # Kubernetes configuration
  gke_config = {
    min_nodes = 1
    max_nodes = 3
    machine_type = "n1-standard-2"
    preemptible = true
    disk_size_gb = 30
    auto_repair = true
    auto_upgrade = true
  }
  
  # Cloud Run configuration
  cloud_run_config = {
    max_instances = 10
    min_instances = 0
    cpu_limit = "1"
    memory_limit = "512Mi"
    timeout_seconds = 300
    max_concurrent_requests = 80
  }
  
  # Database configuration
  database_config = {
    tier = "db-f1-micro"
    high_availability = false
    backup_enabled = true
    backup_start_time = "03:00"
    maintenance_window_day = 7
    maintenance_window_hour = 3
    deletion_protection = false
  }
  
  # Storage configuration
  storage_config = {
    storage_class = "STANDARD"
    lifecycle_age_days = 30
    versioning = false
  }
  
  # Monitoring and alerting
  monitoring_config = {
    log_retention_days = 7
    metrics_retention_days = 30
    alerting_enabled = false
    error_reporting_enabled = true
  }
  
  # Cost optimization
  cost_optimization = {
    use_preemptible_nodes = true
    use_spot_instances = true
    auto_shutdown_enabled = true
    shutdown_time = "22:00"
    startup_time = "08:00"
  }
  
  # Security settings
  security_config = {
    enable_private_google_access = true
    enable_private_ip_google_access = true
    enable_flow_logs = false
    enable_cloud_armor = false
    enable_binary_authorization = false
  }
  
  # Environment tags
  environment_tags = [
    "dev",
    "development",
    "non-production"
  ]
  
  # Environment labels
  environment_labels = {
    environment = local.environment
    region = local.region
    cost_center = "development"
    data_classification = "non-sensitive"
  }
}