# Cloud Build Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region for Cloud Build resources"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
  default     = "cloudbuild"
}

# Build Triggers Configuration
variable "build_triggers" {
  description = "Map of Cloud Build trigger configurations"
  type = map(object({
    name        = optional(string)
    description = optional(string)
    location    = optional(string)
    disabled    = optional(bool)

    # GitHub configuration
    github = optional(object({
      owner = string
      name  = string

      push = optional(object({
        branch       = optional(string)
        tag          = optional(string)
        invert_regex = optional(bool)
      }))

      pull_request = optional(object({
        branch          = optional(string)
        comment_control = optional(string) # "COMMENTS_DISABLED", "COMMENTS_ENABLED", "COMMENTS_ENABLED_FOR_EXTERNAL_CONTRIBUTORS_ONLY"
        invert_regex    = optional(bool)
      }))
    }))

    # Repository event configuration (for Cloud Source Repositories)
    repository_event_config = optional(object({
      repository = string

      push = optional(object({
        branch       = optional(string)
        tag          = optional(string)
        invert_regex = optional(bool)
      }))

      pull_request = optional(object({
        branch          = optional(string)
        comment_control = optional(string)
        invert_regex    = optional(bool)
      }))
    }))

    # Webhook configuration
    webhook_config = optional(object({
      secret = string
    }))

    # Pub/Sub configuration
    pubsub_config = optional(object({
      topic                 = string
      service_account_email = optional(string)
    }))

    # Build configuration
    build = optional(object({
      images      = optional(list(string))
      tags        = optional(list(string))
      timeout     = optional(string)
      queue_ttl   = optional(string)
      logs_bucket = optional(string)

      steps = optional(list(object({
        name             = string
        args             = optional(list(string))
        env              = optional(list(string))
        id               = optional(string)
        entrypoint       = optional(string)
        dir              = optional(string)
        secret_env       = optional(list(string))
        timeout          = optional(string)
        timing           = optional(string)
        wait_for         = optional(list(string))
        script           = optional(string)
        allow_failure    = optional(bool)
        allow_exit_codes = optional(list(number))

        volumes = optional(list(object({
          name = string
          path = string
        })))
      })))

      source = optional(object({
        storage_source = optional(object({
          bucket     = string
          object     = string
          generation = optional(string)
        }))

        repo_source = optional(object({
          project_id    = optional(string)
          repo_name     = string
          branch_name   = optional(string)
          commit_sha    = optional(string)
          tag_name      = optional(string)
          dir           = optional(string)
          invert_regex  = optional(bool)
          substitutions = optional(map(string))
        }))
      }))

      artifacts = optional(object({
        images = optional(list(string))

        objects = optional(object({
          location = string
          paths    = list(string)

          timing = optional(object({
            start_time = string
            end_time   = string
          }))
        }))

        maven_artifacts = optional(list(object({
          repository  = string
          path        = string
          artifact_id = string
          group_id    = string
          version     = string
        })))

        python_packages = optional(list(object({
          repository = string
          paths      = list(string)
        })))

        npm_packages = optional(list(object({
          repository   = string
          package_path = string
        })))
      }))

      options = optional(object({
        source_provenance_hash  = optional(list(string))
        requested_verify_option = optional(string)
        machine_type            = optional(string)
        disk_size_gb            = optional(number)
        substitution_option     = optional(string)
        dynamic_substitutions   = optional(bool)
        log_streaming_option    = optional(string)
        worker_pool             = optional(string)
        logging                 = optional(string)
        env                     = optional(list(string))
        secret_env              = optional(list(string))

        volumes = optional(list(object({
          name = string
          path = string
        })))
      }))

      secrets = optional(list(object({
        kms_key_name = string
        secret_env   = map(string)
      })))

      available_secrets = optional(object({
        secret_manager = optional(list(object({
          version_name = string
          env          = string
        })))
      }))
    }))

    # Build configuration from file
    filename = optional(string)

    # Git file source configuration
    git_file_source = optional(object({
      path                     = string
      uri                      = optional(string)
      repo_type                = string # "UNKNOWN", "CLOUD_SOURCE_REPOSITORIES", "GITHUB", "BITBUCKET_SERVER"
      revision                 = optional(string)
      github_enterprise_config = optional(string)
      bitbucket_server_config  = optional(string)
    }))

    # Trigger template
    trigger_template = optional(object({
      project_id   = optional(string)
      repo_name    = string
      branch_name  = optional(string)
      commit_sha   = optional(string)
      tag_name     = optional(string)
      dir          = optional(string)
      invert_regex = optional(bool)
    }))

    # Source to build
    source_to_build = optional(object({
      uri                      = string
      ref                      = string
      repo_type                = string
      github_enterprise_config = optional(string)
      bitbucket_server_config  = optional(string)
    }))

    # Approval configuration
    approval_config = optional(object({
      approval_required = optional(bool)
    }))

    service_account    = optional(string)
    include_build_logs = optional(string) # "INCLUDE_BUILD_LOGS_UNSPECIFIED", "INCLUDE_BUILD_LOGS_WITH_STATUS"
    substitutions      = optional(map(string))
    ignored_files      = optional(list(string))
    included_files     = optional(list(string))
    filter             = optional(string)
    tags               = optional(list(string))
  }))
  default = {}
}

