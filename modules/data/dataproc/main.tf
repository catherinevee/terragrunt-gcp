# Google Cloud Dataproc Module
# Manages Dataproc clusters, jobs, workflows, and autoscaling policies

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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

locals {
  # Cluster name with optional suffix
  cluster_name = var.cluster_name != null ? var.cluster_name : "${var.name_prefix}-${random_id.cluster_suffix[0].hex}"

  # Network configuration
  network    = var.network != null ? var.network : "default"
  subnetwork = var.subnetwork != null ? var.subnetwork : "default"

  # Labels with defaults
  labels = merge(
    var.labels,
    {
      managed_by   = "terraform"
      module       = "dataproc"
      environment  = var.environment
      cluster_type = var.cluster_type
      created_at   = formatdate("YYYY-MM-DD", timestamp())
    }
  )

  # GCS bucket for staging
  staging_bucket = var.staging_bucket != null ? var.staging_bucket : (
    var.create_staging_bucket ? google_storage_bucket.staging_bucket[0].name : "${var.project_id}-dataproc-staging-${var.region}"
  )

  # Default cluster config
  default_cluster_config = {
    staging_bucket = local.staging_bucket
    temp_bucket    = var.temp_bucket != null ? var.temp_bucket : local.staging_bucket
  }

  # Merge cluster config
  cluster_config = merge(
    local.default_cluster_config,
    var.cluster_config
  )

  # Autoscaling policy ID
  autoscaling_policy_id = var.autoscaling_policy_id != null ? var.autoscaling_policy_id : (
    var.create_autoscaling_policy ? google_dataproc_autoscaling_policy.autoscaling_policy[0].id : null
  )

  # Metastore service
  metastore_service = var.metastore_service != null ? var.metastore_service : (
    var.create_metastore ? google_dataproc_metastore_service.metastore[0].id : null
  )

  # Software config with defaults
  software_config = merge(
    {
      image_version = var.image_version
      override_properties = merge(
        var.enable_component_gateway ? {
          "dataproc:dataproc.allow.zero.workers" = "true"
        } : {},
        var.override_properties
      )
    },
    var.software_config
  )

  # Initialize actions
  initialization_actions = concat(
    var.initialization_actions,
    var.enable_stackdriver_monitoring ? [{
      script      = "gs://goog-dataproc-initialization-actions-${var.region}/stackdriver/stackdriver.sh"
      timeout_sec = 300
    }] : [],
    var.enable_jupyter ? [{
      script      = "gs://goog-dataproc-initialization-actions-${var.region}/jupyter/jupyter.sh"
      timeout_sec = 300
    }] : [],
    var.enable_kafka ? [{
      script      = "gs://goog-dataproc-initialization-actions-${var.region}/kafka/kafka.sh"
      timeout_sec = 600
    }] : []
  )
}

# Random suffix for cluster naming
resource "random_id" "cluster_suffix" {
  count       = var.cluster_name == null ? 1 : 0
  byte_length = 4

  keepers = {
    project_id = var.project_id
    region     = var.region
  }
}

# Staging bucket for Dataproc
resource "google_storage_bucket" "staging_bucket" {
  count = var.create_staging_bucket ? 1 : 0

  project       = var.project_id
  name          = var.staging_bucket_name != null ? var.staging_bucket_name : "${var.project_id}-dataproc-staging-${var.region}"
  location      = var.region
  storage_class = "STANDARD"

  uniform_bucket_level_access = true
  force_destroy               = var.staging_bucket_force_destroy

  lifecycle_rule {
    condition {
      age = var.staging_bucket_lifecycle_days
    }
    action {
      type = "Delete"
    }
  }

  encryption {
    default_kms_key_name = var.kms_key_name
  }

  labels = local.labels
}

# Dataproc Autoscaling Policy
resource "google_dataproc_autoscaling_policy" "autoscaling_policy" {
  count = var.create_autoscaling_policy ? 1 : 0

  provider = google-beta

  project   = var.project_id
  location  = var.region
  policy_id = var.autoscaling_policy_name != null ? var.autoscaling_policy_name : "${local.cluster_name}-autoscale"

  basic_algorithm {
    yarn_config {
      graceful_decommission_timeout  = var.autoscale_graceful_decommission_timeout
      scale_up_factor                = var.autoscale_scale_up_factor
      scale_down_factor              = var.autoscale_scale_down_factor
      scale_up_min_worker_fraction   = var.autoscale_scale_up_min_worker_fraction
      scale_down_min_worker_fraction = var.autoscale_scale_down_min_worker_fraction
    }

    cooldown_period = var.autoscale_cooldown_period
  }

  worker_config {
    min_instances = var.autoscale_min_workers
    max_instances = var.autoscale_max_workers
    weight        = var.autoscale_primary_worker_weight
  }

  dynamic "secondary_worker_config" {
    for_each = var.preemptible_workers > 0 || var.autoscale_secondary_workers ? [1] : []
    content {
      min_instances = var.autoscale_min_secondary_workers
      max_instances = var.autoscale_max_secondary_workers
      weight        = var.autoscale_secondary_worker_weight
    }
  }

  labels = local.labels
}

