# Google Compute Managed Instance Group Module
# Creates and manages GCE managed instance groups with auto-scaling

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

locals {
  # Distribution zones
  distribution_zones = var.distribution_zones != null ? var.distribution_zones : (
    var.regional ? data.google_compute_zones.available[0].names : [var.zone]
  )

  # Base instance name
  base_instance_name = var.base_instance_name != null ? var.base_instance_name : var.name

  # Health check name
  health_check_name = var.health_check_name != null ? var.health_check_name : "${var.name}-hc"

  # Service account
  service_account_email = var.service_account_email != null ? var.service_account_email : (
    var.create_service_account ? google_service_account.mig[0].email : null
  )
}

# Get available zones for regional MIG
data "google_compute_zones" "available" {
  count   = var.regional && var.distribution_zones == null ? 1 : 0
  project = var.project_id
  region  = var.region
  status  = "UP"
}

# Service account for the MIG instances
resource "google_service_account" "mig" {
  count        = var.create_service_account ? 1 : 0
  project      = var.project_id
  account_id   = "${var.name}-sa"
  display_name = "${var.name} MIG Service Account"
  description  = "Service account for managed instance group ${var.name}"
}

# IAM bindings for service account
resource "google_project_iam_member" "mig_sa" {
  for_each = var.create_service_account ? toset(var.service_account_roles) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.mig[0].email}"
}

