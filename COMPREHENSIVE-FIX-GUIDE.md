# Comprehensive Fix Guide for terragrunt-gcp

## Overview
This guide provides a complete roadmap to fix all remaining issues and make the terragrunt-gcp repository production-ready.

## Issue Categories and Prioritization

### 🔴 Priority 1: Critical Infrastructure Issues (Block Deployment)

#### 1.1 Missing Root Terragrunt Configuration
**Issue**: All environments (dev, staging, prod) missing root terragrunt.hcl
**Impact**: Prevents proper Terragrunt inheritance and DRY configuration
**Fix**:

```bash
# For each environment, create root terragrunt.hcl
cat > infrastructure/environments/dev/terragrunt.hcl << 'EOF'
# Root configuration for dev environment
remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "acme-ecommerce-platform-dev-tfstate"
    prefix         = "${path_relative_to_include()}"
    project        = "acme-ecommerce-platform-dev"
    location       = "us"
    enable_bucket_policy_only = true
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents = <<EOF
provider "google" {
  project = "acme-ecommerce-platform-dev"
  region  = "us-central1"
}

provider "google-beta" {
  project = "acme-ecommerce-platform-dev"
  region  = "us-central1"
}
EOF
}

inputs = {
  project_id  = "acme-ecommerce-platform-dev"
  environment = "dev"
}
EOF
```

Repeat for staging and prod with appropriate values.

#### 1.2 Cloud Composer Module Issues
**Issue**: Invalid arguments and unsupported blocks
**Location**: `modules/compute/cloud-composer/main.tf`
**Fix**:

```terraform
# Remove or comment out in node_config:
# disk_type    = local.node_config.disk_type  # Not supported
# enable_ip_alias = local.node_config.enable_ip_alias  # Not supported

# Replace scheduler_count dynamic block with:
scheduler_count = var.scheduler_count  # Use direct assignment

# Remove web_server_network_access_control block entirely
# This feature requires different configuration approach
```

### 🟡 Priority 2: Documentation & Usability (Required for Production)

#### 2.1 Module Documentation
**Issue**: No README files in any module
**Fix Script**:

```bash
#!/bin/bash
# generate-module-docs.sh

for module_dir in modules/*/*/; do
  if [ -d "$module_dir" ]; then
    category=$(basename "$(dirname "$module_dir")")
    module=$(basename "$module_dir")

    cat > "$module_dir/README.md" << EOF
# $module Module

## Overview
This module manages $module resources in GCP.

## Usage

\`\`\`hcl
module "$module" {
  source = "../../modules/$category/$module"

  project_id = var.project_id
  # Add required variables here
}
\`\`\`

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| google | >= 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | The GCP project ID | string | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| id | The resource ID |

## Resources Created

- List resources created by this module

## Examples

See the [examples](./examples/) directory for usage examples.
EOF
  fi
done
```

#### 2.2 Environment Documentation
**Create**: `infrastructure/environments/README.md`

```markdown
# Environment Configuration

## Structure
- `dev/` - Development environment (cost-optimized)
- `staging/` - Staging environment (production-like, scaled down)
- `prod/` - Production environment (HA, multi-region)

## Deployment Order
1. Global resources (IAM, DNS)
2. Networking (VPC, Subnets)
3. Security (KMS, Secret Manager)
4. Data (BigQuery, Cloud SQL)
5. Compute (GKE, Cloud Run)
6. Monitoring & Logging

## Usage
```bash
cd infrastructure/environments/dev
terragrunt run-all plan
terragrunt run-all apply
```
```

### 🟢 Priority 3: Code Quality & Testing (Improve Reliability)

#### 3.1 Fix Go Test Issues
**Issue**: Tests skipping due to client creation errors
**Fix**:

```go
// test/testhelpers/gcp_mock.go
package testhelpers

import (
    "context"
    "testing"
    "github.com/stretchr/testify/mock"
)

type MockGCPClient struct {
    mock.Mock
}

func NewMockGCPClient(t *testing.T) *MockGCPClient {
    return &MockGCPClient{}
}

func (m *MockGCPClient) GetProject(ctx context.Context) (string, error) {
    args := m.Called(ctx)
    return args.String(0), args.Error(1)
}

// Add other mock methods
```

Update tests to use mocks:
```go
func TestAuthService(t *testing.T) {
    mockClient := testhelpers.NewMockGCPClient(t)
    mockClient.On("GetProject", mock.Anything).Return("test-project", nil)

    // Test with mock
}
```

#### 3.2 Restore Commented GCP APIs
**Issue**: Some APIs commented out due to import issues
**Fix**:

```bash
# Update go.mod with correct versions
go get cloud.google.com/go/servicenetworking@latest
go get cloud.google.com/go/resourcemanager/apiv3@latest

# Then uncomment in files:
# - internal/gcp/network.go (servicenetworking import)
# - internal/gcp/utils.go (resourcemanagerpb import)
```

