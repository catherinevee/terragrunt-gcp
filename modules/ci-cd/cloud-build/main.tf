# Cloud Build Module - Main Configuration
# Manages Cloud Build triggers, worker pools, and build configurations

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

# Local variables
locals {
  environment = var.environment != null ? var.environment : "dev"
  name_prefix = var.name_prefix != null ? var.name_prefix : "cloudbuild"

  default_labels = merge(
    {
      environment = local.environment
      managed_by  = "terraform"
      module      = "cloud-build"
      created_at  = formatdate("YYYY-MM-DD", timestamp())
    },
    var.labels
  )

  # Build trigger configurations
  build_triggers = {
    for k, v in var.build_triggers : k => merge(
      v,
      {
        name        = v.name != null ? v.name : "${local.name_prefix}-${k}-trigger"
        description = v.description != null ? v.description : "Cloud Build trigger for ${k}"
      }
    )
  }

  # Worker pool configurations
  worker_pools = {
    for k, v in var.worker_pools : k => merge(
      v,
      {
        name         = v.name != null ? v.name : "${local.name_prefix}-${k}-pool"
        display_name = v.display_name != null ? v.display_name : "Worker pool for ${k}"
      }
    )
  }

  # Build configurations
  build_configs = {
    for k, v in var.build_configs : k => merge(
      v,
      {
        name = v.name != null ? v.name : "${local.name_prefix}-${k}-build"
      }
    )
  }

  # Artifact registry configurations
  artifact_registries = {
    for k, v in var.artifact_registries : k => merge(
      v,
      {
        repository_id = v.repository_id != null ? v.repository_id : "${local.name_prefix}-${k}-registry"
        description   = v.description != null ? v.description : "Artifact registry for ${k}"
      }
    )
  }
}

# Enable required APIs
resource "google_project_service" "cloudbuild_api" {
  project = var.project_id
  service = "cloudbuild.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "source_repo_api" {
  project = var.project_id
  service = "sourcerepo.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "container_registry_api" {
  project = var.project_id
  service = "containerregistry.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "artifact_registry_api" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"

  disable_on_destroy = false
}

# Service Account for Cloud Build
resource "google_service_account" "cloud_build" {
  count = var.create_service_account ? 1 : 0

  account_id   = var.service_account_name != null ? var.service_account_name : "${local.name_prefix}-sa"
  display_name = "Cloud Build Service Account"
  description  = "Service account for Cloud Build operations"
  project      = var.project_id
}

# IAM roles for Cloud Build service account
resource "google_project_iam_member" "cloud_build_roles" {
  for_each = var.create_service_account && var.grant_service_account_roles ? toset(var.service_account_roles) : []

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_build[0].email}"

  depends_on = [google_service_account.cloud_build]
}

# Cloud Source Repository
resource "google_sourcerepo_repository" "repositories" {
  for_each = var.source_repositories

  name    = each.value.name != null ? each.value.name : "${local.name_prefix}-${each.key}-repo"
  project = var.project_id

  dynamic "pubsub_configs" {
    for_each = each.value.pubsub_configs != null ? each.value.pubsub_configs : []

    content {
      topic                 = pubsub_configs.value.topic
      message_format        = pubsub_configs.value.message_format
      service_account_email = pubsub_configs.value.service_account_email
    }
  }

  depends_on = [google_project_service.source_repo_api]
}