# Dataproc Metastore Service
resource "google_dataproc_metastore_service" "metastore" {
  count = var.create_metastore ? 1 : 0

  provider = google-beta

  project    = var.project_id
  service_id = var.metastore_service_name != null ? var.metastore_service_name : "${local.cluster_name}-metastore"
  location   = var.region

  tier            = var.metastore_tier
  release_channel = var.metastore_release_channel
  database_type   = var.metastore_database_type

  maintenance_window {
    hour_of_day = var.metastore_maintenance_window_hour
    day_of_week = var.metastore_maintenance_window_day
  }

  hive_metastore_config {
    version          = var.metastore_hive_version
    config_overrides = var.metastore_config_overrides
    kerberos_config {
      keytab {
        cloud_secret = var.metastore_kerberos_keytab_secret
      }
      principal           = var.metastore_kerberos_principal
      krb5_config_gcs_uri = var.metastore_kerberos_config_gcs_uri
    }
    auxiliary_versions {
      key              = var.metastore_auxiliary_version_key
      version          = var.metastore_auxiliary_version
      config_overrides = var.metastore_auxiliary_config_overrides
    }
  }

  network_config {
    consumers {
      subnetwork = var.metastore_consumer_subnetworks
    }
  }

  encryption_config {
    kms_key = var.metastore_kms_key
  }

  port = var.metastore_port

  telemetry_config {
    log_format = var.metastore_telemetry_log_format
  }

  metadata_integration {
    data_catalog_config {
      enabled = var.metastore_data_catalog_enabled
    }
  }

  scaling_config {
    instance_size  = var.metastore_instance_size
    scaling_factor = var.metastore_scaling_factor
  }

  labels = local.labels
}

