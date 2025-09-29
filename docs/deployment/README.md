# Deployment Documentation

This directory contains comprehensive deployment documentation for the terragrunt-gcp project, covering installation, configuration, deployment strategies, and operational procedures.

## Overview

The terragrunt-gcp project supports multiple deployment models to accommodate different organizational needs and infrastructure patterns.

## Prerequisites

### System Requirements

#### Minimum Requirements
- **Go**: Version 1.19 or higher
- **Terraform**: Version 1.5.0 or higher
- **Terragrunt**: Version 0.50.0 or higher
- **Operating System**: Linux, macOS, or Windows
- **Memory**: 2GB RAM minimum, 8GB recommended
- **Storage**: 10GB free space minimum

#### Production Requirements
- **Go**: Latest stable version
- **Terraform**: Latest stable version
- **Terragrunt**: Latest stable version
- **Memory**: 16GB RAM minimum
- **Storage**: 100GB free space for state files and caches
- **Network**: Stable internet connection with GCP API access

### Google Cloud Platform Setup

#### Project Configuration
```bash
# Create a new GCP project
gcloud projects create your-project-id

# Set the project as default
gcloud config set project your-project-id

# Enable required APIs
gcloud services enable compute.googleapis.com
gcloud services enable storage-api.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable secretmanager.googleapis.com
gcloud services enable networksecurity.googleapis.com
gcloud services enable dns.googleapis.com
gcloud services enable cloudbilling.googleapis.com
```

#### Authentication Setup
```bash
# Option 1: Application Default Credentials (recommended for development)
gcloud auth application-default login

# Option 2: Service Account (recommended for production)
gcloud iam service-accounts create terragrunt-gcp-sa \
    --description="Service account for terragrunt-gcp operations" \
    --display-name="Terragrunt GCP Service Account"

# Grant necessary permissions
gcloud projects add-iam-policy-binding your-project-id \
    --member="serviceAccount:terragrunt-gcp-sa@your-project-id.iam.gserviceaccount.com" \
    --role="roles/compute.admin"

gcloud projects add-iam-policy-binding your-project-id \
    --member="serviceAccount:terragrunt-gcp-sa@your-project-id.iam.gserviceaccount.com" \
    --role="roles/storage.admin"

gcloud projects add-iam-policy-binding your-project-id \
    --member="serviceAccount:terragrunt-gcp-sa@your-project-id.iam.gserviceaccount.com" \
    --role="roles/iam.admin"

# Create and download service account key
gcloud iam service-accounts keys create ~/terragrunt-gcp-key.json \
    --iam-account=terragrunt-gcp-sa@your-project-id.iam.gserviceaccount.com
```

## Installation

### Option 1: Binary Installation

#### Download Pre-built Binaries
```bash
# Download latest release
curl -LO https://github.com/your-org/terragrunt-gcp/releases/latest/download/terragrunt-gcp-linux-amd64.tar.gz

# Extract binary
tar -xzf terragrunt-gcp-linux-amd64.tar.gz

# Move to PATH
sudo mv terragrunt-gcp /usr/local/bin/

# Verify installation
terragrunt-gcp version
```

### Option 2: Source Installation

#### Build from Source
```bash
# Clone repository
git clone https://github.com/your-org/terragrunt-gcp.git
cd terragrunt-gcp

# Install dependencies
go mod tidy

# Build binary
go build -o terragrunt-gcp ./cmd/terragrunt-gcp

# Install binary
sudo mv terragrunt-gcp /usr/local/bin/

# Verify installation
terragrunt-gcp version
```

### Option 3: Go Install

#### Install via Go
```bash
# Install latest version
go install github.com/your-org/terragrunt-gcp/cmd/terragrunt-gcp@latest

# Verify installation
terragrunt-gcp version
```

### Option 4: Docker Installation

