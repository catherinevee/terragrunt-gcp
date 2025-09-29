# Dataproc Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for the Dataproc cluster"
  type        = string
}

variable "zone" {
  description = "The zone for the Dataproc cluster"
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Cluster Configuration
variable "cluster_name" {
  description = "Name of the Dataproc cluster"
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Name prefix for the Dataproc cluster"
  type        = string
  default     = "dataproc-cluster"
}

variable "deploy_cluster" {
  description = "Whether to deploy the Dataproc cluster"
  type        = bool
  default     = true
}

variable "cluster_type" {
  description = "Type of cluster (standard or virtual)"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "virtual"], var.cluster_type)
    error_message = "cluster_type must be standard or virtual"
  }
}

variable "cluster_config" {
  description = "Additional cluster configuration"
  type        = map(any)
  default     = {}
}

variable "image_version" {
  description = "Dataproc image version"
  type        = string
  default     = "2.1"
}

variable "graceful_decommission_timeout" {
  description = "Graceful decommission timeout"
  type        = string
  default     = "120s"
}

# Master Configuration
variable "master_num_instances" {
  description = "Number of master instances"
  type        = number
  default     = 1
}

variable "master_machine_type" {
  description = "Machine type for master nodes"
  type        = string
  default     = "n2-standard-4"
}

variable "master_boot_disk_type" {
  description = "Boot disk type for master"
  type        = string
  default     = "pd-standard"
}

variable "master_boot_disk_size_gb" {
  description = "Boot disk size for master in GB"
  type        = number
  default     = 100
}

variable "master_num_local_ssds" {
  description = "Number of local SSDs for master"
  type        = number
  default     = 0
}

variable "master_local_ssd_interface" {
  description = "Local SSD interface for master"
  type        = string
  default     = "SCSI"
}

variable "master_min_cpu_platform" {
  description = "Minimum CPU platform for master"
  type        = string
  default     = null
}

variable "master_accelerators" {
  description = "Accelerators for master nodes"
  type = list(object({
    type  = string
    count = number
  }))
  default = []
}

variable "master_image_uri" {
  description = "Custom image URI for master"
  type        = string
  default     = null
}

# Worker Configuration
variable "worker_num_instances" {
  description = "Number of worker instances"
  type        = number
  default     = 2
}

variable "worker_machine_type" {
  description = "Machine type for worker nodes"
  type        = string
  default     = "n2-standard-4"
}

variable "worker_boot_disk_type" {
  description = "Boot disk type for workers"
  type        = string
  default     = "pd-standard"
}

variable "worker_boot_disk_size_gb" {
  description = "Boot disk size for workers in GB"
  type        = number
  default     = 100
}

variable "worker_num_local_ssds" {
  description = "Number of local SSDs for workers"
  type        = number
  default     = 0
}

variable "worker_local_ssd_interface" {
  description = "Local SSD interface for workers"
  type        = string
  default     = "SCSI"
}

variable "worker_min_cpu_platform" {
  description = "Minimum CPU platform for workers"
  type        = string
  default     = null
}

variable "worker_accelerators" {
  description = "Accelerators for worker nodes"
  type = list(object({
    type  = string
    count = number
  }))
  default = []
}

variable "worker_image_uri" {
  description = "Custom image URI for workers"
  type        = string
  default     = null
}

# Preemptible Worker Configuration
variable "preemptible_workers" {
  description = "Number of preemptible worker instances"
  type        = number
  default     = 0
}

variable "preemptible_worker_type" {
  description = "Preemptibility type (NON_PREEMPTIBLE, PREEMPTIBLE, or SPOT)"
  type        = string
  default     = "PREEMPTIBLE"
}

variable "preemptible_boot_disk_type" {
  description = "Boot disk type for preemptible workers"
  type        = string
  default     = "pd-standard"
}

variable "preemptible_boot_disk_size_gb" {
  description = "Boot disk size for preemptible workers in GB"
  type        = number
  default     = 100
}

variable "preemptible_num_local_ssds" {
  description = "Number of local SSDs for preemptible workers"
  type        = number
  default     = 0
}

variable "preemptible_local_ssd_interface" {
  description = "Local SSD interface for preemptible workers"
  type        = string
  default     = "SCSI"
}

# Software Configuration
variable "optional_components" {
  description = "Optional components to install"
  type        = list(string)
  default     = []
}

