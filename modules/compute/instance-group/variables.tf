# Managed Instance Group Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "name" {
  description = "Name of the managed instance group"
  type        = string
}

variable "description" {
  description = "Description of the managed instance group"
  type        = string
  default     = null
}

variable "base_instance_name" {
  description = "Base name for instances created by the MIG"
  type        = string
  default     = null
}

variable "region" {
  description = "Region for regional MIG"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for zonal MIG"
  type        = string
  default     = "us-central1-a"
}

variable "regional" {
  description = "Whether to create a regional (true) or zonal (false) managed instance group"
  type        = bool
  default     = false
}

variable "distribution_zones" {
  description = "Zones for distributing instances in a regional MIG"
  type        = list(string)
  default     = null
}

variable "distribution_policy_target_shape" {
  description = "Target shape for distribution policy (EVEN, BALANCED, ANY_SINGLE_ZONE)"
  type        = string
  default     = null
}

# Instance Template Configuration
variable "instance_template_description" {
  description = "Description for the instance template"
  type        = string
  default     = "Instance template for managed instance group"
}

variable "machine_type" {
  description = "Machine type for instances"
  type        = string
  default     = "e2-medium"
}

variable "min_cpu_platform" {
  description = "Minimum CPU platform for instances"
  type        = string
  default     = null
}

variable "can_ip_forward" {
  description = "Enable IP forwarding"
  type        = bool
  default     = false
}

variable "enable_display" {
  description = "Enable virtual display"
  type        = bool
  default     = false
}

variable "resource_policies" {
  description = "List of resource policies to attach"
  type        = list(string)
  default     = []
}

# Boot Disk Configuration
variable "source_image" {
  description = "Source image for boot disk"
  type        = string
  default     = "debian-cloud/debian-11"
}

variable "boot_disk_auto_delete" {
  description = "Auto-delete boot disk when instance is deleted"
  type        = bool
  default     = true
}

variable "boot_disk_name" {
  description = "Name for the boot disk"
  type        = string
  default     = null
}

variable "boot_disk_size_gb" {
  description = "Size of boot disk in GB"
  type        = number
  default     = 20
}

variable "boot_disk_type" {
  description = "Type of boot disk"
  type        = string
  default     = "pd-standard"
}

variable "boot_disk_kms_key_self_link" {
  description = "KMS key for encrypting boot disk"
  type        = string
  default     = null
}

# Additional Disks
variable "additional_disks" {
  description = "List of additional disks to attach"
  type = list(object({
    auto_delete       = optional(bool)
    disk_name        = optional(string)
    disk_size_gb     = optional(number)
    disk_type        = optional(string)
    source_image     = optional(string)
    source           = optional(string)
    mode             = optional(string)
    type             = optional(string)
    kms_key_self_link = optional(string)
  }))
  default = []
}

# Network Configuration
variable "network_interfaces" {
  description = "List of network interfaces"
  type = list(object({
    network            = optional(string)
    subnetwork         = optional(string)
    subnetwork_project = optional(string)
    network_ip         = optional(string)
    nic_type          = optional(string)
    stack_type        = optional(string)
    queue_count       = optional(number)
    access_config = optional(list(object({
      nat_ip       = optional(string)
      network_tier = optional(string)
    })))
    ipv6_access_config = optional(list(object({
      network_tier = optional(string)
    })))
    alias_ip_range = optional(list(object({
      ip_cidr_range         = string
      subnetwork_range_name = optional(string)
    })))
  }))
  default = [{
    network    = "default"
    subnetwork = null
  }]
}

# Service Account Configuration
variable "create_service_account" {
  description = "Create a new service account for MIG instances"
  type        = bool
  default     = false
}

variable "service_account_email" {
  description = "Service account email for instances"
  type        = string
  default     = null
}

variable "service_account_scopes" {
  description = "Service account scopes"
  type        = list(string)
  default     = ["cloud-platform"]
}

variable "service_account_roles" {
  description = "IAM roles to grant to the service account"
  type        = list(string)
  default     = []
}

# Metadata and Labels
variable "metadata" {
  description = "Metadata key/value pairs"
  type        = map(string)
  default     = {}
}

