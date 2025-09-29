# Production Account Configuration
# Contains account-level settings for production environment with maximum enterprise features

locals {
  account_name = "production"
  account_id   = "prod-account-001"

  # GCP project configuration
  project_id     = get_env("GCP_PROJECT_ID_PROD", "my-company-production")
  project_name   = "Production Environment Project"
  project_number = get_env("GCP_PROJECT_NUMBER_PROD", "345678901234")

  # Organization settings
  organization_id     = get_env("GCP_ORG_ID", "123456789")
  organization_domain = get_env("GCP_ORG_DOMAIN", "company.com")
  billing_account     = get_env("GCP_BILLING_ACCOUNT", "01ABCD-23EFGH-45IJKL")

  # Folder structure for resource organization
  folder_structure = {
    parent_folder_id = get_env("GCP_PROD_FOLDER_ID", "folders/567890123456")
    sub_folders = {
      networking = "prod-networking"
      compute    = "prod-compute"
      data       = "prod-data"
      security   = "prod-security"
      operations = "prod-operations"
      compliance = "prod-compliance"
      disaster_recovery = "prod-dr"
    }
  }

  # Default regions and zones with global distribution
  default_regions = ["us-central1", "us-east1", "europe-west1", "asia-southeast1", "australia-southeast1"]
  default_zones   = [
    "us-central1-a", "us-central1-b", "us-central1-c", "us-central1-f",
    "us-east1-b", "us-east1-c", "us-east1-d",
    "europe-west1-b", "europe-west1-c", "europe-west1-d",
    "asia-southeast1-a", "asia-southeast1-b", "asia-southeast1-c",
    "australia-southeast1-a", "australia-southeast1-b", "australia-southeast1-c"
  ]

  # Disaster recovery configuration with multi-region failover
  dr_config = {
    primary_region   = "us-central1"
    secondary_region = "us-east1"
    tertiary_region  = "europe-west1"
    quaternary_region = "asia-southeast1"
    rpo_minutes      = 15  # Recovery Point Objective
    rto_minutes      = 60  # Recovery Time Objective

    failover_strategy = {
      automatic_failover = true
      failover_threshold = 3  # Number of health check failures
      failback_delay     = 1800  # Seconds before automatic failback
      cross_region_replication = true
      multi_master_replication = true
    }

    backup_strategy = {
      continuous_backup = true
      point_in_time_recovery = true
      geo_redundant_backup = true
      backup_encryption = "customer_managed"
      immutable_backups = true
      backup_retention_policy = {
        daily   = 30
        weekly  = 52
        monthly = 84
        yearly  = 10
      }
    }
  }

  # Account-wide labels for resource tracking, compliance, and governance
  account_labels = {
    environment         = "production"
    managed_by         = "terragrunt"
    cost_center        = "operations"
    compliance_level   = "critical"
    data_classification = "highly-confidential"
    automation_enabled = "true"
    backup_required    = "true"
    business_unit      = "core-platform"
    technical_owner    = "platform-team"
    business_owner     = "cto-office"
    regulatory_scope   = "sox-pci-hipaa-gdpr"
    disaster_recovery  = "tier1"
    sla_tier          = "platinum"
    change_management = "required"
    security_review   = "mandatory"
    created_date      = formatdate("YYYY-MM-DD", timestamp())
  }

  # Account-wide IAM settings with comprehensive role management
  iam_config = {
    admin_users = [
      "cto@company.com",
      "security-admin@company.com",
      "platform-admin@company.com",
      "infrastructure-lead@company.com"
    ]

    platform_engineers = [
      "platform-eng1@company.com",
      "platform-eng2@company.com",
      "platform-eng3@company.com",
      "platform-eng4@company.com",
      "platform-eng5@company.com"
    ]

    sre_team = [
      "sre-lead@company.com",
      "sre1@company.com",
      "sre2@company.com",
      "sre3@company.com",
      "oncall-primary@company.com",
      "oncall-secondary@company.com"
    ]

    security_team = [
      "security-lead@company.com",
      "security-analyst1@company.com",
      "security-analyst2@company.com",
      "security-architect@company.com",
      "compliance-officer@company.com"
    ]

    readonly_users = [
      "auditor-external@audit-firm.com",
      "compliance-auditor@company.com",
      "finance-reviewer@company.com",
      "executive-dashboard@company.com",
      "board-member1@company.com",
      "board-member2@company.com"
    ]

    break_glass_accounts = [
      "emergency-access1@company.com",
      "emergency-access2@company.com"
    ]

    service_accounts = {
      terraform = {
        email = "terraform-prod@${local.project_id}.iam.gserviceaccount.com"
        roles = [
          "roles/editor",
          "roles/resourcemanager.projectIamAdmin",
          "roles/compute.admin",
          "roles/container.admin",
          "roles/storage.admin",
          "roles/iam.serviceAccountAdmin"
        ]
        conditions = {
          time_based = true
          expiry_hours = 4
          require_mfa = true
        }
      }

      ci_cd = {
        email = "cicd-prod@${local.project_id}.iam.gserviceaccount.com"
        roles = [
          "roles/cloudbuild.builds.builder",
          "roles/container.developer",
          "roles/artifactregistry.writer",
          "roles/cloudrun.developer"
        ]
        conditions = {
          ip_restriction = ["10.0.0.0/8", "172.16.0.0/12"]
          require_approval = true
        }
      }

      monitoring = {
        email = "monitoring-prod@${local.project_id}.iam.gserviceaccount.com"
        roles = [
          "roles/monitoring.metricWriter",
          "roles/logging.logWriter",
          "roles/cloudtrace.agent",
          "roles/clouddebugger.agent",
          "roles/cloudprofiler.agent"
        ]
      }

      backup = {
        email = "backup-prod@${local.project_id}.iam.gserviceaccount.com"
        roles = [
          "roles/compute.storageAdmin",
          "roles/cloudsql.admin",
          "roles/datastore.importExportAdmin",
          "roles/storage.objectAdmin",
          "roles/bigquery.dataEditor"
        ]
      }

      security_scanner = {
        email = "security-scanner-prod@${local.project_id}.iam.gserviceaccount.com"
        roles = [
          "roles/securitycenter.findingsEditor",
          "roles/containeranalysis.occurrences.editor",
          "roles/binaryauthorization.attestorsViewer"
        ]
      }

      disaster_recovery = {
        email = "dr-orchestrator-prod@${local.project_id}.iam.gserviceaccount.com"
        roles = [
          "roles/compute.instanceAdmin",
          "roles/cloudsql.admin",
          "roles/storage.admin",
          "roles/dns.admin"
        ]
      }
    }
  }

  # Service account configuration
  terraform_service_account       = "terraform-prod@${local.project_id}.iam.gserviceaccount.com"
  terraform_state_bucket          = "${local.project_id}-terraform-state"
  terraform_state_bucket_location = "MULTI-REGION-US"

  # Comprehensive API services to enable
  required_apis = [
    # Core APIs
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudapis.googleapis.com",
    "orgpolicy.googleapis.com",

    # Compute APIs
    "compute.googleapis.com",
    "container.googleapis.com",
    "containerregistry.googleapis.com",
    "artifactregistry.googleapis.com",
    "run.googleapis.com",
    "appengine.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudtasks.googleapis.com",
    "batch.googleapis.com",

    # Storage APIs
    "storage.googleapis.com",
    "storage-component.googleapis.com",
    "storage-transfer.googleapis.com",

    # Database APIs
    "sqladmin.googleapis.com",
    "redis.googleapis.com",
    "memcache.googleapis.com",
    "firestore.googleapis.com",
    "datastore.googleapis.com",
    "spanner.googleapis.com",
    "bigtableadmin.googleapis.com",
    "alloydb.googleapis.com",

    # Data Analytics APIs
    "bigquery.googleapis.com",
    "bigquerystorage.googleapis.com",
    "bigquerydatatransfer.googleapis.com",
    "dataflow.googleapis.com",
    "dataproc.googleapis.com",
    "composer.googleapis.com",
    "datacatalog.googleapis.com",
    "dataplex.googleapis.com",
    "datalineage.googleapis.com",
    "datapipelines.googleapis.com",

    # AI/ML APIs
    "ml.googleapis.com",
    "automl.googleapis.com",
    "aiplatform.googleapis.com",
    "notebooks.googleapis.com",
    "recommendationengine.googleapis.com",
    "vision.googleapis.com",
    "speech.googleapis.com",
    "translate.googleapis.com",
    "videointelligence.googleapis.com",
    "language.googleapis.com",

    # Networking APIs
    "servicenetworking.googleapis.com",
    "networkmanagement.googleapis.com",
    "networkconnectivity.googleapis.com",
    "networksecurity.googleapis.com",
    "dns.googleapis.com",
    "certificatemanager.googleapis.com",
    "trafficdirector.googleapis.com",

    # Security APIs
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com",
    "binaryauthorization.googleapis.com",
    "containeranalysis.googleapis.com",
    "cloudasset.googleapis.com",
    "securitycenter.googleapis.com",
    "accesscontextmanager.googleapis.com",
    "policytroubleshooter.googleapis.com",
    "privateca.googleapis.com",
    "confidentialcomputing.googleapis.com",
    "beyondcorp.googleapis.com",

    # Monitoring & Logging APIs
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "cloudprofiler.googleapis.com",
    "clouderrorreporting.googleapis.com",
    "clouddebugger.googleapis.com",

    # CI/CD APIs
    "cloudbuild.googleapis.com",
    "sourcerepo.googleapis.com",
    "artifactregistry.googleapis.com",
    "clouddeploy.googleapis.com",

    # Integration APIs
    "pubsub.googleapis.com",
    "eventarc.googleapis.com",
    "workflows.googleapis.com",
    "apigateway.googleapis.com",
    "endpoints.googleapis.com",
    "apigee.googleapis.com",

    # Identity & Access
    "identityplatform.googleapis.com",
    "sts.googleapis.com",
    "oslogin.googleapis.com",

    # Management APIs
    "cloudconfig.googleapis.com",
    "osconfig.googleapis.com",
    "deploymentmanager.googleapis.com",

    # Compliance & Governance
    "assuredworkloads.googleapis.com",
    "accessapproval.googleapis.com",
    "essentialcontacts.googleapis.com"
  ]

  # Comprehensive security settings for production
  security_config = {
    # Network Security
    enable_vpc_flow_logs          = true
    enable_cloud_armor           = true
    enable_private_google_access = true
    enable_cloud_nat             = true
    require_ssl                  = true
    enable_firewall_insights     = true
    enable_packet_mirroring      = true
    enable_cloud_ids            = true

    # Identity & Access
    enable_identity_aware_proxy  = true
    enable_binary_authorization = true
    enable_workload_identity    = true
    enable_organization_policies = true
    enable_beyondcorp           = true
    require_mfa                 = true
    session_duration_hours      = 4

    # Data Protection
    enable_dlp                  = true
    enable_cmek_encryption      = true
    default_kms_key_ring       = "production-keyring"
    enable_data_access_logs    = true
    enable_vpc_service_controls = true
    enable_assured_workloads    = true
    data_residency_requirement = true

    # Threat Detection & Response
    enable_security_command_center = true
    enable_cloud_ids              = true
    enable_vulnerability_scanning = true
    enable_container_analysis     = true
    enable_web_security_scanner   = true
    enable_phishing_protection    = true
    enable_reCAPTCHA_enterprise   = true

    # Compliance & Audit
    enable_access_transparency    = true
    enable_audit_logs            = true
    audit_log_retention_days     = 2555  # 7 years
    enable_resource_location_constraint = true
    allowed_resource_locations   = ["us-central1", "us-east1", "europe-west1", "asia-southeast1"]

    # Encryption & Key Management
    hsm_protection_level        = "HSM"
    key_rotation_period_days    = 30
    enable_application_layer_encryption = true
    enable_confidential_computing = true

    # Zero Trust Security
    enable_zero_trust_network   = true
    enable_microsegmentation    = true
    enable_certificate_based_access = true
    enable_device_trust_verification = true
  }

  # Cost management configuration with advanced controls
  budget_config = {
    budget_amount           = 50000
    budget_currency        = "USD"
    budget_time_period     = "MONTHLY"
    include_credits        = false
    include_taxes          = true
    include_discounts      = true

    alert_thresholds = [
      {
        percent = 50
        action  = "email"
      },
      {
        percent = 75
        action  = "slack"
      },
      {
        percent = 85
        action  = "pagerduty"
      },
      {
        percent = 90
        action  = "emergency_notification"
      },
      {
        percent = 95
        action  = "cost_containment"
      },
      {
        percent = 100
        action  = "spending_freeze"
      },
      {
        percent = 110
        action  = "auto_shutdown_non_critical"
      }
    ]

    notification_channels = {
      email     = ["budget-alerts-prod@company.com", "finance@company.com", "cfo@company.com"]
      slack     = ["#prod-alerts", "#finance-alerts", "#executive-alerts"]
      pagerduty = ["production-budget-critical", "executive-escalation"]
      teams     = ["FinanceTeam", "ExecutiveTeam"]
      webhook   = ["https://finance.company.com/budget-webhook", "https://ops.company.com/cost-alert"]
    }

    cost_optimization = {
      enable_recommendations      = true
      enable_committed_use_discounts = true
      enable_sustained_use_discounts = true
      enable_preemptible_vms      = false  # Not for production workloads
      enable_auto_shutdown        = false  # Production runs 24/7
      enable_rightsizing_recommendations = true
      enable_unused_resource_detection = true
      enable_cost_anomaly_detection = true
      anomaly_threshold_percent   = 20
    }

    spend_controls = {
      enable_quotas              = true
      enable_purchase_orders     = true
      require_approval_above     = 1000
      block_expensive_resources  = true
      allowed_machine_types      = ["n2-standard-*", "n2-highmem-*", "c2-standard-*"]
      blocked_machine_types      = ["a2-*", "m2-*"]  # Block expensive GPU instances
      max_instance_count         = 1000
      max_disk_size_gb          = 10000
    }
  }

  # Comprehensive backup and disaster recovery settings
  backup_config = {
    enable_backups        = true
    backup_retention_days = 90
    backup_schedule       = "0 */4 * * *"  # Every 4 hours
    backup_location       = "multi-region-us"

    # Multi-tier backup strategy
    backup_tiers = {
      critical = {
        frequency      = "continuous"  # Real-time replication
        retention_days = 365
        locations      = ["us-central1", "us-east1", "europe-west1", "asia-southeast1"]
        encryption     = "cmek"
        immutable      = true
        versioning     = true
      }

      high = {
        frequency      = "hourly"
        retention_days = 180
        locations      = ["us-central1", "us-east1", "europe-west1"]
        encryption     = "cmek"
        immutable      = true
        versioning     = true
      }

      standard = {
        frequency      = "every_6_hours"
        retention_days = 90
        locations      = ["us-central1", "us-east1"]
        encryption     = "cmek"
        immutable      = false
        versioning     = true
      }

      archival = {
        frequency      = "daily"
        retention_days = 2555  # 7 years
        locations      = ["us-central1"]
        encryption     = "cmek"
        storage_class  = "archive"
        immutable      = true
      }
    }

    # Point-in-time recovery
    pitr_config = {
      enable_pitr              = true
      pitr_window_days        = 35
      transaction_logs        = true
      binlog_retention        = "30d"
      continuous_protection   = true
      automated_restore_test  = true
      restore_test_frequency  = "weekly"
    }

    # Disaster recovery testing
    dr_testing = {
      enable_dr_testing        = true
      test_frequency          = "weekly"
      test_scenarios          = ["failover", "restore", "replication", "network_partition", "region_failure"]
      automated_testing       = true
      chaos_engineering       = true
      notification_list       = ["dr-team@company.com", "platform-team@company.com", "executive-team@company.com"]
      success_criteria = {
        rto_target_minutes = 60
        rpo_target_minutes = 15
        data_integrity     = 100
        service_availability = 99.99
      }
    }
  }

  # Network configuration with advanced features
  network_config = {
    vpc_auto_create = false  # Use explicitly defined VPCs

    # IP addressing scheme with careful planning
    ip_ranges = {
      primary = {
        prod_us_central1     = "10.0.0.0/16"
        prod_us_east1        = "10.1.0.0/16"
        prod_europe_west1    = "10.2.0.0/16"
        prod_asia_southeast1 = "10.3.0.0/16"
        prod_australia_southeast1 = "10.4.0.0/16"
      }

      secondary = {
        gke_pods_range       = "172.16.0.0/14"
        gke_services_range   = "172.20.0.0/16"
        cloud_sql_range      = "172.21.0.0/16"
        memorystore_range    = "172.22.0.0/16"
        serverless_range     = "172.23.0.0/16"
      }

      reserved = {
        future_expansion     = "10.100.0.0/16"
        interconnect_range   = "10.200.0.0/16"
        partner_connections  = "10.201.0.0/16"
      }
    }

    # DNS configuration
    dns_config = {
      enable_cloud_dns        = true
      enable_dnssec          = true
      enable_dns_policies    = true
      internal_zone_name     = "prod.internal.company.com"
      external_zone_name     = "company.com"
      enable_split_horizon   = true
      enable_geo_routing     = true
      enable_health_checks   = true
    }

    # Network connectivity
    connectivity_config = {
      enable_vpc_peering          = true
      enable_private_service_connect = true
      enable_shared_vpc           = true
      enable_cloud_interconnect   = true
      enable_partner_interconnect = true
      enable_cloud_vpn           = true
      enable_network_connectivity_center = true
      interconnect_bandwidth_gbps = 10
      vpn_bandwidth_mbps        = 3000
    }

    # CDN and load balancing
    cdn_config = {
      enable_cloud_cdn        = true
      enable_cloud_armor      = true
      cache_mode             = "CACHE_ALL_STATIC"
      default_ttl_seconds    = 3600
      max_ttl_seconds        = 86400
      enable_negative_caching = true
      enable_request_coalescing = true
    }
  }

  # Monitoring and observability configuration
  monitoring_config = {
    # Metrics
    enable_metrics           = true
    metrics_retention_days   = 180
    custom_metrics_enabled   = true
    enable_prometheus_export = true

    # Logging
    enable_logging          = true
    log_retention_days      = 90
    enable_log_analytics    = true
    log_exclusions = [
      "severity < WARNING AND resource.type = k8s_cluster",
      "protoPayload.methodName = storage.objects.get AND severity < ERROR"
    ]
    log_sinks = {
      security_logs = "security-logs-bucket"
      audit_logs    = "audit-logs-bucket"
      application_logs = "application-logs-bucket"
    }

    # Tracing
    enable_tracing          = true
    trace_sampling_rate     = 0.01  # 1% sampling for production
    enable_auto_instrumentation = true

    # Profiling
    enable_profiling        = true
    profiling_enabled_services = ["api", "backend", "worker", "gateway", "database-proxy"]

    # Alerting
    enable_alerting         = true
    alert_notification_channels = ["email", "slack", "pagerduty", "opsgenie", "webhook"]
    enable_smart_alerts     = true
    alert_correlation       = true
    noise_reduction        = true

    # Dashboards
    enable_dashboards       = true
    dashboard_templates = [
      "executive-overview",
      "service-health",
      "infrastructure-metrics",
      "application-performance",
      "security-posture",
      "cost-tracking",
      "user-experience",
      "business-metrics",
      "compliance-status",
      "capacity-planning"
    ]

    # SLOs and SLIs
    slo_config = {
      availability_target  = 99.99   # Four nines for production
      latency_p50_ms      = 50
      latency_p95_ms      = 200
      latency_p99_ms      = 500
      error_rate_percent  = 0.01
      throughput_qps      = 10000

      error_budget_policy = {
        auto_freeze_deployments = true
        alert_on_burn_rate     = true
        burn_rate_thresholds    = [2, 5, 10]
      }
    }

    # Synthetic monitoring
    synthetic_monitoring = {
      enable_uptime_checks    = true
      enable_user_journey_tests = true
      test_frequency_minutes  = 1
      test_locations = [
        "us-central1", "us-east1", "europe-west1",
        "asia-southeast1", "australia-southeast1"
      ]
    }
  }

  # Compliance and governance
  governance_config = {
    # Regulatory compliance
    compliance_frameworks = ["SOC2-Type2", "ISO27001", "ISO27017", "ISO27018", "HIPAA", "PCI-DSS", "GDPR", "CCPA", "FedRAMP-High"]

    # Policy enforcement
    enable_org_policies      = true
    enable_policy_controller = true
    policy_enforcement_mode  = "enforced"
    enable_config_controller = true
    enable_policy_intelligence = true

    # Asset management
    enable_asset_inventory   = true
    asset_scan_frequency    = "continuous"
    enable_resource_manager_tags = true
    enable_tag_policies     = true

    # Change management
    require_change_approval  = true
    approval_levels = {
      minor    = ["team-lead", "sre-oncall"]
      standard = ["team-lead", "platform-lead", "security-review"]
      major    = ["team-lead", "platform-lead", "director", "security-team", "cto"]
      critical = ["platform-lead", "director", "cto", "ciso", "ceo"]
    }

    change_freeze_windows = [
      {
        name = "year_end_freeze"
        start = "12-15"
        end = "01-15"
      },
      {
        name = "quarterly_freeze"
        days_before_quarter_end = 5
      }
    ]

    # Tagging strategy
    required_tags = [
      "environment", "team", "cost-center", "project",
      "owner", "data-classification", "compliance-scope",
      "business-criticality", "sla-tier", "change-tracking"
    ]
    tag_enforcement_mode = "strict"
    block_untagged_resources = true

    # Audit and compliance reporting
    audit_config = {
      enable_continuous_compliance_monitoring = true
      compliance_scan_frequency = "daily"
      generate_compliance_reports = true
      report_frequency = "weekly"
      report_recipients = ["compliance@company.com", "audit@company.com", "legal@company.com"]
    }
  }

  # Integration configurations
  integrations = {
    # Source control
    github = {
      enabled = true
      org     = "company"
      repos   = ["infrastructure", "applications", "configurations", "policies", "runbooks"]
      branch_protection = true
      require_reviews = 2
      dismiss_stale_reviews = true
      require_code_owner_reviews = true
    }

    # CI/CD
    cloud_build = {
      enabled = true
      triggers = ["push", "pull_request", "tag", "schedule"]
      worker_pool_regions = ["us-central1", "us-east1", "europe-west1", "asia-southeast1"]
      require_approval = true
      enable_vulnerability_scanning = true
      enable_dependency_scanning = true
    }

    # Monitoring & APM
    datadog = {
      enabled = true
      api_key_secret = "datadog-api-key-prod"
      app_key_secret = "datadog-app-key-prod"
      site = "datadoghq.com"
      enable_apm = true
      enable_rum = true
      enable_synthetics = true
    }

    new_relic = {
      enabled = true
      account_id = get_env("NEW_RELIC_ACCOUNT_ID", "")
      api_key_secret = "newrelic-api-key-prod"
      enable_apm = true
      enable_infrastructure = true
      enable_browser = true
    }

    # Incident management
    pagerduty = {
      enabled = true
      integration_key = get_env("PAGERDUTY_PROD_KEY", "")
      escalation_policy = "production-oncall"
      high_urgency_services = ["api", "database", "authentication", "payment"]
      enable_intelligent_alerting = true
    }

    opsgenie = {
      enabled = true
      api_key_secret = "opsgenie-api-key-prod"
      team = "production-team"
      enable_on_call_schedules = true
    }

    # Communication
    slack = {
      enabled = true
      workspace = "company"
      channels = {
        alerts     = "#prod-alerts"
        critical   = "#prod-critical"
        deployments = "#prod-deployments"
        costs      = "#prod-costs"
        security   = "#prod-security"
        incidents  = "#prod-incidents"
        war_room   = "#prod-war-room"
      }
      enable_interactive_alerts = true
    }

    microsoft_teams = {
      enabled = true
      webhook_secret = "teams-webhook-prod"
      channels = ["Production-Alerts", "Executive-Updates"]
    }

    # SIEM & Security
    splunk = {
      enabled = true
      hec_endpoint = "https://splunk.company.com:8088"
      hec_token_secret = "splunk-hec-token-prod"
      index = "production"
      source_type = "gcp:production"
    }

    elastic_siem = {
      enabled = true
      cloud_id = get_env("ELASTIC_CLOUD_ID_PROD", "")
      api_key_secret = "elastic-api-key-prod"
      enable_threat_intelligence = true
    }
  }

  # Feature flags for progressive rollout
  feature_flags = {
    enable_workload_identity_federation = true
    enable_autopilot_gke_clusters      = true
    enable_confidential_computing      = true
    enable_private_service_connect     = true
    enable_vpc_service_controls        = true
    enable_supply_chain_security       = true
    enable_artifact_registry           = true
    enable_container_registry_deprecation = true
    enable_cloud_run_jobs              = true
    enable_eventarc                    = true
    enable_anthos_service_mesh         = true
    enable_anthos_config_management    = true
    enable_config_sync                 = true
    enable_policy_controller           = true
    enable_cloud_deploy               = true
    enable_assured_workloads          = true
    enable_sovereign_controls         = true
    enable_certificate_authority_service = true
    enable_key_access_justifications   = true
    enable_data_fusion               = true
    enable_datastream                = true
  }

  # Quota management with production limits
  quota_config = {
    enable_quota_monitoring = true
    enable_quota_alerts    = true

    compute_quotas = {
      cpus_all_regions        = 10000
      gpus_all_regions        = 100
      disks_total_gb         = 1000000  # 1PB
      instances_all_regions   = 5000
      networks_per_project    = 50
      firewalls_per_project   = 500
      load_balancers         = 100
      ssl_certificates       = 100
    }

    storage_quotas = {
      total_storage_gb       = 5000000  # 5PB
      number_of_buckets      = 1000
      object_compose_qps     = 1000
      object_get_qps        = 50000
      object_list_qps       = 5000
      object_insert_qps     = 10000
    }

    database_quotas = {
      cloud_sql_instances    = 100
      cloud_sql_total_gb    = 100000
      spanner_nodes         = 100
      firestore_reads_per_day = 1000000000
      firestore_writes_per_day = 100000000
      bigtable_nodes        = 100
    }

    api_quotas = {
      compute_api_qps        = 5000
      storage_api_qps        = 10000
      bigquery_api_qps       = 5000
      kubernetes_api_qps     = 2000
      cloud_sql_api_qps     = 1000
      monitoring_api_qps    = 5000
    }

    quota_alert_thresholds = [80, 90, 95, 98]
    auto_quota_increase    = true
    quota_buffer_percent   = 20
  }

  # Performance optimization
  performance_config = {
    enable_performance_insights = true
    enable_recommendations     = true
    enable_auto_scaling       = true
    enable_predictive_scaling = true
    enable_load_balancing_optimization = true
    enable_cache_optimization = true
    enable_database_insights  = true
    enable_query_insights    = true

    auto_scaling_config = {
      min_replicas = 3
      max_replicas = 100
      target_cpu_utilization = 70
      target_memory_utilization = 75
      scale_down_delay_seconds = 300
      scale_up_delay_seconds = 60
    }

    performance_targets = {
      api_latency_p50_ms = 50
      api_latency_p99_ms = 500
      database_query_p50_ms = 10
      database_query_p99_ms = 100
      cache_hit_rate_percent = 95
      cdn_hit_rate_percent = 90
    }
  }
}