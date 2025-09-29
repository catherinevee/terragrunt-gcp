# Cloud CDN Module
# Provides comprehensive Cloud CDN configuration with backend services, caching policies, and monitoring

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
  name_prefix = var.name_prefix != null ? var.name_prefix : "cdn"
  environment = var.environment != null ? var.environment : "dev"

  # Common labels to apply to all resources
  default_labels = merge(var.labels, {
    module      = "cloud-cdn"
    environment = local.environment
    managed_by  = "terraform"
  })

  # Backend service configurations with defaults
  backend_services = {
    for name, config in var.backend_services : name => merge({
      name                            = "${local.name_prefix}-${name}-${local.environment}"
      description                     = "Backend service for ${name}"
      protocol                        = "HTTP"
      port_name                       = "http"
      timeout_sec                     = 30
      enable_cdn                      = true
      connection_draining_timeout_sec = 300
      load_balancing_scheme           = "EXTERNAL"
      locality_lb_policy              = "ROUND_ROBIN"
      session_affinity                = "NONE"
      affinity_cookie_ttl_sec         = null

      # CDN policy with comprehensive defaults
      cdn_policy = {
        cache_mode                   = "CACHE_ALL_STATIC"
        default_ttl                  = 3600
        client_ttl                   = 3600
        max_ttl                      = 86400
        negative_caching             = true
        negative_caching_policy      = []
        serve_while_stale            = 86400
        signed_url_cache_max_age_sec = 0

        cache_key_policy = {
          include_protocol       = false
          include_host           = true
          include_query_string   = false
          query_string_whitelist = []
          query_string_blacklist = []
          include_http_headers   = []
          include_named_cookies  = []
        }

        bypass_cache_on_request_headers = []
      }

      # Health checks
      health_checks = []

      # Backend configuration
      backends = []

      # Circuit breaker configuration
      circuit_breakers = null

      # Consistent hash configuration
      consistent_hash = null

      # IAP configuration
      iap_config = null

      # Security policy
      security_policy = null

      # Custom headers
      custom_request_headers  = []
      custom_response_headers = []

      # Outlier detection
      outlier_detection = null

      # Log configuration
      log_config = {
        enable      = true
        sample_rate = 1.0
      }
    }, config)
  }

  # URL map configurations with defaults
  url_maps = {
    for name, config in var.url_maps : name => merge({
      name            = "${local.name_prefix}-${name}-${local.environment}"
      description     = "URL map for ${name}"
      default_service = null

      # Host rules
      host_rules = []

      # Path matchers
      path_matchers = []

      # Tests
      tests = []

      # Default URL redirect
      default_url_redirect = null

      # Default route action
      default_route_action = null

      # Header action
      header_action = null
    }, config)
  }

  # Global forwarding rule configurations
  global_forwarding_rules = {
    for name, config in var.global_forwarding_rules : name => merge({
      name                  = "${local.name_prefix}-${name}-${local.environment}"
      description           = "Global forwarding rule for ${name}"
      port_range            = "80"
      ip_protocol           = "TCP"
      ip_address            = null
      target                = null
      load_balancing_scheme = "EXTERNAL"
      network_tier          = "PREMIUM"
      labels                = {}
    }, config)
  }

  # SSL certificate configurations
  ssl_certificates = {
    for name, config in var.ssl_certificates : name => merge({
      name        = "${local.name_prefix}-${name}-${local.environment}"
      description = "SSL certificate for ${name}"
      certificate = null
      private_key = null
      managed = {
        domains = []
      }
      self_managed = null
    }, config)
  }

  # Target HTTPS proxy configurations
  target_https_proxies = {
    for name, config in var.target_https_proxies : name => merge({
      name                        = "${local.name_prefix}-${name}-${local.environment}"
      description                 = "HTTPS proxy for ${name}"
      url_map                     = null
      ssl_certificates            = []
      ssl_policy                  = null
      quic_override               = "NONE"
      http_keep_alive_timeout_sec = null
    }, config)
  }

  # Cloud Armor security policy configurations
  security_policies = {
    for name, config in var.security_policies : name => merge({
      name        = "${local.name_prefix}-${name}-${local.environment}"
      description = "Security policy for ${name}"
      type        = "CLOUD_ARMOR"

      # Default rule
      default_rule = {
        action   = "allow"
        priority = 2147483647
        match = {
          versioned_expr = "SRC_IPS_V1"
          config = {
            src_ip_ranges = ["*"]
          }
        }
        description = "Default allow rule"
      }

      # Additional rules
      rules = []

      # Rate limiting
      rate_limit_threshold = null

      # Adaptive protection
      adaptive_protection_config = null
    }, config)
  }

  # Origin configurations for backend services
  origins = {
    for name, config in var.origins : name => merge({
      name        = "${local.name_prefix}-${name}-${local.environment}"
      description = "Origin for ${name}"
      address     = config.address
      port        = 80
      protocol    = "HTTP"

      # Health check configuration
      health_check = {
        type                = "HTTP"
        port                = 80
        request_path        = "/"
        check_interval_sec  = 10
        timeout_sec         = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }

      # Backend service configuration
      backend_config = {
        max_rate_per_instance        = null
        max_rate                     = null
        max_connections              = null
        max_connections_per_instance = null
        max_utilization              = 0.8
        capacity_scaler              = 1.0
        balancing_mode               = "UTILIZATION"
      }
    }, config)
  }
}

