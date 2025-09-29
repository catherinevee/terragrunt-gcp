# Binary Authorization Module - Main Configuration
# Enterprise container security with attestation, policy enforcement, and vulnerability scanning integration

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

# Local variables for configuration
locals {
  # Default admission rule based on enforcement mode
  default_admission_rule = {
    evaluation_mode         = var.default_admission_rule.evaluation_mode
    enforcement_mode        = var.default_admission_rule.enforcement_mode
    require_attestations_by = var.default_admission_rule.require_attestations_by
  }

  # Cluster-specific admission rules
  cluster_admission_rules = {
    for cluster_id, rule in var.cluster_admission_rules : cluster_id => {
      cluster_id              = cluster_id
      evaluation_mode         = rule.evaluation_mode
      enforcement_mode        = rule.enforcement_mode
      require_attestations_by = rule.require_attestations_by
    }
  }

  # Namespace-specific admission rules
  namespace_admission_rules = {
    for key, rule in var.namespace_admission_rules : key => {
      cluster_id              = rule.cluster_id
      namespace_id            = rule.namespace_id
      evaluation_mode         = rule.evaluation_mode
      enforcement_mode        = rule.enforcement_mode
      require_attestations_by = rule.require_attestations_by
    }
  }

  # IST (Istio Service Mesh) admission rules
  istio_admission_rules = {
    for key, rule in var.istio_service_identity_admission_rules : key => {
      cluster_id              = rule.cluster_id
      service_identity        = rule.service_identity
      evaluation_mode         = rule.evaluation_mode
      enforcement_mode        = rule.enforcement_mode
      require_attestations_by = rule.require_attestations_by
    }
  }

  # Attestor configurations with PKIX keys
  attestors = {
    for name, config in var.attestors : name => {
      name        = "${var.attestor_prefix}-${name}"
      description = config.description

      user_owned_grafeas_note = config.use_grafeas ? {
        note_reference = config.grafeas_note_reference != null ? config.grafeas_note_reference : google_container_analysis_note.attestor_notes[name].id
        public_keys    = config.pkix_public_keys
      } : null

      iam_bindings = config.iam_bindings
    }
  }

  # Vulnerability scanning integration
  vulnerability_policies = {
    for name, policy in var.vulnerability_policies : name => {
      maximum_severity           = policy.maximum_severity
      maximum_unfixable_severity = policy.maximum_unfixable_severity
      allowlisted_cves           = policy.allowlisted_cves
      blocklisted_cves           = policy.blocklisted_cves
      cve_expiry_time            = policy.cve_expiry_time
    }
  }

  # Platform policy configurations (for Cloud Run, etc.)
  platform_policies = {
    for platform, config in var.platform_policies : platform => {
      platform        = platform
      policy_data     = config.policy_data
      evaluation_mode = config.evaluation_mode
    }
  }

  # KMS key configurations for attestation signing
  kms_configs = {
    for name, config in var.kms_crypto_key_configs : name => {
      location        = config.location
      key_ring        = config.key_ring
      crypto_key      = config.crypto_key
      purpose         = config.purpose
      algorithm       = config.algorithm
      rotation_period = config.rotation_period
    }
  }

  # Container Analysis notes for attestations
  analysis_notes = {
    for name, config in var.container_analysis_notes : name => {
      note_id         = "${var.project_id}-${name}-note"
      description     = config.description
      related_urls    = config.related_urls
      expiration_time = config.expiration_time
      attestation_authority = {
        hint = config.attestation_hint
      }
    }
  }
}

# Enable required APIs
resource "google_project_service" "binary_authorization_apis" {
  for_each = toset(var.enable_apis ? [
    "binaryauthorization.googleapis.com",
    "containeranalysis.googleapis.com",
    "containerscanning.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudbuild.googleapis.com"
  ] : [])

  project                    = var.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}

