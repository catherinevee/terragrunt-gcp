# Compute Instance Module Outputs

# Instance Identifiers
output "instance_id" {
  description = "The server-assigned unique identifier of the instance"
  value       = google_compute_instance.instance.instance_id
}

output "instance_name" {
  description = "The name of the instance"
  value       = google_compute_instance.instance.name
}

output "self_link" {
  description = "The URI of the created instance"
  value       = google_compute_instance.instance.self_link
}

output "id" {
  description = "An identifier for the resource (same as instance_id)"
  value       = google_compute_instance.instance.id
}

# Network Information
output "network_ip" {
  description = "The internal IP address of the instance"
  value       = google_compute_instance.instance.network_interface[0].network_ip
}

output "external_ip" {
  description = "The external IP address of the instance (if applicable)"
  value = length(google_compute_instance.instance.network_interface[0].access_config) > 0 ? (
    google_compute_instance.instance.network_interface[0].access_config[0].nat_ip
  ) : null
}

output "ipv6_address" {
  description = "The IPv6 address of the instance (if applicable)"
  value = length(google_compute_instance.instance.network_interface[0].ipv6_access_config) > 0 ? (
    google_compute_instance.instance.network_interface[0].ipv6_access_config[0].external_ipv6
  ) : null
}

output "network_interfaces" {
  description = "All network interfaces attached to the instance"
  value       = google_compute_instance.instance.network_interface
}

# Instance Details
output "zone" {
  description = "The zone where the instance is deployed"
  value       = google_compute_instance.instance.zone
}

output "machine_type" {
  description = "The machine type of the instance"
  value       = google_compute_instance.instance.machine_type
}

output "cpu_platform" {
  description = "The CPU platform used by this instance"
  value       = google_compute_instance.instance.cpu_platform
}

output "current_status" {
  description = "Current status of the instance"
  value       = google_compute_instance.instance.current_status
}

output "hostname" {
  description = "The hostname of the instance"
  value       = google_compute_instance.instance.hostname
}

# Service Account
output "service_account_email" {
  description = "The service account email attached to the instance"
  value       = google_compute_instance.instance.service_account[0].email
}

output "service_account_scopes" {
  description = "The service account scopes attached to the instance"
  value       = google_compute_instance.instance.service_account[0].scopes
}

output "created_service_account" {
  description = "The service account created for the instance (if applicable)"
  value       = var.create_service_account ? google_service_account.instance[0].email : null
}

# Boot Disk Information
output "boot_disk_id" {
  description = "The ID of the boot disk"
  value       = google_compute_instance.instance.boot_disk[0].source
}

output "boot_disk_device_name" {
  description = "The device name of the boot disk"
  value       = google_compute_instance.instance.boot_disk[0].device_name
}

output "boot_disk_size" {
  description = "The size of the boot disk in GB"
  value       = var.boot_disk_size
}

output "boot_disk_type" {
  description = "The type of the boot disk"
  value       = var.boot_disk_type
}

# Attached Disks
output "attached_disks" {
  description = "List of attached disks"
  value       = google_compute_instance.instance.attached_disk
}

output "scratch_disks" {
  description = "List of scratch disks attached to the instance"
  value       = google_compute_instance.instance.scratch_disk
}

# GPU Information
output "guest_accelerators" {
  description = "List of guest accelerators (GPUs) attached to the instance"
  value       = google_compute_instance.instance.guest_accelerator
}

# Scheduling Information
output "scheduling" {
  description = "The scheduling configuration of the instance"
  value = {
    preemptible         = google_compute_instance.instance.scheduling[0].preemptible
    automatic_restart   = google_compute_instance.instance.scheduling[0].automatic_restart
    on_host_maintenance = google_compute_instance.instance.scheduling[0].on_host_maintenance
  }
}

# Shielded Instance Configuration
output "shielded_instance_config" {
  description = "Shielded instance configuration"
  value = {
    enable_secure_boot          = google_compute_instance.instance.shielded_instance_config[0].enable_secure_boot
    enable_vtpm                 = google_compute_instance.instance.shielded_instance_config[0].enable_vtpm
    enable_integrity_monitoring = google_compute_instance.instance.shielded_instance_config[0].enable_integrity_monitoring
  }
}

