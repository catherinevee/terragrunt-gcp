# Cloud Armor Configuration for Production - US Central 1
# Enterprise-grade DDoS protection, WAF rules, and security policies for load balancers

terraform {
  source = "${get_repo_root()}/modules/security/cloud-armor"
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

# Cloud Armor depends on Load Balancer for backend services
dependency "load_balancer" {
  config_path = "../../networking/load-balancer"
  skip_outputs = true

  mock_outputs = {
    backend_services = {
      web = {
        id = "mock-backend-service-web"
        self_link = "projects/mock/global/backendServices/web"
      }
      api = {
        id = "mock-backend-service-api"
        self_link = "projects/mock/global/backendServices/api"
      }
    }
  }
}

# Prevent accidental destruction of production security policies
prevent_destroy = true

locals {
  # Extract configuration from includes
  env_config    = include.env.locals
  region_config = include.region.locals

  # Policy naming prefix
  policy_prefix = "${local.env_config.environment}-${local.region_config.region_short}"

  # IP allowlists and denylists based on environment
  ip_lists = {
    # Office and VPN IP ranges
    office_ips = [
      "203.0.113.0/24",  # Main office
      "198.51.100.0/24", # Branch office
      "192.0.2.0/24"     # VPN range
    ]

    # Known malicious IPs (example)
    blocked_ips = [
      "10.0.0.0/8",      # Private ranges should not hit public endpoints
      "172.16.0.0/12",
      "192.168.0.0/16"
    ]

    # Trusted third-party services
    trusted_services = [
      "35.235.240.0/20", # Google Cloud IAP
      "35.191.0.0/16",   # Google Health Checks
      "130.211.0.0/22"   # Google Cloud Load Balancer
    ]

    # Geographic restrictions (country codes)
    allowed_countries = local.env_config.environment == "prod" ? [
      "US", "CA", "GB", "DE", "FR", "JP", "AU", "SG"
    ] : []

    denied_countries = local.env_config.environment == "prod" ? [
      "KP", "IR", "SY", "CU"  # Sanctioned countries
    ] : []
  }

  # Security policies configuration
  security_policies = {
    # Main web application policy
    main_web_policy = {
      name        = "${local.policy_prefix}-web-security-policy"
      description = "Main security policy for web applications in ${local.env_config.environment}"
      type        = "CLOUD_ARMOR"

      # Adaptive protection configuration
      adaptive_protection_config = {
        layer_7_ddos_defense_config = {
          enable = true
          rule_visibility = local.env_config.environment == "prod" ? "STANDARD" : "PREMIUM"

          threshold_configs = [
            {
              name = "high_traffic_threshold"
              auto_deploy_load_threshold = 0.7
              auto_deploy_confidence_threshold = 0.8
              auto_deploy_impacted_baseline_threshold = 0.5
              auto_deploy_expiration_sec = 7200
            }
          ]
        }

        auto_deploy_config = {
          load_threshold = 0.8
          confidence_threshold = 0.9
          impacted_baseline_threshold = 0.5
          expiration_sec = 3600
        }
      }

      # Advanced options
      advanced_options_config = {
        json_parsing = "STANDARD"
        json_custom_config = {
          content_types = ["application/json", "application/ld+json"]
        }

        log_level = local.env_config.environment == "prod" ? "NORMAL" : "VERBOSE"

        user_ip_request_headers = [
          "X-Forwarded-For",
          "X-Real-IP",
          "CF-Connecting-IP"
        ]
      }

      # Security rules
      rules = [
        # Rule 1: Deny blocked IP addresses
        {
          action      = "deny(403)"
          priority    = 100
          description = "Block known malicious IP addresses"

          match = {
            versioned_expr = "SRC_IPS_V1"
            config = {
              src_ip_ranges = local.ip_lists.blocked_ips
            }
          }

          preview = false
        },

        # Rule 2: Allow office and VPN IPs
        {
          action      = "allow"
          priority    = 200
          description = "Allow traffic from office and VPN"

          match = {
            versioned_expr = "SRC_IPS_V1"
            config = {
              src_ip_ranges = local.ip_lists.office_ips
            }
          }

          preview = false
        },

        # Rule 3: Rate limiting
        {
          action      = "rate_based_ban"
          priority    = 300
          description = "Rate limit excessive requests"

          match = {
            versioned_expr = "SRC_IPS_V1"
            config = {
              src_ip_ranges = ["0.0.0.0/0"]
            }
          }

          rate_limit_options = {
            conform_action = "allow"
            exceed_action = "deny(429)"

            rate_limit_threshold = {
              count = 100
              interval_sec = 60
            }

            ban_duration_sec = 600
            enforce_on_key = "IP"

            enforce_on_key_configs = [
              {
                enforce_on_key_type = "IP"
              }
            ]

            ban_threshold = {
              count = 1000
              interval_sec = 600
            }
          }

          preview = false
        },

        # Rule 4: Geographic restrictions
        {
          action      = "deny(403)"
          priority    = 400
          description = "Block traffic from sanctioned countries"

          match = {
            expr = {
              expression = join(" || ", [
                for country in local.ip_lists.denied_countries :
                "origin.region_code == '${country}'"
              ])
            }
          }

          preview = false
        },

        # Rule 5: OWASP Top 10 protection - SQL Injection
        {
          action      = "deny(403)"
          priority    = 500
          description = "Block SQL injection attempts"

          match = {
            expr = {
              expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
            }
          }

          preview = false
        },

        # Rule 6: OWASP Top 10 protection - XSS
        {
          action      = "deny(403)"
          priority    = 501
          description = "Block cross-site scripting attempts"

          match = {
            expr = {
              expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
            }
          }

          preview = false
        },

        # Rule 7: OWASP Top 10 protection - LFI
        {
          action      = "deny(403)"
          priority    = 502
          description = "Block local file inclusion attempts"

          match = {
            expr = {
              expression = "evaluatePreconfiguredExpr('lfi-v33-stable')"
            }
          }

          preview = false
        },

        # Rule 8: OWASP Top 10 protection - RFI
        {
          action      = "deny(403)"
          priority    = 503
          description = "Block remote file inclusion attempts"

          match = {
            expr = {
              expression = "evaluatePreconfiguredExpr('rfi-v33-stable')"
            }
          }

          preview = false
        },

        # Rule 9: OWASP Top 10 protection - RCE
        {
          action      = "deny(403)"
          priority    = 504
          description = "Block remote code execution attempts"

          match = {
            expr = {
              expression = "evaluatePreconfiguredExpr('rce-v33-stable')"
            }
          }

          preview = false
        },

        # Rule 10: Protocol attacks
        {
          action      = "deny(403)"
          priority    = 505
          description = "Block protocol attack attempts"

          match = {
            expr = {
              expression = "evaluatePreconfiguredExpr('protocolattack-v33-stable')"
            }
          }

          preview = false
        },

        # Rule 11: Scanner detection
        {
          action      = "deny(403)"
          priority    = 506
          description = "Block automated scanner and bot traffic"

          match = {
            expr = {
              expression = "evaluatePreconfiguredExpr('scannerdetection-v33-stable')"
            }
          }

          preview = false
        },

        # Rule 12: PHP injection
        {
          action      = "deny(403)"
          priority    = 507
          description = "Block PHP injection attempts"

          match = {
            expr = {
              expression = "evaluatePreconfiguredExpr('php-v33-stable')"
            }
          }

          preview = false
        },

        # Rule 13: Session fixation
        {
          action      = "deny(403)"
          priority    = 508
          description = "Block session fixation attempts"

          match = {
            expr = {
              expression = "evaluatePreconfiguredExpr('sessionfixation-v33-stable')"
            }
          }

          preview = false
        },

        # Rule 14: Block large request bodies
        {
          action      = "deny(413)"
          priority    = 600
          description = "Block requests with large bodies"

          match = {
            expr = {
              expression = "int(request.headers['content-length']) > 10485760"  # 10MB
            }
          }

          preview = false
        },

        # Rule 15: Require specific headers
        {
          action      = "deny(400)"
          priority    = 700
          description = "Require API key header for API endpoints"

          match = {
            expr = {
              expression = "request.path.startsWith('/api/') && !has(request.headers['x-api-key'])"
            }
          }

          preview = false
        },

        # Rule 16: Custom throttling for specific endpoints
        {
          action      = "throttle"
          priority    = 800
          description = "Throttle login attempts"

          match = {
            expr = {
              expression = "request.path == '/login' || request.path == '/signin'"
            }
          }

          rate_limit_options = {
            conform_action = "allow"
            exceed_action = "deny(429)"

            rate_limit_threshold = {
              count = 5
              interval_sec = 300
            }

            enforce_on_key = "IP"
          }

          preview = false
        },

        # Rule 17: Bot management
        {
          action      = "redirect"
          priority    = 900
          description = "Redirect bot traffic to captcha"

          match = {
            expr = {
              expression = "has(request.headers['user-agent']) && request.headers['user-agent'].matches('.*bot.*|.*crawler.*|.*spider.*')"
            }
          }

          redirect_options = {
            type = "EXTERNAL_302"
            target = "https://captcha.example.com/verify?return={url}"
          }

          preview = false
        },

        # Rule 18: Allow health checks
        {
          action      = "allow"
          priority    = 1000
          description = "Allow Google Cloud health checks"

          match = {
            versioned_expr = "SRC_IPS_V1"
            config = {
              src_ip_ranges = local.ip_lists.trusted_services
            }
          }

          preview = false
        },

        # Rule 19: Custom WAF rule
        {
          action      = "deny(403)"
          priority    = 1100
          description = "Custom WAF rule for application-specific threats"

          match = {
            expr = {
              expression = <<-EOT
                request.path.matches('.*\\.(php|asp|aspx|jsp|cgi)$') ||
                request.headers['user-agent'].matches('.*(<script|javascript:|onerror=).*') ||
                request.query.matches('.*(union.*select|select.*from|insert.*into|delete.*from).*')
              EOT
            }
          }

          preview = false
        },

        # Default rule: Allow all other traffic (in production, consider deny by default)
        {
          action      = local.env_config.environment == "prod" ? "allow" : "allow"
          priority    = 2147483647
          description = "Default rule"

          match = {
            versioned_expr = "SRC_IPS_V1"
            config = {
              src_ip_ranges = ["*"]
            }
          }

          preview = false
        }
      ]

      # Recaptcha options
      recaptcha_options_config = local.env_config.environment == "prod" ? {
        waf_service = "CA"  # Cloud Armor

        recaptcha_site_key = get_env("RECAPTCHA_SITE_KEY", "")

        action_token_site_keys = [
          get_env("RECAPTCHA_ACTION_TOKEN_SITE_KEY", "")
        ]

        session_token_site_keys = [
          get_env("RECAPTCHA_SESSION_TOKEN_SITE_KEY", "")
        ]
      } : null
    }

    # API-specific security policy
    api_policy = {
      name        = "${local.policy_prefix}-api-security-policy"
      description = "API security policy with strict rate limiting"
      type        = "CLOUD_ARMOR"

      rules = [
        # Strict rate limiting for API
        {
          action      = "rate_based_ban"
          priority    = 100
          description = "Strict API rate limiting"

          match = {
            versioned_expr = "SRC_IPS_V1"
            config = {
              src_ip_ranges = ["0.0.0.0/0"]
            }
          }

          rate_limit_options = {
            conform_action = "allow"
            exceed_action = "deny(429)"

            rate_limit_threshold = {
              count = 1000
              interval_sec = 60
            }

            ban_duration_sec = 3600
            enforce_on_key = "HTTP_HEADER"

            enforce_on_key_configs = [
              {
                enforce_on_key_type = "HTTP_HEADER"
                enforce_on_key_name = "X-API-Key"
              }
            ]
          }

          preview = false
        },

        # Require API key
        {
          action      = "deny(401)"
          priority    = 200
          description = "Require API key authentication"

          match = {
            expr = {
              expression = "!has(request.headers['x-api-key']) || request.headers['x-api-key'] == ''"
            }
          }

          preview = false
        },

        # Block non-HTTPS
        {
          action      = "deny(403)"
          priority    = 300
          description = "Require HTTPS for API calls"

          match = {
            expr = {
              expression = "!request.scheme.matches('https')"
            }
          }

          preview = false
        }
      ]
    }

    # Internal services policy
    internal_policy = {
      name        = "${local.policy_prefix}-internal-security-policy"
      description = "Security policy for internal services"
      type        = "CLOUD_ARMOR"

      rules = [
        # Only allow from private IP ranges
        {
          action      = "allow"
          priority    = 100
          description = "Allow private IP ranges"

          match = {
            versioned_expr = "SRC_IPS_V1"
            config = {
              src_ip_ranges = [
                "10.0.0.0/8",
                "172.16.0.0/12",
                "192.168.0.0/16"
              ]
            }
          }

          preview = false
        },

        # Deny all other traffic
        {
          action      = "deny(403)"
          priority    = 2147483647
          description = "Deny all other traffic"

          match = {
            versioned_expr = "SRC_IPS_V1"
            config = {
              src_ip_ranges = ["*"]
            }
          }

          preview = false
        }
      ]
    }
  }

  # Edge security policies (for Cloud CDN)
  edge_security_policies = local.env_config.environment == "prod" ? {
    cdn_policy = {
      name        = "${local.policy_prefix}-cdn-security-policy"
      description = "Edge security policy for CDN"
      type        = "CLOUD_ARMOR_EDGE"

      rules = [
        # Cache key manipulation protection
        {
          action      = "deny(403)"
          priority    = 100
          description = "Prevent cache poisoning attempts"

          match = {
            expr = {
              expression = "request.query.matches('.*[<>\"'].*') || request.headers['host'].matches('.*[<>\"'].*')"
            }
          }

          preview = false
        }
      ]
    }
  } : {}

  # Network security policies
  network_security_policies = {
    ddos_protection = {
      name        = "${local.policy_prefix}-ddos-protection"
      description = "DDoS protection policy"

      ddos_protection_config = {
        eligibility = local.env_config.environment == "prod" ? "STANDARD" : "STANDARD"
      }
    }
  }

  # Threat intelligence configuration
  threat_intelligence = {
    enable_threat_intelligence = local.env_config.environment == "prod"

    threat_intelligence_rules = {
      tor_exit_nodes = {
        action = "deny(403)"
        priority = 50
        description = "Block Tor exit nodes"

        threat_intelligence_list = "TOR_EXIT_NODES"
      }

      known_malicious = {
        action = "deny(403)"
        priority = 51
        description = "Block known malicious IPs"

        threat_intelligence_list = "KNOWN_MALICIOUS_IPS"
      }

      search_engines = {
        action = "allow"
        priority = 52
        description = "Allow search engine crawlers"

        threat_intelligence_list = "SEARCH_ENGINE_CRAWLERS"
      }
    }
  }

  # Custom threat indicators
  custom_threat_indicators = {
    suspicious_user_agents = [
      "sqlmap",
      "nikto",
      "nmap",
      "masscan",
      "metasploit"
    ]

    suspicious_paths = [
      "/admin",
      "/wp-admin",
      "/phpmyadmin",
      "/.env",
      "/.git",
      "/config.php"
    ]

    suspicious_parameters = [
      "cmd",
      "exec",
      "system",
      "eval",
      "passwd",
      "/etc/shadow"
    ]
  }

  # Monitoring and alerting
  monitoring_config = {
    alerts = {
      high_threat_traffic = {
        display_name = "High Threat Traffic Detected"
        conditions = {
          threshold_percent = 10
          duration = "300s"
          severity = "critical"
        }
      }

      ddos_attack_detected = {
        display_name = "DDoS Attack Detected"
        conditions = {
          threshold_rps = 10000
          duration = "60s"
          severity = "critical"
        }
      }

      waf_rule_triggered = {
        display_name = "WAF Rule Triggered"
        conditions = {
          threshold_count = 100
          duration = "300s"
          severity = "high"
        }
      }

      rate_limit_exceeded = {
        display_name = "Rate Limit Exceeded"
        conditions = {
          threshold_count = 1000
          duration = "60s"
          severity = "medium"
        }
      }

      geo_blocking_triggered = {
        display_name = "Geographic Blocking Triggered"
        conditions = {
          threshold_count = 50
          duration = "300s"
          severity = "low"
        }
      }
    }

    metrics = {
      allowed_traffic = {
        metric = "cloudarmor.googleapis.com/security_policy/request_count"
        filter = "action=\"allow\""
      }

      blocked_traffic = {
        metric = "cloudarmor.googleapis.com/security_policy/request_count"
        filter = "action=\"deny\""
      }

      rate_limited_traffic = {
        metric = "cloudarmor.googleapis.com/security_policy/request_count"
        filter = "action=\"rate_based_ban\""
      }
    }

    dashboard = {
      display_name = "Cloud Armor Dashboard - ${local.env_config.environment}"

      widgets = [
        {
          title = "Traffic Overview"
          type = "line_chart"
          metrics = ["allowed_traffic", "blocked_traffic"]
        },
        {
          title = "Threat Distribution"
          type = "pie_chart"
          metric = "threat_categories"
        },
        {
          title = "Geographic Distribution"
          type = "geo_chart"
          metric = "traffic_by_country"
        },
        {
          title = "Top Blocked IPs"
          type = "table"
          metric = "blocked_ips"
        },
        {
          title = "WAF Rule Hits"
          type = "bar_chart"
          metric = "waf_rule_triggers"
        }
      ]
    }
  }

  # Logging configuration
  logging_config = {
    enable_logging = true
    sample_rate = local.env_config.environment == "prod" ? 0.1 : 1.0

    log_fields = [
      "enforced_security_policy",
      "outcome",
      "priority",
      "rule_details",
      "source_ip",
      "request_headers",
      "request_url"
    ]

    export_to = {
      bigquery = {
        dataset = "${var.project_id}_security_logs"
        table = "cloud_armor_logs"
      }

      pubsub = {
        topic = "projects/${var.project_id}/topics/security-logs"
      }

      cloud_logging = {
        log_name = "cloud-armor"
      }
    }
  }

  # Integration configuration
  integrations = {
    # SIEM integration
    siem = {
      enabled = local.env_config.environment == "prod"
      type = "SPLUNK"
      endpoint = "https://siem.example.com/services/collector"
      token = get_env("SIEM_TOKEN", "")
    }

    # Slack notifications
    slack = {
      enabled = true
      webhook_url = get_env("SLACK_SECURITY_WEBHOOK", "")
      channel = "#security-alerts"
    }

    # PagerDuty integration
    pagerduty = {
      enabled = local.env_config.environment == "prod"
      integration_key = get_env("PAGERDUTY_SECURITY_KEY", "")
    }
  }
}

# Module inputs
inputs = {
  # Project configuration
  project_id = var.project_id

  # Security policies
  security_policies = local.security_policies

  # Edge security policies
  edge_security_policies = local.edge_security_policies

  # Network security policies
  network_security_policies = local.network_security_policies

  # Threat intelligence configuration
  threat_intelligence = local.threat_intelligence

  # Custom threat indicators
  custom_threat_indicators = local.custom_threat_indicators

  # Backend service associations
  backend_services = try(dependency.load_balancer.outputs.backend_services, {})

  # Monitoring configuration
  monitoring_config = local.monitoring_config
  enable_monitoring = true
  create_monitoring_dashboard = local.env_config.environment == "prod"
  create_monitoring_alerts = local.env_config.environment != "dev"

  # Logging configuration
  logging_config = local.logging_config

  # Integration configuration
  integrations = local.integrations

  # Labels
  labels = merge(
    var.common_labels,
    {
      component = "security"
      service   = "cloud-armor"
      tier      = "edge"
    }
  )

  # Dependencies
  depends_on = [dependency.load_balancer]
}