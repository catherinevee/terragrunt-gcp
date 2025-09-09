#!/bin/bash

# GitHub Actions Secrets Setup Script for Terragrunt GCP Infrastructure
# This script automates the setup of GCP Workload Identity Federation and GitHub secrets

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}[OK] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

# Check prerequisites
print_header "Checking Prerequisites"
check_command gcloud
check_command gh
check_command jq
print_success "All required tools are installed"

# Configuration
print_header "Configuration Setup"

# Get current project from gcloud or ask user
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
if [ -n "$CURRENT_PROJECT" ]; then
    echo -e "Current GCP project: ${GREEN}${CURRENT_PROJECT}${NC}"
    read -p "Use this project? (y/n): " use_current
    if [ "$use_current" != "y" ]; then
        read -p "Enter GCP Project ID: " PROJECT_ID
    else
        PROJECT_ID=$CURRENT_PROJECT
    fi
else
    read -p "Enter GCP Project ID: " PROJECT_ID
fi

# Get GitHub repository
CURRENT_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
if [ -n "$CURRENT_REPO" ]; then
    echo -e "Current GitHub repository: ${GREEN}${CURRENT_REPO}${NC}"
    read -p "Use this repository? (y/n): " use_current_repo
    if [ "$use_current_repo" != "y" ]; then
        read -p "Enter GitHub repository (format: owner/repo): " GITHUB_REPO
    else
        GITHUB_REPO=$CURRENT_REPO
    fi
else
    read -p "Enter GitHub repository (format: owner/repo): " GITHUB_REPO
fi

# Get organization name
read -p "Enter your organization name (default: acme): " ORG_NAME
ORG_NAME=${ORG_NAME:-acme}

# Get region
read -p "Enter GCP region (default: europe-west1): " REGION
REGION=${REGION:-europe-west1}

# Authentication method selection
echo ""
echo "Select authentication method:"
echo "1) Workload Identity Federation (Recommended - Most Secure)"
echo "2) Service Account Key (Less Secure)"
read -p "Enter choice (1 or 2): " AUTH_METHOD

# Optional features
echo ""
echo "Configure optional features:"
read -p "Setup Slack notifications? (y/n): " SETUP_SLACK
read -p "Setup Infracost for cost estimation? (y/n): " SETUP_INFRACOST

# Summary
print_header "Configuration Summary"
echo "Project ID: $PROJECT_ID"
echo "GitHub Repository: $GITHUB_REPO"
echo "Organization: $ORG_NAME"
echo "Region: $REGION"
echo "Authentication: $([ "$AUTH_METHOD" == "1" ] && echo "Workload Identity Federation" || echo "Service Account Key")"
echo ""
read -p "Proceed with this configuration? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    print_error "Setup cancelled"
    exit 1
fi

# Set gcloud project
print_header "Setting GCP Project"
gcloud config set project ${PROJECT_ID}
print_success "Project set to ${PROJECT_ID}"

# Get project number (needed for WIF)
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
print_success "Project number: ${PROJECT_NUMBER}"

# Enable required APIs
print_header "Enabling Required GCP APIs"
APIS=(
    "compute.googleapis.com"
    "container.googleapis.com"
    "storage.googleapis.com"
    "cloudresourcemanager.googleapis.com"
    "servicenetworking.googleapis.com"
    "iam.googleapis.com"
    "iamcredentials.googleapis.com"
    "sqladmin.googleapis.com"
    "secretmanager.googleapis.com"
    "cloudkms.googleapis.com"
)

for api in "${APIS[@]}"; do
    echo "Enabling $api..."
    gcloud services enable $api --project=${PROJECT_ID} &
done
wait
print_success "All APIs enabled"

# Create service account
print_header "Creating Service Account"
SA_NAME="github-actions-sa"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if gcloud iam service-accounts describe ${SA_EMAIL} --project=${PROJECT_ID} &>/dev/null; then
    print_warning "Service account already exists: ${SA_EMAIL}"
else
    gcloud iam service-accounts create ${SA_NAME} \
        --display-name="GitHub Actions Service Account" \
        --description="Used by GitHub Actions for Terragrunt deployments" \
        --project=${PROJECT_ID}
    print_success "Service account created: ${SA_EMAIL}"
fi

# Grant IAM roles to service account
print_header "Granting IAM Roles"
ROLES=(
    "roles/editor"
    "roles/storage.admin"
    "roles/resourcemanager.projectIamAdmin"
    "roles/iam.serviceAccountUser"
    "roles/iam.serviceAccountKeyAdmin"
)

for role in "${ROLES[@]}"; do
    echo "Granting $role..."
    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${SA_EMAIL}" \
        --role="$role" \
        --condition=None &>/dev/null
