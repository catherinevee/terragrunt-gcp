# VPN Module - Main Configuration
# Manages Cloud VPN gateways, tunnels, and site-to-site connectivity

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

# Local variables
locals {
  environment = var.environment != null ? var.environment : "dev"
  name_prefix = var.name_prefix != null ? var.name_prefix : "vpn"

  default_labels = merge(
    {
      environment = local.environment
      managed_by  = "terraform"
      module      = "vpn"
      created_at  = formatdate("YYYY-MM-DD", timestamp())
    },
    var.labels
  )

  # HA VPN gateway configurations
  ha_vpn_gateways = {
    for k, v in var.ha_vpn_gateways : k => merge(
      v,
      {
        name        = v.name != null ? v.name : "${local.name_prefix}-${k}-ha-gateway"
        description = v.description != null ? v.description : "HA VPN gateway for ${k}"
      }
    )
  }

  # Classic VPN gateway configurations
  classic_vpn_gateways = {
    for k, v in var.classic_vpn_gateways : k => merge(
      v,
      {
        name        = v.name != null ? v.name : "${local.name_prefix}-${k}-gateway"
        description = v.description != null ? v.description : "Classic VPN gateway for ${k}"
      }
    )
  }

  # External VPN gateway configurations
  external_vpn_gateways = {
    for k, v in var.external_vpn_gateways : k => merge(
      v,
      {
        name        = v.name != null ? v.name : "${local.name_prefix}-${k}-external-gateway"
        description = v.description != null ? v.description : "External VPN gateway for ${k}"
      }
    )
  }

  # VPN tunnel configurations
  vpn_tunnels = {
    for k, v in var.vpn_tunnels : k => merge(
      v,
      {
        name        = v.name != null ? v.name : "${local.name_prefix}-${k}-tunnel"
        description = v.description != null ? v.description : "VPN tunnel for ${k}"
      }
    )
  }

  # Router configurations
  routers = {
    for k, v in var.routers : k => merge(
      v,
      {
        name        = v.name != null ? v.name : "${local.name_prefix}-${k}-router"
        description = v.description != null ? v.description : "Cloud Router for ${k}"
      }
    )
  }

  # Router interfaces configurations
  router_interfaces = {
    for k, v in var.router_interfaces : k => merge(
      v,
      {
        name = v.name != null ? v.name : "${local.name_prefix}-${k}-interface"
      }
    )
  }

  # BGP peers configurations
  bgp_peers = {
    for k, v in var.bgp_peers : k => merge(
      v,
      {
        name = v.name != null ? v.name : "${local.name_prefix}-${k}-peer"
      }
    )
  }
}

# Enable required APIs
resource "google_project_service" "compute_api" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

# Service Account for VPN operations
resource "google_service_account" "vpn" {
  count = var.create_service_account ? 1 : 0

  account_id   = var.service_account_name != null ? var.service_account_name : "${local.name_prefix}-sa"
  display_name = "VPN Service Account"
  description  = "Service account for VPN operations"
  project      = var.project_id
}

# IAM roles for service account
resource "google_project_iam_member" "vpn_roles" {
  for_each = var.create_service_account && var.grant_service_account_roles ? toset(var.service_account_roles) : []

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.vpn[0].email}"

  depends_on = [google_service_account.vpn]
}

# Random IDs for shared secrets if not provided
resource "random_password" "vpn_shared_secrets" {
  for_each = {
    for k, v in local.vpn_tunnels : k => v
    if v.shared_secret == null && v.generate_shared_secret != false
  }

  length  = var.shared_secret_length != null ? var.shared_secret_length : 32
  special = true
  upper   = true
  lower   = true
  numeric = true
}

# HA VPN Gateways
resource "google_compute_ha_vpn_gateway" "ha_gateways" {
  for_each = local.ha_vpn_gateways

  name        = each.value.name
  description = each.value.description
  network     = each.value.network
  region      = each.value.region != null ? each.value.region : var.region
  project     = var.project_id

  stack_type = each.value.stack_type != null ? each.value.stack_type : "IPV4_ONLY"

  dynamic "vpn_interfaces" {
    for_each = each.value.vpn_interfaces != null ? each.value.vpn_interfaces : []

    content {
      id                      = vpn_interfaces.value.id
      interconnect_attachment = vpn_interfaces.value.interconnect_attachment
    }
  }

  depends_on = [google_project_service.compute_api]
}

# Classic VPN Gateways
resource "google_compute_vpn_gateway" "classic_gateways" {
  for_each = local.classic_vpn_gateways

  name        = each.value.name
  description = each.value.description
  network     = each.value.network
  region      = each.value.region != null ? each.value.region : var.region
  project     = var.project_id

  depends_on = [google_project_service.compute_api]
}

