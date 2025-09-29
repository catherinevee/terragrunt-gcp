# Gcs Module

## Overview
This module manages gcs resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "gcs" {
  source = "../../modules/storage/gcs"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "gcs_advanced" {
  source = "../../modules/storage/gcs"

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
    module      = "gcs"
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
| name | | string | | yes |
| name_prefix | | string | | yes |
| location | | string | | yes |
| storage_class | | string | | yes |
| force_destroy | | string | | yes |
| uniform_bucket_level_access | | string | | yes |
| public_access_prevention | | string | | yes |
| requester_pays | | string | | yes |
| default_event_based_hold | | string | | yes |
| environment | | string | | yes |
| versioning | | string | | yes |
| lifecycle_rules | | string | | yes |
| enable_default_lifecycle_rules | | string | | yes |
| cors | | string | | yes |
| enable_default_cors | | string | | yes |
| website | | string | | yes |
| enable_website | | string | | yes |
| website_main_page_suffix | | string | | yes |
| website_not_found_page | | string | | yes |
| retention_policy | | string | | yes |
| retention_days | | string | | yes |
| retention_policy_is_locked | | string | | yes |
| encryption | | string | | yes |
| kms_key_name | | string | | yes |
| logging | | string | | yes |
| autoclass | | string | | yes |
| custom_placement_config | | string | | yes |
| labels | | string | | yes |
| iam_policy | | string | | yes |
| iam_bindings | | string | | yes |
| iam_binding_conditions | | string | | yes |
| iam_members | | string | | yes |
| predefined_acl | | string | | yes |
| role_entities | | string | | yes |
| default_acl | | string | | yes |
| objects | | string | | yes |
| notifications | | string | | yes |
| timeouts | | string | | yes |
| module_depends_on | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| bucket_name | |
| bucket_id | |
| bucket_self_link | |
| bucket_url | |
| location | |
| storage_class | |
| project | |
| uniform_bucket_level_access | |
| public_access_prevention | |
| requester_pays | |
| default_event_based_hold | |
| versioning_enabled | |
| lifecycle_rules | |
| lifecycle_rules_count | |
| cors | |
| website | |
| website_endpoint | |
| retention_policy | |
| retention_policy_is_locked | |
| retention_period_seconds | |
| encryption | |
| default_kms_key_name | |
| logging | |
| autoclass | |
| autoclass_enabled | |
| labels | |
| effective_labels | |
| objects | |
| object_count | |
| iam_policy_etag | |
| iam_bindings | |
| iam_members | |
| acl | |
| default_object_acl | |
| notifications | |
| console_url | |
| gsutil_url | |
| api_endpoint | |
| gsutil_commands | |
| import_commands | |

## Resources Created

The following resources are created by this module:

- google_storage_bucket
- google_storage_bucket_acl
- google_storage_bucket_iam_binding
- google_storage_bucket_iam_member
- google_storage_bucket_iam_policy
- google_storage_bucket_object
- google_storage_default_object_acl
- google_storage_notification
- random_id

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
terraform import module.gcs.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:29 AM
Module Version: 1.0.0