# Dataproc Cluster
resource "google_dataproc_cluster" "cluster" {
  count = var.deploy_cluster ? 1 : 0

  provider = google-beta

  project = var.project_id
  name    = local.cluster_name
  region  = var.region

  labels = local.labels

  cluster_config {
    staging_bucket = local.staging_bucket
    temp_bucket    = var.temp_bucket

    # Master configuration
    master_config {
      num_instances    = var.master_num_instances
      machine_type     = var.master_machine_type
      min_cpu_platform = var.master_min_cpu_platform

      disk_config {
        boot_disk_type      = var.master_boot_disk_type
        boot_disk_size_gb   = var.master_boot_disk_size_gb
        num_local_ssds      = var.master_num_local_ssds
        local_ssd_interface = var.master_local_ssd_interface
      }

      dynamic "accelerators" {
        for_each = var.master_accelerators
        content {
          accelerator_type  = accelerators.value.type
          accelerator_count = accelerators.value.count
        }
      }

      image_uri = var.master_image_uri
    }

    # Worker configuration
    worker_config {
      num_instances     = var.worker_num_instances
      machine_type      = var.worker_machine_type
      min_cpu_platform  = var.worker_min_cpu_platform
      min_num_instances = var.enable_autoscaling ? var.autoscale_min_workers : null

      disk_config {
        boot_disk_type      = var.worker_boot_disk_type
        boot_disk_size_gb   = var.worker_boot_disk_size_gb
        num_local_ssds      = var.worker_num_local_ssds
        local_ssd_interface = var.worker_local_ssd_interface
      }

      dynamic "accelerators" {
        for_each = var.worker_accelerators
        content {
          accelerator_type  = accelerators.value.type
          accelerator_count = accelerators.value.count
        }
      }

      image_uri = var.worker_image_uri
    }

    # Preemptible worker configuration
    dynamic "preemptible_worker_config" {
      for_each = var.preemptible_workers > 0 ? [1] : []
      content {
        num_instances  = var.preemptible_workers
        preemptibility = var.preemptible_worker_type
        disk_config {
          boot_disk_type      = var.preemptible_boot_disk_type
          boot_disk_size_gb   = var.preemptible_boot_disk_size_gb
          num_local_ssds      = var.preemptible_num_local_ssds
          local_ssd_interface = var.preemptible_local_ssd_interface
        }
      }
    }

    # Software configuration
    software_config {
      image_version       = var.image_version
      optional_components = var.optional_components
      properties          = local.software_config.override_properties
    }

    # Security configuration
    security_config {
      kerberos_config {
        enable_kerberos                       = var.enable_kerberos
        root_principal_password_uri           = var.kerberos_root_principal_password_uri
        kms_key_uri                           = var.kerberos_kms_key_uri
        keystore_uri                          = var.kerberos_keystore_uri
        truststore_uri                        = var.kerberos_truststore_uri
        keystore_password_uri                 = var.kerberos_keystore_password_uri
        key_password_uri                      = var.kerberos_key_password_uri
        truststore_password_uri               = var.kerberos_truststore_password_uri
        cross_realm_trust_realm               = var.kerberos_cross_realm_trust_realm
        cross_realm_trust_kdc                 = var.kerberos_cross_realm_trust_kdc
        cross_realm_trust_admin_server        = var.kerberos_cross_realm_trust_admin_server
        cross_realm_trust_shared_password_uri = var.kerberos_cross_realm_trust_shared_password_uri
        kdc_db_key_uri                        = var.kerberos_kdc_db_key_uri
        tgt_lifetime_hours                    = var.kerberos_tgt_lifetime_hours
        realm                                 = var.kerberos_realm
      }

      identity_config {
        user_service_account_mapping = var.user_service_account_mapping
      }
    }

    # Autoscaling configuration
    dynamic "autoscaling_config" {
      for_each = var.enable_autoscaling && local.autoscaling_policy_id != null ? [1] : []
      content {
        policy_uri = local.autoscaling_policy_id
      }
    }

    # Lifecycle configuration
    lifecycle_config {
      idle_delete_ttl  = var.idle_delete_ttl
      auto_delete_time = var.auto_delete_time
      auto_delete_ttl  = var.auto_delete_ttl
    }

    # Endpoint configuration
    endpoint_config {
      enable_http_port_access = var.enable_http_port_access
      http_ports              = var.http_ports
    }

    # Metastore configuration
    dynamic "metastore_config" {
      for_each = local.metastore_service != null ? [1] : []
      content {
        dataproc_metastore_service = local.metastore_service
      }
    }

    # GCE cluster configuration
    gce_cluster_config {
      zone                   = var.zone
      network                = local.network
      subnetwork             = local.subnetwork
      internal_ip_only       = var.internal_ip_only
      service_account        = var.service_account
      service_account_scopes = var.service_account_scopes
      tags                   = var.network_tags

      metadata = merge(
        var.metadata,
        var.enable_component_gateway ? {
          "enable-guest-attributes" = "true"
        } : {}
      )

      reservation_affinity {
        consume_reservation_type = var.reservation_affinity_consume_type
        key                      = var.reservation_affinity_key
        values                   = var.reservation_affinity_values
      }

      node_group_affinity {
        node_group_uri = var.node_group_affinity_uri
      }

      shielded_instance_config {
        enable_secure_boot          = var.enable_secure_boot
        enable_vtpm                 = var.enable_vtpm
        enable_integrity_monitoring = var.enable_integrity_monitoring
      }
    }

    # Dataproc metric configuration
    dataproc_metric_config {
      metrics {
        metric_source    = var.metric_source
        metric_overrides = var.metric_overrides
      }
    }

    # Initialization actions
    dynamic "initialization_action" {
      for_each = local.initialization_actions
      content {
        script      = initialization_action.value.script
        timeout_sec = lookup(initialization_action.value, "timeout_sec", 300)
      }
    }

    # Encryption configuration
    encryption_config {
      kms_key_name = var.kms_key_name
    }
  }

  # Cluster labels
  dynamic "virtual_cluster_config" {
    for_each = var.cluster_type == "virtual" ? [1] : []
    content {
      staging_bucket = local.staging_bucket

      kubernetes_cluster_config {
        kubernetes_namespace = var.kubernetes_namespace

        kubernetes_software_config {
          component_version = var.kubernetes_component_versions
          properties        = var.kubernetes_properties
        }

        gke_cluster_config {
          gke_cluster_target = var.gke_cluster_target

          node_pool_target {
            node_pool = var.gke_node_pool
            roles     = var.gke_node_pool_roles

            node_pool_config {
              config {
                machine_type     = var.gke_node_machine_type
                local_ssd_count  = var.gke_node_local_ssd_count
                disk_size_gb     = var.gke_node_disk_size_gb
                disk_type        = var.gke_node_disk_type
                oauth_scopes     = var.gke_node_oauth_scopes
                service_account  = var.gke_node_service_account
                tags             = var.gke_node_tags
                min_cpu_platform = var.gke_node_min_cpu_platform
                preemptible      = var.gke_node_preemptible
                spot             = var.gke_node_spot

                accelerators {
                  accelerator_count  = var.gke_node_accelerator_count
                  accelerator_type   = var.gke_node_accelerator_type
                  gpu_partition_size = var.gke_node_gpu_partition_size
                }
              }

              locations = var.gke_node_locations

              autoscaling {
                min_node_count = var.gke_node_min_count
                max_node_count = var.gke_node_max_count
              }
            }
          }
        }
      }
    }
  }

  graceful_decommission_timeout = var.graceful_decommission_timeout

  depends_on = [
    google_dataproc_autoscaling_policy.autoscaling_policy,
    google_dataproc_metastore_service.metastore,
    google_storage_bucket.staging_bucket
  ]
}