# Cloud Build Triggers
resource "google_cloudbuild_trigger" "build_triggers" {
  for_each = local.build_triggers

  project     = var.project_id
  name        = each.value.name
  description = each.value.description
  location    = each.value.location != null ? each.value.location : var.region

  # Trigger source configuration
  dynamic "github" {
    for_each = each.value.github != null ? [each.value.github] : []

    content {
      owner = github.value.owner
      name  = github.value.name

      dynamic "push" {
        for_each = github.value.push != null ? [github.value.push] : []

        content {
          branch       = push.value.branch
          tag          = push.value.tag
          invert_regex = push.value.invert_regex
        }
      }

      dynamic "pull_request" {
        for_each = github.value.pull_request != null ? [github.value.pull_request] : []

        content {
          branch          = pull_request.value.branch
          comment_control = pull_request.value.comment_control
          invert_regex    = pull_request.value.invert_regex
        }
      }
    }
  }

  dynamic "repository_event_config" {
    for_each = each.value.repository_event_config != null ? [each.value.repository_event_config] : []

    content {
      repository = repository_event_config.value.repository

      dynamic "push" {
        for_each = repository_event_config.value.push != null ? [repository_event_config.value.push] : []

        content {
          branch       = push.value.branch
          tag          = push.value.tag
          invert_regex = push.value.invert_regex
        }
      }

      dynamic "pull_request" {
        for_each = repository_event_config.value.pull_request != null ? [repository_event_config.value.pull_request] : []

        content {
          branch          = pull_request.value.branch
          comment_control = pull_request.value.comment_control
          invert_regex    = pull_request.value.invert_regex
        }
      }
    }
  }

  dynamic "webhook_config" {
    for_each = each.value.webhook_config != null ? [each.value.webhook_config] : []

    content {
      secret = webhook_config.value.secret
    }
  }

  dynamic "pubsub_config" {
    for_each = each.value.pubsub_config != null ? [each.value.pubsub_config] : []

    content {
      topic                 = pubsub_config.value.topic
      service_account_email = pubsub_config.value.service_account_email
    }
  }

  # Build configuration
  dynamic "build" {
    for_each = each.value.build != null ? [each.value.build] : []

    content {
      images      = build.value.images
      tags        = build.value.tags
      timeout     = build.value.timeout
      queue_ttl   = build.value.queue_ttl
      logs_bucket = build.value.logs_bucket

      dynamic "step" {
        for_each = build.value.steps != null ? build.value.steps : []

        content {
          name             = step.value.name
          args             = step.value.args
          env              = step.value.env
          id               = step.value.id
          entrypoint       = step.value.entrypoint
          dir              = step.value.dir
          secret_env       = step.value.secret_env
          timeout          = step.value.timeout
          timing           = step.value.timing
          wait_for         = step.value.wait_for
          script           = step.value.script
          allow_failure    = step.value.allow_failure
          allow_exit_codes = step.value.allow_exit_codes

          dynamic "volumes" {
            for_each = step.value.volumes != null ? step.value.volumes : []

            content {
              name = volumes.value.name
              path = volumes.value.path
            }
          }
        }
      }

      dynamic "source" {
        for_each = build.value.source != null ? [build.value.source] : []

        content {
          dynamic "storage_source" {
            for_each = source.value.storage_source != null ? [source.value.storage_source] : []

            content {
              bucket     = storage_source.value.bucket
              object     = storage_source.value.object
              generation = storage_source.value.generation
            }
          }

          dynamic "repo_source" {
            for_each = source.value.repo_source != null ? [source.value.repo_source] : []

            content {
              project_id    = repo_source.value.project_id
              repo_name     = repo_source.value.repo_name
              branch_name   = repo_source.value.branch_name
              commit_sha    = repo_source.value.commit_sha
              tag_name      = repo_source.value.tag_name
              dir           = repo_source.value.dir
              invert_regex  = repo_source.value.invert_regex
              substitutions = repo_source.value.substitutions
            }
          }
        }
      }

      dynamic "artifacts" {
        for_each = build.value.artifacts != null ? [build.value.artifacts] : []

        content {
          images = artifacts.value.images

          dynamic "objects" {
            for_each = artifacts.value.objects != null ? [artifacts.value.objects] : []

            content {
              location = objects.value.location
              paths    = objects.value.paths

              dynamic "timing" {
                for_each = objects.value.timing != null ? [objects.value.timing] : []

                content {
                  start_time = timing.value.start_time
                  end_time   = timing.value.end_time
                }
              }
            }
          }

          dynamic "maven_artifacts" {
            for_each = artifacts.value.maven_artifacts != null ? artifacts.value.maven_artifacts : []

            content {
              repository  = maven_artifacts.value.repository
              path        = maven_artifacts.value.path
              artifact_id = maven_artifacts.value.artifact_id
              group_id    = maven_artifacts.value.group_id
              version     = maven_artifacts.value.version
            }
          }

          dynamic "python_packages" {
            for_each = artifacts.value.python_packages != null ? artifacts.value.python_packages : []

            content {
              repository = python_packages.value.repository
              paths      = python_packages.value.paths
            }
          }

          dynamic "npm_packages" {
            for_each = artifacts.value.npm_packages != null ? artifacts.value.npm_packages : []

            content {
              repository   = npm_packages.value.repository
              package_path = npm_packages.value.package_path
            }
          }
        }
      }

      dynamic "options" {
        for_each = build.value.options != null ? [build.value.options] : []

        content {
          source_provenance_hash  = options.value.source_provenance_hash
          requested_verify_option = options.value.requested_verify_option
          machine_type            = options.value.machine_type
          disk_size_gb            = options.value.disk_size_gb
          substitution_option     = options.value.substitution_option
          dynamic_substitutions   = options.value.dynamic_substitutions
          log_streaming_option    = options.value.log_streaming_option
          worker_pool             = options.value.worker_pool
          logging                 = options.value.logging
          env                     = options.value.env
          secret_env              = options.value.secret_env

          dynamic "volumes" {
            for_each = options.value.volumes != null ? options.value.volumes : []

            content {
              name = volumes.value.name
              path = volumes.value.path
            }
          }
        }
      }

      dynamic "secret" {
        for_each = build.value.secrets != null ? build.value.secrets : []

        content {
          kms_key_name = secret.value.kms_key_name
          secret_env   = secret.value.secret_env
        }
      }

      dynamic "available_secrets" {
        for_each = build.value.available_secrets != null ? [build.value.available_secrets] : []

        content {
          dynamic "secret_manager" {
            for_each = available_secrets.value.secret_manager != null ? available_secrets.value.secret_manager : []

            content {
              version_name = secret_manager.value.version_name
              env          = secret_manager.value.env
            }
          }
        }
      }
    }
  }

  # Build configuration from file
  filename = each.value.filename

  # Build configuration from inline
  dynamic "git_file_source" {
    for_each = each.value.git_file_source != null ? [each.value.git_file_source] : []

    content {
      path                     = git_file_source.value.path
      uri                      = git_file_source.value.uri
      repo_type                = git_file_source.value.repo_type
      revision                 = git_file_source.value.revision
      github_enterprise_config = git_file_source.value.github_enterprise_config
      bitbucket_server_config  = git_file_source.value.bitbucket_server_config
    }
  }

  # Trigger template
  dynamic "trigger_template" {
    for_each = each.value.trigger_template != null ? [each.value.trigger_template] : []

    content {
      project_id   = trigger_template.value.project_id
      repo_name    = trigger_template.value.repo_name
      branch_name  = trigger_template.value.branch_name
      commit_sha   = trigger_template.value.commit_sha
      tag_name     = trigger_template.value.tag_name
      dir          = trigger_template.value.dir
      invert_regex = trigger_template.value.invert_regex
    }
  }

  # Source to build
  dynamic "source_to_build" {
    for_each = each.value.source_to_build != null ? [each.value.source_to_build] : []

    content {
      uri                      = source_to_build.value.uri
      ref                      = source_to_build.value.ref
      repo_type                = source_to_build.value.repo_type
      github_enterprise_config = source_to_build.value.github_enterprise_config
      bitbucket_server_config  = source_to_build.value.bitbucket_server_config
    }
  }

  # Approval configuration
  dynamic "approval_config" {
    for_each = each.value.approval_config != null ? [each.value.approval_config] : []

    content {
      approval_required = approval_config.value.approval_required
    }
  }

  service_account = each.value.service_account != null ? each.value.service_account : (
    var.create_service_account ? google_service_account.cloud_build[0].email : null
  )

  include_build_logs = each.value.include_build_logs != null ? each.value.include_build_logs : "INCLUDE_BUILD_LOGS_WITH_STATUS"

  substitutions  = each.value.substitutions
  ignored_files  = each.value.ignored_files
  included_files = each.value.included_files
  filter         = each.value.filter

  tags = concat(
    each.value.tags != null ? each.value.tags : [],
    [local.environment, "managed-by-terraform"]
  )

  disabled = each.value.disabled != null ? each.value.disabled : false

  depends_on = [
    google_project_service.cloudbuild_api,
    google_service_account.cloud_build
  ]
}

