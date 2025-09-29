# Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying infrastructure using Terragrunt in the terragrunt-gcp repository.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [First-Time Deployment](#first-time-deployment)
4. [Regular Deployments](#regular-deployments)
5. [Environment-Specific Deployments](#environment-specific-deployments)
6. [Rollback Procedures](#rollback-procedures)
7. [CI/CD Deployments](#cicd-deployments)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

Install the following tools:

```bash
# Terraform
wget https://releases.hashicorp.com/terraform/1.9.0/terraform_1.9.0_linux_amd64.zip
unzip terraform_1.9.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Terragrunt
wget https://github.com/gruntwork-io/terragrunt/releases/download/v0.55.0/terragrunt_linux_amd64
chmod +x terragrunt_linux_amd64
sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

# Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Verify installations
terraform version
terragrunt --version
gcloud --version
```

### GCP Access

1. **Authenticate with GCP**:
```bash
gcloud auth login
gcloud auth application-default login
```

2. **Set default project**:
```bash
gcloud config set project acme-ecommerce-platform-dev
```

3. **Verify permissions**:
```bash
gcloud projects get-iam-policy $(gcloud config get-value project)
```

### Required Permissions

Your account needs these roles:
- `roles/owner` OR
- `roles/editor` + `roles/iam.securityAdmin`

### Repository Setup

```bash
# Clone repository
git clone https://github.com/your-org/terragrunt-gcp.git
cd terragrunt-gcp

# Create feature branch
git checkout -b feature/my-deployment
```

---

## Initial Setup

### 1. Enable Required APIs

```bash
# Run API enablement script
./scripts/enable-gcp-apis.sh
```

Or manually:
```bash
PROJECT_ID=$(gcloud config get-value project)

gcloud services enable compute.googleapis.com --project=$PROJECT_ID
gcloud services enable container.googleapis.com --project=$PROJECT_ID
gcloud services enable storage-api.googleapis.com --project=$PROJECT_ID
gcloud services enable secretmanager.googleapis.com --project=$PROJECT_ID
gcloud services enable cloudkms.googleapis.com --project=$PROJECT_ID
gcloud services enable iam.googleapis.com --project=$PROJECT_ID
gcloud services enable cloudresourcemanager.googleapis.com --project=$PROJECT_ID
gcloud services enable servicenetworking.googleapis.com --project=$PROJECT_ID
gcloud services enable sqladmin.googleapis.com --project=$PROJECT_ID
```

### 2. Create State Bucket

```bash
PROJECT_ID=$(gcloud config get-value project)
ENVIRONMENT="dev"  # or staging, prod

# Create bucket
gsutil mb -p $PROJECT_ID \
  -l us \
  -b on \
  gs://${PROJECT_ID}-tfstate

# Enable versioning
gsutil versioning set on gs://${PROJECT_ID}-tfstate

# Set lifecycle policy
cat > lifecycle.json << 'EOF'
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 90,
          "isLive": false
        }
      }
    ]
  }
}
EOF

gsutil lifecycle set lifecycle.json gs://${PROJECT_ID}-tfstate
rm lifecycle.json
```

### 3. Configure Secrets

See [SECRET-MANAGEMENT.md](./SECRET-MANAGEMENT.md) for detailed instructions.

**Quick Setup**:
```bash
# Generate template
./scripts/generate-secrets-template.sh

# Create .env file
cp secrets.template.env .env

# Edit with your secrets
nano .env

# Load secrets
source .env
```

---

## First-Time Deployment

### Step 1: Validate Configuration

```bash
cd infrastructure/environments/dev

# Format Terraform files
terraform fmt -recursive

# Validate syntax
find . -name "*.hcl" -exec terragrunt hclfmt {} \;

# Dry-run validation
terragrunt run-all validate --terragrunt-non-interactive
```

### Step 2: Plan Deployment

```bash
# Plan all resources
terragrunt run-all plan \
  --terragrunt-non-interactive \
  | tee plan-$(date +%Y%m%d-%H%M%S).out

# Review the plan file
less plan-*.out
```

**Review Checklist**:
- [ ] No unexpected destroys
- [ ] Resource counts look correct
- [ ] No sensitive data in output
- [ ] Dependencies are correct

### Step 3: Deploy in Order

Deploy resources in dependency order:

```bash
# 1. Global resources
cd infrastructure/environments/dev/global
terragrunt apply --terragrunt-non-interactive

# 2. Security (KMS, Secret Manager)
cd ../us-central1/security
terragrunt run-all apply --terragrunt-non-interactive

# 3. Networking
cd ../networking
terragrunt run-all apply --terragrunt-non-interactive

# 4. Data layer
cd ../data
terragrunt run-all apply --terragrunt-non-interactive

# 5. Compute
cd ../compute
terragrunt run-all apply --terragrunt-non-interactive

# 6. Monitoring
cd ../monitoring
terragrunt run-all apply --terragrunt-non-interactive
```

### Step 4: Verify Deployment

```bash
# Check state
terragrunt state list

# Verify resources in GCP Console
gcloud compute instances list
gcloud container clusters list
gcloud sql instances list

# Test connectivity
# ... application-specific tests
```

---

## Regular Deployments

### Standard Workflow

```bash
# 1. Pull latest changes
git pull origin main

# 2. Create feature branch
git checkout -b feature/add-new-service

# 3. Make changes to Terraform files
# ... edit files ...

# 4. Format and validate
terraform fmt -recursive
terragrunt run-all validate

# 5. Plan changes
cd infrastructure/environments/dev/us-central1/compute
terragrunt plan

# 6. Review plan output
# ... review carefully ...

# 7. Apply changes
terragrunt apply

# 8. Verify
# ... run tests ...

# 9. Commit and push
git add .
git commit -m "feat: Add new compute service"
git push origin feature/add-new-service

# 10. Create PR
gh pr create --title "Add new compute service" --body "..."
```

### Applying Single Module

```bash
cd infrastructure/environments/dev/us-central1/compute/cloud-run

# Plan
terragrunt plan

# Apply
terragrunt apply

# Or in one command
terragrunt apply --auto-approve
```

### Applying Multiple Related Modules

```bash
# Apply all compute services
cd infrastructure/environments/dev/us-central1/compute
terragrunt run-all apply

# Apply specific services
cd infrastructure/environments/dev/us-central1
terragrunt run-all apply \
  --terragrunt-include-dir compute/cloud-run \
  --terragrunt-include-dir compute/cloud-functions
```

---

## Environment-Specific Deployments

### Deploy to Development

```bash
cd infrastructure/environments/dev

# Quick deploy (with confirmation)
terragrunt run-all apply

# Or specify region
cd us-central1
terragrunt run-all apply
```

### Deploy to Staging

```bash
# Ensure dev is working
cd infrastructure/environments/dev
terragrunt run-all plan

# Deploy to staging
cd ../staging
terragrunt run-all plan | tee staging-plan.out

# Review plan
less staging-plan.out

# Apply
terragrunt run-all apply
```

### Deploy to Production

**Production deployments require extra care!**

```bash
# 1. Ensure staging is validated
cd infrastructure/environments/staging
terragrunt run-all plan

# 2. Schedule maintenance window
# ... coordinate with team ...

# 3. Create production plan
cd ../prod
terragrunt run-all plan | tee prod-plan-$(date +%Y%m%d).out

# 4. Review plan with team
# ... thorough review ...

# 5. Backup current state
gsutil cp -r gs://acme-ecommerce-platform-prod-tfstate gs://backup-bucket/$(date +%Y%m%d)/

# 6. Apply changes
terragrunt run-all apply --terragrunt-non-interactive

# 7. Verify deployment
./scripts/verify-production.sh

# 8. Monitor for issues
# ... watch dashboards ...
```

### Production Deployment Checklist

- [ ] Changes tested in dev
- [ ] Changes validated in staging
- [ ] PR approved by 2+ reviewers
- [ ] Maintenance window scheduled
- [ ] Rollback plan prepared
- [ ] Monitoring dashboards ready
- [ ] On-call team notified
- [ ] Backup of current state created
- [ ] Plan reviewed by team
- [ ] Apply during maintenance window
- [ ] Post-deployment verification complete
- [ ] Documentation updated

---

## Rollback Procedures

### Quick Rollback (Git Revert)

```bash
# Find commit to revert
git log --oneline

# Revert the change
git revert <commit-hash>

# Apply the revert
cd infrastructure/environments/prod
terragrunt apply
```

### State Rollback (Emergency)

```bash
# List state backups
gsutil ls gs://acme-ecommerce-platform-prod-tfstate/**/.terraform.tfstate

# Download previous state
gsutil cp gs://path/to/previous/state.tfstate terraform.tfstate.backup

# Copy to current
terragrunt state pull > current-state.tfstate.backup
cp terraform.tfstate.backup .terraform/terraform.tfstate

# Verify
terragrunt plan

# Apply if needed
terragrunt apply
```

### Resource-Level Rollback

```bash
# Destroy specific resource
terragrunt state rm module.problematic_resource.resource_name
terragrunt destroy -target=module.problematic_resource.resource_name

# Re-import from previous configuration
git checkout HEAD~1 -- path/to/resource.tf
terragrunt apply
```

---

## CI/CD Deployments

### GitHub Actions

The repository includes automated deployment workflows:

**.github/workflows/deploy.yml**:
```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.9.0

      - name: Setup Terragrunt
        run: |
          wget -O /usr/local/bin/terragrunt https://github.com/gruntwork-io/terragrunt/releases/download/v0.55.0/terragrunt_linux_amd64
          chmod +x /usr/local/bin/terragrunt

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Plan
        run: |
          cd infrastructure/environments/dev
          terragrunt run-all plan

      - name: Apply (on main)
        if: github.ref == 'refs/heads/main'
        run: |
          cd infrastructure/environments/dev
          terragrunt run-all apply --terragrunt-non-interactive
```

### Manual CI/CD Trigger

```bash
# Trigger deployment via GitHub CLI
gh workflow run deploy.yml --ref main

# Watch progress
gh run watch

# View logs
gh run view --log
```

---

## Troubleshooting

### Common Issues

#### Issue: State Lock

**Error**: `Error acquiring the state lock`

**Solution**:
```bash
# View lock info
terragrunt state list

# Force unlock (use with extreme caution)
terragrunt force-unlock <LOCK_ID>
```

#### Issue: Resource Already Exists

**Error**: `Resource already exists`

**Solution**:
```bash
# Import existing resource
terragrunt import module.resource.name resource-id

# Or remove from state if managed elsewhere
terragrunt state rm module.resource.name
```

#### Issue: Dependency Errors

**Error**: `Module dependency not found`

**Solution**:
```bash
# Initialize all modules
terragrunt run-all init

# Or use mock outputs for planning
dependency "vpc" {
  config_path = "../networking/vpc"
  mock_outputs = {
    network_id = "mock-network"
  }
}
```

#### Issue: Permission Denied

**Error**: `403: Permission denied`

**Solution**:
```bash
# Check current permissions
gcloud projects get-iam-policy $(gcloud config get-value project)

# Re-authenticate
gcloud auth application-default login

# Verify service account
gcloud auth list
```

### Debug Mode

Enable detailed logging:

```bash
# Terraform debug
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform-debug.log

# Terragrunt debug
export TG_LOG=debug

# Run command
terragrunt plan

# Review logs
less terraform-debug.log
```

### Validation Commands

```bash
# Validate all Terraform
find infrastructure/environments -name "*.tf" -exec terraform fmt -check {} \;

# Validate Terragrunt syntax
find infrastructure/environments -name "*.hcl" -exec terragrunt hclfmt --check {} \;

# Check for drift
cd infrastructure/environments/dev
terragrunt run-all plan -detailed-exitcode
```

---

## Best Practices

### 1. Always Plan Before Apply

```bash
terragrunt plan | tee plan.out
# Review plan.out
terragrunt apply
```

### 2. Use Feature Branches

```bash
git checkout -b feature/my-change
# Make changes
# Test in dev
# Create PR
```

### 3. Keep State Synchronized

```bash
# Refresh state
terragrunt refresh

# Pull latest state
terragrunt state pull > current.tfstate
```

### 4. Document Changes

```bash
# Good commit message
git commit -m "feat: Add Cloud Run service for API

- Configured autoscaling 1-10 instances
- Enabled Cloud SQL connection
- Added monitoring alerts
- Updated networking rules

Resolves #123"
```

### 5. Test Thoroughly

```bash
# Run all tests
./scripts/run-tests.sh

# Validate in dev first
cd infrastructure/environments/dev
terragrunt run-all plan
terragrunt run-all apply

# Then staging
cd ../staging
terragrunt run-all apply

# Finally production
cd ../prod
terragrunt run-all apply
```

---

## Additional Resources

- [Environment Configuration](../infrastructure/environments/README.md)
- [Secret Management](./SECRET-MANAGEMENT.md)
- [Module Documentation](../modules/)
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/docs/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

## Support

For deployment issues:
1. Check this guide
2. Review Terragrunt logs
3. Check GCP Console
4. Open issue in repository

---

**Maintained by**: Infrastructure Team
**Last Updated**: 2025-09-29