# CLAUDE.md
## AI Assistant Integration Guide for GCP Terragrunt Infrastructure

---

## 🤖 Purpose
This document provides structured context and guidelines for AI assistants (Claude, GPT, etc.) to effectively work with this GCP Terragrunt infrastructure project. It contains project-specific knowledge, patterns, and instructions optimized for AI comprehension.

---

## 📋 Project Overview

### Quick Context
```yaml
project_type: infrastructure_as_code
platform: google_cloud_platform
iac_tool: terragrunt
orchestration: terraform
environments: [dev, staging, prod]
primary_region: us-central1
deployment_method: gitops
ci_cd: github_actions
state_backend: gcs
```

### Architecture Summary
```
User → Load Balancer → CDN → [Cloud Run | GKE | App Engine]
                              ↓
                    [Cloud SQL | Redis | BigQuery]
                              ↓
                    [Pub/Sub | Cloud Functions]
```

---

## 🎯 Common AI Tasks

### Task 1: Generate New Resource Configuration
**Context Needed:** Resource type, environment, dependencies
**Pattern to Follow:**
```hcl
# infrastructure/environments/{env}/{env}-{region}-{resource}.hcl

terraform {
  source = "../../modules/{category}/{resource}"
}

include "root" {
  path = find_in_parent_folders()
}

dependency "vpc" {
  config_path = "."
  mock_outputs = {
    network_id = "mock-network-id"
  }
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  common_vars = read_terragrunt_config(find_in_parent_folders("terragrunt.hcl"))
}

inputs = {
  name = "${local.env_vars.locals.environment}-${local.env_vars.locals.region}-{resource}"
  # Resource-specific inputs
  
  labels = merge(
    local.common_vars.locals.common_labels,
    {
      component = "{component}"
      resource  = "{resource}"
    }
  )
}
```

### Task 2: Debug Deployment Issues
**Common Issues & Solutions:**
```yaml
dependency_errors:
  symptom: "Error: Reference to undeclared resource"
  check:
    - Verify dependency blocks in terragrunt.hcl
    - Ensure mock_outputs are defined
    - Check if dependent resource is deployed
  fix: |
    dependency "required_resource" {
      config_path = "."
      mock_outputs = {
        output_name = "mock-value"
      }
    }

state_lock_errors:
  symptom: "Error acquiring the state lock"
  check:
    - Check for stuck CI/CD pipelines
    - Verify GCS bucket permissions
  fix: |
    terragrunt force-unlock <lock-id>

api_not_enabled:
  symptom: "API has not been used in project"
  check:
    - List enabled APIs: gcloud services list --enabled
  fix: |
    gcloud services enable <service-name>.googleapis.com

insufficient_quota:
  symptom: "Quota exceeded for quota metric"
  check:
    - Current quotas: gcloud compute project-info describe
  fix: |
    Request quota increase in GCP Console or use different region
```

### Task 3: Cost Optimization Analysis
**Key Areas to Check:**
```yaml
compute_optimization:
  - Check for preemptible/spot instances in non-prod
  - Review instance sizing (right-sizing)
  - Identify unused resources
  - Check autoscaling min/max settings

storage_optimization:
  - Review storage classes (use Archive for old data)
  - Check lifecycle policies
  - Identify unused buckets
  - Review snapshot retention

network_optimization:
  - Check for unused static IPs
  - Review NAT gateway usage
  - Optimize CDN cache settings
  - Check inter-region traffic

database_optimization:
  - Review backup retention policies
  - Check for over-provisioned instances
  - Consider read replicas vs. size increase
  - Review connection pooling
```

### Task 4: Security Audit
**Security Checklist:**
```yaml
iam_audit:
  - No service accounts with Owner role
  - API keys rotated within 90 days
  - Least privilege principle applied
  - No default service accounts used

network_security:
  - Private GKE clusters enabled
  - VPC firewall rules reviewed
  - No public IPs except load balancers
  - Cloud Armor policies configured

data_security:
  - Encryption at rest enabled
  - KMS keys properly managed
  - Secrets in Secret Manager
  - Database SSL enforced

compliance:
  - Audit logs enabled
  - Backup policies configured
  - DLP policies if handling PII
  - Binary Authorization for GKE
```

---

## 📁 Project Structure Understanding

### Directory Mapping
```
infrastructure/
├── terragrunt.hcl                    # Root: remote state, providers
├── accounts/account.hcl              # Organization settings
├── environments/
│   └── {env}/
│       ├── env.hcl                   # Environment variables
│       └── {env}-{region}-{resource}.hcl  # Resource configs
├── modules/
│   ├── networking/                   # VPC, subnets, LB, CDN
│   ├── compute/                      # GKE, Cloud Run, Functions
│   ├── data/                         # Databases, storage
│   └── security/                     # IAM, KMS, secrets
└── .github/workflows/                # CI/CD pipelines
```