### 🔵 Priority 4: Advanced Features (Nice to Have)

#### 4.1 Add Terraform Validation Tests
**Create**: `test/terraform_validation_test.go`

```go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestTerraformModulesValidation(t *testing.T) {
    modules := []string{
        "modules/compute/instance",
        "modules/networking/vpc",
        // Add all modules
    }

    for _, module := range modules {
        t.Run(module, func(t *testing.T) {
            terraformOptions := &terraform.Options{
                TerraformDir: module,
                NoColor: true,
            }

            _, err := terraform.InitAndValidateE(t, terraformOptions)
            assert.NoError(t, err)
        })
    }
}
```

#### 4.2 Add Pre-commit Hooks
**Create**: `.pre-commit-config.yaml`

```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.77.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
      - id: terraform_tflint

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files

  - repo: https://github.com/golangci/golangci-lint
    rev: v1.50.0
    hooks:
      - id: golangci-lint
```

## Implementation Checklist

### Phase 1: Critical Fixes (Day 1-2)
- [ ] Create root terragrunt.hcl for all environments
- [ ] Fix Cloud Composer module issues
- [ ] Test deployment in dev environment
- [ ] Verify CI/CD pipeline passes

### Phase 2: Documentation (Day 3-4)
- [ ] Generate module README files
- [ ] Create environment documentation
- [ ] Add architecture diagrams
- [ ] Document deployment procedures

### Phase 3: Testing (Day 5-6)
- [ ] Implement GCP client mocks
- [ ] Fix skipped tests
- [ ] Add integration tests
- [ ] Add Terraform validation tests

### Phase 4: Advanced Features (Day 7-8)
- [ ] Restore commented APIs
- [ ] Add pre-commit hooks
- [ ] Add performance monitoring
- [ ] Implement cost tracking

## Automation Scripts

### Complete Fix Script
```bash
#!/bin/bash
# fix-all-issues.sh

echo "🔧 Starting comprehensive fix..."

# Phase 1: Critical Fixes
echo "📝 Phase 1: Creating root terragrunt configurations..."
./scripts/create-root-terragrunt.sh

echo "🔨 Fixing Cloud Composer module..."
./scripts/fix-composer-module.sh

# Phase 2: Documentation
echo "📚 Phase 2: Generating documentation..."
./scripts/generate-module-docs.sh
./scripts/create-architecture-docs.sh

# Phase 3: Testing
echo "🧪 Phase 3: Fixing tests..."
./scripts/fix-go-tests.sh
./scripts/add-terraform-tests.sh

# Phase 4: Validation
echo "✅ Phase 4: Validating fixes..."
terraform fmt -recursive modules/
go mod tidy
go test ./...

echo "🎉 All fixes completed!"
```

## Validation Commands

```bash
# Validate Terraform
terraform fmt -check -recursive modules/
for module in modules/*/*/; do
  terraform -chdir="$module" init -backend=false
  terraform -chdir="$module" validate
done

# Validate Go
go mod verify
go test -race ./...
golangci-lint run

# Validate Terragrunt
terragrunt hclfmt --terragrunt-check
terragrunt run-all validate

# Check CI/CD
gh workflow run "CI/CD Pipeline" --ref main
gh run watch
```

## Success Criteria

1. **All workflows passing**: CI/CD, Terraform CI/CD, Security Scans
2. **No skipped tests**: All Go tests running and passing
3. **Complete documentation**: Every module has README
4. **Clean validation**: No Terraform errors, Go builds cleanly
5. **Deployable**: Can deploy to all environments with Terragrunt

## Support & Troubleshooting

### Common Issues

**Issue**: Terraform version conflicts
```bash
# Solution: Use tfenv
tfenv install 1.5.7
tfenv use 1.5.7
```

**Issue**: GCP authentication errors
```bash
# Solution: Re-authenticate
gcloud auth application-default login
gcloud config set project acme-ecommerce-platform-dev
```

**Issue**: Go module conflicts
```bash
# Solution: Clean and rebuild
go clean -modcache
go mod download
go mod tidy
```

## Monitoring Progress

Track progress in GitHub Issues:
```bash
# Create tracking issue
gh issue create --title "Complete terragrunt-gcp fixes" \
  --body "Tracking issue for completing all fixes per COMPREHENSIVE-FIX-GUIDE.md" \
  --label "enhancement,documentation,testing"

# Create sub-issues for each phase
gh issue create --title "Phase 1: Critical Infrastructure Fixes" \
  --body "Fix root terragrunt.hcl and Cloud Composer module" \
  --label "bug,priority-1"
```

## Next Steps

1. Review this guide with the team
2. Assign responsibilities for each phase
3. Set up daily check-ins to track progress
4. Create feature branches for each major fix
5. Test thoroughly in dev before promoting

---

Generated: $(date)
Version: 1.0.0