# Config Connector Module - Main Configuration

# Enable required APIs
resource "google_project_service" "config_connector_apis" {
  for_each = var.enable_apis ? toset([
    "container.googleapis.com",
    "gkehub.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "secretmanager.googleapis.com",
    "certificatemanager.googleapis.com",
    "anthosconfigmanagement.googleapis.com"
  ]) : toset([])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# Config Connector Feature in GKE Hub
resource "google_gke_hub_feature" "config_management" {
  count = var.enable_config_connector ? 1 : 0

  name     = "configmanagement"
  project  = var.project_id
  location = "global"

  depends_on = [
    google_project_service.config_connector_apis
  ]
}

# Config Connector membership configurations
resource "google_gke_hub_feature_membership" "config_connector_memberships" {
  for_each = var.enable_config_connector ? var.config_connector_memberships : {}

  location   = "global"
  feature    = google_gke_hub_feature.config_management[0].name
  membership = each.value.membership_name
  project    = var.project_id

  configmanagement {
    version = each.value.config_management_version

    config_sync {
      enabled       = each.value.config_sync_enabled
      source_format = each.value.source_format

      git {
        sync_repo               = each.value.sync_repo
        sync_branch             = each.value.sync_branch
        policy_dir              = each.value.policy_dir
        sync_wait_secs          = each.value.sync_wait_secs
        secret_type             = each.value.secret_type
        https_proxy             = each.value.https_proxy
        gcp_service_account_email = each.value.gcp_service_account_email
      }

      prevent_drift                = each.value.prevent_drift
      metrics_gcp_service_account_email = each.value.metrics_gcp_service_account_email
    }

    policy_controller {
      enabled                    = each.value.policy_controller_enabled
      template_library_installed = each.value.template_library_installed
      audit_interval_seconds     = each.value.audit_interval_seconds
      exemptable_namespaces      = each.value.exemptable_namespaces
      log_denies_enabled         = each.value.log_denies_enabled
      mutation_enabled           = each.value.mutation_enabled
      referential_rules_enabled  = each.value.referential_rules_enabled

      dynamic "monitoring" {
        for_each = each.value.policy_controller_monitoring != null ? [each.value.policy_controller_monitoring] : []
        content {
          backends = monitoring.value.backends
        }
      }
    }

    hierarchy_controller {
      enabled                             = each.value.hierarchy_controller_enabled
      enable_pod_tree_labels              = each.value.enable_pod_tree_labels
      enable_hierarchical_resource_quota  = each.value.enable_hierarchical_resource_quota
    }

    binauthz {
      enabled = each.value.binauthz_enabled
    }
  }

  depends_on = [
    google_gke_hub_feature.config_management
  ]
}

# Config Connector namespace
resource "kubernetes_namespace" "config_connector_system" {
  count = var.create_config_connector_namespace ? 1 : 0

  metadata {
    name = var.config_connector_namespace
    labels = merge(var.labels, {
      "cnrm.cloud.google.com/system" = "true"
      "app.kubernetes.io/managed-by" = "terraform"
    })
    annotations = merge(var.namespace_annotations, {
      "cnrm.cloud.google.com/project-id" = var.project_id
    })
  }

  depends_on = [
    google_gke_hub_feature_membership.config_connector_memberships
  ]
}

# Config Connector operator
resource "kubernetes_manifest" "config_connector_operator" {
  count = var.install_config_connector_operator ? 1 : 0

  manifest = {
    apiVersion = "core.cnrm.cloud.google.com/v1beta1"
    kind       = "ConfigConnector"
    metadata = {
      name = "configconnector.core.cnrm.cloud.google.com"
      labels = merge(var.labels, {
        "cnrm.cloud.google.com/system" = "true"
      })
    }
    spec = {
      mode                 = var.config_connector_mode
      googleServiceAccount = var.google_service_account_email

      credentialSecretName = var.credential_secret_name

      stateIntoSpec = var.state_into_spec

      actuationMode = var.actuation_mode

      webhookConfiguration = {
        failurePolicy = var.webhook_failure_policy
        timeoutSeconds = var.webhook_timeout_seconds
      }

      resourceWatcherConfiguration = {
        watchFleetWorkloads       = var.watch_fleet_workloads
        watchFleetWorkloadIdentity = var.watch_fleet_workload_identity
      }
    }
  }

  depends_on = [
    kubernetes_namespace.config_connector_system
  ]
}

# Config Connector Context for namespace-scoped resources
resource "kubernetes_manifest" "config_connector_contexts" {
  for_each = var.config_connector_contexts

  manifest = {
    apiVersion = "core.cnrm.cloud.google.com/v1beta1"
    kind       = "ConfigConnectorContext"
    metadata = {
      name      = each.key
      namespace = each.value.namespace
      labels = merge(var.labels, each.value.labels)
    }
    spec = {
      googleServiceAccount = each.value.google_service_account_email
      billingProject       = each.value.billing_project
      requestProjectPolicy = each.value.request_project_policy

      credentialSecretName = each.value.credential_secret_name

      stateIntoSpec = each.value.state_into_spec

      actuationMode = each.value.actuation_mode
    }
  }

  depends_on = [
    kubernetes_manifest.config_connector_operator
  ]
}

# Service account for Config Connector
resource "google_service_account" "config_connector_sa" {
  count = var.create_service_account ? 1 : 0

  account_id   = var.service_account_id
  display_name = "Config Connector Service Account"
  description  = "Service account for Config Connector operations"
  project      = var.project_id
}

# IAM roles for the service account
resource "google_project_iam_member" "config_connector_sa_roles" {
  for_each = var.create_service_account ? toset(var.service_account_roles) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.config_connector_sa[0].email}"

  depends_on = [
    google_service_account.config_connector_sa
  ]
}

