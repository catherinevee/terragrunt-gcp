# Global Resources for Multi-Region Deployment
# These resources are shared across all regions

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.45.2"
    }
  }
}

# Configure the Google Cloud Provider
provider "google" {
  project = var.project_id
  region  = var.primary_region
}

# Local values for consistent naming
locals {
  project_id       = var.project_id
  environment      = var.environment
  primary_region   = var.primary_region
  secondary_region = var.secondary_region

  # Global resource naming
  global_prefix = "acme-ecommerce-platform-${local.environment}"

  # IAM bindings disabled by default to handle permission issues
  enable_iam_bindings = false
}

# Global VPC Network (shared across regions)
module "vpc" {
  source = "../../../../modules/networking/vpc"

  project_id   = local.project_id
  network_name = "${local.global_prefix}-vpc"
  description  = "Global VPC network for ${local.environment} environment"

  # Global VPC settings
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

# # Global Load Balancer
# module "load_balancer" {
#   source = "../../../../modules/networking/load-balancer"
# 
#   project_id  = local.project_id
#   environment = local.environment
# 
#   # Global load balancer configuration
#   global_ip_name       = "${local.global_prefix}-lb-ip"
#   health_check_name    = "${local.global_prefix}-lb-health-check"
#   backend_service_name = "${local.global_prefix}-lb-backend"
#   url_map_name         = "${local.global_prefix}-lb-url-map"
#   forwarding_rule_name = "${local.global_prefix}-lb-forwarding-rule"
# 
#   # Backend regions
#   backend_regions = [local.primary_region, local.secondary_region]
# 
#   # Health check configuration
#   health_check_config = {
#     check_interval_sec  = var.load_balancer_health_check_interval
#     timeout_sec         = var.load_balancer_health_check_timeout
#     healthy_threshold   = var.load_balancer_healthy_threshold
#     unhealthy_threshold = var.load_balancer_unhealthy_threshold
#     port                = var.load_balancer_health_check_port
#     request_path        = "/health"
#   }
# }
# 
# # Global DNS Configuration
# module "dns" {
#   source = "../../../../modules/networking/dns"
# 
#   project_id  = local.project_id
#   environment = local.environment
# 
#   # DNS zone configuration
#   zone_name = var.dns_zone_name
#   dns_name  = var.dns_name
# 
#   # Load balancer IP
#   load_balancer_ip = module.load_balancer.global_ip_address
# 
#   # Records
#   records = {
#     "api" = {
#       name = "api"
#       type = "A"
#       ttl  = var.dns_ttl_seconds
#     }
#     "web" = {
#       name = "www"
#       type = "A"
#       ttl  = var.dns_ttl_seconds
#     }
#   }
# }

# Global IAM Configuration
module "iam" {
  source = "../../../../modules/security/iam"

  project_id          = local.project_id
  environment         = local.environment
  enable_iam_bindings = local.enable_iam_bindings

  # Service accounts for global resources
  service_accounts = {
    "acme-ecommerce-terraform-sa" = {
      account_id   = "acme-ecommerce-terraform-sa"
      display_name = "ACME E-commerce Terraform Service Account"
      description  = "Service account for Terraform operations"
    }
    "acme-orders-service-sa" = {
      account_id   = "acme-orders-service-sa"
      display_name = "ACME Orders Service Account"
      description  = "Service account for orders service"
    }
    "acme-customer-api-gke-sa" = {
      account_id   = "acme-customer-api-gke-sa"
      display_name = "ACME Customer API GKE Service Account"
      description  = "Service account for customer API in GKE"
    }
  }

