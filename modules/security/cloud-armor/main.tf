# Cloud Armor Module
# Provides comprehensive Cloud Armor security policies with DDoS protection, WAF rules, and rate limiting

terraform {
  required_version = ">= 1.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.0"
    }
  }
}

# Local values for resource naming and configuration
locals {
  name_prefix = var.name_prefix != null ? var.name_prefix : "armor"
  environment = var.environment != null ? var.environment : "dev"

  # Common labels to apply to all resources
  default_labels = merge(var.labels, {
    module      = "cloud-armor"
    environment = local.environment
    managed_by  = "terraform"
  })

  # Security policy configurations with defaults
  security_policies = {
    for name, config in var.security_policies : name => merge({
      name        = "${local.name_prefix}-${name}-${local.environment}"
      description = "Cloud Armor security policy for ${name}"
      type        = "CLOUD_ARMOR"

      # Default rule configuration
      default_rule = {
        action      = "allow"
        priority    = 2147483647
        description = "Default rule - allow all traffic"
        preview     = false
        match = {
          versioned_expr = "SRC_IPS_V1"
          config = {
            src_ip_ranges = ["*"]
          }
        }
      }

      # Pre-configured rules
      preconfigured_waf_config = {
        exclusions = []
      }

      # Adaptive protection configuration
      adaptive_protection_config = {
        layer_7_ddos_defense_config = {
          enable                    = false
          rule_visibility          = "STANDARD"
          threshold_configs = []
        }
        auto_deploy_config = {
          load_threshold            = 0.1
          confidence_threshold      = 0.5
          impacted_baseline_threshold = 0.01
          expiration_sec           = 7200
        }
      }

      # Advanced options
      advanced_options_config = {
        json_parsing = "STANDARD"
        json_custom_config = {
          content_types = []
        }
        log_level = "NORMAL"
        user_ip_request_headers = []
      }

      # Rate limiting rules
      rate_limit_rules = []

      # Geographic rules
      geo_rules = []

      # IP allowlist/blocklist rules
      ip_rules = []

      # Custom expression rules
      custom_rules = []

      # OWASP ModSecurity CRS rules
      owasp_rules = []

      # Bot management rules
      bot_management_rules = []
    }, config)
  }

  # Flatten all rules for easier processing
  all_security_rules = merge(
    # Rate limiting rules
    {
      for policy_name, policy in local.security_policies :
      "${policy_name}_rate_limit" => {
        policy_name = policy_name
        type       = "rate_limit"
        rules      = policy.rate_limit_rules
      }
      if length(policy.rate_limit_rules) > 0
    },
    # Geographic rules
    {
      for policy_name, policy in local.security_policies :
      "${policy_name}_geo" => {
        policy_name = policy_name
        type       = "geo"
        rules      = policy.geo_rules
      }
      if length(policy.geo_rules) > 0
    },
    # IP rules
    {
      for policy_name, policy in local.security_policies :
      "${policy_name}_ip" => {
        policy_name = policy_name
        type       = "ip"
        rules      = policy.ip_rules
      }
      if length(policy.ip_rules) > 0
    },
    # Custom rules
    {
      for policy_name, policy in local.security_policies :
      "${policy_name}_custom" => {
        policy_name = policy_name
        type       = "custom"
        rules      = policy.custom_rules
      }
      if length(policy.custom_rules) > 0
    },
    # OWASP rules
    {
      for policy_name, policy in local.security_policies :
      "${policy_name}_owasp" => {
        policy_name = policy_name
        type       = "owasp"
        rules      = policy.owasp_rules
      }
      if length(policy.owasp_rules) > 0
    },
    # Bot management rules
    {
      for policy_name, policy in local.security_policies :
      "${policy_name}_bot" => {
        policy_name = policy_name
        type       = "bot"
        rules      = policy.bot_management_rules
      }
      if length(policy.bot_management_rules) > 0
    }
  )

  # Edge security policy configurations
  edge_security_policies = {
    for name, config in var.edge_security_policies : name => merge({
      name        = "${local.name_prefix}-edge-${name}-${local.environment}"
      description = "Edge security policy for ${name}"
      type        = "CLOUD_ARMOR_EDGE"

      # Default rule
      default_rule = {
        action      = "allow"
        priority    = 2147483647
        description = "Default edge rule"
      }

      # Edge rules
      rules = []
    }, config)
  }

  # Security policy attachments
  policy_attachments = {
    for name, config in var.policy_attachments : name => merge({
      security_policy = config.security_policy
      backend_service = config.backend_service
    }, config)
  }
}

