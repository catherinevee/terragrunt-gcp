# Anthos Service Mesh Module - Main Configuration

# Enable required APIs
resource "google_project_service" "asm_apis" {
  for_each = var.enable_apis ? toset([
    "mesh.googleapis.com",
    "container.googleapis.com",
    "gkehub.googleapis.com",
    "anthos.googleapis.com",
    "meshconfig.googleapis.com",
    "meshtelemetry.googleapis.com",
    "meshca.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudtrace.googleapis.com",
    "servicenetworking.googleapis.com",
    "secretmanager.googleapis.com",
    "certificatemanager.googleapis.com"
  ]) : toset([])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# GKE Hub Membership for clusters
resource "google_gke_hub_membership" "cluster_memberships" {
  for_each = var.cluster_memberships

  membership_id = each.key
  project       = var.project_id

  endpoint {
    gke_cluster {
      resource_link = each.value.cluster_resource_link
    }
  }

  authority {
    issuer = each.value.issuer
  }

  labels = merge(var.labels, each.value.labels)

  depends_on = [
    google_project_service.asm_apis
  ]
}

# Anthos Service Mesh Feature
resource "google_gke_hub_feature" "service_mesh" {
  count = var.enable_service_mesh ? 1 : 0

  name     = "servicemesh"
  project  = var.project_id
  location = "global"

  spec {
    multiclusteringress {
      config_membership = var.config_membership_name
    }
  }

  depends_on = [
    google_project_service.asm_apis,
    google_gke_hub_membership.cluster_memberships
  ]
}

# Service Mesh membership configurations
resource "google_gke_hub_feature_membership" "service_mesh_memberships" {
  for_each = var.enable_service_mesh ? var.service_mesh_memberships : {}

  location   = "global"
  feature    = google_gke_hub_feature.service_mesh[0].name
  membership = google_gke_hub_membership.cluster_memberships[each.value.membership_name].membership_id
  project    = var.project_id

  mesh {
    management = each.value.management_type

    dynamic "control_plane" {
      for_each = each.value.control_plane_management == "MANAGEMENT_AUTOMATIC" ? [1] : []
      content {
        management = each.value.control_plane_management
      }
    }
  }

  configmanagement {
    version = each.value.config_management_version

    config_sync {
      enabled     = each.value.config_sync_enabled
      source_format = each.value.source_format

      git {
        sync_repo    = each.value.sync_repo
        sync_branch  = each.value.sync_branch
        policy_dir   = each.value.policy_dir
        sync_wait_secs = each.value.sync_wait_secs
        secret_type  = each.value.secret_type
      }

      prevent_drift = each.value.prevent_drift
    }

    policy_controller {
      enabled                    = each.value.policy_controller_enabled
      template_library_installed = each.value.template_library_installed
      audit_interval_seconds     = each.value.audit_interval_seconds
      exemptable_namespaces      = each.value.exemptable_namespaces
      log_denies_enabled         = each.value.log_denies_enabled
      mutation_enabled           = each.value.mutation_enabled
      referential_rules_enabled  = each.value.referential_rules_enabled

      dynamic "monitoring" {
        for_each = each.value.policy_controller_monitoring != null ? [each.value.policy_controller_monitoring] : []
        content {
          backends = monitoring.value.backends
        }
      }
    }

    hierarchy_controller {
      enabled                = each.value.hierarchy_controller_enabled
      enable_pod_tree_labels = each.value.enable_pod_tree_labels
      enable_hierarchical_resource_quota = each.value.enable_hierarchical_resource_quota
    }
  }

  depends_on = [
    google_gke_hub_feature.service_mesh,
    google_gke_hub_membership.cluster_memberships
  ]
}

# Istio Operator configuration
resource "kubernetes_namespace" "istio_system" {
  for_each = var.create_istio_namespaces ? toset(["istio-system", "istio-config", "asm-system"]) : toset([])

  metadata {
    name = each.value
    labels = merge(var.labels, {
      "istio-injection" = "disabled"
      "app.kubernetes.io/managed-by" = "terraform"
    })
    annotations = {
      "mesh.cloud.google.com/proxy" = jsonencode({
        "managed" = "true"
      })
    }
  }

  depends_on = [
    google_gke_hub_feature_membership.service_mesh_memberships
  ]
}

# Istio Control Plane configuration
resource "kubernetes_manifest" "istio_control_plane" {
  for_each = var.istio_control_plane_configs

  manifest = {
    apiVersion = "install.istio.io/v1alpha1"
    kind       = "IstioOperator"
    metadata = {
      name      = each.key
      namespace = "istio-system"
      labels = merge(var.labels, each.value.labels)
    }
    spec = {
      hub = each.value.hub
      tag = each.value.tag
      revision = each.value.revision

      values = {
        global = {
          meshID      = each.value.mesh_id
          network     = each.value.network
          trustDomain = each.value.trust_domain

          proxy = {
            resources = {
              requests = {
                cpu    = each.value.proxy_resources.requests.cpu
                memory = each.value.proxy_resources.requests.memory
              }
              limits = {
                cpu    = each.value.proxy_resources.limits.cpu
                memory = each.value.proxy_resources.limits.memory
              }
            }
            logLevel = each.value.proxy_log_level
            componentLogLevel = each.value.proxy_component_log_level
            privileged = each.value.proxy_privileged
          }

          logging = {
            level = each.value.logging_level
          }

          tracer = {
            stackdriver = {
              enabled = each.value.stackdriver_tracing_enabled
            }
            zipkin = {
              address = each.value.zipkin_address
            }
          }

          sds = {
            token = {
              aud = each.value.sds_token_audience
            }
          }

          certificates = each.value.certificates_config
        }

        pilot = {
          resources = {
            requests = {
              cpu    = each.value.pilot_resources.requests.cpu
              memory = each.value.pilot_resources.requests.memory
            }
            limits = {
              cpu    = each.value.pilot_resources.limits.cpu
              memory = each.value.pilot_resources.limits.memory
            }
          }
          env = each.value.pilot_env_vars
          traceSampling = each.value.pilot_trace_sampling
        }

        gateways = {
          istio-ingressgateway = {
            enabled = each.value.ingress_gateway_enabled
            type    = each.value.ingress_gateway_type

            resources = {
              requests = {
                cpu    = each.value.gateway_resources.requests.cpu
                memory = each.value.gateway_resources.requests.memory
              }
              limits = {
                cpu    = each.value.gateway_resources.limits.cpu
                memory = each.value.gateway_resources.limits.memory
              }
            }

            autoscaleEnabled = each.value.gateway_autoscale_enabled
            autoscaleMin     = each.value.gateway_autoscale_min
            autoscaleMax     = each.value.gateway_autoscale_max

            secretVolumes = each.value.gateway_secret_volumes
          }

          istio-egressgateway = {
            enabled = each.value.egress_gateway_enabled
            type    = each.value.egress_gateway_type

            resources = {
              requests = {
                cpu    = each.value.gateway_resources.requests.cpu
                memory = each.value.gateway_resources.requests.memory
              }
              limits = {
                cpu    = each.value.gateway_resources.limits.cpu
                memory = each.value.gateway_resources.limits.memory
              }
            }

            autoscaleEnabled = each.value.gateway_autoscale_enabled
            autoscaleMin     = each.value.gateway_autoscale_min
            autoscaleMax     = each.value.gateway_autoscale_max
          }
        }

        security = {
          enableNamespacesByDefault = each.value.security_namespace_default
          workloadCertTtl          = each.value.workload_cert_ttl
        }

        telemetry = {
          v2 = {
            enabled = each.value.telemetry_v2_enabled
            prometheus = {
              configOverride = each.value.prometheus_config_override
            }
            stackdriver = {
              enabled           = each.value.stackdriver_telemetry_enabled
              logging          = each.value.stackdriver_logging_enabled
              monitoring       = each.value.stackdriver_monitoring_enabled
              topology         = each.value.stackdriver_topology_enabled
              disableOutbound  = each.value.stackdriver_disable_outbound
              configOverride   = each.value.stackdriver_config_override
            }
          }
        }
      }

      components = {
        pilot = {
          k8s = {
            env = each.value.pilot_k8s_env
            resources = {
              requests = {
                cpu    = each.value.pilot_resources.requests.cpu
                memory = each.value.pilot_resources.requests.memory
              }
              limits = {
                cpu    = each.value.pilot_resources.limits.cpu
                memory = each.value.pilot_resources.limits.memory
              }
            }
            hpaSpec = {
              minReplicas = each.value.pilot_hpa_min_replicas
              maxReplicas = each.value.pilot_hpa_max_replicas
              metrics = each.value.pilot_hpa_metrics
            }
          }
        }

        ingressGateways = each.value.ingress_gateway_enabled ? [
          {
            name    = "istio-ingressgateway"
            enabled = true
            k8s = {
              service = {
                type = each.value.ingress_gateway_service_type
                ports = each.value.ingress_gateway_ports
                loadBalancerIP = each.value.ingress_gateway_load_balancer_ip
                annotations = each.value.ingress_gateway_service_annotations
              }
              hpaSpec = {
                minReplicas = each.value.gateway_autoscale_min
                maxReplicas = each.value.gateway_autoscale_max
              }
              nodeSelector = each.value.gateway_node_selector
              tolerations  = each.value.gateway_tolerations
              affinity     = each.value.gateway_affinity
            }
          }
        ] : []

        egressGateways = each.value.egress_gateway_enabled ? [
          {
            name    = "istio-egressgateway"
            enabled = true
            k8s = {
              hpaSpec = {
                minReplicas = each.value.gateway_autoscale_min
                maxReplicas = each.value.gateway_autoscale_max
              }
              nodeSelector = each.value.gateway_node_selector
              tolerations  = each.value.gateway_tolerations
              affinity     = each.value.gateway_affinity
            }
          }
        ] : []
      }

      meshConfig = {
        defaultConfig = {
          proxyStatsMatcher = each.value.proxy_stats_matcher
          holdApplicationUntilProxyStarts = each.value.hold_application_until_proxy_starts
          statusPort = each.value.proxy_status_port
          terminationDrainDuration = each.value.termination_drain_duration
        }
        defaultProviders = {
          metrics    = each.value.default_metrics_provider
          tracing    = each.value.default_tracing_provider
          accessLogging = each.value.default_access_logging_provider
        }
        extensionProviders = each.value.extension_providers
        trustDomain = each.value.trust_domain
        caCertificates = each.value.ca_certificates
      }
    }
  }

  depends_on = [
    kubernetes_namespace.istio_system
  ]
}

# Istio Gateway configurations
resource "kubernetes_manifest" "istio_gateways" {
  for_each = var.istio_gateways

  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "Gateway"
    metadata = {
      name      = each.key
      namespace = each.value.namespace
      labels = merge(var.labels, each.value.labels)
    }
    spec = {
      selector = each.value.selector
      servers = [
        for server in each.value.servers : {
          port = {
            number   = server.port.number
            name     = server.port.name
            protocol = server.port.protocol
          }
          hosts = server.hosts
          tls = server.tls != null ? {
            mode           = server.tls.mode
            credentialName = server.tls.credential_name
            serverCertificate = server.tls.server_certificate
            privateKey     = server.tls.private_key
            caCertificates = server.tls.ca_certificates
            minProtocolVersion = server.tls.min_protocol_version
            maxProtocolVersion = server.tls.max_protocol_version
            cipherSuites   = server.tls.cipher_suites
          } : null
        }
      ]
    }
  }

  depends_on = [
    kubernetes_manifest.istio_control_plane
  ]
}

