# Cloud Source Repositories Module - Main Configuration

# Enable required APIs
resource "google_project_service" "source_repos_apis" {
  for_each = var.enable_apis ? toset([
    "sourcerepo.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com"
  ]) : toset([])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# Cloud Source Repositories
resource "google_sourcerepo_repository" "repositories" {
  for_each = var.repositories

  name    = each.key
  project = var.project_id

  depends_on = [
    google_project_service.source_repos_apis
  ]
}

# Repository IAM bindings
resource "google_sourcerepo_repository_iam_binding" "repository_bindings" {
  for_each = var.repository_iam_bindings

  project    = var.project_id
  repository = google_sourcerepo_repository.repositories[each.value.repository_name].name
  role       = each.value.role
  members    = each.value.members

  depends_on = [
    google_sourcerepo_repository.repositories
  ]
}

# Pub/Sub topics for repository events
resource "google_pubsub_topic" "repo_event_topics" {
  for_each = var.enable_pubsub_notifications ? var.pubsub_topics : {}

  name    = each.key
  project = var.project_id

  dynamic "message_storage_policy" {
    for_each = each.value.message_storage_policy != null ? [each.value.message_storage_policy] : []
    content {
      allowed_persistence_regions = message_storage_policy.value.allowed_persistence_regions
    }
  }

  message_retention_duration = each.value.message_retention_duration
  kms_key_name               = each.value.kms_key_name

  labels = merge(var.labels, each.value.labels)

  depends_on = [
    google_project_service.source_repos_apis
  ]
}

# Pub/Sub subscriptions for repository events
resource "google_pubsub_subscription" "repo_event_subscriptions" {
  for_each = var.enable_pubsub_notifications ? var.pubsub_subscriptions : {}

  name    = each.key
  topic   = google_pubsub_topic.repo_event_topics[each.value.topic_name].name
  project = var.project_id

  ack_deadline_seconds       = each.value.ack_deadline_seconds
  message_retention_duration = each.value.message_retention_duration
  retain_acked_messages      = each.value.retain_acked_messages
  enable_message_ordering    = each.value.enable_message_ordering

  dynamic "expiration_policy" {
    for_each = each.value.expiration_policy != null ? [each.value.expiration_policy] : []
    content {
      ttl = expiration_policy.value.ttl
    }
  }

  filter = each.value.filter

  dynamic "push_config" {
    for_each = each.value.push_config != null ? [each.value.push_config] : []
    content {
      push_endpoint = push_config.value.push_endpoint
      attributes    = push_config.value.attributes

      dynamic "oidc_token" {
        for_each = push_config.value.oidc_token != null ? [push_config.value.oidc_token] : []
        content {
          service_account_email = oidc_token.value.service_account_email
          audience              = oidc_token.value.audience
        }
      }
    }
  }

  dynamic "retry_policy" {
    for_each = each.value.retry_policy != null ? [each.value.retry_policy] : []
    content {
      minimum_backoff = retry_policy.value.minimum_backoff
      maximum_backoff = retry_policy.value.maximum_backoff
    }
  }

  dynamic "dead_letter_policy" {
    for_each = each.value.dead_letter_policy != null ? [each.value.dead_letter_policy] : []
    content {
      dead_letter_topic     = dead_letter_policy.value.dead_letter_topic
      max_delivery_attempts = dead_letter_policy.value.max_delivery_attempts
    }
  }

  labels = merge(var.labels, each.value.labels)

  depends_on = [
    google_pubsub_topic.repo_event_topics
  ]
}

# Cloud Build triggers for Source Repositories
resource "google_cloudbuild_trigger" "repo_triggers" {
  for_each = var.enable_cloud_build_integration ? var.cloud_build_triggers : {}

  name        = each.key
  project     = var.project_id
  description = each.value.description

  trigger_template {
    project_id   = var.project_id
    repo_name    = google_sourcerepo_repository.repositories[each.value.repository_name].name
    branch_name  = each.value.branch_name
    tag_name     = each.value.tag_name
    commit_sha   = each.value.commit_sha
    dir          = each.value.dir
    invert_regex = each.value.invert_regex
  }

  dynamic "build" {
    for_each = each.value.build_config != null ? [each.value.build_config] : []
    content {
      dynamic "step" {
        for_each = build.value.steps
        content {
          name       = step.value.name
          args       = step.value.args
          env        = step.value.env
          id         = step.value.id
          entrypoint = step.value.entrypoint
          dir        = step.value.dir
          secret_env = step.value.secret_env
          timeout    = step.value.timeout
          timing     = step.value.timing
          wait_for   = step.value.wait_for

          dynamic "volumes" {
            for_each = step.value.volumes != null ? step.value.volumes : []
            content {
              name = volumes.value.name
              path = volumes.value.path
            }
          }
        }
      }

      timeout                = build.value.timeout
      images                 = build.value.images
      substitutions          = build.value.substitutions
      tags                   = build.value.tags
      logs_bucket            = build.value.logs_bucket
      machine_type           = build.value.machine_type
      disk_size_gb           = build.value.disk_size_gb
      source_provenance_hash = build.value.source_provenance_hash

      dynamic "artifacts" {
        for_each = build.value.artifacts != null ? [build.value.artifacts] : []
        content {
          images = artifacts.value.images

          dynamic "objects" {
            for_each = artifacts.value.objects != null ? [artifacts.value.objects] : []
            content {
              location = objects.value.location
              paths    = objects.value.paths
            }
          }
        }
      }

      dynamic "options" {
        for_each = build.value.options != null ? [build.value.options] : []
        content {
          disk_size_gb            = options.value.disk_size_gb
          machine_type            = options.value.machine_type
          requested_verify_option = options.value.requested_verify_option
          source_provenance_hash  = options.value.source_provenance_hash
          substitution_option     = options.value.substitution_option
          dynamic_substitutions   = options.value.dynamic_substitutions
          log_streaming_option    = options.value.log_streaming_option
          worker_pool             = options.value.worker_pool
          logging                 = options.value.logging

          env        = options.value.env
          secret_env = options.value.secret_env

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
              env          = secret_manager.value.env
              version_name = secret_manager.value.version_name
            }
          }
        }
      }
    }
  }

  filename       = each.value.filename
  ignored_files  = each.value.ignored_files
  included_files = each.value.included_files
  disabled       = each.value.disabled

  dynamic "substitutions" {
    for_each = each.value.substitutions != null ? [each.value.substitutions] : []
    content {
      # Dynamic content based on substitutions map
    }
  }

  service_account = each.value.service_account

  tags = each.value.tags

  depends_on = [
    google_sourcerepo_repository.repositories,
    google_project_service.source_repos_apis
  ]
}

