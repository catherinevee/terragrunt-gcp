# App Engine Module - Main Configuration

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0"
    }
  }
}

# Local variables
locals {
  app_id = var.app_id != null ? var.app_id : var.project_id

  labels = merge(
    {
      environment = var.environment
      managed_by  = "terraform"
      service     = "app-engine"
    },
    var.labels
  )

  service_name = var.service_name != null ? var.service_name : "default"

  # App Engine location mapping
  location_map = {
    us-central1     = "us-central"
    europe-west1    = "europe-west"
    asia-northeast1 = "asia-northeast1"
  }

  app_location = lookup(local.location_map, var.region, var.region)
}

# App Engine Application
resource "google_app_engine_application" "app" {
  count = var.create_application ? 1 : 0

  project     = var.project_id
  location_id = local.app_location

  auth_domain    = var.auth_domain
  serving_status = var.serving_status

  dynamic "feature_settings" {
    for_each = var.feature_settings != null ? [var.feature_settings] : []
    content {
      split_health_checks = feature_settings.value.split_health_checks
    }
  }

  database_type = var.database_type
}

# App Engine Service (Standard Environment)
resource "google_app_engine_standard_app_version" "standard" {
  count = var.environment_type == "standard" && var.deploy_version ? 1 : 0

  project    = var.project_id
  service    = local.service_name
  version_id = var.version_id != null ? var.version_id : "v${replace(timestamp(), ":", "-")}"
  runtime    = var.runtime

  # Scaling configuration
  dynamic "automatic_scaling" {
    for_each = var.scaling_type == "automatic" ? [var.automatic_scaling] : []
    content {
      min_idle_instances      = automatic_scaling.value.min_idle_instances
      max_idle_instances      = automatic_scaling.value.max_idle_instances
      min_pending_latency     = automatic_scaling.value.min_pending_latency
      max_pending_latency     = automatic_scaling.value.max_pending_latency
      max_concurrent_requests = automatic_scaling.value.max_concurrent_requests

      dynamic "standard_scheduler_settings" {
        for_each = automatic_scaling.value.standard_scheduler_settings != null ? [automatic_scaling.value.standard_scheduler_settings] : []
        content {
          target_cpu_utilization        = standard_scheduler_settings.value.target_cpu_utilization
          target_throughput_utilization = standard_scheduler_settings.value.target_throughput_utilization
          min_instances                 = standard_scheduler_settings.value.min_instances
          max_instances                 = standard_scheduler_settings.value.max_instances
        }
      }
    }
  }

  dynamic "manual_scaling" {
    for_each = var.scaling_type == "manual" ? [var.manual_scaling] : []
    content {
      instances = manual_scaling.value.instances
    }
  }

  dynamic "basic_scaling" {
    for_each = var.scaling_type == "basic" ? [var.basic_scaling] : []
    content {
      max_instances = basic_scaling.value.max_instances
      idle_timeout  = basic_scaling.value.idle_timeout
    }
  }

  # Deployment
  deployment {
    dynamic "zip" {
      for_each = var.deployment_zip != null ? [var.deployment_zip] : []
      content {
        source_url  = zip.value.source_url
        files_count = zip.value.files_count
      }
    }

    dynamic "files" {
      for_each = var.deployment_files
      content {
        name       = files.key
        source_url = files.value
      }
    }
  }

  # Entrypoint
  entrypoint {
    shell = var.entrypoint_shell
  }

  # Environment variables
  env_variables = var.env_variables

  # Handlers
  dynamic "handlers" {
    for_each = var.handlers
    content {
      url_regex                   = handlers.value.url_regex
      security_level              = try(handlers.value.security_level, null)
      login                       = try(handlers.value.login, null)
      auth_fail_action            = try(handlers.value.auth_fail_action, null)
      redirect_http_response_code = try(handlers.value.redirect_http_response_code, null)

      dynamic "static_files" {
        for_each = try(handlers.value.static_files, null) != null ? [handlers.value.static_files] : []
        content {
          path                  = static_files.value.path
          upload_path_regex     = static_files.value.upload_path_regex
          http_headers          = try(static_files.value.http_headers, null)
          mime_type             = try(static_files.value.mime_type, null)
          expiration            = try(static_files.value.expiration, null)
          require_matching_file = try(static_files.value.require_matching_file, null)
          application_readable  = try(static_files.value.application_readable, null)
        }
      }

      dynamic "script" {
        for_each = try(handlers.value.script, null) != null ? [handlers.value.script] : []
        content {
          script_path = script.value.script_path
        }
      }
    }
  }

  # Libraries
  dynamic "libraries" {
    for_each = var.libraries
    content {
      name    = libraries.value.name
      version = libraries.value.version
    }
  }

  # Instance class
  instance_class = var.instance_class

  # Inbound services
  inbound_services = var.inbound_services

  # VPC Access Connector
  vpc_access_connector {
    name           = var.vpc_connector_name
    egress_setting = var.vpc_egress_setting
  }

  # Delete behavior
  delete_service_on_destroy = var.delete_service_on_destroy
  noop_on_destroy           = var.noop_on_destroy

  lifecycle {
    create_before_destroy = true
    ignore_changes        = var.ignore_changes
  }
}

