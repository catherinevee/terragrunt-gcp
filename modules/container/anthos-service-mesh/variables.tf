# Anthos Service Mesh Module - Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "enable_apis" {
  description = "Whether to enable required GCP APIs"
  type        = bool
  default     = true
}

variable "create_service_account" {
  description = "Whether to create a service account for ASM operations"
  type        = bool
  default     = true
}

variable "service_account_id" {
  description = "The service account ID for ASM operations"
  type        = string
  default     = "anthos-service-mesh-sa"
}

variable "service_account_roles" {
  description = "Roles to assign to the ASM service account"
  type        = list(string)
  default = [
    "roles/gkehub.admin",
    "roles/container.clusterAdmin",
    "roles/meshconfig.admin",
    "roles/meshtelemetry.admin",
    "roles/meshca.admin",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
    "roles/cloudtrace.agent"
  ]
}

# Cluster Configuration
variable "cluster_memberships" {
  description = "Configuration for GKE Hub cluster memberships"
  type = map(object({
    cluster_resource_link = string
    issuer               = string
    labels               = optional(map(string), {})
  }))
  default = {}
}

variable "config_membership_name" {
  description = "Name of the config membership for multi-cluster ingress"
  type        = string
  default     = ""
}

# Service Mesh Configuration
variable "enable_service_mesh" {
  description = "Whether to enable Anthos Service Mesh"
  type        = bool
  default     = true
}

variable "service_mesh_memberships" {
  description = "Configuration for service mesh memberships"
  type = map(object({
    membership_name                = string
    management_type               = optional(string, "MANAGEMENT_AUTOMATIC")
    control_plane_management      = optional(string, "MANAGEMENT_AUTOMATIC")
    config_management_version     = optional(string, "1.15.1")
    config_sync_enabled          = optional(bool, true)
    source_format                = optional(string, "hierarchy")
    sync_repo                    = optional(string)
    sync_branch                  = optional(string, "main")
    policy_dir                   = optional(string, "config")
    sync_wait_secs              = optional(number, 15)
    secret_type                 = optional(string, "none")
    prevent_drift               = optional(bool, true)
    policy_controller_enabled    = optional(bool, true)
    template_library_installed   = optional(bool, true)
    audit_interval_seconds       = optional(number, 60)
    exemptable_namespaces       = optional(list(string), ["kube-system"])
    log_denies_enabled          = optional(bool, true)
    mutation_enabled            = optional(bool, true)
    referential_rules_enabled   = optional(bool, true)
    policy_controller_monitoring = optional(object({
      backends = list(string)
    }))
    hierarchy_controller_enabled             = optional(bool, true)
    enable_pod_tree_labels                  = optional(bool, true)
    enable_hierarchical_resource_quota      = optional(bool, false)
  }))
  default = {}
}

# Istio Configuration
variable "create_istio_namespaces" {
  description = "Whether to create Istio system namespaces"
  type        = bool
  default     = true
}