# Virtual Service configurations
resource "kubernetes_manifest" "virtual_services" {
  for_each = var.virtual_services

  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "VirtualService"
    metadata = {
      name      = each.key
      namespace = each.value.namespace
      labels = merge(var.labels, each.value.labels)
    }
    spec = {
      hosts    = each.value.hosts
      gateways = each.value.gateways

      http = [
        for http_route in each.value.http_routes : {
          name = http_route.name
          match = [
            for match in http_route.matches : {
              uri = match.uri != null ? {
                exact  = match.uri.exact
                prefix = match.uri.prefix
                regex  = match.uri.regex
              } : null
              headers = match.headers
              queryParams = match.query_params
              method = match.method
            }
          ]
          route = [
            for route in http_route.routes : {
              destination = {
                host   = route.destination.host
                subset = route.destination.subset
                port = route.destination.port != null ? {
                  number = route.destination.port.number
                } : null
              }
              weight = route.weight
              headers = route.headers != null ? {
                request = route.headers.request
                response = route.headers.response
              } : null
            }
          ]
          redirect = http_route.redirect != null ? {
            uri        = http_route.redirect.uri
            authority  = http_route.redirect.authority
            redirectCode = http_route.redirect.redirect_code
          } : null
          rewrite = http_route.rewrite != null ? {
            uri       = http_route.rewrite.uri
            authority = http_route.rewrite.authority
          } : null
          timeout = http_route.timeout
          retries = http_route.retries != null ? {
            attempts      = http_route.retries.attempts
            perTryTimeout = http_route.retries.per_try_timeout
            retryOn       = http_route.retries.retry_on
          } : null
          fault = http_route.fault != null ? {
            delay = http_route.fault.delay != null ? {
              percentage = http_route.fault.delay.percentage
              fixedDelay = http_route.fault.delay.fixed_delay
            } : null
            abort = http_route.fault.abort != null ? {
              percentage = http_route.fault.abort.percentage
              httpStatus = http_route.fault.abort.http_status
            } : null
          } : null
          mirror = http_route.mirror != null ? {
            host   = http_route.mirror.host
            subset = http_route.mirror.subset
          } : null
          corsPolicy = http_route.cors_policy != null ? {
            allowOrigins = http_route.cors_policy.allow_origins
            allowMethods = http_route.cors_policy.allow_methods
            allowHeaders = http_route.cors_policy.allow_headers
            exposeHeaders = http_route.cors_policy.expose_headers
            maxAge       = http_route.cors_policy.max_age
            allowCredentials = http_route.cors_policy.allow_credentials
          } : null
        }
      ]

      tcp = [
        for tcp_route in each.value.tcp_routes : {
          match = [
            for match in tcp_route.matches : {
              destinationSubnets = match.destination_subnets
              port              = match.port
              sourceLabels      = match.source_labels
              gateways          = match.gateways
            }
          ]
          route = [
            for route in tcp_route.routes : {
              destination = {
                host   = route.destination.host
                subset = route.destination.subset
                port = route.destination.port != null ? {
                  number = route.destination.port.number
                } : null
              }
              weight = route.weight
            }
          ]
        }
      ]

      tls = [
        for tls_route in each.value.tls_routes : {
          match = [
            for match in tls_route.matches : {
              sniHosts          = match.sni_hosts
              destinationSubnets = match.destination_subnets
              port              = match.port
              sourceLabels      = match.source_labels
              gateways          = match.gateways
            }
          ]
          route = [
            for route in tls_route.routes : {
              destination = {
                host   = route.destination.host
                subset = route.destination.subset
                port = route.destination.port != null ? {
                  number = route.destination.port.number
                } : null
              }
              weight = route.weight
            }
          ]
        }
      ]
    }
  }

  depends_on = [
    kubernetes_manifest.istio_gateways
  ]
}

