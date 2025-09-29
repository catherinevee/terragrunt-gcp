# Cloud Interconnect Module - Main Configuration

# Enable required APIs
resource "google_project_service" "interconnect_apis" {
  for_each = var.enable_apis ? toset([
    "compute.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "networkconnectivity.googleapis.com"
  ]) : toset([])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# Dedicated Interconnect resources
resource "google_compute_interconnect" "dedicated_interconnects" {
  for_each = var.dedicated_interconnects

  name                     = each.key
  description             = each.value.description
  interconnect_type       = "DEDICATED"
  location                = each.value.location
  requested_link_count    = each.value.link_count
  link_type              = each.value.link_type
  admin_enabled          = each.value.admin_enabled
  noc_contact_email      = each.value.noc_contact_email
  customer_name          = each.value.customer_name

  dynamic "expected_outages" {
    for_each = each.value.expected_outages != null ? each.value.expected_outages : []
    content {
      name        = expected_outages.value.name
      description = expected_outages.value.description
      source      = expected_outages.value.source
      state       = expected_outages.value.state
      issue_type  = expected_outages.value.issue_type
      start_time  = expected_outages.value.start_time
      end_time    = expected_outages.value.end_time
    }
  }

  project = var.project_id

  depends_on = [
    google_project_service.interconnect_apis
  ]
}

# Partner Interconnect resources
resource "google_compute_interconnect" "partner_interconnects" {
  for_each = var.partner_interconnects

  name              = each.key
  description       = each.value.description
  interconnect_type = "PARTNER"
  location          = each.value.location
  admin_enabled     = each.value.admin_enabled
  noc_contact_email = each.value.noc_contact_email
  customer_name     = each.value.customer_name

  project = var.project_id

  depends_on = [
    google_project_service.interconnect_apis
  ]
}

# Interconnect Attachments (VLANs) for Dedicated Interconnects
resource "google_compute_interconnect_attachment" "dedicated_attachments" {
  for_each = var.dedicated_attachments

  name                     = each.key
  description             = each.value.description
  interconnect            = google_compute_interconnect.dedicated_interconnects[each.value.interconnect_name].id
  type                    = "DEDICATED"
  router                  = google_compute_router.interconnect_routers[each.value.router_name].id
  region                  = each.value.region
  vlan_tag8021q          = each.value.vlan_tag
  bandwidth              = each.value.bandwidth
  candidate_subnets      = each.value.candidate_subnets
  admin_enabled          = each.value.admin_enabled
  edge_availability_domain = each.value.edge_availability_domain
  encryption             = each.value.encryption
  ipsec_internal_addresses = each.value.ipsec_internal_addresses

  project = var.project_id

  depends_on = [
    google_compute_interconnect.dedicated_interconnects,
    google_compute_router.interconnect_routers
  ]
}

# Interconnect Attachments for Partner Interconnects
resource "google_compute_interconnect_attachment" "partner_attachments" {
  for_each = var.partner_attachments

  name         = each.key
  description  = each.value.description
  type         = "PARTNER"
  router       = google_compute_router.interconnect_routers[each.value.router_name].id
  region       = each.value.region
  bandwidth    = each.value.bandwidth
  admin_enabled = each.value.admin_enabled
  edge_availability_domain = each.value.edge_availability_domain
  pairing_key  = each.value.pairing_key
  partner_asn  = each.value.partner_asn
  encryption   = each.value.encryption

  project = var.project_id

  depends_on = [
    google_compute_router.interconnect_routers
  ]
}

# Cloud Routers for Interconnect
resource "google_compute_router" "interconnect_routers" {
  for_each = var.cloud_routers

  name    = each.key
  region  = each.value.region
  network = each.value.network
  description = each.value.description

  bgp {
    asn               = each.value.bgp_asn
    advertise_mode    = each.value.advertise_mode
    advertised_groups = each.value.advertised_groups

    dynamic "advertised_ip_ranges" {
      for_each = each.value.advertised_ip_ranges != null ? each.value.advertised_ip_ranges : []
      content {
        range       = advertised_ip_ranges.value.range
        description = advertised_ip_ranges.value.description
      }
    }

    keepalive_interval = each.value.keepalive_interval
  }

  encrypted_interconnect_router = each.value.encrypted_interconnect_router

  project = var.project_id

  depends_on = [
    google_project_service.interconnect_apis
  ]
}

# BGP Sessions for Interconnect Attachments
resource "google_compute_router_peer" "interconnect_bgp_peers" {
  for_each = var.bgp_sessions

  name                      = each.key
  router                    = google_compute_router.interconnect_routers[each.value.router_name].name
  region                    = each.value.region
  peer_ip_address          = each.value.peer_ip_address
  peer_asn                 = each.value.peer_asn
  advertised_route_priority = each.value.advertised_route_priority
  interface                = google_compute_router_interface.interconnect_interfaces[each.value.interface_name].name
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
      session_initialization_mode = bfd.value.session_initialization_mode
      min_receive_interval        = bfd.value.min_receive_interval
      min_transmit_interval       = bfd.value.min_transmit_interval
      multiplier                  = bfd.value.multiplier
    }
  }

  enable           = each.value.enable
  router_appliance_instance = each.value.router_appliance_instance

  project = var.project_id

  depends_on = [
    google_compute_router_interface.interconnect_interfaces
  ]
}