variable "labels" {
  description = "Labels to apply to instances"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Network tags for instances"
  type        = list(string)
  default     = []
}

variable "enable_oslogin" {
  description = "Enable OS Login"
  type        = bool
  default     = false
}

variable "startup_script" {
  description = "Startup script for instances"
  type        = string
  default     = null
}

variable "shutdown_script" {
  description = "Shutdown script for instances"
  type        = string
  default     = null
}

# Guest Accelerators
variable "guest_accelerators" {
  description = "List of guest accelerators (GPUs)"
  type = list(object({
    type  = string
    count = number
  }))
  default = []
}

# Scheduling Configuration
variable "preemptible" {
  description = "Use preemptible instances"
  type        = bool
  default     = false
}

variable "automatic_restart" {
  description = "Automatically restart instances"
  type        = bool
  default     = true
}

variable "on_host_maintenance" {
  description = "Behavior on host maintenance"
  type        = string
  default     = "MIGRATE"
}

variable "provisioning_model" {
  description = "VM provisioning model"
  type        = string
  default     = "STANDARD"
}

variable "instance_termination_action" {
  description = "Action on instance termination"
  type        = string
  default     = "STOP"
}

variable "node_affinities" {
  description = "Node affinity labels"
  type = list(object({
    key      = string
    operator = string
    values   = list(string)
  }))
  default = []
}

# Shielded Instance Configuration
variable "enable_secure_boot" {
  description = "Enable secure boot"
  type        = bool
  default     = false
}

variable "enable_vtpm" {
  description = "Enable vTPM"
  type        = bool
  default     = true
}

variable "enable_integrity_monitoring" {
  description = "Enable integrity monitoring"
  type        = bool
  default     = true
}

# Confidential Computing
variable "enable_confidential_compute" {
  description = "Enable confidential compute"
  type        = bool
  default     = false
}