# Workload Identity binding
resource "google_service_account_iam_member" "workload_identity_binding" {
  count = var.enable_workload_identity && var.create_service_account ? 1 : 0

  service_account_id = google_service_account.config_connector_sa[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.config_connector_namespace}/${var.kubernetes_service_account_name}]"

  depends_on = [
    google_service_account.config_connector_sa
  ]
}

# Kubernetes service account for Config Connector
resource "kubernetes_service_account" "config_connector_ksa" {
  count = var.create_kubernetes_service_account ? 1 : 0

  metadata {
    name      = var.kubernetes_service_account_name
    namespace = var.config_connector_namespace
    labels = merge(var.labels, {
      "cnrm.cloud.google.com/system" = "true"
    })
    annotations = {
      "iam.gke.io/gcp-service-account" = var.create_service_account ? google_service_account.config_connector_sa[0].email : var.google_service_account_email
    }
  }

  depends_on = [
    kubernetes_namespace.config_connector_system,
    google_service_account_iam_member.workload_identity_binding
  ]
}

# Config Connector Custom Resource Definitions
resource "kubernetes_manifest" "config_connector_crds" {
  for_each = var.enable_custom_resources ? var.custom_resource_definitions : {}

  manifest = {
    apiVersion = each.value.api_version
    kind       = each.value.kind
    metadata = {
      name      = each.key
      namespace = each.value.namespace
      labels = merge(var.labels, each.value.labels)
      annotations = each.value.annotations
    }
    spec = each.value.spec
  }

  depends_on = [
    kubernetes_manifest.config_connector_contexts
  ]
}

# Policy Controller constraints
resource "kubernetes_manifest" "policy_constraints" {
  for_each = var.enable_policy_controller ? var.policy_constraints : {}

  manifest = {
    apiVersion = each.value.api_version
    kind       = each.value.kind
    metadata = {
      name = each.key
      labels = merge(var.labels, each.value.labels)
    }
    spec = each.value.spec
  }

  depends_on = [
    google_gke_hub_feature_membership.config_connector_memberships
  ]
}

# Policy Controller constraint templates
resource "kubernetes_manifest" "constraint_templates" {
  for_each = var.enable_policy_controller ? var.constraint_templates : {}

  manifest = {
    apiVersion = "templates.gatekeeper.sh/v1beta1"
    kind       = "ConstraintTemplate"
    metadata = {
      name = each.key
      labels = merge(var.labels, each.value.labels)
    }
    spec = {
      crd = {
        spec = {
          names = {
            kind = each.value.crd_kind
          }
          validation = {
            openAPIV3Schema = each.value.validation_schema
          }
        }
      }
      targets = each.value.targets
    }
  }

  depends_on = [
    kubernetes_manifest.policy_constraints
  ]
}

# Config Sync repository configuration
resource "kubernetes_secret" "config_sync_secret" {
  for_each = var.enable_config_sync ? var.config_sync_secrets : {}

  metadata {
    name      = each.key
    namespace = each.value.namespace
    labels = merge(var.labels, {
      "app" = "config-sync"
    })
  }

  type = each.value.secret_type

  data = each.value.data

  depends_on = [
    kubernetes_namespace.config_connector_system
  ]
}