# External VPN Gateways
resource "google_compute_external_vpn_gateway" "external_gateways" {
  for_each = local.external_vpn_gateways

  name            = each.value.name
  description     = each.value.description
  redundancy_type = each.value.redundancy_type != null ? each.value.redundancy_type : "SINGLE_IP_INTERNALLY_REDUNDANT"
  project         = var.project_id

  dynamic "interface" {
    for_each = each.value.interfaces != null ? each.value.interfaces : []

    content {
      id                      = interface.value.id
      ip_address              = interface.value.ip_address
      ipv6_address            = interface.value.ipv6_address
      interconnect_attachment = interface.value.interconnect_attachment
    }
  }

  labels = merge(
    local.default_labels,
    each.value.labels != null ? each.value.labels : {}
  )

  depends_on = [google_project_service.compute_api]
}

# VPN Tunnels
resource "google_compute_vpn_tunnel" "vpn_tunnels" {
  for_each = local.vpn_tunnels

  name        = each.value.name
  description = each.value.description
  region      = each.value.region != null ? each.value.region : var.region
  project     = var.project_id

  # Gateway configuration
  vpn_gateway = each.value.vpn_gateway_key != null ? (
    each.value.vpn_gateway_type == "HA" ?
    google_compute_ha_vpn_gateway.ha_gateways[each.value.vpn_gateway_key].id :
    google_compute_vpn_gateway.classic_gateways[each.value.vpn_gateway_key].id
  ) : each.value.vpn_gateway

  peer_external_gateway = each.value.peer_external_gateway_key != null ? (
    google_compute_external_vpn_gateway.external_gateways[each.value.peer_external_gateway_key].id
  ) : each.value.peer_external_gateway

  peer_external_gateway_interface = each.value.peer_external_gateway_interface
  peer_gcp_gateway                = each.value.peer_gcp_gateway
  vpn_gateway_interface           = each.value.vpn_gateway_interface

  # Tunnel configuration
  shared_secret = each.value.shared_secret != null ? each.value.shared_secret : (
    each.value.generate_shared_secret != false ? random_password.vpn_shared_secrets[each.key].result : null
  )

  ike_version = each.value.ike_version != null ? each.value.ike_version : 2
  peer_ip     = each.value.peer_ip
  router = each.value.router_key != null ? (
    google_compute_router.routers[each.value.router_key].id
  ) : each.value.router

  # Traffic selectors
  local_traffic_selector  = each.value.local_traffic_selector
  remote_traffic_selector = each.value.remote_traffic_selector

  labels = merge(
    local.default_labels,
    each.value.labels != null ? each.value.labels : {}
  )

  depends_on = [
    google_compute_ha_vpn_gateway.ha_gateways,
    google_compute_vpn_gateway.classic_gateways,
    google_compute_external_vpn_gateway.external_gateways,
    google_compute_router.routers
  ]
}

# Cloud Routers
resource "google_compute_router" "routers" {
  for_each = local.routers

  name        = each.value.name
  description = each.value.description
  network     = each.value.network
  region      = each.value.region != null ? each.value.region : var.region
  project     = var.project_id

  dynamic "bgp" {
    for_each = each.value.bgp_config != null ? [each.value.bgp_config] : []

    content {
      asn                = bgp.value.asn
      advertise_mode     = bgp.value.advertise_mode
      advertised_groups  = bgp.value.advertised_groups
      keepalive_interval = bgp.value.keepalive_interval

      dynamic "advertised_ip_ranges" {
        for_each = bgp.value.advertised_ip_ranges != null ? bgp.value.advertised_ip_ranges : []

        content {
          range       = advertised_ip_ranges.value.range
          description = advertised_ip_ranges.value.description
        }
      }

      identifier_range = bgp.value.identifier_range
    }
  }

  encrypted_interconnect_router = each.value.encrypted_interconnect_router

  depends_on = [google_project_service.compute_api]
}

# Router Interfaces
resource "google_compute_router_interface" "interfaces" {
  for_each = local.router_interfaces

  name = each.value.name
  router = each.value.router_key != null ? (
    google_compute_router.routers[each.value.router_key].name
  ) : each.value.router
  region  = each.value.region != null ? each.value.region : var.region
  project = var.project_id

  ip_range = each.value.ip_range
  vpn_tunnel = each.value.vpn_tunnel_key != null ? (
    google_compute_vpn_tunnel.vpn_tunnels[each.value.vpn_tunnel_key].name
  ) : each.value.vpn_tunnel

  interconnect_attachment = each.value.interconnect_attachment
  subnetwork              = each.value.subnetwork
  private_ip_address      = each.value.private_ip_address
  redundant_interface     = each.value.redundant_interface

  depends_on = [
    google_compute_router.routers,
    google_compute_vpn_tunnel.vpn_tunnels
  ]
}