# Binary Authorization Policy
resource "google_binary_authorization_policy" "policy" {
  provider = google-beta
  project  = var.project_id

  description                   = var.policy_description
  global_policy_evaluation_mode = var.global_policy_evaluation_mode

  # Default admission rule
  default_admission_rule {
    evaluation_mode  = local.default_admission_rule.evaluation_mode
    enforcement_mode = local.default_admission_rule.enforcement_mode

    dynamic "require_attestations_by" {
      for_each = toset(local.default_admission_rule.require_attestations_by)
      content {
        attestor_id = google_binary_authorization_attestor.attestors[require_attestations_by.value].id
      }
    }
  }

  # Cluster-specific admission rules
  dynamic "cluster_admission_rules" {
    for_each = local.cluster_admission_rules
    content {
      cluster          = cluster_admission_rules.value.cluster_id
      evaluation_mode  = cluster_admission_rules.value.evaluation_mode
      enforcement_mode = cluster_admission_rules.value.enforcement_mode

      dynamic "require_attestations_by" {
        for_each = toset(cluster_admission_rules.value.require_attestations_by)
        content {
          attestor_id = google_binary_authorization_attestor.attestors[require_attestations_by.value].id
        }
      }
    }
  }

  # Namespace-specific admission rules
  dynamic "kubernetes_namespace_admission_rules" {
    for_each = local.namespace_admission_rules
    content {
      cluster          = kubernetes_namespace_admission_rules.value.cluster_id
      namespace        = kubernetes_namespace_admission_rules.value.namespace_id
      evaluation_mode  = kubernetes_namespace_admission_rules.value.evaluation_mode
      enforcement_mode = kubernetes_namespace_admission_rules.value.enforcement_mode

      dynamic "require_attestations_by" {
        for_each = toset(kubernetes_namespace_admission_rules.value.require_attestations_by)
        content {
          attestor_id = google_binary_authorization_attestor.attestors[require_attestations_by.value].id
        }
      }
    }
  }

  # Istio service identity admission rules
  dynamic "istio_service_identity_admission_rules" {
    for_each = local.istio_admission_rules
    content {
      cluster          = istio_service_identity_admission_rules.value.cluster_id
      service_identity = istio_service_identity_admission_rules.value.service_identity
      evaluation_mode  = istio_service_identity_admission_rules.value.evaluation_mode
      enforcement_mode = istio_service_identity_admission_rules.value.enforcement_mode

      dynamic "require_attestations_by" {
        for_each = toset(istio_service_identity_admission_rules.value.require_attestations_by)
        content {
          attestor_id = google_binary_authorization_attestor.attestors[require_attestations_by.value].id
        }
      }
    }
  }

  depends_on = [
    google_project_service.binary_authorization_apis,
    google_binary_authorization_attestor.attestors
  ]
}

# Container Analysis Notes for attestations
resource "google_container_analysis_note" "attestor_notes" {
  for_each = { for name, config in var.attestors : name => config if config.use_grafeas && config.grafeas_note_reference == null }

  name    = "${var.project_id}-${each.key}-note"
  project = var.project_id

  attestation {
    hint {
      human_readable_name = "${each.value.description} Attestation"
    }
  }

  short_description = "Attestation note for ${each.key}"
  long_description  = each.value.description

  related_url {
    url   = "https://console.cloud.google.com/binary-authorization/policy?project=${var.project_id}"
    label = "Binary Authorization Policy"
  }

  dynamic "related_url" {
    for_each = lookup(each.value, "related_urls", [])
    content {
      url   = related_url.value.url
      label = related_url.value.label
    }
  }

  depends_on = [google_project_service.binary_authorization_apis]
}

# Binary Authorization Attestors
resource "google_binary_authorization_attestor" "attestors" {
  for_each = local.attestors

  name        = each.value.name
  project     = var.project_id
  description = each.value.description

  dynamic "user_owned_grafeas_note" {
    for_each = each.value.user_owned_grafeas_note != null ? [each.value.user_owned_grafeas_note] : []
    content {
      note_reference = user_owned_grafeas_note.value.note_reference

      dynamic "public_keys" {
        for_each = user_owned_grafeas_note.value.public_keys
        content {
          id      = public_keys.value.id
          comment = public_keys.value.comment

          dynamic "ascii_armored_pgp_public_key" {
            for_each = public_keys.value.ascii_armored_pgp_public_key != null ? [public_keys.value.ascii_armored_pgp_public_key] : []
            content {
              ascii_armored_pgp_public_key = ascii_armored_pgp_public_key.value
            }
          }

          dynamic "pkix_public_key" {
            for_each = public_keys.value.pkix_public_key != null ? [public_keys.value.pkix_public_key] : []
            content {
              public_key_pem      = pkix_public_key.value.public_key_pem
              signature_algorithm = pkix_public_key.value.signature_algorithm
            }
          }
        }
      }

      delegation_service_account_email = user_owned_grafeas_note.value.delegation_service_account_email
    }
  }

  depends_on = [
    google_project_service.binary_authorization_apis,
    google_container_analysis_note.attestor_notes
  ]
}