variable "istio_control_plane_configs" {
  description = "Configuration for Istio control plane"
  type = map(object({
    hub      = optional(string, "gcr.io/istio-release")
    tag      = optional(string, "1.18.2-asm.3")
    revision = optional(string, "asm-managed")
    mesh_id  = string
    network  = string
    trust_domain = string
    labels   = optional(map(string), {})

    # Proxy configuration
    proxy_resources = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
    proxy_log_level           = optional(string, "warning")
    proxy_component_log_level = optional(string, "misc:error")
    proxy_privileged         = optional(bool, false)

    # Pilot configuration
    pilot_resources = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
    pilot_env_vars        = optional(map(string), {})
    pilot_trace_sampling  = optional(number, 1.0)
    pilot_k8s_env        = optional(map(string), {})
    pilot_hpa_min_replicas = optional(number, 1)
    pilot_hpa_max_replicas = optional(number, 3)
    pilot_hpa_metrics     = optional(list(any), [])

    # Gateway configuration
    ingress_gateway_enabled = optional(bool, true)
    ingress_gateway_type    = optional(string, "LoadBalancer")
    egress_gateway_enabled  = optional(bool, false)
    egress_gateway_type     = optional(string, "ClusterIP")

    gateway_resources = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
    gateway_autoscale_enabled = optional(bool, true)
    gateway_autoscale_min     = optional(number, 1)
    gateway_autoscale_max     = optional(number, 5)
    gateway_secret_volumes    = optional(list(any), [])

    # Gateway service configuration
    ingress_gateway_service_type = optional(string, "LoadBalancer")
    ingress_gateway_ports = optional(list(object({
      name       = string
      port       = number
      protocol   = string
      targetPort = number
    })), [])
    ingress_gateway_load_balancer_ip = optional(string)
    ingress_gateway_service_annotations = optional(map(string), {})

    # Gateway scheduling
    gateway_node_selector = optional(map(string), {})
    gateway_tolerations  = optional(list(any), [])
    gateway_affinity     = optional(any)

    # Security configuration
    security_namespace_default = optional(bool, true)
    workload_cert_ttl         = optional(string, "24h")

    # Telemetry configuration
    telemetry_v2_enabled        = optional(bool, true)
    prometheus_config_override = optional(map(string), {})
    stackdriver_telemetry_enabled = optional(bool, true)
    stackdriver_logging_enabled   = optional(bool, true)
    stackdriver_monitoring_enabled = optional(bool, true)
    stackdriver_topology_enabled   = optional(bool, true)
    stackdriver_disable_outbound   = optional(bool, false)
    stackdriver_config_override    = optional(map(string), {})

    # Tracing configuration
    stackdriver_tracing_enabled = optional(bool, true)
    zipkin_address             = optional(string)
    logging_level              = optional(string, "default:info")

    # SDS configuration
    sds_token_audience = optional(string)

    # Certificates configuration
    certificates_config = optional(map(string), {})

    # Mesh configuration
    proxy_stats_matcher = optional(map(string), {})
    hold_application_until_proxy_starts = optional(bool, false)
    proxy_status_port = optional(number, 15020)
    termination_drain_duration = optional(string, "5s")

    # Default providers
    default_metrics_provider        = optional(string, "prometheus")
    default_tracing_provider        = optional(string, "stackdriver")
    default_access_logging_provider = optional(string, "stackdriver")

    # Extension providers
    extension_providers = optional(list(any), [])

    # CA certificates
    ca_certificates = optional(list(string), [])
  }))
  default = {}
}

# Gateway Configuration
variable "istio_gateways" {
  description = "Configuration for Istio Gateways"
  type = map(object({
    namespace = string
    selector  = map(string)
    labels    = optional(map(string), {})
    servers = list(object({
      port = object({
        number   = number
        name     = string
        protocol = string
      })
      hosts = list(string)
      tls = optional(object({
        mode               = string
        credential_name    = optional(string)
        server_certificate = optional(string)
        private_key        = optional(string)
        ca_certificates    = optional(string)
        min_protocol_version = optional(string)
        max_protocol_version = optional(string)
        cipher_suites      = optional(list(string))
      }))
    }))
  }))
  default = {}
}

# Virtual Service Configuration
variable "virtual_services" {
  description = "Configuration for Istio Virtual Services"
  type = map(object({
    namespace = string
    hosts     = list(string)
    gateways  = optional(list(string))
    labels    = optional(map(string), {})

    http_routes = optional(list(object({
      name = optional(string)
      matches = list(object({
        uri = optional(object({
          exact  = optional(string)
          prefix = optional(string)
          regex  = optional(string)
        }))
        headers     = optional(map(string))
        query_params = optional(map(string))
        method      = optional(string)
      }))
      routes = list(object({
        destination = object({
          host   = string
          subset = optional(string)
          port = optional(object({
            number = number
          }))
        })
        weight = optional(number, 100)
        headers = optional(object({
          request  = optional(map(string))
          response = optional(map(string))
        }))
      }))
      redirect = optional(object({
        uri           = optional(string)
        authority     = optional(string)
        redirect_code = optional(number)
      }))
      rewrite = optional(object({
        uri       = optional(string)
        authority = optional(string)
      }))
      timeout = optional(string)
      retries = optional(object({
        attempts       = number
        per_try_timeout = optional(string)
        retry_on       = optional(string)
      }))
      fault = optional(object({
        delay = optional(object({
          percentage  = number
          fixed_delay = string
        }))
        abort = optional(object({
          percentage  = number
          http_status = number
        }))
      }))
      mirror = optional(object({
        host   = string
        subset = optional(string)
      }))
      cors_policy = optional(object({
        allow_origins     = list(string)
        allow_methods     = list(string)
        allow_headers     = list(string)
        expose_headers    = optional(list(string))
        max_age          = optional(string)
        allow_credentials = optional(bool)
      }))
    })), [])

    tcp_routes = optional(list(object({
      matches = list(object({
        destination_subnets = optional(list(string))
        port               = optional(number)
        source_labels      = optional(map(string))
        gateways           = optional(list(string))
      }))
      routes = list(object({
        destination = object({
          host   = string
          subset = optional(string)
          port = optional(object({
            number = number
          }))
        })
        weight = optional(number, 100)
      }))
    })), [])

    tls_routes = optional(list(object({
      matches = list(object({
        sni_hosts           = list(string)
        destination_subnets = optional(list(string))
        port               = optional(number)
        source_labels      = optional(map(string))
        gateways           = optional(list(string))
      }))
      routes = list(object({
        destination = object({
          host   = string
          subset = optional(string)
          port = optional(object({
            number = number
          }))
        })
        weight = optional(number, 100)
      }))
    })), [])
  }))
  default = {}
}