# Router Interfaces for Interconnect Attachments
resource "google_compute_router_interface" "interconnect_interfaces" {
  for_each = var.router_interfaces

  name               = each.key
  router             = google_compute_router.interconnect_routers[each.value.router_name].name
  region             = each.value.region
  ip_range           = each.value.ip_range
  vpn_tunnel         = each.value.vpn_tunnel
  interconnect_attachment = each.value.attachment_name != null ? (
    contains(keys(var.dedicated_attachments), each.value.attachment_name) ?
    google_compute_interconnect_attachment.dedicated_attachments[each.value.attachment_name].id :
    google_compute_interconnect_attachment.partner_attachments[each.value.attachment_name].id
  ) : null
  redundant_interface = each.value.redundant_interface
  subnetwork         = each.value.subnetwork
  private_ip_address = each.value.private_ip_address

  project = var.project_id

  depends_on = [
    google_compute_interconnect_attachment.dedicated_attachments,
    google_compute_interconnect_attachment.partner_attachments
  ]
}

# Network Connectivity Center Hub
resource "google_network_connectivity_hub" "connectivity_hub" {
  count = var.enable_network_connectivity_center ? 1 : 0

  name        = var.connectivity_hub_name
  description = var.connectivity_hub_description
  project     = var.project_id

  depends_on = [
    google_project_service.interconnect_apis
  ]
}

# Network Connectivity Center Spokes
resource "google_network_connectivity_spoke" "interconnect_spokes" {
  for_each = var.enable_network_connectivity_center ? var.connectivity_spokes : {}

  name        = each.key
  description = each.value.description
  location    = each.value.location
  hub         = google_network_connectivity_hub.connectivity_hub[0].id

  dynamic "linked_vpn_tunnels" {
    for_each = each.value.linked_vpn_tunnels != null ? [each.value.linked_vpn_tunnels] : []
    content {
      uris                = linked_vpn_tunnels.value.uris
      site_to_site_data_transfer = linked_vpn_tunnels.value.site_to_site_data_transfer
    }
  }

  dynamic "linked_interconnect_attachments" {
    for_each = each.value.linked_interconnect_attachments != null ? [each.value.linked_interconnect_attachments] : []
    content {
      uris                = linked_interconnect_attachments.value.uris
      site_to_site_data_transfer = linked_interconnect_attachments.value.site_to_site_data_transfer
    }
  }

  dynamic "linked_router_appliance_instances" {
    for_each = each.value.linked_router_appliance_instances != null ? [each.value.linked_router_appliance_instances] : []
    content {
      dynamic "instances" {
        for_each = linked_router_appliance_instances.value.instances
        content {
          virtual_machine = instances.value.virtual_machine
          ip_address     = instances.value.ip_address
        }
      }
      site_to_site_data_transfer = linked_router_appliance_instances.value.site_to_site_data_transfer
    }
  }

  dynamic "linked_vpc_network" {
    for_each = each.value.linked_vpc_network != null ? [each.value.linked_vpc_network] : []
    content {
      uri                        = linked_vpc_network.value.uri
      exclude_export_ranges      = linked_vpc_network.value.exclude_export_ranges
    }
  }

  project = var.project_id

  depends_on = [
    google_network_connectivity_hub.connectivity_hub
  ]
}

# Cross-Connect resources for Dedicated Interconnects
resource "google_compute_interconnect_macsec_config" "macsec_configs" {
  for_each = var.macsec_configs

  name         = each.key
  interconnect = google_compute_interconnect.dedicated_interconnects[each.value.interconnect_name].id

  dynamic "pre_shared_keys" {
    for_each = each.value.pre_shared_keys
    content {
      name     = pre_shared_keys.value.name
      cak      = pre_shared_keys.value.cak
      ckn      = pre_shared_keys.value.ckn
      start_time = pre_shared_keys.value.start_time
    }
  }

  project = var.project_id

  depends_on = [
    google_compute_interconnect.dedicated_interconnects
  ]
}

# Service Account for Interconnect operations
resource "google_service_account" "interconnect_sa" {
  count = var.create_service_account ? 1 : 0

  account_id   = var.service_account_id
  display_name = "Cloud Interconnect Service Account"
  description  = "Service account for Cloud Interconnect operations and monitoring"
  project      = var.project_id
}