# Worker Pools Configuration
variable "worker_pools" {
  description = "Map of Cloud Build worker pool configurations"
  type = map(object({
    name         = optional(string)
    display_name = optional(string)
    location     = optional(string)
    annotations  = optional(map(string))

    worker_config = optional(object({
      disk_size_gb   = optional(number)
      machine_type   = optional(string)
      no_external_ip = optional(bool)
    }))

    network_config = optional(object({
      peered_network          = string
      peered_network_ip_range = optional(string)
      egress_option           = optional(string) # "EGRESS_OPTION_UNSPECIFIED", "NO_PUBLIC_EGRESS", "PUBLIC_EGRESS"
    }))
  }))
  default = {}
}

# Build Configurations
variable "build_configs" {
  description = "Map of Cloud Build configuration files"
  type = map(object({
    name               = optional(string)
    store_in_gcs       = optional(bool)
    gcs_bucket         = optional(string)
    gcs_object         = optional(string)
    build_yaml_content = string
  }))
  default = {}
}

# Source Repositories Configuration
variable "source_repositories" {
  description = "Map of Cloud Source Repository configurations"
  type = map(object({
    name = optional(string)

    pubsub_configs = optional(list(object({
      topic                 = string
      message_format        = optional(string) # "PROTOBUF", "JSON"
      service_account_email = optional(string)
    })))
  }))
  default = {}
}

