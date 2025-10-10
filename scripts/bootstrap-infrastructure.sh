#!/bin/bash
set -euo pipefail

# Bootstrap script for GCP infrastructure
# This script creates the necessary resources for Terraform state management
# and initial infrastructure setup before running Terraform/Terragrunt

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
PROJECT_ID="${PROJECT_ID:-acme-ecommerce-platform-dev}"
REGION="${REGION:-us-central1}"
STATE_BUCKET_NAME="${STATE_BUCKET_NAME:-${PROJECT_ID}-terraform-state}"
BACKUP_BUCKET_NAME="${BACKUP_BUCKET_NAME:-${PROJECT_ID}-terraform-backups}"
LOCATION="${LOCATION:-US}"

print_info "Starting infrastructure bootstrap for project: $PROJECT_ID"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI not found. Please install Google Cloud SDK."
    exit 1
fi

# Check authentication
print_info "Checking GCP authentication..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    print_error "Not authenticated with GCP. Run: gcloud auth login"
    exit 1
fi

print_info "Setting active project to: $PROJECT_ID"
gcloud config set project "$PROJECT_ID" 2>/dev/null || {
    print_error "Failed to set project. Please verify project ID: $PROJECT_ID"
    exit 1
}

# Enable required APIs
print_info "Enabling required GCP APIs..."
REQUIRED_APIS=(
    "cloudresourcemanager.googleapis.com"
    "serviceusage.googleapis.com"
    "compute.googleapis.com"
    "storage-api.googleapis.com"
    "storage-component.googleapis.com"
    "iam.googleapis.com"
    "iamcredentials.googleapis.com"
    "bigquery.googleapis.com"
    "logging.googleapis.com"
    "monitoring.googleapis.com"
)

for api in "${REQUIRED_APIS[@]}"; do
    print_info "Enabling API: $api"
    gcloud services enable "$api" --project="$PROJECT_ID" 2>/dev/null || {
        print_warn "API $api may already be enabled or failed to enable"
    }
done

# Wait for APIs to be fully enabled
print_info "Waiting for APIs to be fully enabled (30 seconds)..."
sleep 30

# Create Terraform state bucket
print_info "Creating GCS bucket for Terraform state: $STATE_BUCKET_NAME"
if gsutil ls -b "gs://$STATE_BUCKET_NAME" &> /dev/null; then
    print_warn "State bucket already exists: $STATE_BUCKET_NAME"
else
    gsutil mb -p "$PROJECT_ID" -c STANDARD -l "$REGION" "gs://$STATE_BUCKET_NAME" || {
        print_error "Failed to create state bucket"
        exit 1
    }

    # Enable versioning on state bucket
    print_info "Enabling versioning on state bucket..."
    gsutil versioning set on "gs://$STATE_BUCKET_NAME"

    # Set lifecycle policy to retain versions for 30 days
    cat > /tmp/lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "numNewerVersions": 3,
          "isLive": false
        }
      }
    ]
  }
}
EOF
    gsutil lifecycle set /tmp/lifecycle.json "gs://$STATE_BUCKET_NAME"
    rm /tmp/lifecycle.json

    print_info "State bucket created successfully"
fi

# Create backup bucket
print_info "Creating GCS bucket for backups: $BACKUP_BUCKET_NAME"
if gsutil ls -b "gs://$BACKUP_BUCKET_NAME" &> /dev/null; then
    print_warn "Backup bucket already exists: $BACKUP_BUCKET_NAME"
else
    gsutil mb -p "$PROJECT_ID" -c STANDARD -l "$REGION" "gs://$BACKUP_BUCKET_NAME" || {
        print_warn "Failed to create backup bucket (non-critical)"
    }
fi

# Create BigQuery datasets for logging
print_info "Creating BigQuery datasets for logging..."
bq mk --dataset \
    --location="$LOCATION" \
    --description="Application logs dataset" \
    "${PROJECT_ID}:application_logs" 2>/dev/null || {
    print_warn "Dataset application_logs may already exist"
}

bq mk --dataset \
    --location="$LOCATION" \
    --description="Security logs dataset" \
    "${PROJECT_ID}:security_logs" 2>/dev/null || {
    print_warn "Dataset security_logs may already exist"
}

bq mk --dataset \
    --location="$LOCATION" \
    --description="Audit logs dataset" \
    "${PROJECT_ID}:audit_logs" 2>/dev/null || {
    print_warn "Dataset audit_logs may already exist"
}

# Create service account for Terraform (if running in CI/CD)
if [ "${CI:-false}" = "true" ]; then
    SA_NAME="terraform-sa"
    SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

    print_info "Creating service account for Terraform: $SA_NAME"
    gcloud iam service-accounts create "$SA_NAME" \
        --display-name="Terraform Service Account" \
        --description="Service account for Terraform automation" \
        --project="$PROJECT_ID" 2>/dev/null || {
        print_warn "Service account may already exist: $SA_NAME"
    }

    # Grant necessary roles
    print_info "Granting roles to service account..."
    ROLES=(
        "roles/editor"
        "roles/storage.admin"
        "roles/compute.admin"
        "roles/iam.serviceAccountAdmin"
        "roles/resourcemanager.projectIamAdmin"
    )

    for role in "${ROLES[@]}"; do
        print_info "Granting role: $role"
        gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="serviceAccount:$SA_EMAIL" \
            --role="$role" \
            --condition=None \
            --quiet 2>/dev/null || {
            print_warn "Failed to grant role $role"
        }
    done
fi

# Verify bucket access
print_info "Verifying state bucket access..."
if gsutil ls "gs://$STATE_BUCKET_NAME" &> /dev/null; then
    print_info "State bucket is accessible"
else
    print_error "Cannot access state bucket. Check permissions."
    exit 1
fi

# Create initial directory structure in state bucket
print_info "Creating directory structure in state bucket..."
echo "Terraform state storage initialized on $(date)" | gsutil cp - "gs://$STATE_BUCKET_NAME/README.txt"

# Summary
print_info "Bootstrap completed successfully!"
echo ""
echo "======================================================================"
echo "  Infrastructure Bootstrap Summary"
echo "======================================================================"
echo "  Project ID:           $PROJECT_ID"
echo "  Region:               $REGION"
echo "  State Bucket:         gs://$STATE_BUCKET_NAME"
echo "  Backup Bucket:        gs://$BACKUP_BUCKET_NAME"
echo "  BigQuery Location:    $LOCATION"
echo "======================================================================"
echo ""
print_info "You can now run Terraform/Terragrunt commands"
print_info "State will be stored in: gs://$STATE_BUCKET_NAME"
echo ""

exit 0