# App Engine Service (Flexible Environment)
resource "google_app_engine_flexible_app_version" "flexible" {
  count = var.environment_type == "flexible" && var.deploy_version ? 1 : 0

  project    = var.project_id
  service    = local.service_name
  version_id = var.version_id != null ? var.version_id : "v${replace(timestamp(), ":", "-")}"
  runtime    = var.runtime

  # Runtime channel
  runtime_channel = var.runtime_channel

  # Scaling configuration
  dynamic "automatic_scaling" {
    for_each = var.scaling_type == "automatic" ? [var.automatic_scaling_flex] : []
    content {
      min_total_instances = automatic_scaling.value.min_total_instances
      max_total_instances = automatic_scaling.value.max_total_instances
      cool_down_period    = automatic_scaling.value.cool_down_period

      dynamic "cpu_utilization" {
        for_each = automatic_scaling.value.cpu_utilization != null ? [automatic_scaling.value.cpu_utilization] : []
        content {
          target_utilization        = cpu_utilization.value.target_utilization
          aggregation_window_length = cpu_utilization.value.aggregation_window_length
        }
      }

      dynamic "disk_utilization" {
        for_each = automatic_scaling.value.disk_utilization != null ? [automatic_scaling.value.disk_utilization] : []
        content {
          target_write_bytes_per_second = disk_utilization.value.target_write_bytes_per_second
          target_write_ops_per_second   = disk_utilization.value.target_write_ops_per_second
          target_read_bytes_per_second  = disk_utilization.value.target_read_bytes_per_second
          target_read_ops_per_second    = disk_utilization.value.target_read_ops_per_second
        }
      }

      dynamic "network_utilization" {
        for_each = automatic_scaling.value.network_utilization != null ? [automatic_scaling.value.network_utilization] : []
        content {
          target_sent_bytes_per_second       = network_utilization.value.target_sent_bytes_per_second
          target_sent_packets_per_second     = network_utilization.value.target_sent_packets_per_second
          target_received_bytes_per_second   = network_utilization.value.target_received_bytes_per_second
          target_received_packets_per_second = network_utilization.value.target_received_packets_per_second
        }
      }

      dynamic "request_utilization" {
        for_each = automatic_scaling.value.request_utilization != null ? [automatic_scaling.value.request_utilization] : []
        content {
          target_request_count_per_second = request_utilization.value.target_request_count_per_second
          target_concurrent_requests      = request_utilization.value.target_concurrent_requests
        }
      }
    }
  }

  dynamic "manual_scaling" {
    for_each = var.scaling_type == "manual" ? [var.manual_scaling_flex] : []
    content {
      instances = manual_scaling.value.instances
    }
  }

  # Resources
  resources {
    cpu       = var.resources.cpu
    memory_gb = var.resources.memory_gb
    disk_gb   = var.resources.disk_gb

    dynamic "volumes" {
      for_each = var.resources.volumes
      content {
        name        = volumes.value.name
        volume_type = volumes.value.volume_type
        size_gb     = volumes.value.size_gb
      }
    }
  }

  # Network
  network {
    name             = var.network_name
    subnetwork       = var.subnetwork_name
    instance_tag     = var.instance_tag
    forwarded_ports  = var.forwarded_ports
    session_affinity = var.session_affinity
  }

  # Beta settings
  beta_settings = var.beta_settings

  # Environment variables
  env_variables = var.env_variables

  # Deployment
  deployment {
    dynamic "container" {
      for_each = var.deployment_container != null ? [var.deployment_container] : []
      content {
        image = container.value.image
      }
    }

    dynamic "zip" {
      for_each = var.deployment_zip != null ? [var.deployment_zip] : []
      content {
        source_url  = zip.value.source_url
        files_count = zip.value.files_count
      }
    }

    dynamic "files" {
      for_each = var.deployment_files
      content {
        name       = files.key
        source_url = files.value
      }
    }

    dynamic "cloud_build_options" {
      for_each = var.cloud_build_options != null ? [var.cloud_build_options] : []
      content {
        app_yaml_path       = cloud_build_options.value.app_yaml_path
        cloud_build_timeout = cloud_build_options.value.cloud_build_timeout
      }
    }
  }

  # Endpoints API
  dynamic "endpoints_api_service" {
    for_each = var.endpoints_api_service != null ? [var.endpoints_api_service] : []
    content {
      name                   = endpoints_api_service.value.name
      config_id              = endpoints_api_service.value.config_id
      rollout_strategy       = endpoints_api_service.value.rollout_strategy
      disable_trace_sampling = endpoints_api_service.value.disable_trace_sampling
    }
  }

  # API Config
  dynamic "api_config" {
    for_each = var.api_config != null ? [var.api_config] : []
    content {
      auth_fail_action = api_config.value.auth_fail_action
      login            = api_config.value.login
      script           = api_config.value.script
      security_level   = api_config.value.security_level
      url              = api_config.value.url
    }
  }

  # Liveness check
  liveness_check {
    path              = var.liveness_check.path
    host              = var.liveness_check.host
    failure_threshold = var.liveness_check.failure_threshold
    success_threshold = var.liveness_check.success_threshold
    check_interval    = var.liveness_check.check_interval
    timeout           = var.liveness_check.timeout
    initial_delay     = var.liveness_check.initial_delay
  }

  # Readiness check
  readiness_check {
    path              = var.readiness_check.path
    host              = var.readiness_check.host
    failure_threshold = var.readiness_check.failure_threshold
    success_threshold = var.readiness_check.success_threshold
    check_interval    = var.readiness_check.check_interval
    timeout           = var.readiness_check.timeout
    app_start_timeout = var.readiness_check.app_start_timeout
  }

  # Delete behavior
  delete_service_on_destroy = var.delete_service_on_destroy
  noop_on_destroy           = var.noop_on_destroy

  lifecycle {
    create_before_destroy = true
    ignore_changes        = var.ignore_changes
  }
}

# App Engine Domain Mapping
resource "google_app_engine_domain_mapping" "domain" {
  for_each = var.domain_mappings

  project     = var.project_id
  domain_name = each.value.domain_name

  dynamic "ssl_settings" {
    for_each = each.value.ssl_settings != null ? [each.value.ssl_settings] : []
    content {
      ssl_management_type = ssl_settings.value.ssl_management_type
      certificate_id      = ssl_settings.value.certificate_id
    }
  }
}

# App Engine Firewall Rules
resource "google_app_engine_firewall_rule" "rules" {
  for_each = var.firewall_rules

  project      = var.project_id
  priority     = each.value.priority
  action       = each.value.action
  source_range = each.value.source_range
  description  = each.value.description
}

# App Engine Service IAM
resource "google_app_engine_service_iam_member" "members" {
  for_each = var.service_iam_members

  project = var.project_id
  service = each.value.service
  role    = each.value.role
  member  = each.value.member
}