# Data sources
data "google_project" "current" {
  project_id = var.project_id
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com"
  ])

  project = var.project_id
  service = each.key

  disable_dependent_services = false
  disable_on_destroy        = false
}

# Service account for Cloud Armor operations
resource "google_service_account" "armor" {
  count = var.create_service_account ? 1 : 0

  project      = var.project_id
  account_id   = var.service_account_name != null ? var.service_account_name : "${local.name_prefix}-${local.environment}"
  display_name = "Cloud Armor Service Account for ${title(local.environment)}"
  description  = "Service account for Cloud Armor operations in ${local.environment} environment"
}

# IAM role bindings for service account
resource "google_project_iam_member" "armor_roles" {
  for_each = var.create_service_account && var.grant_service_account_roles ? toset(var.service_account_roles) : toset([])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.armor[0].email}"

  depends_on = [google_service_account.armor]
}

# Cloud Armor Security Policies
resource "google_compute_security_policy" "security_policies" {
  for_each = local.security_policies

  project = var.project_id
  name    = each.value.name

  description = each.value.description
  type        = each.value.type

  # Default rule
  rule {
    action      = each.value.default_rule.action
    priority    = each.value.default_rule.priority
    description = each.value.default_rule.description
    preview     = each.value.default_rule.preview

    match {
      versioned_expr = each.value.default_rule.match.versioned_expr
      config {
        src_ip_ranges = each.value.default_rule.match.config.src_ip_ranges
      }
    }
  }

  # Rate limiting rules
  dynamic "rule" {
    for_each = each.value.rate_limit_rules
    content {
      action      = rule.value.action
      priority    = rule.value.priority
      description = rule.value.description
      preview     = rule.value.preview != null ? rule.value.preview : false

      match {
        versioned_expr = rule.value.match.versioned_expr
        config {
          src_ip_ranges = rule.value.match.config.src_ip_ranges
        }
      }

      rate_limit_options {
        conform_action = rule.value.rate_limit_options.conform_action
        exceed_action  = rule.value.rate_limit_options.exceed_action

        rate_limit_threshold {
          count        = rule.value.rate_limit_options.rate_limit_threshold.count
          interval_sec = rule.value.rate_limit_options.rate_limit_threshold.interval_sec
        }

        dynamic "enforce_on_key" {
          for_each = rule.value.rate_limit_options.enforce_on_key != null ? [1] : []
          content {
            enforce_on_key_type = rule.value.rate_limit_options.enforce_on_key.enforce_on_key_type
            enforce_on_key_name = rule.value.rate_limit_options.enforce_on_key.enforce_on_key_name
          }
        }

        dynamic "ban_threshold" {
          for_each = rule.value.rate_limit_options.ban_threshold != null ? [1] : []
          content {
            count        = rule.value.rate_limit_options.ban_threshold.count
            interval_sec = rule.value.rate_limit_options.ban_threshold.interval_sec
          }
        }

        ban_duration_sec = rule.value.rate_limit_options.ban_duration_sec

        dynamic "exceed_redirect_options" {
          for_each = rule.value.rate_limit_options.exceed_redirect_options != null ? [1] : []
          content {
            type   = rule.value.rate_limit_options.exceed_redirect_options.type
            target = rule.value.rate_limit_options.exceed_redirect_options.target
          }
        }
      }
    }
  }

  # Geographic rules
  dynamic "rule" {
    for_each = each.value.geo_rules
    content {
      action      = rule.value.action
      priority    = rule.value.priority
      description = rule.value.description
      preview     = rule.value.preview != null ? rule.value.preview : false

      match {
        expr {
          expression = rule.value.expression
        }
      }

      dynamic "header_action" {
        for_each = rule.value.header_action != null ? [1] : []
        content {
          dynamic "request_headers_to_adds" {
            for_each = rule.value.header_action.request_headers_to_adds != null ? rule.value.header_action.request_headers_to_adds : []
            content {
              header_name  = request_headers_to_adds.value.header_name
              header_value = request_headers_to_adds.value.header_value
              replace      = request_headers_to_adds.value.replace
            }
          }
        }
      }
    }
  }

  # IP allowlist/blocklist rules
  dynamic "rule" {
    for_each = each.value.ip_rules
    content {
      action      = rule.value.action
      priority    = rule.value.priority
      description = rule.value.description
      preview     = rule.value.preview != null ? rule.value.preview : false

      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = rule.value.src_ip_ranges
        }
      }
    }
  }

  # Custom expression rules
  dynamic "rule" {
    for_each = each.value.custom_rules
    content {
      action      = rule.value.action
      priority    = rule.value.priority
      description = rule.value.description
      preview     = rule.value.preview != null ? rule.value.preview : false

      match {
        expr {
          expression = rule.value.expression
        }
      }

      dynamic "redirect_options" {
        for_each = rule.value.redirect_options != null ? [1] : []
        content {
          type   = rule.value.redirect_options.type
          target = rule.value.redirect_options.target
        }
      }
    }
  }

  # OWASP ModSecurity CRS rules
  dynamic "rule" {
    for_each = each.value.owasp_rules
    content {
      action      = rule.value.action
      priority    = rule.value.priority
      description = rule.value.description
      preview     = rule.value.preview != null ? rule.value.preview : false

      match {
        expr {
          expression = rule.value.expression
        }
      }

      dynamic "preconfigured_waf_config" {
        for_each = rule.value.preconfigured_waf_config != null ? [1] : []
        content {
          dynamic "exclusion" {
            for_each = rule.value.preconfigured_waf_config.exclusions != null ? rule.value.preconfigured_waf_config.exclusions : []
            content {
              target_rule_set = exclusion.value.target_rule_set
              target_rule_ids = exclusion.value.target_rule_ids

              dynamic "request_header" {
                for_each = exclusion.value.request_headers != null ? exclusion.value.request_headers : []
                content {
                  operator = request_header.value.operator
                  value    = request_header.value.value
                }
              }

              dynamic "request_cookie" {
                for_each = exclusion.value.request_cookies != null ? exclusion.value.request_cookies : []
                content {
                  operator = request_cookie.value.operator
                  value    = request_cookie.value.value
                }
              }

              dynamic "request_uri" {
                for_each = exclusion.value.request_uris != null ? exclusion.value.request_uris : []
                content {
                  operator = request_uri.value.operator
                  value    = request_uri.value.value
                }
              }

              dynamic "request_query_param" {
                for_each = exclusion.value.request_query_params != null ? exclusion.value.request_query_params : []
                content {
                  operator = request_query_param.value.operator
                  value    = request_query_param.value.value
                }
              }
            }
          }
        }
      }
    }
  }

  # Bot management rules
  dynamic "rule" {
    for_each = each.value.bot_management_rules
    content {
      action      = rule.value.action
      priority    = rule.value.priority
      description = rule.value.description
      preview     = rule.value.preview != null ? rule.value.preview : false

      match {
        expr {
          expression = rule.value.expression
        }
      }
    }
  }

  # Adaptive protection configuration
  dynamic "adaptive_protection_config" {
    for_each = each.value.adaptive_protection_config.layer_7_ddos_defense_config.enable ? [1] : []
    content {
      layer_7_ddos_defense_config {
        enable          = each.value.adaptive_protection_config.layer_7_ddos_defense_config.enable
        rule_visibility = each.value.adaptive_protection_config.layer_7_ddos_defense_config.rule_visibility

        dynamic "threshold_config" {
          for_each = each.value.adaptive_protection_config.layer_7_ddos_defense_config.threshold_configs
          content {
            name                     = threshold_config.value.name
            threshold_config_type    = threshold_config.value.threshold_config_type
            auto_deploy_load_threshold = threshold_config.value.auto_deploy_load_threshold
            auto_deploy_confidence_threshold = threshold_config.value.auto_deploy_confidence_threshold
            auto_deploy_impacted_baseline_threshold = threshold_config.value.auto_deploy_impacted_baseline_threshold
            auto_deploy_expiration_sec = threshold_config.value.auto_deploy_expiration_sec
          }
        }
      }

      auto_deploy_config {
        load_threshold              = each.value.adaptive_protection_config.auto_deploy_config.load_threshold
        confidence_threshold        = each.value.adaptive_protection_config.auto_deploy_config.confidence_threshold
        impacted_baseline_threshold = each.value.adaptive_protection_config.auto_deploy_config.impacted_baseline_threshold
        expiration_sec             = each.value.adaptive_protection_config.auto_deploy_config.expiration_sec
      }
    }
  }

  # Advanced options
  dynamic "advanced_options_config" {
    for_each = [1]
    content {
      json_parsing = each.value.advanced_options_config.json_parsing
      log_level    = each.value.advanced_options_config.log_level
      user_ip_request_headers = each.value.advanced_options_config.user_ip_request_headers

      dynamic "json_custom_config" {
        for_each = length(each.value.advanced_options_config.json_custom_config.content_types) > 0 ? [1] : []
        content {
          content_types = each.value.advanced_options_config.json_custom_config.content_types
        }
      }
    }
  }

  depends_on = [google_project_service.apis]
}