#### Using Docker
```bash
# Pull Docker image
docker pull your-org/terragrunt-gcp:latest

# Run container
docker run -it --rm \
    -v $(pwd):/workspace \
    -v ~/.config/gcloud:/root/.config/gcloud \
    your-org/terragrunt-gcp:latest
```

## Configuration

### Environment Variables

#### Core Configuration
```bash
# Required environment variables
export GOOGLE_CLOUD_PROJECT="your-project-id"
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
export GOOGLE_CLOUD_REGION="us-central1"
export GOOGLE_CLOUD_ZONE="us-central1-a"

# Optional configuration
export TERRAGRUNT_GCP_LOG_LEVEL="INFO"
export TERRAGRUNT_GCP_CACHE_ENABLED="true"
export TERRAGRUNT_GCP_CACHE_TTL="30m"
export TERRAGRUNT_GCP_RATE_LIMIT_QPS="100"
export TERRAGRUNT_GCP_RETRY_ATTEMPTS="3"
export TERRAGRUNT_GCP_TIMEOUT="5m"
```

#### Advanced Configuration
```bash
# Performance tuning
export TERRAGRUNT_GCP_MAX_CONCURRENT_OPERATIONS="10"
export TERRAGRUNT_GCP_CONNECTION_POOL_SIZE="50"
export TERRAGRUNT_GCP_BATCH_SIZE="100"

# Security settings
export TERRAGRUNT_GCP_ENCRYPTION_ENABLED="true"
export TERRAGRUNT_GCP_AUDIT_ENABLED="true"
export TERRAGRUNT_GCP_TLS_MIN_VERSION="1.3"

# Monitoring and observability
export TERRAGRUNT_GCP_METRICS_ENABLED="true"
export TERRAGRUNT_GCP_METRICS_PORT="9090"
export TERRAGRUNT_GCP_TRACING_ENABLED="true"
export TERRAGRUNT_GCP_LOG_FORMAT="json"
```

### Configuration Files

#### YAML Configuration
```yaml
# config/config.yaml
client:
  project_id: "your-project-id"
  region: "us-central1"
  zone: "us-central1-a"
  credentials_path: "/path/to/service-account-key.json"
  timeout: "5m"
  retry_attempts: 3
  retry_delay: "1s"
  rate_limit_qps: 100
  rate_limit_burst: 200

services:
  compute:
    cache_enabled: true
    cache_ttl: "30m"
    metrics_enabled: true
    operation_timeout: "10m"

  storage:
    default_storage_class: "STANDARD"
    default_location: "US"
    chunk_size: 8388608  # 8MB
    max_concurrent_transfers: 10

  network:
    default_network: "default"
    default_subnet: "default"
    connectivity_testing_enabled: true

  iam:
    policy_cache_enabled: true
    policy_cache_ttl: "15m"
    audit_enabled: true

  monitoring:
    metrics_retention_days: 90
    logs_retention_days: 30
    real_time_alerts_enabled: true

  secrets:
    default_replication: "automatic"
    default_ttl: "24h"
    rotation_enabled: true

logging:
  level: "INFO"
  format: "json"
  output: "stdout"

metrics:
  enabled: true
  port: 9090
  path: "/metrics"

tracing:
  enabled: true
  sampler_type: "probabilistic"
  sampler_param: 0.1
```

#### JSON Configuration
```json
{
  "client": {
    "project_id": "your-project-id",
    "region": "us-central1",
    "zone": "us-central1-a",
    "credentials_path": "/path/to/service-account-key.json",
    "timeout": "5m",
    "retry_attempts": 3,
    "rate_limit_qps": 100
  },
  "services": {
    "compute": {
      "cache_enabled": true,
      "cache_ttl": "30m",
      "metrics_enabled": true
    },
    "storage": {
      "default_storage_class": "STANDARD",
      "default_location": "US"
    }
  },
  "logging": {
    "level": "INFO",
    "format": "json"
  }
}
```

## Deployment Strategies

### Single Environment Deployment