# Destination Rule configurations
resource "kubernetes_manifest" "destination_rules" {
  for_each = var.destination_rules

  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "DestinationRule"
    metadata = {
      name      = each.key
      namespace = each.value.namespace
      labels = merge(var.labels, each.value.labels)
    }
    spec = {
      host = each.value.host

      trafficPolicy = each.value.traffic_policy != null ? {
        loadBalancer = each.value.traffic_policy.load_balancer != null ? {
          simple = each.value.traffic_policy.load_balancer.simple
          consistentHash = each.value.traffic_policy.load_balancer.consistent_hash != null ? {
            httpHeaderName  = each.value.traffic_policy.load_balancer.consistent_hash.http_header_name
            httpCookieName  = each.value.traffic_policy.load_balancer.consistent_hash.http_cookie_name
            useSourceIp     = each.value.traffic_policy.load_balancer.consistent_hash.use_source_ip
            minimumRingSize = each.value.traffic_policy.load_balancer.consistent_hash.minimum_ring_size
          } : null
        } : null

        connectionPool = each.value.traffic_policy.connection_pool != null ? {
          tcp = each.value.traffic_policy.connection_pool.tcp != null ? {
            maxConnections = each.value.traffic_policy.connection_pool.tcp.max_connections
            connectTimeout = each.value.traffic_policy.connection_pool.tcp.connect_timeout
            tcpKeepalive = each.value.traffic_policy.connection_pool.tcp.tcp_keepalive != null ? {
              time     = each.value.traffic_policy.connection_pool.tcp.tcp_keepalive.time
              interval = each.value.traffic_policy.connection_pool.tcp.tcp_keepalive.interval
              probes   = each.value.traffic_policy.connection_pool.tcp.tcp_keepalive.probes
            } : null
          } : null

          http = each.value.traffic_policy.connection_pool.http != null ? {
            http1MaxPendingRequests  = each.value.traffic_policy.connection_pool.http.http1_max_pending_requests
            http2MaxRequests        = each.value.traffic_policy.connection_pool.http.http2_max_requests
            maxRequestsPerConnection = each.value.traffic_policy.connection_pool.http.max_requests_per_connection
            maxRetries              = each.value.traffic_policy.connection_pool.http.max_retries
            idleTimeout             = each.value.traffic_policy.connection_pool.http.idle_timeout
            h2UpgradePolicy         = each.value.traffic_policy.connection_pool.http.h2_upgrade_policy
          } : null
        } : null

        outlierDetection = each.value.traffic_policy.outlier_detection != null ? {
          consecutiveErrors         = each.value.traffic_policy.outlier_detection.consecutive_errors
          consecutiveGatewayErrors  = each.value.traffic_policy.outlier_detection.consecutive_gateway_errors
          consecutive5xxErrors      = each.value.traffic_policy.outlier_detection.consecutive_5xx_errors
          interval                 = each.value.traffic_policy.outlier_detection.interval
          baseEjectionTime         = each.value.traffic_policy.outlier_detection.base_ejection_time
          maxEjectionPercent       = each.value.traffic_policy.outlier_detection.max_ejection_percent
          minHealthPercent         = each.value.traffic_policy.outlier_detection.min_health_percent
        } : null

        tls = each.value.traffic_policy.tls != null ? {
          mode              = each.value.traffic_policy.tls.mode
          clientCertificate = each.value.traffic_policy.tls.client_certificate
          privateKey        = each.value.traffic_policy.tls.private_key
          caCertificates    = each.value.traffic_policy.tls.ca_certificates
          credentialName    = each.value.traffic_policy.tls.credential_name
          subjectAltNames   = each.value.traffic_policy.tls.subject_alt_names
          sni              = each.value.traffic_policy.tls.sni
        } : null
      } : null

      subsets = [
        for subset in each.value.subsets : {
          name   = subset.name
          labels = subset.labels
          trafficPolicy = subset.traffic_policy != null ? {
            loadBalancer = subset.traffic_policy.load_balancer != null ? {
              simple = subset.traffic_policy.load_balancer.simple
            } : null
            connectionPool = subset.traffic_policy.connection_pool != null ? {
              tcp = subset.traffic_policy.connection_pool.tcp != null ? {
                maxConnections = subset.traffic_policy.connection_pool.tcp.max_connections
                connectTimeout = subset.traffic_policy.connection_pool.tcp.connect_timeout
              } : null
              http = subset.traffic_policy.connection_pool.http != null ? {
                http1MaxPendingRequests = subset.traffic_policy.connection_pool.http.http1_max_pending_requests
                http2MaxRequests       = subset.traffic_policy.connection_pool.http.http2_max_requests
              } : null
            } : null
          } : null
        }
      ]

      exportTo = each.value.export_to
    }
  }

  depends_on = [
    kubernetes_manifest.virtual_services
  ]
}