# Edge Security Policies
resource "google_compute_security_policy" "edge_security_policies" {
  for_each = local.edge_security_policies

  project = var.project_id
  name    = each.value.name

  description = each.value.description
  type        = each.value.type

  # Default rule
  rule {
    action      = each.value.default_rule.action
    priority    = each.value.default_rule.priority
    description = each.value.default_rule.description

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }

  # Edge rules
  dynamic "rule" {
    for_each = each.value.rules
    content {
      action      = rule.value.action
      priority    = rule.value.priority
      description = rule.value.description

      match {
        expr {
          expression = rule.value.expression
        }
      }
    }
  }

  depends_on = [google_project_service.apis]
}

# Security Policy Attachments to Backend Services
resource "google_compute_backend_service" "backend_service_with_security_policy" {
  for_each = local.policy_attachments

  project = var.project_id
  name    = "${each.key}-with-security-policy"

  # Copy configuration from existing backend service and add security policy
  description           = "Backend service with Cloud Armor security policy"
  protocol             = "HTTP"
  timeout_sec          = 30
  enable_cdn           = false
  load_balancing_scheme = "EXTERNAL"

  security_policy = google_compute_security_policy.security_policies[each.value.security_policy].id

  depends_on = [google_compute_security_policy.security_policies]
}