  # Custom roles
  custom_roles = {
    "terraform-custom-role" = {
      role_id     = "terraform_custom_role"
      title       = "Terraform Custom Role"
      description = "Custom role for Terraform operations"
      permissions = [
        "compute.instances.create",
        "compute.instances.delete",
        "compute.instances.get",
        "compute.instances.list",
        "compute.instances.setMetadata",
        "compute.instances.setTags",
        "compute.instances.start",
        "compute.instances.stop",
        "compute.instances.update",
        "compute.instances.use",
        "compute.instances.attachDisk",
        "compute.instances.detachDisk",
        "compute.instances.reset",
        "compute.instances.setServiceAccount",
        "compute.instances.setShieldedInstanceIntegrityPolicy",
        "compute.instances.setShieldedVmIntegrityPolicy",
        "compute.instances.setShieldedInstanceIntegrityPolicy",
        "compute.instances.setShieldedVmIntegrityPolicy"
      ]
    }
  }

  # Service account roles - Only pass when IAM bindings are enabled
  service_account_roles = local.enable_iam_bindings ? {
    "terraform-editor" = {
      role                = "roles/editor"
      service_account_key = "acme-ecommerce-terraform-sa"
    }
    "app-storage-admin" = {
      role                = "roles/storage.admin"
      service_account_key = "acme-orders-service-sa"
    }
    "gke-cluster-admin" = {
      role                = "roles/container.clusterAdmin"
      service_account_key = "acme-customer-api-gke-sa"
    }
  } : {}

  # Project IAM bindings - Only pass when IAM bindings are enabled
  project_iam_bindings = local.enable_iam_bindings ? {
    "terraform-sa-editor" = {
      role   = "roles/editor"
      member = "serviceAccount:acme-ecommerce-terraform-sa@${local.project_id}.iam.gserviceaccount.com"
    }
  } : {}

  # Workload Identity Pool for GitHub Actions
  enable_workload_identity       = true
  workload_identity_pool_id      = "github-actions"
  workload_identity_display_name = "GitHub Actions Workload Identity Pool"
  workload_identity_description  = "Workload Identity Pool for GitHub Actions CI/CD"

  workload_identity_pool_provider_id      = "github-actions-provider"
  workload_identity_provider_display_name = "GitHub Actions Provider"
  workload_identity_provider_description  = "Workload Identity Provider for GitHub Actions"

  oidc_issuer_uri        = "https://token.actions.githubusercontent.com"
  oidc_allowed_audiences = ["https://github.com/catherinevee"]
}

# Global KMS Configuration
module "kms" {
  source = "../../../../modules/security/kms"

  project_id          = local.project_id
  environment         = local.environment
  region              = local.primary_region
  key_ring_name       = "${local.global_prefix}-keyring"
  enable_iam_bindings = local.enable_iam_bindings

  crypto_keys = {
    "acme-ecommerce-data-encryption-key" = {
      name            = "acme-ecommerce-data-encryption-key"
      purpose         = "ENCRYPT_DECRYPT"
      algorithm       = "GOOGLE_SYMMETRIC_ENCRYPTION"
      rotation_period = "7776000s" # 90 days
    }
    "acme-ecommerce-signing-key" = {
      name            = "acme-ecommerce-signing-key"
      purpose         = "ASYMMETRIC_SIGN"
      algorithm       = "EC_SIGN_P256_SHA256"
      rotation_period = "0s" # Asymmetric keys don't support automatic rotation
    }
  }

  # IAM bindings for crypto keys - Only pass when IAM bindings are enabled
  crypto_key_iam_bindings = local.enable_iam_bindings ? {
    "encryption-key-encrypt-decrypt" = {
      role = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
      members = [
        "serviceAccount:acme-ecommerce-terraform-sa@${local.project_id}.iam.gserviceaccount.com",
        "serviceAccount:acme-orders-service-sa@${local.project_id}.iam.gserviceaccount.com"
      ]
      crypto_key_key = "acme-ecommerce-data-encryption-key"
    }
    "signing-key-signer" = {
      role = "roles/cloudkms.signer"
      members = [
        "serviceAccount:acme-ecommerce-terraform-sa@${local.project_id}.iam.gserviceaccount.com"
      ]
      crypto_key_key = "acme-ecommerce-signing-key"
    }
  } : {}
}

# Global Secret Manager Configuration
module "secret_manager" {
  source = "../../../../modules/security/secret-manager"