# Service Entry configurations for external services
resource "kubernetes_manifest" "service_entries" {
  for_each = var.service_entries

  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "ServiceEntry"
    metadata = {
      name      = each.key
      namespace = each.value.namespace
      labels = merge(var.labels, each.value.labels)
    }
    spec = {
      hosts     = each.value.hosts
      ports = [
        for port in each.value.ports : {
          number   = port.number
          name     = port.name
          protocol = port.protocol
        }
      ]
      location   = each.value.location
      resolution = each.value.resolution

      addresses = each.value.addresses

      endpoints = [
        for endpoint in each.value.endpoints : {
          address = endpoint.address
          ports   = endpoint.ports
          labels  = endpoint.labels
          network = endpoint.network
          locality = endpoint.locality
          weight  = endpoint.weight
        }
      ]

      workloadSelector = each.value.workload_selector != null ? {
        labels = each.value.workload_selector.labels
      } : null
    }
  }

  depends_on = [
    kubernetes_manifest.destination_rules
  ]
}

# Sidecar configurations
resource "kubernetes_manifest" "sidecars" {
  for_each = var.sidecar_configs

  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "Sidecar"
    metadata = {
      name      = each.key
      namespace = each.value.namespace
      labels = merge(var.labels, each.value.labels)
    }
    spec = {
      workloadSelector = each.value.workload_selector != null ? {
        labels = each.value.workload_selector.labels
      } : null

      ingress = [
        for ingress in each.value.ingress : {
          port = {
            number       = ingress.port.number
            protocol     = ingress.port.protocol
            name         = ingress.port.name
            targetPort   = ingress.port.target_port
          }
          bind             = ingress.bind
          captureMode      = ingress.capture_mode
          defaultEndpoint  = ingress.default_endpoint
        }
      ]

      egress = [
        for egress in each.value.egress : {
          port = egress.port != null ? {
            number   = egress.port.number
            protocol = egress.port.protocol
            name     = egress.port.name
          } : null
          bind        = egress.bind
          captureMode = egress.capture_mode
          hosts       = egress.hosts
        }
      ]

      outboundTrafficPolicy = each.value.outbound_traffic_policy != null ? {
        mode = each.value.outbound_traffic_policy.mode
        egressProxy = each.value.outbound_traffic_policy.egress_proxy != null ? {
          host   = each.value.outbound_traffic_policy.egress_proxy.host
          subset = each.value.outbound_traffic_policy.egress_proxy.subset
          port = each.value.outbound_traffic_policy.egress_proxy.port != null ? {
            number = each.value.outbound_traffic_policy.egress_proxy.port.number
          } : null
        } : null
      } : null
    }
  }

  depends_on = [
    kubernetes_manifest.service_entries
  ]
}