#### Development Environment
```bash
# Initialize Terragrunt
cd environments/dev
terragrunt init

# Plan changes
terragrunt plan

# Apply changes
terragrunt apply

# Validate deployment
terragrunt-gcp validate --environment=dev
```

#### Configuration Structure
```
environments/
├── dev/
│   ├── terragrunt.hcl
│   ├── compute/
│   │   └── terragrunt.hcl
│   ├── storage/
│   │   └── terragrunt.hcl
│   └── network/
│       └── terragrunt.hcl
├── staging/
└── prod/
```

### Multi-Environment Deployment

#### Environment Promotion Pipeline
```bash
#!/bin/bash
# deploy.sh

set -e

ENVIRONMENT=$1
if [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <environment>"
    exit 1
fi

echo "Deploying to $ENVIRONMENT environment..."

# Set environment-specific variables
case $ENVIRONMENT in
    dev)
        export GOOGLE_CLOUD_PROJECT="dev-project-id"
        export GOOGLE_CLOUD_REGION="us-central1"
        ;;
    staging)
        export GOOGLE_CLOUD_PROJECT="staging-project-id"
        export GOOGLE_CLOUD_REGION="us-east1"
        ;;
    prod)
        export GOOGLE_CLOUD_PROJECT="prod-project-id"
        export GOOGLE_CLOUD_REGION="us-west1"
        ;;
    *)
        echo "Unknown environment: $ENVIRONMENT"
        exit 1
        ;;
esac

# Navigate to environment directory
cd "environments/$ENVIRONMENT"

# Validate configuration
terragrunt-gcp validate --config=config.yaml

# Initialize Terragrunt
terragrunt run-all init

# Plan all modules
terragrunt run-all plan --out=tfplan

# Apply if plan succeeds
if [ $? -eq 0 ]; then
    echo "Plan successful. Applying changes..."
    terragrunt run-all apply tfplan
else
    echo "Plan failed. Aborting deployment."
    exit 1
fi

# Validate deployment
terragrunt-gcp validate --environment=$ENVIRONMENT

echo "Deployment to $ENVIRONMENT completed successfully!"
```

### Blue-Green Deployment

#### Blue-Green Strategy
```bash
#!/bin/bash
# blue-green-deploy.sh

ENVIRONMENT=$1
COLOR=$2  # blue or green

if [ -z "$ENVIRONMENT" ] || [ -z "$COLOR" ]; then
    echo "Usage: $0 <environment> <blue|green>"
    exit 1
fi

# Deploy to target color
echo "Deploying $COLOR environment..."
cd "environments/$ENVIRONMENT/$COLOR"

# Deploy infrastructure
terragrunt run-all apply

# Run health checks
terragrunt-gcp health-check --environment=$ENVIRONMENT --color=$COLOR

if [ $? -eq 0 ]; then
    echo "Health checks passed. Switching traffic to $COLOR..."

    # Update load balancer to point to new environment
    terragrunt apply -target=module.load_balancer

    echo "Traffic switched to $COLOR environment"

    # Optional: Destroy old environment after successful switch
    read -p "Destroy the other environment? (y/N): " confirm
    if [ "$confirm" = "y" ]; then
        OTHER_COLOR=$([ "$COLOR" = "blue" ] && echo "green" || echo "blue")
        cd "../$OTHER_COLOR"
        terragrunt run-all destroy
    fi
else
    echo "Health checks failed. Rolling back..."
    terragrunt run-all destroy
    exit 1
fi
```

### Canary Deployment