# IAM bindings for attestors
resource "google_binary_authorization_attestor_iam_binding" "attestor_bindings" {
  for_each = merge([
    for attestor_name, attestor_config in local.attestors : {
      for role, members in attestor_config.iam_bindings :
      "${attestor_name}-${role}" => {
        attestor = google_binary_authorization_attestor.attestors[attestor_name].id
        role     = role
        members  = members
      }
    }
  ]...)

  project  = var.project_id
  attestor = each.value.attestor
  role     = each.value.role
  members  = each.value.members
}

# KMS crypto keys for attestation signing
resource "google_kms_key_ring" "attestation_key_rings" {
  for_each = { for name, config in local.kms_configs : name => config if var.create_kms_keys }

  name     = each.value.key_ring
  project  = var.project_id
  location = each.value.location

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.binary_authorization_apis]
}

resource "google_kms_crypto_key" "attestation_keys" {
  for_each = { for name, config in local.kms_configs : name => config if var.create_kms_keys }

  name            = each.value.crypto_key
  key_ring        = google_kms_key_ring.attestation_key_rings[each.key].id
  purpose         = each.value.purpose
  rotation_period = each.value.rotation_period

  version_template {
    algorithm        = each.value.algorithm
    protection_level = var.hsm_protection_level ? "HSM" : "SOFTWARE"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# KMS crypto key IAM for attestation service accounts
resource "google_kms_crypto_key_iam_binding" "attestation_key_bindings" {
  for_each = { for name, config in local.kms_configs : name => config if var.create_kms_keys && length(config.key_users) > 0 }

  crypto_key_id = google_kms_crypto_key.attestation_keys[each.key].id
  role          = "roles/cloudkms.signerVerifier"
  members       = each.value.key_users
}

# Service account for attestation operations
resource "google_service_account" "attestation_sa" {
  count = var.create_attestation_service_account ? 1 : 0

  account_id   = var.attestation_service_account_id
  display_name = "Binary Authorization Attestation Service Account"
  description  = "Service account for creating and verifying attestations"
  project      = var.project_id
}

# Service account IAM bindings
resource "google_project_iam_member" "attestation_sa_roles" {
  for_each = var.create_attestation_service_account ? toset(var.attestation_service_account_roles) : []

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.attestation_sa[0].email}"
}

# Container Analysis Occurrences for attestations
resource "google_container_analysis_occurrence" "attestation_occurrences" {
  for_each = var.create_sample_attestations ? var.sample_attestations : {}

  project      = var.project_id
  resource_uri = each.value.resource_uri
  note_name    = google_container_analysis_note.attestor_notes[each.value.attestor].id

  attestation {
    serialized_payload = base64encode(jsonencode({
      critical = {
        identity = {
          docker_reference = each.value.resource_uri
        }
        image = {
          docker_manifest_digest = each.value.digest
        }
        type = "atomic container signature"
      }
    }))

    signatures {
      public_key_id = each.value.public_key_id
      signature     = each.value.signature
    }
  }

  depends_on = [
    google_container_analysis_note.attestor_notes,
    google_binary_authorization_attestor.attestors
  ]
}

# Platform policies for Cloud Run
resource "google_binary_authorization_platform_policy" "platform_policies" {
  for_each = { for platform, config in local.platform_policies : platform => config if var.enable_platform_policies }

  provider    = google-beta
  project     = var.project_id
  platform    = each.value.platform
  policy_data = jsonencode(each.value.policy_data)
  description = "Platform policy for ${each.value.platform}"
}

# Continuous Validation for GKE clusters
resource "google_binary_authorization_policy_binding" "continuous_validation" {
  for_each = var.continuous_validation_enabled ? var.continuous_validation_clusters : {}

  provider = google-beta
  project  = var.project_id

  name = "${each.key}-cv-binding"

  policy_binding_id = "${each.key}-continuous-validation"

  policy {
    kubernetes_policy {
      admission_whitelist_patterns {
        name_pattern = each.value.admission_whitelist_pattern
      }

      dynamic "image_allowlist" {
        for_each = each.value.image_allowlist
        content {
          allow_pattern = image_allowlist.value
        }
      }
    }
  }
}

# Cloud Build trigger for attestation creation
resource "google_cloudbuild_trigger" "attestation_trigger" {
  count = var.create_cloudbuild_attestation_trigger ? 1 : 0

  project     = var.project_id
  name        = "${var.attestor_prefix}-attestation-trigger"
  description = "Trigger for creating Binary Authorization attestations"

  trigger_template {
    project_id  = var.project_id
    repo_name   = var.attestation_trigger_repo
    branch_name = var.attestation_trigger_branch
  }

  build {
    step {
      name = "gcr.io/cloud-builders/gcloud"
      args = [
        "beta",
        "container",
        "binauthz",
        "attestations",
        "sign-and-create",
        "--project=${var.project_id}",
        "--artifact-url=$${_IMAGE}@$${_IMAGE_DIGEST}",
        "--attestor=${google_binary_authorization_attestor.attestors[var.primary_attestor].name}",
        "--keyversion=${var.attestation_kms_key_version}"
      ]
    }

    substitutions = {
      _IMAGE        = "$${_IMAGE}"
      _IMAGE_DIGEST = "$${_IMAGE_DIGEST}"
    }

    options {
      substitution_option = "ALLOW_LOOSE"
      logging             = "CLOUD_LOGGING_ONLY"
    }
  }

  depends_on = [
    google_project_service.binary_authorization_apis,
    google_binary_authorization_attestor.attestors
  ]
}

# Monitoring dashboard for Binary Authorization
resource "google_monitoring_dashboard" "binary_authorization_dashboard" {
  count = var.enable_monitoring && var.create_dashboard ? 1 : 0

  dashboard_json = jsonencode({
    displayName = "Binary Authorization Dashboard - ${var.project_id}"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Admission Decisions"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_cluster\" metric.type=\"binaryauthorization.googleapis.com/admission_decisions\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.decision"]
                      }
                    }
                  }
                  plotType = "STACKED_AREA"
                }
              ]
            }
          }
        },
        {
          xPos   = 6
          width  = 6
          height = 4
          widget = {
            title = "Policy Violations"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_cluster\" metric.type=\"binaryauthorization.googleapis.com/policy_violations\""
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_RATE"
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
            }
          }
        },
        {
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Attestation Verifications"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"binary_authorization_attestor\" metric.type=\"binaryauthorization.googleapis.com/attestation_requests\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["resource.attestor_id"]
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Continuous Validation Findings"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"k8s_cluster\" metric.type=\"binaryauthorization.googleapis.com/continuous_validation_findings\""
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
        }
      ]
    }
  })

  project = var.project_id
}

# Alert policies for Binary Authorization
resource "google_monitoring_alert_policy" "binary_authorization_alerts" {
  for_each = var.enable_monitoring ? var.alert_policies : {}

  display_name = each.value.display_name
  project      = var.project_id
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

      trigger {
        count   = each.value.trigger_count
        percent = each.value.trigger_percent
      }
    }
  }

  notification_channels = each.value.notification_channels

  user_labels = merge(
    var.labels,
    each.value.labels
  )
}

# Vulnerability scanning policy integration
resource "google_container_analysis_note" "vulnerability_notes" {
  for_each = var.enable_vulnerability_scanning ? local.vulnerability_policies : {}

  name    = "${var.project_id}-vulnerability-${each.key}-note"
  project = var.project_id

  vulnerability {
    severity = each.value.maximum_severity

    dynamic "cve_details" {
      for_each = each.value.blocklisted_cves
      content {
        cve_id = cve_details.value
      }
    }
  }

  short_description = "Vulnerability policy for ${each.key}"
  long_description  = "Maximum severity: ${each.value.maximum_severity}, Blocklisted CVEs: ${join(", ", each.value.blocklisted_cves)}"

  depends_on = [google_project_service.binary_authorization_apis]
}