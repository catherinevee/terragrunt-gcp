# Binary-authorization Module

## Overview
This module manages binary authorization resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "binary-authorization" {
  source = "../../modules/security/binary-authorization"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "binary-authorization_advanced" {
  source = "../../modules/security/binary-authorization"

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
    module      = "binary-authorization"
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
| enable_apis | | string | | yes |
| global_policy_evaluation_mode | | string | | yes |
| policy_description | | string | | yes |
| admission_whitelist_patterns | | string | | yes |
| default_admission_rule | | string | | yes |
| cluster_admission_rules | | string | | yes |
| kubernetes_namespace_admission_rules | | string | | yes |
| kubernetes_service_account_admission_rules | | string | | yes |
| cloud_run_admission_rules | | string | | yes |
| attestors | | string | | yes |
| container_analysis_notes | | string | | yes |
| enable_vulnerability_scanning | | string | | yes |
| vulnerability_scanning_config | | string | | yes |
| enable_continuous_validation | | string | | yes |
| continuous_validation_config | | string | | yes |
| enable_platform_policies | | string | | yes |
| platform_policies | | string | | yes |
| enable_kms_signing | | string | | yes |
| kms_config | | string | | yes |
| enable_breakglass | | string | | yes |
| breakglass_config | | string | | yes |
| trusted_registries | | string | | yes |
| blocked_registries | | string | | yes |
| trusted_directory_patterns | | string | | yes |
| image_signing_config | | string | | yes |
| enable_monitoring | | string | | yes |
| monitoring_config | | string | | yes |
| enable_policy_bindings | | string | | yes |
| policy_bindings | | string | | yes |
| enable_supply_chain_validation | | string | | yes |
| supply_chain_validation_config | | string | | yes |
| enable_admission_controller_webhook | | string | | yes |
| admission_webhook_config | | string | | yes |
| enable_cloud_build_integration | | string | | yes |
| cloud_build_config | | string | | yes |
| labels | | string | | yes |
| enable_dry_run | | string | | yes |
| dry_run_config | | string | | yes |
| compliance_standards | | string | | yes |
| image_freshness_config | | string | | yes |
| attestation_authority_iam_bindings | | string | | yes |
| enable_policy_data_sync | | string | | yes |
| policy_data_sync_config | | string | | yes |
| exemption_config | | string | | yes |
| enable_cross_project_attestation | | string | | yes |
| cross_project_config | | string | | yes |
| enable_automated_remediation | | string | | yes |
| remediation_config | | string | | yes |
| network_policy_config | | string | | yes |
| custom_attestor_validation_rules | | string | | yes |
| enable_cost_optimization | | string | | yes |
| cost_optimization_config | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| policy_id | |
| policy_global_evaluation_mode | |
| policy_description | |
| policy_etag | |
| attestor_names | |
| attestor_ids | |
| attestor_details | |
| container_analysis_note_names | |
| container_analysis_note_ids | |
| container_analysis_note_details | |
| kms_keyring_id | |
| kms_keyring_location | |
| kms_crypto_key_id | |
| kms_crypto_key_name | |
| attestation_service_account_email | |
| attestation_service_account_id | |
| attestation_service_account_unique_id | |
| cloud_build_trigger_ids | |
| cloud_build_trigger_names | |
| cloud_build_trigger_details | |
| monitoring_dashboard_id | |
| monitoring_dashboard_url | |
| alert_policy_ids | |
| alert_policy_names | |
| configuration_metadata | |
| admission_rule_summary | |
| attestation_authority_note_names | |
| user_owned_grafeas_note_names | |
| attestor_public_keys | |
| security_configuration | |
| platform_integration | |
| operational_configuration | |
| iam_configuration | |
| api_status | |
| policy_validation | |
| network_security | |
| quota_configuration | |
| management_urls | |
| resource_identifiers | |

## Resources Created

The following resources are created by this module:

- google_binary_authorization_attestor
- google_binary_authorization_attestor_iam_binding
- google_binary_authorization_platform_policy
- google_binary_authorization_policy
- google_binary_authorization_policy_binding
- google_cloudbuild_trigger
- google_container_analysis_note
- google_container_analysis_occurrence
- google_kms_crypto_key
- google_kms_crypto_key_iam_binding
- google_kms_key_ring
- google_monitoring_alert_policy
- google_monitoring_dashboard
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
terraform import module.binary-authorization.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:24 AM
Module Version: 1.0.0
