# Environment Configuration

## Overview

This directory contains environment-specific Terragrunt configurations for the terragrunt-gcp infrastructure. Each environment is isolated with its own state, configurations, and resources.

## Environment Structure

```
environments/
├── dev/                    # Development environment
│   ├── terragrunt.hcl     # Root configuration
│   ├── account.hcl        # Account-level config
│   ├── env.hcl            # Environment variables
│   ├── global/            # Global resources
│   ├── us-central1/       # Region-specific resources
│   ├── us-east1/          # Region-specific resources
│   └── europe-west1/      # Region-specific resources
├── staging/               # Staging environment
│   └── ...                # Same structure as dev
└── prod/                  # Production environment
    └── ...                # Same structure as dev
```

## Environments

### Development (dev)

**Purpose**: Development and testing
**Project ID**: `acme-ecommerce-platform-dev`
**Primary Region**: `us-central1`

**Characteristics**:
- Cost-optimized configurations
- Smaller instance sizes
- Single-zone deployments
- Shorter retention periods
- Development-grade SLAs
- Frequent deployments allowed

**Access**:
- All developers have read/write access
- Automated testing pipelines
- Feature branch deployments

**State Backend**: `gs://acme-ecommerce-platform-dev-tfstate`

### Staging (staging)

**Purpose**: Pre-production validation
**Project ID**: `acme-ecommerce-platform-staging`
**Primary Region**: `us-central1`

**Characteristics**:
- Production-like configuration
- Scaled-down resource sizing
- Multi-zone deployments
- Standard retention periods
- Production-grade testing
- Controlled deployment schedule

**Access**:
- QA team full access
- Developers read-only access
- Automated integration tests
- Release candidate validation

**State Backend**: `gs://acme-ecommerce-platform-staging-tfstate`

### Production (prod)

**Purpose**: Live production workloads
**Project ID**: `acme-ecommerce-platform-prod`
**Primary Region**: `us-central1`

**Characteristics**:
- High availability (HA) configurations
- Multi-zone/multi-region deployments
- Maximum retention periods
- Production SLAs and monitoring
- Strict change management
- Zero-downtime deployments

**Access**:
- Production team only
- Automated rollback capabilities
- Audit logging for all changes
- Approval workflows required

**State Backend**: `gs://acme-ecommerce-platform-prod-tfstate`

## Regional Structure

Each environment supports multiple regions:

### Primary Region: us-central1
- Main production workloads
- Primary databases
- Core services

### Secondary Region: us-east1
- Disaster recovery
- Geographic distribution
- Failover capabilities

### Europe Region: europe-west1
- GDPR compliance
- EU customer data
- Low latency for European users

## Deployment Order

Resources should be deployed in this order to satisfy dependencies:

### 1. Global Resources
```bash
cd environments/{env}/global
terragrunt apply
```

Resources created:
- DNS zones and records
- Global load balancers
- IAM policies and service accounts
- Organization policies

### 2. Regional Security
```bash
cd environments/{env}/{region}/security
terragrunt run-all apply
```

Resources created:
- KMS keyrings and keys
- Secret Manager secrets
- Security policies
- Certificate Manager certificates

### 3. Regional Networking
```bash
cd environments/{env}/{region}/networking
terragrunt run-all apply
```

Resources created:
- VPC networks
- Subnets
- Firewall rules
- VPN gateways
- Cloud NAT
- Load balancers

### 4. Regional Data Layer
```bash
cd environments/{env}/{region}/data
terragrunt run-all apply
```

Resources created:
- Cloud SQL databases
- Firestore databases
- BigQuery datasets
- Spanner instances
- Memorystore instances

### 5. Regional Storage
```bash
cd environments/{env}/{region}/storage
terragrunt run-all apply
```

Resources created:
- Cloud Storage buckets
- Container Registry
- Filestore instances

### 6. Regional Compute
```bash
cd environments/{env}/{region}/compute
terragrunt run-all apply
```

Resources created:
- GKE clusters
- Cloud Run services
- Compute Engine instances
- Instance groups
- App Engine applications
- Cloud Functions

### 7. Regional Monitoring
```bash
cd environments/{env}/{region}/monitoring
terragrunt run-all apply
```

Resources created:
- Monitoring dashboards
- Alert policies
- Log sinks
- Uptime checks

## Configuration Files

### terragrunt.hcl (Root)

Root configuration file that defines:
- Remote state backend
- Provider generation
- Common inputs
- Environment-specific locals

```hcl
# Example structure
remote_state {
  backend = "gcs"
  config = {
    bucket = "${local.project_id}-tfstate"
    prefix = "${path_relative_to_include()}"
  }
}

generate "provider" {
  path = "provider.tf"
  contents = <<PROVIDER
provider "google" {
  project = "${local.project_id}"
  region  = "${local.region}"
}
PROVIDER
}

locals {
  project_id  = "acme-ecommerce-platform-dev"
  environment = "dev"
  region      = "us-central1"
}
```

### account.hcl

Account-level configuration:
- Organization ID
- Billing account
- Account defaults

### env.hcl

Environment-specific variables:
- Resource sizing
- Retention policies
- Feature flags
- Cost optimization settings

### region.hcl

Region-specific configuration:
- Region identifier
- Zone preferences
- Regional quotas

## Usage

### Plan All Resources in Environment

```bash
cd infrastructure/environments/dev
terragrunt run-all plan
```

### Apply All Resources in Environment

```bash
cd infrastructure/environments/dev
terragrunt run-all apply
```

### Apply Specific Module

```bash
cd infrastructure/environments/dev/us-central1/networking/vpc
terragrunt apply
```

### Destroy Environment (DANGEROUS)

```bash
cd infrastructure/environments/dev
terragrunt run-all destroy
```

