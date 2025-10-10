# Terragrunt GCP Infrastructure

<!-- Workflow Status Badges -->
[![Terraform GCP Pipeline](https://github.com/catherinevee/terragrunt-gcp/actions/workflows/terraform-gcp-pipeline.yml/badge.svg)](https://github.com/catherinevee/terragrunt-gcp/actions/workflows/terraform-gcp-pipeline.yml)
[![Terratest Coverage](https://github.com/catherinevee/terragrunt-gcp/actions/workflows/coverage.yml/badge.svg)](https://github.com/catherinevee/terragrunt-gcp/actions/workflows/coverage.yml)
[![Drift Detection](https://github.com/catherinevee/terragrunt-gcp/actions/workflows/drift-detection.yml/badge.svg)](https://github.com/catherinevee/terragrunt-gcp/actions/workflows/drift-detection.yml)
[![Security Scan](https://github.com/catherinevee/terragrunt-gcp/actions/workflows/security-scan.yml/badge.svg)](https://github.com/catherinevee/terragrunt-gcp/actions/workflows/security-scan.yml)

<!-- Version and License Badges -->
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.0-623CE4?logo=terraform)](https://www.terraform.io/)
[![Terragrunt](https://img.shields.io/badge/Terragrunt-%3E%3D0.48-00ADD8)](https://terragrunt.gruntwork.io/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](https://github.com/pre-commit/pre-commit)

Enterprise-grade Google Cloud Platform (GCP) infrastructure managed with Terragrunt, featuring multi-environment support, comprehensive security controls, and production-ready CI/CD pipelines.

## Overview

This repository provides a scalable, DRY (Don't Repeat Yourself) approach to managing GCP infrastructure across multiple environments and regions using Terragrunt. It implements infrastructure-as-code best practices with automated security scanning, drift detection, and comprehensive testing.

### Key Features

- **Multi-Environment**: Dev, Staging, and Production environments
- **Multi-Region**: Support for multiple GCP regions (us-central1, us-east1, europe-west1, asia-southeast1)
- **Security Hardened**: Pre-commit hooks, security scanning (Checkov, Bandit, Semgrep), and compliance checks
- **CI/CD Ready**: GitHub Actions workflows for automated validation, deployment, and drift detection
- **Modular Design**: Reusable Terraform modules for all major GCP services
- **DRY Configuration**: Terragrunt eliminates code duplication across environments
- **State Management**: Remote state management with GCS backend

## Repository Structure

\`\`\`
terragrunt-gcp/
├── infrastructure/               # Infrastructure definitions
│   ├── _shared/                 # Shared configurations
│   ├── accounts/                # Account-level configurations
│   ├── environments/            # Environment-specific configurations
│   │   ├── dev/                # Development environment
│   │   ├── staging/            # Staging environment
│   │   └── prod/               # Production environment
│   └── terragrunt.hcl          # Root Terragrunt configuration
├── modules/                     # Reusable Terraform modules
│   ├── networking/             # Networking modules
│   ├── compute/               # Compute modules
│   ├── kubernetes/            # Kubernetes modules
│   ├── database/              # Database modules
│   ├── data/                  # Data services
│   ├── storage/               # Storage modules
│   ├── security/              # Security modules
│   ├── monitoring/            # Monitoring modules
│   ├── ci-cd/                 # CI/CD modules
│   └── management/            # Management modules
├── .github/workflows/         # GitHub Actions workflows
├── examples/                  # Usage examples
├── scripts/                   # Utility scripts
├── docs/                      # Documentation
├── tests/                     # Infrastructure tests
└── Makefile                   # Build automation
\`\`\`

## Quick Start

### Prerequisites

- **Terraform** >= 1.0
- **Terragrunt** >= 0.48.0
- **Google Cloud SDK**
- **Pre-commit** (optional)
- **Make**

### Initial Setup

1. Clone the repository
2. Authenticate with GCP: \`gcloud auth login && gcloud auth application-default login\`
3. Set your project: \`gcloud config set project YOUR_PROJECT_ID\`
4. Install pre-commit: \`pre-commit install\` (optional)

### Deploy Infrastructure

\`\`\`bash
# Deploy entire environment
cd infrastructure/environments/dev
terragrunt run-all init
terragrunt run-all plan
terragrunt run-all apply

# Deploy specific module
cd infrastructure/environments/dev/us-central1/networking/vpc
terragrunt init && terragrunt plan && terragrunt apply
\`\`\`

## Architecture

### Hierarchical Structure

\`\`\`
Account (GCP Project) → Environment → Region → Service Category → Resource
\`\`\`

### Configuration Inheritance

1. Root \`terragrunt.hcl\` - Common configuration
2. \`account.hcl\` - Account/project settings
3. \`env.hcl\` - Environment variables
4. \`region.hcl\` - Region settings
5. Module \`terragrunt.hcl\` - Resource configuration

### State Management

- Backend: Google Cloud Storage (GCS)
- State Files: Organized by environment/region
- State Locking: Enabled
- Format: \`\${project_id}-terraform-state\` bucket

## Security

### Security Features

- Pre-commit hooks (Terraform validation, secret scanning, security checks)
- Security scanning (Checkov, Bandit, Semgrep, CodeQL)
- Secret Management (GCP Secret Manager integration)

### Running Security Scans

\`\`\`bash
pre-commit run --all-files
make checkov
make security-scan
\`\`\`

## CI/CD Pipelines

### GitHub Actions Workflows

1. **Terraform GCP Pipeline** - Validation, planning, deployment
2. **Drift Detection** - Scheduled drift detection
3. **Security Scanning** - Automated security scans
4. **Code Coverage** - Test coverage reporting

## Available Modules

### Networking
VPC, Cloud NAT, Load Balancer, VPN, DNS, Cloud CDN, Cloud Interconnect

### Compute
Compute Engine, Cloud Run, Cloud Functions, App Engine, Cloud Scheduler, Cloud Tasks

### Kubernetes
GKE, Config Connector

### Database & Data
Cloud SQL, BigQuery, Firestore, Memorystore, Spanner, Dataproc, Dataflow

### Storage
Cloud Storage, Container Registry

### Security
Cloud KMS, Secret Manager, Cloud Armor, Certificate Manager, Binary Authorization, Cloud IAM

### Monitoring & Logging
Cloud Monitoring, Cloud Logging

### CI/CD & DevOps
Cloud Build, Source Repositories

## Development

### Makefile Commands

\`\`\`bash
make init       # Initialize environments
make validate   # Validate configurations
make fmt        # Format Terraform files
make checkov    # Security checks
make test       # Run tests
make clean      # Clean cache
make docs       # Generate docs
\`\`\`

## Documentation

- [Deployment Guide](docs/DEPLOYMENT.md)
- [Secret Management](docs/SECRET-MANAGEMENT.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Architecture](docs/architecture/)

## Troubleshooting

### Common Issues

1. **State Lock**: \`terragrunt force-unlock <LOCK_ID>\`
2. **Authentication**: \`gcloud auth application-default login\`
3. **Module Not Found**: \`terragrunt init -upgrade\`

## Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Run pre-commit hooks
5. Submit Pull Request

## License

MIT License - see [LICENSE](LICENSE) file.

## Roadmap

- [ ] Cloud Run Jobs support
- [ ] Workload Identity Federation
- [ ] Anthos Service Mesh
- [ ] Enhanced monitoring dashboards
- [ ] Cost optimization policies
- [ ] Multi-project support

## Project Statistics

- **Modules**: 41 reusable Terraform modules
- **Test Coverage**: 78% (32/41 modules tested with 104+ test cases)
- **Environments**: Dev, Staging, Production
- **Regions**: 4+ GCP regions
- **Security**: 5+ scanning tools
- **CI/CD**: 10+ GitHub Actions workflows

### Test Coverage by Category

| Category | Coverage | Status |
|----------|----------|--------|
| Networking | 100% (8/8) | Complete |
| Compute | 100% (4/4) | Complete |
| Kubernetes | 100% (2/2) | Complete |
| Database | 100% (3/3) | Complete |
| Data | 100% (5/5) | Complete |
| Storage | 100% (2/2) | Complete |
| Security | 100% (4/4) | Complete |
| Monitoring | 100% (1/1) | Complete |
| CI/CD | 50% (1/2) | Partial |
| Management | 25% (1/4) | Partial |
| Container | 25% (1/4) | Partial |
| Developer Tools | 0% (0/2) | Not Started |

See [test coverage reports](tests/) for detailed information.

---

**Managed with Terragrunt and Terraform**

*Keep your GCP infrastructure consistent, secure, and scalable.*
