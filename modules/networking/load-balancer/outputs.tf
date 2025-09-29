# Load Balancer Module Outputs

output "global_ip_address" {
  description = "The global IP address for the load balancer"
  value       = google_compute_global_address.global_ip.address
}

output "global_ip_id" {
  description = "The ID of the global IP address"
  value       = google_compute_global_address.global_ip.id
}

output "health_check_id" {
  description = "The ID of the health check"
  value       = google_compute_health_check.health_check.id
}

output "health_check_self_link" {
  description = "The self-link of the health check"
  value       = google_compute_health_check.health_check.self_link
}

output "backend_service_id" {
  description = "The ID of the backend service"
  value       = google_compute_backend_service.backend_service.id
}

output "backend_service_self_link" {
  description = "The self-link of the backend service"
  value       = google_compute_backend_service.backend_service.self_link
}

output "url_map_id" {
  description = "The ID of the URL map"
  value       = google_compute_url_map.url_map.id
}

output "url_map_self_link" {
  description = "The self-link of the URL map"
  value       = google_compute_url_map.url_map.self_link
}

output "target_http_proxy_id" {
  description = "The ID of the target HTTP proxy"
  value       = google_compute_target_http_proxy.http_proxy.id
}

output "target_http_proxy_self_link" {
  description = "The self-link of the target HTTP proxy"
  value       = google_compute_target_http_proxy.http_proxy.self_link
}

output "forwarding_rule_id" {
  description = "The ID of the forwarding rule"
  value       = google_compute_global_forwarding_rule.forwarding_rule.id
}

output "forwarding_rule_self_link" {
  description = "The self-link of the forwarding rule"
  value       = google_compute_global_forwarding_rule.forwarding_rule.self_link
}

output "load_balancer_ip" {
  description = "The external IP address of the load balancer"
  value       = google_compute_global_address.global_ip.address
}

output "instance_groups" {
  description = "Map of region to instance group details for auto-created groups"
  value = {
    for region, group in google_compute_region_instance_group_manager.backend_groups :
    region => {
      id             = group.id
      instance_group = group.instance_group
      self_link      = group.self_link
      target_size    = group.target_size
      status         = group.status
    }
  }
}

output "instance_templates" {
  description = "List of auto-created instance templates"
  value = [
    for template in google_compute_instance_template.backend_template : {
      id        = template.id
      self_link = template.self_link
      name      = template.name
    }
  ]
}

output "backend_groups_mapping" {
  description = "Map of regions to their final backend group URLs"
  value       = local.final_backend_groups
}

output "data_instance_groups" {
  description = "Details of existing instance groups looked up by name"
  value = {
    for region, group in data.google_compute_instance_group.existing_groups :
    region => {
      id        = group.id
      self_link = group.self_link
      name      = group.name
      zone      = group.zone
      size      = group.size
    }
  }
}

output "load_balancer_url" {
  description = "The URL of the load balancer"
  value       = "http://${google_compute_global_address.global_ip.address}"
}

output "backend_service_configuration" {
  description = "Backend service configuration details"
  value = {
    name                  = google_compute_backend_service.backend_service.name
    protocol              = google_compute_backend_service.backend_service.protocol
    load_balancing_scheme = google_compute_backend_service.backend_service.load_balancing_scheme
    timeout_sec           = google_compute_backend_service.backend_service.timeout_sec
    locality_lb_policy    = google_compute_backend_service.backend_service.locality_lb_policy
    session_affinity      = google_compute_backend_service.backend_service.session_affinity
    backend_count         = length(var.backend_regions)
    backends = [
      for region in var.backend_regions : {
        region = region
        group  = local.final_backend_groups[region]
      }
    ]
  }
}

output "health_check_configuration" {
  description = "Health check configuration details"
  value = {
    name                = google_compute_health_check.health_check.name
    check_interval_sec  = google_compute_health_check.health_check.check_interval_sec
    timeout_sec         = google_compute_health_check.health_check.timeout_sec
    healthy_threshold   = google_compute_health_check.health_check.healthy_threshold
    unhealthy_threshold = google_compute_health_check.health_check.unhealthy_threshold
    http_health_check = {
      port         = google_compute_health_check.health_check.http_health_check[0].port
      request_path = google_compute_health_check.health_check.http_health_check[0].request_path
    }
  }
}