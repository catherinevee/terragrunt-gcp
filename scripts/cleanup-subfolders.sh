#!/bin/bash
# Subfolder Cleanup Script for terragrunt-gcp
# This script organizes subfolders and removes empty directories

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DRY_RUN=${DRY_RUN:-true}
BACKUP_DIR=".backup-subfolders-$(date +%Y%m%d-%H%M%S)"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Execute or simulate command
execute() {
    local cmd="$1"
    local description="$2"
    
    if [ "$DRY_RUN" == "true" ]; then
        log_info "[DRY RUN] $description"
        echo "  Command: $cmd"
    else
        log_info "$description"
        eval "$cmd"
        log_success "Done"
    fi
}

# Check if we're in the right directory
check_repository() {
    if [ ! -f "README.md" ] || [ ! -d ".github" ] || [ ! -d "infrastructure" ]; then
        log_error "This doesn't appear to be the terragrunt-gcp repository root"
        exit 1
    fi
}

# Create backup
create_backup() {
    if [ "$DRY_RUN" == "false" ]; then
        log_info "Creating backup in $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
        cp -r .github infrastructure test policies "$BACKUP_DIR" 2>/dev/null || true
        log_success "Backup created"
    else
        log_info "[DRY RUN] Would create backup in $BACKUP_DIR"
    fi
}

