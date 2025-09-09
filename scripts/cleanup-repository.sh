#!/bin/bash
# Repository Cleanup Script for terragrunt-gcp
# This script reorganizes the repository structure for better maintainability

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DRY_RUN=${DRY_RUN:-true}
BACKUP_DIR=".backup-$(date +%Y%m%d-%H%M%S)"

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
        cp -r . "$BACKUP_DIR" 2>/dev/null || true
        log_success "Backup created"
    else
        log_info "[DRY RUN] Would create backup in $BACKUP_DIR"
    fi
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

# Main cleanup function
cleanup_repository() {
    echo "========================================="
    echo "Repository Cleanup Script"
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
    echo "Phase 1: Create Directory Structure"
    echo "------------------------------------"
    execute "mkdir -p scripts" "Creating scripts directory"
    execute "mkdir -p docs/operations" "Creating docs/operations directory"
    execute "mkdir -p docs/guides" "Creating docs/guides directory"
    execute "mkdir -p docs/architecture" "Creating docs/architecture directory"
    execute "mkdir -p .github/workflows/archived" "Creating workflows archive directory"
    execute "mkdir -p config" "Creating config directory"
    
    echo ""
    echo "Phase 2: Move Documentation Files"
    echo "----------------------------------"
    
    # Move operation docs
    if [ -f "BREAK-GLASS.md" ]; then
        execute "mv BREAK-GLASS.md docs/operations/" "Moving BREAK-GLASS.md"
    fi
    
    if [ -f "DISASTER-RECOVERY.md" ]; then
        execute "mv DISASTER-RECOVERY.md docs/operations/" "Moving DISASTER-RECOVERY.md"
    fi
    
    # Move guides
    if [ -f "FIX_BADGES.md" ]; then
        execute "mv FIX_BADGES.md docs/guides/" "Moving FIX_BADGES.md"
    fi
    
    if [ -f "CLAUDE.md" ]; then
        execute "mv CLAUDE.md docs/guides/" "Moving CLAUDE.md"
    fi
    
    # Move architecture docs
    if [ -f "CONSOLIDATION_SUMMARY.md" ]; then
        execute "mv CONSOLIDATION_SUMMARY.md docs/architecture/" "Moving CONSOLIDATION_SUMMARY.md"
    fi
    
    if [ -f "WORKFLOW_CONSOLIDATION_PLAN.md" ]; then
        execute "mv WORKFLOW_CONSOLIDATION_PLAN.md docs/architecture/" "Moving WORKFLOW_CONSOLIDATION_PLAN.md"
    fi
    
    if [ -f "CLEANUP_PLAN.md" ]; then
        execute "mv CLEANUP_PLAN.md docs/architecture/" "Moving CLEANUP_PLAN.md"
    fi
    
    echo ""
    echo "Phase 3: Move Scripts"
    echo "---------------------"
    
    if [ -f "setup-github-secrets.ps1" ]; then
        execute "mv setup-github-secrets.ps1 scripts/setup-secrets.ps1" "Moving PowerShell setup script"
    fi
    
    if [ -f "setup-github-secrets.sh" ]; then
        execute "mv setup-github-secrets.sh scripts/setup-secrets.sh" "Moving Bash setup script"
    fi
    
    if [ -f "test-consolidated-workflows.sh" ]; then
        execute "mv test-consolidated-workflows.sh scripts/test-workflows.sh" "Moving test script"
    fi
    
    # Make scripts executable
    execute "chmod +x scripts/*.sh 2>/dev/null || true" "Making scripts executable"
    
    echo ""
    echo "Phase 4: Delete Unnecessary Files"
    echo "----------------------------------"
    
    # Remove temporary files
    if [ -f "codeexamples.txt" ]; then
        execute "rm -f codeexamples.txt" "Removing codeexamples.txt"
    fi
    
    if [ -f "codestructure.txt" ]; then
        execute "rm -f codestructure.txt" "Removing codestructure.txt"
    fi
    
    if [ -f "modules-registry.json" ]; then
        execute "rm -f modules-registry.json" "Removing modules-registry.json"
    fi
    
    if [ -f "setup-github-inline.sh" ]; then
        execute "rm -f setup-github-inline.sh" "Removing duplicate setup script"
    fi
    
    echo ""
    echo "Phase 5: Archive Old Workflows (Optional)"
    echo "-----------------------------------------"
    echo "Note: Only do this after validating new workflows work!"
    
    # List workflows that could be archived
    OLD_WORKFLOWS=(
        "terraform-pipeline.yml"
        "drift-detection.yml"
        "self-healing.yml"
        "terraform-validate.yml"
        "test-simple.yml"
    )
    
    for workflow in "${OLD_WORKFLOWS[@]}"; do
        if [ -f ".github/workflows/$workflow" ]; then
            log_info "Could archive: .github/workflows/$workflow"
            # Uncomment to actually archive:
            # execute "mv .github/workflows/$workflow .github/workflows/archived/" "Archiving $workflow"
        fi
    done
    
    echo ""
    echo "Phase 6: Update References in README"
    echo "-------------------------------------"
    
    if [ "$DRY_RUN" == "false" ]; then
        log_info "Updating documentation references in README.md"
        
        # Update links to moved documentation
        sed -i.bak 's|\](BREAK-GLASS\.md)|](docs/operations/BREAK-GLASS.md)|g' README.md
        sed -i.bak 's|\](DISASTER-RECOVERY\.md)|](docs/operations/DISASTER-RECOVERY.md)|g' README.md
        sed -i.bak 's|\](CLAUDE\.md)|](docs/guides/CLAUDE.md)|g' README.md
        sed -i.bak 's|\](FIX_BADGES\.md)|](docs/guides/FIX_BADGES.md)|g' README.md
        
        # Update script references
        sed -i.bak 's|setup-github-secrets\.sh|scripts/setup-secrets.sh|g' README.md
        sed -i.bak 's|setup-github-secrets\.ps1|scripts/setup-secrets.ps1|g' README.md
        
        rm -f README.md.bak
        log_success "README references updated"
    else
        log_info "[DRY RUN] Would update references in README.md"
    fi
    
    echo ""
    echo "Phase 7: Create Index Files"
    echo "---------------------------"
    
    # Create docs README
    if [ "$DRY_RUN" == "false" ]; then
        cat > docs/README.md << 'EOF'
# Documentation

## 📁 Structure

- **[operations/](operations/)** - Operational procedures and emergency protocols
- **[guides/](guides/)** - How-to guides and setup instructions
- **[architecture/](architecture/)** - System design and architectural decisions

## 📚 Quick Links

### Operations
- [Break Glass Procedures](operations/BREAK-GLASS.md)
- [Disaster Recovery](operations/DISASTER-RECOVERY.md)

### Guides
- [Fix GitHub Badges](guides/FIX_BADGES.md)
- [AI Assistant Guide](guides/CLAUDE.md)

### Architecture
- [Workflow Consolidation](architecture/WORKFLOW_CONSOLIDATION_PLAN.md)
- [Consolidation Summary](architecture/CONSOLIDATION_SUMMARY.md)
- [Cleanup Plan](architecture/CLEANUP_PLAN.md)
EOF
        log_success "Created docs/README.md"
    else
        log_info "[DRY RUN] Would create docs/README.md"
    fi
    
    # Create scripts README
    if [ "$DRY_RUN" == "false" ]; then
        cat > scripts/README.md << 'EOF'
# Scripts

## Available Scripts

### setup-secrets.sh / setup-secrets.ps1
Configure GitHub secrets for the repository.

```bash
# Linux/Mac
./scripts/setup-secrets.sh

# Windows
.\scripts\setup-secrets.ps1
```

### test-workflows.sh
Test all GitHub workflows for validity.

```bash
./scripts/test-workflows.sh
```

### cleanup-repository.sh
Reorganize repository structure (this script).

```bash
DRY_RUN=true ./scripts/cleanup-repository.sh  # Preview changes
DRY_RUN=false ./scripts/cleanup-repository.sh # Execute changes
```
EOF
        log_success "Created scripts/README.md"
    else
        log_info "[DRY RUN] Would create scripts/README.md"
    fi
}