# Metadata and Labels
output "metadata" {
  description = "The metadata key/value pairs assigned to the instance"
  value       = google_compute_instance.instance.metadata
  sensitive   = true
}

output "metadata_fingerprint" {
  description = "The unique fingerprint of the metadata"
  value       = google_compute_instance.instance.metadata_fingerprint
}

output "labels" {
  description = "The labels assigned to the instance"
  value       = google_compute_instance.instance.labels
}

output "tags" {
  description = "The network tags assigned to the instance"
  value       = google_compute_instance.instance.tags
}

output "tags_fingerprint" {
  description = "The unique fingerprint of the network tags"
  value       = google_compute_instance.instance.tags_fingerprint
}

# Instance Group Information
output "instance_group_self_link" {
  description = "The self link of the unmanaged instance group (if created)"
  value       = var.create_instance_group ? google_compute_instance_group.unmanaged[0].self_link : null
}

output "instance_group_id" {
  description = "The ID of the unmanaged instance group (if created)"
  value       = var.create_instance_group ? google_compute_instance_group.unmanaged[0].id : null
}

output "instance_group_size" {
  description = "The size of the unmanaged instance group (if created)"
  value       = var.create_instance_group ? google_compute_instance_group.unmanaged[0].size : null
}

# SSH Connection Information
output "ssh_command" {
  description = "gcloud command to SSH into the instance"
  value       = "gcloud compute ssh --zone=${google_compute_instance.instance.zone} ${google_compute_instance.instance.name} --project=${var.project_id}"
}

output "ssh_connection_string" {
  description = "SSH connection string for the instance (if external IP exists)"
  value = length(google_compute_instance.instance.network_interface[0].access_config) > 0 ? (
    "ssh -i ~/.ssh/id_rsa user@${google_compute_instance.instance.network_interface[0].access_config[0].nat_ip}"
  ) : "No external IP - use gcloud compute ssh or bastion host"
}

# Creation Timestamp
output "creation_timestamp" {
  description = "Creation timestamp in RFC3339 text format"
  value       = google_compute_instance.instance.creation_timestamp
}

# Label Fingerprint
output "label_fingerprint" {
  description = "The unique fingerprint of the labels"
  value       = google_compute_instance.instance.label_fingerprint
}

# Advanced Features
output "min_cpu_platform" {
  description = "The minimum CPU platform specified for the instance"
  value       = google_compute_instance.instance.min_cpu_platform
}

output "enable_display" {
  description = "Whether virtual display is enabled for the instance"
  value       = google_compute_instance.instance.enable_display
}

output "deletion_protection" {
  description = "Whether deletion protection is enabled for the instance"
  value       = google_compute_instance.instance.deletion_protection
}

output "can_ip_forward" {
  description = "Whether IP forwarding is enabled for the instance"
  value       = google_compute_instance.instance.can_ip_forward
}

# Resource Policies
output "resource_policies" {
  description = "List of resource policies attached to the instance"
  value       = google_compute_instance.instance.resource_policies
}

# Confidential Instance Config
output "confidential_instance_config" {
  description = "Confidential instance configuration"
  value       = google_compute_instance.instance.confidential_instance_config
}

# Advanced Machine Features
output "advanced_machine_features" {
  description = "Advanced machine features configuration"
  value       = google_compute_instance.instance.advanced_machine_features
}

# Reservation Affinity
output "reservation_affinity" {
  description = "Reservation affinity configuration"
  value       = google_compute_instance.instance.reservation_affinity
}

# Network Performance Config
output "network_performance_config" {
  description = "Network performance configuration"
  value       = google_compute_instance.instance.network_performance_config
}

# Instance Template Reference (for future scaling)
output "instance_template" {
  description = "Configuration that can be used to create an instance template"
  value = {
    machine_type           = google_compute_instance.instance.machine_type
    boot_disk_image        = var.boot_disk_image
    boot_disk_size         = var.boot_disk_size
    boot_disk_type         = var.boot_disk_type
    network_tags           = google_compute_instance.instance.tags
    labels                 = google_compute_instance.instance.labels
    service_account_email  = google_compute_instance.instance.service_account[0].email
    service_account_scopes = google_compute_instance.instance.service_account[0].scopes
  }
}