### Naming Conventions
```yaml
resources: "{environment}-{region}-{resource_type}"
files: "{environment}-{region}-{resource}.hcl"
modules: "{category}/{resource_type}"
labels:
  environment: [dev, staging, prod]
  component: [networking, compute, data, security]
  resource: [specific-resource-name]
  managed_by: terragrunt
```

---

## 🔧 Module Templates

### Creating a New Module
```hcl
# modules/{category}/{resource}/main.tf

# Resource definitions
resource "google_{resource_type}" "{name}" {
  name    = var.name
  project = var.project_id
  region  = var.region
  
  # Resource-specific configuration
  
  labels = var.labels
}

# modules/{category}/{resource}/variables.tf
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

# modules/{category}/{resource}/outputs.tf
output "id" {
  description = "Resource ID"
  value       = google_{resource_type}.{name}.id
}
```

---

## 💬 Response Patterns

### When Asked About Resource Status
```bash
# Check resource existence
gcloud {service} {resource-type} describe {resource-name} \
  --project={project-id} \
  --region={region}

# Get resource details
terragrunt output --terragrunt-working-dir infrastructure/environments/{env}

# View state
terragrunt state show {resource_address}
```

### When Asked to Add a New Service
1. **Check prerequisites:**
   - Required APIs enabled
   - Dependencies exist
   - Naming follows convention

2. **Create module if needed:**
   - Follow module template above
   - Include all standard variables
   - Add comprehensive outputs

3. **Create environment config:**
   - Use proper file naming
   - Include all dependencies
   - Follow label standards

4. **Update documentation:**
   - Add to README
   - Update dependency graph
   - Include in test suite

### When Asked About Costs
```bash
# Generate cost breakdown
infracost breakdown --path infrastructure/environments/{env}

# Compare environments
infracost diff --path infrastructure/environments/dev \
  --compare-to infrastructure/environments/prod

# Key metrics to report:
# - Total monthly cost
# - Cost per service
# - Biggest cost drivers
# - Optimization opportunities
```

---

## 🚨 Error Handling Patterns

### Terragrunt Errors
```yaml
dependency_cycle:
  error: "There are dependency cycles"
  solution: Review dependency blocks, ensure no circular references

provider_error:
  error: "Error configuring Terraform provider"
  solution: Check credentials, project ID, and API enablement

state_migration:
  error: "Resource already exists"
  solution: Import existing resource or use different name
  command: terragrunt import {resource_address} {resource_id}
```

### GCP Errors
```yaml
permission_denied:
  error: "Permission denied on resource"
  solution: Check IAM roles for service account
  debug: gcloud projects get-iam-policy {project-id}

quota_exceeded:
  error: "Quota exceeded for quota metric"
  solution: Request quota increase or use different region
  check: gcloud compute project-info describe --project={project-id}

api_disabled:
  error: "API {api} not enabled"
  solution: Enable required API
  fix: gcloud services enable {api}.googleapis.com
```

---

## 📊 Monitoring & Observability

### Key Metrics to Track
```yaml
infrastructure_metrics:
  - Resource utilization (CPU, memory, disk)
  - Network throughput and latency
  - Error rates and status codes
  - Cost per environment

application_metrics:
  - Request rates and response times
  - Error rates by service
  - Database query performance
  - Cache hit rates

security_metrics:
  - Failed authentication attempts
  - Firewall rule violations
  - Secret access patterns
  - Compliance violations
```

### Useful Queries
```sql
-- BigQuery: Analyze costs by label
SELECT
  labels.environment,
  labels.component,
  SUM(cost) as total_cost
FROM `billing_export.gcp_billing_export_v1`
WHERE DATE(_PARTITIONTIME) = CURRENT_DATE()
GROUP BY 1, 2
ORDER BY total_cost DESC;

-- Logs: Find errors
resource.type="k8s_container"
severity>=ERROR
timestamp>="2024-01-01T00:00:00Z"
```

---

## 🔄 Common Workflows

### 1. Deploy New Environment
```bash
# 1. Copy existing environment
cp -r infrastructure/environments/dev infrastructure/environments/new-env

# 2. Update environment variables
sed -i 's/dev/new-env/g' infrastructure/environments/new-env/*.hcl

# 3. Initialize
cd infrastructure/environments/new-env
terragrunt run-all init

# 4. Plan
terragrunt run-all plan

# 5. Apply
terragrunt run-all apply
```

### 2. Update Module Version
```bash
# 1. Update source in terragrunt.hcl
terraform {
  source = "../../modules/category/resource?ref=v2.0.0"
}

# 2. Re-initialize
terragrunt init -upgrade

# 3. Plan changes
terragrunt plan

# 4. Apply if safe
terragrunt apply
```