  project_id          = local.project_id
  environment         = local.environment
  enable_iam_bindings = local.enable_iam_bindings

  secrets = {
    "database-password" = {
      secret_id = "cataziza-orders-database-password"
      replication = {
        automatic = true
      }
    }
    "vpn-shared-secret" = {
      secret_id = "cataziza-vpn-shared-secret"
      replication = {
        automatic = true
      }
    }
  }

  secret_versions = {
    "database-password-version" = {
      secret_key  = "database-password"
      secret_data = "your-database-password-here"
    }
    "vpn-shared-secret-version" = {
      secret_key  = "vpn-shared-secret"
      secret_data = "your-vpn-shared-secret-here"
    }
  }

  secret_iam_bindings = local.enable_iam_bindings ? {
    "database-password-access" = {
      secret_key = "database-password"
      role       = "roles/secretmanager.secretAccessor"
      members = [
        "serviceAccount:acme-orders-service-sa@${local.project_id}.iam.gserviceaccount.com"
      ]
    }
    "vpn-shared-secret-access" = {
      secret_key = "vpn-shared-secret"
      role       = "roles/secretmanager.secretAccessor"
      members = [
        "serviceAccount:acme-ecommerce-terraform-sa@${local.project_id}.iam.gserviceaccount.com"
      ]
    }
  } : {}
}

# Global Container Registry
module "container_registry" {
  source = "../../../../modules/storage/container-registry"

  project_id          = local.project_id
  environment         = local.environment
  region              = local.primary_region
  enable_iam_bindings = local.enable_iam_bindings

  repositories = {
    "app-images" = {
      repository_id = "${local.global_prefix}-application-images"
      description   = "Application container images"
      format        = "DOCKER"
    }
    "base-images" = {
      repository_id = "${local.global_prefix}-base-images"
      description   = "Base container images"
      format        = "DOCKER"
    }
  }

  # IAM bindings for repositories - Only pass when IAM bindings are enabled
  repository_iam_bindings = local.enable_iam_bindings ? {
    "app-images-access" = {
      repository_key = "app-images"
      role           = "roles/artifactregistry.reader"
      members = [
        "serviceAccount:acme-customer-api-gke-sa@${local.project_id}.iam.gserviceaccount.com",
        "serviceAccount:acme-orders-service-sa@${local.project_id}.iam.gserviceaccount.com"
      ]
    }
    "base-images-access" = {
      repository_key = "base-images"
      role           = "roles/artifactregistry.reader"
      members = [
        "serviceAccount:acme-customer-api-gke-sa@${local.project_id}.iam.gserviceaccount.com",
        "serviceAccount:acme-orders-service-sa@${local.project_id}.iam.gserviceaccount.com"
      ]
    }
  } : {}
}

# Global Monitoring Configuration
module "monitoring" {
  source = "../../../../modules/monitoring/cloud-monitoring"

  project_id  = local.project_id
  environment = local.environment

  # Alert policies for global resources
  alert_policies = {
    "high-cpu-usage" = {
      display_name = "ACME E-commerce Platform High CPU Usage Alert"
      documentation = {
        content   = "This alert fires when CPU usage is high across all regions"
        mime_type = "text/markdown"
      }
      conditions = [{
        display_name = "CPU usage is high"
        condition_threshold = {
          filter          = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
          comparison      = "COMPARISON_GT"
          threshold_value = var.monitoring_cpu_threshold_percent
          duration        = "300s"
          aggregations = [{
            alignment_period   = "300s"
            per_series_aligner = "ALIGN_MEAN"
          }]
        }
      }]
      notification_channels = []
    }
    "high-memory-usage" = {
      display_name = "ACME E-commerce Platform High Memory Usage Alert"
      documentation = {
        content   = "This alert fires when memory usage is high across all regions"
        mime_type = "text/markdown"
      }
      conditions = [{
        display_name = "Memory usage is high"
        condition_threshold = {
          filter          = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
          comparison      = "COMPARISON_GT"
          threshold_value = var.monitoring_memory_threshold_percent
          duration        = "300s"
          aggregations = [{
            alignment_period   = "300s"
            per_series_aligner = "ALIGN_MEAN"
          }]
        }
      }]
      notification_channels = []
    }
    "disk-space-low" = {
      display_name = "ACME E-commerce Platform Low Disk Space Alert"
      documentation = {
        content   = "This alert fires when disk space is low across all regions"
        mime_type = "text/markdown"
      }
      conditions = [{
        display_name = "Disk space is low"
        condition_threshold = {
          filter          = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
          comparison      = "COMPARISON_LT"
          threshold_value = var.monitoring_disk_threshold_percent
          duration        = "300s"
          aggregations = [{
            alignment_period   = "300s"
            per_series_aligner = "ALIGN_MEAN"
          }]
        }
      }]
      notification_channels = []
    }
  }