# IAM roles for the service account
resource "google_project_iam_member" "interconnect_sa_roles" {
  for_each = var.create_service_account ? toset(var.service_account_roles) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.interconnect_sa[0].email}"

  depends_on = [
    google_service_account.interconnect_sa
  ]
}

# Monitoring for Interconnect
resource "google_monitoring_dashboard" "interconnect_dashboard" {
  count = var.enable_monitoring && var.create_dashboard ? 1 : 0

  dashboard_json = jsonencode({
    displayName = var.dashboard_display_name
    mosaicLayout = {
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Interconnect Link State"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"gce_interconnect\" AND metric.type=\"compute.googleapis.com/interconnect/link/state\""
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "State"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Interconnect Throughput"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"gce_interconnect_attachment\" AND metric.type=\"compute.googleapis.com/interconnect_attachment/sent_bytes_count\""
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Bytes/sec"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "BGP Session State"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"gce_router\" AND metric.type=\"compute.googleapis.com/router/bgp/session_up\""
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Session Up"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Interconnect Errors"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"gce_interconnect_attachment\" AND metric.type=\"compute.googleapis.com/interconnect_attachment/dropped_packets_count\""
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Dropped Packets"
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
    google_project_service.interconnect_apis
  ]
}

# Alert policies for Interconnect monitoring
resource "google_monitoring_alert_policy" "interconnect_alerts" {
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
    google_project_service.interconnect_apis
  ]
}

# IAM bindings for Interconnect resources
resource "google_compute_interconnect_iam_binding" "interconnect_bindings" {
  for_each = var.interconnect_iam_bindings

  interconnect = contains(keys(var.dedicated_interconnects), each.value.interconnect_name) ?
    google_compute_interconnect.dedicated_interconnects[each.value.interconnect_name].name :
    google_compute_interconnect.partner_interconnects[each.value.interconnect_name].name
  role    = each.value.role
  members = each.value.members

  project = var.project_id

  depends_on = [
    google_compute_interconnect.dedicated_interconnects,
    google_compute_interconnect.partner_interconnects
  ]
}

# Compute Router IAM bindings
resource "google_compute_router_iam_binding" "router_bindings" {
  for_each = var.router_iam_bindings

  router  = google_compute_router.interconnect_routers[each.value.router_name].name
  region  = each.value.region
  role    = each.value.role
  members = each.value.members

  project = var.project_id

  depends_on = [
    google_compute_router.interconnect_routers
  ]
}

# Network Connectivity Center Hub IAM bindings
resource "google_network_connectivity_hub_iam_binding" "hub_bindings" {
  for_each = var.enable_network_connectivity_center ? var.hub_iam_bindings : {}

  name    = google_network_connectivity_hub.connectivity_hub[0].name
  role    = each.value.role
  members = each.value.members

  project = var.project_id

  depends_on = [
    google_network_connectivity_hub.connectivity_hub
  ]
}

# Log sinks for Interconnect audit logs
resource "google_logging_project_sink" "interconnect_audit_sink" {
  count = var.enable_audit_logging ? 1 : 0

  name        = var.audit_log_sink_name
  destination = var.audit_log_destination

  filter = join(" OR ", [
    "protoPayload.serviceName=\"compute.googleapis.com\"",
    "protoPayload.methodName:\"interconnect\"",
    "protoPayload.methodName:\"router\"",
    "protoPayload.methodName:\"attachment\""
  ])

  unique_writer_identity = true
  project               = var.project_id

  depends_on = [
    google_project_service.interconnect_apis
  ]
}

# Cloud Armor security policies for Interconnect (if applicable)
resource "google_compute_security_policy" "interconnect_security_policy" {
  count = var.enable_cloud_armor ? 1 : 0

  name        = var.security_policy_name
  description = "Security policy for Cloud Interconnect traffic"

  dynamic "rule" {
    for_each = var.security_policy_rules
    content {
      action   = rule.value.action
      priority = rule.value.priority

      match {
        versioned_expr = rule.value.versioned_expr
        config {
          src_ip_ranges = rule.value.src_ip_ranges
        }
      }

      description = rule.value.description
    }
  }

  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable          = var.enable_adaptive_protection
      rule_visibility = var.adaptive_protection_rule_visibility
    }
  }

  project = var.project_id

  depends_on = [
    google_project_service.interconnect_apis
  ]
}

# Local variables for data processing
locals {
  # Combine all interconnects for unified processing
  all_interconnects = merge(var.dedicated_interconnects, var.partner_interconnects)

  # Combine all attachments for unified processing
  all_attachments = merge(var.dedicated_attachments, var.partner_attachments)

  # Create attachment to interconnect mapping
  attachment_interconnect_map = merge(
    {
      for k, v in var.dedicated_attachments : k => v.interconnect_name
    },
    {
      for k, v in var.partner_attachments : k => "partner"
    }
  )

  # Create BGP session to router mapping
  bgp_router_map = {
    for k, v in var.bgp_sessions : k => v.router_name
  }
}