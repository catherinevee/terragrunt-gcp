# Load Balancer Configuration for Production - US Central 1
# Global and regional load balancing with Cloud CDN, Cloud Armor, and SSL certificates

terraform {
  source = "${get_repo_root()}/modules/networking/load-balancer"
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

# Load Balancer depends on VPC
dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    network_id = "mock-network-id"
    network_name = "mock-network-name"
    subnets = {
      public = {
        id = "mock-subnet-id"
        name = "mock-subnet-name"
        ip_cidr_range = "10.0.1.0/24"
        region = "us-central1"
      }
      private_web = {
        id = "mock-subnet-id"
        name = "mock-subnet-name"
        ip_cidr_range = "10.0.2.0/24"
        region = "us-central1"
      }
    }
  }
}

# Load Balancer depends on GKE for backend services
dependency "gke" {
  config_path = "../../compute/gke"
  skip_outputs = true
  mock_outputs = {
    cluster_endpoint = "mock-endpoint"
    cluster_name = "mock-cluster"
    node_pools = {
      web = {
        instance_group_urls = ["mock-instance-group-1", "mock-instance-group-2"]
      }
    }
  }
}

# Load Balancer depends on Cloud Armor for security policies
dependency "cloud_armor" {
  config_path = "../../security/cloud-armor"
  skip_outputs = true
  mock_outputs = {
    policy_self_link = "mock-policy-link"
    policy_name = "mock-policy"
  }
}

# Load Balancer depends on SSL certificates
dependency "ssl_certificates" {
  config_path = "../../security/ssl-certificates"
  skip_outputs = true
  mock_outputs = {
    certificates = {
      main = {
        self_link = "mock-cert-link"
        name = "mock-cert"
      }
      wildcard = {
        self_link = "mock-wildcard-cert-link"
        name = "mock-wildcard-cert"
      }
    }
  }
}

# Prevent accidental destruction of production load balancers
prevent_destroy = true