# Data sources
data "google_project" "current" {
  project_id = var.project_id
}

data "google_compute_zones" "available" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "certificatemanager.googleapis.com"
  ])

  project = var.project_id
  service = each.key

  disable_dependent_services = false
  disable_on_destroy         = false
}

# Service account for CDN operations
resource "google_service_account" "cdn" {
  count = var.create_service_account ? 1 : 0

  project      = var.project_id
  account_id   = var.service_account_name != null ? var.service_account_name : "${local.name_prefix}-${local.environment}"
  display_name = "Cloud CDN Service Account for ${title(local.environment)}"
  description  = "Service account for Cloud CDN operations in ${local.environment} environment"
}

# IAM role bindings for service account
resource "google_project_iam_member" "cdn_roles" {
  for_each = var.create_service_account && var.grant_service_account_roles ? toset(var.service_account_roles) : toset([])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.cdn[0].email}"

  depends_on = [google_service_account.cdn]
}

# Health checks for backend services
resource "google_compute_health_check" "health_checks" {
  for_each = local.origins

  project = var.project_id
  name    = "${each.value.name}-health-check"

  description         = "Health check for ${each.key} origin"
  check_interval_sec  = each.value.health_check.check_interval_sec
  timeout_sec         = each.value.health_check.timeout_sec
  healthy_threshold   = each.value.health_check.healthy_threshold
  unhealthy_threshold = each.value.health_check.unhealthy_threshold

  dynamic "http_health_check" {
    for_each = each.value.health_check.type == "HTTP" ? [1] : []
    content {
      port               = each.value.health_check.port
      request_path       = each.value.health_check.request_path
      response           = each.value.health_check.response != null ? each.value.health_check.response : null
      proxy_header       = each.value.health_check.proxy_header != null ? each.value.health_check.proxy_header : "NONE"
      port_specification = each.value.health_check.port_specification != null ? each.value.health_check.port_specification : "USE_FIXED_PORT"
    }
  }

  dynamic "https_health_check" {
    for_each = each.value.health_check.type == "HTTPS" ? [1] : []
    content {
      port               = each.value.health_check.port
      request_path       = each.value.health_check.request_path
      response           = each.value.health_check.response != null ? each.value.health_check.response : null
      proxy_header       = each.value.health_check.proxy_header != null ? each.value.health_check.proxy_header : "NONE"
      port_specification = each.value.health_check.port_specification != null ? each.value.health_check.port_specification : "USE_FIXED_PORT"
    }
  }

  dynamic "tcp_health_check" {
    for_each = each.value.health_check.type == "TCP" ? [1] : []
    content {
      port               = each.value.health_check.port
      request            = each.value.health_check.request != null ? each.value.health_check.request : null
      response           = each.value.health_check.response != null ? each.value.health_check.response : null
      proxy_header       = each.value.health_check.proxy_header != null ? each.value.health_check.proxy_header : "NONE"
      port_specification = each.value.health_check.port_specification != null ? each.value.health_check.port_specification : "USE_FIXED_PORT"
    }
  }

  depends_on = [google_project_service.apis]
}