# Destination Rule Configuration
variable "destination_rules" {
  description = "Configuration for Istio Destination Rules"
  type = map(object({
    namespace = string
    host      = string
    labels    = optional(map(string), {})
    export_to = optional(list(string))

    traffic_policy = optional(object({
      load_balancer = optional(object({
        simple = optional(string)
        consistent_hash = optional(object({
          http_header_name  = optional(string)
          http_cookie_name  = optional(string)
          use_source_ip     = optional(bool)
          minimum_ring_size = optional(number)
        }))
      }))

      connection_pool = optional(object({
        tcp = optional(object({
          max_connections = optional(number)
          connect_timeout = optional(string)
          tcp_keepalive = optional(object({
            time     = optional(string)
            interval = optional(string)
            probes   = optional(number)
          }))
        }))
        http = optional(object({
          http1_max_pending_requests   = optional(number)
          http2_max_requests          = optional(number)
          max_requests_per_connection = optional(number)
          max_retries                 = optional(number)
          idle_timeout                = optional(string)
          h2_upgrade_policy           = optional(string)
        }))
      }))

      outlier_detection = optional(object({
        consecutive_errors           = optional(number)
        consecutive_gateway_errors   = optional(number)
        consecutive_5xx_errors       = optional(number)
        interval                    = optional(string)
        base_ejection_time          = optional(string)
        max_ejection_percent        = optional(number)
        min_health_percent          = optional(number)
      }))

      tls = optional(object({
        mode              = string
        client_certificate = optional(string)
        private_key       = optional(string)
        ca_certificates   = optional(string)
        credential_name   = optional(string)
        subject_alt_names = optional(list(string))
        sni              = optional(string)
      }))
    }))

    subsets = optional(list(object({
      name   = string
      labels = map(string)
      traffic_policy = optional(object({
        load_balancer = optional(object({
          simple = optional(string)
        }))
        connection_pool = optional(object({
          tcp = optional(object({
            max_connections = optional(number)
            connect_timeout = optional(string)
          }))
          http = optional(object({
            http1_max_pending_requests = optional(number)
            http2_max_requests        = optional(number)
          }))
        }))
      }))
    })), [])
  }))
  default = {}
}

# Service Entry Configuration
variable "service_entries" {
  description = "Configuration for Istio Service Entries"
  type = map(object({
    namespace  = string
    hosts      = list(string)
    location   = optional(string, "MESH_EXTERNAL")
    resolution = optional(string, "DNS")
    addresses  = optional(list(string))
    labels     = optional(map(string), {})

    ports = list(object({
      number   = number
      name     = string
      protocol = string
    }))

    endpoints = optional(list(object({
      address  = string
      ports    = optional(map(number))
      labels   = optional(map(string))
      network  = optional(string)
      locality = optional(string)
      weight   = optional(number)
    })), [])

    workload_selector = optional(object({
      labels = map(string)
    }))
  }))
  default = {}
}

# Sidecar Configuration
variable "sidecar_configs" {
  description = "Configuration for Istio Sidecars"
  type = map(object({
    namespace = string
    labels    = optional(map(string), {})

    workload_selector = optional(object({
      labels = map(string)
    }))

    ingress = optional(list(object({
      port = object({
        number      = number
        protocol    = string
        name        = string
        target_port = optional(number)
      })
      bind            = optional(string)
      capture_mode    = optional(string)
      default_endpoint = optional(string)
    })), [])

    egress = optional(list(object({
      port = optional(object({
        number   = number
        protocol = string
        name     = string
      }))
      bind        = optional(string)
      capture_mode = optional(string)
      hosts       = list(string)
    })), [])

    outbound_traffic_policy = optional(object({
      mode = string
      egress_proxy = optional(object({
        host   = string
        subset = optional(string)
        port = optional(object({
          number = number
        }))
      }))
    }))
  }))
  default = {}
}

