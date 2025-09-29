# SSL Certificates Configuration for Production - US Central 1
# Enterprise-grade SSL/TLS certificate management with automatic renewal and monitoring

terraform {
  source = "${get_repo_root()}/modules/security/ssl-certificates"
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

# SSL Certificates depends on Secret Manager for private keys
dependency "secret_manager" {
  config_path = "../secret-manager"
  skip_outputs = true

  mock_outputs = {
    secrets = {
      ssl_certificates = {
        id = "mock-ssl-secret-id"
        secret_id = "mock-ssl-secret"
      }
    }
  }
}

# SSL Certificates depends on DNS for domain validation
dependency "dns" {
  config_path = "../../networking/dns"
  skip_outputs = true

  mock_outputs = {
    managed_zones = {
      main = {
        name = "mock-zone"
        dns_name = "example.com."
      }
    }
  }
}

# Prevent accidental destruction of production certificates
prevent_destroy = true

locals {
  # Extract configuration from includes
  env_config    = include.env.locals
  region_config = include.region.locals

  # Certificate naming prefix
  cert_prefix = "${local.env_config.environment}-${local.region_config.region_short}"

  # Domain configuration based on environment
  domain_config = {
    primary_domain = local.env_config.environment == "prod" ? "example.com" : "${local.env_config.environment}.example.com"
    wildcard_domain = local.env_config.environment == "prod" ? "*.example.com" : "*.${local.env_config.environment}.example.com"

    san_domains = local.env_config.environment == "prod" ? [
      "www.example.com",
      "api.example.com",
      "admin.example.com",
      "app.example.com",
      "dashboard.example.com",
      "metrics.example.com",
      "grafana.example.com",
      "kibana.example.com"
    ] : [
      "www.${local.env_config.environment}.example.com",
      "api.${local.env_config.environment}.example.com",
      "app.${local.env_config.environment}.example.com"
    ]

    regional_domains = local.env_config.environment == "prod" ? {
      "us-central1" = ["us.example.com", "*.us.example.com"]
      "us-east1" = ["us-east.example.com", "*.us-east.example.com"]
      "europe-west1" = ["eu.example.com", "*.eu.example.com"]
      "asia-southeast1" = ["asia.example.com", "*.asia.example.com"]
    } : {}
  }

  # Managed SSL Certificates (Google-managed)
  managed_certificates = {
    # Primary domain certificate
    main = {
      name = "${local.cert_prefix}-main-cert"
      description = "Main SSL certificate for ${local.domain_config.primary_domain}"

      managed = {
        domains = [local.domain_config.primary_domain, "www.${local.domain_config.primary_domain}"]
      }

      labels = {
        type = "managed"
        domain = "main"
        auto_renewal = "true"
      }

      lifecycle_config = {
        auto_renew = true
        renewal_days_before_expiry = 30
      }

      scope = "GLOBAL"
      project = var.project_id
    }

    # Wildcard certificate
    wildcard = {
      name = "${local.cert_prefix}-wildcard-cert"
      description = "Wildcard SSL certificate for ${local.domain_config.wildcard_domain}"

      managed = {
        domains = [local.domain_config.wildcard_domain]
      }

      labels = {
        type = "managed"
        domain = "wildcard"
        auto_renewal = "true"
      }

      scope = "GLOBAL"
    }

    # API certificate
    api = {
      name = "${local.cert_prefix}-api-cert"
      description = "API SSL certificate"

      managed = {
        domains = ["api.${local.domain_config.primary_domain}"]
      }

      labels = {
        type = "managed"
        domain = "api"
        service = "api"
      }

      scope = "GLOBAL"
    }
  }

  # Self-managed SSL Certificates (customer-provided)
  self_managed_certificates = local.env_config.environment == "prod" ? {
    # Custom certificate for special requirements
    custom = {
      name = "${local.cert_prefix}-custom-cert"
      description = "Custom SSL certificate with EV validation"

      certificate = file("${path.module}/certs/custom.crt")
      private_key = file("${path.module}/certs/custom.key")
      certificate_chain = file("${path.module}/certs/custom-chain.crt")

      labels = {
        type = "self_managed"
        validation = "ev"
        provider = "digicert"
      }

      lifecycle_config = {
        expiration_time = "2025-12-31T23:59:59Z"
        rotation_period = "8640000s" # 100 days
      }

      scope = "GLOBAL"
    }

    # Multi-domain certificate
    multi_domain = {
      name = "${local.cert_prefix}-multi-domain-cert"
      description = "Multi-domain SSL certificate"

      certificate = file("${path.module}/certs/multi-domain.crt")
      private_key = file("${path.module}/certs/multi-domain.key")

      subject_alternative_names = local.domain_config.san_domains

      labels = {
        type = "self_managed"
        validation = "dv"
        provider = "letsencrypt"
      }

      scope = "GLOBAL"
    }
  } : {}

  # Regional SSL Certificates (for regional load balancers)
  regional_certificates = {
    internal = {
      name = "${local.cert_prefix}-internal-cert"
      description = "Internal SSL certificate for private endpoints"
      region = local.region_config.region

      certificate = file("${path.module}/certs/internal.crt")
      private_key = file("${path.module}/certs/internal.key")

      labels = {
        type = "regional"
        usage = "internal"
      }

      scope = "REGIONAL"
    }
  }

  # Certificate Authority Service certificates (CAS)
  cas_certificates = local.env_config.environment == "prod" ? {
    internal_ca = {
      name = "${local.cert_prefix}-internal-ca"
      description = "Internal Certificate Authority"

      ca_pool = {
        name = "${local.cert_prefix}-ca-pool"
        tier = "ENTERPRISE"

        issuance_policy = {
          allowed_key_types = [
            {
              rsa = {
                min_modulus_size = 2048
                max_modulus_size = 4096
              }
            },
            {
              elliptic_curve = {
                signature_algorithm = "ECDSA_P256"
              }
            }
          ]

          maximum_lifetime = "315360000s" # 10 years

          allowed_issuance_modes = {
            allow_csr_based_issuance = true
            allow_config_based_issuance = true
          }

          identity_constraints = {
            allow_subject_passthrough = true
            allow_subject_alt_names_passthrough = true

            cel_expression = {
              expression = "subject.country_code == 'US'"
              title = "US Only"
              description = "Only issue certificates for US entities"
            }
          }

          baseline_values = {
            key_usage = {
              base_key_usage = {
                digital_signature = true
                key_encipherment = true
              }
              extended_key_usage = {
                server_auth = true
                client_auth = true
              }
            }

            ca_options = {
              is_ca = false
              max_issuer_path_length = 0
            }
          }
        }

        publishing_options = {
          publish_ca_cert = true
          publish_crl = true
        }
      }

      labels = {
        type = "cas"
        usage = "internal"
        tier = "enterprise"
      }
    }

    code_signing_ca = {
      name = "${local.cert_prefix}-code-signing-ca"
      description = "Code Signing Certificate Authority"

      ca_pool = {
        name = "${local.cert_prefix}-code-signing-pool"
        tier = "DEVOPS"

        issuance_policy = {
          maximum_lifetime = "94608000s" # 3 years

          baseline_values = {
            key_usage = {
              base_key_usage = {
                digital_signature = true
              }
              extended_key_usage = {
                code_signing = true
              }
            }
          }
        }
      }

      labels = {
        type = "cas"
        usage = "code_signing"
      }
    }
  } : {}

  # SSL Policies (for configuring SSL features)
  ssl_policies = {
    modern = {
      name = "${local.cert_prefix}-ssl-policy-modern"
      description = "Modern SSL policy with strong ciphers only"

      min_tls_version = "TLS_1_2"
      profile = "MODERN"

      custom_features = []

      labels = {
        profile = "modern"
        strength = "strong"
      }
    }

    compatible = {
      name = "${local.cert_prefix}-ssl-policy-compatible"
      description = "Compatible SSL policy for broader client support"

      min_tls_version = "TLS_1_0"
      profile = "COMPATIBLE"

      labels = {
        profile = "compatible"
        strength = "medium"
      }
    }

    restricted = {
      name = "${local.cert_prefix}-ssl-policy-restricted"
      description = "Restricted SSL policy with only approved ciphers"

      min_tls_version = "TLS_1_3"
      profile = "RESTRICTED"

      custom_features = local.env_config.environment == "prod" ? [
        "TLS_AES_128_GCM_SHA256",
        "TLS_AES_256_GCM_SHA384",
        "TLS_CHACHA20_POLY1305_SHA256"
      ] : []

      labels = {
        profile = "restricted"
        strength = "maximum"
        compliance = "fips"
      }
    }
  }

  # Certificate validation configuration
  validation_config = {
    # DNS validation
    dns_validation = {
      enabled = true

      dns_records = {
        for cert_name, cert in local.managed_certificates : cert_name => {
          name = "_acme-challenge.${cert.managed.domains[0]}"
          type = "TXT"
          ttl = 300
          managed_zone = try(dependency.dns.outputs.managed_zones.main.name, "")
        }
      }

      auto_validate = true
      validation_timeout = "3600s"
    }

    # HTTP validation
    http_validation = {
      enabled = false  # Using DNS validation instead

      well_known_path = "/.well-known/acme-challenge/"
      validation_timeout = "1800s"
    }
  }

  # Certificate monitoring and alerting
  monitoring_config = {
    alerts = {
      certificate_expiring_soon = {
        display_name = "SSL Certificate Expiring Soon"
        conditions = {
          days_before_expiry = 30
          severity = "warning"
        }
      }

      certificate_expired = {
        display_name = "SSL Certificate Expired"
        conditions = {
          alert_immediately = true
          severity = "critical"
        }
      }

      certificate_validation_failed = {
        display_name = "SSL Certificate Validation Failed"
        conditions = {
          alert_immediately = true
          severity = "high"
        }
      }

      certificate_renewal_failed = {
        display_name = "SSL Certificate Renewal Failed"
        conditions = {
          alert_immediately = true
          severity = "critical"
        }
      }

      weak_cipher_detected = {
        display_name = "Weak SSL Cipher Detected"
        conditions = {
          alert_immediately = true
          severity = "medium"
        }
      }

      ssl_protocol_downgrade = {
        display_name = "SSL Protocol Downgrade Detected"
        conditions = {
          threshold_count = 10
          duration = "300s"
          severity = "high"
        }
      }
    }

    metrics = {
      certificate_expiry_days = {
        metric = "ssl.googleapis.com/certificate/days_until_expiry"
        aggregation = "ALIGN_MIN"
      }

      ssl_handshake_latency = {
        metric = "ssl.googleapis.com/handshake/latency"
        aggregation = "ALIGN_MEAN"
      }

      cipher_usage = {
        metric = "ssl.googleapis.com/cipher/usage_count"
        aggregation = "ALIGN_RATE"
      }
    }

    dashboard = {
      display_name = "SSL Certificates Dashboard - ${local.env_config.environment}"

      widgets = [
        {
          title = "Certificate Expiry Status"
          type = "scorecard"
          metric = "certificate_expiry_days"
        },
        {
          title = "SSL Handshake Performance"
          type = "line_chart"
          metric = "ssl_handshake_latency"
        },
        {
          title = "Cipher Suite Usage"
          type = "pie_chart"
          metric = "cipher_usage"
        },
        {
          title = "Certificate Validation Status"
          type = "table"
          metric = "validation_status"
        }
      ]
    }
  }

  # Certificate rotation configuration
  rotation_config = {
    enable_auto_rotation = true

    rotation_schedule = {
      frequency = "MONTHLY"
      days_before_expiry = 30
    }

    rotation_strategy = {
      type = "BLUE_GREEN"

      blue_green = {
        traffic_split_duration = "3600s"
        rollback_on_failure = true
        health_check_interval = "30s"
      }
    }

    notification_config = {
      notify_days_before = [60, 30, 14, 7, 1]

      channels = local.env_config.environment == "prod" ? [
        "email:security-team@${local.env_config.organization_domain}",
        "slack:#security-alerts",
        "pagerduty:ssl-rotation"
      ] : [
        "email:platform-team@${local.env_config.organization_domain}"
      ]
    }
  }

  # Compliance and security configuration
  compliance_config = {
    # Standards compliance
    standards = local.env_config.environment == "prod" ? [
      "PCI_DSS_3_2",
      "NIST_800_52",
      "FIPS_140_2"
    ] : []

    # Security requirements
    security_requirements = {
      min_key_size = 2048
      max_certificate_lifetime = "397d"  # 397 days max for public trust

      required_key_usage = [
        "digital_signature",
        "key_encipherment"
      ]

      required_extended_key_usage = [
        "server_auth",
        "client_auth"
      ]

      prohibited_algorithms = [
        "SHA1",
        "MD5",
        "RC4"
      ]

      required_san_validation = true
      require_ct_logs = true  # Certificate Transparency
      require_ocsp_stapling = true
      require_must_staple = local.env_config.environment == "prod"
    }

    # Audit requirements
    audit_config = {
      log_all_operations = true
      log_certificate_details = true
      retention_days = local.env_config.environment == "prod" ? 2555 : 365
    }
  }

  # Integration configuration
  integrations = {
    # Load Balancer integration
    load_balancer = {
      enabled = true

      target_https_proxies = [
        "${local.cert_prefix}-https-proxy"
      ]

      target_ssl_proxies = [
        "${local.cert_prefix}-ssl-proxy"
      ]

      ssl_certificates_per_proxy = 15  # Max 15 certificates per proxy
    }

    # CDN integration
    cdn = {
      enabled = true

      edge_certificates = {
        provision_edge_certificates = true
        auto_provision_subdomains = true
      }
    }

    # Cloud Armor integration
    cloud_armor = {
      enabled = true

      ssl_inspection = {
        enable_deep_inspection = local.env_config.environment == "prod"
        inspect_encrypted_traffic = true
      }
    }
  }

  # Backup and recovery configuration
  backup_config = {
    enable_backup = local.env_config.environment == "prod"

    backup_schedule = {
      frequency = "DAILY"
      retention_days = 90
    }

    backup_location = {
      type = "GCS"
      bucket = "${var.project_id}-ssl-certificate-backups"
      encryption = "CMEK"
    }

    recovery_config = {
      enable_point_in_time_recovery = true
      recovery_window_days = 7
    }
  }

  # Cost optimization
  cost_optimization = {
    # Use managed certificates where possible (free)
    prefer_managed_certificates = true

    # Consolidate certificates
    use_wildcard_certificates = true
    use_san_certificates = true
    max_domains_per_certificate = 100

    # Certificate pooling
    enable_certificate_pooling = true
    pool_size = local.env_config.environment == "prod" ? 10 : 3

    # Automatic cleanup
    auto_delete_expired = local.env_config.environment != "prod"
    expired_retention_days = 30
  }
}

# Module inputs
inputs = {
  # Project configuration
  project_id = var.project_id
  region     = local.region_config.region

  # Managed certificates
  managed_certificates = local.managed_certificates

  # Self-managed certificates
  self_managed_certificates = local.self_managed_certificates

  # Regional certificates
  regional_certificates = local.regional_certificates

  # Certificate Authority Service
  cas_certificates = local.cas_certificates

  # SSL policies
  ssl_policies = local.ssl_policies

  # Validation configuration
  validation_config = local.validation_config

  # Rotation configuration
  rotation_config = local.rotation_config

  # Monitoring configuration
  monitoring_config = local.monitoring_config
  enable_monitoring = true
  create_monitoring_dashboard = local.env_config.environment == "prod"
  create_monitoring_alerts = local.env_config.environment != "dev"

  # Compliance configuration
  compliance_config = local.compliance_config

  # Integration configuration
  integrations = local.integrations

  # Backup configuration
  backup_config = local.backup_config

  # Cost optimization
  cost_optimization = local.cost_optimization

  # Security configuration
  security_config = {
    enable_certificate_transparency = true
    enable_ocsp_stapling = true
    enable_hsts = true
    hsts_max_age = 31536000
    hsts_include_subdomains = true
    hsts_preload = local.env_config.environment == "prod"
  }

  # Labels
  labels = merge(
    var.common_labels,
    {
      component = "security"
      service   = "ssl-certificates"
      tier      = "edge"
    }
  )

  # Dependencies
  depends_on = [dependency.secret_manager, dependency.dns]
}