output "firewall_rules" {
  description = "Map of firewall rule names to their details"
  value = {
    for k, v in google_compute_firewall.rules : k => {
      id          = v.id
      self_link   = v.self_link
      name        = v.name
      priority    = v.priority
      direction   = v.direction
      target_tags = v.target_tags
    }
  }
}

output "firewall_rule_ids" {
  description = "Map of firewall rule names to their IDs"
  value       = { for k, v in google_compute_firewall.rules : k => v.id }
}

output "firewall_rule_self_links" {
  description = "Map of firewall rule names to their self links"
  value       = { for k, v in google_compute_firewall.rules : k => v.self_link }
}