locals {
  # Extract configuration from includes
  env_config    = include.env.locals
  region_config = include.region.locals

  # Load balancer names
  lb_name_prefix = "${local.env_config.environment}-${local.region_config.region_short}"

  # Global Load Balancer configuration
  global_load_balancers = {
    main = {
      name = "${local.lb_name_prefix}-global-lb-main"
      type = "EXTERNAL_MANAGED"
      scheme = "EXTERNAL"
      tier = local.env_config.environment == "prod" ? "PREMIUM" : "STANDARD"

      # Frontend configuration
      frontend = {
        name = "${local.lb_name_prefix}-frontend-main"
        port_range = "443"
        protocol = "HTTPS"

        # IP configuration
        ip_config = {
          ip_version = "IPV4"
          ip_address = null  # Will be created
          address_type = "EXTERNAL"
          network_tier = local.env_config.environment == "prod" ? "PREMIUM" : "STANDARD"
        }

        # SSL configuration
        ssl_certificates = [
          dependency.ssl_certificates.outputs.certificates.main.self_link,
          dependency.ssl_certificates.outputs.certificates.wildcard.self_link
        ]

        # SSL policy
        ssl_policy = {
          min_tls_version = "TLS_1_2"
          profile = "MODERN"
          custom_features = []
        }
      }

      # Backend services
      backend_services = {
        web = {
          name = "${local.lb_name_prefix}-backend-web"
          protocol = "HTTPS"
          port_name = "http"
          timeout_sec = 30
          session_affinity = "GENERATED_COOKIE"
          affinity_cookie_ttl_sec = 3600

          # Health check
          health_check = {
            name = "${local.lb_name_prefix}-health-check-web"
            protocol = "HTTPS"
            port = 443
            request_path = "/health"
            check_interval_sec = 10
            timeout_sec = 5
            healthy_threshold = 2
            unhealthy_threshold = 3
          }

          # Backend configuration
          backends = [
            {
              group = try(dependency.gke.outputs.node_pools.web.instance_group_urls[0], "mock-group")
              balancing_mode = "RATE"
              max_rate_per_instance = 100
              capacity_scaler = 1.0
            },
            {
              group = try(dependency.gke.outputs.node_pools.web.instance_group_urls[1], "mock-group")
              balancing_mode = "RATE"
              max_rate_per_instance = 100
              capacity_scaler = 1.0
            }
          ]

          # Circuit breakers
          circuit_breakers = {
            max_requests_per_connection = 2
            max_connections = 5000
            max_pending_requests = 500
            max_requests = 5000
            max_retries = 3
          }

          # Connection draining
          connection_draining = {
            draining_timeout_sec = 300
          }

          # Outlier detection
          outlier_detection = {
            consecutive_errors = 5
            interval = {
              seconds = 30
              nanos = 0
            }
            base_ejection_time = {
              seconds = 30
              nanos = 0
            }
            max_ejection_percent = 50
            enforcing_consecutive_errors = 100
            enforcing_success_rate = 100
            success_rate_minimum_hosts = 5
            success_rate_request_volume = 100
            success_rate_stdev_factor = 1900
            consecutive_gateway_failure = 5
            enforcing_consecutive_gateway_failure = 100
            split_external_local_origin_errors = false
          }

          # Consistent hash
          consistent_hash = {
            http_cookie = {
              name = "lb_session"
              ttl = {
                seconds = 3600
                nanos = 0
              }
            }
            minimum_ring_size = 1024
          }

          # IAP configuration (if needed)
          iap = local.env_config.environment == "prod" ? {
            enabled = true
            oauth2_client_id = get_env("IAP_CLIENT_ID", "")
            oauth2_client_secret = get_env("IAP_CLIENT_SECRET", "")
          } : null

          # Security policy
          security_policy = try(dependency.cloud_armor.outputs.policy_self_link, null)

          # Custom request headers
          custom_request_headers = [
            "X-Environment: ${local.env_config.environment}",
            "X-Region: ${local.region_config.region}",
            "X-Load-Balancer: global"
          ]

          # Custom response headers
          custom_response_headers = [
            "X-Content-Type-Options: nosniff",
            "X-Frame-Options: DENY",
            "X-XSS-Protection: 1; mode=block",
            "Strict-Transport-Security: max-age=31536000; includeSubDomains"
          ]
        }

        api = {
          name = "${local.lb_name_prefix}-backend-api"
          protocol = "HTTPS"
          port_name = "https"
          timeout_sec = 60
          session_affinity = "CLIENT_IP_PORT_PROTO"

          health_check = {
            name = "${local.lb_name_prefix}-health-check-api"
            protocol = "HTTPS"
            port = 443
            request_path = "/api/health"
            check_interval_sec = 5
            timeout_sec = 3
            healthy_threshold = 2
            unhealthy_threshold = 2
          }

          backends = [
            {
              group = try(dependency.gke.outputs.node_pools.api.instance_group_urls[0], "mock-group")
              balancing_mode = "UTILIZATION"
              max_utilization = 0.8
              capacity_scaler = 1.0
            }
          ]

          circuit_breakers = {
            max_connections = 10000
            max_pending_requests = 1000
            max_requests = 10000
            max_retries = 5
          }

          security_policy = try(dependency.cloud_armor.outputs.policy_self_link, null)
        }
      }

      # URL maps and routing rules
      url_map = {
        name = "${local.lb_name_prefix}-url-map-main"
        default_service = "web"

        host_rules = [
          {
            hosts = ["www.example.com", "example.com"]
            path_matcher = "web-paths"
          },
          {
            hosts = ["api.example.com"]
            path_matcher = "api-paths"
          },
          {
            hosts = ["admin.example.com"]
            path_matcher = "admin-paths"
          }
        ]

        path_matchers = [
          {
            name = "web-paths"
            default_service = "web"
            path_rules = [
              {
                paths = ["/api/*"]
                service = "api"
              },
              {
                paths = ["/static/*"]
                service = "web"
                route_action = {
                  url_rewrite = {
                    path_prefix_rewrite = "/"
                  }
                }
              }
            ]
          },
          {
            name = "api-paths"
            default_service = "api"
            path_rules = [
              {
                paths = ["/v1/*"]
                service = "api"
                route_action = {
                  retry_policy = {
                    num_retries = 3
                    retry_conditions = ["5xx", "deadline-exceeded", "connect-failure"]
                  }
                }
              },
              {
                paths = ["/v2/*"]
                service = "api"
                route_action = {
                  timeout = {
                    seconds = 120
                    nanos = 0
                  }
                }
              }
            ]
          },
          {
            name = "admin-paths"
            default_service = "web"
            path_rules = []
            route_action = {
              fault_injection_policy = local.env_config.environment == "dev" ? {
                abort = {
                  http_status = 503
                  percentage = 0.1
                }
                delay = {
                  fixed_delay = {
                    seconds = 5
                    nanos = 0
                  }
                  percentage = 0.1
                }
              } : null
            }
          }
        ]

        # Default route action
        default_route_action = {
          cors_policy = {
            allow_origins = ["https://example.com"]
            allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
            allow_headers = ["Content-Type", "Authorization", "X-Requested-With"]
            expose_headers = ["Content-Length", "Content-Type"]
            max_age = 3600
            allow_credentials = true
            disabled = false
          }
        }
      }

      # Cloud CDN configuration
      cdn_config = {
        enabled = local.env_config.environment == "prod"

        cache_key_policy = {
          include_host = true
          include_protocol = true
          include_query_string = false
          query_string_whitelist = ["page", "limit", "sort"]
          query_string_blacklist = ["session", "token"]
        }

        cache_mode = "CACHE_ALL_STATIC"
        client_ttl = 3600
        default_ttl = 3600
        max_ttl = 86400
        negative_caching = true

        negative_caching_policy = [
          {
            code = 404
            ttl = 120
          },
          {
            code = 410
            ttl = 120
          }
        ]

        serve_while_stale = 86400
        signed_url_cache_max_age_sec = 7200

        bypass_cache_on_request_headers = [
          {
            header_name = "X-No-Cache"
          }
        ]

        cache_rules = [
          {
            priority = 1
            origin = "web"
            path_pattern = "/static/*"
            ttl = 86400
          },
          {
            priority = 2
            origin = "web"
            path_pattern = "/images/*"
            ttl = 604800  # 1 week
          },
          {
            priority = 3
            origin = "api"
            path_pattern = "/api/v1/public/*"
            ttl = 300
          }
        ]
      }

      # Logging configuration
      logging = {
        enable = true
        sample_rate = local.env_config.environment == "prod" ? 0.1 : 1.0
        include_host = true
        include_protocol = true
        include_query_string = true
        include_request_headers = ["User-Agent", "Referer", "Authorization"]
        include_response_headers = ["Content-Type", "Cache-Control"]
      }
    }
  }

  # Regional Load Balancer configuration
  regional_load_balancers = {
    internal = {
      name = "${local.lb_name_prefix}-regional-lb-internal"
      type = "INTERNAL_MANAGED"
      scheme = "INTERNAL"
      region = local.region_config.region

      # Frontend configuration
      frontend = {
        name = "${local.lb_name_prefix}-frontend-internal"
        port_range = "443"
        protocol = "HTTPS"

        # IP configuration
        ip_config = {
          subnet = dependency.vpc.outputs.subnets.private_web.id
          ip_address = null  # Will be allocated from subnet
          purpose = "SHARED_LOADBALANCER_VIP"
        }

        # SSL configuration
        ssl_certificates = [
          dependency.ssl_certificates.outputs.certificates.main.self_link
        ]
      }

      # Backend services
      backend_services = {
        internal_api = {
          name = "${local.lb_name_prefix}-backend-internal-api"
          protocol = "HTTPS"
          port_name = "https"
          timeout_sec = 30
          session_affinity = "CLIENT_IP"

          health_check = {
            name = "${local.lb_name_prefix}-health-check-internal"
            protocol = "HTTPS"
            port = 443
            request_path = "/internal/health"
            check_interval_sec = 10
            timeout_sec = 5
          }

          backends = [
            {
              group = try(dependency.gke.outputs.node_pools.internal.instance_group_urls[0], "mock-group")
              balancing_mode = "CONNECTION"
              max_connections_per_instance = 100
              capacity_scaler = 1.0
            }
          ]
        }
      }

      # URL map
      url_map = {
        name = "${local.lb_name_prefix}-url-map-internal"
        default_service = "internal_api"
      }
    }
  }

  # Network Endpoint Groups (NEGs) for serverless backends
  network_endpoint_groups = {
    cloud_run = {
      name = "${local.lb_name_prefix}-neg-cloud-run"
      network = dependency.vpc.outputs.network_id
      subnetwork = dependency.vpc.outputs.subnets.private_web.id
      network_endpoint_type = "SERVERLESS"
      region = local.region_config.region

      cloud_run = {
        service = "${local.env_config.environment}-api-service"
        tag = "latest"
        url_mask = "https://api.example.com/<service>"
      }
    }

    cloud_functions = {
      name = "${local.lb_name_prefix}-neg-cloud-functions"
      network = dependency.vpc.outputs.network_id
      subnetwork = dependency.vpc.outputs.subnets.private_web.id
      network_endpoint_type = "SERVERLESS"
      region = local.region_config.region

      cloud_function = {
        function = "${local.env_config.environment}-webhook-processor"
        url_mask = "https://functions.example.com/<function>"
      }
    }

    app_engine = {
      name = "${local.lb_name_prefix}-neg-app-engine"
      network = dependency.vpc.outputs.network_id
      network_endpoint_type = "SERVERLESS"

      app_engine = {
        service = "default"
        version = local.env_config.environment
        url_mask = "https://app.example.com/<service>/<version>"
      }
    }
  }

  # Traffic management policies
  traffic_policies = {
    # Traffic splitting for canary deployments
    traffic_split = local.env_config.environment == "prod" ? {
      enabled = true
      splits = [
        {
          service = "web"
          percentage = 90
        },
        {
          service = "web-canary"
          percentage = 10
        }
      ]
    } : null

    # Rate limiting
    rate_limiting = {
      enabled = true
      rate_limit_threshold = {
        count = 1000
        interval = "1m"
      }
      conform_action = "allow"
      exceed_action = "deny_429"
      enforce_on_key = "IP"
    }

    # Header-based routing
    header_routing = {
      enabled = true
      rules = [
        {
          header_name = "X-User-Type"
          header_value = "premium"
          service = "web-premium"
        },
        {
          header_name = "X-Beta-User"
          header_value = "true"
          service = "web-beta"
        }
      ]
    }
  }

  # Monitoring and alerting
  monitoring_config = {
    alerts = {
      high_latency = {
        display_name = "High Latency - Load Balancer"
        conditions = {
          threshold_value = 1000  # milliseconds
          duration = "300s"
        }
      }
      high_error_rate = {
        display_name = "High Error Rate - Load Balancer"
        conditions = {
          threshold_value = 0.01  # 1%
          duration = "300s"
        }
      }
      backend_unhealthy = {
        display_name = "Backend Unhealthy - Load Balancer"
        conditions = {
          threshold_value = 0.5  # 50% unhealthy
          duration = "180s"
        }
      }
      ssl_cert_expiry = {
        display_name = "SSL Certificate Expiring Soon"
        conditions = {
          threshold_value = 30  # days
          duration = "86400s"
        }
      }
    }

    dashboard = {
      display_name = "Load Balancer Dashboard - ${local.env_config.environment}"
      grid_layout = {
        widgets = [
          {
            title = "Request Rate"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"https_lb_rule\" AND metric.type=\"loadbalancing.googleapis.com/https/request_count\""
                  }
                }
              }]
            }
          },
          {
            title = "Latency Distribution"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"https_lb_rule\" AND metric.type=\"loadbalancing.googleapis.com/https/total_latencies\""
                  }
                }
              }]
            }
          },
          {
            title = "Error Rate"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"https_lb_rule\" AND metric.type=\"loadbalancing.googleapis.com/https/request_count\" AND metric.label.response_code_class=\"5xx\""
                  }
                }
              }]
            }
          },
          {
            title = "Backend Health"
            scorecard = {
              time_series_query = {
                time_series_filter = {
                  filter = "resource.type=\"https_lb_rule\" AND metric.type=\"loadbalancing.googleapis.com/https/backend_latencies\""
                }
              }
            }
          },
          {
            title = "CDN Hit Rate"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"https_lb_rule\" AND metric.type=\"loadbalancing.googleapis.com/https/internal/request_count\" AND metric.label.cache_result=\"HIT\""
                  }
                }
              }]
            }
          },
          {
            title = "Bandwidth"
            xy_chart = {
              data_sets = [{
                time_series_query = {
                  time_series_filter = {
                    filter = "resource.type=\"https_lb_rule\" AND metric.type=\"loadbalancing.googleapis.com/https/request_bytes_count\""
                  }
                }
              }]
            }
          }
        ]
      }
    }
  }

  # Autoscaling configuration for backend services
  autoscaling_config = {
    enabled = true
    min_replicas = local.env_config.environment == "prod" ? 3 : 1
    max_replicas = local.env_config.environment == "prod" ? 100 : 10

    cpu_utilization = {
      target = 0.6
    }

    load_balancing_utilization = {
      target = 0.8
    }

    custom_metrics = [
      {
        name = "custom.googleapis.com/request_rate"
        target_value = 1000
        target_type = "GAUGE"
      }
    ]

    scale_down_control = {
      max_scaled_down_replicas = {
        percent = 10
        fixed = 2
      }
      time_window_sec = 600
    }
  }
}