# WAF exclusions for specific applications
resource "google_compute_security_policy" "waf_exclusions" {
  for_each = var.waf_exclusion_policies

  project = var.project_id
  name    = "${local.name_prefix}-waf-exclusions-${each.key}-${local.environment}"

  description = "WAF exclusions policy for ${each.key}"
  type        = "CLOUD_ARMOR"

  # Default rule
  rule {
    action   = "allow"
    priority = 2147483647

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }

  # WAF rule with exclusions
  dynamic "rule" {
    for_each = each.value.waf_rules
    content {
      action      = rule.value.action
      priority    = rule.value.priority
      description = rule.value.description

      match {
        expr {
          expression = rule.value.expression
        }
      }

      preconfigured_waf_config {
        dynamic "exclusion" {
          for_each = rule.value.exclusions
          content {
            target_rule_set = exclusion.value.target_rule_set
            target_rule_ids = exclusion.value.target_rule_ids

            dynamic "request_header" {
              for_each = exclusion.value.request_headers != null ? exclusion.value.request_headers : []
              content {
                operator = request_header.value.operator
                value    = request_header.value.value
              }
            }

            dynamic "request_cookie" {
              for_each = exclusion.value.request_cookies != null ? exclusion.value.request_cookies : []
              content {
                operator = request_cookie.value.operator
                value    = request_cookie.value.value
              }
            }

            dynamic "request_uri" {
              for_each = exclusion.value.request_uris != null ? exclusion.value.request_uris : []
              content {
                operator = request_uri.value.operator
                value    = request_uri.value.value
              }
            }

            dynamic "request_query_param" {
              for_each = exclusion.value.request_query_params != null ? exclusion.value.request_query_params : []
              content {
                operator = request_query_param.value.operator
                value    = request_query_param.value.value
              }
            }
          }
        }
      }
    }
  }

  depends_on = [google_project_service.apis]
}

