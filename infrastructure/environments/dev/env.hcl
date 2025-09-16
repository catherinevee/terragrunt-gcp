# Development environment configuration

locals {
  environment = "dev"
  region      = "us-central1"
  zone        = "us-central1-a"
  
  # Project configuration
  project_id = "acme-ecommerce-platform-dev"  # ACME E-commerce Platform Development Environment
  
  # Network configuration
  network_config = {
    vpc_cidr          = "10.0.0.0/16"
    public_subnet_cidr  = "10.0.1.0/24"
    private_subnet_cidr = "10.0.10.0/24"
    pods_subnet_cidr    = "10.0.100.0/21"  # For GKE pods
    services_subnet_cidr = "10.0.108.0/21"  # For GKE services
  }
  
  # Resource sizing (smaller for dev)
  resource_sizing = {
    # GKE configuration
    gke_node_count       = 2
    gke_min_nodes        = 1
    gke_max_nodes        = 3
    gke_machine_type     = "e2-standard-2"
    gke_disk_size_gb     = 50
    gke_preemptible      = true  # Use preemptible nodes to save costs
    
    # Cloud SQL configuration
    db_tier              = "db-f1-micro"
    db_disk_size         = 10
    db_disk_type         = "PD_HDD"
    db_backup_enabled    = false
    db_ha_enabled        = false  # No HA in dev
    
    # Redis configuration
    redis_tier           = "BASIC"
    redis_memory_size_gb = 1
    
    # Cloud Run configuration
    cloudrun_cpu         = "1"
    cloudrun_memory      = "512Mi"
    cloudrun_min_instances = 0
    cloudrun_max_instances = 10
    
    # Storage configuration
    storage_class        = "STANDARD"
    enable_versioning    = false
  }
  
  # Environment-specific features
  features = {
    enable_monitoring      = true
    enable_logging         = true
    enable_tracing        = false
    enable_profiling      = false
    enable_debug_mode     = true
    enable_auto_scaling   = false
    enable_cdn            = false
    enable_armor          = false  # Cloud Armor DDoS protection
  }
  
  # Cost optimization
  cost_optimization = {
    use_preemptible_nodes = true
    auto_shutdown_enabled = true  # Shutdown resources after hours
    shutdown_schedule     = "0 20 * * *"  # 8 PM daily
    startup_schedule      = "0 8 * * 1-5"  # 8 AM weekdays
  }
  
  # Dev-specific settings
  dev_settings = {
    allow_public_access    = true
    enable_ssh_access      = true
    enable_debug_endpoints = true
    log_level             = "DEBUG"
  }
  
  # DNS configuration
  dns = {
    zone_name    = "acme-ecommerce-dev-com"
    dns_name     = "dev.acme-ecommerce.com."
    subdomain    = "dev"
  }
  
  # Tagging
  environment_tags = {
    environment  = "development"
    business_unit = "ecommerce"
    application  = "ecommerce-platform"
    auto_shutdown = "true"
    cost_center  = "development"
  }
}