done
print_success "All IAM roles granted"

# Setup authentication based on user choice
if [ "$AUTH_METHOD" == "1" ]; then
    # Workload Identity Federation Setup
    print_header "Setting up Workload Identity Federation"
    
    POOL_NAME="github-pool"
    PROVIDER_NAME="github-provider"
    
    # Create workload identity pool
    if gcloud iam workload-identity-pools describe ${POOL_NAME} --location=global --project=${PROJECT_ID} &>/dev/null; then
        print_warning "Workload identity pool already exists: ${POOL_NAME}"
    else
        gcloud iam workload-identity-pools create ${POOL_NAME} \
            --location="global" \
            --display-name="GitHub Actions Pool" \
            --description="Pool for GitHub Actions authentication" \
            --project=${PROJECT_ID}
        print_success "Workload identity pool created: ${POOL_NAME}"
    fi
    
    # Create workload identity provider
    if gcloud iam workload-identity-pools providers describe ${PROVIDER_NAME} \
        --workload-identity-pool=${POOL_NAME} \
        --location=global \
        --project=${PROJECT_ID} &>/dev/null; then
        print_warning "Workload identity provider already exists: ${PROVIDER_NAME}"
    else
        gcloud iam workload-identity-pools providers create-oidc ${PROVIDER_NAME} \
            --location="global" \
            --workload-identity-pool="${POOL_NAME}" \
            --display-name="GitHub Provider" \
            --description="OIDC provider for GitHub Actions" \
            --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
            --issuer-uri="https://token.actions.githubusercontent.com" \
            --project=${PROJECT_ID}
        print_success "Workload identity provider created: ${PROVIDER_NAME}"
    fi
    
    # Get provider resource name
    WIF_PROVIDER=$(gcloud iam workload-identity-pools providers describe ${PROVIDER_NAME} \
        --location="global" \
        --workload-identity-pool="${POOL_NAME}" \
        --project=${PROJECT_ID} \
        --format="value(name)")
    
    # Bind service account to workload identity
    gcloud iam service-accounts add-iam-policy-binding ${SA_EMAIL} \
        --role="roles/iam.workloadIdentityUser" \
        --member="principalSet://iam.googleapis.com/${WIF_PROVIDER}/attribute.repository/${GITHUB_REPO}" \
        --project=${PROJECT_ID}
    
    print_success "Workload Identity Federation configured"
    
    # Set GitHub secrets for WIF
    WIF_SECRETS=(
        "WIF_PROVIDER=${WIF_PROVIDER}"
        "WIF_SERVICE_ACCOUNT=${SA_EMAIL}"
    )
    
else
    # Service Account Key Setup
    print_header "Setting up Service Account Key"
    
    KEY_FILE="github-actions-key.json"
    
    # Create service account key
    gcloud iam service-accounts keys create ${KEY_FILE} \
        --iam-account=${SA_EMAIL} \
        --project=${PROJECT_ID}
    
    # Encode key
    GCP_SA_KEY=$(cat ${KEY_FILE} | base64 -w 0)
    
    print_success "Service account key created"
    print_warning "Key file saved as ${KEY_FILE} - keep this secure!"
    
    # Set GitHub secrets for SA key
    SA_KEY_SECRETS=(
        "GCP_SERVICE_ACCOUNT_KEY=${GCP_SA_KEY}"
    )
fi

# Create GCS buckets
print_header "Creating GCS Buckets"

STATE_BUCKET="${ORG_NAME}-terraform-state-${PROJECT_ID}"
BACKUP_BUCKET="${ORG_NAME}-terraform-backups-${PROJECT_ID}"

for bucket in ${STATE_BUCKET} ${BACKUP_BUCKET}; do
    if gsutil ls -b gs://${bucket} &>/dev/null; then
        print_warning "Bucket already exists: ${bucket}"
    else
        gsutil mb -p ${PROJECT_ID} -c STANDARD -l ${REGION} gs://${bucket}/
        gsutil versioning set on gs://${bucket}/
        
        # Enable uniform bucket-level access (recommended for Terraform state)
        gsutil uniformbucketlevelaccess set on gs://${bucket}/
        
        # Set lifecycle policy for backup bucket only
        if [ "${bucket}" == "${BACKUP_BUCKET}" ]; then
            cat > /tmp/lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 90}
      }
    ]
  }
}
EOF
            gsutil lifecycle set /tmp/lifecycle.json gs://${bucket}/
            rm -f /tmp/lifecycle.json
        fi
        
        print_success "Bucket created: ${bucket}"
    fi
done

# Setup GitHub secrets
print_header "Setting GitHub Secrets"

# Check if gh is authenticated
if ! gh auth status &>/dev/null; then
    print_error "GitHub CLI is not authenticated. Please run: gh auth login"
    exit 1