# Advanced Machine Features
variable "advanced_machine_features" {
  description = "Advanced machine features"
  type = object({
    enable_nested_virtualization = optional(bool)
    threads_per_core            = optional(number)
    visible_core_count          = optional(number)
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

# MIG Configuration
variable "target_size" {
  description = "Target number of instances"
  type        = number
  default     = 1
}

variable "target_pools" {
  description = "List of target pools for the MIG"
  type        = list(string)
  default     = []
}

variable "named_ports" {
  description = "Named ports for the instance group"
  type = list(object({
    name = string
    port = number
  }))
  default = []
}

variable "wait_for_instances" {
  description = "Wait for instances to be created/updated"
  type        = bool
  default     = false
}

variable "wait_for_instances_status" {
  description = "Status to wait for when wait_for_instances is true"
  type        = string
  default     = "STABLE"
}

# Versions (for canary deployments)
variable "versions" {
  description = "Additional versions for canary deployments"
  type = list(object({
    instance_template = string
    name             = string
    target_size = optional(object({
      fixed   = optional(number)
      percent = optional(number)
    }))
  }))
  default = []
}

# Health Check Configuration
variable "create_health_check" {
  description = "Create a new health check"
  type        = bool
  default     = true
}

variable "health_check_id" {
  description = "Existing health check ID to use"
  type        = string
  default     = null
}

variable "health_check_name" {
  description = "Name for the health check"
  type        = string
  default     = null
}

variable "health_check_type" {
  description = "Type of health check (http, https, tcp, ssl, grpc)"
  type        = string
  default     = "http"
}

variable "health_check_interval_sec" {
  description = "Health check interval in seconds"
  type        = number
  default     = 10
}

variable "health_check_timeout_sec" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Number of successful checks before healthy"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of failed checks before unhealthy"
  type        = number
  default     = 3
}

variable "health_check_port" {
  description = "Port for health check"
  type        = number
  default     = 80
}

variable "health_check_request_path" {
  description = "Request path for HTTP(S) health checks"
  type        = string
  default     = "/health"
}

variable "health_check_host" {
  description = "Host header for health checks"
  type        = string
  default     = null
}

variable "health_check_response" {
  description = "Expected response for health checks"
  type        = string
  default     = null
}

variable "health_check_proxy_header" {
  description = "Proxy header for health checks"
  type        = string
  default     = "NONE"
}

variable "health_check_port_specification" {
  description = "Port specification for health checks"
  type        = string
  default     = null
}

variable "health_check_tcp_request" {
  description = "Request data for TCP health checks"
  type        = string
  default     = null
}

variable "health_check_tcp_response" {
  description = "Response data for TCP health checks"
  type        = string
  default     = null
}

variable "health_check_grpc_service_name" {
  description = "gRPC service name for health checks"
  type        = string
  default     = null
}

variable "health_check_enable_logging" {
  description = "Enable health check logging"
  type        = bool
  default     = false
}

# Auto-healing Configuration
variable "auto_healing_initial_delay_sec" {
  description = "Initial delay before auto-healing"
  type        = number
  default     = 300
}

# Update Policy
variable "update_policy" {
  description = "Update policy configuration"
  type = object({
    type                           = optional(string)
    instance_redistribution_type   = optional(string)
    minimal_action                 = optional(string)
    most_disruptive_allowed_action = optional(string)
    max_surge_fixed                = optional(number)
    max_surge_percent              = optional(number)
    max_unavailable_fixed          = optional(number)
    max_unavailable_percent        = optional(number)
    min_ready_sec                  = optional(number)
    replacement_method             = optional(string)
  })
  default = null
}

# Stateful Configuration
variable "stateful_disks" {
  description = "Stateful disk configuration"
  type = list(object({
    device_name = string
    delete_rule = optional(string)
  }))
  default = []
}

variable "stateful_internal_ips" {
  description = "Stateful internal IP configuration"
  type = list(object({
    interface_name = string
    delete_rule    = optional(string)
  }))
  default = []
}

variable "stateful_external_ips" {
  description = "Stateful external IP configuration"
  type = list(object({
    interface_name = string
    delete_rule    = optional(string)
  }))
  default = []
}

# Instance Lifecycle Policy
variable "instance_lifecycle_policy" {
  description = "Instance lifecycle policy"
  type = object({
    default_action_on_failure = optional(string)
    force_update_on_repair   = optional(string)
  })
  default = null
}

# Autoscaling Configuration
variable "autoscaling_enabled" {
  description = "Enable autoscaling"
  type        = bool
  default     = true
}

variable "max_replicas" {
  description = "Maximum number of instances"
  type        = number
  default     = 10
}

variable "min_replicas" {
  description = "Minimum number of instances"
  type        = number
  default     = 1
}

variable "autoscaling_cooldown_period" {
  description = "Autoscaling cooldown period in seconds"
  type        = number
  default     = 60
}

variable "autoscaling_cpu" {
  description = "CPU utilization target for autoscaling"
  type = object({
    target            = number
    predictive_method = optional(string)
  })
  default = {
    target = 0.7
  }
}

variable "autoscaling_metrics" {
  description = "Custom metrics for autoscaling"
  type = list(object({
    name   = string
    target = number
    type   = optional(string)
  }))
  default = []
}

variable "autoscaling_load_balancing_utilization" {
  description = "Load balancing utilization for autoscaling"
  type = object({
    target = number
  })
  default = null
}

variable "autoscaling_scale_in_control" {
  description = "Scale-in control configuration"
  type = object({
    max_scaled_in_replicas_fixed   = optional(number)
    max_scaled_in_replicas_percent = optional(number)
    time_window_sec                = optional(number)
  })
  default = null
}

variable "autoscaling_mode" {
  description = "Autoscaling mode (ON, OFF, ONLY_SCALE_OUT)"
  type        = string
  default     = "ON"
}

# Lifecycle Configuration
variable "ignore_changes_list" {
  description = "List of attributes to ignore changes on"
  type        = list(string)
  default     = []
}

# Timeouts
variable "mig_timeouts" {
  description = "Timeouts for MIG operations"
  type = object({
    create = optional(string, "30m")
    update = optional(string, "30m")
    delete = optional(string, "30m")
  })
  default = {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

variable "autoscaler_timeouts" {
  description = "Timeouts for autoscaler operations"
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