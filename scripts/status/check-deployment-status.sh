#!/bin/bash

# Check Terraform Deployment Status Script
# This script checks if the Terraform deployment is "live" or "unalive" (destroyed)

set -e

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-cataziza-platform-dev}"
REGION="${GCP_REGION:-europe-west1}"
STATUS_FILE="deployment-status.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Checking Terraform deployment status for project: $PROJECT_ID"

# Function to check if a resource exists
check_resource_exists() {
    local resource_type="$1"
    local resource_name="$2"
    local region="$3"
    
    case "$resource_type" in
        "vpc")
            gcloud compute networks describe "$resource_name" --project="$PROJECT_ID" >/dev/null 2>&1
            ;;
        "subnet")
            gcloud compute networks subnets describe "$resource_name" --region="$region" --project="$PROJECT_ID" >/dev/null 2>&1
            ;;
        "instance")
            gcloud compute instances describe "$resource_name" --zone="${region}-a" --project="$PROJECT_ID" >/dev/null 2>&1
            ;;
        "bucket")
            gsutil ls -b "gs://$resource_name" >/dev/null 2>&1
            ;;
        "sql")
            gcloud sql instances describe "$resource_name" --project="$PROJECT_ID" >/dev/null 2>&1
            ;;
        "kms")
            gcloud kms keyrings describe "$resource_name" --location=global --project="$PROJECT_ID" >/dev/null 2>&1
            ;;
        *)
            echo "Unknown resource type: $resource_type"
            return 1
            ;;
    esac
}

# Function to check critical resources
check_critical_resources() {
    local live_count=0
    local total_count=0
    
    # Define critical resources to check
    declare -A resources=(
        ["vpc:cataziza-platform-dev-vpc"]="VPC"
        ["subnet:cataziza-web-tier-dev:${REGION}"]="Web Tier Subnet"
        ["subnet:cataziza-app-tier-dev:${REGION}"]="App Tier Subnet"
        ["subnet:cataziza-database-tier-dev:${REGION}"]="Database Tier Subnet"
        ["bucket:cataziza-platform-dev-terraform-state"]="Terraform State Bucket"
        ["kms:cataziza-platform-dev-keyring"]="KMS Keyring"
    )
    
    echo "📋 Checking critical resources..."
    
    for resource_key in "${!resources[@]}"; do
        IFS=':' read -r resource_type resource_name region <<< "$resource_key"
        total_count=$((total_count + 1))
        
        echo -n "  Checking ${resources[$resource_key]}... "
        
        if check_resource_exists "$resource_type" "$resource_name" "$region"; then
            echo -e "${GREEN}✓ LIVE${NC}"
            live_count=$((live_count + 1))
        else
            echo -e "${RED}✗ UNALIVE${NC}"
        fi
    done
    
    echo ""
    echo "📊 Status Summary: $live_count/$total_count resources are live"
    
    # Determine overall status
    local percentage=$((live_count * 100 / total_count))
    
    if [ $percentage -ge 80 ]; then
        echo -e "${GREEN}🟢 DEPLOYMENT STATUS: LIVE${NC}"
        echo "LIVE" > status.txt
        return 0
    elif [ $percentage -ge 50 ]; then
        echo -e "${YELLOW}🟡 DEPLOYMENT STATUS: PARTIAL${NC}"
        echo "PARTIAL" > status.txt
        return 1
    else
        echo -e "${RED}🔴 DEPLOYMENT STATUS: UNALIVE${NC}"
        echo "UNALIVE" > status.txt
        return 2
    fi
}

# Function to create status JSON
create_status_json() {
    local status="$1"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat > "$STATUS_FILE" << EOF
{
    "status": "$status",
    "timestamp": "$timestamp",
    "project_id": "$PROJECT_ID",
    "region": "$REGION",
    "last_checked": "$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
}
EOF
}

# Main execution
main() {
    echo "🚀 Starting deployment status check..."
    echo "Project: $PROJECT_ID"
    echo "Region: $REGION"
    echo "Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo ""
    
    # Check if gcloud is authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        echo -e "${RED}❌ Error: Not authenticated with gcloud${NC}"
        echo "UNALIVE" > status.txt
        create_status_json "UNALIVE"
        exit 1
    fi
    
    # Check if project exists and is accessible
    if ! gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
        echo -e "${RED}❌ Error: Project $PROJECT_ID not found or not accessible${NC}"
        echo "UNALIVE" > status.txt
        create_status_json "UNALIVE"
        exit 1
    fi
    
    # Check critical resources
    if check_critical_resources; then
        create_status_json "LIVE"
    else
        local exit_code=$?
        if [ $exit_code -eq 1 ]; then
            create_status_json "PARTIAL"
        else
            create_status_json "UNALIVE"
        fi
    fi
    
    echo ""
    echo "✅ Status check completed. Results saved to $STATUS_FILE"
}

# Run main function
main "$@"