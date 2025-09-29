# Secret Management Guide

## Overview

This guide explains how to securely manage secrets in the terragrunt-gcp infrastructure. All sensitive values (passwords, API keys, certificates, etc.) must be handled securely using one of the approved methods below.

## Table of Contents

1. [Principles](#principles)
2. [Approved Methods](#approved-methods)
3. [Development Workflow](#development-workflow)
4. [Production Workflow](#production-workflow)
5. [Secret Rotation](#secret-rotation)
6. [Troubleshooting](#troubleshooting)

---

## Principles

**NEVER commit secrets to version control**

All secret management follows these principles:

1. **No Hardcoded Secrets**: Never commit actual secret values to Git
2. **Use Placeholders**: Use placeholder values or variables in Terraform/Terragrunt files
3. **Leverage Secret Manager**: Use GCP Secret Manager for production secrets
4. **Environment Variables**: Use environment variables for local development
5. **Access Control**: Implement least-privilege access to secrets
6. **Rotation**: Rotate secrets regularly (every 90 days)
7. **Audit Logging**: Enable audit logging for all secret access

---

## Approved Methods

### Method 1: Environment Variables (Recommended for Local Development)

Use Terragrunt's `get_env()` function to read secrets from environment variables:

```hcl
# infrastructure/environments/dev/us-central1/security/secret-manager/terragrunt.hcl

inputs = {
  db_password = get_env("DB_PASSWORD", "")
  stripe_api_key = get_env("STRIPE_API_KEY", "")
  sendgrid_api_key = get_env("SENDGRID_API_KEY", "")
}
```

**Setup**:

```bash
# Create .env file (DO NOT COMMIT)
cat > .env << 'EOF'
export DB_PASSWORD="your-secure-password"
export STRIPE_API_KEY="sk_test_your_key"
export SENDGRID_API_KEY="SG.your_key"
EOF

# Load environment variables
source .env

# Deploy
terragrunt apply
```

**Advantages**:
- Simple for local development
- No external dependencies
- Fast iteration

**Disadvantages**:
- Not suitable for CI/CD
- Requires manual setup on each machine

---

### Method 2: GCP Secret Manager (Recommended for Production)

Reference existing secrets from GCP Secret Manager:

```hcl
# Create data sources for existing secrets
data "google_secret_manager_secret_version" "db_password" {
  project = var.project_id
  secret  = "db-password"
  version = "latest"
}

data "google_secret_manager_secret_version" "stripe_key" {
  project = var.project_id
  secret  = "stripe-api-key"
  version = "latest"
}

# Use in resources
resource "google_secret_manager_secret" "app_config" {
  project   = var.project_id
  secret_id = "app-config"

  # Reference other secrets
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "app_config" {
  secret = google_secret_manager_secret.app_config.id
  secret_data = jsonencode({
    database = {
      password = data.google_secret_manager_secret_version.db_password.secret_data
    }
    stripe = {
      api_key = data.google_secret_manager_secret_version.stripe_key.secret_data
    }
  })
}
```

**Setup**:

```bash
# Create secrets in Secret Manager first
PROJECT_ID="acme-ecommerce-platform-prod"

# Create secret
gcloud secrets create db-password \
  --project=$PROJECT_ID \
  --replication-policy=automatic

# Add secret version
echo -n "your-secure-password" | \
  gcloud secrets versions add db-password \
  --project=$PROJECT_ID \
  --data-file=-

# Grant access to Terraform service account
gcloud secrets add-iam-policy-binding db-password \
  --project=$PROJECT_ID \
  --member="serviceAccount:terraform@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

**Advantages**:
- Secure and encrypted
- Centralized management
- Audit logging
- Version control
- Access control

**Disadvantages**:
- Requires GCP setup
- Additional API calls
- Cost considerations

---

### Method 3: Terraform Variables File (Development Only)

Create a `.auto.tfvars` file that is excluded from Git:

```hcl
# secrets.auto.tfvars (DO NOT COMMIT - add to .gitignore)
db_password      = "dev-password"
stripe_api_key   = "sk_test_key"
sendgrid_api_key = "SG.test_key"
```

```terraform
# variables.tf
variable "db_password" {
  type        = string
  description = "Database password"
  sensitive   = true
}

variable "stripe_api_key" {
  type        = string
  description = "Stripe API key"
  sensitive   = true
}
```

**Setup**:

```bash
# Create secrets file
cat > secrets.auto.tfvars << 'EOF'
db_password = "dev-password-here"
stripe_api_key = "sk_test_your_key"
EOF

# Add to .gitignore
echo "secrets.auto.tfvars" >> .gitignore

# Deploy (Terraform auto-loads *.auto.tfvars)
terraform apply
```

**Advantages**:
- Simple for development
- No environment setup needed

**Disadvantages**:
- Risk of accidental commit
- Not suitable for production
- Manual management

---

## Development Workflow

### Initial Setup

1. **Choose your method** (Method 1 recommended for local dev)

2. **Create secrets template**:

```bash
./scripts/generate-secrets-template.sh
```

This creates `secrets.template.env` with all required secrets:

```bash
# Database Credentials
export DB_PASSWORD=""
export DB_ROOT_PASSWORD=""

# API Keys
export STRIPE_API_KEY=""
export SENDGRID_API_KEY=""
export TWILIO_API_KEY=""

# OAuth Credentials
export OAUTH_CLIENT_ID=""
export OAUTH_CLIENT_SECRET=""

# Certificates (base64 encoded)
export TLS_CERT=""
export TLS_KEY=""
```

3. **Copy and fill in values**:

```bash
cp secrets.template.env .env
# Edit .env with your actual values
nano .env
```

4. **Load secrets**:

```bash
source .env
```

5. **Verify secrets are loaded**:

```bash
echo $DB_PASSWORD  # Should output your password
```

6. **Deploy**:

```bash
cd infrastructure/environments/dev
terragrunt run-all plan
terragrunt run-all apply
```

---

## Production Workflow

### Bootstrap Secrets (One-Time Setup)

1. **Create secret management script**:

```bash
#!/bin/bash
# scripts/create-production-secrets.sh

set -e

PROJECT_ID="acme-ecommerce-platform-prod"
SECRETS_FILE="secrets.json"  # Store this securely (e.g., 1Password, Vault)

# Ensure secrets file exists
if [ ! -f "$SECRETS_FILE" ]; then
  echo "Error: $SECRETS_FILE not found"
  exit 1
fi

# Read secrets from JSON file
DB_PASSWORD=$(jq -r '.database.password' "$SECRETS_FILE")
STRIPE_KEY=$(jq -r '.stripe.api_key' "$SECRETS_FILE")

# Create secrets in Secret Manager
create_secret() {
  local SECRET_ID=$1
  local SECRET_VALUE=$2

  echo "Creating secret: $SECRET_ID"

  # Check if secret exists
  if gcloud secrets describe "$SECRET_ID" --project="$PROJECT_ID" &>/dev/null; then
    echo "  Secret exists, adding new version"
    echo -n "$SECRET_VALUE" | \
      gcloud secrets versions add "$SECRET_ID" \
      --project="$PROJECT_ID" \
      --data-file=-
  else
    echo "  Creating new secret"
    gcloud secrets create "$SECRET_ID" \
      --project="$PROJECT_ID" \
      --replication-policy=automatic

    echo -n "$SECRET_VALUE" | \
      gcloud secrets versions add "$SECRET_ID" \
      --project="$PROJECT_ID" \
      --data-file=-
  fi
}

# Create all secrets
create_secret "db-password" "$DB_PASSWORD"
create_secret "stripe-api-key" "$STRIPE_KEY"

echo "✅ All secrets created successfully"
```

2. **Run bootstrap script**:

```bash
chmod +x scripts/create-production-secrets.sh
./scripts/create-production-secrets.sh
```

3. **Update Terraform to use Secret Manager**:

Replace placeholder values with data sources:

```hcl
# Before (with placeholders)
locals {
  secrets = {
    db_password = "PLACEHOLDER"
  }
}

# After (with Secret Manager)
data "google_secret_manager_secret_version" "db_password" {
  project = var.project_id
  secret  = "db-password"
}

locals {
  secrets = {
    db_password = data.google_secret_manager_secret_version.db_password.secret_data
  }
}
```

4. **Deploy to production**:

```bash
cd infrastructure/environments/prod
terragrunt run-all plan
terragrunt run-all apply
```

---

## Secret Rotation

### Automated Rotation (Recommended)

Use Secret Manager's built-in rotation:

```terraform
resource "google_secret_manager_secret" "rotated_secret" {
  project   = var.project_id
  secret_id = "database-password"

  rotation {
    next_rotation_time = timeadd(timestamp(), "2160h")  # 90 days
    rotation_period    = "7776000s"  # 90 days in seconds
  }

  topics {
    name = google_pubsub_topic.secret_rotation.id
  }

  replication {
    automatic = true
  }
}

# Pub/Sub topic for rotation notifications
resource "google_pubsub_topic" "secret_rotation" {
  project = var.project_id
  name    = "secret-rotation-topic"
}

# Cloud Function to handle rotation
resource "google_cloudfunctions_function" "rotate_secret" {
  project     = var.project_id
  name        = "rotate-database-password"
  runtime     = "python39"
  entry_point = "rotate_password"

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.secret_rotation.id
  }

  source_archive_bucket = google_storage_bucket.functions.name
  source_archive_object = google_storage_bucket_object.rotation_function.name
}
```

### Manual Rotation

1. **Generate new secret**:

```bash
NEW_PASSWORD=$(openssl rand -base64 32)
```

2. **Add new secret version**:

```bash
echo -n "$NEW_PASSWORD" | \
  gcloud secrets versions add db-password \
  --project="$PROJECT_ID" \
  --data-file=-
```

3. **Update application** to use new version

4. **Disable old version**:

```bash
gcloud secrets versions disable 1 \
  --secret=db-password \
  --project="$PROJECT_ID"
```

5. **Verify and destroy old version**:

```bash
gcloud secrets versions destroy 1 \
  --secret=db-password \
  --project="$PROJECT_ID"
```

### Rotation Schedule

| Secret Type | Rotation Period | Method |
|-------------|----------------|--------|
| Database passwords | 90 days | Automated |
| API keys | 90 days | Manual |
| OAuth secrets | 180 days | Manual |
| TLS certificates | 365 days | Automated (Let's Encrypt) |
| Service account keys | 90 days | Automated |
| SSH keys | 180 days | Manual |

---

## File Structure

```
infrastructure/
├── environments/
│   ├── dev/
│   │   ├── us-central1/
│   │   │   └── security/
│   │   │       └── secret-manager/
│   │   │           └── terragrunt.hcl  # Uses get_env() or variables
│   │   └── .env                         # Git-ignored
│   ├── staging/
│   │   └── ...
│   └── prod/
│       ├── us-central1/
│       │   └── security/
│       │       └── secret-manager/
│       │           └── terragrunt.hcl  # Uses Secret Manager data sources
│       └── ...
├── scripts/
│   ├── create-production-secrets.sh
│   ├── generate-secrets-template.sh
│   └── rotate-secrets.sh
└── docs/
    └── SECRET-MANAGEMENT.md  # This file
```

---

## Security Best Practices

### Access Control

1. **Principle of Least Privilege**:

```bash
# Grant access only to specific secrets
gcloud secrets add-iam-policy-binding db-password \
  --member="serviceAccount:app@project.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

2. **Use separate service accounts** for different environments

3. **Enable audit logging**:

```terraform
resource "google_project_iam_audit_config" "secret_manager" {
  project = var.project_id
  service = "secretmanager.googleapis.com"

  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}
```

### Encryption

1. **Use Customer-Managed Encryption Keys (CMEK)**:

```terraform
resource "google_secret_manager_secret" "encrypted" {
  project   = var.project_id
  secret_id = "sensitive-data"

  replication {
    user_managed {
      replicas {
        location = "us-central1"
        customer_managed_encryption {
          kms_key_name = google_kms_crypto_key.secret_key.id
        }
      }
    }
  }
}
```

2. **Enable encryption at rest** (enabled by default in Secret Manager)

### Monitoring

1. **Set up alerts** for secret access:

```terraform
resource "google_monitoring_alert_policy" "secret_access" {
  project      = var.project_id
  display_name = "Unusual Secret Access"
  combiner     = "OR"

  conditions {
    display_name = "Secret accessed from unusual location"

    condition_threshold {
      filter = "resource.type=\"secretmanager.googleapis.com/Secret\" metric.type=\"secretmanager.googleapis.com/secret/access_count\""

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = 10
      duration        = "300s"
    }
  }
}
```

---

## Troubleshooting

### Issue: "Permission denied on secret"

**Solution**:

```bash
# Check current permissions
gcloud secrets get-iam-policy db-password --project=$PROJECT_ID

# Grant access
gcloud secrets add-iam-policy-binding db-password \
  --member="serviceAccount:your-sa@project.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=$PROJECT_ID
```

### Issue: "Secret not found"

**Solution**:

```bash
# List all secrets
gcloud secrets list --project=$PROJECT_ID

# Create missing secret
gcloud secrets create db-password \
  --project=$PROJECT_ID \
  --replication-policy=automatic
```

### Issue: "Environment variable not set"

**Solution**:

```bash
# Verify environment variable
echo $DB_PASSWORD

# If empty, source your .env file
source .env

# Or export directly
export DB_PASSWORD="your-password"
```

### Issue: "Terraform shows secret in plan output"

**Solution**:

Mark variables as sensitive:

```terraform
variable "db_password" {
  type      = string
  sensitive = true  # This prevents output in plan/apply
}

output "db_connection" {
  value     = "postgresql://user:${var.db_password}@host/db"
  sensitive = true  # This prevents output
}
```

### Issue: "Secret value contains special characters"

**Solution**:

Use base64 encoding:

```bash
# Encode secret
SECRET_ENCODED=$(echo -n "password!@#$" | base64)

# Store encoded
gcloud secrets versions add db-password --data-file=- <<< "$SECRET_ENCODED"

# Decode in Terraform
locals {
  db_password = base64decode(data.google_secret_manager_secret_version.db_password.secret_data)
}
```

---

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Deploy Infrastructure

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest

    permissions:
      contents: read
      id-token: write  # For Workload Identity

    steps:
      - uses: actions/checkout@v3

      - id: auth
        uses: google-github-actions/auth@v1
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Deploy
        run: |
          cd infrastructure/environments/prod
          terragrunt run-all apply --terragrunt-non-interactive
```

### GitLab CI

```yaml
# .gitlab-ci.yml
deploy:
  stage: deploy
  image: google/cloud-sdk:alpine
  script:
    - echo $GCP_SERVICE_ACCOUNT_KEY | gcloud auth activate-service-account --key-file=-
    - cd infrastructure/environments/prod
    - terragrunt run-all apply --terragrunt-non-interactive
  only:
    - main
```

---

## Additional Resources

- [GCP Secret Manager Documentation](https://cloud.google.com/secret-manager/docs)
- [Terraform Sensitive Variables](https://www.terraform.io/language/values/variables#suppressing-values-in-cli-output)
- [Terragrunt Environment Variables](https://terragrunt.gruntwork.io/docs/features/interpolation/)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

---

## Support

For questions or issues with secret management:

1. Check this guide first
2. Review GCP Secret Manager logs
3. Check audit logs for access issues
4. Contact the infrastructure team

**Remember: Never share secrets via chat, email, or other insecure channels.**