variable "override_properties" {
  description = "Override properties for software config"
  type        = map(string)
  default     = {}
}

variable "software_config" {
  description = "Software configuration"
  type        = any
  default     = {}
}

variable "enable_component_gateway" {
  description = "Enable component gateway"
  type        = bool
  default     = false
}

# Network Configuration
variable "network" {
  description = "Network for Dataproc cluster"
  type        = string
  default     = null
}

variable "subnetwork" {
  description = "Subnetwork for Dataproc cluster"
  type        = string
  default     = null
}

variable "internal_ip_only" {
  description = "Use internal IPs only"
  type        = bool
  default     = true
}

variable "network_tags" {
  description = "Network tags for instances"
  type        = list(string)
  default     = ["dataproc"]
}

# Service Account
variable "service_account" {
  description = "Service account for Dataproc"
  type        = string
  default     = null
}

variable "service_account_scopes" {
  description = "Service account scopes"
  type        = list(string)
  default = [
    "https://www.googleapis.com/auth/cloud-platform"
  ]
}

variable "create_service_account_roles" {
  description = "Grant necessary roles to service account"
  type        = bool
  default     = false
}

# Storage
variable "staging_bucket" {
  description = "Staging bucket name"
  type        = string
  default     = null
}

variable "temp_bucket" {
  description = "Temp bucket name"
  type        = string
  default     = null
}

variable "create_staging_bucket" {
  description = "Create staging bucket"
  type        = bool
  default     = false
}

variable "staging_bucket_name" {
  description = "Name for new staging bucket"
  type        = string
  default     = null
}

variable "staging_bucket_force_destroy" {
  description = "Force destroy staging bucket"
  type        = bool
  default     = false
}

variable "staging_bucket_lifecycle_days" {
  description = "Lifecycle days for staging bucket"
  type        = number
  default     = 30
}

# Autoscaling
variable "enable_autoscaling" {
  description = "Enable autoscaling"
  type        = bool
  default     = false
}

variable "create_autoscaling_policy" {
  description = "Create autoscaling policy"
  type        = bool
  default     = false
}

variable "autoscaling_policy_id" {
  description = "Existing autoscaling policy ID"
  type        = string
  default     = null
}

variable "autoscaling_policy_name" {
  description = "Name for new autoscaling policy"
  type        = string
  default     = null
}

variable "autoscale_min_workers" {
  description = "Minimum number of workers for autoscaling"
  type        = number
  default     = 2
}

variable "autoscale_max_workers" {
  description = "Maximum number of workers for autoscaling"
  type        = number
  default     = 10
}

variable "autoscale_secondary_workers" {
  description = "Enable secondary worker autoscaling"
  type        = bool
  default     = false
}

variable "autoscale_min_secondary_workers" {
  description = "Minimum secondary workers"
  type        = number
  default     = 0
}

variable "autoscale_max_secondary_workers" {
  description = "Maximum secondary workers"
  type        = number
  default     = 10
}

variable "autoscale_primary_worker_weight" {
  description = "Weight for primary workers"
  type        = number
  default     = 1
}

variable "autoscale_secondary_worker_weight" {
  description = "Weight for secondary workers"
  type        = number
  default     = 1
}

variable "autoscale_graceful_decommission_timeout" {
  description = "Graceful decommission timeout"
  type        = string
  default     = "120s"
}

variable "autoscale_scale_up_factor" {
  description = "Scale up factor"
  type        = number
  default     = 1.0
}

variable "autoscale_scale_down_factor" {
  description = "Scale down factor"
  type        = number
  default     = 1.0
}

variable "autoscale_scale_up_min_worker_fraction" {
  description = "Scale up minimum worker fraction"
  type        = number
  default     = 0.0
}

variable "autoscale_scale_down_min_worker_fraction" {
  description = "Scale down minimum worker fraction"
  type        = number
  default     = 0.0
}

variable "autoscale_cooldown_period" {
  description = "Cooldown period for autoscaling"
  type        = string
  default     = "120s"
}

# Lifecycle Configuration
variable "idle_delete_ttl" {
  description = "Idle time before cluster deletion"
  type        = string
  default     = null
}

variable "auto_delete_time" {
  description = "Time when cluster will be deleted"
  type        = string
  default     = null
}

