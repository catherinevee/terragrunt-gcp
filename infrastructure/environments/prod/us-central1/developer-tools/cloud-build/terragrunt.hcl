# Production Cloud Build CI/CD Configuration
# This configuration provides comprehensive build automation, deployment pipelines, and CI/CD workflows

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("env.hcl")
}

include "region" {
  path = find_in_parent_folders("region.hcl")
}

terraform {
  source = "../../../../../../modules/developer-tools/cloud-build"
}

dependency "vpc" {
  config_path = "../../networking/vpc"
  mock_outputs = {
    network_self_link = "projects/mock-project/global/networks/mock-network"
    network_name = "mock-network"
    private_subnet_self_links = ["projects/mock-project/regions/us-central1/subnetworks/mock-subnet"]
  }
}

dependency "gke" {
  config_path = "../../kubernetes/gke-cluster"
  mock_outputs = {
    cluster_name = "mock-cluster"
    cluster_endpoint = "https://mock-endpoint"
    cluster_ca_certificate = "mock-cert"
    cluster_location = "us-central1-a"
  }
}

dependency "artifact_registry" {
  config_path = "../../storage/artifact-registry"
  mock_outputs = {
    repository_urls = {
      docker = "us-central1-docker.pkg.dev/mock-project/docker-repo"
      npm = "us-central1-npm.pkg.dev/mock-project/npm-repo"
    }
  }
}

dependency "source_repos" {
  config_path = "../source-repositories"
  mock_outputs = {
    repository_urls = {
      main_app = "https://source.developers.google.com/p/mock-project/r/main-app"
      infrastructure = "https://source.developers.google.com/p/mock-project/r/infrastructure"
    }
  }
}

dependency "binary_auth" {
  config_path = "../../security/binary-authorization"
  mock_outputs = {
    policy_name = "projects/mock-project/policy"
    attestor_names = ["build-attestor", "security-attestor"]
  }
}

dependency "kms" {
  config_path = "../../security/kms"
  mock_outputs = {
    crypto_keys = {
      cloud_build = "projects/mock-project/locations/us-central1/keyRings/main/cryptoKeys/cloud-build"
    }
  }
}

