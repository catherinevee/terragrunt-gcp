# Compute Instance Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "name" {
  description = "Name of the instance. If null, will use name_prefix with random suffix"
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Name prefix for the instance"
  type        = string
  default     = "instance"
}

variable "zone" {
  description = "The zone where the instance will be created. If null, will select automatically"
  type        = string
  default     = null
}

variable "region" {
  description = "The region for selecting zones automatically"
  type        = string
  default     = "us-central1"
}

variable "machine_type" {
  description = "The machine type to create"
  type        = string
  default     = "e2-medium"
}

variable "min_cpu_platform" {
  description = "Minimum CPU platform for the instance"
  type        = string
  default     = null
}

variable "enable_display" {
  description = "Enable virtual display on the instance"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Enable deletion protection on the instance"
  type        = bool
  default     = false
}

variable "allow_stopping_for_update" {
  description = "Allow Terraform to stop the instance to update properties"
  type        = bool
  default     = true
}

variable "can_ip_forward" {
  description = "Whether to allow sending and receiving packets with non-matching source/destination IPs"
  type        = bool
  default     = false
}

variable "hostname" {
  description = "Hostname of the instance"
  type        = string
  default     = null
}

variable "description" {
  description = "Description of the instance"
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Boot Disk Configuration
variable "boot_disk_auto_delete" {
  description = "Whether the boot disk will be auto-deleted when the instance is deleted"
  type        = bool
  default     = true
}

variable "boot_disk_device_name" {
  description = "Name with which the boot disk is attached"
  type        = string
  default     = null
}

variable "boot_disk_mode" {
  description = "Mode in which to attach the boot disk"
  type        = string
  default     = "READ_WRITE"
}

variable "boot_disk_encryption_key_raw" {
  description = "A 256-bit customer-supplied encryption key for the boot disk"
  type        = string
  default     = null
  sensitive   = true
}

variable "boot_disk_kms_key_self_link" {
  description = "The self_link of the encryption key used to encrypt the boot disk"
  type        = string
  default     = null
}

variable "boot_disk_size" {
  description = "Size of the boot disk in GB"
  type        = number
  default     = 20
}

variable "boot_disk_type" {
  description = "Type of the boot disk"
  type        = string
  default     = "pd-standard"
}

variable "boot_disk_image" {
  description = "The image from which to initialize the boot disk"
  type        = string
  default     = "debian-cloud/debian-11"
}

variable "boot_disk_labels" {
  description = "Labels to apply to the boot disk"
  type        = map(string)
  default     = {}
}

variable "boot_disk_resource_manager_tags" {
  description = "Resource manager tags to apply to the boot disk"
  type        = map(string)
  default     = null
}

# Additional Disks
variable "attached_disks" {
  description = "List of disks to attach to the instance"
  type = list(object({
    source                  = string
    device_name             = optional(string)
    mode                    = optional(string)
    disk_encryption_key_raw = optional(string)
    kms_key_self_link       = optional(string)
  }))
  default = []
}

variable "scratch_disk_count" {
  description = "Number of scratch disks to attach"
  type        = number
  default     = 0
}

variable "scratch_disk_interface" {
  description = "Interface to use for scratch disks"
  type        = string
  default     = "NVME"
}

# Network Configuration
variable "network" {
  description = "Network to attach the instance to"
  type        = string
  default     = "default"
}

variable "subnetwork" {
  description = "Subnetwork to attach the instance to"
  type        = string
  default     = null
}

variable "network_ip" {
  description = "Private IP address to assign to the instance"
  type        = string
  default     = null
}

variable "stack_type" {
  description = "IP stack type for the instance"
  type        = string
  default     = "IPV4_ONLY"
}

variable "enable_external_ip" {
  description = "Whether to assign an external IP to the instance"
  type        = bool
  default     = false
}

variable "nat_ip" {
  description = "External IP address to assign to the instance"
  type        = string
  default     = null
}

variable "network_tier" {
  description = "Network tier for external IP"
  type        = string
  default     = "STANDARD"
}

variable "public_ptr_domain_name" {
  description = "Public PTR domain name for external IP"
  type        = string
  default     = null
}

variable "enable_ipv6" {
  description = "Enable IPv6 on the instance"
  type        = bool
  default     = false
}

variable "alias_ip_ranges" {
  description = "Alias IP ranges for the instance"
  type = list(object({
    ip_cidr_range         = string
    subnetwork_range_name = optional(string)
  }))
  default = []
}

variable "network_interface" {
  description = "Complete network interface configuration. If provided, overrides individual network settings"
  type = list(object({
    network            = optional(string)
    subnetwork         = optional(string)
    subnetwork_project = optional(string)
    network_ip         = optional(string)
    nic_type           = optional(string)
    stack_type         = optional(string)
    queue_count        = optional(number)
    access_config = optional(list(object({
      nat_ip                 = optional(string)
      network_tier           = optional(string)
      public_ptr_domain_name = optional(string)
    })))
    ipv6_access_config = optional(list(object({
      network_tier           = optional(string)
      public_ptr_domain_name = optional(string)
    })))
    alias_ip_range = optional(list(object({
      ip_cidr_range         = string
      subnetwork_range_name = optional(string)
    })))
  }))
  default = null
}

# Service Account Configuration
variable "create_service_account" {
  description = "Whether to create a new service account for the instance"
  type        = bool
  default     = false
}

variable "service_account_email" {
  description = "Email of the service account to attach to the instance"
  type        = string
  default     = null
}

variable "service_account_scopes" {
  description = "List of scopes for the service account"
  type        = list(string)
  default     = ["cloud-platform"]
}

variable "service_account_roles" {
  description = "List of IAM roles to grant to the service account"
  type        = list(string)
  default     = []
}

# Guest Accelerators (GPU)
variable "guest_accelerators" {
  description = "List of guest accelerators (GPUs) to attach to the instance"
  type = list(object({
    type  = string
    count = number
  }))
  default = []
}

# Scheduling Configuration
variable "preemptible" {
  description = "Whether the instance is preemptible"
  type        = bool
  default     = false
}

variable "automatic_restart" {
  description = "Whether the instance should be automatically restarted if terminated"
  type        = bool
  default     = true
}

variable "on_host_maintenance" {
  description = "Behavior when maintenance occurs"
  type        = string
  default     = "MIGRATE"
}

variable "provisioning_model" {
  description = "Provisioning model of the instance"
  type        = string
  default     = "STANDARD"
}

variable "instance_termination_action" {
  description = "Action to take when instance is terminated"
  type        = string
  default     = "STOP"
}

variable "node_affinities" {
  description = "Node affinity labels for sole-tenant node selection"
  type = list(object({
    key      = string
    operator = string
    values   = list(string)
  }))
  default = []
}

variable "local_ssd_recovery_timeout" {
  description = "Local SSD recovery timeout"
  type = object({
    seconds = number
    nanos   = optional(number)
  })
  default = null
}

# Shielded Instance Configuration
variable "enable_secure_boot" {
  description = "Enable secure boot for shielded instance"
  type        = bool
  default     = false
}

variable "enable_vtpm" {
  description = "Enable vTPM for shielded instance"
  type        = bool
  default     = true
}

variable "enable_integrity_monitoring" {
  description = "Enable integrity monitoring for shielded instance"
  type        = bool
  default     = true
}

# Confidential Computing
variable "enable_confidential_compute" {
  description = "Enable confidential compute for the instance"
  type        = bool
  default     = false
}

# Advanced Machine Features
variable "advanced_machine_features" {
  description = "Advanced machine features configuration"
  type = object({
    enable_nested_virtualization = optional(bool)
    threads_per_core             = optional(number)
    visible_core_count           = optional(number)
  })
  default = null
}

# Reservation Affinity
variable "reservation_affinity" {
  description = "Reservation affinity configuration"
  type = object({
    type = string
    specific_reservation = optional(object({
      key    = string
      values = list(string)
    }))
  })
  default = null
}

# Network Performance
variable "network_performance_config" {
  description = "Network performance configuration"
  type = object({
    total_egress_bandwidth_tier = string
  })
  default = null
}

# Metadata and Scripts
variable "metadata" {
  description = "Metadata key/value pairs to assign to the instance"
  type        = map(string)
  default     = {}
}

variable "enable_oslogin" {
  description = "Enable OS Login for the instance"
  type        = bool
  default     = false
}

variable "enable_oslogin_2fa" {
  description = "Enable OS Login 2FA for the instance"
  type        = bool
  default     = false
}

variable "startup_script" {
  description = "Startup script to run when the instance boots"
  type        = string
  default     = null
}

variable "shutdown_script" {
  description = "Shutdown script to run when the instance shuts down"
  type        = string
  default     = null
}

variable "metadata_startup_script" {
  description = "Alternative way to provide startup script"
  type        = string
  default     = null
}

# Labels and Tags
variable "labels" {
  description = "Labels to apply to the instance"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Network tags to apply to the instance"
  type        = list(string)
  default     = []
}

# Resource Policies
variable "resource_policies" {
  description = "List of resource policies to attach to the instance"
  type        = list(string)
  default     = []
}

# Instance Group
variable "create_instance_group" {
  description = "Whether to create an unmanaged instance group for this instance"
  type        = bool
  default     = false
}

variable "named_ports" {
  description = "Named ports for the instance group"
  type = list(object({
    name = string
    port = number
  }))
  default = []
}

# Lifecycle Configuration
variable "ignore_changes_list" {
  description = "List of instance attributes to ignore changes on"
  type        = list(string)
  default     = []
}

variable "create_before_destroy" {
  description = "Whether to create a new instance before destroying the old one"
  type        = bool
  default     = false
}

# Timeouts
variable "timeouts" {
  description = "Timeout configuration for instance operations"
  type = object({
    create = optional(string, "20m")
    update = optional(string, "20m")
    delete = optional(string, "20m")
  })
  default = {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
}