# Dataproc Jobs
resource "google_dataproc_job" "spark_job" {
  for_each = var.spark_jobs

  project      = var.project_id
  region       = var.region
  force_delete = lookup(each.value, "force_delete", false)

  placement {
    cluster_name = google_dataproc_cluster.cluster[0].name
  }

  spark_config {
    main_class        = lookup(each.value, "main_class", null)
    main_jar_file_uri = lookup(each.value, "main_jar_file_uri", null)
    jar_file_uris     = lookup(each.value, "jar_file_uris", [])
    file_uris         = lookup(each.value, "file_uris", [])
    archive_uris      = lookup(each.value, "archive_uris", [])
    properties        = lookup(each.value, "properties", {})
    args              = lookup(each.value, "args", [])

    logging_config {
      driver_log_levels = lookup(each.value, "driver_log_levels", {})
    }
  }

  labels = merge(
    local.labels,
    lookup(each.value, "labels", {}),
    {
      job_type = "spark"
      job_name = each.key
    }
  )

  scheduling {
    max_failures_per_hour = lookup(each.value, "max_failures_per_hour", 1)
    max_failures_total    = lookup(each.value, "max_failures_total", 4)
  }

  depends_on = [google_dataproc_cluster.cluster]
}

resource "google_dataproc_job" "pyspark_job" {
  for_each = var.pyspark_jobs

  project      = var.project_id
  region       = var.region
  force_delete = lookup(each.value, "force_delete", false)

  placement {
    cluster_name = google_dataproc_cluster.cluster[0].name
  }

  pyspark_config {
    main_python_file_uri = each.value.main_python_file_uri
    python_file_uris     = lookup(each.value, "python_file_uris", [])
    jar_file_uris        = lookup(each.value, "jar_file_uris", [])
    file_uris            = lookup(each.value, "file_uris", [])
    archive_uris         = lookup(each.value, "archive_uris", [])
    properties           = lookup(each.value, "properties", {})
    args                 = lookup(each.value, "args", [])

    logging_config {
      driver_log_levels = lookup(each.value, "driver_log_levels", {})
    }
  }

  labels = merge(
    local.labels,
    lookup(each.value, "labels", {}),
    {
      job_type = "pyspark"
      job_name = each.key
    }
  )

  scheduling {
    max_failures_per_hour = lookup(each.value, "max_failures_per_hour", 1)
    max_failures_total    = lookup(each.value, "max_failures_total", 4)
  }

  depends_on = [google_dataproc_cluster.cluster]
}

resource "google_dataproc_job" "hive_job" {
  for_each = var.hive_jobs

  project      = var.project_id
  region       = var.region
  force_delete = lookup(each.value, "force_delete", false)

  placement {
    cluster_name = google_dataproc_cluster.cluster[0].name
  }

  hive_config {
    query_file_uri      = lookup(each.value, "query_file_uri", null)
    query_list          = lookup(each.value, "query_list", null)
    continue_on_failure = lookup(each.value, "continue_on_failure", false)
    script_variables    = lookup(each.value, "script_variables", {})
    properties          = lookup(each.value, "properties", {})
    jar_file_uris       = lookup(each.value, "jar_file_uris", [])
  }

  labels = merge(
    local.labels,
    lookup(each.value, "labels", {}),
    {
      job_type = "hive"
      job_name = each.key
    }
  )

  scheduling {
    max_failures_per_hour = lookup(each.value, "max_failures_per_hour", 1)
    max_failures_total    = lookup(each.value, "max_failures_total", 4)
  }

  depends_on = [google_dataproc_cluster.cluster]
}