#### Canary Strategy
```bash
#!/bin/bash
# canary-deploy.sh

ENVIRONMENT=$1
CANARY_PERCENTAGE=${2:-10}  # Default 10% traffic

echo "Starting canary deployment to $ENVIRONMENT with $CANARY_PERCENTAGE% traffic..."

# Deploy canary version
cd "environments/$ENVIRONMENT/canary"
terragrunt run-all apply

# Configure traffic splitting
terragrunt apply -var="canary_percentage=$CANARY_PERCENTAGE"

# Monitor metrics for specified duration
echo "Monitoring canary deployment for 30 minutes..."
sleep 1800  # 30 minutes

# Check success metrics
ERROR_RATE=$(terragrunt-gcp metrics --metric=error_rate --environment=$ENVIRONMENT --target=canary)
LATENCY=$(terragrunt-gcp metrics --metric=latency_p99 --environment=$ENVIRONMENT --target=canary)

if (( $(echo "$ERROR_RATE < 0.01" | bc -l) )) && (( $(echo "$LATENCY < 1000" | bc -l) )); then
    echo "Canary metrics are healthy. Promoting to full deployment..."

    # Gradually increase traffic
    for percentage in 25 50 75 100; do
        echo "Increasing traffic to $percentage%..."
        terragrunt apply -var="canary_percentage=$percentage"
        sleep 600  # Wait 10 minutes between increases

        # Check metrics at each stage
        ERROR_RATE=$(terragrunt-gcp metrics --metric=error_rate --environment=$ENVIRONMENT --target=canary)
        if (( $(echo "$ERROR_RATE >= 0.01" | bc -l) )); then
            echo "Error rate increased. Rolling back..."
            terragrunt apply -var="canary_percentage=0"
            exit 1
        fi
    done

    echo "Canary deployment successful!"
else
    echo "Canary metrics are unhealthy. Rolling back..."
    terragrunt apply -var="canary_percentage=0"
    exit 1
fi
```

## CI/CD Integration

### GitHub Actions

#### Workflow Configuration
```yaml
# .github/workflows/deploy.yml
name: Deploy Infrastructure

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  GOOGLE_CLOUD_PROJECT: ${{ secrets.GCP_PROJECT_ID }}
  GOOGLE_APPLICATION_CREDENTIALS: ${{ secrets.GCP_SA_KEY }}
  TF_VAR_project_id: ${{ secrets.GCP_PROJECT_ID }}

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Go
        uses: actions/setup-go@v4
        with:
          go-version: '1.19'

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0

      - name: Setup Terragrunt
        run: |
          wget https://github.com/gruntwork-io/terragrunt/releases/download/v0.50.0/terragrunt_linux_amd64
          chmod +x terragrunt_linux_amd64
          sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Build terragrunt-gcp
        run: |
          go mod tidy
          go build -o terragrunt-gcp ./cmd/terragrunt-gcp

      - name: Validate configuration
        run: |
          ./terragrunt-gcp validate --config=config/config.yaml

      - name: Run tests
        run: |
          go test ./... -v -race -coverprofile=coverage.out

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.out

  plan:
    needs: validate
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging]
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup tools
        # ... (same as validate job)

      - name: Terragrunt Plan
        run: |
          cd environments/${{ matrix.environment }}
          terragrunt run-all plan --out=tfplan-${{ matrix.environment }}

      - name: Upload plan
        uses: actions/upload-artifact@v3
        with:
          name: tfplan-${{ matrix.environment }}
          path: environments/${{ matrix.environment }}/tfplan-${{ matrix.environment }}

  deploy-dev:
    needs: plan
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    environment: development
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup tools
        # ... (same as validate job)

      - name: Download plan
        uses: actions/download-artifact@v3
        with:
          name: tfplan-dev
          path: environments/dev/

      - name: Terragrunt Apply
        run: |
          cd environments/dev
          terragrunt run-all apply tfplan-dev

      - name: Validate deployment
        run: |
          ./terragrunt-gcp validate --environment=dev

  deploy-staging:
    needs: plan
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup tools
        # ... (same as validate job)

      - name: Download plan
        uses: actions/download-artifact@v3
        with:
          name: tfplan-staging
          path: environments/staging/

      - name: Terragrunt Apply
        run: |
          cd environments/staging
          terragrunt run-all apply tfplan-staging

      - name: Validate deployment
        run: |
          ./terragrunt-gcp validate --environment=staging

  deploy-prod:
    needs: deploy-staging
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Manual approval
        uses: hmarr/auto-approve-action@v2
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}

      - name: Setup tools
        # ... (same as validate job)

      - name: Blue-Green Deployment
        run: |
          ./scripts/blue-green-deploy.sh prod green

      - name: Validate production deployment
        run: |
          ./terragrunt-gcp validate --environment=prod
```