# Instance Template
resource "google_compute_instance_template" "template" {
  project     = var.project_id
  name_prefix = "${var.name}-template-"
  description = var.instance_template_description

  machine_type      = var.machine_type
  min_cpu_platform  = var.min_cpu_platform
  can_ip_forward    = var.can_ip_forward
  enable_display    = var.enable_display
  resource_policies = var.resource_policies

  # Boot disk
  disk {
    source_image = var.source_image
    auto_delete  = var.boot_disk_auto_delete
    boot         = true
    disk_name    = var.boot_disk_name
    disk_size_gb = var.boot_disk_size_gb
    disk_type    = var.boot_disk_type

    dynamic "disk_encryption_key" {
      for_each = var.boot_disk_kms_key_self_link != null ? [1] : []
      content {
        kms_key_self_link = var.boot_disk_kms_key_self_link
      }
    }
  }

  # Additional disks
  dynamic "disk" {
    for_each = var.additional_disks
    content {
      auto_delete  = lookup(disk.value, "auto_delete", true)
      boot         = false
      disk_name    = lookup(disk.value, "disk_name", null)
      disk_size_gb = lookup(disk.value, "disk_size_gb", null)
      disk_type    = lookup(disk.value, "disk_type", "pd-standard")
      source_image = lookup(disk.value, "source_image", null)
      source       = lookup(disk.value, "source", null)
      mode         = lookup(disk.value, "mode", "READ_WRITE")
      type         = lookup(disk.value, "type", "PERSISTENT")

      dynamic "disk_encryption_key" {
        for_each = lookup(disk.value, "kms_key_self_link", null) != null ? [1] : []
        content {
          kms_key_self_link = disk.value.kms_key_self_link
        }
      }
    }
  }

  # Network interfaces
  dynamic "network_interface" {
    for_each = var.network_interfaces
    content {
      network            = lookup(network_interface.value, "network", "default")
      subnetwork         = lookup(network_interface.value, "subnetwork", null)
      subnetwork_project = lookup(network_interface.value, "subnetwork_project", var.project_id)
      network_ip         = lookup(network_interface.value, "network_ip", null)
      nic_type           = lookup(network_interface.value, "nic_type", null)
      stack_type         = lookup(network_interface.value, "stack_type", "IPV4_ONLY")
      queue_count        = lookup(network_interface.value, "queue_count", null)

      dynamic "access_config" {
        for_each = lookup(network_interface.value, "access_config", [])
        content {
          nat_ip       = lookup(access_config.value, "nat_ip", null)
          network_tier = lookup(access_config.value, "network_tier", "STANDARD")
        }
      }

      dynamic "ipv6_access_config" {
        for_each = lookup(network_interface.value, "ipv6_access_config", [])
        content {
          network_tier = lookup(ipv6_access_config.value, "network_tier", "PREMIUM")
        }
      }

      dynamic "alias_ip_range" {
        for_each = lookup(network_interface.value, "alias_ip_range", [])
        content {
          ip_cidr_range         = alias_ip_range.value.ip_cidr_range
          subnetwork_range_name = lookup(alias_ip_range.value, "subnetwork_range_name", null)
        }
      }
    }
  }

  # Service account
  service_account {
    email  = local.service_account_email
    scopes = var.service_account_scopes
  }

  # Metadata
  metadata = merge(
    var.metadata,
    var.enable_oslogin ? { enable-oslogin = "TRUE" } : {},
    var.startup_script != null ? { startup-script = var.startup_script } : {},
    var.shutdown_script != null ? { shutdown-script = var.shutdown_script } : {}
  )

  # Labels
  labels = var.labels

  # Tags
  tags = var.tags

  # Guest accelerators
  dynamic "guest_accelerator" {
    for_each = var.guest_accelerators
    content {
      type  = guest_accelerator.value.type
      count = guest_accelerator.value.count
    }
  }

  # Scheduling
  scheduling {
    preemptible                 = var.preemptible
    automatic_restart           = var.preemptible ? false : var.automatic_restart
    on_host_maintenance         = var.on_host_maintenance
    provisioning_model          = var.provisioning_model
    instance_termination_action = var.instance_termination_action

    dynamic "node_affinities" {
      for_each = var.node_affinities
      content {
        key      = node_affinities.value.key
        operator = node_affinities.value.operator
        values   = node_affinities.value.values
      }
    }
  }

  # Shielded instance config
  shielded_instance_config {
    enable_secure_boot          = var.enable_secure_boot
    enable_vtpm                 = var.enable_vtpm
    enable_integrity_monitoring = var.enable_integrity_monitoring
  }

  # Confidential instance config
  dynamic "confidential_instance_config" {
    for_each = var.enable_confidential_compute ? [1] : []
    content {
      enable_confidential_compute = true
    }
  }

  # Advanced machine features
  dynamic "advanced_machine_features" {
    for_each = var.advanced_machine_features != null ? [var.advanced_machine_features] : []
    content {
      enable_nested_virtualization = lookup(advanced_machine_features.value, "enable_nested_virtualization", null)
      threads_per_core             = lookup(advanced_machine_features.value, "threads_per_core", null)
      visible_core_count           = lookup(advanced_machine_features.value, "visible_core_count", null)
    }
  }

  # Reservation affinity
  dynamic "reservation_affinity" {
    for_each = var.reservation_affinity != null ? [var.reservation_affinity] : []
    content {
      type = reservation_affinity.value.type

      dynamic "specific_reservation" {
        for_each = lookup(reservation_affinity.value, "specific_reservation", null) != null ? [reservation_affinity.value.specific_reservation] : []
        content {
          key    = specific_reservation.value.key
          values = specific_reservation.value.values
        }
      }
    }
  }

  # Network performance config
  dynamic "network_performance_config" {
    for_each = var.network_performance_config != null ? [var.network_performance_config] : []
    content {
      total_egress_bandwidth_tier = network_performance_config.value.total_egress_bandwidth_tier
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Health Check
resource "google_compute_health_check" "health_check" {
  count = var.create_health_check ? 1 : 0

  project             = var.project_id
  name                = local.health_check_name
  description         = "Health check for ${var.name}"
  check_interval_sec  = var.health_check_interval_sec
  timeout_sec         = var.health_check_timeout_sec
  healthy_threshold   = var.health_check_healthy_threshold
  unhealthy_threshold = var.health_check_unhealthy_threshold

  dynamic "http_health_check" {
    for_each = var.health_check_type == "http" ? [1] : []
    content {
      port               = var.health_check_port
      request_path       = var.health_check_request_path
      host               = var.health_check_host
      response           = var.health_check_response
      proxy_header       = var.health_check_proxy_header
      port_specification = var.health_check_port_specification
    }
  }

  dynamic "https_health_check" {
    for_each = var.health_check_type == "https" ? [1] : []
    content {
      port               = var.health_check_port
      request_path       = var.health_check_request_path
      host               = var.health_check_host
      response           = var.health_check_response
      proxy_header       = var.health_check_proxy_header
      port_specification = var.health_check_port_specification
    }
  }

  dynamic "tcp_health_check" {
    for_each = var.health_check_type == "tcp" ? [1] : []
    content {
      port               = var.health_check_port
      request            = var.health_check_tcp_request
      response           = var.health_check_tcp_response
      proxy_header       = var.health_check_proxy_header
      port_specification = var.health_check_port_specification
    }
  }

  dynamic "ssl_health_check" {
    for_each = var.health_check_type == "ssl" ? [1] : []
    content {
      port               = var.health_check_port
      request            = var.health_check_tcp_request
      response           = var.health_check_tcp_response
      proxy_header       = var.health_check_proxy_header
      port_specification = var.health_check_port_specification
    }
  }

  dynamic "grpc_health_check" {
    for_each = var.health_check_type == "grpc" ? [1] : []
    content {
      port               = var.health_check_port
      grpc_service_name  = var.health_check_grpc_service_name
      port_specification = var.health_check_port_specification
    }
  }

  dynamic "log_config" {
    for_each = var.health_check_enable_logging ? [1] : []
    content {
      enable = true
    }
  }
}

# Regional Managed Instance Group
resource "google_compute_region_instance_group_manager" "mig" {
  count = var.regional ? 1 : 0

  project            = var.project_id
  name               = var.name
  base_instance_name = local.base_instance_name
  region             = var.region
  description        = var.description

  version {
    instance_template = google_compute_instance_template.template.self_link
    name              = "primary"
  }

  # Additional versions for canary deployments
  dynamic "version" {
    for_each = var.versions
    content {
      instance_template = version.value.instance_template
      name              = version.value.name

      dynamic "target_size" {
        for_each = lookup(version.value, "target_size", null) != null ? [version.value.target_size] : []
        content {
          fixed   = lookup(target_size.value, "fixed", null)
          percent = lookup(target_size.value, "percent", null)
        }
      }
    }
  }

  target_size               = var.target_size
  target_pools              = var.target_pools
  distribution_policy_zones = local.distribution_zones

  dynamic "distribution_policy_target_shape" {
    for_each = var.distribution_policy_target_shape != null ? [1] : []
    content {
      shape = var.distribution_policy_target_shape
    }
  }

  # Named ports
  dynamic "named_port" {
    for_each = var.named_ports
    content {
      name = named_port.value.name
      port = named_port.value.port
    }
  }

  # Auto-healing policies
  dynamic "auto_healing_policies" {
    for_each = var.create_health_check || var.health_check_id != null ? [1] : []
    content {
      health_check      = var.health_check_id != null ? var.health_check_id : google_compute_health_check.health_check[0].id
      initial_delay_sec = var.auto_healing_initial_delay_sec
    }
  }

  # Update policy
  dynamic "update_policy" {
    for_each = var.update_policy != null ? [var.update_policy] : []
    content {
      type                           = lookup(update_policy.value, "type", "OPPORTUNISTIC")
      instance_redistribution_type   = lookup(update_policy.value, "instance_redistribution_type", "PROACTIVE")
      minimal_action                 = lookup(update_policy.value, "minimal_action", "REPLACE")
      most_disruptive_allowed_action = lookup(update_policy.value, "most_disruptive_allowed_action", null)
      max_surge_fixed                = lookup(update_policy.value, "max_surge_fixed", null)
      max_surge_percent              = lookup(update_policy.value, "max_surge_percent", null)
      max_unavailable_fixed          = lookup(update_policy.value, "max_unavailable_fixed", null)
      max_unavailable_percent        = lookup(update_policy.value, "max_unavailable_percent", null)
      min_ready_sec                  = lookup(update_policy.value, "min_ready_sec", null)
      replacement_method             = lookup(update_policy.value, "replacement_method", "SUBSTITUTE")
    }
  }

  # Stateful configuration
  dynamic "stateful_disk" {
    for_each = var.stateful_disks
    content {
      device_name = stateful_disk.value.device_name
      delete_rule = lookup(stateful_disk.value, "delete_rule", "NEVER")
    }
  }

  dynamic "stateful_internal_ip" {
    for_each = var.stateful_internal_ips
    content {
      interface_name = stateful_internal_ip.value.interface_name
      delete_rule    = lookup(stateful_internal_ip.value, "delete_rule", "NEVER")
    }
  }

  dynamic "stateful_external_ip" {
    for_each = var.stateful_external_ips
    content {
      interface_name = stateful_external_ip.value.interface_name
      delete_rule    = lookup(stateful_external_ip.value, "delete_rule", "NEVER")
    }
  }

  # Instance lifecycle policy
  dynamic "instance_lifecycle_policy" {
    for_each = var.instance_lifecycle_policy != null ? [var.instance_lifecycle_policy] : []
    content {
      default_action_on_failure = lookup(instance_lifecycle_policy.value, "default_action_on_failure", "REPAIR")
      force_update_on_repair    = lookup(instance_lifecycle_policy.value, "force_update_on_repair", "NO")
    }
  }

  wait_for_instances        = var.wait_for_instances
  wait_for_instances_status = var.wait_for_instances_status

  timeouts {
    create = var.mig_timeouts.create
    update = var.mig_timeouts.update
    delete = var.mig_timeouts.delete
  }

  lifecycle {
    create_before_destroy = true
    # ignore_changes must be static, not variable
    ignore_changes = []
  }
}

# Zonal Managed Instance Group
resource "google_compute_instance_group_manager" "mig" {
  count = !var.regional ? 1 : 0

  project            = var.project_id
  name               = var.name
  base_instance_name = local.base_instance_name
  zone               = var.zone
  description        = var.description

  version {
    instance_template = google_compute_instance_template.template.self_link
    name              = "primary"
  }

  # Additional versions for canary deployments
  dynamic "version" {
    for_each = var.versions
    content {
      instance_template = version.value.instance_template
      name              = version.value.name

      dynamic "target_size" {
        for_each = lookup(version.value, "target_size", null) != null ? [version.value.target_size] : []
        content {
          fixed   = lookup(target_size.value, "fixed", null)
          percent = lookup(target_size.value, "percent", null)
        }
      }
    }
  }

  target_size  = var.target_size
  target_pools = var.target_pools

  # Named ports
  dynamic "named_port" {
    for_each = var.named_ports
    content {
      name = named_port.value.name
      port = named_port.value.port
    }
  }

  # Auto-healing policies
  dynamic "auto_healing_policies" {
    for_each = var.create_health_check || var.health_check_id != null ? [1] : []
    content {
      health_check      = var.health_check_id != null ? var.health_check_id : google_compute_health_check.health_check[0].id
      initial_delay_sec = var.auto_healing_initial_delay_sec
    }
  }

  # Update policy
  dynamic "update_policy" {
    for_each = var.update_policy != null ? [var.update_policy] : []
    content {
      type                           = lookup(update_policy.value, "type", "OPPORTUNISTIC")
      minimal_action                 = lookup(update_policy.value, "minimal_action", "REPLACE")
      most_disruptive_allowed_action = lookup(update_policy.value, "most_disruptive_allowed_action", null)
      max_surge_fixed                = lookup(update_policy.value, "max_surge_fixed", null)
      max_surge_percent              = lookup(update_policy.value, "max_surge_percent", null)
      max_unavailable_fixed          = lookup(update_policy.value, "max_unavailable_fixed", null)
      max_unavailable_percent        = lookup(update_policy.value, "max_unavailable_percent", null)
      min_ready_sec                  = lookup(update_policy.value, "min_ready_sec", null)
      replacement_method             = lookup(update_policy.value, "replacement_method", "SUBSTITUTE")
    }
  }

  # Stateful configuration
  dynamic "stateful_disk" {
    for_each = var.stateful_disks
    content {
      device_name = stateful_disk.value.device_name
      delete_rule = lookup(stateful_disk.value, "delete_rule", "NEVER")
    }
  }

  dynamic "stateful_internal_ip" {
    for_each = var.stateful_internal_ips
    content {
      interface_name = stateful_internal_ip.value.interface_name
      delete_rule    = lookup(stateful_internal_ip.value, "delete_rule", "NEVER")
    }
  }

  dynamic "stateful_external_ip" {
    for_each = var.stateful_external_ips
    content {
      interface_name = stateful_external_ip.value.interface_name
      delete_rule    = lookup(stateful_external_ip.value, "delete_rule", "NEVER")
    }
  }

  # Instance lifecycle policy
  dynamic "instance_lifecycle_policy" {
    for_each = var.instance_lifecycle_policy != null ? [var.instance_lifecycle_policy] : []
    content {
      default_action_on_failure = lookup(instance_lifecycle_policy.value, "default_action_on_failure", "REPAIR")
      force_update_on_repair    = lookup(instance_lifecycle_policy.value, "force_update_on_repair", "NO")
    }
  }

  wait_for_instances        = var.wait_for_instances
  wait_for_instances_status = var.wait_for_instances_status

  timeouts {
    create = var.mig_timeouts.create
    update = var.mig_timeouts.update
    delete = var.mig_timeouts.delete
  }

  lifecycle {
    create_before_destroy = true
    # ignore_changes must be static, not variable
    ignore_changes = []
  }
}

# Autoscaler for Regional MIG
resource "google_compute_region_autoscaler" "autoscaler" {
  count = var.regional && var.autoscaling_enabled ? 1 : 0

  project = var.project_id
  name    = "${var.name}-autoscaler"
  region  = var.region
  target  = google_compute_region_instance_group_manager.mig[0].id

  autoscaling_policy {
    max_replicas    = var.max_replicas
    min_replicas    = var.min_replicas
    cooldown_period = var.autoscaling_cooldown_period

    dynamic "cpu_utilization" {
      for_each = var.autoscaling_cpu != null ? [var.autoscaling_cpu] : []
      content {
        target            = cpu_utilization.value.target
        predictive_method = lookup(cpu_utilization.value, "predictive_method", null)
      }
    }

    dynamic "metric" {
      for_each = var.autoscaling_metrics
      content {
        name   = metric.value.name
        target = metric.value.target
        type   = lookup(metric.value, "type", "GAUGE")
      }
    }

    dynamic "load_balancing_utilization" {
      for_each = var.autoscaling_load_balancing_utilization != null ? [var.autoscaling_load_balancing_utilization] : []
      content {
        target = load_balancing_utilization.value.target
      }
    }

    dynamic "scale_in_control" {
      for_each = var.autoscaling_scale_in_control != null ? [var.autoscaling_scale_in_control] : []
      content {
        max_scaled_in_replicas {
          fixed   = lookup(scale_in_control.value, "max_scaled_in_replicas_fixed", null)
          percent = lookup(scale_in_control.value, "max_scaled_in_replicas_percent", null)
        }
        time_window_sec = lookup(scale_in_control.value, "time_window_sec", null)
      }
    }

    mode = var.autoscaling_mode
  }

  timeouts {
    create = var.autoscaler_timeouts.create
    update = var.autoscaler_timeouts.update
    delete = var.autoscaler_timeouts.delete
  }
}

# Autoscaler for Zonal MIG
resource "google_compute_autoscaler" "autoscaler" {
  count = !var.regional && var.autoscaling_enabled ? 1 : 0

  project = var.project_id
  name    = "${var.name}-autoscaler"
  zone    = var.zone
  target  = google_compute_instance_group_manager.mig[0].id

  autoscaling_policy {
    max_replicas    = var.max_replicas
    min_replicas    = var.min_replicas
    cooldown_period = var.autoscaling_cooldown_period

    dynamic "cpu_utilization" {
      for_each = var.autoscaling_cpu != null ? [var.autoscaling_cpu] : []
      content {
        target            = cpu_utilization.value.target
        predictive_method = lookup(cpu_utilization.value, "predictive_method", null)
      }
    }

    dynamic "metric" {
      for_each = var.autoscaling_metrics
      content {
        name   = metric.value.name
        target = metric.value.target
        type   = lookup(metric.value, "type", "GAUGE")
      }
    }

    dynamic "load_balancing_utilization" {
      for_each = var.autoscaling_load_balancing_utilization != null ? [var.autoscaling_load_balancing_utilization] : []
      content {
        target = load_balancing_utilization.value.target
      }
    }

    dynamic "scale_in_control" {
      for_each = var.autoscaling_scale_in_control != null ? [var.autoscaling_scale_in_control] : []
      content {
        max_scaled_in_replicas {
          fixed   = lookup(scale_in_control.value, "max_scaled_in_replicas_fixed", null)
          percent = lookup(scale_in_control.value, "max_scaled_in_replicas_percent", null)
        }
        time_window_sec = lookup(scale_in_control.value, "time_window_sec", null)
      }
    }

    mode = var.autoscaling_mode
  }

  timeouts {
    create = var.autoscaler_timeouts.create
    update = var.autoscaler_timeouts.update
    delete = var.autoscaler_timeouts.delete
  }
}