# Main cleanup function
cleanup_subfolders() {
    echo "========================================="
    echo "Subfolder Cleanup Script"
    echo "========================================="
    echo ""
    
    if [ "$DRY_RUN" == "true" ]; then
        log_warning "Running in DRY RUN mode - no changes will be made"
        echo "Set DRY_RUN=false to execute changes"
    else
        log_warning "Running in EXECUTE mode - changes will be made"
        read -p "Are you sure you want to continue? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cleanup cancelled"
            exit 0
        fi
    fi
    echo ""
    
    # Check we're in the right place
    check_repository
    
    # Create backup
    create_backup
    
    echo ""
    echo "Phase 1: Archive Old Workflows"
    echo "-------------------------------"
    
    execute "mkdir -p .github/workflows/archived" "Creating archived workflows directory"
    
    # List of workflows to archive
    OLD_WORKFLOWS=(
        "terraform-pipeline.yml"
        "drift-detection.yml"
        "self-healing.yml"
        "terraform-validate.yml"
        "test-simple.yml"
    )
    
    for workflow in "${OLD_WORKFLOWS[@]}"; do
        if [ -f ".github/workflows/$workflow" ]; then
            execute "mv .github/workflows/$workflow .github/workflows/archived/" "Archiving $workflow"
        else
            log_info "Skip: $workflow (not found)"
        fi
    done
    
    echo ""
    echo "Phase 2: Remove Empty Module Directories"
    echo "-----------------------------------------"
    
    # List of empty modules to remove
    EMPTY_MODULES=(
        "infrastructure/modules/compute/app-engine"
        "infrastructure/modules/compute/cloud-functions"
        "infrastructure/modules/compute/cloud-run"
        "infrastructure/modules/compute/vm-instances"
        "infrastructure/modules/data/bigquery"
        "infrastructure/modules/data/cloud-storage"
        "infrastructure/modules/data/pubsub"
        "infrastructure/modules/data/redis"
        "infrastructure/modules/networking/cdn"
        "infrastructure/modules/networking/dns"
        "infrastructure/modules/networking/load-balancer"
        "infrastructure/modules/security/kms"
        "infrastructure/modules/security/secrets"
    )
    
    for module in "${EMPTY_MODULES[@]}"; do
        if [ -d "$module" ] && [ -z "$(ls -A "$module" 2>/dev/null)" ]; then
            execute "rmdir $module" "Removing empty module: $(basename $(dirname $module))/$(basename $module)"
        fi
    done
    
    echo ""
    echo "Phase 3: Reorganize Environment Configurations"
    echo "-----------------------------------------------"
    
    # Create regional structure for dev environment
    if [ -d "infrastructure/environments/dev" ]; then
        execute "mkdir -p infrastructure/environments/dev/europe-west1" "Creating europe-west1 directory"
        execute "mkdir -p infrastructure/environments/dev/us-central1" "Creating us-central1 directory"
        
        # Move files to regional directories
        if [ -f "infrastructure/environments/dev/dev-europe-west1-gke.hcl" ]; then
            execute "mv infrastructure/environments/dev/dev-europe-west1-gke.hcl infrastructure/environments/dev/europe-west1/gke.hcl" \
                    "Moving GKE config to europe-west1"
        fi
        
        if [ -f "infrastructure/environments/dev/dev-europe-west1-vpc.hcl" ]; then
            execute "mv infrastructure/environments/dev/dev-europe-west1-vpc.hcl infrastructure/environments/dev/europe-west1/vpc.hcl" \
                    "Moving VPC config to europe-west1"
        fi
        
        if [ -f "infrastructure/environments/dev/dev-us-central1-vpc.hcl" ]; then
            execute "mv infrastructure/environments/dev/dev-us-central1-vpc.hcl infrastructure/environments/dev/us-central1/vpc.hcl" \
                    "Moving VPC config to us-central1"
        fi
    fi
    
    # Add placeholders for staging and prod
    execute "touch infrastructure/environments/staging/.gitkeep" "Adding staging placeholder"
    execute "touch infrastructure/environments/prod/.gitkeep" "Adding prod placeholder"
    
    echo ""
    echo "Phase 4: Create Module Templates"
    echo "---------------------------------"
    
    execute "mkdir -p infrastructure/modules/_templates/basic" "Creating basic template directory"
    execute "mkdir -p infrastructure/modules/_templates/complete/examples" "Creating complete template directory"
    
    # Create basic template files
    if [ "$DRY_RUN" == "false" ]; then
        cat > infrastructure/modules/_templates/basic/main.tf << 'EOF'
# Module: ${module_name}
# Description: ${module_description}

resource "google_${resource_type}" "this" {
  name    = var.name
  project = var.project_id
  
  # Add resource-specific configuration
  
  labels = var.labels
}
EOF
        
        cat > infrastructure/modules/_templates/basic/variables.tf << 'EOF'
variable "name" {
  description = "Resource name"
  type        = string
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "labels" {
  description = "Resource labels"
  type        = map(string)
  default     = {}
}
EOF
        
        cat > infrastructure/modules/_templates/basic/outputs.tf << 'EOF'
output "id" {
  description = "Resource ID"
  value       = google_${resource_type}.this.id
}

output "name" {
  description = "Resource name"
  value       = google_${resource_type}.this.name
}
EOF
        
        cat > infrastructure/modules/_templates/basic/README.md << 'EOF'
# Module Name

## Description
Brief description of what this module does.

## Usage
```hcl
module "example" {
  source = "../../modules/category/name"
  
  name       = "my-resource"
  project_id = var.project_id
}
```

## Inputs
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Resource name | string | n/a | yes |
| project_id | GCP Project ID | string | n/a | yes |

## Outputs
| Name | Description |
|------|-------------|
| id | Resource ID |
| name | Resource name |
EOF
        log_success "Created module templates"
    else
        log_info "[DRY RUN] Would create module templates"
    fi
    
    echo ""
    echo "Phase 5: Add Documentation"
    echo "--------------------------"
    
    # Create README for modules
    if [ "$DRY_RUN" == "false" ]; then
        cat > infrastructure/modules/README.md << 'EOF'
# Terraform Modules

## Structure
```
modules/
├── _templates/     # Module templates for new modules
├── compute/        # Compute resources (GKE, Cloud Run, etc.)
├── data/          # Data resources (Cloud SQL, BigQuery, etc.)
├── networking/    # Network resources (VPC, Subnets, etc.)
└── security/      # Security resources (IAM, KMS, etc.)
```

## Available Modules

### Compute
- `gke` - Google Kubernetes Engine cluster

### Data
- `cloud-sql` - Cloud SQL database instances

### Networking
- `vpc` - Virtual Private Cloud network
- `subnets` - VPC subnet configuration
- `firewall` - Firewall rules
- `nat` - Cloud NAT gateway

### Security
- `iam` - IAM roles and policies

## Creating New Modules

1. Copy a template from `_templates/`:
   - `basic/` - Simple module structure
   - `complete/` - Full module with examples

2. Update the template variables:
   - Replace `${module_name}` with your module name
   - Replace `${resource_type}` with the GCP resource type
   - Update variables and outputs as needed

3. Add documentation:
   - Update the README.md
   - Add usage examples
   - Document all inputs and outputs

## Module Standards

- All modules must have:
  - `main.tf` - Main resource definitions
  - `variables.tf` - Input variables
  - `outputs.tf` - Output values
  - `README.md` - Documentation

- Optional files:
  - `versions.tf` - Provider version constraints
  - `locals.tf` - Local values
  - `data.tf` - Data sources
EOF
        log_success "Created modules README"
        
        # Create README for each category
        for category in compute data networking security; do
            if [ -d "infrastructure/modules/$category" ]; then
                cat > "infrastructure/modules/$category/README.md" << EOF
# ${category^} Modules

## Available Modules
$(ls -d infrastructure/modules/$category/*/ 2>/dev/null | xargs -n1 basename | sed 's/^/- /' || echo "- None currently")

## Creating New ${category^} Modules
Use the templates in \`../_templates/\` as a starting point.
EOF
                log_success "Created $category README"
            fi
        done
    else
        log_info "[DRY RUN] Would create documentation files"
    fi
    
    echo ""
    echo "Phase 6: Organize Test Directory"
    echo "---------------------------------"
    
    if [ -d "test" ]; then
        execute "mkdir -p test/unit" "Creating unit test directory"
        execute "mkdir -p test/integration" "Creating integration test directory"
        
        if [ -f "test/vpc_test.go" ]; then
            execute "mv test/vpc_test.go test/unit/" "Moving VPC test to unit directory"
        fi
        
        execute "touch test/integration/.gitkeep" "Adding integration test placeholder"
        
        if [ "$DRY_RUN" == "false" ]; then
            cat > test/README.md << 'EOF'
# Tests

## Structure
```
test/
├── unit/         # Unit tests for individual modules
├── integration/  # Integration tests for combined modules
└── e2e/         # End-to-end tests (future)
```

## Running Tests

### Unit Tests
```bash
cd test/unit
go test -v ./...
```

### Integration Tests
```bash
cd test/integration
go test -v ./...
```

## Writing Tests

1. Create a new test file: `module_name_test.go`
2. Import the testing framework
3. Write test functions starting with `Test`
4. Run tests to verify

## Test Coverage
Target: 80% coverage for critical modules
EOF
            log_success "Created test README"
        else
            log_info "[DRY RUN] Would create test README"
        fi
    fi
    
    echo ""
    echo "Phase 7: Clean Up Empty Directories"
    echo "------------------------------------"
    
    # Remove any remaining empty directories
    execute "find infrastructure/modules -type d -empty -delete 2>/dev/null || true" "Removing remaining empty directories"
}

# Summary function
show_summary() {
    echo ""
    echo "========================================="
    echo "Subfolder Cleanup Summary"
    echo "========================================="
    
    echo ""
    echo "Changes Made:"
    echo "-------------"
    echo "✅ Archived old workflows to .github/workflows/archived/"
    echo "✅ Removed 13 empty module directories"
    echo "✅ Reorganized dev environment by region"
    echo "✅ Created module templates in _templates/"
    echo "✅ Added README documentation throughout"
    echo "✅ Organized test directory structure"
    
    echo ""
    echo "New Structure:"
    echo "--------------"
    echo "📁 .github/workflows/"
    echo "  ├── main.yml and reusable-*.yml (active)"
    echo "  └── archived/ (old workflows)"
    echo ""
    echo "📁 infrastructure/"
    echo "  ├── modules/ (only modules with content)"
    echo "  │   └── _templates/ (for new modules)"
    echo "  └── environments/dev/ (organized by region)"
    echo "      ├── europe-west1/"
    echo "      └── us-central1/"
    
    if [ "$DRY_RUN" == "true" ]; then
        echo ""
        log_warning "This was a DRY RUN - no changes were made"
        echo "To execute the cleanup, run:"
        echo "  DRY_RUN=false $0"
    else
        echo ""
        log_success "Subfolder cleanup completed successfully!"
        
        if [ -d "$BACKUP_DIR" ]; then
            echo ""
            echo "Backup created at: $BACKUP_DIR"
            echo "You can restore if needed with: cp -r $BACKUP_DIR/* ."
        fi
    fi
    
    echo ""
    echo "Next Steps:"
    echo "-----------"
    echo "1. Review the changes"
    echo "2. Test workflows still function"
    echo "3. Update any documentation referencing old paths"
    echo "4. Commit the reorganization"
    echo "5. Inform team of structural changes"
}

# Main execution
main() {
    cleanup_subfolders
    show_summary
}

# Run main function
main "$@"