variable "auto_delete_ttl" {
  description = "TTL for auto deletion"
  type        = string
  default     = null
}

# Security
variable "kms_key_name" {
  description = "KMS key for encryption"
  type        = string
  default     = null
}

variable "enable_kerberos" {
  description = "Enable Kerberos"
  type        = bool
  default     = false
}

variable "kerberos_root_principal_password_uri" {
  description = "Kerberos root principal password URI"
  type        = string
  default     = null
}

variable "kerberos_kms_key_uri" {
  description = "Kerberos KMS key URI"
  type        = string
  default     = null
}

variable "kerberos_keystore_uri" {
  description = "Kerberos keystore URI"
  type        = string
  default     = null
}

variable "kerberos_truststore_uri" {
  description = "Kerberos truststore URI"
  type        = string
  default     = null
}

variable "kerberos_keystore_password_uri" {
  description = "Kerberos keystore password URI"
  type        = string
  default     = null
}

variable "kerberos_key_password_uri" {
  description = "Kerberos key password URI"
  type        = string
  default     = null
}

variable "kerberos_truststore_password_uri" {
  description = "Kerberos truststore password URI"
  type        = string
  default     = null
}

variable "kerberos_cross_realm_trust_realm" {
  description = "Cross realm trust realm"
  type        = string
  default     = null
}

variable "kerberos_cross_realm_trust_kdc" {
  description = "Cross realm trust KDC"
  type        = string
  default     = null
}

variable "kerberos_cross_realm_trust_admin_server" {
  description = "Cross realm trust admin server"
  type        = string
  default     = null
}

variable "kerberos_cross_realm_trust_shared_password_uri" {
  description = "Cross realm trust shared password URI"
  type        = string
  default     = null
}

variable "kerberos_kdc_db_key_uri" {
  description = "KDC database key URI"
  type        = string
  default     = null
}

variable "kerberos_tgt_lifetime_hours" {
  description = "TGT lifetime in hours"
  type        = number
  default     = 10
}

variable "kerberos_realm" {
  description = "Kerberos realm"
  type        = string
  default     = null
}

variable "user_service_account_mapping" {
  description = "User to service account mapping"
  type        = map(string)
  default     = {}
}

variable "enable_secure_boot" {
  description = "Enable secure boot"
  type        = bool
  default     = false
}

variable "enable_vtpm" {
  description = "Enable vTPM"
  type        = bool
  default     = false
}

variable "enable_integrity_monitoring" {
  description = "Enable integrity monitoring"
  type        = bool
  default     = true
}

# Endpoint Configuration
variable "enable_http_port_access" {
  description = "Enable HTTP port access"
  type        = bool
  default     = false
}

variable "http_ports" {
  description = "HTTP ports to enable"
  type        = map(string)
  default     = {}
}

# Metadata
variable "metadata" {
  description = "Metadata for instances"
  type        = map(string)
  default     = {}
}

# Reservation Affinity
variable "reservation_affinity_consume_type" {
  description = "Reservation affinity consume type"
  type        = string
  default     = "NO_RESERVATION"
}

variable "reservation_affinity_key" {
  description = "Reservation affinity key"
  type        = string
  default     = null
}

variable "reservation_affinity_values" {
  description = "Reservation affinity values"
  type        = list(string)
  default     = []
}

# Node Group Affinity
variable "node_group_affinity_uri" {
  description = "Node group affinity URI"
  type        = string
  default     = null
}

# Metrics
variable "metric_source" {
  description = "Metric source"
  type        = string
  default     = "MONITORING_AGENT_DEFAULTS"
}

variable "metric_overrides" {
  description = "Metric overrides"
  type        = list(string)
  default     = []
}

# Initialization Actions
variable "initialization_actions" {
  description = "Initialization action scripts"
  type = list(object({
    script      = string
    timeout_sec = optional(number)
  }))
  default = []
}

variable "enable_stackdriver_monitoring" {
  description = "Enable Stackdriver monitoring"
  type        = bool
  default     = true
}

variable "enable_jupyter" {
  description = "Enable Jupyter"
  type        = bool
  default     = false
}

variable "enable_kafka" {
  description = "Enable Kafka"
  type        = bool
  default     = false
}

# Labels
variable "labels" {
  description = "Labels for resources"
  type        = map(string)
  default     = {}
}