resource "google_dataproc_job" "pig_job" {
  for_each = var.pig_jobs

  project      = var.project_id
  region       = var.region
  force_delete = lookup(each.value, "force_delete", false)

  placement {
    cluster_name = google_dataproc_cluster.cluster[0].name
  }

  pig_config {
    query_file_uri      = lookup(each.value, "query_file_uri", null)
    query_list          = lookup(each.value, "query_list", null)
    continue_on_failure = lookup(each.value, "continue_on_failure", false)
    script_variables    = lookup(each.value, "script_variables", {})
    properties          = lookup(each.value, "properties", {})
    jar_file_uris       = lookup(each.value, "jar_file_uris", [])

    logging_config {
      driver_log_levels = lookup(each.value, "driver_log_levels", {})
    }
  }

  labels = merge(
    local.labels,
    lookup(each.value, "labels", {}),
    {
      job_type = "pig"
      job_name = each.key
    }
  )

  scheduling {
    max_failures_per_hour = lookup(each.value, "max_failures_per_hour", 1)
    max_failures_total    = lookup(each.value, "max_failures_total", 4)
  }

  depends_on = [google_dataproc_cluster.cluster]
}

resource "google_dataproc_job" "hadoop_job" {
  for_each = var.hadoop_jobs

  project      = var.project_id
  region       = var.region
  force_delete = lookup(each.value, "force_delete", false)

  placement {
    cluster_name = google_dataproc_cluster.cluster[0].name
  }

  hadoop_config {
    main_class        = lookup(each.value, "main_class", null)
    main_jar_file_uri = lookup(each.value, "main_jar_file_uri", null)
    jar_file_uris     = lookup(each.value, "jar_file_uris", [])
    file_uris         = lookup(each.value, "file_uris", [])
    archive_uris      = lookup(each.value, "archive_uris", [])
    properties        = lookup(each.value, "properties", {})
    args              = lookup(each.value, "args", [])

    logging_config {
      driver_log_levels = lookup(each.value, "driver_log_levels", {})
    }
  }

  labels = merge(
    local.labels,
    lookup(each.value, "labels", {}),
    {
      job_type = "hadoop"
      job_name = each.key
    }
  )

  scheduling {
    max_failures_per_hour = lookup(each.value, "max_failures_per_hour", 1)
    max_failures_total    = lookup(each.value, "max_failures_total", 4)
  }

  depends_on = [google_dataproc_cluster.cluster]
}

resource "google_dataproc_job" "sparksql_job" {
  for_each = var.sparksql_jobs

  project      = var.project_id
  region       = var.region
  force_delete = lookup(each.value, "force_delete", false)

  placement {
    cluster_name = google_dataproc_cluster.cluster[0].name
  }

  sparksql_config {
    query_file_uri   = lookup(each.value, "query_file_uri", null)
    query_list       = lookup(each.value, "query_list", null)
    script_variables = lookup(each.value, "script_variables", {})
    properties       = lookup(each.value, "properties", {})
    jar_file_uris    = lookup(each.value, "jar_file_uris", [])

    logging_config {
      driver_log_levels = lookup(each.value, "driver_log_levels", {})
    }
  }

  labels = merge(
    local.labels,
    lookup(each.value, "labels", {}),
    {
      job_type = "sparksql"
      job_name = each.key
    }
  )

  scheduling {
    max_failures_per_hour = lookup(each.value, "max_failures_per_hour", 1)
    max_failures_total    = lookup(each.value, "max_failures_total", 4)
  }

  depends_on = [google_dataproc_cluster.cluster]
}

resource "google_dataproc_job" "presto_job" {
  for_each = var.presto_jobs

  project      = var.project_id
  region       = var.region
  force_delete = lookup(each.value, "force_delete", false)

  placement {
    cluster_name = google_dataproc_cluster.cluster[0].name
  }

  presto_config {
    query_file_uri      = lookup(each.value, "query_file_uri", null)
    query_list          = lookup(each.value, "query_list", null)
    continue_on_failure = lookup(each.value, "continue_on_failure", false)
    output_format       = lookup(each.value, "output_format", "CSV")
    client_tags         = lookup(each.value, "client_tags", [])
    properties          = lookup(each.value, "properties", {})

    logging_config {
      driver_log_levels = lookup(each.value, "driver_log_levels", {})
    }
  }

  labels = merge(
    local.labels,
    lookup(each.value, "labels", {}),
    {
      job_type = "presto"
      job_name = each.key
    }
  )

  scheduling {
    max_failures_per_hour = lookup(each.value, "max_failures_per_hour", 1)
    max_failures_total    = lookup(each.value, "max_failures_total", 4)
  }

  depends_on = [google_dataproc_cluster.cluster]
}

