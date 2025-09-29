# Cloud NAT Module - Main Configuration
# Manages Cloud NAT gateways for outbound internet connectivity

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
  name_prefix = var.name_prefix != null ? var.name_prefix : "nat"

  default_labels = merge(
    {
      environment = local.environment
      managed_by  = "terraform"
      module      = "cloud-nat"
      created_at  = formatdate("YYYY-MM-DD", timestamp())
    },
    var.labels
  )

  # NAT gateway configurations
  nat_gateways = {
    for k, v in var.nat_gateways : k => merge(
      v,
      {
        name        = v.name != null ? v.name : "${local.name_prefix}-${k}-gateway"
        router_name = v.router_name != null ? v.router_name : "${local.name_prefix}-${k}-router"
        region      = v.region != null ? v.region : var.region
      }
    )
  }

  # Cloud router configurations
  cloud_routers = {
    for k, v in var.cloud_routers : k => merge(
      v,
      {
        name        = v.name != null ? v.name : "${local.name_prefix}-${k}-router"
        description = v.description != null ? v.description : "Cloud Router for ${k}"
        region      = v.region != null ? v.region : var.region
      }
    )
  }

  # NAT IP addresses configurations
  nat_ips = {
    for k, v in var.nat_ip_addresses : k => merge(
      v,
      {
        name        = v.name != null ? v.name : "${local.name_prefix}-${k}-ip"
        description = v.description != null ? v.description : "NAT IP address for ${k}"
        region      = v.region != null ? v.region : var.region
      }
    )
  }

  # Router interfaces configurations
  router_interfaces = {
    for k, v in var.router_interfaces : k => merge(
      v,
      {
        name        = v.name != null ? v.name : "${local.name_prefix}-${k}-interface"
        description = v.description != null ? v.description : "Router interface for ${k}"
      }
    )
  }

  # BGP peers configurations
  bgp_peers = {
    for k, v in var.bgp_peers : k => merge(
      v,
      {
        name                  = v.name != null ? v.name : "${local.name_prefix}-${k}-peer"
        advertised_route_priority = v.advertised_route_priority != null ? v.advertised_route_priority : 100
      }
    )
  }
}