# Metastore
variable "create_metastore" {
  description = "Create Dataproc Metastore"
  type        = bool
  default     = false
}

variable "metastore_service" {
  description = "Existing metastore service"
  type        = string
  default     = null
}

variable "metastore_service_name" {
  description = "Name for new metastore service"
  type        = string
  default     = null
}

variable "metastore_tier" {
  description = "Metastore tier"
  type        = string
  default     = "DEVELOPER"
}

variable "metastore_release_channel" {
  description = "Metastore release channel"
  type        = string
  default     = "STABLE"
}

variable "metastore_database_type" {
  description = "Metastore database type"
  type        = string
  default     = "MYSQL"
}

variable "metastore_hive_version" {
  description = "Hive metastore version"
  type        = string
  default     = "3.1.2"
}

variable "metastore_config_overrides" {
  description = "Metastore config overrides"
  type        = map(string)
  default     = {}
}

variable "metastore_kerberos_keytab_secret" {
  description = "Metastore Kerberos keytab secret"
  type        = string
  default     = null
}

variable "metastore_kerberos_principal" {
  description = "Metastore Kerberos principal"
  type        = string
  default     = null
}

variable "metastore_kerberos_config_gcs_uri" {
  description = "Metastore Kerberos config GCS URI"
  type        = string
  default     = null
}

variable "metastore_auxiliary_version_key" {
  description = "Metastore auxiliary version key"
  type        = string
  default     = null
}

variable "metastore_auxiliary_version" {
  description = "Metastore auxiliary version"
  type        = string
  default     = null
}

variable "metastore_auxiliary_config_overrides" {
  description = "Metastore auxiliary config overrides"
  type        = map(string)
  default     = {}
}

variable "metastore_consumer_subnetworks" {
  description = "Consumer subnetworks for metastore"
  type        = list(string)
  default     = []
}

variable "metastore_kms_key" {
  description = "KMS key for metastore"
  type        = string
  default     = null
}

variable "metastore_port" {
  description = "Port for metastore"
  type        = number
  default     = 9083
}

variable "metastore_maintenance_window_hour" {
  description = "Maintenance window hour"
  type        = number
  default     = 2
}

variable "metastore_maintenance_window_day" {
  description = "Maintenance window day"
  type        = string
  default     = "SUNDAY"
}

variable "metastore_telemetry_log_format" {
  description = "Telemetry log format"
  type        = string
  default     = "JSON"
}

variable "metastore_data_catalog_enabled" {
  description = "Enable Data Catalog integration"
  type        = bool
  default     = false
}

variable "metastore_instance_size" {
  description = "Metastore instance size"
  type        = string
  default     = null
}

variable "metastore_scaling_factor" {
  description = "Metastore scaling factor"
  type        = number
  default     = null
}

# Jobs Configuration
variable "spark_jobs" {
  description = "Spark jobs to run"
  type        = map(any)
  default     = {}
}

variable "pyspark_jobs" {
  description = "PySpark jobs to run"
  type        = map(any)
  default     = {}
}

variable "hive_jobs" {
  description = "Hive jobs to run"
  type        = map(any)
  default     = {}
}

variable "pig_jobs" {
  description = "Pig jobs to run"
  type        = map(any)
  default     = {}
}

variable "hadoop_jobs" {
  description = "Hadoop jobs to run"
  type        = map(any)
  default     = {}
}

variable "sparksql_jobs" {
  description = "SparkSQL jobs to run"
  type        = map(any)
  default     = {}
}

variable "presto_jobs" {
  description = "Presto jobs to run"
  type        = map(any)
  default     = {}
}

# Virtual Cluster Configuration
variable "kubernetes_namespace" {
  description = "Kubernetes namespace for virtual cluster"
  type        = string
  default     = "default"
}

variable "kubernetes_component_versions" {
  description = "Kubernetes component versions"
  type        = map(string)
  default     = {}
}

variable "kubernetes_properties" {
  description = "Kubernetes properties"
  type        = map(string)
  default     = {}
}

variable "gke_cluster_target" {
  description = "Target GKE cluster"
  type        = string
  default     = null
}

variable "gke_node_pool" {
  description = "GKE node pool"
  type        = string
  default     = null
}

variable "gke_node_pool_roles" {
  description = "GKE node pool roles"
  type        = list(string)
  default     = ["DEFAULT"]
}