# Security policies - PeerAuthentication
resource "kubernetes_manifest" "peer_authentications" {
  for_each = var.peer_authentications

  manifest = {
    apiVersion = "security.istio.io/v1beta1"
    kind       = "PeerAuthentication"
    metadata = {
      name      = each.key
      namespace = each.value.namespace
      labels = merge(var.labels, each.value.labels)
    }
    spec = {
      selector = each.value.selector != null ? {
        matchLabels = each.value.selector.match_labels
      } : null

      mtls = each.value.mtls != null ? {
        mode = each.value.mtls.mode
      } : null

      portLevelMtls = {
        for port, mtls_config in each.value.port_level_mtls : port => {
          mode = mtls_config.mode
        }
      }
    }
  }

  depends_on = [
    kubernetes_manifest.sidecars
  ]
}

# Security policies - AuthorizationPolicy
resource "kubernetes_manifest" "authorization_policies" {
  for_each = var.authorization_policies

  manifest = {
    apiVersion = "security.istio.io/v1beta1"
    kind       = "AuthorizationPolicy"
    metadata = {
      name      = each.key
      namespace = each.value.namespace
      labels = merge(var.labels, each.value.labels)
    }
    spec = {
      selector = each.value.selector != null ? {
        matchLabels = each.value.selector.match_labels
      } : null

      action = each.value.action

      rules = [
        for rule in each.value.rules : {
          from = rule.from != null ? [
            for from_rule in rule.from : {
              source = from_rule.source != null ? {
                principals      = from_rule.source.principals
                requestPrincipals = from_rule.source.request_principals
                namespaces      = from_rule.source.namespaces
                ipBlocks        = from_rule.source.ip_blocks
                remoteIpBlocks  = from_rule.source.remote_ip_blocks
              } : null
            }
          ] : null

          to = rule.to != null ? [
            for to_rule in rule.to : {
              operation = to_rule.operation != null ? {
                methods = to_rule.operation.methods
                hosts   = to_rule.operation.hosts
                ports   = to_rule.operation.ports
                paths   = to_rule.operation.paths
              } : null
            }
          ] : null

          when = rule.when != null ? [
            for when_condition in rule.when : {
              key    = when_condition.key
              values = when_condition.values
              notValues = when_condition.not_values
            }
          ] : null
        }
      ]
    }
  }

  depends_on = [
    kubernetes_manifest.peer_authentications
  ]
}

