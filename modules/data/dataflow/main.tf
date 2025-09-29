# Google Cloud Dataflow Module
# Manages Dataflow jobs, templates, and pipelines with comprehensive configuration

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
  # Job name with optional suffix
  job_name = var.job_name != null ? var.job_name : "${var.name_prefix}-${random_id.job_suffix[0].hex}"

  # Network configuration
  network    = var.network != null ? var.network : "default"
  subnetwork = var.subnetwork != null ? var.subnetwork : "regions/${var.region}/subnetworks/default"

  # Labels with defaults
  labels = merge(
    var.labels,
    {
      managed_by  = "terraform"
      module      = "dataflow"
      environment = var.environment
      job_type    = var.template_type
      created_at  = formatdate("YYYY-MM-DD", timestamp())
    }
  )

  # Default job parameters
  default_parameters = {
    maxNumWorkers         = var.max_workers
    numWorkers            = var.initial_workers
    workerMachineType     = var.machine_type
    workerDiskType        = var.disk_type
    diskSizeGb            = var.disk_size_gb
    zone                  = var.zone
    region                = var.region
    serviceAccountEmail   = var.service_account_email
    usePublicIps          = var.use_public_ips ? "true" : "false"
    enableStreamingEngine = var.enable_streaming_engine ? "true" : "false"
  }

  # Merge default and custom parameters
  job_parameters = merge(
    local.default_parameters,
    var.parameters
  )

  # Template GCS path
  template_gcs_path = var.template_gcs_path != null ? var.template_gcs_path : (
    var.template_type == "classic" ? var.classic_template_location : null
  )

  # Flex template spec
  flex_template_spec = var.flex_template_spec != null ? var.flex_template_spec : (
    var.create_flex_template_spec ? {
      image = var.container_image
      sdkInfo = {
        language = var.sdk_language
      }
      metadata = merge(
        {
          name        = local.job_name
          description = var.job_description
        },
        var.flex_template_metadata
      )
      defaultEnvironment = {
        tempLocation                   = var.temp_location
        maxWorkers                     = var.max_workers
        numWorkers                     = var.initial_workers
        workerMachineType              = var.machine_type
        additionalExperiments          = var.additional_experiments
        additionalUserLabels           = local.labels
        enableStreamingEngine          = var.enable_streaming_engine
        network                        = local.network
        subnetwork                     = local.subnetwork
        serviceAccountEmail            = var.service_account_email
        kmsKeyName                     = var.kms_key_name
        ipConfiguration                = var.ip_configuration
        workerRegion                   = var.worker_region
        workerZone                     = var.worker_zone
        enableLauncherVmKerberosConfig = var.enable_kerberos
        stagingLocation                = var.staging_location
      }
      parameterMetadata = var.parameter_metadata
    } : null
  )

  # Streaming update parameters
  streaming_update_params = var.enable_streaming_update ? {
    updateCompatibilityVersion = var.update_compatibility_version
    transformNameMapping       = var.transform_name_mapping
  } : {}

  # Autoscaling configuration
  autoscaling_config = var.enable_autoscaling ? {
    algorithm                   = var.autoscaling_algorithm
    maxNumWorkers               = var.max_workers
    enableAutoScalingFlexRSGoal = var.enable_flexrs_goal
  } : {}
}

# Random suffix for job naming
resource "random_id" "job_suffix" {
  count       = var.job_name == null ? 1 : 0
  byte_length = 4

  keepers = {
    project_id = var.project_id
    region     = var.region
  }
}