### GitLab CI

#### Pipeline Configuration
```yaml
# .gitlab-ci.yml
stages:
  - validate
  - plan
  - deploy-dev
  - deploy-staging
  - deploy-prod

variables:
  GOOGLE_CLOUD_PROJECT: $GCP_PROJECT_ID
  GOOGLE_APPLICATION_CREDENTIALS: /tmp/gcp-key.json

before_script:
  - echo $GCP_SA_KEY | base64 -d > $GOOGLE_APPLICATION_CREDENTIALS
  - export PATH=$PATH:$GOPATH/bin

validate:
  stage: validate
  image: golang:1.19
  script:
    - go mod tidy
    - go build -o terragrunt-gcp ./cmd/terragrunt-gcp
    - ./terragrunt-gcp validate --config=config/config.yaml
    - go test ./... -v -race -coverprofile=coverage.out
  coverage: '/coverage: \d+\.\d+%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml

plan:
  stage: plan
  image: hashicorp/terraform:1.5.0
  parallel:
    matrix:
      - ENVIRONMENT: [dev, staging, prod]
  script:
    - cd environments/$ENVIRONMENT
    - terragrunt run-all plan --out=tfplan-$ENVIRONMENT
  artifacts:
    paths:
      - environments/$ENVIRONMENT/tfplan-$ENVIRONMENT
    expire_in: 1 hour

deploy-dev:
  stage: deploy-dev
  image: hashicorp/terraform:1.5.0
  dependencies:
    - plan
  environment:
    name: development
  script:
    - cd environments/dev
    - terragrunt run-all apply tfplan-dev
    - ./terragrunt-gcp validate --environment=dev
  only:
    - develop

deploy-staging:
  stage: deploy-staging
  image: hashicorp/terraform:1.5.0
  dependencies:
    - plan
  environment:
    name: staging
  script:
    - cd environments/staging
    - terragrunt run-all apply tfplan-staging
    - ./terragrunt-gcp validate --environment=staging
  only:
    - main

deploy-prod:
  stage: deploy-prod
  image: hashicorp/terraform:1.5.0
  dependencies:
    - plan
  environment:
    name: production
  when: manual
  script:
    - ./scripts/blue-green-deploy.sh prod green
    - ./terragrunt-gcp validate --environment=prod
  only:
    - main
```

## Monitoring and Health Checks

### Health Check Script
```bash
#!/bin/bash
# health-check.sh

ENVIRONMENT=$1
if [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <environment>"
    exit 1
fi

echo "Running health checks for $ENVIRONMENT environment..."

# Check GCP connectivity
echo "Checking GCP connectivity..."
gcloud compute instances list --project=$GOOGLE_CLOUD_PROJECT > /dev/null
if [ $? -ne 0 ]; then
    echo "❌ GCP connectivity failed"
    exit 1
fi
echo "✅ GCP connectivity OK"

# Check Terraform state
echo "Checking Terraform state..."
cd "environments/$ENVIRONMENT"
terragrunt run-all validate > /dev/null
if [ $? -ne 0 ]; then
    echo "❌ Terraform state validation failed"
    exit 1
fi
echo "✅ Terraform state OK"

# Check resource health
echo "Checking resource health..."
terragrunt-gcp health-check --environment=$ENVIRONMENT
if [ $? -ne 0 ]; then
    echo "❌ Resource health check failed"
    exit 1
fi
echo "✅ Resource health OK"

# Check monitoring endpoints
echo "Checking monitoring endpoints..."
curl -f http://localhost:9090/metrics > /dev/null
if [ $? -ne 0 ]; then
    echo "❌ Metrics endpoint not available"
    exit 1
fi
echo "✅ Monitoring endpoints OK"

echo "All health checks passed! ✅"
```

