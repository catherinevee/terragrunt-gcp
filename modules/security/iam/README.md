# Iam Module

## Overview
This module manages iam resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "iam" {
  source = "../../modules/security/iam"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "iam_advanced" {
  source = "../../modules/security/iam"

  project_id  = var.project_id
  environment = "production"

  # High availability configuration
  enable_ha   = true

  # Security configuration
  encryption_key = google_kms_crypto_key.key.id

  # Networking
  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  # Tags
  labels = {
    environment = "production"
    managed_by  = "terraform"
    module      = "iam"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| google | >= 4.0 |
| google-beta | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| google | >= 4.0 |
| google-beta | >= 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | | string | | yes |
| environment | | string | | yes |
| enable_iam_bindings | | string | | yes |
| service_accounts | | string | | yes |
| custom_roles | | string | | yes |
| service_account_roles | | string | | yes |
| project_iam_bindings | | string | | yes |
| enable_workload_identity | | string | | yes |
| workload_identity_pool_id | | string | | yes |
| workload_identity_display_name | | string | | yes |
| workload_identity_description | | string | | yes |
| workload_identity_pool_provider_id | | string | | yes |
| workload_identity_provider_display_name | | string | | yes |
| workload_identity_provider_description | | string | | yes |
| oidc_issuer_uri | | string | | yes |
| oidc_allowed_audiences | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| service_account_ids | |
| service_account_emails | |
| service_account_names | |
| service_account_unique_ids | |
| service_account_members | |
| service_account_keys | |
| service_account_private_keys | |
| custom_role_ids | |
| custom_role_names | |
| custom_role_titles | |
| custom_role_permissions | |
| project_iam_bindings | |
| project_iam_members | |
| folder_iam_bindings | |
| organization_iam_bindings | |
| workload_identity_pool_id | |
| workload_identity_pool_name | |
| workload_identity_pool_state | |
| workload_identity_pool_providers | |
| workforce_identity_pool_id | |
| workforce_identity_pool_name | |
| workforce_identity_pool_state | |
| workforce_identity_pool_providers | |
| iam_policy_project_id | |
| iam_policy_folder_id | |
| iam_policy_organization_id | |
| conditional_bindings | |
| audit_config | |
| iam_policy_data | |
| deny_policies | |
| access_approval_settings | |
| essential_contacts | |
| binary_authorization_policy | |
| org_policy_constraints | |
| iam_conditions_summary | |
| service_accounts_summary | |
| custom_roles_summary | |

## Resources Created

The following resources are created by this module:

- google_iam_workload_identity_pool
- google_iam_workload_identity_pool_provider
- google_project_iam_custom_role
- google_project_iam_member
- google_project_service
- google_service_account

## IAM Permissions Required

The service account running Terraform needs the following roles:
- `roles/editor` (or more specific roles based on resources)

## Network Requirements

- VPC network with appropriate subnets
- Firewall rules for required ports
- Private Google Access enabled (recommended)

## Security Considerations

- Enable encryption at rest
- Use private IPs where possible
- Implement least privilege IAM
- Enable audit logging
- Regular security scans

## Cost Optimization

- Use appropriate machine types
- Enable autoscaling where applicable
- Schedule resources for dev/staging
- Use preemptible instances for non-critical workloads
- Regular cost analysis and optimization

## Monitoring and Alerting

This module creates the following monitoring resources:
- Log-based metrics
- Uptime checks (where applicable)
- Custom dashboards
- Alert policies

## Backup and Recovery

- Automated backups configured
- Point-in-time recovery enabled
- Cross-region backups for production

## Troubleshooting

### Common Issues

**Issue**: Permission denied errors
```bash
# Solution: Ensure service account has required roles
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA_EMAIL" \
  --role="roles/editor"
```

**Issue**: Resource already exists
```bash
# Solution: Import existing resource
terraform import module.iam.RESOURCE_TYPE.NAME RESOURCE_ID
```

## Development

### Testing
```bash
# Run tests
cd test/
go test -v -timeout 30m
```

### Validation
```bash
# Validate module
terraform init
terraform validate
terraform fmt -check
```

## Contributing

1. Create feature branch
2. Make changes
3. Test thoroughly
4. Submit PR with description

## License

Copyright 2024 - All rights reserved

## Support

For issues or questions:
- Create GitHub issue
- Check documentation
- Contact platform team

---
Generated: Mon, Sep 29, 2025  8:10:26 AM
Module Version: 1.0.0
