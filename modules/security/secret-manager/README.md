# Secret-manager Module

## Overview
This module manages secret manager resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "secret-manager" {
  source = "../../modules/security/secret-manager"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "secret-manager_advanced" {
  source = "../../modules/security/secret-manager"

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
    module      = "secret-manager"
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
| secrets | | string | | yes |
| secret_versions | | string | | yes |
| secret_iam_bindings | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| secret_ids | |
| secret_names | |
| secret_resource_names | |
| secret_project | |
| secret_labels | |
| secret_topics | |
| secret_rotation_periods | |
| secret_next_rotation_times | |
| secret_expiration_times | |
| secret_ttls | |
| secret_version_aliases | |
| secret_annotations | |
| secret_replication_policies | |
| secret_version_ids | |
| secret_version_names | |
| secret_version_create_times | |
| secret_version_destroy_times | |
| secret_version_states | |
| secret_version_enabled_states | |
| secret_data | |
| secret_iam_bindings | |
| secret_iam_members | |
| secret_accessors | |
| secret_version_managers | |
| secret_admins | |
| cmek_encrypted_secrets | |
| automatic_replication_secrets | |
| user_managed_replication_secrets | |
| rotating_secrets | |
| expiring_secrets | |
| ttl_secrets | |
| pubsub_notification_topics | |
| regional_secret_ids | |
| regional_secret_names | |
| regional_secret_locations | |
| regional_secret_customer_managed_encryption | |
| secret_version_count | |
| latest_secret_versions | |
| enabled_secret_versions | |
| destroyed_secret_versions | |
| secret_metadata | |
| secret_access_policies | |
| secret_manager_service_account | |
| secret_manager_api_enabled | |
| total_secrets_count | |
| total_secret_versions_count | |
| total_regional_secrets_count | |
| secrets_by_state | |
| secrets_summary | |
| secret_locations | |
| secret_kms_keys | |
| secret_pubsub_topics | |
| secrets_with_conditions | |
| secret_version_aliases_map | |
| secret_rotation_lambda_functions | |

## Resources Created

The following resources are created by this module:

- google_project_service
- google_secret_manager_secret
- google_secret_manager_secret_iam_binding
- google_secret_manager_secret_version

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
terraform import module.secret-manager.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:28 AM
Module Version: 1.0.0