# Instance groups for backend services
resource "google_compute_instance_group" "backend_groups" {
  for_each = var.create_instance_groups ? local.origins : {}

  project = var.project_id
  zone    = var.zone != null ? var.zone : data.google_compute_zones.available.names[0]
  name    = "${each.value.name}-group"

  description = "Instance group for ${each.key} backend"
  network     = var.network_self_link

  named_port {
    name = "http"
    port = each.value.port
  }

  dynamic "named_port" {
    for_each = each.value.protocol == "HTTPS" ? [1] : []
    content {
      name = "https"
      port = 443
    }
  }

  depends_on = [google_project_service.apis]
}

# Backend services with CDN enabled
resource "google_compute_backend_service" "backend_services" {
  for_each = local.backend_services

  project = var.project_id
  name    = each.value.name

  description                     = each.value.description
  protocol                        = each.value.protocol
  port_name                       = each.value.port_name
  timeout_sec                     = each.value.timeout_sec
  enable_cdn                      = each.value.enable_cdn
  connection_draining_timeout_sec = each.value.connection_draining_timeout_sec
  load_balancing_scheme           = each.value.load_balancing_scheme
  locality_lb_policy              = each.value.locality_lb_policy
  session_affinity                = each.value.session_affinity
  affinity_cookie_ttl_sec         = each.value.affinity_cookie_ttl_sec

  # Health checks
  health_checks = length(each.value.health_checks) > 0 ? each.value.health_checks : [
    for origin_name, origin in local.origins : google_compute_health_check.health_checks[origin_name].id
    if contains(keys(var.origins), origin_name)
  ]

  # Backend configuration
  dynamic "backend" {
    for_each = length(each.value.backends) > 0 ? each.value.backends : [
      for origin_name, origin in local.origins : {
        group                        = var.create_instance_groups ? google_compute_instance_group.backend_groups[origin_name].id : origin.address
        balancing_mode               = origin.backend_config.balancing_mode
        capacity_scaler              = origin.backend_config.capacity_scaler
        max_rate_per_instance        = origin.backend_config.max_rate_per_instance
        max_rate                     = origin.backend_config.max_rate
        max_connections              = origin.backend_config.max_connections
        max_connections_per_instance = origin.backend_config.max_connections_per_instance
        max_utilization              = origin.backend_config.max_utilization
        description                  = "Backend for ${origin_name}"
      }
      if contains(keys(var.origins), origin_name)
    ]
    content {
      group                        = backend.value.group
      balancing_mode               = backend.value.balancing_mode
      capacity_scaler              = backend.value.capacity_scaler
      description                  = backend.value.description
      max_connections              = backend.value.max_connections
      max_connections_per_instance = backend.value.max_connections_per_instance
      max_connections_per_endpoint = backend.value.max_connections_per_endpoint
      max_rate                     = backend.value.max_rate
      max_rate_per_instance        = backend.value.max_rate_per_instance
      max_rate_per_endpoint        = backend.value.max_rate_per_endpoint
      max_utilization              = backend.value.max_utilization
    }
  }

  # CDN policy
  dynamic "cdn_policy" {
    for_each = each.value.enable_cdn ? [1] : []
    content {
      cache_mode                   = each.value.cdn_policy.cache_mode
      default_ttl                  = each.value.cdn_policy.default_ttl
      client_ttl                   = each.value.cdn_policy.client_ttl
      max_ttl                      = each.value.cdn_policy.max_ttl
      negative_caching             = each.value.cdn_policy.negative_caching
      serve_while_stale            = each.value.cdn_policy.serve_while_stale
      signed_url_cache_max_age_sec = each.value.cdn_policy.signed_url_cache_max_age_sec

      dynamic "negative_caching_policy" {
        for_each = each.value.cdn_policy.negative_caching_policy
        content {
          code = negative_caching_policy.value.code
          ttl  = negative_caching_policy.value.ttl
        }
      }

      dynamic "cache_key_policy" {
        for_each = each.value.cdn_policy.cache_key_policy != null ? [1] : []
        content {
          include_protocol       = each.value.cdn_policy.cache_key_policy.include_protocol
          include_host           = each.value.cdn_policy.cache_key_policy.include_host
          include_query_string   = each.value.cdn_policy.cache_key_policy.include_query_string
          query_string_whitelist = each.value.cdn_policy.cache_key_policy.query_string_whitelist
          query_string_blacklist = each.value.cdn_policy.cache_key_policy.query_string_blacklist
          include_http_headers   = each.value.cdn_policy.cache_key_policy.include_http_headers
          include_named_cookies  = each.value.cdn_policy.cache_key_policy.include_named_cookies
        }
      }

      dynamic "bypass_cache_on_request_headers" {
        for_each = each.value.cdn_policy.bypass_cache_on_request_headers
        content {
          header_name = bypass_cache_on_request_headers.value.header_name
        }
      }
    }
  }

  # Circuit breaker configuration
  dynamic "circuit_breakers" {
    for_each = each.value.circuit_breakers != null ? [1] : []
    content {
      max_requests_per_connection = each.value.circuit_breakers.max_requests_per_connection
      max_connections             = each.value.circuit_breakers.max_connections
      max_pending_requests        = each.value.circuit_breakers.max_pending_requests
      max_requests                = each.value.circuit_breakers.max_requests
      max_retries                 = each.value.circuit_breakers.max_retries
    }
  }

  # Consistent hash configuration
  dynamic "consistent_hash" {
    for_each = each.value.consistent_hash != null ? [1] : []
    content {
      http_cookie_ttl_seconds = each.value.consistent_hash.http_cookie_ttl_seconds
      http_cookie_name        = each.value.consistent_hash.http_cookie_name
      http_cookie_path        = each.value.consistent_hash.http_cookie_path
      http_header_name        = each.value.consistent_hash.http_header_name
      minimum_ring_size       = each.value.consistent_hash.minimum_ring_size
    }
  }

  # IAP configuration
  dynamic "iap" {
    for_each = each.value.iap_config != null ? [1] : []
    content {
      oauth2_client_id     = each.value.iap_config.oauth2_client_id
      oauth2_client_secret = each.value.iap_config.oauth2_client_secret
    }
  }

  # Outlier detection
  dynamic "outlier_detection" {
    for_each = each.value.outlier_detection != null ? [1] : []
    content {
      consecutive_errors                    = each.value.outlier_detection.consecutive_errors
      consecutive_gateway_failure           = each.value.outlier_detection.consecutive_gateway_failure
      enforcing_consecutive_errors          = each.value.outlier_detection.enforcing_consecutive_errors
      enforcing_consecutive_gateway_failure = each.value.outlier_detection.enforcing_consecutive_gateway_failure
      enforcing_success_rate                = each.value.outlier_detection.enforcing_success_rate
      interval_seconds                      = each.value.outlier_detection.interval_seconds
      base_ejection_time_seconds            = each.value.outlier_detection.base_ejection_time_seconds
      max_ejection_percent                  = each.value.outlier_detection.max_ejection_percent
      split_external_local_origin_errors    = each.value.outlier_detection.split_external_local_origin_errors
      success_rate_minimum_hosts            = each.value.outlier_detection.success_rate_minimum_hosts
      success_rate_request_volume           = each.value.outlier_detection.success_rate_request_volume
      success_rate_stdev_factor             = each.value.outlier_detection.success_rate_stdev_factor
    }
  }

  # Log configuration
  dynamic "log_config" {
    for_each = each.value.log_config != null ? [1] : []
    content {
      enable      = each.value.log_config.enable
      sample_rate = each.value.log_config.sample_rate
    }
  }

  # Security policy
  security_policy = each.value.security_policy

  # Custom headers
  custom_request_headers  = each.value.custom_request_headers
  custom_response_headers = each.value.custom_response_headers

  depends_on = [
    google_compute_health_check.health_checks,
    google_compute_instance_group.backend_groups,
    google_project_service.apis
  ]
}