# Security Configuration
variable "peer_authentications" {
  description = "Configuration for Istio Peer Authentication policies"
  type = map(object({
    namespace = string
    labels    = optional(map(string), {})

    selector = optional(object({
      match_labels = map(string)
    }))

    mtls = optional(object({
      mode = string
    }))

    port_level_mtls = optional(map(object({
      mode = string
    })), {})
  }))
  default = {}
}

variable "authorization_policies" {
  description = "Configuration for Istio Authorization policies"
  type = map(object({
    namespace = string
    action    = optional(string, "ALLOW")
    labels    = optional(map(string), {})

    selector = optional(object({
      match_labels = map(string)
    }))

    rules = optional(list(object({
      from = optional(list(object({
        source = optional(object({
          principals        = optional(list(string))
          request_principals = optional(list(string))
          namespaces        = optional(list(string))
          ip_blocks         = optional(list(string))
          remote_ip_blocks  = optional(list(string))
        }))
      })))

      to = optional(list(object({
        operation = optional(object({
          methods = optional(list(string))
          hosts   = optional(list(string))
          ports   = optional(list(string))
          paths   = optional(list(string))
        }))
      })))

      when = optional(list(object({
        key        = string
        values     = optional(list(string))
        not_values = optional(list(string))
      })))
    })), [])
  }))
  default = {}
}

# Telemetry Configuration
variable "telemetry_configs" {
  description = "Configuration for Istio Telemetry"
  type = map(object({
    namespace = string
    labels    = optional(map(string), {})

    selector = optional(object({
      match_labels = map(string)
    }))

    metrics = optional(list(object({
      providers = list(object({
        name = string
      }))
      overrides = optional(list(object({
        match = optional(object({
          metric = string
          mode   = optional(string)
        }))
        disabled = optional(bool)
        tags = optional(map(object({
          value     = optional(string)
          operation = optional(string)
        })), {})
      })), [])
    })), [])

    tracing = optional(list(object({
      providers = list(object({
        name = string
      }))
      random_sampling_percentage = optional(number)
      custom_tags = optional(map(object({
        literal     = optional(string)
        environment = optional(string)
        header = optional(object({
          name         = string
          default_value = optional(string)
        }))
      })), {})
    })), [])

    access_logging = optional(list(object({
      providers = list(object({
        name = string
      }))
      match = optional(object({
        mode = string
      }))
      filter = optional(object({
        expression = string
      }))
    })), [])
  }))
  default = {}
}

# Monitoring Configuration
variable "enable_monitoring" {
  description = "Whether to enable monitoring for Anthos Service Mesh"
  type        = bool
  default     = true
}

variable "create_dashboard" {
  description = "Whether to create a monitoring dashboard"
  type        = bool
  default     = true
}

variable "dashboard_display_name" {
  description = "Display name for the monitoring dashboard"
  type        = string
  default     = "Anthos Service Mesh Dashboard"
}

variable "notification_channels" {
  description = "List of notification channel IDs for alerts"
  type        = list(string)
  default     = []
}

variable "alert_policies" {
  description = "Alert policies configuration"
  type = map(object({
    display_name           = string
    combiner              = optional(string, "OR")
    enabled               = optional(bool, true)
    documentation         = optional(string)
    condition_display_name = string
    filter                = string
    duration              = string
    comparison            = string
    threshold_value       = number
    alignment_period      = optional(string, "60s")
    per_series_aligner    = optional(string, "ALIGN_RATE")
    cross_series_reducer  = optional(string, "REDUCE_SUM")
    group_by_fields       = optional(list(string), [])
    trigger_count         = optional(number)
    trigger_percent       = optional(number)
    notification_channels = optional(list(string), [])
    auto_close_duration   = optional(string, "86400s")
    rate_limit           = optional(string)
  }))
  default = {}
}

# Logging Configuration
variable "enable_audit_logging" {
  description = "Whether to enable audit logging for Anthos Service Mesh"
  type        = bool
  default     = true
}

variable "audit_log_sink_name" {
  description = "Name of the audit log sink"
  type        = string
  default     = "asm-audit-sink"
}