# Telemetry configurations
resource "kubernetes_manifest" "telemetry_configs" {
  for_each = var.telemetry_configs

  manifest = {
    apiVersion = "telemetry.istio.io/v1alpha1"
    kind       = "Telemetry"
    metadata = {
      name      = each.key
      namespace = each.value.namespace
      labels = merge(var.labels, each.value.labels)
    }
    spec = {
      selector = each.value.selector != null ? {
        matchLabels = each.value.selector.match_labels
      } : null

      metrics = [
        for metric in each.value.metrics : {
          providers = [
            for provider in metric.providers : {
              name = provider.name
            }
          ]
          overrides = [
            for override in metric.overrides : {
              match = override.match != null ? {
                metric = override.match.metric
                mode   = override.match.mode
              } : null
              disabled = override.disabled
              tags = {
                for tag_key, tag_config in override.tags : tag_key => {
                  value     = tag_config.value
                  operation = tag_config.operation
                }
              }
            }
          ]
        }
      ]

      tracing = [
        for tracing in each.value.tracing : {
          providers = [
            for provider in tracing.providers : {
              name = provider.name
            }
          ]
          randomSamplingPercentage = tracing.random_sampling_percentage
          customTags = {
            for tag_key, tag_config in tracing.custom_tags : tag_key => {
              literal = tag_config.literal
              environment = tag_config.environment
              header = tag_config.header != null ? {
                name         = tag_config.header.name
                defaultValue = tag_config.header.default_value
              } : null
            }
          }
        }
      ]

      accessLogging = [
        for access_logging in each.value.access_logging : {
          providers = [
            for provider in access_logging.providers : {
              name = provider.name
            }
          ]
          match = access_logging.match != null ? {
            mode = access_logging.match.mode
          } : null
          filter = access_logging.filter != null ? {
            expression = access_logging.filter.expression
          } : null
        }
      ]
    }
  }

  depends_on = [
    kubernetes_manifest.authorization_policies
  ]
}

