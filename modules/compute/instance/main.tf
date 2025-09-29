# Google Compute Instance Module
# Creates and manages GCE VM instances with comprehensive configuration

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
  # Instance naming
  instance_name = var.name != null ? var.name : "${var.name_prefix}-${random_id.instance_suffix[0].hex}"

  # Zone selection
  zone = var.zone != null ? var.zone : data.google_compute_zones.available[0].names[0]

  # Network configuration
  network_interface = var.network_interface != null ? var.network_interface : [{
    network    = var.network
    subnetwork = var.subnetwork
    network_ip = var.network_ip
    stack_type = var.stack_type

    access_config = var.enable_external_ip ? [{
      nat_ip                 = var.nat_ip
      network_tier           = var.network_tier
      public_ptr_domain_name = var.public_ptr_domain_name
    }] : []

    ipv6_access_config = var.enable_ipv6 ? [{
      network_tier = var.network_tier
    }] : []

    alias_ip_range = var.alias_ip_ranges
  }]

  # Service account configuration
  service_account_email = var.service_account_email != null ? var.service_account_email : (
    var.create_service_account ? google_service_account.instance[0].email : null
  )

  # Labels with defaults
  labels = merge(
    var.labels,
    {
      managed_by  = "terraform"
      module      = "compute-instance"
      environment = var.environment
      created_at  = formatdate("YYYY-MM-DD", timestamp())
    }
  )

  # Metadata with OS Login configuration
  metadata = merge(
    var.metadata,
    var.enable_oslogin ? { enable-oslogin = "TRUE" } : {},
    var.enable_oslogin_2fa ? { enable-oslogin-2fa = "TRUE" } : {},
    var.startup_script != null ? { startup-script = var.startup_script } : {},
    var.shutdown_script != null ? { shutdown-script = var.shutdown_script } : {},
    var.metadata_startup_script != null ? { startup-script = var.metadata_startup_script } : {}
  )
}

# Random suffix for instance naming
resource "random_id" "instance_suffix" {
  count       = var.name == null ? 1 : 0
  byte_length = 4

  keepers = {
    machine_type = var.machine_type
    zone         = local.zone
  }
}

# Get available zones if not specified
data "google_compute_zones" "available" {
  count   = var.zone == null ? 1 : 0
  project = var.project_id
  region  = var.region
  status  = "UP"
}

# Service account for the instance
resource "google_service_account" "instance" {
  count        = var.create_service_account ? 1 : 0
  project      = var.project_id
  account_id   = "${local.instance_name}-sa"
  display_name = "${local.instance_name} Service Account"
  description  = "Service account for compute instance ${local.instance_name}"
}

# IAM binding for service account
resource "google_project_iam_member" "instance_sa" {
  for_each = var.create_service_account ? toset(var.service_account_roles) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.instance[0].email}"
}

