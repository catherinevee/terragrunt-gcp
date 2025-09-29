# Kms Module

## Overview
This module manages kms resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "kms" {
  source = "../../modules/security/kms"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "kms_advanced" {
  source = "../../modules/security/kms"

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
    module      = "kms"
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
| region | | string | | yes |
| key_ring_name | | string | | yes |
| crypto_keys | | string | | yes |
| enable_iam_bindings | | string | | yes |
| crypto_key_iam_bindings | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| keyring_id | |
| keyring_name | |
| keyring_location | |
| keyring_self_link | |
| key_ids | |
| key_names | |
| key_self_links | |
| key_purposes | |
| key_rotation_periods | |
| key_algorithms | |
| key_protection_levels | |
| key_version_ids | |
| key_version_names | |
| key_version_states | |
| key_version_algorithms | |
| key_version_protection_levels | |
| key_version_attestations | |
| key_version_generate_times | |
| key_version_destroy_times | |
| import_job_ids | |
| import_job_names | |
| import_job_states | |
| import_job_import_methods | |
| import_job_protection_levels | |
| import_job_public_keys | |
| import_job_attestations | |
| key_iam_bindings | |
| key_iam_members | |
| keyring_iam_bindings | |
| keyring_iam_members | |
| secret_manager_crypto_keys | |
| ekm_connection_id | |
| ekm_connection_name | |
| ekm_connection_service_resolvers | |
| ekm_connection_key_management_mode | |
| ekm_connection_crypto_space_path | |
| autokey_config | |
| key_labels | |
| key_skip_initial_version_creation | |
| key_import_only | |
| key_destroy_scheduled_duration | |
| crypto_key_backend_services | |
| project_id | |
| kms_service_account | |
| kms_crypto_key_encrypter_decrypters | |
| kms_admin_members | |
| hsm_keys | |
| software_keys | |
| external_keys | |
| external_vpc_keys | |
| symmetric_encryption_keys | |
| asymmetric_signing_keys | |
| asymmetric_decryption_keys | |
| mac_signing_keys | |
| raw_encryption_keys | |
| key_creation_times | |
| primary_key_versions | |
| key_state_summary | |
| kms_locations | |
| enabled_services | |

## Resources Created

The following resources are created by this module:

- google_kms_crypto_key
- google_kms_crypto_key_iam_binding
- google_kms_key_ring
- google_project_service

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
terraform import module.kms.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:27 AM
Module Version: 1.0.0