fi

# Common secrets
COMMON_SECRETS=(
    "GCP_PROJECT_ID=${PROJECT_ID}"
    "STATE_BUCKET=${STATE_BUCKET}"
    "BACKUP_BUCKET=${BACKUP_BUCKET}"
)

# Combine all secrets
ALL_SECRETS=("${COMMON_SECRETS[@]}")
if [ "$AUTH_METHOD" == "1" ]; then
    ALL_SECRETS+=("${WIF_SECRETS[@]}")
else
    ALL_SECRETS+=("${SA_KEY_SECRETS[@]}")
fi

# Set secrets in GitHub
for secret in "${ALL_SECRETS[@]}"; do
    KEY="${secret%%=*}"
    VALUE="${secret#*=}"
    
    echo "Setting secret: ${KEY}"
    echo "${VALUE}" | gh secret set ${KEY} --repo ${GITHUB_REPO}
done

# Optional: Slack webhook
if [ "$SETUP_SLACK" == "y" ]; then
    print_header "Setting up Slack Notifications"
    echo "Please create a Slack webhook:"
    echo "1. Go to https://api.slack.com/apps"
    echo "2. Create new app → Incoming Webhooks → Add New Webhook"
    echo "3. Copy the webhook URL"
    echo ""
    read -p "Enter Slack Webhook URL (or press Enter to skip): " SLACK_WEBHOOK
    if [ -n "$SLACK_WEBHOOK" ]; then
        echo "${SLACK_WEBHOOK}" | gh secret set SLACK_WEBHOOK --repo ${GITHUB_REPO}
        print_success "Slack webhook configured"
    fi
fi

# Optional: Infracost
if [ "$SETUP_INFRACOST" == "y" ]; then
    print_header "Setting up Infracost"
    echo "Please sign up at https://www.infracost.io/ to get an API key"
    read -p "Enter Infracost API key (or press Enter to skip): " INFRACOST_KEY
    if [ -n "$INFRACOST_KEY" ]; then
        echo "${INFRACOST_KEY}" | gh secret set INFRACOST_API_KEY --repo ${GITHUB_REPO}
        print_success "Infracost configured"
    fi
fi

# Create environments in GitHub
print_header "Creating GitHub Environments"

for env in dev staging prod; do
    echo "Creating environment: ${env}"
    gh api --method PUT -H "Accept: application/vnd.github+json" \
        /repos/${GITHUB_REPO}/environments/${env} \
        --field wait_timer=$([ "$env" == "prod" ] && echo 5 || echo 0) \
        --field reviewers='[]' \
        --field deployment_branch_policy=null &>/dev/null || true
done
print_success "GitHub environments created"

# Summary
print_header "Setup Complete!"

echo -e "${GREEN}[OK] Service Account:${NC} ${SA_EMAIL}"
echo -e "${GREEN}[OK] State Bucket:${NC} ${STATE_BUCKET}"
echo -e "${GREEN}[OK] Backup Bucket:${NC} ${BACKUP_BUCKET}"

if [ "$AUTH_METHOD" == "1" ]; then
    echo -e "${GREEN}[OK] WIF Provider:${NC} ${WIF_PROVIDER}"
else
    echo -e "${GREEN}[OK] Service Account Key:${NC} Stored in GitHub secrets"
fi

echo ""
echo "GitHub Secrets configured:"
gh secret list --repo ${GITHUB_REPO}

echo ""
print_success "Your GitHub Actions pipeline is ready to use!"
echo ""
echo "Next steps:"
echo "1. Update infrastructure/accounts/account.hcl with:"
echo "   - organization = \"${ORG_NAME}\""
echo "   - project_id = \"${PROJECT_ID}\""
echo ""
echo "2. Commit and push your code:"
echo "   git add ."
echo "   git commit -m \"feat: configure infrastructure\""
echo "   git push origin main"
echo ""
echo "3. Create a pull request to trigger the pipeline:"
echo "   git checkout -b feature/test-pipeline"
echo "   git push origin feature/test-pipeline"
echo "   gh pr create --title \"Test pipeline\" --body \"Testing GitHub Actions\""
echo ""
echo "4. Monitor the pipeline in GitHub Actions tab"

# Cleanup sensitive files
if [ "$AUTH_METHOD" == "2" ] && [ -f "${KEY_FILE}" ]; then
    echo ""
    read -p "Delete local service account key file? (recommended) (y/n): " delete_key
    if [ "$delete_key" == "y" ]; then
        rm -f ${KEY_FILE}
        print_success "Key file deleted"
    else
        print_warning "Remember to secure or delete ${KEY_FILE}"
    fi
fi

print_header "Script Completed Successfully!"