# Module inputs
inputs = {
  # Global load balancers
  global_load_balancers = local.global_load_balancers

  # Regional load balancers
  regional_load_balancers = local.regional_load_balancers

  # Network endpoint groups
  network_endpoint_groups = local.network_endpoint_groups

  # Network configuration
  network_config = {
    network_id = dependency.vpc.outputs.network_id
    network_name = dependency.vpc.outputs.network_name
    subnets = dependency.vpc.outputs.subnets
  }

  # SSL configuration
  ssl_config = {
    certificates = try(dependency.ssl_certificates.outputs.certificates, {})
    ssl_policy = {
      min_tls_version = "TLS_1_2"
      profile = local.env_config.environment == "prod" ? "MODERN" : "COMPATIBLE"
      custom_features = local.env_config.environment == "prod" ? [
        "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
        "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
        "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
        "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
      ] : []
    }
  }

  # Security configuration
  security_config = {
    cloud_armor_policy = try(dependency.cloud_armor.outputs.policy_self_link, null)
    enable_iap = local.env_config.environment == "prod"
    enable_https_redirect = true
    enable_quic_negotiation = local.env_config.environment == "prod"
  }

  # CDN configuration
  cdn_config = local.global_load_balancers.main.cdn_config

  # Traffic policies
  traffic_policies = local.traffic_policies

  # Monitoring configuration
  monitoring_config = local.monitoring_config
  enable_monitoring = true
  create_monitoring_dashboard = local.env_config.environment == "prod"
  create_monitoring_alerts = local.env_config.environment != "dev"

  # Autoscaling configuration
  autoscaling_config = local.autoscaling_config

  # High availability configuration
  ha_config = {
    enable_ha = local.env_config.environment == "prod"
    enable_cross_region_failover = local.env_config.environment == "prod"
    failover_ratio = 0.1
    backup_pool_health_threshold = 0.3
  }

  # Performance optimization
  performance_config = {
    enable_http2 = true
    enable_quic = local.env_config.environment == "prod"
    enable_compression = true
    compression_mode = "AUTOMATIC"
    max_connections_per_endpoint = local.env_config.environment == "prod" ? 10000 : 1000
  }

  # Cost optimization
  cost_optimization = {
    enable_cloud_cdn = local.env_config.environment == "prod"
    enable_connection_draining = true
    connection_draining_timeout_sec = 300
    enable_unused_backend_cleanup = local.env_config.environment == "dev"
  }

  # Labels
  labels = merge(
    var.common_labels,
    {
      component = "networking"
      service   = "load-balancer"
      tier      = "edge"
    }
  )

  # Project configuration
  project_id = var.project_id
  region     = local.region_config.region

  # Dependencies
  depends_on = [dependency.vpc, dependency.gke, dependency.cloud_armor, dependency.ssl_certificates]
}