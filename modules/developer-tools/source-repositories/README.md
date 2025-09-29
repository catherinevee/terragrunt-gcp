# Source-repositories Module

## Overview
This module manages source repositories resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "source-repositories" {
  source = "../../modules/developer-tools/source-repositories"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "source-repositories_advanced" {
  source = "../../modules/developer-tools/source-repositories"

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
    module      = "source-repositories"
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
| create_service_account | | string | | yes |
| service_account_id | | string | | yes |
| service_account_roles | | string | | yes |
| repositories | | string | | yes |
| repository_iam_bindings | | string | | yes |
| enable_cloud_build_integration | | string | | yes |
| cloud_build_triggers | | string | | yes |
| enable_pubsub_notifications | | string | | yes |
| pubsub_topics | | string | | yes |
| pubsub_subscriptions | | string | | yes |
| pubsub_topic_iam_bindings | | string | | yes |
| enable_build_artifacts_storage | | string | | yes |
| build_artifacts_bucket_name | | string | | yes |
| storage_bucket_location | | string | | yes |
| force_destroy_bucket | | string | | yes |
| uniform_bucket_level_access | | string | | yes |
| bucket_versioning_enabled | | string | | yes |
| bucket_lifecycle_rules | | string | | yes |
| bucket_retention_policy | | string | | yes |
| bucket_encryption_key | | string | | yes |
| bucket_logging_config | | string | | yes |
| storage_bucket_labels | | string | | yes |
| storage_bucket_iam_bindings | | string | | yes |
| enable_secret_management | | string | | yes |
| repository_secrets | | string | | yes |
| repository_secret_versions | | string | | yes |
| enable_webhook_functions | | string | | yes |
| webhook_functions | | string | | yes |
| enable_monitoring | | string | | yes |
| create_dashboard | | string | | yes |
| dashboard_display_name | | string | | yes |
| notification_channels | | string | | yes |
| alert_policies | | string | | yes |
| enable_audit_logging | | string | | yes |
| audit_log_sink_name | | string | | yes |
| audit_log_destination | | string | | yes |
| enable_branch_protection | | string | | yes |
| branch_protection_rules | | string | | yes |
| enable_code_scanning | | string | | yes |
| code_scanning_config | | string | | yes |
| enable_dependency_scanning | | string | | yes |
| dependency_scanning_config | | string | | yes |
| enable_container_scanning | | string | | yes |
| container_scanning_config | | string | | yes |
| enable_performance_monitoring | | string | | yes |
| performance_monitoring_config | | string | | yes |
| enable_compliance_monitoring | | string | | yes |
| compliance_config | | string | | yes |
| enable_backup_and_recovery | | string | | yes |
| backup_config | | string | | yes |
| integration_configs | | string | | yes |
| workflow_templates | | string | | yes |
| enable_automated_testing | | string | | yes |
| automated_testing_config | | string | | yes |
| labels | | string | | yes |
| tags | | string | | yes |
| environment | | string | | yes |
| custom_build_environments | | string | | yes |
| notification_config | | string | | yes |
| repository_templates | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| repository_names | |
| repository_urls | |
| repository_details | |
| build_trigger_ids | |
| build_trigger_names | |
| build_trigger_details | |
| pubsub_topic_names | |
| pubsub_topic_ids | |
| pubsub_subscription_names | |
| pubsub_subscription_ids | |
| build_artifacts_bucket_name | |
| build_artifacts_bucket_url | |
| service_account_email | |
| service_account_id | |
| repository_secret_names | |
| repository_secret_details | |
| webhook_function_names | |
| webhook_function_urls | |
| monitoring_dashboard_id | |
| monitoring_dashboard_url | |
| alert_policy_ids | |
| alert_policy_names | |
| configuration_metadata | |
| repository_summary | |
| build_configuration_summary | |
| security_configuration | |
| integration_status | |
| performance_monitoring_summary | |
| workflow_template_summary | |
| management_urls | |
| resource_identifiers | |

## Resources Created

The following resources are created by this module:

- google_cloudbuild_trigger
- google_cloudfunctions_function
- google_logging_project_sink
- google_monitoring_alert_policy
- google_monitoring_dashboard
- google_project_iam_member
- google_project_service
- google_pubsub_subscription
- google_pubsub_topic
- google_pubsub_topic_iam_binding
- google_secret_manager_secret
- google_secret_manager_secret_version
- google_service_account
- google_sourcerepo_repository
- google_sourcerepo_repository_iam_binding
- google_storage_bucket
- google_storage_bucket_iam_binding

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
terraform import module.source-repositories.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:13 AM
Module Version: 1.0.0