# Cloud Armor security policies
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

    match {
      versioned_expr = each.value.default_rule.match.versioned_expr
      config {
        src_ip_ranges = each.value.default_rule.match.config.src_ip_ranges
      }
    }
  }

  # Additional rules
  dynamic "rule" {
    for_each = each.value.rules
    content {
      action      = rule.value.action
      priority    = rule.value.priority
      description = rule.value.description

      dynamic "match" {
        for_each = rule.value.match != null ? [1] : []
        content {
          versioned_expr = rule.value.match.versioned_expr
          expr {
            expression = rule.value.match.expr.expression
          }
        }
      }

      dynamic "rate_limit_options" {
        for_each = rule.value.rate_limit_options != null ? [1] : []
        content {
          conform_action = rule.value.rate_limit_options.conform_action
          exceed_action  = rule.value.rate_limit_options.exceed_action

          dynamic "rate_limit_threshold" {
            for_each = rule.value.rate_limit_options.rate_limit_threshold != null ? [1] : []
            content {
              count        = rule.value.rate_limit_options.rate_limit_threshold.count
              interval_sec = rule.value.rate_limit_options.rate_limit_threshold.interval_sec
            }
          }
        }
      }
    }
  }

  # Adaptive protection
  dynamic "adaptive_protection_config" {
    for_each = each.value.adaptive_protection_config != null ? [1] : []
    content {
      layer_7_ddos_defense_config {
        enable          = each.value.adaptive_protection_config.layer_7_ddos_defense_config.enable
        rule_visibility = each.value.adaptive_protection_config.layer_7_ddos_defense_config.rule_visibility
      }
    }
  }

  depends_on = [google_project_service.apis]
}