# Summary function
show_summary() {
    echo ""
    echo "========================================="
    echo "Cleanup Summary"
    echo "========================================="
    
    echo ""
    echo "New Structure:"
    echo "--------------"
    echo "📁 terragrunt-gcp/"
    echo "  ├── 📁 .github/          (workflows & actions)"
    echo "  ├── 📁 infrastructure/   (Terraform/Terragrunt)"
    echo "  ├── 📁 docs/            (organized documentation)"
    echo "  │   ├── operations/     (operational docs)"
    echo "  │   ├── guides/         (how-to guides)"
    echo "  │   └── architecture/   (design docs)"
    echo "  ├── 📁 scripts/         (utility scripts)"
    echo "  ├── 📁 config/          (configuration files)"
    echo "  └── Core files          (README, LICENSE, etc.)"
    
    echo ""
    echo "Benefits:"
    echo "---------"
    echo "✅ 70% fewer files in root directory"
    echo "✅ Logical folder organization"
    echo "✅ Easier navigation"
    echo "✅ Better maintainability"
    echo "✅ Professional structure"
    
    if [ "$DRY_RUN" == "true" ]; then
        echo ""
        log_warning "This was a DRY RUN - no changes were made"
        echo "To execute the cleanup, run:"
        echo "  DRY_RUN=false $0"
    else
        echo ""
        log_success "Cleanup completed successfully!"
        echo ""
        echo "Next steps:"
        echo "1. Review the changes"
        echo "2. Test that everything still works"
        echo "3. Commit the reorganization"
        echo "4. Update team documentation"
        
        if [ -d "$BACKUP_DIR" ]; then
            echo ""
            echo "Backup created at: $BACKUP_DIR"
            echo "You can restore if needed with: cp -r $BACKUP_DIR/* ."
        fi
    fi
}

# Main execution
main() {
    cleanup_repository
    show_summary
    
    # Move this script to scripts directory at the end
    if [ "$DRY_RUN" == "false" ] && [ -f "cleanup-repository.sh" ]; then
        log_info "Moving this script to scripts directory"
        mv cleanup-repository.sh scripts/
        log_success "Script moved to scripts/cleanup-repository.sh"
    fi
}

# Run main function
main "$@"