# Artifact Registry Configuration
variable "artifact_registries" {
  description = "Map of Artifact Registry repository configurations"
  type = map(object({
    repository_id = optional(string)
    description   = optional(string)
    format        = optional(string) # "DOCKER", "MAVEN", "NPM", "PYTHON", "APT", "YUM", "HELM", "GO", "GENERIC"
    location      = optional(string)
    mode          = optional(string) # "STANDARD_REPOSITORY", "VIRTUAL_REPOSITORY", "REMOTE_REPOSITORY"
    labels        = optional(map(string))
    kms_key_name  = optional(string)

    docker_config = optional(object({
      immutable_tags = optional(bool)
    }))

    maven_config = optional(object({
      allow_snapshot_overwrites = optional(bool)
      version_policy            = optional(string) # "VERSION_POLICY_UNSPECIFIED", "RELEASE", "SNAPSHOT"
    }))

    virtual_repository_config = optional(object({
      upstream_policies = optional(list(object({
        id         = string
        repository = string
        priority   = number
      })))
    }))

    remote_repository_config = optional(object({
      description = optional(string)

      docker_repository = optional(object({
        public_repository = optional(string) # "DOCKER_HUB"
      }))

      maven_repository = optional(object({
        public_repository = optional(string) # "MAVEN_CENTRAL"
      }))

      npm_repository = optional(object({
        public_repository = optional(string) # "NPMJS"
      }))

      python_repository = optional(object({
        public_repository = optional(string) # "PYPI"
      }))

      apt_repository = optional(object({
        public_repository = optional(object({
          repository_base = string
          repository_path = string
        }))
      }))

      yum_repository = optional(object({
        public_repository = optional(object({
          repository_base = string
          repository_path = string
        }))
      }))
    }))

    cleanup_policy_dry_run = optional(bool)

    cleanup_policies = optional(list(object({
      id = string

      condition = optional(object({
        tag_state             = optional(string) # "TAG_STATE_UNSPECIFIED", "TAGGED", "UNTAGGED", "ANY"
        tag_prefixes          = optional(list(string))
        version_name_prefixes = optional(list(string))
        package_name_prefixes = optional(list(string))
        older_than            = optional(string)
        newer_than            = optional(string)
      }))

      most_recent_versions = optional(object({
        package_name_prefixes = optional(list(string))
        keep_count            = optional(number)
      }))

      action = optional(string) # "DELETE", "KEEP"
    })))

    iam_bindings = optional(map(object({
      role   = string
      member = string
    })))
  }))
  default = {}
}

# Service Account Configuration
variable "create_service_account" {
  description = "Whether to create a service account for Cloud Build"
  type        = bool
  default     = false
}

variable "service_account_name" {
  description = "Name of the service account"
  type        = string
  default     = null
}

variable "grant_service_account_roles" {
  description = "Whether to grant roles to the service account"
  type        = bool
  default     = false
}

variable "service_account_roles" {
  description = "Roles to grant to the service account"
  type        = list(string)
  default = [
    "roles/cloudbuild.builds.builder",
    "roles/source.reader",
    "roles/artifactregistry.writer",
    "roles/containerregistry.ServiceAgent",
    "roles/storage.admin",
    "roles/logging.logWriter"
  ]
}

# Monitoring Configuration
variable "create_monitoring_alerts" {
  description = "Whether to create monitoring alert policies"
  type        = bool
  default     = false
}

variable "monitoring_alerts" {
  description = "Monitoring alert policies configuration"
  type = map(object({
    display_name           = string
    condition_display_name = string
    filter                 = string
    threshold_value        = number
    combiner               = optional(string)
    enabled                = optional(bool)
    duration               = optional(string)
    comparison             = optional(string)
    alignment_period       = optional(string)
    per_series_aligner     = optional(string)
    cross_series_reducer   = optional(string)
    group_by_fields        = optional(list(string))
    trigger_count          = optional(number)
    trigger_percent        = optional(number)
    notification_channels  = optional(list(string))
    auto_close             = optional(string)
    rate_limit = optional(object({
      period = string
    }))
    documentation_content   = optional(string)
    documentation_mime_type = optional(string)
    documentation_subject   = optional(string)
    labels                  = optional(map(string))
  }))
  default = {}
}

variable "create_monitoring_dashboard" {
  description = "Whether to create a monitoring dashboard"
  type        = bool
  default     = false
}

# Budget Configuration
variable "create_budget_alert" {
  description = "Whether to create budget alerts"
  type        = bool
  default     = false
}

variable "billing_account" {
  description = "Billing account ID"
  type        = string
  default     = null
}

variable "budget_amount" {
  description = "Budget amount in currency units"
  type        = string
  default     = "1000"
}

variable "budget_currency" {
  description = "Budget currency code"
  type        = string
  default     = "USD"
}

variable "budget_pubsub_topic" {
  description = "Pub/Sub topic for budget notifications"
  type        = string
  default     = null
}

# Labels
variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}