# BGP Peers
resource "google_compute_router_peer" "bgp_peers" {
  for_each = local.bgp_peers

  name = each.value.name
  router = each.value.router_key != null ? (
    google_compute_router.routers[each.value.router_key].name
  ) : each.value.router
  region  = each.value.region != null ? each.value.region : var.region
  project = var.project_id

  interface = each.value.interface_key != null ? (
    google_compute_router_interface.interfaces[each.value.interface_key].name
  ) : each.value.interface

  peer_ip_address           = each.value.peer_ip_address
  peer_asn                  = each.value.peer_asn
  advertised_route_priority = each.value.advertised_route_priority != null ? each.value.advertised_route_priority : 100
  advertise_mode            = each.value.advertise_mode
  advertised_groups         = each.value.advertised_groups

  dynamic "advertised_ip_ranges" {
    for_each = each.value.advertised_ip_ranges != null ? each.value.advertised_ip_ranges : []

    content {
      range       = advertised_ip_ranges.value.range
      description = advertised_ip_ranges.value.description
    }
  }

  dynamic "bfd" {
    for_each = each.value.bfd_config != null ? [each.value.bfd_config] : []

    content {
      min_receive_interval        = bfd.value.min_receive_interval
      min_transmit_interval       = bfd.value.min_transmit_interval
      multiplier                  = bfd.value.multiplier
      session_initialization_mode = bfd.value.session_initialization_mode
    }
  }

  enable                    = each.value.enable != null ? each.value.enable : true
  enable_ipv6               = each.value.enable_ipv6
  ipv6_nexthop_address      = each.value.ipv6_nexthop_address
  peer_ipv6_nexthop_address = each.value.peer_ipv6_nexthop_address
  router_appliance_instance = each.value.router_appliance_instance
  ip_address                = each.value.ip_address
  management_type           = each.value.management_type

  dynamic "md5_authentication_key" {
    for_each = each.value.md5_authentication_key != null ? [each.value.md5_authentication_key] : []

    content {
      name = md5_authentication_key.value.name
      key  = md5_authentication_key.value.key
    }
  }

  depends_on = [
    google_compute_router.routers,
    google_compute_router_interface.interfaces
  ]
}

# Static Routes for VPN
resource "google_compute_route" "vpn_routes" {
  for_each = var.static_routes

  name        = each.value.name != null ? each.value.name : "${local.name_prefix}-${each.key}-route"
  description = each.value.description
  network     = each.value.network
  dest_range  = each.value.dest_range
  next_hop_vpn_tunnel = each.value.next_hop_vpn_tunnel_key != null ? (
    google_compute_vpn_tunnel.vpn_tunnels[each.value.next_hop_vpn_tunnel_key].id
  ) : each.value.next_hop_vpn_tunnel
  priority = each.value.priority != null ? each.value.priority : 1000
  tags     = each.value.tags
  project  = var.project_id

  depends_on = [google_compute_vpn_tunnel.vpn_tunnels]
}

# Firewall Rules for VPN
resource "google_compute_firewall" "vpn_firewall_rules" {
  for_each = var.firewall_rules

  name        = each.value.name != null ? each.value.name : "${local.name_prefix}-${each.key}-fw"
  description = each.value.description
  network     = each.value.network
  project     = var.project_id

  priority                = each.value.priority != null ? each.value.priority : 1000
  direction               = each.value.direction != null ? each.value.direction : "INGRESS"
  source_ranges           = each.value.source_ranges
  destination_ranges      = each.value.destination_ranges
  source_tags             = each.value.source_tags
  target_tags             = each.value.target_tags
  source_service_accounts = each.value.source_service_accounts
  target_service_accounts = each.value.target_service_accounts

  dynamic "allow" {
    for_each = each.value.allow != null ? each.value.allow : []

    content {
      protocol = allow.value.protocol
      ports    = allow.value.ports
    }
  }

  dynamic "deny" {
    for_each = each.value.deny != null ? each.value.deny : []

    content {
      protocol = deny.value.protocol
      ports    = deny.value.ports
    }
  }

  dynamic "log_config" {
    for_each = each.value.enable_logging != false ? [1] : []

    content {
      metadata = each.value.log_metadata != null ? each.value.log_metadata : "INCLUDE_ALL_METADATA"
    }
  }

  disabled = each.value.disabled != null ? each.value.disabled : false

  depends_on = [google_project_service.compute_api]
}

# Reserved IP addresses for VPN
resource "google_compute_address" "vpn_gateway_ips" {
  for_each = var.reserved_ip_addresses

  name         = each.value.name != null ? each.value.name : "${local.name_prefix}-${each.key}-ip"
  description  = each.value.description
  address_type = "EXTERNAL"
  region       = each.value.region != null ? each.value.region : var.region
  project      = var.project_id

  network_tier = each.value.network_tier != null ? each.value.network_tier : "PREMIUM"
  purpose      = each.value.purpose
  labels       = merge(local.default_labels, each.value.labels != null ? each.value.labels : {})

  depends_on = [google_project_service.compute_api]
}