variable "gke_node_machine_type" {
  description = "GKE node machine type"
  type        = string
  default     = "n2-standard-4"
}

variable "gke_node_local_ssd_count" {
  description = "GKE node local SSD count"
  type        = number
  default     = 0
}

variable "gke_node_disk_size_gb" {
  description = "GKE node disk size"
  type        = number
  default     = 100
}

variable "gke_node_disk_type" {
  description = "GKE node disk type"
  type        = string
  default     = "pd-standard"
}

variable "gke_node_oauth_scopes" {
  description = "GKE node OAuth scopes"
  type        = list(string)
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}

variable "gke_node_service_account" {
  description = "GKE node service account"
  type        = string
  default     = null
}

variable "gke_node_tags" {
  description = "GKE node tags"
  type        = list(string)
  default     = []
}

variable "gke_node_min_cpu_platform" {
  description = "GKE node minimum CPU platform"
  type        = string
  default     = null
}

variable "gke_node_preemptible" {
  description = "Use preemptible GKE nodes"
  type        = bool
  default     = false
}

variable "gke_node_spot" {
  description = "Use spot GKE nodes"
  type        = bool
  default     = false
}

variable "gke_node_accelerator_count" {
  description = "GKE node accelerator count"
  type        = number
  default     = 0
}

variable "gke_node_accelerator_type" {
  description = "GKE node accelerator type"
  type        = string
  default     = null
}

variable "gke_node_gpu_partition_size" {
  description = "GKE node GPU partition size"
  type        = string
  default     = null
}

variable "gke_node_locations" {
  description = "GKE node locations"
  type        = list(string)
  default     = []
}

variable "gke_node_min_count" {
  description = "GKE node minimum count"
  type        = number
  default     = 1
}

variable "gke_node_max_count" {
  description = "GKE node maximum count"
  type        = number
  default     = 10
}

# Workflow Template
variable "create_workflow_template" {
  description = "Create workflow template"
  type        = bool
  default     = false
}

variable "workflow_template_name" {
  description = "Workflow template name"
  type        = string
  default     = null
}

variable "workflow_jobs" {
  description = "Jobs in workflow"
  type        = list(any)
  default     = []
}

variable "workflow_master_num_instances" {
  description = "Workflow master instances"
  type        = number
  default     = 1
}

variable "workflow_master_machine_type" {
  description = "Workflow master machine type"
  type        = string
  default     = "n2-standard-4"
}

variable "workflow_master_boot_disk_type" {
  description = "Workflow master boot disk type"
  type        = string
  default     = "pd-standard"
}

variable "workflow_master_boot_disk_size_gb" {
  description = "Workflow master boot disk size"
  type        = number
  default     = 100
}

variable "workflow_worker_num_instances" {
  description = "Workflow worker instances"
  type        = number
  default     = 2
}

variable "workflow_worker_machine_type" {
  description = "Workflow worker machine type"
  type        = string
  default     = "n2-standard-4"
}

variable "workflow_worker_boot_disk_type" {
  description = "Workflow worker boot disk type"
  type        = string
  default     = "pd-standard"
}

variable "workflow_worker_boot_disk_size_gb" {
  description = "Workflow worker boot disk size"
  type        = number
  default     = 100
}

variable "workflow_software_properties" {
  description = "Workflow software properties"
  type        = map(string)
  default     = {}
}

variable "workflow_auto_delete_ttl" {
  description = "Workflow auto delete TTL"
  type        = string
  default     = "3600s"
}

variable "workflow_parameter_name" {
  description = "Workflow parameter name"
  type        = string
  default     = null
}

variable "workflow_parameter_fields" {
  description = "Workflow parameter fields"
  type        = list(string)
  default     = []
}

variable "workflow_parameter_description" {
  description = "Workflow parameter description"
  type        = string
  default     = null
}

variable "workflow_parameter_validation_regex" {
  description = "Workflow parameter validation regex"
  type        = list(string)
  default     = []
}

variable "workflow_parameter_validation_values" {
  description = "Workflow parameter validation values"
  type        = list(string)
  default     = []
}

variable "workflow_dag_timeout" {
  description = "Workflow DAG timeout"
  type        = string
  default     = null
}

variable "workflow_version" {
  description = "Workflow version"
  type        = number
  default     = null
}