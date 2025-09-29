# Cloud NAT Configuration for Production - US Central 1
# Provides outbound internet connectivity for resources without public IPs

terraform {
  source = "${get_repo_root()}/modules/networking/cloud-nat"
}

# Include root configuration
include "root" {
  path = find_in_parent_folders()
}

# Include environment configuration
include "env" {
  path = find_in_parent_folders("env.hcl")
  expose = true
}

# Include region configuration
include "region" {
  path = find_in_parent_folders("region.hcl")
  expose = true
}

# Cloud NAT depends on VPC
dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    network_id = "mock-network-id"
    network_name = "mock-network-name"
    subnets = {
      private = {
        id = "mock-subnet-id"
        name = "mock-subnet-name"
        ip_cidr_range = "10.0.0.0/24"
        region = "us-central1"
      }
    }
  }
}

# Prevent accidental destruction of production NAT
prevent_destroy = true

locals {
  # Extract configuration from includes
  env_config    = include.env.locals
  region_config = include.region.locals

  # Network configuration from region
  network_config = region_config.network_config

  # NAT name
  nat_name = "${local.env_config.environment}-${local.region_config.region_short}-nat"

  # Router name
  router_name = "${local.env_config.environment}-${local.region_config.region_short}-router"

  # Determine which subnets need NAT
  nat_subnets = [
    for subnet_key, subnet in dependency.vpc.outputs.subnets :
    subnet if contains(["private", "private_web", "private_app", "private_data", "management"], subnet_key)
  ]

  # NAT IP configuration based on environment
  nat_ip_count = local.network_config.nat_ip_count

  # Production-specific NAT configuration
  nat_config = {
    min_ports_per_vm = local.env_config.environment == "prod" ? 256 : 64
    max_ports_per_vm = local.env_config.environment == "prod" ? 4096 : 512
    tcp_established_idle_timeout = local.env_config.environment == "prod" ? 1200 : 600
    tcp_transitory_idle_timeout = local.env_config.environment == "prod" ? 30 : 30
    tcp_time_wait_timeout = local.env_config.environment == "prod" ? 120 : 120
    udp_idle_timeout = local.env_config.environment == "prod" ? 30 : 30
    icmp_idle_timeout = local.env_config.environment == "prod" ? 30 : 30
    enable_dynamic_port_allocation = local.env_config.environment == "prod"
    enable_endpoint_independent_mapping = true
  }

  # Logging configuration
  log_config = local.network_config.enable_nat_logging ? {
    enable = true
    filter = local.network_config.nat_log_config.filter
  } : {
    enable = false
    filter = "ALL"
  }

  # Reserved IP addresses for NAT
  reserved_nat_ips = {
    for i in range(local.nat_ip_count) :
    "nat-ip-${i + 1}" => {
      name         = "${local.nat_name}-ip-${i + 1}"
      description  = "Reserved IP for Cloud NAT gateway ${i + 1}"
      address_type = "EXTERNAL"
      network_tier = local.env_config.environment == "prod" ? "PREMIUM" : "STANDARD"
      purpose      = null
    }
  }

  # BGP configuration for the router
  bgp_config = {
    asn                = 64514
    advertise_mode     = "DEFAULT"
    advertised_groups  = null
    advertised_ip_ranges = []
    keepalive_interval = 20
  }

  # Router interfaces for potential VPN/Interconnect
  router_interfaces = {}

  # BGP peers configuration
  bgp_peers = {}

  # Monitoring alert policies
  alert_policies = local.env_config.environment == "prod" ? {
    high_port_usage = {
      display_name = "High NAT Port Usage - ${local.nat_name}"
      combiner     = "OR"
      conditions = [{
        display_name = "Port usage above 80%"
        condition_threshold = {
          filter          = "resource.type=\"nat_gateway\" AND resource.labels.gateway_name=\"${local.nat_name}\" AND metric.type=\"compute.googleapis.com/nat/port_usage\""
          duration        = "300s"
          comparison      = "COMPARISON_GT"
          threshold_value = 0.8
          aggregations = [{
            alignment_period     = "60s"
            per_series_aligner   = "ALIGN_MEAN"
            cross_series_reducer = "REDUCE_MEAN"
            group_by_fields      = ["resource.labels.gateway_name"]
          }]
        }
      }]
      notification_channels = []
      user_labels = {
        environment = local.env_config.environment
        service     = "cloud-nat"
      }
    }

    nat_allocation_failed = {
      display_name = "NAT Allocation Failed - ${local.nat_name}"
      combiner     = "OR"
      conditions = [{
        display_name = "NAT allocation errors"
        condition_threshold = {
          filter          = "resource.type=\"nat_gateway\" AND resource.labels.gateway_name=\"${local.nat_name}\" AND metric.type=\"compute.googleapis.com/nat/nat_allocation_failed\""
          duration        = "60s"
          comparison      = "COMPARISON_GT"
          threshold_value = 0
          aggregations = [{
            alignment_period     = "60s"
            per_series_aligner   = "ALIGN_RATE"
            cross_series_reducer = "REDUCE_SUM"
            group_by_fields      = ["resource.labels.gateway_name"]
          }]
        }
      }]
      notification_channels = []
      user_labels = {
        environment = local.env_config.environment
        service     = "cloud-nat"
        severity    = "critical"
      }
    }

    dropped_packets = {
      display_name = "NAT Dropped Packets - ${local.nat_name}"
      combiner     = "OR"
      conditions = [{
        display_name = "Packets dropped by NAT"
        condition_threshold = {
          filter          = "resource.type=\"nat_gateway\" AND resource.labels.gateway_name=\"${local.nat_name}\" AND metric.type=\"compute.googleapis.com/nat/dropped_sent_packets_count\""
          duration        = "300s"
          comparison      = "COMPARISON_GT"
          threshold_value = 100
          aggregations = [{
            alignment_period     = "60s"
            per_series_aligner   = "ALIGN_RATE"
            cross_series_reducer = "REDUCE_SUM"
            group_by_fields      = ["resource.labels.gateway_name"]
          }]
        }
      }]
      notification_channels = []
      user_labels = {
        environment = local.env_config.environment
        service     = "cloud-nat"
        severity    = "warning"
      }
    }
  } : {}

  # Dashboard configuration
  dashboard_config = {
    display_name = "Cloud NAT Dashboard - ${local.nat_name}"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 4
          height = 4
          widget = {
            title = "NAT Port Usage"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"nat_gateway\" AND resource.labels.gateway_name=\"${local.nat_name}\" AND metric.type=\"compute.googleapis.com/nat/port_usage\""
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 4
          width  = 4
          height = 4
          widget = {
            title = "Allocated Ports"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"nat_gateway\" AND resource.labels.gateway_name=\"${local.nat_name}\" AND metric.type=\"compute.googleapis.com/nat/allocated_ports\""
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 8
          width  = 4
          height = 4
          widget = {
            title = "Dropped Packets"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"nat_gateway\" AND resource.labels.gateway_name=\"${local.nat_name}\" AND metric.type=\"compute.googleapis.com/nat/dropped_sent_packets_count\""
                  }
                }
              }]
            }
          }
        },
        {
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Open Connections"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"nat_gateway\" AND resource.labels.gateway_name=\"${local.nat_name}\" AND metric.type=\"compute.googleapis.com/nat/open_connections\""
                  }
                }
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
            title = "NAT Gateway Bandwidth"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"nat_gateway\" AND resource.labels.gateway_name=\"${local.nat_name}\" AND metric.type=\"compute.googleapis.com/nat/sent_bytes_count\""
                    }
                  }
                  plotType = "LINE"
                  targetAxis = "Y1"
                },
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"nat_gateway\" AND resource.labels.gateway_name=\"${local.nat_name}\" AND metric.type=\"compute.googleapis.com/nat/received_bytes_count\""
                    }
                  }
                  plotType = "LINE"
                  targetAxis = "Y1"
                }
              ]
            }
          }
        }
      ]
    }
  }
}