# Cloud Build Worker Pools
resource "google_cloudbuild_worker_pool" "worker_pools" {
  for_each = local.worker_pools
  provider = google-beta

  name         = each.value.name
  display_name = each.value.display_name
  location     = each.value.location != null ? each.value.location : var.region
  project      = var.project_id

  annotations = each.value.annotations != null ? each.value.annotations : local.default_labels

  dynamic "worker_config" {
    for_each = each.value.worker_config != null ? [each.value.worker_config] : []

    content {
      disk_size_gb   = worker_config.value.disk_size_gb
      machine_type   = worker_config.value.machine_type
      no_external_ip = worker_config.value.no_external_ip
    }
  }

  dynamic "network_config" {
    for_each = each.value.network_config != null ? [each.value.network_config] : []

    content {
      peered_network          = network_config.value.peered_network
      peered_network_ip_range = network_config.value.peered_network_ip_range
      egress_option           = network_config.value.egress_option
    }
  }

  depends_on = [google_project_service.cloudbuild_api]
}

# Artifact Registry Repositories
resource "google_artifact_registry_repository" "registries" {
  for_each = local.artifact_registries

  repository_id = each.value.repository_id
  description   = each.value.description
  format        = each.value.format != null ? each.value.format : "DOCKER"
  location      = each.value.location != null ? each.value.location : var.region
  project       = var.project_id

  mode = each.value.mode != null ? each.value.mode : "STANDARD_REPOSITORY"

  labels = merge(
    local.default_labels,
    each.value.labels != null ? each.value.labels : {}
  )

  kms_key_name = each.value.kms_key_name

  dynamic "docker_config" {
    for_each = each.value.docker_config != null && each.value.format == "DOCKER" ? [each.value.docker_config] : []

    content {
      immutable_tags = docker_config.value.immutable_tags
    }
  }

  dynamic "maven_config" {
    for_each = each.value.maven_config != null && each.value.format == "MAVEN" ? [each.value.maven_config] : []

    content {
      allow_snapshot_overwrites = maven_config.value.allow_snapshot_overwrites
      version_policy            = maven_config.value.version_policy
    }
  }

  dynamic "virtual_repository_config" {
    for_each = each.value.virtual_repository_config != null && each.value.mode == "VIRTUAL_REPOSITORY" ? [each.value.virtual_repository_config] : []

    content {
      dynamic "upstream_policies" {
        for_each = virtual_repository_config.value.upstream_policies != null ? virtual_repository_config.value.upstream_policies : []

        content {
          id         = upstream_policies.value.id
          repository = upstream_policies.value.repository
          priority   = upstream_policies.value.priority
        }
      }
    }
  }

  dynamic "remote_repository_config" {
    for_each = each.value.remote_repository_config != null && each.value.mode == "REMOTE_REPOSITORY" ? [each.value.remote_repository_config] : []

    content {
      description = remote_repository_config.value.description

      dynamic "docker_repository" {
        for_each = remote_repository_config.value.docker_repository != null ? [remote_repository_config.value.docker_repository] : []

        content {
          public_repository = docker_repository.value.public_repository
        }
      }

      dynamic "maven_repository" {
        for_each = remote_repository_config.value.maven_repository != null ? [remote_repository_config.value.maven_repository] : []

        content {
          public_repository = maven_repository.value.public_repository
        }
      }

      dynamic "npm_repository" {
        for_each = remote_repository_config.value.npm_repository != null ? [remote_repository_config.value.npm_repository] : []

        content {
          public_repository = npm_repository.value.public_repository
        }
      }

      dynamic "python_repository" {
        for_each = remote_repository_config.value.python_repository != null ? [remote_repository_config.value.python_repository] : []

        content {
          public_repository = python_repository.value.public_repository
        }
      }

      dynamic "apt_repository" {
        for_each = remote_repository_config.value.apt_repository != null ? [remote_repository_config.value.apt_repository] : []

        content {
          dynamic "public_repository" {
            for_each = apt_repository.value.public_repository != null ? [apt_repository.value.public_repository] : []

            content {
              repository_base = public_repository.value.repository_base
              repository_path = public_repository.value.repository_path
            }
          }
        }
      }

      dynamic "yum_repository" {
        for_each = remote_repository_config.value.yum_repository != null ? [remote_repository_config.value.yum_repository] : []

        content {
          dynamic "public_repository" {
            for_each = yum_repository.value.public_repository != null ? [yum_repository.value.public_repository] : []

            content {
              repository_base = public_repository.value.repository_base
              repository_path = public_repository.value.repository_path
            }
          }
        }
      }
    }
  }

  cleanup_policy_dry_run = each.value.cleanup_policy_dry_run

  dynamic "cleanup_policies" {
    for_each = each.value.cleanup_policies != null ? each.value.cleanup_policies : []

    content {
      id = cleanup_policies.value.id

      dynamic "condition" {
        for_each = cleanup_policies.value.condition != null ? [cleanup_policies.value.condition] : []

        content {
          tag_state             = condition.value.tag_state
          tag_prefixes          = condition.value.tag_prefixes
          version_name_prefixes = condition.value.version_name_prefixes
          package_name_prefixes = condition.value.package_name_prefixes
          older_than            = condition.value.older_than
          newer_than            = condition.value.newer_than
        }
      }

      dynamic "most_recent_versions" {
        for_each = cleanup_policies.value.most_recent_versions != null ? [cleanup_policies.value.most_recent_versions] : []

        content {
          package_name_prefixes = most_recent_versions.value.package_name_prefixes
          keep_count            = most_recent_versions.value.keep_count
        }
      }

      action = cleanup_policies.value.action
    }
  }

  depends_on = [google_project_service.artifact_registry_api]
}