# Storage bucket for staging (optional)
resource "google_storage_bucket" "staging_bucket" {
  count = var.create_staging_bucket ? 1 : 0

  project       = var.project_id
  name          = var.staging_bucket_name != null ? var.staging_bucket_name : "${var.project_id}-dataflow-staging-${var.region}"
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

# Storage bucket for temp files (optional)
resource "google_storage_bucket" "temp_bucket" {
  count = var.create_temp_bucket ? 1 : 0

  project       = var.project_id
  name          = var.temp_bucket_name != null ? var.temp_bucket_name : "${var.project_id}-dataflow-temp-${var.region}"
  location      = var.region
  storage_class = "STANDARD"

  uniform_bucket_level_access = true
  force_destroy               = var.temp_bucket_force_destroy

  lifecycle_rule {
    condition {
      age = var.temp_bucket_lifecycle_days
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

# Flex Template Spec file (optional)
resource "google_storage_bucket_object" "flex_template_spec" {
  count = var.create_flex_template_spec && local.flex_template_spec != null ? 1 : 0

  bucket  = var.flex_template_bucket
  name    = var.flex_template_spec_path != null ? var.flex_template_spec_path : "${local.job_name}/flex-template.json"
  content = jsonencode(local.flex_template_spec)

  content_type = "application/json"

  depends_on = [
    google_storage_bucket.staging_bucket,
    google_storage_bucket.temp_bucket
  ]
}

# Classic Dataflow Job
resource "google_dataflow_job" "classic_job" {
  count = var.template_type == "classic" && var.deploy_job ? 1 : 0

  project = var.project_id
  name    = local.job_name
  region  = var.region

  template_gcs_path = local.template_gcs_path
  temp_gcs_location = var.temp_location != null ? var.temp_location : (
    var.create_temp_bucket ? "gs://${google_storage_bucket.temp_bucket[0].name}/temp" : null
  )

  parameters = local.job_parameters

  labels = local.labels

  machine_type                 = var.machine_type
  max_workers                  = var.max_workers
  on_delete                    = var.on_delete_action
  skip_wait_on_job_termination = var.skip_wait_on_job_termination

  network               = local.network
  subnetwork            = local.subnetwork
  ip_configuration      = var.ip_configuration
  service_account_email = var.service_account_email
  kms_key_name          = var.kms_key_name

  additional_experiments  = var.additional_experiments
  enable_streaming_engine = var.enable_streaming_engine
  transform_name_mapping  = var.transform_name_mapping

  lifecycle {
    ignore_changes = var.ignore_job_changes
  }

  depends_on = [
    google_storage_bucket.staging_bucket,
    google_storage_bucket.temp_bucket
  ]
}

# Flex Template Job
resource "google_dataflow_flex_template_job" "flex_job" {
  count = var.template_type == "flex" && var.deploy_job ? 1 : 0

  provider = google-beta

  project = var.project_id
  name    = local.job_name
  region  = var.region

  container_spec_gcs_path = var.flex_template_spec_path != null ? (
    var.create_flex_template_spec ?
    "gs://${var.flex_template_bucket}/${google_storage_bucket_object.flex_template_spec[0].name}" :
    var.flex_template_spec_path
  ) : null

  parameters = merge(
    local.job_parameters,
    var.flex_template_parameters
  )

  labels = local.labels

  on_delete                    = var.on_delete_action
  skip_wait_on_job_termination = var.skip_wait_on_job_termination
  machine_type                 = var.machine_type
  max_workers                  = var.max_workers
  num_workers                  = var.initial_workers
  network                      = local.network
  subnetwork                   = local.subnetwork
  temp_location                = var.temp_location
  staging_location             = var.staging_location
  service_account_email        = var.service_account_email
  kms_key_name                 = var.kms_key_name
  ip_configuration             = var.ip_configuration
  additional_experiments       = var.additional_experiments
  launcher_machine_type        = var.launcher_machine_type
  enable_streaming_engine      = var.enable_streaming_engine
  sdk_container_image          = var.container_image
  transform_name_mapping       = var.transform_name_mapping
  autoscaling_algorithm        = var.autoscaling_algorithm

  lifecycle {
    ignore_changes = var.ignore_job_changes
  }

  depends_on = [
    google_storage_bucket.staging_bucket,
    google_storage_bucket.temp_bucket,
    google_storage_bucket_object.flex_template_spec
  ]
}

# SQL Dataflow Job (for SQL-based pipelines)
resource "google_dataflow_job" "sql_job" {
  count = var.template_type == "sql" && var.deploy_job ? 1 : 0

  project = var.project_id
  name    = local.job_name
  region  = var.region

  template_gcs_path = "gs://dataflow-templates-${var.region}/latest/flex/SQLTemplate"
  temp_gcs_location = var.temp_location != null ? var.temp_location : (
    var.create_temp_bucket ? "gs://${google_storage_bucket.temp_bucket[0].name}/temp" : null
  )

  parameters = merge(
    local.job_parameters,
    {
      sqlQuery                            = var.sql_query
      outputTable                         = var.sql_output_table
      bigQueryProject                     = var.sql_bigquery_project != null ? var.sql_bigquery_project : var.project_id
      bigQueryDataset                     = var.sql_bigquery_dataset
      bigQueryLoadingTemporaryDirectory   = var.sql_temp_directory
      outputTableSpec                     = var.sql_output_table_spec
      inputSubscription                   = var.sql_input_subscription
      outputTopic                         = var.sql_output_topic
      javascriptTextTransformGcsPath      = var.sql_udf_gcs_path
      javascriptTextTransformFunctionName = var.sql_udf_function_name
    }
  )

  labels = local.labels

  machine_type                 = var.machine_type
  max_workers                  = var.max_workers
  on_delete                    = var.on_delete_action
  skip_wait_on_job_termination = var.skip_wait_on_job_termination

  network               = local.network
  subnetwork            = local.subnetwork
  ip_configuration      = var.ip_configuration
  service_account_email = var.service_account_email
  kms_key_name          = var.kms_key_name

  additional_experiments  = var.additional_experiments
  enable_streaming_engine = var.enable_streaming_engine

  lifecycle {
    ignore_changes = var.ignore_job_changes
  }

  depends_on = [
    google_storage_bucket.staging_bucket,
    google_storage_bucket.temp_bucket
  ]
}

# Python Dataflow Job (using Apache Beam Python SDK)
resource "null_resource" "python_job" {
  count = var.template_type == "python" && var.deploy_job ? 1 : 0

  triggers = {
    job_name   = local.job_name
    project_id = var.project_id
    region     = var.region
  }

  provisioner "local-exec" {
    command = <<-EOT
      python ${var.python_pipeline_path} \
        --project=${var.project_id} \
        --region=${var.region} \
        --job_name=${local.job_name} \
        --runner=DataflowRunner \
        --temp_location=${var.temp_location} \
        --staging_location=${var.staging_location} \
        --setup_file=${var.python_setup_file} \
        --requirements_file=${var.python_requirements_file} \
        --max_num_workers=${var.max_workers} \
        --num_workers=${var.initial_workers} \
        --machine_type=${var.machine_type} \
        --disk_size_gb=${var.disk_size_gb} \
        --network=${local.network} \
        --subnetwork=${local.subnetwork} \
        --service_account_email=${var.service_account_email} \
        --use_public_ips=${var.use_public_ips} \
        --enable_streaming_engine=${var.enable_streaming_engine} \
        --streaming=${var.is_streaming_job} \
        --save_main_session=${var.python_save_main_session} \
        --sdk_container_image=${var.python_sdk_container_image} \
        --sdk_harness_container_image_overrides='${jsonencode(var.python_sdk_harness_overrides)}' \
        --experiments='${join(",", var.additional_experiments)}' \
        --labels='${jsonencode(local.labels)}' \
        --dataflow_kms_key=${var.kms_key_name} \
        ${join(" ", [for k, v in var.python_pipeline_options : "--${k}=${v}"])}
    EOT

    environment = merge(
      {
        GOOGLE_APPLICATION_CREDENTIALS = var.google_credentials_path
      },
      var.python_environment_vars
    )
  }
}

# Monitoring Alert Policies
resource "google_monitoring_alert_policy" "dataflow_alerts" {
  for_each = var.create_monitoring_alerts ? var.monitoring_alerts : {}

  project      = var.project_id
  display_name = each.value.display_name
  combiner     = lookup(each.value, "combiner", "OR")
  enabled      = lookup(each.value, "enabled", true)

  conditions {
    display_name = each.value.condition_display_name

    condition_threshold {
      filter          = replace(each.value.filter, "JOB_NAME", local.job_name)
      duration        = lookup(each.value, "duration", "60s")
      comparison      = lookup(each.value, "comparison", "COMPARISON_GT")
      threshold_value = each.value.threshold_value

      aggregations {
        alignment_period     = lookup(each.value, "alignment_period", "60s")
        per_series_aligner   = lookup(each.value, "per_series_aligner", "ALIGN_MEAN")
        cross_series_reducer = lookup(each.value, "cross_series_reducer", null)
        group_by_fields      = lookup(each.value, "group_by_fields", null)
      }

      trigger {
        count   = lookup(each.value, "trigger_count", null)
        percent = lookup(each.value, "trigger_percent", null)
      }
    }
  }

  notification_channels = lookup(each.value, "notification_channels", [])

  alert_strategy {
    auto_close = lookup(each.value, "auto_close", "86400s")

    dynamic "rate_limit" {
      for_each = lookup(each.value, "rate_limit", null) != null ? [each.value.rate_limit] : []
      content {
        period = rate_limit.value.period
      }
    }
  }

  documentation {
    content   = lookup(each.value, "documentation_content", "Dataflow job alert for ${local.job_name}")
    mime_type = lookup(each.value, "documentation_mime_type", "text/markdown")
    subject   = lookup(each.value, "documentation_subject", null)
  }

  user_labels = merge(
    local.labels,
    lookup(each.value, "labels", {})
  )
}

# Monitoring Dashboard
resource "google_monitoring_dashboard" "dataflow_dashboard" {
  count = var.create_monitoring_dashboard ? 1 : 0

  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "${local.job_name} Dataflow Dashboard"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Job Status"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"dataflow.googleapis.com/job/is_failed\" resource.type=\"dataflow_job\" resource.label.\"job_name\"=\"${local.job_name}\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_MAX"
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_LINE"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          widget = {
            title = "Elements Processed"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"dataflow.googleapis.com/job/element_count\" resource.type=\"dataflow_job\" resource.label.\"job_name\"=\"${local.job_name}\""
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          yPos   = 4
          widget = {
            title = "System Lag"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"dataflow.googleapis.com/job/system_lag\" resource.type=\"dataflow_job\" resource.label.\"job_name\"=\"${local.job_name}\""
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          yPos   = 4
          widget = {
            title = "Worker CPU Utilization"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"dataflow.googleapis.com/job/current_vcore_count\" resource.type=\"dataflow_job\" resource.label.\"job_name\"=\"${local.job_name}\""
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          yPos   = 8
          widget = {
            title = "Data Watermark Age"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"dataflow.googleapis.com/job/data_watermark_age\" resource.type=\"dataflow_job\" resource.label.\"job_name\"=\"${local.job_name}\""
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          yPos   = 8
          widget = {
            title = "Autoscaling"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"dataflow.googleapis.com/job/current_num_vcpus\" resource.type=\"dataflow_job\" resource.label.\"job_name\"=\"${local.job_name}\""
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                },
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"dataflow.googleapis.com/job/target_num_vcpus\" resource.type=\"dataflow_job\" resource.label.\"job_name\"=\"${local.job_name}\""
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                }
              ]
              yAxis = {
                label = "vCPUs"
                scale = "LINEAR"
              }
            }
          }
        }
      ]
    }
  })
}