# Module inputs
inputs = {
  # Router configuration
  create_router = true
  router_name   = local.router_name
  router_description = "Cloud Router for NAT gateway in ${local.region_config.region}"
  router_network = dependency.vpc.outputs.network_name
  router_region  = local.region_config.region

  # BGP configuration for router
  router_bgp = local.bgp_config

  # NAT configuration
  nat_name = local.nat_name
  nat_description = "Cloud NAT gateway for ${local.env_config.environment} environment in ${local.region_config.region}"

  # Source subnetwork configuration
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetworks = [
    for subnet in local.nat_subnets : {
      name = subnet.id
      source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
      secondary_ip_range_names = []
    }
  ]

  # NAT IP allocation
  nat_ip_allocate_option = "MANUAL_ONLY"
  nat_ips = [
    for ip_key, ip_config in local.reserved_nat_ips : ip_config.name
  ]

  # Reserved IP addresses
  create_reserved_ips = true
  reserved_ips = local.reserved_nat_ips

  # Port allocation
  min_ports_per_vm = local.nat_config.min_ports_per_vm
  max_ports_per_vm = local.nat_config.max_ports_per_vm
  enable_dynamic_port_allocation = local.nat_config.enable_dynamic_port_allocation

  # Enable endpoint-independent mapping
  enable_endpoint_independent_mapping = local.nat_config.enable_endpoint_independent_mapping

  # Timeout configurations
  tcp_established_idle_timeout_sec = local.nat_config.tcp_established_idle_timeout
  tcp_transitory_idle_timeout_sec = local.nat_config.tcp_transitory_idle_timeout
  tcp_time_wait_timeout_sec = local.nat_config.tcp_time_wait_timeout
  udp_idle_timeout_sec = local.nat_config.udp_idle_timeout
  icmp_idle_timeout_sec = local.nat_config.icmp_idle_timeout

  # Logging configuration
  log_config = local.log_config

  # Rules for specific destinations (production only)
  rules = local.env_config.environment == "prod" ? [
    {
      rule_number = 100
      description = "High bandwidth destinations"
      match = "destination.ip IN ('8.8.8.8/32', '8.8.4.4/32', '1.1.1.1/32')"
      action = {
        source_nat_active_ips = []
        source_nat_drain_ips = []
      }
    }
  ] : []

  # Router interfaces (for VPN/Interconnect)
  router_interfaces = local.router_interfaces

  # BGP peers
  bgp_peers = local.bgp_peers

  # Monitoring configuration
  enable_monitoring = true
  create_monitoring_dashboard = local.env_config.environment == "prod"
  monitoring_dashboard_config = local.dashboard_config

  create_monitoring_alerts = local.env_config.environment == "prod"
  monitoring_alerts = local.alert_policies

  # Log metrics
  create_log_metrics = local.env_config.environment == "prod"
  log_metrics = {
    nat_connection_count = {
      name        = "${local.nat_name}-connection-count"
      description = "Count of NAT connections"
      filter      = "resource.type=\"nat_gateway\" AND resource.labels.gateway_name=\"${local.nat_name}\" AND jsonPayload.connection.natIp!=\"\""
      metric_descriptor = {
        metric_kind = "DELTA"
        value_type  = "INT64"
        unit        = "1"
        labels = [
          {
            key         = "nat_ip"
            value_type  = "STRING"
            description = "NAT IP address"
          },
          {
            key         = "destination_ip"
            value_type  = "STRING"
            description = "Destination IP address"
          }
        ]
      }
      value_extractor = "EXTRACT(jsonPayload.connection.natIp)"
      label_extractors = {
        "nat_ip" = "EXTRACT(jsonPayload.connection.natIp)"
        "destination_ip" = "EXTRACT(jsonPayload.connection.dest_ip)"
      }
    }
  }

  # High Availability configuration
  ha_nat_config = {
    enable_ha = local.env_config.environment == "prod"
    ha_min_ports_per_vm = 512
    ha_max_ports_per_vm = 8192
  }

  # Performance configuration
  performance_config = {
    enable_high_performance = local.env_config.environment == "prod"
    bandwidth_tier = local.env_config.environment == "prod" ? "PREMIUM" : "STANDARD"
  }

  # Labels
  labels = merge(
    var.common_labels,
    {
      component = "networking"
      service   = "cloud-nat"
      tier      = "network"
    }
  )

  # Project ID
  project_id = var.project_id
  region     = local.region_config.region

  # Dependencies
  depends_on = [dependency.vpc]
}