# Monitoring Alert Policies
resource "google_monitoring_alert_policy" "vpn_alerts" {
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
resource "google_monitoring_dashboard" "vpn_dashboard" {
  count = var.create_monitoring_dashboard ? 1 : 0

  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "${local.name_prefix}-vpn-dashboard"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "VPN Tunnel Status"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"vpn_gateway\" metric.type=\"vpn.googleapis.com/tunnel_established\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_NEXT_OLDER"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["resource.label.tunnel_name"]
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_BAR"
              }
            }
          }
        },
        {
          xPos   = 6
          width  = 6
          height = 4
          widget = {
            title = "VPN Throughput"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"vpn_gateway\" metric.type=\"vpn.googleapis.com/network/sent_bytes_count\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["resource.label.tunnel_name"]
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                },
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"vpn_gateway\" metric.type=\"vpn.googleapis.com/network/received_bytes_count\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["resource.label.tunnel_name"]
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y2"
                }
              ]
              yAxis = {
                label = "Sent (bytes/sec)"
                scale = "LINEAR"
              }
              y2Axis = {
                label = "Received (bytes/sec)"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "VPN Packet Loss"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"vpn_gateway\" metric.type=\"vpn.googleapis.com/network/dropped_received_packets_count\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.label.tunnel_name"]
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
            title = "VPN Latency"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"vpn_gateway\" metric.type=\"vpn.googleapis.com/tunnel/rtt\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_MEAN"
                      groupByFields      = ["resource.label.tunnel_name"]
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
          width  = 6
          height = 4
          widget = {
            title = "IKE Session Status"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"vpn_gateway\" metric.type=\"vpn.googleapis.com/ike_session_established\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_NEXT_OLDER"
                    crossSeriesReducer = "REDUCE_SUM"
                  }
                }
              }
              thresholds = [
                {
                  value     = 0.5
                  color     = "RED"
                  direction = "BELOW"
                },
                {
                  value     = 1
                  color     = "GREEN"
                  direction = "ABOVE"
                }
              ]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 8
          width  = 6
          height = 4
          widget = {
            title = "BGP Session Status"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"router\" metric.type=\"router.googleapis.com/bgp/session_up\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_NEXT_OLDER"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["resource.label.router_id"]
                  }
                }
              }
              thresholds = [
                {
                  value     = 0.5
                  color     = "YELLOW"
                  direction = "BELOW"
                },
                {
                  value     = 1
                  color     = "GREEN"
                  direction = "ABOVE"
                }
              ]
            }
          }
        }
      ]
    }
  })
}

# Log Metrics
resource "google_logging_metric" "vpn_metrics" {
  for_each = var.create_log_metrics ? var.log_metrics : {}

  name        = each.value.name != null ? each.value.name : "${local.name_prefix}-${each.key}-metric"
  description = each.value.description
  filter      = each.value.filter
  project     = var.project_id

  label_extractors = each.value.label_extractors

  dynamic "metric_descriptor" {
    for_each = each.value.metric_descriptor != null ? [each.value.metric_descriptor] : []

    content {
      metric_kind  = metric_descriptor.value.metric_kind
      value_type   = metric_descriptor.value.value_type
      unit         = metric_descriptor.value.unit
      display_name = metric_descriptor.value.display_name

      dynamic "labels" {
        for_each = metric_descriptor.value.labels != null ? metric_descriptor.value.labels : []

        content {
          key         = labels.value.key
          value_type  = labels.value.value_type
          description = labels.value.description
        }
      }
    }
  }

  value_extractor = each.value.value_extractor
}

# Secret Manager for VPN shared secrets
resource "google_secret_manager_secret" "vpn_secrets" {
  for_each = var.store_secrets_in_secret_manager ? {
    for k, v in local.vpn_tunnels : k => v
    if v.shared_secret != null || v.generate_shared_secret != false
  } : {}

  secret_id = "${local.name_prefix}-${each.key}-secret"
  project   = var.project_id

  labels = merge(
    local.default_labels,
    {
      tunnel = each.key
      type   = "vpn-shared-secret"
    }
  )

  replication {
    user_managed {
      dynamic "replicas" {
        for_each = var.secret_replication_regions != null ? var.secret_replication_regions : [var.region]

        content {
          location = replicas.value
        }
      }
    }
  }
}

# Secret Manager Secret Versions
resource "google_secret_manager_secret_version" "vpn_secret_versions" {
  for_each = google_secret_manager_secret.vpn_secrets

  secret = each.value.id

  secret_data = local.vpn_tunnels[each.key].shared_secret != null ? (
    local.vpn_tunnels[each.key].shared_secret
  ) : random_password.vpn_shared_secrets[each.key].result
}