# IAM binding for Dataflow service account
resource "google_project_iam_member" "dataflow_worker" {
  count = var.create_service_account_roles ? 1 : 0

  project = var.project_id
  role    = "roles/dataflow.worker"
  member  = "serviceAccount:${var.service_account_email}"
}

resource "google_project_iam_member" "dataflow_developer" {
  count = var.create_service_account_roles ? 1 : 0

  project = var.project_id
  role    = "roles/dataflow.developer"
  member  = "serviceAccount:${var.service_account_email}"
}

resource "google_project_iam_member" "storage_admin" {
  count = var.create_service_account_roles ? 1 : 0

  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${var.service_account_email}"
}

resource "google_project_iam_member" "bigquery_admin" {
  count = var.create_service_account_roles && var.grant_bigquery_access ? 1 : 0

  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${var.service_account_email}"
}

resource "google_project_iam_member" "pubsub_admin" {
  count = var.create_service_account_roles && var.grant_pubsub_access ? 1 : 0

  project = var.project_id
  role    = "roles/pubsub.admin"
  member  = "serviceAccount:${var.service_account_email}"
}

# Custom Service Account (optional)
resource "google_service_account" "dataflow_sa" {
  count = var.create_service_account ? 1 : 0

  project      = var.project_id
  account_id   = var.service_account_name != null ? var.service_account_name : "${local.job_name}-sa"
  display_name = "Dataflow Service Account for ${local.job_name}"
  description  = "Service account for Dataflow job ${local.job_name}"
}

