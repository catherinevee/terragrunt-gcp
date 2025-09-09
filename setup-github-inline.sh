#!/bin/bash

# Inline GitHub Actions Setup Script
# This script is designed to be run directly within a GitHub Actions workflow
# It uses environment variables set by GitHub Actions

set -e

# Use GitHub Actions environment variables
PROJECT_ID="${GCP_PROJECT_ID:-$1}"
GITHUB_REPO="${GITHUB_REPOSITORY:-$2}"
ORGANIZATION="${ORGANIZATION:-yanka}"
REGION="${REGION:-europe-west1}"
AUTH_METHOD="${AUTH_METHOD:-workload-identity}"

# Check required variables
if [ -z "$PROJECT_ID" ] || [ -z "$GITHUB_REPO" ]; then
    echo "Error: Missing required variables"
    echo "Usage: $0 <PROJECT_ID> <GITHUB_REPO>"
    echo "Or set GCP_PROJECT_ID and GITHUB_REPOSITORY environment variables"
    exit 1
fi

echo "Setting up infrastructure for:"
echo "  Project: $PROJECT_ID"
echo "  Repository: $GITHUB_REPO"
echo "  Organization: $ORGANIZATION"
echo "  Region: $REGION"

# Get project number
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
echo "Project number: ${PROJECT_NUMBER}"

# Enable required APIs
echo "Enabling required APIs..."
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
    gcloud services enable $api --project=${PROJECT_ID} --quiet || true
done

# Create service account
SA_NAME="github-actions-sa"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if gcloud iam service-accounts describe ${SA_EMAIL} --project=${PROJECT_ID} &>/dev/null; then
    echo "Service account already exists: ${SA_EMAIL}"
else
    gcloud iam service-accounts create ${SA_NAME} \
        --display-name="GitHub Actions Service Account" \
        --description="Used by GitHub Actions for Terragrunt deployments" \
        --project=${PROJECT_ID}
    echo "Service account created: ${SA_EMAIL}"
fi

# Output for GitHub Actions
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "sa_email=${SA_EMAIL}" >> $GITHUB_OUTPUT
fi

# Grant IAM roles
echo "Granting IAM roles..."
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
        --condition=None \
        --quiet 2>/dev/null || true
done

# Setup authentication
if [ "$AUTH_METHOD" == "workload-identity" ]; then
    echo "Setting up Workload Identity Federation..."
    
    POOL_NAME="github-pool"
    PROVIDER_NAME="github-provider"
    
    # Create workload identity pool
    if gcloud iam workload-identity-pools describe ${POOL_NAME} --location=global --project=${PROJECT_ID} &>/dev/null; then
        echo "Workload identity pool already exists: ${POOL_NAME}"
    else
        gcloud iam workload-identity-pools create ${POOL_NAME} \
            --location="global" \
            --display-name="GitHub Actions Pool" \
            --description="Pool for GitHub Actions authentication" \
            --project=${PROJECT_ID} \
            --quiet
        echo "Workload identity pool created: ${POOL_NAME}"
    fi
    
    # Create workload identity provider
    if gcloud iam workload-identity-pools providers describe ${PROVIDER_NAME} \
        --workload-identity-pool=${POOL_NAME} \
        --location=global \
        --project=${PROJECT_ID} &>/dev/null; then
        echo "Workload identity provider already exists: ${PROVIDER_NAME}"
    else
        gcloud iam workload-identity-pools providers create-oidc ${PROVIDER_NAME} \
            --location="global" \
            --workload-identity-pool="${POOL_NAME}" \
            --display-name="GitHub Provider" \
            --description="OIDC provider for GitHub Actions" \
            --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
            --issuer-uri="https://token.actions.githubusercontent.com" \
            --project=${PROJECT_ID} \
            --quiet
        echo "Workload identity provider created: ${PROVIDER_NAME}"
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
        --project=${PROJECT_ID} \
        --quiet
    
    echo "Workload Identity Federation configured"
    
    # Output for GitHub Actions
    if [ -n "$GITHUB_OUTPUT" ]; then
        echo "wif_provider=${WIF_PROVIDER}" >> $GITHUB_OUTPUT
    fi
    
    # Export for use in script
    export WIF_PROVIDER
    export WIF_SERVICE_ACCOUNT="${SA_EMAIL}"
    