  # Monitoring services for global resources - Disabled due to service type incompatibility
  monitoring_services = {}

  # SLOs for global services - Disabled since monitoring service is disabled
  slos = {}
}

# Global Logging Configuration
module "logging" {
  source = "../../../../modules/monitoring/cloud-logging"

  project_id  = local.project_id
  environment = local.environment

  # Log sinks for global resources
  log_sinks = {
    "application-logs" = {
      name        = "${local.global_prefix}-application-logs-sink"
      destination = "bigquery.googleapis.com/projects/${local.project_id}/datasets/application_logs"
      filter      = "resource.type=\"http_load_balancer\" OR resource.type=\"cloud_run_revision\""
    }
    "audit-logs" = {
      name        = "${local.global_prefix}-audit-logs-sink"
      destination = "storage.googleapis.com/${local.global_prefix}-logs"
      filter      = "protoPayload.serviceName=\"cloudsql.googleapis.com\" OR protoPayload.serviceName=\"redis.googleapis.com\""
    }
    "security-logs" = {
      name        = "security-logs-sink"
      destination = "bigquery.googleapis.com/projects/${local.project_id}/datasets/security_logs"
      filter      = "severity>=ERROR AND resource.type=\"gce_instance\""
    }
  }

  # Log exclusions for global resources
  log_exclusions = {
    "debug-logs" = {
      name        = "${local.global_prefix}-debug-logs-exclusion"
      description = "Exclude debug level logs"
      filter      = "severity=\"DEBUG\""
    }
    "health-check-logs" = {
      name        = "${local.global_prefix}-health-check-logs-exclusion"
      description = "Exclude health check logs"
      filter      = "resource.type=\"http_load_balancer\" AND httpRequest.requestUrl=\"/health\""
    }
  }
}

# Outputs for global resources
output "vpc_network_name" {
  description = "Name of the global VPC network"
  value       = module.vpc.network_name
}

output "vpc_network_self_link" {
  description = "Self-link of the global VPC network"
  value       = module.vpc.network_self_link
}

# output "load_balancer_ip" {
#   description = "Global load balancer IP address"
#   value       = module.load_balancer.global_ip_address
# }
# 
# output "dns_zone_name" {
#   description = "DNS zone name"
#   value       = module.dns.zone_name
# }

output "service_accounts" {
  description = "Global service account emails"
  value       = module.iam.service_account_emails
}

output "kms_key_ring" {
  description = "KMS key ring name"
  value       = module.kms.key_ring_name
}

output "crypto_keys" {
  description = "Crypto key names and purposes"
  value       = module.kms.crypto_key_names
}

output "secrets" {
  description = "Secret Manager secret names"
  value       = module.secret_manager.secret_names
}

output "container_repositories" {
  description = "Container registry repository names"
  value       = module.container_registry.repository_names
}

output "alert_policies" {
  description = "Global alert policy names"
  value       = module.monitoring.alert_policy_names
}

output "log_sinks" {
  description = "Global log sink names"
  value       = module.logging.log_sink_names
}

output "log_exclusions" {
  description = "Global log exclusion names"
  value       = module.logging.log_exclusion_names
}