inputs = {
  project_id = "your-prod-project-id"
  region     = "us-central1"

  # Cloud Build Service Account with comprehensive permissions
  cloud_build_service_account = {
    account_id   = "cloud-build-prod"
    display_name = "Cloud Build Production Service Account"
    description  = "Service account for Cloud Build operations in production"

    # Comprehensive IAM roles for build operations
    roles = [
      "roles/cloudbuild.builds.builder",
      "roles/storage.admin",
      "roles/artifactregistry.writer",
      "roles/container.developer",
      "roles/run.developer",
      "roles/iam.serviceAccountUser",
      "roles/cloudkms.cryptoKeyEncrypterDecrypter",
      "roles/secretmanager.secretAccessor",
      "roles/monitoring.metricWriter",
      "roles/logging.logWriter",
      "roles/source.reader",
      "roles/binaryauthorization.attestorsEditor",
      "roles/containeranalysis.notes.editor"
    ]
  }

  # Build Triggers for automated CI/CD
  build_triggers = {
    # Main application build and deployment
    main_app_build = {
      name        = "main-app-build-prod"
      description = "Build and deploy main application to production"

      github = {
        owner = "your-organization"
        name  = "main-application"
        push = {
          branch = "^main$"
        }
      }

      filename = "cloudbuild.yaml"

      substitutions = {
        _ENVIRONMENT = "production"
        _REGION = "us-central1"
        _CLUSTER_NAME = dependency.gke.outputs.cluster_name
        _ARTIFACT_REGISTRY = dependency.artifact_registry.outputs.repository_urls.docker
        _KMS_KEY = dependency.kms.outputs.crypto_keys.cloud_build
        _DEPLOY_NAMESPACE = "production"
      }

      include_build_logs = "INCLUDE_BUILD_LOGS_WITH_STATUS"

      approval_config = {
        approval_required = true
      }
    }

    # Infrastructure deployment trigger
    infrastructure_deploy = {
      name        = "infrastructure-deploy-prod"
      description = "Deploy infrastructure changes to production"

      cloud_source_repositories = {
        repo_name   = "infrastructure"
        branch_name = "main"
      }

      filename = "deploy/cloudbuild.yaml"

      substitutions = {
        _ENVIRONMENT = "production"
        _REGION = "us-central1"
        _TERRAFORM_VERSION = "1.5.0"
        _TERRAGRUNT_VERSION = "0.48.0"
      }

      include_build_logs = "INCLUDE_BUILD_LOGS_WITH_STATUS"

      approval_config = {
        approval_required = true
      }
    }

    # Security scanning trigger
    security_scan = {
      name        = "security-scan-prod"
      description = "Security scanning for production deployments"

      github = {
        owner = "your-organization"
        name  = "main-application"
        pull_request = {
          branch = "^main$"
        }
      }

      filename = "security/cloudbuild.yaml"

      substitutions = {
        _ENVIRONMENT = "production"
        _SCAN_TYPE = "comprehensive"
        _BINARY_AUTH_POLICY = dependency.binary_auth.outputs.policy_name
      }
    }

    # Database migration trigger
    database_migration = {
      name        = "database-migration-prod"
      description = "Database migration for production"

      github = {
        owner = "your-organization"
        name  = "database-migrations"
        push = {
          branch = "^main$"
        }
      }

      filename = "migrations/cloudbuild.yaml"

      substitutions = {
        _ENVIRONMENT = "production"
        _DB_INSTANCE = dependency.cloud_sql.outputs.instance_name
        _MIGRATION_TYPE = "forward"
      }

      approval_config = {
        approval_required = true
      }
    }

    # Disaster recovery testing
    dr_testing = {
      name        = "disaster-recovery-test"
      description = "Automated disaster recovery testing"

      cloud_source_repositories = {
        repo_name   = "disaster-recovery"
        branch_name = "main"
      }

      filename = "testing/cloudbuild.yaml"

      substitutions = {
        _ENVIRONMENT = "production"
        _TEST_TYPE = "full"
        _BACKUP_REGION = "us-east1"
      }

      # Schedule for regular DR testing
      trigger_template = {
        branch_name = "main"
        tag_name    = null
      }
    }

    # Performance testing trigger
    performance_testing = {
      name        = "performance-test-prod"
      description = "Performance testing for production readiness"

      github = {
        owner = "your-organization"
        name  = "performance-tests"
        push = {
          branch = "^main$"
        }
      }

      filename = "performance/cloudbuild.yaml"

      substitutions = {
        _ENVIRONMENT = "production"
        _LOAD_TEST_DURATION = "30m"
        _CONCURRENT_USERS = "1000"
        _TARGET_ENDPOINT = "https://api.your-domain.com"
      }
    }

    # Compliance validation trigger
    compliance_validation = {
      name        = "compliance-validation"
      description = "Validate compliance requirements"

      cloud_source_repositories = {
        repo_name   = "compliance-checks"
        branch_name = "main"
      }

      filename = "compliance/cloudbuild.yaml"

      substitutions = {
        _ENVIRONMENT = "production"
        _COMPLIANCE_FRAMEWORK = "SOC2,ISO27001,PCI-DSS"
        _SCAN_DEPTH = "comprehensive"
      }
    }
  }

  # Worker Pools for enhanced build performance
  worker_pools = {
    # High-performance pool for main builds
    high_performance_pool = {
      name         = "high-performance-prod"
      location     = "us-central1"

      worker_config = {
        machine_type = "e2-standard-8"
        disk_size_gb = 200
        no_external_ip = false
      }

      network_config = {
        peered_network = dependency.vpc.outputs.network_self_link
      }

      annotations = {
        environment = "production"
        purpose = "high-performance-builds"
      }
    }

    # Security-focused pool for sensitive operations
    security_pool = {
      name         = "security-prod"
      location     = "us-central1"

      worker_config = {
        machine_type = "e2-standard-4"
        disk_size_gb = 100
        no_external_ip = true
      }

      network_config = {
        peered_network = dependency.vpc.outputs.network_self_link
      }

      annotations = {
        environment = "production"
        purpose = "security-operations"
        isolation = "enhanced"
      }
    }

    # Cost-optimized pool for testing
    cost_optimized_pool = {
      name         = "cost-optimized-prod"
      location     = "us-central1"

      worker_config = {
        machine_type = "e2-medium"
        disk_size_gb = 50
        no_external_ip = true
      }

      network_config = {
        peered_network = dependency.vpc.outputs.network_self_link
      }

      annotations = {
        environment = "production"
        purpose = "cost-optimized-testing"
      }
    }
  }

  # Build Templates for reusable configurations
  build_templates = {
    # Standard Node.js application build
    nodejs_build = {
      name = "nodejs-production-build"
      description = "Standard Node.js build template for production"

      steps = [
        {
          name = "node:18-alpine"
          script = <<-EOT
            #!/bin/sh
            set -e
            echo "Installing dependencies..."
            npm ci --only=production

            echo "Running security audit..."
            npm audit --audit-level=moderate

            echo "Running tests..."
            npm test

            echo "Building application..."
            npm run build

            echo "Creating production artifact..."
            tar -czf app-$BUILD_ID.tar.gz dist/ package.json package-lock.json
          EOT
        },
        {
          name = "gcr.io/cloud-builders/docker"
          args = [
            "build",
            "-t", "$_ARTIFACT_REGISTRY/app:$BUILD_ID",
            "-t", "$_ARTIFACT_REGISTRY/app:latest",
            "--build-arg", "BUILD_ID=$BUILD_ID",
            "."
          ]
        },
        {
          name = "gcr.io/cloud-builders/docker"
          args = ["push", "--all-tags", "$_ARTIFACT_REGISTRY/app"]
        }
      ]

      substitutions = {
        _ARTIFACT_REGISTRY = dependency.artifact_registry.outputs.repository_urls.docker
      }
    }

    # Go application build template
    go_build = {
      name = "go-production-build"
      description = "Standard Go build template for production"

      steps = [
        {
          name = "golang:1.21-alpine"
          script = <<-EOT
            #!/bin/sh
            set -e
            echo "Running Go security checks..."
            go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest
            gosec ./...

            echo "Running tests..."
            go test -v -race -coverprofile=coverage.out ./...

            echo "Building binary..."
            CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o app

            echo "Building minimal container..."
          EOT
        },
        {
          name = "gcr.io/cloud-builders/docker"
          args = [
            "build",
            "-t", "$_ARTIFACT_REGISTRY/go-app:$BUILD_ID",
            "-t", "$_ARTIFACT_REGISTRY/go-app:latest",
            "-f", "Dockerfile.prod",
            "."
          ]
        }
      ]
    }

    # Infrastructure deployment template
    terraform_deploy = {
      name = "terraform-production-deploy"
      description = "Terraform deployment template for production"

      steps = [
        {
          name = "hashicorp/terraform:$_TERRAFORM_VERSION"
          script = <<-EOT
            #!/bin/sh
            set -e
            echo "Initializing Terraform..."
            terraform init -backend-config="bucket=$_STATE_BUCKET"

            echo "Validating configuration..."
            terraform validate

            echo "Planning changes..."
            terraform plan -out=tfplan -var-file="environments/$_ENVIRONMENT.tfvars"

            echo "Applying changes..."
            if [ "$_AUTO_APPROVE" = "true" ]; then
              terraform apply -auto-approve tfplan
            else
              echo "Manual approval required for production deployment"
              exit 1
            fi
          EOT
        }
      ]

      substitutions = {
        _TERRAFORM_VERSION = "1.5.0"
        _STATE_BUCKET = "your-prod-project-id-terraform-state"
        _AUTO_APPROVE = "false"
      }
    }
  }

  # Build Configurations for different environments
  build_configs = {
    # Production build configuration
    production = {
      environment = "production"

      # Build options
      options = {
        dynamic_substitutions = true
        log_streaming_option = "STREAM_ON"
        logging = "CLOUD_LOGGING_ONLY"
        machine_type = "E2_STANDARD_4"
        disk_size_gb = 200

        # Enhanced security options
        requested_verify_option = "VERIFIED"
        source_provenance_hash = ["SHA256"]
      }

      # Timeout and retry configuration
      timeout = "3600s"  # 1 hour for complex builds

      # Artifact storage configuration
      artifacts = {
        images = [
          "$_ARTIFACT_REGISTRY/app:$BUILD_ID",
          "$_ARTIFACT_REGISTRY/app:latest"
        ]

        objects = {
          location = "gs://your-prod-project-id-build-artifacts"
          paths = [
            "logs/$BUILD_ID/",
            "artifacts/$BUILD_ID/",
            "reports/$BUILD_ID/"
          ]
        }
      }
    }

    # Security scanning configuration
    security_scan = {
      environment = "production"

      options = {
        dynamic_substitutions = true
        log_streaming_option = "STREAM_ON"
        logging = "CLOUD_LOGGING_ONLY"
        machine_type = "E2_STANDARD_2"

        # Security-focused options
        requested_verify_option = "VERIFIED"
        worker_pool = "projects/your-prod-project-id/locations/us-central1/workerPools/security-prod"
      }

      timeout = "1800s"  # 30 minutes for security scans
    }
  }

  # Notification Configurations
  notification_configs = {
    # Build success/failure notifications
    build_notifications = {
      pubsub_topic = "projects/your-prod-project-id/topics/build-notifications"

      config = {
        build_success = true
        build_failure = true
        build_timeout = true
        build_cancelled = true
      }

      filter = "build.status in [SUCCESS, FAILURE, TIMEOUT, CANCELLED]"
    }

    # Security scan notifications
    security_notifications = {
      pubsub_topic = "projects/your-prod-project-id/topics/security-notifications"

      config = {
        build_failure = true
        vulnerability_found = true
      }

      filter = "build.substitutions._SCAN_TYPE = 'security'"
    }

    # Deployment notifications
    deployment_notifications = {
      pubsub_topic = "projects/your-prod-project-id/topics/deployment-notifications"

      config = {
        deployment_success = true
        deployment_failure = true
      }

      filter = "build.substitutions._DEPLOYMENT = 'true'"
    }
  }

  # Repository Integrations
  repository_integrations = {
    # GitHub integration
    github_integration = {
      github_enterprise_config = {
        host_url = "https://github.com"
        app_id = 123456
        app_installation_id = 7890123
      }

      repositories = [
        {
          owner = "your-organization"
          name = "main-application"
          push_config = {
            branch = "main"
            tag = null
          }
        },
        {
          owner = "your-organization"
          name = "infrastructure"
          push_config = {
            branch = "main"
            tag = null
          }
        }
      ]
    }

    # Bitbucket integration
    bitbucket_integration = {
      bitbucket_server_config = {
        host_uri = "https://bitbucket.your-company.com"
        username = "cloudbuild-integration"
        api_key_secret_name = "bitbucket-api-key"
      }

      repositories = [
        {
          project_key = "INFRA"
          repo_slug = "terraform-modules"
        }
      ]
    }
  }

  # Build Caching Configuration
  build_cache = {
    # Docker layer caching
    docker_cache = {
      enabled = true
      cache_from = [
        "$_ARTIFACT_REGISTRY/app:latest",
        "$_ARTIFACT_REGISTRY/app:cache"
      ]
      cache_to = [
        "$_ARTIFACT_REGISTRY/app:cache"
      ]
    }

    # Dependency caching
    dependency_cache = {
      enabled = true
      cache_paths = [
        "/workspace/node_modules",
        "/workspace/.npm",
        "/go/pkg/mod",
        "/root/.cache/go-build"
      ]
    }

    # Build artifact caching
    artifact_cache = {
      enabled = true
      ttl = "168h"  # 7 days
      cache_key_template = "$PROJECT_ID-$_CACHE_KEY-$SHORT_SHA"
    }
  }

  # Security and Compliance Settings
  security_settings = {
    # Binary Authorization integration
    binary_authorization = {
      enabled = true
      policy = dependency.binary_auth.outputs.policy_name
      attestors = dependency.binary_auth.outputs.attestor_names

      # Require attestations for production deployments
      require_attestation = true

      # Verification options
      verification_options = {
        verify_source_provenance = true
        verify_build_integrity = true
        verify_image_signatures = true
      }
    }

    # Vulnerability scanning
    vulnerability_scanning = {
      enabled = true

      # Scan configuration
      scan_config = {
        include_package_vulnerabilities = true
        include_os_vulnerabilities = true
        include_language_vulnerabilities = true
      }

      # Severity thresholds
      severity_thresholds = {
        critical = 0    # No critical vulnerabilities allowed
        high = 2        # Maximum 2 high severity vulnerabilities
        medium = 10     # Maximum 10 medium severity vulnerabilities
      }

      # Fail build on threshold breach
      fail_on_threshold_breach = true
    }

    # SLSA (Supply-chain Levels for Software Artifacts) compliance
    slsa_compliance = {
      enabled = true
      level = 3  # SLSA Level 3 compliance

      # Provenance generation
      generate_provenance = true
      provenance_format = "slsa-v1.0"

      # Source integrity verification
      verify_source_integrity = true
      verify_build_reproducibility = true
    }
  }

  # Integration with existing resources
  network_self_link = dependency.vpc.outputs.network_self_link
  private_subnet_self_links = dependency.vpc.outputs.private_subnet_self_links
  cluster_name = dependency.gke.outputs.cluster_name
  cluster_location = dependency.gke.outputs.cluster_location
  artifact_registry_urls = dependency.artifact_registry.outputs.repository_urls
  source_repository_urls = dependency.source_repos.outputs.repository_urls
  binary_auth_policy = dependency.binary_auth.outputs.policy_name
  kms_crypto_key = dependency.kms.outputs.crypto_keys.cloud_build

  # Tags for resource organization
  tags = {
    Environment = "production"
    Team = "platform"
    Component = "ci-cd"
    CostCenter = "engineering"
    Compliance = "required"
    DataClassification = "internal"
    BackupRequired = "true"
    MonitoringRequired = "true"
    SecurityScanning = "enabled"
    BuildCache = "enabled"
  }
}