# IAM bindings for Artifact Registry
resource "google_artifact_registry_repository_iam_member" "registry_iam" {
  for_each = {
    for item in flatten([
      for registry_key, registry in local.artifact_registries : [
        for role_key, role in registry.iam_bindings != null ? registry.iam_bindings : {} : {
          key        = "${registry_key}-${role_key}"
          registry   = registry_key
          role       = role.role
          member     = role.member
          repository = google_artifact_registry_repository.registries[registry_key].name
          location   = google_artifact_registry_repository.registries[registry_key].location
        }
      ]
    ]) : item.key => item
  }

  project    = var.project_id
  location   = each.value.location
  repository = each.value.repository
  role       = each.value.role
  member     = each.value.member

  depends_on = [google_artifact_registry_repository.registries]
}

# Cloud Build custom build configurations (stored in GCS)
resource "google_storage_bucket_object" "build_configs" {
  for_each = {
    for k, v in local.build_configs : k => v
    if v.store_in_gcs != null && v.store_in_gcs
  }

  bucket  = each.value.gcs_bucket
  name    = each.value.gcs_object != null ? each.value.gcs_object : "cloud-build/${each.key}/cloudbuild.yaml"
  content = each.value.build_yaml_content
}

# Monitoring Alert Policies
resource "google_monitoring_alert_policy" "build_alerts" {
  for_each = var.create_monitoring_alerts ? var.monitoring_alerts : {}

  project      = var.project_id
  display_name = each.value.display_name
  combiner     = each.value.combiner != null ? each.value.combiner : "OR"
  enabled      = each.value.enabled != null ? each.value.enabled : true

  conditions {
    display_name = each.value.condition_display_name

    condition_threshold {
      filter          = each.value.filter
      duration        = each.value.duration != null ? each.value.duration : "60s"
      comparison      = each.value.comparison != null ? each.value.comparison : "COMPARISON_GT"
      threshold_value = each.value.threshold_value

      aggregations {
        alignment_period     = each.value.alignment_period != null ? each.value.alignment_period : "60s"
        per_series_aligner   = each.value.per_series_aligner != null ? each.value.per_series_aligner : "ALIGN_RATE"
        cross_series_reducer = each.value.cross_series_reducer
        group_by_fields      = each.value.group_by_fields
      }

      dynamic "trigger" {
        for_each = each.value.trigger_count != null || each.value.trigger_percent != null ? [1] : []

        content {
          count   = each.value.trigger_count
          percent = each.value.trigger_percent
        }
      }
    }
  }

  notification_channels = each.value.notification_channels

  alert_strategy {
    auto_close = each.value.auto_close != null ? each.value.auto_close : "1800s"

    dynamic "notification_rate_limit" {
      for_each = each.value.rate_limit != null ? [each.value.rate_limit] : []

      content {
        period = notification_rate_limit.value.period
      }
    }
  }

  documentation {
    content   = each.value.documentation_content
    mime_type = each.value.documentation_mime_type != null ? each.value.documentation_mime_type : "text/markdown"
    subject   = each.value.documentation_subject
  }

  user_labels = merge(
    local.default_labels,
    each.value.labels != null ? each.value.labels : {}
  )
}