else
    echo "Setting up Service Account Key..."
    
    # Create service account key
    KEY_FILE="/tmp/github-actions-key.json"
    gcloud iam service-accounts keys create ${KEY_FILE} \
        --iam-account=${SA_EMAIL} \
        --project=${PROJECT_ID} \
        --quiet
    
    # Encode key
    GCP_SA_KEY=$(cat ${KEY_FILE} | base64 -w 0)
    
    # Output for GitHub Actions
    if [ -n "$GITHUB_OUTPUT" ]; then
        echo "sa_key=${GCP_SA_KEY}" >> $GITHUB_OUTPUT
    fi
    
    # Export for use in script
    export GCP_SERVICE_ACCOUNT_KEY="${GCP_SA_KEY}"
    
    # Clean up key file
    rm -f ${KEY_FILE}
    
    echo "Service account key created"
fi

# Create GCS buckets
echo "Creating GCS buckets..."
STATE_BUCKET="${ORGANIZATION}-terraform-state-${PROJECT_ID}"
BACKUP_BUCKET="${ORGANIZATION}-terraform-backups-${PROJECT_ID}"

for bucket in ${STATE_BUCKET} ${BACKUP_BUCKET}; do
    if gsutil ls -b gs://${bucket} &>/dev/null; then
        echo "Bucket already exists: ${bucket}"
    else
        gsutil mb -p ${PROJECT_ID} -c STANDARD -l ${REGION} gs://${bucket}/
        gsutil versioning set on gs://${bucket}/
        gsutil uniformbucketlevelaccess set on gs://${bucket}/
        
        # Set lifecycle policy for backup bucket
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
        
        echo "Bucket created: ${bucket}"
    fi
done

# Output for GitHub Actions
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "state_bucket=${STATE_BUCKET}" >> $GITHUB_OUTPUT
    echo "backup_bucket=${BACKUP_BUCKET}" >> $GITHUB_OUTPUT
fi

# Export for use in script
export STATE_BUCKET
export BACKUP_BUCKET

# Summary output
echo "================================"
echo "Setup Complete!"
echo "================================"
echo "Service Account: ${SA_EMAIL}"
echo "State Bucket: ${STATE_BUCKET}"
echo "Backup Bucket: ${BACKUP_BUCKET}"

if [ "$AUTH_METHOD" == "workload-identity" ]; then
    echo "WIF Provider: ${WIF_PROVIDER}"
    echo ""
    echo "GitHub Secrets to set:"
    echo "  GCP_PROJECT_ID=${PROJECT_ID}"
    echo "  WIF_PROVIDER=${WIF_PROVIDER}"
    echo "  WIF_SERVICE_ACCOUNT=${SA_EMAIL}"
    echo "  STATE_BUCKET=${STATE_BUCKET}"
    echo "  BACKUP_BUCKET=${BACKUP_BUCKET}"
else
    echo "Authentication: Service Account Key"
    echo ""
    echo "GitHub Secrets to set:"
    echo "  GCP_PROJECT_ID=${PROJECT_ID}"
    echo "  GCP_SERVICE_ACCOUNT_KEY=<base64-encoded-key>"
    echo "  STATE_BUCKET=${STATE_BUCKET}"
    echo "  BACKUP_BUCKET=${BACKUP_BUCKET}"
fi

echo ""
echo "Next steps:"
echo "1. The GitHub Actions workflow will automatically set these secrets"
echo "2. Update infrastructure/accounts/account.hcl with your organization and project"
echo "3. Create a pull request to test the pipeline"