# Monitoring alert policies for Cloud Armor
resource "google_monitoring_alert_policy" "armor_alerts" {
  for_each = var.create_monitoring_alerts ? var.monitoring_alerts : {}

  project      = var.project_id
  display_name = each.value.display_name
  enabled      = each.value.enabled != null ? each.value.enabled : true
  combiner     = each.value.combiner != null ? each.value.combiner : "OR"

  conditions {
    display_name = each.value.condition_display_name

    condition_threshold {
      filter         = each.value.filter
      duration       = each.value.duration != null ? each.value.duration : "300s"
      comparison     = each.value.comparison != null ? each.value.comparison : "COMPARISON_GREATER_THAN"
      threshold_value = each.value.threshold_value

      aggregations {
        alignment_period     = each.value.alignment_period != null ? each.value.alignment_period : "300s"
        per_series_aligner   = each.value.per_series_aligner != null ? each.value.per_series_aligner : "ALIGN_RATE"
        cross_series_reducer = each.value.cross_series_reducer != null ? each.value.cross_series_reducer : "REDUCE_SUM"
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

  dynamic "notification_channels" {
    for_each = each.value.notification_channels != null ? [1] : []
    content {
      notification_channels = each.value.notification_channels
    }
  }

  auto_close = each.value.auto_close != null ? each.value.auto_close : "86400s"

  dynamic "alert_strategy" {
    for_each = each.value.rate_limit != null ? [1] : []
    content {
      notification_rate_limit {
        period = each.value.rate_limit.period
      }
    }
  }

  dynamic "documentation" {
    for_each = each.value.documentation_content != null ? [1] : []
    content {
      content   = each.value.documentation_content
      mime_type = each.value.documentation_mime_type != null ? each.value.documentation_mime_type : "text/markdown"
      subject   = each.value.documentation_subject
    }
  }

  user_labels = merge(local.default_labels, each.value.labels != null ? each.value.labels : {})
}

# Monitoring dashboard for Cloud Armor
resource "google_monitoring_dashboard" "armor" {
  count = var.create_monitoring_dashboard ? 1 : 0

  project        = var.project_id
  dashboard_json = jsonencode({
    displayName = "Cloud Armor - ${title(local.environment)}"
    mosaicLayout = {
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Security Policy Requests"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"https_lb_rule\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"loadbalancing.googleapis.com/https/request_count\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.labels.matched_rule_priority"]
                    }
                  }
                }
                plotType = "STACKED_AREA"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          widget = {
            title = "Blocked vs Allowed Requests"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"https_lb_rule\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"loadbalancing.googleapis.com/https/request_count\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.labels.security_policy_rule_action"]
                    }
                  }
                }
                plotType = "STACKED_BAR"
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          yPos   = 4
          widget = {
            title = "Rate Limiting Effectiveness"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"https_lb_rule\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"loadbalancing.googleapis.com/https/request_count\" metric.labels.security_policy_rule_action=\"rate_based_ban\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
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
            title = "Geographic Attack Sources"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"https_lb_rule\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"loadbalancing.googleapis.com/https/request_count\" metric.labels.security_policy_rule_action=\"deny\""
                    aggregation = {
                      alignmentPeriod    = "300s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.labels.country"]
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

# Log-based metrics for security events
resource "google_logging_metric" "security_metrics" {
  for_each = var.create_log_metrics ? var.log_metrics : {}

  project = var.project_id
  name    = each.key
  filter  = each.value.filter

  dynamic "label_extractors" {
    for_each = each.value.label_extractors != null ? each.value.label_extractors : {}
    content {
      key   = label_extractors.key
      value = label_extractors.value
    }
  }

  dynamic "metric_descriptor" {
    for_each = each.value.metric_descriptor != null ? [1] : []
    content {
      metric_kind = each.value.metric_descriptor.metric_kind
      value_type  = each.value.metric_descriptor.value_type
      unit        = each.value.metric_descriptor.unit
      display_name = each.value.metric_descriptor.display_name

      dynamic "labels" {
        for_each = each.value.metric_descriptor.labels != null ? each.value.metric_descriptor.labels : []
        content {
          key         = labels.value.key
          value_type  = labels.value.value_type
          description = labels.value.description
        }
      }
    }
  }

  dynamic "bucket_options" {
    for_each = each.value.bucket_options != null ? [1] : []
    content {
      dynamic "linear_buckets" {
        for_each = each.value.bucket_options.linear_buckets != null ? [1] : []
        content {
          num_finite_buckets = each.value.bucket_options.linear_buckets.num_finite_buckets
          width              = each.value.bucket_options.linear_buckets.width
          offset             = each.value.bucket_options.linear_buckets.offset
        }
      }

      dynamic "exponential_buckets" {
        for_each = each.value.bucket_options.exponential_buckets != null ? [1] : []
        content {
          num_finite_buckets = each.value.bucket_options.exponential_buckets.num_finite_buckets
          growth_factor      = each.value.bucket_options.exponential_buckets.growth_factor
          scale              = each.value.bucket_options.exponential_buckets.scale
        }
      }
    }
  }
}

# Notification channels for security alerts
resource "google_monitoring_notification_channel" "security_notifications" {
  for_each = var.notification_channels

  project      = var.project_id
  display_name = each.value.display_name
  type         = each.value.type
  labels       = each.value.labels
  description  = each.value.description
  enabled      = each.value.enabled

  user_labels = merge(local.default_labels, {
    purpose = "security-notifications"
  })
}

# Cloud Function for automated response to security events
resource "google_cloudfunctions_function" "security_response" {
  for_each = var.create_security_response_functions ? var.security_response_functions : {}

  project = var.project_id
  region  = var.region
  name    = "${local.name_prefix}-${each.key}-response-${local.environment}"

  runtime     = each.value.runtime
  entry_point = each.value.entry_point
  source_archive_bucket = each.value.source_bucket
  source_archive_object = each.value.source_object

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = each.value.trigger_topic
  }

  environment_variables = merge(
    each.value.environment_variables,
    {
      PROJECT_ID = var.project_id
      ENVIRONMENT = local.environment
    }
  )

  available_memory_mb = each.value.memory_mb
  timeout            = each.value.timeout_seconds

  labels = merge(local.default_labels, each.value.labels != null ? each.value.labels : {})

  depends_on = [google_compute_security_policy.security_policies]
}