# Monitoring Dashboard
resource "google_monitoring_dashboard" "build_dashboard" {
  count = var.create_monitoring_dashboard ? 1 : 0

  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "${local.name_prefix}-cloud-build-dashboard"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Build Success Rate"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_build\" metric.type=\"cloudbuild.googleapis.com/build_count\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.label.status"]
                    }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          xPos   = 6
          width  = 6
          height = 4
          widget = {
            title = "Build Duration"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_build\" metric.type=\"cloudbuild.googleapis.com/build_duration\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_MEAN"
                      groupByFields      = ["resource.label.trigger_id"]
                    }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Build Queue Time"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_build\" metric.type=\"cloudbuild.googleapis.com/queue_time\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_MEAN"
                    }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Build Errors"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_build\" metric.type=\"cloudbuild.googleapis.com/build_count\" metric.label.status=\"FAILURE\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.label.trigger_id"]
                    }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          yPos   = 8
          width  = 12
          height = 4
          widget = {
            title = "Worker Pool Utilization"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_build_worker_pool\" metric.type=\"cloudbuild.googleapis.com/worker_pool/used_worker_count\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_MEAN"
                      groupByFields      = ["resource.label.worker_pool_id"]
                    }
                  }
                }
                plotType = "STACKED_AREA"
              }]
            }
          }
        }
      ]
    }
  })
}

# Budget alerts for Cloud Build
resource "google_billing_budget" "build_budget" {
  count = var.create_budget_alert ? 1 : 0

  billing_account = var.billing_account
  display_name    = "${local.name_prefix}-cloud-build-budget"

  budget_filter {
    projects = ["projects/${var.project_id}"]
    services = ["services/9AFD-7D2C-66F0"] # Cloud Build service ID

    labels = {
      environment = local.environment
    }
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency != null ? var.budget_currency : "USD"
      units         = var.budget_amount != null ? var.budget_amount : "1000"
    }
  }

  threshold_rules {
    threshold_percent = 0.5
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.75
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.2
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    pubsub_topic = var.budget_pubsub_topic
  }
}