# Hierarchy Controller configuration
resource "kubernetes_manifest" "hierarchy_configs" {
  for_each = var.enable_hierarchy_controller ? var.hierarchy_configurations : {}

  manifest = {
    apiVersion = "hnc.x-k8s.io/v1alpha2"
    kind       = each.value.kind
    metadata = {
      name      = each.key
      namespace = each.value.namespace
      labels = merge(var.labels, each.value.labels)
    }
    spec = each.value.spec
  }

  depends_on = [
    google_gke_hub_feature_membership.config_connector_memberships
  ]
}

# Resource quotas for Config Connector namespaces
resource "kubernetes_resource_quota" "config_connector_quotas" {
  for_each = var.enable_resource_quotas ? var.resource_quotas : {}

  metadata {
    name      = each.key
    namespace = each.value.namespace
    labels = merge(var.labels, {
      "managed-by" = "config-connector"
    })
  }

  spec {
    hard = each.value.hard_limits
    scopes = each.value.scopes
    scope_selector {
      dynamic "match_expression" {
        for_each = each.value.scope_selector_match_expressions
        content {
          scope_name = match_expression.value.scope_name
          operator   = match_expression.value.operator
          values     = match_expression.value.values
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.config_connector_system
  ]
}

# Network policies for Config Connector
resource "kubernetes_network_policy" "config_connector_network_policies" {
  for_each = var.enable_network_policies ? var.network_policies : {}

  metadata {
    name      = each.key
    namespace = each.value.namespace
    labels = merge(var.labels, {
      "component" = "config-connector"
    })
  }

  spec {
    pod_selector {
      match_labels = each.value.pod_selector_match_labels
    }

    policy_types = each.value.policy_types

    dynamic "ingress" {
      for_each = each.value.ingress_rules
      content {
        dynamic "ports" {
          for_each = ingress.value.ports
          content {
            port     = ports.value.port
            protocol = ports.value.protocol
          }
        }

        dynamic "from" {
          for_each = ingress.value.from_rules
          content {
            dynamic "namespace_selector" {
              for_each = from.value.namespace_selector != null ? [from.value.namespace_selector] : []
              content {
                match_labels = namespace_selector.value.match_labels
              }
            }

            dynamic "pod_selector" {
              for_each = from.value.pod_selector != null ? [from.value.pod_selector] : []
              content {
                match_labels = pod_selector.value.match_labels
              }
            }

            dynamic "ip_block" {
              for_each = from.value.ip_block != null ? [from.value.ip_block] : []
              content {
                cidr   = ip_block.value.cidr
                except = ip_block.value.except
              }
            }
          }
        }
      }
    }

    dynamic "egress" {
      for_each = each.value.egress_rules
      content {
        dynamic "ports" {
          for_each = egress.value.ports
          content {
            port     = ports.value.port
            protocol = ports.value.protocol
          }
        }

        dynamic "to" {
          for_each = egress.value.to_rules
          content {
            dynamic "namespace_selector" {
              for_each = to.value.namespace_selector != null ? [to.value.namespace_selector] : []
              content {
                match_labels = namespace_selector.value.match_labels
              }
            }

            dynamic "pod_selector" {
              for_each = to.value.pod_selector != null ? [to.value.pod_selector] : []
              content {
                match_labels = pod_selector.value.match_labels
              }
            }

            dynamic "ip_block" {
              for_each = to.value.ip_block != null ? [to.value.ip_block] : []
              content {
                cidr   = ip_block.value.cidr
                except = ip_block.value.except
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.config_connector_system
  ]
}

# RBAC configuration for Config Connector
resource "kubernetes_cluster_role" "config_connector_roles" {
  for_each = var.enable_rbac ? var.cluster_roles : {}

  metadata {
    name = each.key
    labels = merge(var.labels, {
      "app.kubernetes.io/component" = "config-connector"
    })
  }

  dynamic "rule" {
    for_each = each.value.rules
    content {
      api_groups        = rule.value.api_groups
      resources         = rule.value.resources
      resource_names    = rule.value.resource_names
      verbs            = rule.value.verbs
      non_resource_urls = rule.value.non_resource_urls
    }
  }

  depends_on = [
    kubernetes_service_account.config_connector_ksa
  ]
}

resource "kubernetes_cluster_role_binding" "config_connector_role_bindings" {
  for_each = var.enable_rbac ? var.cluster_role_bindings : {}

  metadata {
    name = each.key
    labels = merge(var.labels, {
      "app.kubernetes.io/component" = "config-connector"
    })
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = each.value.cluster_role_name
  }

  dynamic "subject" {
    for_each = each.value.subjects
    content {
      kind      = subject.value.kind
      name      = subject.value.name
      namespace = subject.value.namespace
      api_group = subject.value.api_group
    }
  }

  depends_on = [
    kubernetes_cluster_role.config_connector_roles
  ]
}

# Monitoring dashboard for Config Connector
resource "google_monitoring_dashboard" "config_connector_dashboard" {
  count = var.enable_monitoring && var.create_dashboard ? 1 : 0

  dashboard_json = jsonencode({
    displayName = var.dashboard_display_name
    mosaicLayout = {
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Config Connector Resource Count"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/cpu/core_usage_time\" AND metadata.user_labels.app=\"cnrm-controller-manager\""
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "CPU Usage"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Config Connector Memory Usage"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/memory/used_bytes\" AND metadata.user_labels.app=\"cnrm-controller-manager\""
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Memory (bytes)"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Policy Controller Violations"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"k8s_container\" AND metric.type=\"gatekeeper/violations\""
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Violations"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Config Sync Status"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"k8s_container\" AND metric.type=\"config_sync/api_duration_seconds\""
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
        }
      ]
    }
  })

  project = var.project_id

  depends_on = [
    google_project_service.config_connector_apis
  ]
}

# Alert policies for Config Connector monitoring
resource "google_monitoring_alert_policy" "config_connector_alerts" {
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
        alignment_period   = each.value.alignment_period
        per_series_aligner = each.value.per_series_aligner
        cross_series_reducer = each.value.cross_series_reducer
        group_by_fields    = each.value.group_by_fields
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
    google_project_service.config_connector_apis
  ]
}

# Log sink for Config Connector audit logs
resource "google_logging_project_sink" "config_connector_audit_sink" {
  count = var.enable_audit_logging ? 1 : 0

  name        = var.audit_log_sink_name
  destination = var.audit_log_destination

  filter = join(" OR ", [
    "resource.type=\"k8s_cluster\"",
    "resource.type=\"gke_cluster\"",
    "protoPayload.serviceName=\"anthosconfigmanagement.googleapis.com\"",
    "labels.\"k8s-pod/app\"=\"cnrm-controller-manager\"",
    "labels.\"k8s-pod/app\"=\"gatekeeper\"",
    "labels.\"k8s-pod/app\"=\"config-sync\""
  ])

  unique_writer_identity = true
  project               = var.project_id

  depends_on = [
    google_project_service.config_connector_apis
  ]
}

# Backup configuration for Config Connector state
resource "kubernetes_manifest" "config_connector_backup" {
  for_each = var.enable_backup ? var.backup_configurations : {}

  manifest = {
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = each.key
      namespace = each.value.namespace
      labels = merge(var.labels, {
        "component" = "config-connector-backup"
      })
    }
    data = {
      backup_schedule = each.value.backup_schedule
      retention_days  = tostring(each.value.retention_days)
      backup_location = each.value.backup_location
      encryption_key  = each.value.encryption_key
    }
  }

  depends_on = [
    kubernetes_namespace.config_connector_system
  ]
}

# Local values for data processing
locals {
  # All Config Connector namespaces
  all_cc_namespaces = concat(
    var.create_config_connector_namespace ? [var.config_connector_namespace] : [],
    [for context in var.config_connector_contexts : context.namespace]
  )

  # Service account email to use
  service_account_email = var.create_service_account ? google_service_account.config_connector_sa[0].email : var.google_service_account_email

  # Default Config Connector annotations
  default_cc_annotations = {
    "cnrm.cloud.google.com/project-id" = var.project_id
    "cnrm.cloud.google.com/managed-by-cnrm" = "true"
  }

  # Config management versions mapping
  config_management_versions = {
    "1.15.1" = "latest"
    "1.14.3" = "stable"
    "1.13.5" = "legacy"
  }

  # Resource types supported by Config Connector
  supported_resource_types = [
    "bigquerydataset.cnrm.cloud.google.com",
    "bigtableinstance.cnrm.cloud.google.com",
    "computeinstance.cnrm.cloud.google.com",
    "containercluster.cnrm.cloud.google.com",
    "iamserviceaccount.cnrm.cloud.google.com",
    "pubsubtopic.cnrm.cloud.google.com",
    "spannerinstance.cnrm.cloud.google.com",
    "storagebucket.cnrm.cloud.google.com",
    "sqlinstance.cnrm.cloud.google.com"
  ]
}