# SSL certificates
resource "google_compute_managed_ssl_certificate" "ssl_certificates" {
  for_each = {
    for name, config in local.ssl_certificates : name => config
    if config.managed != null
  }

  project = var.project_id
  name    = each.value.name

  description = each.value.description

  managed {
    domains = each.value.managed.domains
  }

  depends_on = [google_project_service.apis]
}

# Self-managed SSL certificates
resource "google_compute_ssl_certificate" "self_managed_ssl_certificates" {
  for_each = {
    for name, config in local.ssl_certificates : name => config
    if config.self_managed != null
  }

  project = var.project_id
  name    = each.value.name

  description = each.value.description
  certificate = each.value.self_managed.certificate
  private_key = each.value.self_managed.private_key

  depends_on = [google_project_service.apis]
}

# URL maps
resource "google_compute_url_map" "url_maps" {
  for_each = local.url_maps

  project = var.project_id
  name    = each.value.name

  description     = each.value.description
  default_service = each.value.default_service

  # Host rules
  dynamic "host_rule" {
    for_each = each.value.host_rules
    content {
      hosts        = host_rule.value.hosts
      path_matcher = host_rule.value.path_matcher
      description  = host_rule.value.description
    }
  }

  # Path matchers
  dynamic "path_matcher" {
    for_each = each.value.path_matchers
    content {
      name            = path_matcher.value.name
      default_service = path_matcher.value.default_service
      description     = path_matcher.value.description

      dynamic "path_rule" {
        for_each = path_matcher.value.path_rules != null ? path_matcher.value.path_rules : []
        content {
          paths   = path_rule.value.paths
          service = path_rule.value.service

          dynamic "route_action" {
            for_each = path_rule.value.route_action != null ? [1] : []
            content {
              dynamic "url_rewrite" {
                for_each = path_rule.value.route_action.url_rewrite != null ? [1] : []
                content {
                  host_rewrite        = path_rule.value.route_action.url_rewrite.host_rewrite
                  path_prefix_rewrite = path_rule.value.route_action.url_rewrite.path_prefix_rewrite
                }
              }
            }
          }
        }
      }

      dynamic "default_url_redirect" {
        for_each = path_matcher.value.default_url_redirect != null ? [1] : []
        content {
          redirect_response_code = path_matcher.value.default_url_redirect.redirect_response_code
          strip_query            = path_matcher.value.default_url_redirect.strip_query
          host_redirect          = path_matcher.value.default_url_redirect.host_redirect
          path_redirect          = path_matcher.value.default_url_redirect.path_redirect
          prefix_redirect        = path_matcher.value.default_url_redirect.prefix_redirect
          https_redirect         = path_matcher.value.default_url_redirect.https_redirect
        }
      }
    }
  }

  # Default URL redirect
  dynamic "default_url_redirect" {
    for_each = each.value.default_url_redirect != null ? [1] : []
    content {
      redirect_response_code = each.value.default_url_redirect.redirect_response_code
      strip_query            = each.value.default_url_redirect.strip_query
      host_redirect          = each.value.default_url_redirect.host_redirect
      path_redirect          = each.value.default_url_redirect.path_redirect
      prefix_redirect        = each.value.default_url_redirect.prefix_redirect
      https_redirect         = each.value.default_url_redirect.https_redirect
    }
  }

  # Tests
  dynamic "test" {
    for_each = each.value.tests
    content {
      service     = test.value.service
      host        = test.value.host
      path        = test.value.path
      description = test.value.description
    }
  }

  depends_on = [google_compute_backend_service.backend_services]
}

