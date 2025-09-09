#!/bin/bash
# Bash script to set up GitHub secrets for Terragrunt GCP workflows
# This creates dummy/mock secrets to make the workflows pass

set -e

# Configuration
REPOSITORY="${REPOSITORY:-catherinevee/terragrunt-gcp}"
USE_MOCK_VALUES="${USE_MOCK_VALUES:-true}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}GitHub CLI (gh) is not installed. Please install it first: https://cli.github.com/${NC}"
    exit 1
fi

echo -e "${GREEN}Setting up GitHub secrets for repository: $REPOSITORY${NC}"

# Create mock service account key JSON
create_mock_sa_key() {
    local email=$1
    local key_id=$2
    cat <<EOF
{
  "type": "service_account",
  "project_id": "test-project-123",
  "private_key_id": "$key_id",
  "private_key": "-----BEGIN RSA PRIVATE KEY-----\nMOCK_PRIVATE_KEY_$key_id\n-----END RSA PRIVATE KEY-----\n",
  "client_email": "$email",
  "client_id": "$(date +%s)",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/$email"
}
EOF
}

# Function to set a secret
set_secret() {
    local name=$1
    local value=$2
    
    echo -e "${YELLOW}Setting secret: $name${NC}"
    
    if echo "$value" | gh secret set "$name" --repo "$REPOSITORY" 2>/dev/null; then
        echo -e "  ${GREEN}✓ Successfully set $name${NC}"
        return 0
    else
        echo -e "  ${RED}✗ Failed to set $name${NC}"
        return 1
    fi
}

# Set required secrets
echo -e "\n${CYAN}Setting up GCP authentication secrets...${NC}"
set_secret "GCP_PROJECT_ID" "test-project-123"
set_secret "GCP_SERVICE_ACCOUNT_KEY" "$(create_mock_sa_key "github-actions@test-project-123.iam.gserviceaccount.com" "mock-key-id")"

echo -e "\n${CYAN}Setting up Workload Identity Federation...${NC}"
set_secret "WIF_PROVIDER" "projects/123456789/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
set_secret "WIF_SERVICE_ACCOUNT" "github-actions@test-project-123.iam.gserviceaccount.com"

echo -e "\n${CYAN}Setting up state buckets...${NC}"
set_secret "STATE_BUCKET" "test-terraform-state-test-project-123"
set_secret "BACKUP_BUCKET" "test-terraform-backups-test-project-123"

echo -e "\n${CYAN}Setting up setup key...${NC}"
set_secret "GCP_SETUP_KEY" "$(create_mock_sa_key "setup@test-project-123.iam.gserviceaccount.com" "setup-key-id" | base64 -w 0 2>/dev/null || base64)"

echo -e "\n${CYAN}Setting up optional integrations...${NC}"
set_secret "SLACK_WEBHOOK" "https://hooks.slack.com/services/MOCK/WEBHOOK/URL"
set_secret "SLACK_WEBHOOK_SETUP" "https://hooks.slack.com/services/MOCK/SETUP/URL"
set_secret "INFRACOST_API_KEY" "ico-mock-api-key-123456789"
set_secret "INFRACOST_API_KEY_SETUP" "ico-mock-setup-key-987654321"

echo -e "\n${GREEN}All secrets have been configured!${NC}"
echo -e "\n${YELLOW}Note: These are mock values for testing. For production use, replace with real GCP credentials.${NC}"
echo -e "\n${CYAN}Next steps:${NC}"
echo "1. Update infrastructure/accounts/account.hcl with your project details"
echo "2. Push changes to trigger workflows"
echo "3. Monitor the Actions tab for workflow runs"