variable "audit_log_destination" {
  description = "Destination for audit logs (e.g., Cloud Storage bucket, BigQuery dataset)"
  type        = string
  default     = ""
}

# Advanced Configuration
variable "enable_multi_cluster" {
  description = "Whether to enable multi-cluster service mesh"
  type        = bool
  default     = false
}

variable "multi_cluster_config" {
  description = "Multi-cluster configuration"
  type = object({
    primary_cluster   = string
    remote_clusters   = list(string)
    network_endpoints = map(string)
    cross_network_policy = optional(object({
      enabled = bool
      trust_domains = list(string)
    }))
  })
  default = {
    primary_cluster   = ""
    remote_clusters   = []
    network_endpoints = {}
  }
}

variable "enable_fleet_workload_identity" {
  description = "Whether to enable Fleet Workload Identity"
  type        = bool
  default     = false
}

variable "fleet_workload_identity_config" {
  description = "Fleet Workload Identity configuration"
  type = object({
    fleet_project_id = string
    workload_identity_pool = string
    service_account_mapping = map(string)
  })
  default = {
    fleet_project_id = ""
    workload_identity_pool = ""
    service_account_mapping = {}
  }
}

variable "enable_service_mesh_certificates" {
  description = "Whether to enable service mesh certificates"
  type        = bool
  default     = false
}

variable "certificate_config" {
  description = "Certificate configuration for service mesh"
  type = object({
    ca_pool              = string
    certificate_lifetime = string
    key_algorithm       = string
    key_size           = number
    automatic_renewal   = bool
  })
  default = {
    ca_pool              = ""
    certificate_lifetime = "24h"
    key_algorithm       = "RSA"
    key_size           = 2048
    automatic_renewal   = true
  }
}

variable "enable_observability" {
  description = "Whether to enable observability features"
  type        = bool
  default     = true
}

variable "observability_config" {
  description = "Observability configuration"
  type = object({
    enable_distributed_tracing = bool
    enable_access_logging     = bool
    enable_metrics_collection = bool
    trace_sampling_rate      = number
    custom_dashboards        = list(string)
    alerting_rules          = list(string)
  })
  default = {
    enable_distributed_tracing = true
    enable_access_logging     = true
    enable_metrics_collection = true
    trace_sampling_rate      = 0.01
    custom_dashboards        = []
    alerting_rules          = []
  }
}

variable "enable_traffic_management" {
  description = "Whether to enable advanced traffic management"
  type        = bool
  default     = false
}

variable "traffic_management_config" {
  description = "Traffic management configuration"
  type = object({
    enable_traffic_splitting = bool
    enable_circuit_breaker   = bool
    enable_retry_policies    = bool
    enable_timeout_policies  = bool
    default_timeout         = string
    default_retry_attempts  = number
  })
  default = {
    enable_traffic_splitting = true
    enable_circuit_breaker   = true
    enable_retry_policies    = true
    enable_timeout_policies  = true
    default_timeout         = "30s"
    default_retry_attempts  = 3
  }
}

variable "enable_security_policies" {
  description = "Whether to enable security policies"
  type        = bool
  default     = true
}

variable "security_policy_config" {
  description = "Security policy configuration"
  type = object({
    default_deny_all       = bool
    enable_mtls_strict     = bool
    enable_authorization   = bool
    custom_ca_certificates = list(string)
    jwt_policies          = list(string)
  })
  default = {
    default_deny_all       = false
    enable_mtls_strict     = true
    enable_authorization   = true
    custom_ca_certificates = []
    jwt_policies          = []
  }
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Network tags to apply to resources"
  type        = list(string)
  default     = []
}

# Environment-specific configurations
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "mesh_feature_configs" {
  description = "Advanced mesh feature configurations"
  type = map(object({
    feature_name = string
    enabled     = bool
    configuration = map(string)
  }))
  default = {}
}

variable "custom_resource_definitions" {
  description = "Custom Resource Definitions for extended functionality"
  type = map(object({
    api_version = string
    kind        = string
    metadata    = map(string)
    spec        = any
  }))
  default = {}
}

variable "workload_annotations" {
  description = "Default annotations for workloads"
  type        = map(string)
  default     = {}
}

variable "namespace_configurations" {
  description = "Namespace-specific configurations"
  type = map(object({
    namespace_name = string
    istio_injection = bool
    security_policies = list(string)
    network_policies  = list(string)
    resource_quotas   = map(string)
  }))
  default = {}
}