# Cloud Router
resource "google_compute_router" "routers" {
  for_each = local.cloud_routers

  name        = each.value.name
  description = each.value.description
  network     = each.value.network
  region      = each.value.region
  project     = var.project_id

  dynamic "bgp" {
    for_each = each.value.bgp_config != null ? [each.value.bgp_config] : []

    content {
      asn                   = bgp.value.asn
      advertise_mode        = bgp.value.advertise_mode
      advertised_groups     = bgp.value.advertised_groups
      keepalive_interval    = bgp.value.keepalive_interval

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
}

# Cloud NAT IP Addresses
resource "google_compute_address" "nat_ips" {
  for_each = local.nat_ips

  name         = each.value.name
  description  = each.value.description
  address_type = "EXTERNAL"
  region       = each.value.region
  project      = var.project_id

  network_tier = each.value.network_tier != null ? each.value.network_tier : "PREMIUM"
  purpose      = each.value.purpose
  labels       = merge(local.default_labels, each.value.labels != null ? each.value.labels : {})
}

# Cloud NAT Gateway
resource "google_compute_router_nat" "nat_gateways" {
  for_each = local.nat_gateways

  name                                = each.value.name
  router                              = each.value.create_router != false ? google_compute_router.routers[each.value.router_key].name : each.value.router_name
  region                              = each.value.region
  project                             = var.project_id

  # NAT IP configuration
  nat_ip_allocate_option = each.value.nat_ip_allocate_option != null ? each.value.nat_ip_allocate_option : "AUTO_ONLY"

  nat_ips = each.value.nat_ip_allocate_option == "MANUAL_ONLY" ? [
    for ip_key in each.value.nat_ip_keys != null ? each.value.nat_ip_keys : [] :
    google_compute_address.nat_ips[ip_key].self_link
  ] : null

  drain_nat_ips = each.value.drain_nat_ips

  # Source subnet configuration
  source_subnetwork_ip_ranges_to_nat = each.value.source_subnetwork_ip_ranges_to_nat != null ? each.value.source_subnetwork_ip_ranges_to_nat : "ALL_SUBNETWORKS_ALL_IP_RANGES"

  dynamic "subnetwork" {
    for_each = each.value.source_subnetwork_ip_ranges_to_nat == "LIST_OF_SUBNETWORKS" ? each.value.subnetworks != null ? each.value.subnetworks : [] : []

    content {
      name                    = subnetwork.value.name
      source_ip_ranges_to_nat = subnetwork.value.source_ip_ranges_to_nat != null ? subnetwork.value.source_ip_ranges_to_nat : ["ALL_IP_RANGES"]
      secondary_ip_range_names = subnetwork.value.secondary_ip_range_names
    }
  }

  # Port allocation configuration
  min_ports_per_vm                    = each.value.min_ports_per_vm != null ? each.value.min_ports_per_vm : 64
  max_ports_per_vm                    = each.value.max_ports_per_vm
  enable_dynamic_port_allocation      = each.value.enable_dynamic_port_allocation
  enable_endpoint_independent_mapping = each.value.enable_endpoint_independent_mapping != null ? each.value.enable_endpoint_independent_mapping : true

  # Timeout configuration
  icmp_idle_timeout_sec              = each.value.icmp_idle_timeout_sec != null ? each.value.icmp_idle_timeout_sec : 30
  tcp_established_idle_timeout_sec   = each.value.tcp_established_idle_timeout_sec != null ? each.value.tcp_established_idle_timeout_sec : 1200
  tcp_transitory_idle_timeout_sec    = each.value.tcp_transitory_idle_timeout_sec != null ? each.value.tcp_transitory_idle_timeout_sec : 30
  tcp_time_wait_timeout_sec          = each.value.tcp_time_wait_timeout_sec != null ? each.value.tcp_time_wait_timeout_sec : 120
  udp_idle_timeout_sec               = each.value.udp_idle_timeout_sec != null ? each.value.udp_idle_timeout_sec : 30

  # Logging configuration
  dynamic "log_config" {
    for_each = each.value.enable_logging != false ? [1] : []

    content {
      enable = true
      filter = each.value.log_filter != null ? each.value.log_filter : "ALL"
    }
  }

  # Rules configuration
  dynamic "rules" {
    for_each = each.value.rules != null ? each.value.rules : []

    content {
      rule_number = rules.value.rule_number
      description = rules.value.description
      match       = rules.value.match

      dynamic "action" {
        for_each = rules.value.action != null ? [rules.value.action] : []

        content {
          source_nat_active_ips = action.value.source_nat_active_ips != null ? [
            for ip_key in action.value.source_nat_active_ip_keys :
            google_compute_address.nat_ips[ip_key].self_link
          ] : null

          source_nat_drain_ips = action.value.source_nat_drain_ips != null ? [
            for ip_key in action.value.source_nat_drain_ip_keys :
            google_compute_address.nat_ips[ip_key].self_link
          ] : null

          source_nat_active_ranges = action.value.source_nat_active_ranges
          source_nat_drain_ranges  = action.value.source_nat_drain_ranges
        }
      }
    }
  }

  depends_on = [
    google_compute_router.routers,
    google_compute_address.nat_ips
  ]
}

# Router Interface (for VPN/Interconnect connectivity)
resource "google_compute_router_interface" "interfaces" {
  for_each = local.router_interfaces

  name                   = each.value.name
  router                 = each.value.router_name
  region                 = each.value.region != null ? each.value.region : var.region
  project                = var.project_id

  ip_range                          = each.value.ip_range
  vpn_tunnel                        = each.value.vpn_tunnel
  interconnect_attachment           = each.value.interconnect_attachment
  subnetwork                        = each.value.subnetwork
  private_ip_address                = each.value.private_ip_address
  redundant_interface               = each.value.redundant_interface
}

# BGP Peers for Cloud Router
resource "google_compute_router_peer" "bgp_peers" {
  for_each = local.bgp_peers

  name                      = each.value.name
  router                    = each.value.router_name
  region                    = each.value.region != null ? each.value.region : var.region
  project                   = var.project_id

  interface                 = each.value.interface_name
  peer_ip_address          = each.value.peer_ip_address
  peer_asn                 = each.value.peer_asn
  advertised_route_priority = each.value.advertised_route_priority
  advertise_mode           = each.value.advertise_mode
  advertised_groups        = each.value.advertised_groups

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

  enable                   = each.value.enable != null ? each.value.enable : true
  enable_ipv6             = each.value.enable_ipv6
  ipv6_nexthop_address    = each.value.ipv6_nexthop_address
  peer_ipv6_nexthop_address = each.value.peer_ipv6_nexthop_address
  router_appliance_instance = each.value.router_appliance_instance

  depends_on = [
    google_compute_router.routers,
    google_compute_router_interface.interfaces
  ]
}

# Route advertisements for specific prefixes
resource "google_compute_route" "custom_routes" {
  for_each = var.custom_routes

  name                   = each.value.name != null ? each.value.name : "${local.name_prefix}-${each.key}-route"
  description           = each.value.description
  dest_range            = each.value.dest_range
  network               = each.value.network
  next_hop_gateway      = each.value.next_hop_gateway
  next_hop_instance     = each.value.next_hop_instance
  next_hop_ip           = each.value.next_hop_ip
  next_hop_vpn_tunnel   = each.value.next_hop_vpn_tunnel
  next_hop_ilb          = each.value.next_hop_ilb
  priority              = each.value.priority != null ? each.value.priority : 1000
  tags                  = each.value.tags
  project               = var.project_id
}

# Firewall rules for NAT
resource "google_compute_firewall" "nat_firewall_rules" {
  for_each = var.firewall_rules

  name        = each.value.name != null ? each.value.name : "${local.name_prefix}-${each.key}-fw"
  description = each.value.description
  network     = each.value.network
  project     = var.project_id

  priority         = each.value.priority != null ? each.value.priority : 1000
  direction        = each.value.direction != null ? each.value.direction : "INGRESS"
  source_ranges    = each.value.source_ranges
  destination_ranges = each.value.destination_ranges
  source_tags      = each.value.source_tags
  target_tags      = each.value.target_tags
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
}

# Service Account for NAT operations
resource "google_service_account" "nat" {
  count = var.create_service_account ? 1 : 0

  account_id   = var.service_account_name != null ? var.service_account_name : "${local.name_prefix}-sa"
  display_name = "Cloud NAT Service Account"
  description  = "Service account for Cloud NAT operations"
  project      = var.project_id
}

# IAM roles for service account
resource "google_project_iam_member" "nat_roles" {
  for_each = var.create_service_account && var.grant_service_account_roles ? toset(var.service_account_roles) : []

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.nat[0].email}"

  depends_on = [google_service_account.nat]
}

# Monitoring Alert Policies
resource "google_monitoring_alert_policy" "nat_alerts" {
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
resource "google_monitoring_dashboard" "nat_dashboard" {
  count = var.create_monitoring_dashboard ? 1 : 0

  project        = var.project_id
  dashboard_json = jsonencode({
    displayName = "${local.name_prefix}-cloud-nat-dashboard"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "NAT Gateway Allocated Ports"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"nat_gateway\" metric.type=\"router.googleapis.com/nat/allocated_ports\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_MEAN"
                      groupByFields      = ["resource.label.gateway_name"]
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
            title = "NAT Gateway Dropped Packets"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"nat_gateway\" metric.type=\"router.googleapis.com/nat/dropped_sent_packets_count\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.label.gateway_name"]
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
            title = "NAT Port Utilization"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"nat_gateway\" metric.type=\"router.googleapis.com/nat/port_usage\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_MEAN"
                      groupByFields      = ["resource.label.gateway_name"]
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
            title = "NAT Connection Count"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"nat_gateway\" metric.type=\"router.googleapis.com/nat/open_connections\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.label.gateway_name"]
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
            title = "NAT Bandwidth Usage"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"nat_gateway\" metric.type=\"router.googleapis.com/nat/sent_bytes_count\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["resource.label.gateway_name"]
                      }
                    }
                  }
                  plotType = "LINE"
                  targetAxis = "Y1"
                },
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"nat_gateway\" metric.type=\"router.googleapis.com/nat/received_bytes_count\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["resource.label.gateway_name"]
                      }
                    }
                  }
                  plotType = "LINE"
                  targetAxis = "Y2"
                }
              ]
              yAxis = {
                label = "Sent Bytes/sec"
                scale = "LINEAR"
              }
              y2Axis = {
                label = "Received Bytes/sec"
                scale = "LINEAR"
              }
            }
          }
        }
      ]
    }
  })
}