# Main compute instance
resource "google_compute_instance" "instance" {
  project = var.project_id
  name    = local.instance_name
  zone    = local.zone

  machine_type              = var.machine_type
  min_cpu_platform          = var.min_cpu_platform
  enable_display            = var.enable_display
  deletion_protection       = var.deletion_protection
  allow_stopping_for_update = var.allow_stopping_for_update
  can_ip_forward            = var.can_ip_forward
  hostname                  = var.hostname
  description               = var.description

  # Boot disk configuration
  boot_disk {
    auto_delete             = var.boot_disk_auto_delete
    device_name             = var.boot_disk_device_name
    mode                    = var.boot_disk_mode
    disk_encryption_key_raw = var.boot_disk_encryption_key_raw
    kms_key_self_link       = var.boot_disk_kms_key_self_link

    initialize_params {
      size                  = var.boot_disk_size
      type                  = var.boot_disk_type
      image                 = var.boot_disk_image
      labels                = var.boot_disk_labels
      resource_manager_tags = var.boot_disk_resource_manager_tags
    }
  }

  # Additional attached disks
  dynamic "attached_disk" {
    for_each = var.attached_disks
    content {
      source                  = attached_disk.value.source
      device_name             = attached_disk.value.device_name
      mode                    = lookup(attached_disk.value, "mode", "READ_WRITE")
      disk_encryption_key_raw = lookup(attached_disk.value, "disk_encryption_key_raw", null)
      kms_key_self_link       = lookup(attached_disk.value, "kms_key_self_link", null)
    }
  }

  # Scratch disks
  dynamic "scratch_disk" {
    for_each = range(var.scratch_disk_count)
    content {
      interface = var.scratch_disk_interface
    }
  }

  # Network interfaces
  dynamic "network_interface" {
    for_each = local.network_interface
    content {
      network            = lookup(network_interface.value, "network", null)
      subnetwork         = lookup(network_interface.value, "subnetwork", null)
      subnetwork_project = lookup(network_interface.value, "subnetwork_project", var.project_id)
      network_ip         = lookup(network_interface.value, "network_ip", null)
      nic_type           = lookup(network_interface.value, "nic_type", null)
      stack_type         = lookup(network_interface.value, "stack_type", "IPV4_ONLY")
      queue_count        = lookup(network_interface.value, "queue_count", null)

      dynamic "access_config" {
        for_each = lookup(network_interface.value, "access_config", [])
        content {
          nat_ip                 = lookup(access_config.value, "nat_ip", null)
          network_tier           = lookup(access_config.value, "network_tier", "STANDARD")
          public_ptr_domain_name = lookup(access_config.value, "public_ptr_domain_name", null)
        }
      }

      dynamic "ipv6_access_config" {
        for_each = lookup(network_interface.value, "ipv6_access_config", [])
        content {
          network_tier           = lookup(ipv6_access_config.value, "network_tier", "PREMIUM")
          public_ptr_domain_name = lookup(ipv6_access_config.value, "public_ptr_domain_name", null)
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

  # Service account configuration
  service_account {
    email  = local.service_account_email
    scopes = var.service_account_scopes
  }

  # Guest accelerator (GPU) configuration
  dynamic "guest_accelerator" {
    for_each = var.guest_accelerators
    content {
      type  = guest_accelerator.value.type
      count = guest_accelerator.value.count
    }
  }

  # Scheduling configuration
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

    dynamic "local_ssd_recovery_timeout" {
      for_each = var.local_ssd_recovery_timeout != null ? [var.local_ssd_recovery_timeout] : []
      content {
        seconds = local_ssd_recovery_timeout.value.seconds
        nanos   = lookup(local_ssd_recovery_timeout.value, "nanos", 0)
      }
    }
  }

  # Shielded instance configuration
  shielded_instance_config {
    enable_secure_boot          = var.enable_secure_boot
    enable_vtpm                 = var.enable_vtpm
    enable_integrity_monitoring = var.enable_integrity_monitoring
  }

  # Confidential instance configuration
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

  # Network performance configuration
  dynamic "network_performance_config" {
    for_each = var.network_performance_config != null ? [var.network_performance_config] : []
    content {
      total_egress_bandwidth_tier = network_performance_config.value.total_egress_bandwidth_tier
    }
  }

  # Metadata
  metadata = local.metadata

  # Labels
  labels = local.labels

  # Tags (firewall)
  tags = var.tags

  # Resource policies
  resource_policies = var.resource_policies

  metadata_startup_script = var.startup_script

  lifecycle {
    ignore_changes = var.ignore_changes_list

    create_before_destroy = var.create_before_destroy
  }

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }
}

# Instance group for single instance (optional)
resource "google_compute_instance_group" "unmanaged" {
  count = var.create_instance_group ? 1 : 0

  project = var.project_id
  name    = "${local.instance_name}-ig"
  zone    = local.zone

  instances = [google_compute_instance.instance.self_link]

  dynamic "named_port" {
    for_each = var.named_ports
    content {
      name = named_port.value.name
      port = named_port.value.port
    }
  }

  description = "Unmanaged instance group for ${local.instance_name}"

  lifecycle {
    create_before_destroy = true
  }
}