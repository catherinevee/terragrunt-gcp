locals {
  rules_map = { for rule in var.firewall_rules : rule.name => rule }
}

resource "google_compute_firewall" "rules" {
  for_each = local.rules_map

  name        = each.value.name
  project     = var.project_id
  network     = var.network_name
  description = each.value.description
  priority    = each.value.priority
  direction   = each.value.direction

  # Source and destination ranges
  source_ranges      = each.value.direction == "INGRESS" ? each.value.source_ranges : null
  destination_ranges = each.value.direction == "EGRESS" ? each.value.destination_ranges : null

  # Source and target tags
  source_tags = each.value.source_tags
  target_tags = each.value.target_tags

  # Source and target service accounts
  source_service_accounts = each.value.source_service_accounts
  target_service_accounts = each.value.target_service_accounts

  # Allow rules
  dynamic "allow" {
    for_each = each.value.allow != null ? each.value.allow : []
    content {
      protocol = allow.value.protocol
      ports    = allow.value.ports
    }
  }

  # Deny rules
  dynamic "deny" {
    for_each = each.value.deny != null ? each.value.deny : []
    content {
      protocol = deny.value.protocol
      ports    = deny.value.ports
    }
  }

  # Logging
  dynamic "log_config" {
    for_each = each.value.enable_logging ? [1] : []
    content {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }

  disabled = each.value.disabled
}