# Service account for ASM operations
resource "google_service_account" "asm_sa" {
  count = var.create_service_account ? 1 : 0

  account_id   = var.service_account_id
  display_name = "Anthos Service Mesh Service Account"
  description  = "Service account for Anthos Service Mesh operations and management"
  project      = var.project_id
}

# IAM roles for the service account
resource "google_project_iam_member" "asm_sa_roles" {
  for_each = var.create_service_account ? toset(var.service_account_roles) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.asm_sa[0].email}"

  depends_on = [
    google_service_account.asm_sa
  ]
}

# Monitoring dashboard for Anthos Service Mesh
resource "google_monitoring_dashboard" "asm_dashboard" {
  count = var.enable_monitoring && var.create_dashboard ? 1 : 0

  dashboard_json = jsonencode({
    displayName = var.dashboard_display_name
    mosaicLayout = {
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Service Mesh Request Rate"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"k8s_container\" AND metric.type=\"istio.io/service/server/request_count\""
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Requests/sec"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Service Mesh Error Rate"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"k8s_container\" AND metric.type=\"istio.io/service/server/response_latencies\""
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Latency (ms)"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "mTLS Certificate Status"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"k8s_container\" AND metric.type=\"istio.io/galley/endpoint_no_pod\""
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Count"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Envoy Proxy Memory Usage"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/memory/used_bytes\" AND metadata.user_labels.app=\"istio-proxy\""
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Memory (bytes)"
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
    google_project_service.asm_apis
  ]
}

# Alert policies for Anthos Service Mesh monitoring
resource "google_monitoring_alert_policy" "asm_alerts" {
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
    google_project_service.asm_apis
  ]
}

# Log sink for Anthos Service Mesh audit logs
resource "google_logging_project_sink" "asm_audit_sink" {
  count = var.enable_audit_logging ? 1 : 0

  name        = var.audit_log_sink_name
  destination = var.audit_log_destination

  filter = join(" OR ", [
    "resource.type=\"k8s_cluster\"",
    "resource.type=\"gke_cluster\"",
    "protoPayload.serviceName=\"mesh.googleapis.com\"",
    "protoPayload.serviceName=\"gkehub.googleapis.com\"",
    "labels.\"k8s-pod/app\"=\"istiod\"",
    "labels.\"k8s-pod/app\"=\"istio-proxy\""
  ])

  unique_writer_identity = true
  project               = var.project_id

  depends_on = [
    google_project_service.asm_apis
  ]
}

# Local values for data processing
locals {
  # All cluster membership names
  all_cluster_memberships = keys(var.cluster_memberships)

  # Service mesh membership to cluster mapping
  membership_cluster_map = {
    for membership_name, membership_config in var.service_mesh_memberships :
    membership_name => membership_config.membership_name
  }

  # Gateway to namespace mapping
  gateway_namespace_map = {
    for gateway_name, gateway_config in var.istio_gateways :
    gateway_name => gateway_config.namespace
  }

  # Default Istio configuration values
  default_istio_config = {
    hub = "gcr.io/istio-release"
    tag = "1.18.2-asm.3"
    mesh_id = "mesh-${var.project_id}"
    network = "default"
    trust_domain = var.project_id
  }

  # Common resource requirements
  default_resources = {
    pilot = {
      requests = { cpu = "100m", memory = "128Mi" }
      limits   = { cpu = "500m", memory = "512Mi" }
    }
    proxy = {
      requests = { cpu = "100m", memory = "128Mi" }
      limits   = { cpu = "2000m", memory = "1Gi" }
    }
    gateway = {
      requests = { cpu = "100m", memory = "128Mi" }
      limits   = { cpu = "2000m", memory = "1Gi" }
    }
  }
}