# Cloud Storage bucket for build artifacts and logs
resource "google_storage_bucket" "build_artifacts_bucket" {
  count = var.enable_build_artifacts_storage ? 1 : 0

  name     = var.build_artifacts_bucket_name
  location = var.storage_bucket_location
  project  = var.project_id

  force_destroy = var.force_destroy_bucket

  uniform_bucket_level_access = var.uniform_bucket_level_access

  dynamic "versioning" {
    for_each = var.bucket_versioning_enabled ? [1] : []
    content {
      enabled = true
    }
  }

  dynamic "lifecycle_rule" {
    for_each = var.bucket_lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action.type
        storage_class = lifecycle_rule.value.action.storage_class
      }

      condition {
        age                        = lifecycle_rule.value.condition.age
        created_before             = lifecycle_rule.value.condition.created_before
        with_state                 = lifecycle_rule.value.condition.with_state
        matches_storage_class      = lifecycle_rule.value.condition.matches_storage_class
        num_newer_versions         = lifecycle_rule.value.condition.num_newer_versions
        custom_time_before         = lifecycle_rule.value.condition.custom_time_before
        days_since_custom_time     = lifecycle_rule.value.condition.days_since_custom_time
        days_since_noncurrent_time = lifecycle_rule.value.condition.days_since_noncurrent_time
        noncurrent_time_before     = lifecycle_rule.value.condition.noncurrent_time_before
      }
    }
  }

  dynamic "retention_policy" {
    for_each = var.bucket_retention_policy != null ? [var.bucket_retention_policy] : []
    content {
      is_locked        = retention_policy.value.is_locked
      retention_period = retention_policy.value.retention_period
    }
  }

  dynamic "encryption" {
    for_each = var.bucket_encryption_key != null ? [1] : []
    content {
      default_kms_key_name = var.bucket_encryption_key
    }
  }

  dynamic "logging" {
    for_each = var.bucket_logging_config != null ? [var.bucket_logging_config] : []
    content {
      log_bucket        = logging.value.log_bucket
      log_object_prefix = logging.value.log_object_prefix
    }
  }

  labels = merge(var.labels, var.storage_bucket_labels)

  depends_on = [
    google_project_service.source_repos_apis
  ]
}

# Service account for Source Repositories operations
resource "google_service_account" "source_repos_sa" {
  count = var.create_service_account ? 1 : 0

  account_id   = var.service_account_id
  display_name = "Cloud Source Repositories Service Account"
  description  = "Service account for Cloud Source Repositories operations and Cloud Build"
  project      = var.project_id
}

