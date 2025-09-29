# DNS Module Outputs

output "zone_id" {
  description = "The unique identifier for the managed zone"
  value       = try(google_dns_managed_zone.main.id, "")
}

output "zone_name" {
  description = "The DNS name of the managed zone"
  value       = try(google_dns_managed_zone.main.dns_name, "")
}

output "zone_name_servers" {
  description = "The list of name servers for the managed zone"
  value       = try(google_dns_managed_zone.main.name_servers, [])
}

output "zone_creation_time" {
  description = "The time the managed zone was created"
  value       = try(google_dns_managed_zone.main.creation_time, "")
}

output "zone_visibility" {
  description = "The visibility of the managed zone (public or private)"
  value       = try(google_dns_managed_zone.main.visibility, "")
}

output "zone_description" {
  description = "The description of the managed zone"
  value       = try(google_dns_managed_zone.main.description, "")
}

output "record_set_ids" {
  description = "Map of record set names to their identifiers"
  value = {
    for k, v in google_dns_record_set.records : k => {
      id      = v.id
      name    = v.name
      type    = v.type
      ttl     = v.ttl
      rrdatas = v.rrdatas
    }
  }
}

output "record_set_names" {
  description = "List of all DNS record set names"
  value = [
    for record in google_dns_record_set.records : record.name
  ]
}

output "record_set_types" {
  description = "Map of record names to their types"
  value = {
    for k, v in google_dns_record_set.records : k => v.type
  }
}

output "a_records" {
  description = "Map of A record names to their IP addresses"
  value = {
    for k, v in google_dns_record_set.records : k => v.rrdatas
    if v.type == "A"
  }
}

output "aaaa_records" {
  description = "Map of AAAA record names to their IPv6 addresses"
  value = {
    for k, v in google_dns_record_set.records : k => v.rrdatas
    if v.type == "AAAA"
  }
}

output "cname_records" {
  description = "Map of CNAME record names to their targets"
  value = {
    for k, v in google_dns_record_set.records : k => v.rrdatas
    if v.type == "CNAME"
  }
}

output "mx_records" {
  description = "Map of MX record names to their mail servers"
  value = {
    for k, v in google_dns_record_set.records : k => v.rrdatas
    if v.type == "MX"
  }
}

output "txt_records" {
  description = "Map of TXT record names to their values"
  value = {
    for k, v in google_dns_record_set.records : k => v.rrdatas
    if v.type == "TXT"
  }
}

output "srv_records" {
  description = "Map of SRV record names to their values"
  value = {
    for k, v in google_dns_record_set.records : k => v.rrdatas
    if v.type == "SRV"
  }
}

output "ns_records" {
  description = "Map of NS record names to their name servers"
  value = {
    for k, v in google_dns_record_set.records : k => v.rrdatas
    if v.type == "NS"
  }
}

output "ptr_records" {
  description = "Map of PTR record names to their reverse lookup values"
  value = {
    for k, v in google_dns_record_set.records : k => v.rrdatas
    if v.type == "PTR"
  }
}

output "dns_policy_id" {
  description = "The identifier for the DNS policy"
  value       = try(google_dns_policy.main[0].id, "")
}

output "dns_policy_name" {
  description = "The name of the DNS policy"
  value       = try(google_dns_policy.main[0].name, "")
}

output "dns_policy_networks" {
  description = "Networks to which the DNS policy is applied"
  value       = try(google_dns_policy.main[0].networks, [])
}

output "dns_policy_alternative_name_servers" {
  description = "Alternative name server configuration"
  value       = try(google_dns_policy.main[0].alternative_name_server_config, {})
}

output "dns_policy_enable_inbound_forwarding" {
  description = "Whether inbound forwarding is enabled"
  value       = try(google_dns_policy.main[0].enable_inbound_forwarding, false)
}

output "dns_policy_enable_logging" {
  description = "Whether DNS query logging is enabled"
  value       = try(google_dns_policy.main[0].enable_logging, false)
}

output "forwarding_config" {
  description = "DNS forwarding configuration"
  value = try({
    target_name_servers = google_dns_managed_zone.main.forwarding_config[0].target_name_servers
  }, {})
}

output "peering_config" {
  description = "DNS peering configuration"
  value = try({
    target_network = google_dns_managed_zone.main.peering_config[0].target_network
  }, {})
}

output "private_visibility_config" {
  description = "Private zone visibility configuration"
  value = try([
    for network in google_dns_managed_zone.main.private_visibility_config[*].networks : {
      network_url = network.network_url
    }
  ], [])
}

output "dnssec_config" {
  description = "DNSSEC configuration for the zone"
  value = try({
    state             = google_dns_managed_zone.main.dnssec_config[0].state
    default_key_specs = google_dns_managed_zone.main.dnssec_config[0].default_key_specs
    non_existence     = google_dns_managed_zone.main.dnssec_config[0].non_existence
  }, {})
}

output "response_policy_id" {
  description = "The identifier for the response policy"
  value       = try(google_dns_response_policy.main[0].id, "")
}

output "response_policy_name" {
  description = "The name of the response policy"
  value       = try(google_dns_response_policy.main[0].response_policy_name, "")
}

output "response_policy_rule_ids" {
  description = "Map of response policy rule names to their IDs"
  value = {
    for k, v in google_dns_response_policy_rule.rules : k => v.id
  }
}

output "managed_zone_project" {
  description = "The project where the DNS zone is created"
  value       = var.project_id
}

output "managed_zone_labels" {
  description = "Labels applied to the managed zone"
  value       = try(google_dns_managed_zone.main.labels, {})
}

output "cloud_logging_config" {
  description = "Cloud logging configuration for the zone"
  value = try({
    enable_logging = google_dns_managed_zone.main.cloud_logging_config[0].enable_logging
  }, {})
}

output "reverse_lookup_zone" {
  description = "Reverse lookup zone configuration"
  value = {
    enabled = var.enable_reverse_lookup
    zone_id = try(google_dns_managed_zone.reverse[0].id, "")
    name    = try(google_dns_managed_zone.reverse[0].dns_name, "")
  }
}

output "subdomain_zones" {
  description = "Map of subdomain zones created"
  value = {
    for k, v in google_dns_managed_zone.subdomains : k => {
      id           = v.id
      dns_name     = v.dns_name
      name_servers = v.name_servers
    }
  }
}

output "zone_iam_bindings" {
  description = "IAM bindings for the DNS zone"
  value = {
    for k, v in google_dns_managed_zone_iam_binding.bindings : k => {
      role    = v.role
      members = v.members
    }
  }
}

output "record_sets_count" {
  description = "Total number of DNS record sets"
  value       = length(google_dns_record_set.records)
}

output "response_policy_rules_count" {
  description = "Total number of response policy rules"
  value       = length(google_dns_response_policy_rule.rules)
}

output "zone_type" {
  description = "Type of the DNS zone (public or private)"
  value       = var.zone_type
}

output "enabled_features" {
  description = "List of enabled DNS features"
  value = {
    dnssec_enabled          = var.enable_dnssec
    logging_enabled         = var.enable_logging
    private_zone            = var.zone_type == "private"
    forwarding_enabled      = length(var.forwarding_targets) > 0
    peering_enabled         = var.peering_network != ""
    response_policy_enabled = var.enable_response_policy
  }
}