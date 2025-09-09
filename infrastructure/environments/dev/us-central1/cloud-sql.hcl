terraform {
  # Source from Terraform Registry - Google Cloud SQL Module
  source = "tfr:///GoogleCloudPlatform/sql-db/google//modules/postgresql?version=18.0.0"
}

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("env.hcl")
}

dependency "network" {
  config_path = "../network"
  
  mock_outputs = {
    network_self_link = "projects/mock-project/global/networks/mock-network"
    private_vpc_connection = "mock-vpc-connection"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.env_vars.locals.environment
  region = "us-central1"
}

inputs = {
  project_id = "${local.environment}-project"
  name       = "${local.environment}-${local.region}-postgres"
  
  database_version = "POSTGRES_15"
  region          = local.region
  zone            = "${local.region}-a"
  tier            = local.environment == "prod" ? "db-custom-4-16384" : "db-f1-micro"

  deletion_protection = local.environment == "prod"

  # Network configuration
  ip_configuration = {
    ipv4_enabled                                  = false
    private_network                               = dependency.network.outputs.network_self_link
    enable_private_path_for_google_cloud_services = true
    require_ssl                                   = true
  }

  # Backup configuration
  backup_configuration = {
    enabled                        = true
    start_time                     = "03:00"
    location                       = local.region
    point_in_time_recovery_enabled = local.environment == "prod"
    retained_backups               = local.environment == "prod" ? 30 : 7
    retention_unit                 = "COUNT"
  }

  # High availability (for production only)
  availability_type = local.environment == "prod" ? "REGIONAL" : "ZONAL"

  # Database flags
  database_flags = [
    {
      name  = "max_connections"
      value = "100"
    },
    {
      name  = "log_checkpoints"
      value = "on"
    }
  ]

  # Maintenance window
  maintenance_window_day          = 7  # Sunday
  maintenance_window_hour         = 4  # 4 AM
  maintenance_window_update_track = "stable"

  # User labels
  user_labels = {
    environment = local.environment
    region      = local.region
    managed_by  = "terragrunt"
  }

  # Additional databases
  additional_databases = [
    {
      name      = "application_db"
      charset   = "UTF8"
      collation = "en_US.UTF8"
    }
  ]

  # Additional users
  additional_users = [
    {
      name     = "app_user"
      password = "" # Will be generated
    }
  ]
}