# IAM roles for the service account
resource "google_project_iam_member" "source_repos_sa_roles" {
  for_each = var.create_service_account ? toset(var.service_account_roles) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.source_repos_sa[0].email}"

  depends_on = [
    google_service_account.source_repos_sa
  ]
}

# Secret Manager secrets for repository credentials
resource "google_secret_manager_secret" "repo_secrets" {
  for_each = var.enable_secret_management ? var.repository_secrets : {}

  secret_id = each.key
  project   = var.project_id

  labels = merge(var.labels, each.value.labels)

  dynamic "replication" {
    for_each = each.value.replication_policy != null ? [each.value.replication_policy] : []
    content {
      dynamic "automatic" {
        for_each = replication.value.automatic != null ? [1] : []
        content {
          dynamic "customer_managed_encryption" {
            for_each = replication.value.automatic.customer_managed_encryption != null ? [replication.value.automatic.customer_managed_encryption] : []
            content {
              kms_key_name = customer_managed_encryption.value.kms_key_name
            }
          }
        }
      }

      dynamic "user_managed" {
        for_each = replication.value.user_managed != null ? [replication.value.user_managed] : []
        content {
          dynamic "replicas" {
            for_each = user_managed.value.replicas
            content {
              location = replicas.value.location

              dynamic "customer_managed_encryption" {
                for_each = replicas.value.customer_managed_encryption != null ? [replicas.value.customer_managed_encryption] : []
                content {
                  kms_key_name = customer_managed_encryption.value.kms_key_name
                }
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    google_project_service.source_repos_apis
  ]
}

# Secret Manager secret versions
resource "google_secret_manager_secret_version" "repo_secret_versions" {
  for_each = var.enable_secret_management ? var.repository_secret_versions : {}

  secret      = google_secret_manager_secret.repo_secrets[each.value.secret_name].id
  secret_data = each.value.secret_data

  depends_on = [
    google_secret_manager_secret.repo_secrets
  ]
}

# Cloud Functions for repository webhooks
resource "google_cloudfunctions_function" "repo_webhooks" {
  for_each = var.enable_webhook_functions ? var.webhook_functions : {}

  name        = each.key
  project     = var.project_id
  region      = each.value.region
  description = each.value.description

  runtime               = each.value.runtime
  available_memory_mb   = each.value.memory_mb
  timeout               = each.value.timeout
  entry_point           = each.value.entry_point
  service_account_email = var.create_service_account ? google_service_account.source_repos_sa[0].email : each.value.service_account_email

  source_archive_bucket = each.value.source_bucket
  source_archive_object = each.value.source_object

  dynamic "event_trigger" {
    for_each = each.value.event_trigger != null ? [each.value.event_trigger] : []
    content {
      event_type = event_trigger.value.event_type
      resource   = event_trigger.value.resource

      dynamic "failure_policy" {
        for_each = event_trigger.value.failure_policy_retry ? [1] : []
        content {
          retry = true
        }
      }
    }
  }

  dynamic "https_trigger" {
    for_each = each.value.https_trigger_enabled ? [1] : []
    content {
      security_level = each.value.https_security_level
    }
  }

  environment_variables = each.value.environment_variables

  labels = merge(var.labels, each.value.labels)

  depends_on = [
    google_project_service.source_repos_apis,
    google_service_account.source_repos_sa
  ]
}

# Monitoring dashboard for Source Repositories
resource "google_monitoring_dashboard" "source_repos_dashboard" {
  count = var.enable_monitoring && var.create_dashboard ? 1 : 0

  dashboard_json = jsonencode({
    displayName = var.dashboard_display_name
    mosaicLayout = {
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Repository Operations"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"source_repository\" AND metric.type=\"sourcerepo.googleapis.com/api/request_count\""
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Requests/sec"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Cloud Build Executions"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"build\" AND metric.type=\"cloudbuild.googleapis.com/build/count\""
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Builds"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Build Duration"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"build\" AND metric.type=\"cloudbuild.googleapis.com/build/duration\""
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Duration (seconds)"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Storage Operations"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"gcs_bucket\" AND metric.type=\"storage.googleapis.com/api/request_count\""
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Requests/sec"
                scale = "LINEAR"
              }
            }
          }
        }
      ]
    }
  })

  project = var.project_id

  depends_on = [
    google_project_service.source_repos_apis
  ]
}

# Alert policies for Source Repositories monitoring
resource "google_monitoring_alert_policy" "source_repos_alerts" {
  for_each = var.enable_monitoring ? var.alert_policies : {}

  display_name = each.value.display_name
  combiner     = each.value.combiner
  enabled      = each.value.enabled

  documentation {
    content   = each.value.documentation
    mime_type = "text/markdown"
  }

  conditions {
    display_name = each.value.condition_display_name

    condition_threshold {
      filter          = each.value.filter
      duration        = each.value.duration
      comparison      = each.value.comparison
      threshold_value = each.value.threshold_value

      aggregations {
        alignment_period     = each.value.alignment_period
        per_series_aligner   = each.value.per_series_aligner
        cross_series_reducer = each.value.cross_series_reducer
        group_by_fields      = each.value.group_by_fields
      }

      dynamic "trigger" {
        for_each = each.value.trigger_count != null ? [1] : []
        content {
          count = each.value.trigger_count
        }
      }

      dynamic "trigger" {
        for_each = each.value.trigger_percent != null ? [1] : []
        content {
          percent = each.value.trigger_percent
        }
      }
    }
  }

  notification_channels = concat(
    var.notification_channels,
    each.value.notification_channels
  )

  alert_strategy {
    auto_close = each.value.auto_close_duration

    dynamic "notification_rate_limit" {
      for_each = each.value.rate_limit != null ? [1] : []
      content {
        period = each.value.rate_limit
      }
    }
  }

  project = var.project_id

  depends_on = [
    google_project_service.source_repos_apis
  ]
}

# IAM bindings for storage bucket
resource "google_storage_bucket_iam_binding" "build_bucket_bindings" {
  for_each = var.enable_build_artifacts_storage ? var.storage_bucket_iam_bindings : {}

  bucket  = google_storage_bucket.build_artifacts_bucket[0].name
  role    = each.value.role
  members = each.value.members

  depends_on = [
    google_storage_bucket.build_artifacts_bucket
  ]
}

# IAM bindings for Pub/Sub topics
resource "google_pubsub_topic_iam_binding" "topic_bindings" {
  for_each = var.enable_pubsub_notifications ? var.pubsub_topic_iam_bindings : {}

  topic   = google_pubsub_topic.repo_event_topics[each.value.topic_name].name
  role    = each.value.role
  members = each.value.members
  project = var.project_id

  depends_on = [
    google_pubsub_topic.repo_event_topics
  ]
}

# Log sink for Source Repositories audit logs
resource "google_logging_project_sink" "source_repos_audit_sink" {
  count = var.enable_audit_logging ? 1 : 0

  name        = var.audit_log_sink_name
  destination = var.audit_log_destination

  filter = join(" OR ", [
    "protoPayload.serviceName=\"sourcerepo.googleapis.com\"",
    "protoPayload.serviceName=\"cloudbuild.googleapis.com\"",
    "protoPayload.methodName:\"CreateRepo\"",
    "protoPayload.methodName:\"DeleteRepo\"",
    "protoPayload.methodName:\"UpdateRepo\"",
    "protoPayload.methodName:\"CreateBuild\"",
    "protoPayload.methodName:\"CancelBuild\""
  ])

  unique_writer_identity = true
  project                = var.project_id

  depends_on = [
    google_project_service.source_repos_apis
  ]
}

# Local values for data processing
locals {
  # Repository to trigger mapping
  repo_trigger_map = {
    for trigger_name, trigger_config in var.cloud_build_triggers : trigger_name => trigger_config.repository_name
  }

  # Topic to subscription mapping
  topic_subscription_map = {
    for sub_name, sub_config in var.pubsub_subscriptions : sub_name => sub_config.topic_name
  }

  # Default build steps for common use cases
  default_build_steps = {
    docker_build = [
      {
        name = "gcr.io/cloud-builders/docker"
        args = ["build", "-t", "gcr.io/$PROJECT_ID/${var.project_id}:$COMMIT_SHA", "."]
      },
      {
        name = "gcr.io/cloud-builders/docker"
        args = ["push", "gcr.io/$PROJECT_ID/${var.project_id}:$COMMIT_SHA"]
      }
    ]
    npm_build = [
      {
        name       = "node:16"
        entrypoint = "npm"
        args       = ["install"]
      },
      {
        name       = "node:16"
        entrypoint = "npm"
        args       = ["run", "build"]
      },
      {
        name       = "node:16"
        entrypoint = "npm"
        args       = ["test"]
      }
    ]
    go_build = [
      {
        name = "gcr.io/cloud-builders/go"
        args = ["mod", "download"]
        env  = ["GO111MODULE=on"]
      },
      {
        name = "gcr.io/cloud-builders/go"
        args = ["build", "-v", "."]
        env  = ["GO111MODULE=on"]
      },
      {
        name = "gcr.io/cloud-builders/go"
        args = ["test", "-v", "./..."]
        env  = ["GO111MODULE=on"]
      }
    ]
  }
}