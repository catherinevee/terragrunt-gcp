# Staging Account Configuration
# Contains account-level settings for staging environment with full enterprise features

locals {
  account_name = "staging"
  account_id   = "staging-account-001"

  # GCP project configuration
  project_id     = get_env("GCP_PROJECT_ID_STAGING", "my-company-staging")
  project_name   = "Staging Environment Project"
  project_number = get_env("GCP_PROJECT_NUMBER_STAGING", "234567890123")

  # Organization settings
  organization_id     = get_env("GCP_ORG_ID", "123456789")
  organization_domain = get_env("GCP_ORG_DOMAIN", "company.com")
  billing_account     = get_env("GCP_BILLING_ACCOUNT", "01ABCD-23EFGH-45IJKL")

  # Folder structure for resource organization
  folder_structure = {
    parent_folder_id = get_env("GCP_STAGING_FOLDER_ID", "folders/456789012345")
    sub_folders = {
      networking = "staging-networking"
      compute    = "staging-compute"
      data       = "staging-data"
      security   = "staging-security"
      operations = "staging-operations"
    }
  }

  # Default regions and zones with DR configuration
  default_regions = ["us-central1", "us-east1", "europe-west1"]
  default_zones   = ["us-central1-a", "us-central1-b", "us-central1-c"]

  # Disaster recovery configuration
  dr_config = {
    primary_region   = "us-central1"
    secondary_region = "us-east1"
    tertiary_region  = "europe-west1"
    rpo_minutes      = 30
    rto_minutes      = 120
  }

  # Account-wide labels for resource tracking and compliance
  account_labels = {
    environment         = "staging"
    managed_by         = "terragrunt"
    cost_center        = "engineering"
    compliance_level   = "medium"
    data_classification = "confidential"
    automation_enabled = "true"
    backup_required    = "true"
    business_unit      = "platform"
    technical_owner    = "platform-team"
    created_date       = formatdate("YYYY-MM-DD", timestamp())
  }

  # Account-wide IAM settings with comprehensive role management
  iam_config = {
    admin_users = [
      "admin@company.com",
      "platform-lead@company.com",
      "sre-lead@company.com"
    ]

    developer_users = [
      "dev1@company.com",
      "dev2@company.com",
      "dev3@company.com",
      "dev4@company.com"
    ]

    qa_users = [
      "qa1@company.com",
      "qa2@company.com",
      "qa-automation@company.com"
    ]

    readonly_users = [
      "auditor@company.com",
      "compliance@company.com",
      "finance@company.com"
    ]

    service_accounts = {
      terraform = {
        email = "terraform-staging@${local.project_id}.iam.gserviceaccount.com"
        roles = [
          "roles/editor",
          "roles/resourcemanager.projectIamAdmin",
          "roles/compute.admin",
          "roles/container.admin"
        ]
      }

      ci_cd = {
        email = "cicd-staging@${local.project_id}.iam.gserviceaccount.com"
        roles = [
          "roles/cloudbuild.builds.editor",
          "roles/container.developer",
          "roles/artifactregistry.writer"
        ]
      }

      monitoring = {
        email = "monitoring-staging@${local.project_id}.iam.gserviceaccount.com"
        roles = [
          "roles/monitoring.metricWriter",
          "roles/logging.logWriter",
          "roles/cloudtrace.agent"
        ]
      }

      backup = {
        email = "backup-staging@${local.project_id}.iam.gserviceaccount.com"
        roles = [
          "roles/compute.storageAdmin",
          "roles/cloudsql.admin",
          "roles/datastore.importExportAdmin"
        ]
      }
    }
  }

  # Service account configuration
  terraform_service_account       = "terraform-staging@${local.project_id}.iam.gserviceaccount.com"
  terraform_state_bucket          = "${local.project_id}-terraform-state"
  terraform_state_bucket_location = "US"

  # Comprehensive API services to enable
  required_apis = [
    # Core APIs
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudapis.googleapis.com",

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

    # Storage APIs
    "storage.googleapis.com",
    "storage-component.googleapis.com",

    # Database APIs
    "sqladmin.googleapis.com",
    "redis.googleapis.com",
    "firestore.googleapis.com",
    "datastore.googleapis.com",
    "spanner.googleapis.com",
    "bigtableadmin.googleapis.com",

    # Data Analytics APIs
    "bigquery.googleapis.com",
    "bigquerystorage.googleapis.com",
    "dataflow.googleapis.com",
    "dataproc.googleapis.com",
    "composer.googleapis.com",
    "datacatalog.googleapis.com",
    "dataplex.googleapis.com",

    # Networking APIs
    "servicenetworking.googleapis.com",
    "networkmanagement.googleapis.com",
    "dns.googleapis.com",
    "certificatemanager.googleapis.com",
    "networksecurity.googleapis.com",
    "networkconnectivity.googleapis.com",

    # Security APIs
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com",
    "binaryauthorization.googleapis.com",
    "containeranalysis.googleapis.com",
    "cloudasset.googleapis.com",
    "securitycenter.googleapis.com",
    "accesscontextmanager.googleapis.com",
    "policytroubleshooter.googleapis.com",

    # Monitoring & Logging APIs
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "cloudprofiler.googleapis.com",
    "clouderrorreporting.googleapis.com",

    # CI/CD APIs
    "cloudbuild.googleapis.com",
    "sourcerepo.googleapis.com",

    # Other APIs
    "pubsub.googleapis.com",
    "oslogin.googleapis.com",
    "notebooks.googleapis.com",
    "ml.googleapis.com",
    "apigateway.googleapis.com",
    "endpoints.googleapis.com"
  ]

  # Comprehensive security settings
  security_config = {
    # Network Security
    enable_vpc_flow_logs          = true
    enable_cloud_armor           = true
    enable_private_google_access = true
    enable_cloud_nat             = true
    require_ssl                  = true
    enable_firewall_insights     = true

    # Identity & Access
    enable_identity_aware_proxy  = true
    enable_binary_authorization = true
    enable_workload_identity    = true
    enable_organization_policies = true

    # Data Protection
    enable_dlp                  = true
    enable_cmek_encryption      = true
    default_kms_key_ring       = "staging-keyring"
    enable_data_access_logs    = true

    # Threat Detection
    enable_security_command_center = true
    enable_cloud_ids              = true
    enable_vulnerability_scanning = true
    enable_container_analysis     = true

    # Compliance
    enable_access_transparency    = true
    enable_audit_logs            = true
    audit_log_retention_days     = 365
    enable_resource_location_constraint = true
    allowed_resource_locations   = ["us-central1", "us-east1", "europe-west1"]
  }

  # Cost management configuration
  budget_config = {
    budget_amount           = 10000
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
        action  = "email"
      },
      {
        percent = 90
        action  = "slack"
      },
      {
        percent = 100
        action  = "pagerduty"
      },
      {
        percent = 110
        action  = "auto_throttle"
      }
    ]

    notification_channels = {
      email     = ["budget-alerts-staging@company.com", "finance@company.com"]
      slack     = ["#staging-alerts", "#platform-oncall"]
      pagerduty = ["staging-budget-escalation"]
    }

    cost_optimization = {
      enable_recommendations      = true
      enable_committed_use_discounts = true
      enable_sustained_use_discounts = true
      enable_preemptible_vms      = true
      enable_auto_shutdown        = true
      shutdown_schedule           = "0 20 * * MON-FRI"  # 8 PM weekdays
      startup_schedule            = "0 6 * * MON-FRI"   # 6 AM weekdays
    }
  }

  # Comprehensive backup and disaster recovery settings
  backup_config = {
    enable_backups        = true
    backup_retention_days = 30
    backup_schedule       = "0 1 * * *"  # Daily at 1 AM
    backup_location       = "us-central1"

    # Multi-tier backup strategy
    backup_tiers = {
      critical = {
        frequency      = "hourly"
        retention_days = 90
        locations      = ["us-central1", "us-east1", "europe-west1"]
        encryption     = "cmek"
      }

      standard = {
        frequency      = "daily"
        retention_days = 30
        locations      = ["us-central1", "us-east1"]
        encryption     = "cmek"
      }

      archival = {
        frequency      = "weekly"
        retention_days = 365
        locations      = ["us-central1"]
        encryption     = "google-managed"
      }
    }

    # Point-in-time recovery
    pitr_config = {
      enable_pitr        = true
      pitr_window_days   = 7
      transaction_logs   = true
      binlog_retention   = "7d"
    }

    # Disaster recovery testing
    dr_testing = {
      enable_dr_testing  = true
      test_frequency     = "monthly"
      test_scenarios     = ["failover", "restore", "replication"]
      notification_list  = ["dr-team@company.com", "platform-team@company.com"]
    }
  }

  # Network configuration
  network_config = {
    vpc_auto_create = false  # Use explicitly defined VPCs

    # IP addressing scheme
    ip_ranges = {
      primary = {
        staging_us_central1 = "10.20.0.0/16"
        staging_us_east1    = "10.21.0.0/16"
        staging_europe_west1 = "10.22.0.0/16"
      }

      secondary = {
        gke_pods_range     = "172.20.0.0/14"
        gke_services_range = "172.24.0.0/16"
      }
    }

    # DNS configuration
    dns_config = {
      enable_cloud_dns    = true
      enable_dnssec      = true
      internal_zone_name = "staging.internal.company.com"
      external_zone_name = "staging.company.com"
    }

    # Peering configuration
    peering_config = {
      enable_vpc_peering          = true
      enable_private_service_connect = true
      enable_shared_vpc           = false  # Staging uses dedicated VPCs
    }
  }

  # Monitoring and observability configuration
  monitoring_config = {
    # Metrics
    enable_metrics           = true
    metrics_retention_days   = 90
    custom_metrics_enabled   = true

    # Logging
    enable_logging          = true
    log_retention_days      = 60
    log_exclusions = [
      "severity < ERROR AND resource.type = k8s_cluster",
      "protoPayload.methodName = storage.objects.list"
    ]

    # Tracing
    enable_tracing          = true
    trace_sampling_rate     = 0.1  # 10% sampling

    # Profiling
    enable_profiling        = true
    profiling_enabled_services = ["api", "backend", "worker"]

    # Alerting
    enable_alerting         = true
    alert_notification_channels = ["email", "slack", "pagerduty"]

    # Dashboards
    enable_dashboards       = true
    dashboard_templates = [
      "executive-overview",
      "service-health",
      "infrastructure-metrics",
      "application-performance",
      "security-posture",
      "cost-tracking"
    ]

    # SLOs
    slo_config = {
      availability_target = 99.9    # Three nines for staging
      latency_p99_ms     = 500
      error_rate_percent = 0.1
      throughput_qps     = 1000
    }
  }

  # Compliance and governance
  governance_config = {
    # Regulatory compliance
    compliance_frameworks = ["SOC2-Type2", "ISO27001", "HIPAA", "GDPR"]

    # Policy enforcement
    enable_org_policies      = true
    enable_policy_controller = true
    policy_enforcement_mode  = "enforced"  # enforced | dryrun

    # Asset management
    enable_asset_inventory   = true
    asset_scan_frequency    = "daily"

    # Change management
    require_change_approval  = true
    approval_levels = {
      minor    = ["team-lead"]
      standard = ["team-lead", "platform-lead"]
      major    = ["team-lead", "platform-lead", "director"]
    }

    # Tagging strategy
    required_tags = ["environment", "team", "cost-center", "project", "owner", "data-classification"]
    tag_enforcement_mode = "strict"
  }

  # Integration configurations
  integrations = {
    # Source control
    github = {
      enabled = true
      org     = "company"
      repos   = ["infrastructure", "applications", "configurations"]
    }

    # CI/CD
    cloud_build = {
      enabled = true
      triggers = ["push", "pull_request", "tag"]
      worker_pool_regions = ["us-central1", "us-east1"]
    }

    # Monitoring
    datadog = {
      enabled = false  # Use native GCP monitoring for staging
    }

    # Incident management
    pagerduty = {
      enabled = true
      integration_key = get_env("PAGERDUTY_STAGING_KEY", "")
      escalation_policy = "staging-oncall"
    }

    # Chat
    slack = {
      enabled = true
      workspace = "company"
      channels = {
        alerts     = "#staging-alerts"
        deployments = "#staging-deployments"
        costs      = "#staging-costs"
      }
    }
  }

  # Feature flags for progressive rollout
  feature_flags = {
    enable_workload_identity_federation = true
    enable_autopilot_gke_clusters      = true
    enable_confidential_computing      = false
    enable_private_service_connect     = true
    enable_vpc_service_controls        = true
    enable_supply_chain_security       = true
    enable_artifact_registry           = true
    enable_container_registry_deprecation = true
    enable_cloud_run_jobs              = true
    enable_eventarc                    = true
  }

  # Quota management
  quota_config = {
    enable_quota_monitoring = true

    compute_quotas = {
      cpus_all_regions        = 500
      gpus_all_regions        = 10
      disks_total_gb         = 50000
      instances_all_regions   = 200
      networks_per_project    = 15
      firewalls_per_project   = 200
    }

    api_quotas = {
      compute_api_qps        = 2000
      storage_api_qps        = 5000
      bigquery_api_qps       = 1000
      kubernetes_api_qps     = 500
    }

    quota_alert_thresholds = [75, 90, 95]
  }
}