# Log Sink for NAT logs
resource "google_logging_project_sink" "nat_logs" {
  count = var.enable_log_export ? 1 : 0

  name        = "${local.name_prefix}-nat-logs-sink"
  destination = var.log_export_destination
  project     = var.project_id

  filter = var.log_export_filter != null ? var.log_export_filter : "resource.type=\"nat_gateway\""

  unique_writer_identity = true
  bigquery_options {
    use_partitioned_tables = var.log_export_use_partitioned_tables != null ? var.log_export_use_partitioned_tables : true
  }
}

# Log Metrics
resource "google_logging_metric" "nat_metrics" {
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

  dynamic "bucket_options" {
    for_each = each.value.bucket_options != null ? [each.value.bucket_options] : []

    content {
      dynamic "linear_buckets" {
        for_each = bucket_options.value.linear_buckets != null ? [bucket_options.value.linear_buckets] : []

        content {
          num_finite_buckets = linear_buckets.value.num_finite_buckets
          width              = linear_buckets.value.width
          offset             = linear_buckets.value.offset
        }
      }

      dynamic "exponential_buckets" {
        for_each = bucket_options.value.exponential_buckets != null ? [bucket_options.value.exponential_buckets] : []

        content {
          num_finite_buckets = exponential_buckets.value.num_finite_buckets
          growth_factor      = exponential_buckets.value.growth_factor
          scale              = exponential_buckets.value.scale
        }
      }
    }
  }

  value_extractor = each.value.value_extractor
}