## Environment Variables

Required environment variables for deployment:

```bash
# GCP Authentication
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"

# Or use gcloud auth
gcloud auth application-default login

# Secrets (see docs/SECRET-MANAGEMENT.md)
export DB_PASSWORD="secure-password"
export STRIPE_API_KEY="sk_test_..."
# ... other secrets
```

## State Management

### State Buckets

Each environment has its own state bucket:
- `acme-ecommerce-platform-dev-tfstate`
- `acme-ecommerce-platform-staging-tfstate`
- `acme-ecommerce-platform-prod-tfstate`

### State Locking

State locking prevents concurrent modifications:
- Automatic locking on plan/apply
- Lock timeout: 10 minutes
- Force unlock only in emergencies

### State Backup

State is versioned and backed up:
- Object versioning enabled
- 30-day retention for old versions
- Point-in-time recovery available

## Dependency Management

Terragrunt dependencies ensure proper ordering:

```hcl
# Example dependency
dependency "vpc" {
  config_path = "../networking/vpc"
}

inputs = {
  network = dependency.vpc.outputs.network_id
}
```

## Environment-Specific Configurations

### Development
```hcl
# env.hcl
locals {
  instance_type = "n1-standard-1"  # Smaller
  min_replicas  = 1                # Lower
  max_replicas  = 3
  retention_days = 7               # Shorter
}
```

### Staging
```hcl
# env.hcl
locals {
  instance_type = "n1-standard-2"  # Medium
  min_replicas  = 2                # Medium
  max_replicas  = 5
  retention_days = 30              # Standard
}
```

### Production
```hcl
# env.hcl
locals {
  instance_type = "n1-standard-4"  # Larger
  min_replicas  = 3                # Higher
  max_replicas  = 10
  retention_days = 90              # Longer
}
```

## Security Considerations

### Access Control
- Environment isolation via separate projects
- Principle of least privilege
- Service account per environment
- Workload Identity for GKE

### Network Security
- Private IP addresses
- VPC Service Controls
- Cloud Armor policies
- DDoS protection

### Data Protection
- Encryption at rest (CMEK)
- Encryption in transit
- Regular backups
- Audit logging

## Monitoring

### Environment Health Dashboards
- Resource utilization
- Error rates
- Performance metrics
- Cost tracking

### Alerts
- Resource exhaustion
- Deployment failures
- Security incidents
- Cost anomalies

## Cost Management

### Cost by Environment
- Dev: ~$200-500/month
- Staging: ~$500-1000/month
- Prod: ~$2000-5000/month

### Cost Optimization
- Committed use discounts for prod
- Preemptible instances in dev
- Automatic scaling
- Resource cleanup policies

## Troubleshooting

### Common Issues

#### Issue: State lock timeout
```bash
# View current locks
terragrunt state list

# Force unlock (use with caution)
terragrunt force-unlock LOCK_ID
```

#### Issue: Dependency cycle
```bash
# Use skip_outputs to break cycles
dependency "vpc" {
  config_path = "../networking/vpc"
  skip_outputs = true
}
```

#### Issue: Resource already exists
```bash
# Import existing resource
terragrunt import module.resource.name resource_id
```

### Debug Mode

Enable verbose logging:
```bash
export TF_LOG=DEBUG
export TG_LOG=debug
terragrunt plan
```

## Migration Between Environments

### Promote from Dev to Staging

1. Test thoroughly in dev
2. Create PR with changes
3. Review and approve
4. Apply to staging:
   ```bash
   cd infrastructure/environments/staging
   terragrunt run-all plan
   terragrunt run-all apply
   ```

### Promote from Staging to Production

1. Validate in staging
2. Schedule maintenance window
3. Create production PR
4. Require multiple approvals
5. Apply with backup plan:
   ```bash
   cd infrastructure/environments/prod
   terragrunt run-all plan > plan.out
   # Review plan thoroughly
   terragrunt run-all apply
   ```

## Disaster Recovery

### Backup Procedures
- Daily automated state backups
- Configuration stored in Git
- Secrets in Secret Manager
- Database backups per retention policy

### Recovery Procedures

1. **Minor Issues**: Rollback via Git
   ```bash
   git revert <commit>
   terragrunt apply
   ```

2. **Major Issues**: Restore from backup
   ```bash
   gsutil cp gs://backup-bucket/state.tfstate .
   terragrunt import ...
   ```

3. **Complete Rebuild**: Fresh deployment
   ```bash
   terragrunt run-all apply
   ```

## Best Practices

### 1. Always Plan Before Apply
```bash
terragrunt run-all plan | tee plan.out
# Review plan.out thoroughly
terragrunt run-all apply
```

### 2. Use Feature Branches
```bash
git checkout -b feature/new-service
# Make changes
# Test in dev
# Create PR
```

### 3. Keep Environments in Sync
- Use same module versions
- Maintain consistent structure
- Document differences explicitly

### 4. Regular Updates
- Update provider versions quarterly
- Rotate secrets every 90 days
- Review and cleanup unused resources
- Update documentation

### 5. Automated Testing
- Validate Terraform syntax
- Run terraform-compliance
- Test in dev first
- Automated integration tests in staging

## Additional Resources

- [Secret Management Guide](../../docs/SECRET-MANAGEMENT.md)
- [Comprehensive Fix Guide](../../COMPREHENSIVE-FIX-GUIDE.md)
- [Module Documentation](../../modules/)
- [GCP Best Practices](https://cloud.google.com/docs/enterprise/best-practices-for-enterprise-organizations)

## Support

For environment-related issues:
1. Check this documentation
2. Review Terragrunt logs
3. Check GCP Console for resource status
4. Open issue in repository

---

**Maintained by**: Infrastructure Team
**Last Updated**: 2025-09-29