# GCP Terragrunt Infrastructure

![CI/CD Pipeline](https://github.com/catherinevee/terragrunt-gcp/actions/workflows/ci-cd.yml/badge.svg)
![Terraform Pipeline](https://github.com/catherinevee/terragrunt-gcp/actions/workflows/terraform-pipeline.yml/badge.svg)
![Drift Detection](https://github.com/catherinevee/terragrunt-gcp/actions/workflows/drift-detection.yml/badge.svg)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Production-ready Terragrunt infrastructure for Google Cloud Platform with multi-environment support, GitOps workflows, and enterprise security controls.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Workflows](#workflows)
- [Security](#security)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Overview

This repository provides a production-grade infrastructure as code (IaC) solution for Google Cloud Platform using Terragrunt and Terraform. It implements a multi-environment architecture with automated deployments, drift detection, and cost optimization strategies.

### Key Features

- Multi-environment support (dev, staging, production)
- Regional deployment strategies with disaster recovery
- Automated CI/CD pipelines via GitHub Actions
- Infrastructure drift detection and alerting
- Cost optimization through resource sizing and scheduling
- Security hardening with IAM, KMS, and network policies
- Terraform Registry modules for GCP resources

### Architecture

The infrastructure follows a hub-and-spoke model with environment isolation:

```
Environments:
├── Development   → us-central1    → Cost-optimized, auto-shutdown
├── Staging      → europe-west1   → Production-like, reduced scale
└── Production   → europe-west1   → High availability, full scale
```

## Prerequisites

Before you begin, ensure you have the following installed and configured:

### Required Tools

| Tool | Version | Installation |
|------|---------|-------------|
| Terraform | 1.5.7 | [Download](https://releases.hashicorp.com/terraform/1.5.7/) |
| Terragrunt | 0.52.0 | [Download](https://github.com/gruntwork-io/terragrunt/releases/tag/v0.52.0) |
| gcloud CLI | Latest | [Install Guide](https://cloud.google.com/sdk/docs/install) |
| GitHub CLI | Latest | [Install Guide](https://cli.github.com/) |
| jq | 1.6+ | [Download](https://stedolan.github.io/jq/download/) |

### GCP Requirements

- GCP Organization (optional but recommended)
- Billing account with appropriate quotas
- Project creation permissions
- Following APIs will be enabled:
  - Compute Engine API
  - Kubernetes Engine API
  - Cloud SQL Admin API
  - Cloud Resource Manager API
  - Identity and Access Management API
  - Cloud KMS API
  - Secret Manager API

### GitHub Requirements

- Repository with Actions enabled
- Permissions to configure secrets
- (Optional) Environment protection rules

## Quick Start

Follow these steps to deploy your first environment:

### Step 1: Clone and Setup

```bash
# Clone the repository
git clone https://github.com/catherinevee/terragrunt-gcp.git
cd terragrunt-gcp

# Verify tool versions
terraform version   # Should show 1.5.7
terragrunt --version # Should show 0.52.0
gcloud version      # Should show latest
```

### Step 2: Configure GCP Authentication

#### Option A: Service Account Key (Quickest)

```bash
# Create a service account
export PROJECT_ID="your-project-id"
gcloud iam service-accounts create terraform-sa \
  --display-name="Terraform Service Account" \
  --project=${PROJECT_ID}

# Grant necessary roles
for role in roles/editor roles/resourcemanager.projectIamAdmin roles/storage.admin; do
  gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:terraform-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="${role}"
done

# Create and download key
gcloud iam service-accounts keys create terraform-key.json \
  --iam-account=terraform-sa@${PROJECT_ID}.iam.gserviceaccount.com

# Add to GitHub Secrets
gh secret set GCP_SA_KEY < terraform-key.json
```

#### Option B: Workload Identity Federation (Recommended for Production)

See [docs/setup/workload-identity.md](docs/setup/workload-identity.md) for detailed setup.

### Step 3: Initialize Infrastructure

Run the setup workflow to prepare your GCP environment:

```bash
gh workflow run setup-infrastructure.yml \
  -f project_id="${PROJECT_ID}" \
  -f organization="your-org" \
  -f region="us-central1" \
  -f enable_apis=true
```

Monitor the setup:

```bash
gh run watch
```

### Step 4: Deploy Development Environment

```bash
# Run terraform plan
gh workflow run terraform-pipeline.yml \
  -f operation=plan \
  -f environment=dev

# Review the plan output in GitHub Actions

# Apply the infrastructure
gh workflow run terraform-pipeline.yml \
  -f operation=apply \
  -f environment=dev
```

### Step 5: Verify Deployment

```bash
# Check deployment status
gcloud compute instances list --project=${PROJECT_ID}
gcloud container clusters list --project=${PROJECT_ID}
gcloud sql instances list --project=${PROJECT_ID}

# View Terraform state
gsutil ls gs://terraform-state-${PROJECT_ID}/
```

## Project Structure

```
terragrunt-gcp/
├── infrastructure/
│   ├── terragrunt.hcl              # Root configuration
│   ├── accounts/
│   │   └── account.hcl              # Organization settings
│   └── environments/
│       ├── dev/                     # Development environment
│       │   ├── env.hcl
│       │   └── us-central1/         # Region-specific resources
│       │       ├── network.hcl      # VPC (Terraform Registry)
│       │       ├── gke.hcl          # GKE cluster (Terraform Registry)
│       │       └── cloud-sql.hcl    # PostgreSQL (Terraform Registry)
│       ├── staging/                 # Staging environment
│       │   └── env.hcl
│       └── prod/                    # Production environment
│           └── env.hcl
├── .github/
│   └── workflows/                   # CI/CD pipelines
│       ├── ci-cd.yml               # Main CI/CD pipeline
│       ├── terraform-pipeline.yml   # Terraform operations
│       ├── drift-detection.yml      # Scheduled drift checks
│       └── setup-infrastructure.yml # Initial GCP setup
├── docs/                           # Documentation
├── scripts/                        # Automation scripts
├── test/                          # Test suites
├── policies/                      # OPA policies
└── CLAUDE.md                      # AI assistant guide
```

## Configuration

### Environment Configuration

Each environment has specific configurations optimized for its use case:

| Environment | Region | Purpose | Key Characteristics |
|------------|--------|---------|-------------------|
| Development | us-central1 | Testing and development | Cost-optimized, auto-shutdown, preemptible nodes |
| Staging | europe-west1 | Pre-production validation | Production-like, reduced scale, same region as prod |
| Production | europe-west1 | Live services | High availability, full scale, disaster recovery |

### Resource Sizing

Resources are sized appropriately per environment:

#### Development
- GKE: e2-standard-2 nodes (preemptible), 1-3 node autoscaling
- Cloud SQL: db-f1-micro, no HA, basic backups
- Storage: Standard class, no versioning

#### Staging
- GKE: e2-standard-4 nodes, 2-5 node autoscaling
- Cloud SQL: db-g1-small, no HA, daily backups
- Storage: Standard class, versioning enabled

#### Production
- GKE: n2-standard-8 nodes, 3-20 node autoscaling
- Cloud SQL: db-custom-4-16384, regional HA, continuous backups
- Storage: Multi-regional, versioning, lifecycle policies

### Customizing Configurations

To modify environment settings, edit the respective `env.hcl` file:

```hcl
# infrastructure/environments/dev/env.hcl
locals {
  environment = "dev"
  region      = "us-central1"  # Change region
  
  resource_sizing = {
    gke_machine_type = "e2-standard-4"  # Upgrade instance type
    gke_max_nodes    = 5                # Increase max nodes
  }
}
```

## Deployment

### Manual Deployment

For local Terragrunt operations:

```bash
# Navigate to environment
cd infrastructure/environments/dev

# Initialize Terragrunt
terragrunt run-all init

# Plan changes
terragrunt run-all plan

# Apply changes
terragrunt run-all apply

# Destroy resources (careful!)
terragrunt run-all destroy
```

### Automated Deployment

Use GitHub Actions for automated deployments:

#### Deploy to Specific Environment

```bash
# Development
gh workflow run terraform-pipeline.yml -f operation=apply -f environment=dev

# Staging
gh workflow run terraform-pipeline.yml -f operation=apply -f environment=staging

# Production (requires approval)
gh workflow run terraform-pipeline.yml -f operation=apply -f environment=prod
```

#### Destroy Infrastructure

```bash
# Destroy development environment
gh workflow run terraform-pipeline.yml -f operation=destroy -f environment=dev
```

### Deployment Order

Resources are deployed in the following dependency order:

1. Network infrastructure (VPC, subnets, firewall rules)
2. Security resources (KMS keys, service accounts)
3. Data layer (Cloud SQL, Cloud Storage)
4. Compute layer (GKE clusters, node pools)
5. Application layer (Load balancers, Cloud Run services)

## Workflows

### CI/CD Pipeline

The main CI/CD pipeline runs on every push and pull request:

- **Lint & Validate**: Checks YAML syntax and structure
- **Security Scanning**: Scans for exposed secrets and vulnerabilities
- **Testing**: Runs infrastructure tests
- **Build**: Validates Terraform configurations
- **Deploy**: Automatically deploys to appropriate environment

### Terraform Pipeline

Manages infrastructure operations:

```bash
# Plan infrastructure changes
gh workflow run terraform-pipeline.yml -f operation=plan -f environment=dev

# Apply infrastructure changes
gh workflow run terraform-pipeline.yml -f operation=apply -f environment=dev

# Destroy infrastructure
gh workflow run terraform-pipeline.yml -f operation=destroy -f environment=dev
```

### Drift Detection

Runs daily at 2 AM UTC to detect infrastructure drift:

```bash
# Manual drift check for all environments
gh workflow run drift-detection.yml -f environment=all

# Check specific environment
gh workflow run drift-detection.yml -f environment=prod
```

When drift is detected, an issue is automatically created with details.

### Setup Infrastructure

Initial setup for new GCP projects:

```bash
gh workflow run setup-infrastructure.yml \
  -f project_id="new-project-id" \
  -f organization="your-org" \
  -f region="us-central1" \
  -f enable_apis=true
```

## Security

### IAM Configuration

The infrastructure implements least-privilege access:

- Separate service accounts per environment
- Workload Identity for GKE pods
- Time-bound access tokens
- No Owner or Editor roles in production

### Network Security

- Private GKE clusters with authorized networks
- VPC firewall rules with source IP restrictions
- Cloud NAT for outbound internet access
- Private Google Access for GCP services

### Data Protection

- Customer-managed encryption keys (CMEK)
- Secrets stored in Secret Manager
- Automated secret rotation
- VPC Service Controls for data exfiltration prevention

### Compliance

The infrastructure supports compliance requirements for:

- SOC 2
- PCI DSS
- HIPAA
- GDPR

## Troubleshooting

### Common Issues

#### Terraform State Lock

**Problem**: Error acquiring the state lock

**Solution**:
```bash
# Find the lock ID in the error message
terragrunt force-unlock <lock-id>
```

#### API Not Enabled

**Problem**: API [service] has not been used in project

**Solution**:
```bash
# Enable the required API
gcloud services enable <service>.googleapis.com --project=${PROJECT_ID}
```

#### Insufficient Quota

**Problem**: Quota exceeded for quota metric

**Solution**:
1. Check current quotas:
   ```bash
   gcloud compute project-info describe --project=${PROJECT_ID}
   ```
2. Request increase in GCP Console
3. Or use a different region with available quota

#### Authentication Failed

**Problem**: Failed to authenticate with GCP

**Solution**:
```bash
# Re-authenticate with gcloud
gcloud auth application-default login

# Verify GitHub secret
gh secret list | grep GCP_SA_KEY
```

### Validation Mode

If GCP credentials are not configured, workflows run in validation mode:

- Terraform and Terragrunt versions are verified
- Configuration structure is validated
- No actual resources are created or modified
- Instructions for setup are provided in workflow logs

### Getting Help

1. Check workflow logs:
   ```bash
   gh run view --log
   ```

2. Review Terragrunt debug output:
   ```bash
   export TF_LOG=DEBUG
   terragrunt plan
   ```

3. Consult documentation:
   - [CLAUDE.md](CLAUDE.md) - AI assistant integration guide
   - [docs/](docs/) - Additional documentation

## Contributing

We welcome contributions! Please follow these guidelines:

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests locally
5. Submit a pull request

### Testing

```bash
# Validate Terraform configurations
terragrunt run-all validate

# Run format check
terragrunt hclfmt --terragrunt-check

# Run security scan
tfsec .
```

### Pull Request Process

1. Update documentation for any changed functionality
2. Ensure all CI/CD checks pass
3. Request review from maintainers
4. Squash commits before merge

### Coding Standards

- Use Terraform Registry modules where available
- Follow Terragrunt best practices
- Maintain consistent naming conventions
- Document all non-obvious configurations

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues and questions:

1. Check existing [GitHub Issues](https://github.com/catherinevee/terragrunt-gcp/issues)
2. Review the [troubleshooting guide](#troubleshooting)
3. Create a new issue with:
   - Environment details
   - Error messages
   - Steps to reproduce
   - Expected vs actual behavior

## Roadmap

Planned improvements:

- [ ] Blue-green deployment support
- [ ] Automated cost reporting
- [ ] Backup and restore automation
- [ ] Multi-region active-active setup
- [ ] Kubernetes operators for CRDs
- [ ] Policy as Code with OPA
- [ ] Infrastructure testing with Terratest

---

For detailed documentation, see the [docs/](docs/) directory.