### 3. Disaster Recovery
```bash
# 1. Check current state
terragrunt state list

# 2. Backup state
gsutil cp gs://terraform-state-bucket/terraform.tfstate ./backup.tfstate

# 3. For corruption, restore from backup
gsutil cp ./backup.tfstate gs://terraform-state-bucket/terraform.tfstate

# 4. For resource issues, taint and recreate
terragrunt taint {resource_address}
terragrunt apply
```

---

## 🎓 Learning Resources

### Key Concepts to Understand
```yaml
terragrunt_concepts:
  - Dependency blocks and mock outputs
  - Include blocks and find_in_parent_folders()
  - Remote state configuration
  - Input inheritance

gcp_concepts:
  - Project and folder hierarchy
  - IAM and service accounts
  - VPC and networking
  - Workload Identity Federation

terraform_concepts:
  - State management
  - Resource lifecycle
  - Provider configuration
  - Module composition
```

### Useful Commands Reference
```bash
# Terragrunt
terragrunt run-all plan          # Plan all resources
terragrunt graph-dependencies    # Show dependency graph
terragrunt hclfmt                # Format HCL files
terragrunt validate-all          # Validate configurations

# GCP
gcloud config list               # Show current configuration
gcloud projects list             # List all projects
gcloud services list --enabled   # List enabled APIs
gcloud compute zones list        # List available zones

# Debugging
export TF_LOG=DEBUG              # Enable debug logging
terragrunt console               # Interactive console
terragrunt state pull            # Download current state
```

---

## 🤝 Collaboration Guidelines

### When Working with Human Operators
1. **Always confirm understanding** of the environment (dev/staging/prod)
2. **Provide rollback procedures** for any destructive changes
3. **Include testing commands** to verify changes
4. **Explain cost implications** of resource changes
5. **Highlight security considerations** for any modifications

### Response Format Preferences
```yaml
for_quick_fixes:
  - Direct commands with context
  - Expected output
  - Rollback procedure

for_analysis:
  - Current state summary
  - Issue identification
  - Recommended solutions with trade-offs
  - Implementation steps

for_new_features:
  - Architecture diagram/description
  - Module code
  - Terragrunt configuration
  - Test procedures
  - Documentation updates
```

---

## 📝 Documentation Standards

### Code Comments
```hcl
# Purpose: Brief description of what this resource does
# Dependencies: List any required resources
# Considerations: Note any important details
resource "google_example" "name" {
  # Inline comments for complex logic
  setting = var.complex_value # Explain why
}
```

### Commit Messages
```
type(scope): description

- feat(gke): add autoscaling configuration
- fix(network): correct firewall rule priority  
- docs(readme): update deployment instructions
- refactor(modules): simplify variable structure
- test(uat): add Cloud SQL backup tests
```

---

## 🔮 AI-Specific Instructions

### Context Retention
Remember across conversation:
- Current environment being worked on
- Recent errors encountered
- Optimization goals mentioned
- Security requirements stated

### Proactive Suggestions
When reviewing configurations, check for:
- Missing security best practices
- Cost optimization opportunities
- Performance improvements
- Compliance requirements

### Safety Checks
Before suggesting destructive operations:
- Confirm environment (never auto-approve in prod)
- Provide state backup commands
- Include rollback procedures
- Estimate downtime/impact

---

## 🚀 Quick Start for AI

```bash
# Set context
export ENVIRONMENT="dev"
export PROJECT_ID="acme-${ENVIRONMENT}-project"
export REGION="us-central1"

# Authenticate
gcloud auth application-default login
gcloud config set project $PROJECT_ID

# Navigate to environment
cd infrastructure/environments/$ENVIRONMENT

# Check current state
terragrunt run-all plan

# Your assistance starts here...
```

---

## 📚 Appendix: Resource Quick Reference

### Service Limits
```yaml
gke:
  max_nodes_per_cluster: 15000
  max_pods_per_node: 110
  
cloud_run:
  max_containers_per_service: 1000
  max_concurrent_requests: 1000
  max_request_timeout: 60min
  
cloud_sql:
  max_connections: 4000  # varies by tier
  max_storage: 64TB
  
bigquery:
  max_table_size: unlimited
  max_query_length: 1MB
  max_query_execution: 6hours
```

### Cost Factors
```yaml
primary_cost_drivers:
  - Compute instance hours
  - Storage capacity and operations
  - Network egress traffic
  - Load balancer forwarding rules
  - SQL instance uptime
  - BigQuery slot usage

optimization_levers:
  - Preemptible/Spot instances
  - Committed use discounts
  - Storage lifecycle policies
  - CDN caching
  - Autoscaling tuning
  - Query optimization
```

---

*Last Updated: 2024*
*Version: 1.0.0*
*Maintainer: Platform Team*