### Monitoring Configuration
```yaml
# monitoring/config.yaml
monitoring:
  prometheus:
    enabled: true
    port: 9090
    path: /metrics

  grafana:
    enabled: true
    port: 3000
    datasources:
      - name: prometheus
        url: http://localhost:9090

  alerts:
    - name: high_error_rate
      condition: rate(terragrunt_gcp_errors_total[5m]) > 0.1
      for: 5m
      severity: warning

    - name: deployment_failure
      condition: terragrunt_gcp_deployment_status != 1
      for: 0s
      severity: critical

    - name: quota_exhaustion
      condition: terragrunt_gcp_quota_usage > 0.9
      for: 10m
      severity: warning

logging:
  level: info
  format: json
  outputs:
    - stdout
    - file:///var/log/terragrunt-gcp.log

  structured_logging:
    service: terragrunt-gcp
    environment: ${ENVIRONMENT}
    version: ${VERSION}
```

## Troubleshooting

### Common Issues

#### Authentication Issues
```bash
# Check authentication status
gcloud auth list

# Re-authenticate if necessary
gcloud auth application-default login

# Verify service account permissions
gcloud projects get-iam-policy $GOOGLE_CLOUD_PROJECT
```

#### State Lock Issues
```bash
# Force unlock Terraform state
terragrunt force-unlock LOCK_ID

# Clear corrupted state
terragrunt state rm problematic_resource
```

#### Quota Issues
```bash
# Check quota usage
terragrunt-gcp quota --project=$GOOGLE_CLOUD_PROJECT

# Request quota increase
gcloud compute project-info describe --project=$GOOGLE_CLOUD_PROJECT
```

#### Network Connectivity Issues
```bash
# Test GCP API connectivity
curl -I https://compute.googleapis.com/

# Check DNS resolution
nslookup compute.googleapis.com

# Verify firewall rules
gcloud compute firewall-rules list
```

### Debugging Tools

#### Verbose Logging
```bash
# Enable debug logging
export TERRAGRUNT_GCP_LOG_LEVEL=DEBUG
export TF_LOG=DEBUG

# Run with verbose output
terragrunt apply --terragrunt-log-level debug
```

#### Diagnostic Commands
```bash
# Generate diagnostic report
terragrunt-gcp diagnostics --output=report.json

# Validate configuration
terragrunt-gcp validate --verbose

# Check connectivity
terragrunt-gcp ping --all-services
```

## Rollback Procedures

### Automated Rollback
```bash
#!/bin/bash
# rollback.sh

ENVIRONMENT=$1
ROLLBACK_VERSION=$2

if [ -z "$ENVIRONMENT" ] || [ -z "$ROLLBACK_VERSION" ]; then
    echo "Usage: $0 <environment> <version>"
    exit 1
fi

echo "Rolling back $ENVIRONMENT to version $ROLLBACK_VERSION..."

# Checkout specific version
git checkout $ROLLBACK_VERSION

# Apply previous configuration
cd "environments/$ENVIRONMENT"
terragrunt run-all apply

# Validate rollback
terragrunt-gcp validate --environment=$ENVIRONMENT

if [ $? -eq 0 ]; then
    echo "Rollback completed successfully"
else
    echo "Rollback failed. Manual intervention required."
    exit 1
fi
```

### Manual Rollback
```bash
# Identify last known good state
terragrunt state list

# Import resources if necessary
terragrunt import resource_type.name resource_id

# Apply specific resource configurations
terragrunt apply -target=resource_type.name
```

This comprehensive deployment documentation provides all the necessary information for successfully deploying and operating the terragrunt-gcp project in any environment.