resource "google_service_account_key" "dataflow_sa_key" {
  count = var.create_service_account && var.create_service_account_key ? 1 : 0

  service_account_id = google_service_account.dataflow_sa[0].name
  key_algorithm      = "KEY_ALG_RSA_2048"
  private_key_type   = "TYPE_GOOGLE_CREDENTIALS_FILE"
}

# VPC Firewall rules for Dataflow (optional)
resource "google_compute_firewall" "dataflow_ingress" {
  count = var.create_firewall_rules ? 1 : 0

  project = var.project_id
  name    = "${local.job_name}-dataflow-ingress"
  network = local.network

  allow {
    protocol = "tcp"
    ports    = ["12345", "12346"] # Dataflow shuffle service ports
  }

  source_tags = ["dataflow"]
  target_tags = ["dataflow"]

  direction = "INGRESS"
  priority  = 1000

  description = "Allow Dataflow workers to communicate"
}

resource "google_compute_firewall" "dataflow_egress" {
  count = var.create_firewall_rules ? 1 : 0

  project = var.project_id
  name    = "${local.job_name}-dataflow-egress"
  network = local.network

  allow {
    protocol = "tcp"
    ports    = ["443", "80"]
  }

  allow {
    protocol = "tcp"
    ports    = ["12345", "12346"]
  }

  target_tags = ["dataflow"]

  direction = "EGRESS"
  priority  = 1000

  description = "Allow Dataflow workers egress"
}