# Target HTTPS proxies
resource "google_compute_target_https_proxy" "target_https_proxies" {
  for_each = local.target_https_proxies

  project = var.project_id
  name    = each.value.name

  description                 = each.value.description
  url_map                     = each.value.url_map
  ssl_certificates            = each.value.ssl_certificates
  ssl_policy                  = each.value.ssl_policy
  quic_override               = each.value.quic_override
  http_keep_alive_timeout_sec = each.value.http_keep_alive_timeout_sec

  depends_on = [
    google_compute_url_map.url_maps,
    google_compute_managed_ssl_certificate.ssl_certificates,
    google_compute_ssl_certificate.self_managed_ssl_certificates
  ]
}

# Global IP addresses
resource "google_compute_global_address" "global_ips" {
  for_each = var.create_global_ips ? local.global_forwarding_rules : {}

  project = var.project_id
  name    = "${each.value.name}-ip"

  description  = "Global IP for ${each.key}"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"

  depends_on = [google_project_service.apis]
}

# Global forwarding rules
resource "google_compute_global_forwarding_rule" "global_forwarding_rules" {
  for_each = local.global_forwarding_rules

  project = var.project_id
  name    = each.value.name

  description           = each.value.description
  port_range            = each.value.port_range
  ip_protocol           = each.value.ip_protocol
  ip_address            = each.value.ip_address != null ? each.value.ip_address : (var.create_global_ips ? google_compute_global_address.global_ips[each.key].address : null)
  target                = each.value.target
  load_balancing_scheme = each.value.load_balancing_scheme
  network_tier          = each.value.network_tier
  labels                = merge(local.default_labels, each.value.labels)

  depends_on = [
    google_compute_target_https_proxy.target_https_proxies,
    google_compute_global_address.global_ips
  ]
}

# Monitoring alert policies for CDN
resource "google_monitoring_alert_policy" "cdn_alerts" {
  for_each = var.create_monitoring_alerts ? var.monitoring_alerts : {}

  project      = var.project_id
  display_name = each.value.display_name
  enabled      = each.value.enabled != null ? each.value.enabled : true
  combiner     = each.value.combiner != null ? each.value.combiner : "OR"

  conditions {
    display_name = each.value.condition_display_name

    condition_threshold {
      filter          = each.value.filter
      duration        = each.value.duration != null ? each.value.duration : "300s"
      comparison      = each.value.comparison != null ? each.value.comparison : "COMPARISON_GREATER_THAN"
      threshold_value = each.value.threshold_value

      aggregations {
        alignment_period     = each.value.alignment_period != null ? each.value.alignment_period : "300s"
        per_series_aligner   = each.value.per_series_aligner != null ? each.value.per_series_aligner : "ALIGN_RATE"
        cross_series_reducer = each.value.cross_series_reducer != null ? each.value.cross_series_reducer : "REDUCE_MEAN"
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

# Monitoring dashboard for CDN
resource "google_monitoring_dashboard" "cdn" {
  count = var.create_monitoring_dashboard ? 1 : 0

  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "Cloud CDN - ${title(local.environment)}"
    mosaicLayout = {
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "CDN Cache Hit Rate"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"https_lb_rule\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"loadbalancing.googleapis.com/https/request_count\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.labels.cache_result"]
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
            title = "Total Request Count"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"https_lb_rule\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"loadbalancing.googleapis.com/https/request_count\""
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
          yPos   = 4
          widget = {
            title = "Response Latency"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"https_lb_rule\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"loadbalancing.googleapis.com/https/total_latencies\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_DELTA"
                      crossSeriesReducer = "REDUCE_PERCENTILE_95"
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
            title = "Backend Response Codes"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"backend_service\" resource.labels.project_id=\"${var.project_id}\" metric.type=\"loadbalancing.googleapis.com/https/backend_request_count\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.labels.response_code_class"]
                    }
                  }
                }
                plotType = "STACKED_BAR"
              }]
            }
          }
        }
      ]
    }
  })
}