# GCP Terragrunt Infrastructure

Production-ready Terragrunt infrastructure for Google Cloud Platform with multi-environment support, GitOps workflows, and comprehensive security controls.

## 📁 Project Structure

```
terragrunt-gcp/
├── infrastructure/
│   ├── terragrunt.hcl              # Root configuration
│   ├── accounts/
│   │   └── account.hcl              # Organization settings
│   ├── environments/
│   │   ├── dev/                     # Development environment
│   │   │   ├── env.hcl
│   │   │   ├── dev-us-central1-vpc.hcl
│   │   │   └── dev-us-central1-gke.hcl
│   │   ├── staging/                 # Staging environment
│   │   │   └── env.hcl
│   │   └── prod/                    # Production environment
│   │       └── env.hcl
│   └── modules/
│       ├── networking/              # VPC, subnets, firewall
│       │   └── vpc/
│       ├── compute/                 # GKE, Cloud Run
│       │   └── gke/
│       ├── data/                    # Cloud SQL, GCS
│       │   └── cloud-sql/
│       └── security/                # IAM, KMS
│           └── iam/
├── .github/
│   └── workflows/                   # CI/CD pipelines
│       ├── terragrunt-plan.yml
│       ├── terragrunt-apply.yml
│       └── terragrunt-destroy.yml
└── CLAUDE.md                        # AI assistant guide
```

## 🚀 Quick Start

### Prerequisites

1. **GCP Project Setup**
   ```bash
   export GCP_PROJECT_ID="your-project-id"
   export GCP_BILLING_ACCOUNT="your-billing-account"
   export GCP_ORG_ID="your-org-id"  # Optional
   ```

2. **Install Tools**
   ```bash
   # Terraform
   wget https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip
   unzip terraform_1.5.7_linux_amd64.zip
   sudo mv terraform /usr/local/bin/

   # Terragrunt
   wget https://github.com/gruntwork-io/terragrunt/releases/download/v0.52.0/terragrunt_linux_amd64
   chmod +x terragrunt_linux_amd64
   sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

   # Google Cloud SDK
   curl https://sdk.cloud.google.com | bash
   exec -l $SHELL
   gcloud init
   ```

3. **Authentication**
   ```bash
   gcloud auth application-default login
   gcloud config set project $GCP_PROJECT_ID
   ```

### Deployment

1. **Initialize Environment**
   ```bash
   cd infrastructure/environments/dev
   terragrunt run-all init
   ```

2. **Plan Changes**
   ```bash
   terragrunt run-all plan
   ```

3. **Apply Infrastructure**
   ```bash
   terragrunt run-all apply
   ```

## 🌍 Environments

### Development
- **Purpose**: Development and testing
- **Features**: Cost-optimized, preemptible nodes, auto-shutdown
- **Access**: Open for development team

### Staging
- **Purpose**: Pre-production testing
- **Features**: Production-like setup, HA enabled, monitoring
- **Access**: Restricted to deployment pipelines

### Production
- **Purpose**: Live production workloads
- **Features**: Full HA, backup, monitoring, security
- **Access**: Highly restricted, manual approval required

## 🔧 Configuration

### Update Environment Variables

Edit `infrastructure/accounts/account.hcl`:
```hcl
locals {
  organization = "your-org"
  project_id   = "your-project-id"
}
```

Edit environment-specific `env.hcl` files:
```hcl
locals {
  environment = "dev"
  region      = "us-central1"
}
```

### Module Usage

Example VPC deployment:
```hcl
terraform {
  source = "../../modules/networking/vpc"
}

inputs = {
  name = "my-vpc"
  # ... other inputs
}
```

## 🔐 Security

### IAM Best Practices
- Service accounts with minimal permissions
- Workload Identity for GKE
- No default service accounts
- Regular key rotation

### Network Security
- Private GKE clusters
- VPC firewall rules
- Cloud Armor for DDoS protection
- Private Google Access enabled

### Data Security
- Encryption at rest with Cloud KMS
- Secrets in Secret Manager
- SSL/TLS enforcement
- Audit logging enabled

## 📊 CI/CD Workflows

### Pull Request Workflow
1. Developer creates PR
2. Terragrunt plan runs automatically
3. Security scan with Checkov
4. Cost estimation with Infracost
5. Manual review and approval
6. Merge to main

### Deployment Workflow
1. Merge to main triggers deployment
2. Dev deploys automatically
3. Staging requires approval
4. Production requires 2 approvals
5. Post-deployment tests run
6. Slack notifications sent

### Destruction Workflow
1. Manual trigger only
2. Confirmation required
3. State backup created
4. Production requires additional approval
5. Verification after destruction

## 🛠️ Common Operations

### Add New Resource
```bash
# Create module configuration
vi infrastructure/environments/dev/dev-us-central1-newresource.hcl

# Plan and apply
cd infrastructure/environments/dev
terragrunt plan dev-us-central1-newresource
terragrunt apply dev-us-central1-newresource
```

### Update Module
```bash
# Update module source
vi infrastructure/modules/category/resource/main.tf

# Re-init and apply
terragrunt init -upgrade
terragrunt apply
```

### Debug Issues
```bash
# Enable debug logging
export TF_LOG=DEBUG
export TERRAGRUNT_DEBUG=true

# Check state
terragrunt state list
terragrunt state show <resource>

# Force unlock if needed
terragrunt force-unlock <lock-id>
```

## 📈 Monitoring

### Logs
- Cloud Logging for all resources
- Structured logging with severity levels
- Log retention based on environment

### Metrics
- Cloud Monitoring dashboards
- Custom metrics for applications
- Alerting policies configured

### Cost Management
- Budget alerts configured
- Cost breakdown by label
- Regular cost optimization reviews

## 🔍 Troubleshooting

### Common Issues

1. **State Lock Error**
   ```bash
   terragrunt force-unlock <lock-id>
   ```

2. **API Not Enabled**
   ```bash
   gcloud services enable <service>.googleapis.com
   ```

3. **Quota Exceeded**
   - Check quotas: `gcloud compute project-info describe`
   - Request increase or use different region

4. **Permission Denied**
   - Check IAM roles: `gcloud projects get-iam-policy $GCP_PROJECT_ID`
   - Ensure service account has required permissions

## 📚 Documentation

- [CLAUDE.md](./CLAUDE.md) - AI assistant guide
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/)
- [GCP Terraform Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GCP Best Practices](https://cloud.google.com/docs/enterprise/best-practices-for-enterprise-organizations)

## 🤝 Contributing

1. Create feature branch
2. Make changes
3. Test in dev environment
4. Create pull request
5. Wait for approval
6. Merge to main

## 📝 License

Copyright © 2024 - All rights reserved

## 👥 Support

- **Slack**: #platform-team
- **Email**: platform-team@acme.com
- **On-call**: See PagerDuty schedule