# Dataproc Workflow Template
resource "google_dataproc_workflow_template" "workflow" {
  count = var.create_workflow_template ? 1 : 0

  provider = google-beta

  project  = var.project_id
  location = var.region
  name     = var.workflow_template_name != null ? var.workflow_template_name : "${local.cluster_name}-workflow"

  placement {
    managed_cluster {
      cluster_name = "${local.cluster_name}-workflow-cluster"

      config {
        staging_bucket = local.staging_bucket
        temp_bucket    = var.temp_bucket

        master_config {
          num_instances = var.workflow_master_num_instances
          machine_type  = var.workflow_master_machine_type
          disk_config {
            boot_disk_type    = var.workflow_master_boot_disk_type
            boot_disk_size_gb = var.workflow_master_boot_disk_size_gb
          }
        }

        worker_config {
          num_instances = var.workflow_worker_num_instances
          machine_type  = var.workflow_worker_machine_type
          disk_config {
            boot_disk_type    = var.workflow_worker_boot_disk_type
            boot_disk_size_gb = var.workflow_worker_boot_disk_size_gb
          }
        }

        software_config {
          image_version = var.image_version
          properties    = var.workflow_software_properties
        }

        gce_cluster_config {
          zone                   = var.zone
          network                = local.network
          subnetwork             = local.subnetwork
          internal_ip_only       = var.internal_ip_only
          service_account        = var.service_account
          service_account_scopes = var.service_account_scopes
          tags                   = var.network_tags
        }

        lifecycle_config {
          auto_delete_ttl = var.workflow_auto_delete_ttl
        }
      }

      labels = local.labels
    }
  }

  dynamic "jobs" {
    for_each = var.workflow_jobs
    content {
      step_id = jobs.value.step_id

      dynamic "spark_job" {
        for_each = lookup(jobs.value, "spark_job", null) != null ? [jobs.value.spark_job] : []
        content {
          main_class        = lookup(spark_job.value, "main_class", null)
          main_jar_file_uri = lookup(spark_job.value, "main_jar_file_uri", null)
          jar_file_uris     = lookup(spark_job.value, "jar_file_uris", [])
          properties        = lookup(spark_job.value, "properties", {})
          args              = lookup(spark_job.value, "args", [])
        }
      }

      dynamic "pyspark_job" {
        for_each = lookup(jobs.value, "pyspark_job", null) != null ? [jobs.value.pyspark_job] : []
        content {
          main_python_file_uri = pyspark_job.value.main_python_file_uri
          python_file_uris     = lookup(pyspark_job.value, "python_file_uris", [])
          properties           = lookup(pyspark_job.value, "properties", {})
          args                 = lookup(pyspark_job.value, "args", [])
        }
      }

      prerequisite_step_ids = lookup(jobs.value, "prerequisite_step_ids", [])

      labels = merge(
        local.labels,
        lookup(jobs.value, "labels", {})
      )

      scheduling {
        max_failures_per_hour = lookup(jobs.value, "max_failures_per_hour", 1)
        max_failures_total    = lookup(jobs.value, "max_failures_total", 4)
      }
    }
  }

  parameters {
    name        = var.workflow_parameter_name
    fields      = var.workflow_parameter_fields
    description = var.workflow_parameter_description
    validation {
      regex {
        regexes = var.workflow_parameter_validation_regex
      }
      values {
        values = var.workflow_parameter_validation_values
      }
    }
  }

  labels = local.labels

  dag_timeout = var.workflow_dag_timeout
  version     = var.workflow_version
}

# IAM bindings
resource "google_project_iam_member" "dataproc_worker" {
  count = var.create_service_account_roles ? 1 : 0

  project = var.project_id
  role    = "roles/dataproc.worker"
  member  = "serviceAccount:${var.service_account}"
}

resource "google_project_iam_member" "dataproc_editor" {
  count = var.create_service_account_roles ? 1 : 0

  project = var.project_id
  role    = "roles/dataproc.editor"
  member  = "serviceAccount:${var.service_account}"
}