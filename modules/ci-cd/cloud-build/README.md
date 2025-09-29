# Cloud-build Module

## Overview
This module manages cloud build resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "cloud-build" {
  source = "../../modules/ci-cd/cloud-build"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "cloud-build_advanced" {
  source = "../../modules/ci-cd/cloud-build"

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
    module      = "cloud-build"
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
| region | | string | | yes |
| environment | | string | | yes |
| name_prefix | | string | | yes |
| build_triggers | | string | | yes |
| worker_pools | | string | | yes |
| build_configs | | string | | yes |
| source_repositories | | string | | yes |
| artifact_registries | | string | | yes |
| create_service_account | | string | | yes |
| service_account_name | | string | | yes |
| grant_service_account_roles | | string | | yes |
| service_account_roles | | string | | yes |
| create_monitoring_alerts | | string | | yes |
| monitoring_alerts | | string | | yes |
| create_monitoring_dashboard | | string | | yes |
| create_budget_alert | | string | | yes |
| billing_account | | string | | yes |
| budget_amount | | string | | yes |
| budget_currency | | string | | yes |
| budget_pubsub_topic | | string | | yes |
| labels | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| build_trigger_ids | |
| build_trigger_names | |
| build_trigger_trigger_ids | |
| build_trigger_create_times | |
| build_trigger_webhook_configs | |
| worker_pool_ids | |
| worker_pool_names | |
| worker_pool_states | |
| worker_pool_create_times | |
| worker_pool_update_times | |
| worker_pool_delete_times | |
| worker_pool_etags | |
| worker_pool_uids | |
| source_repository_urls | |
| source_repository_names | |
| source_repository_sizes | |
| artifact_registry_ids | |
| artifact_registry_names | |
| artifact_registry_create_times | |
| artifact_registry_update_times | |
| artifact_registry_formats | |
| artifact_registry_modes | |
| artifact_registry_size_bytes | |
| artifact_registry_satisfies_pzs | |
| service_account_email | |
| service_account_id | |
| service_account_name | |
| service_account_member | |
| monitoring_alert_policy_ids | |
| monitoring_alert_policy_names | |
| monitoring_dashboard_id | |
| budget_id | |
| budget_name | |
| build_configuration_summary | |
| registry_configuration_summary | |
| worker_pool_configuration_summary | |
| security_configuration_summary | |
| monitoring_configuration_summary | |
| build_steps_summary | |
| connection_info | |
| module_configuration | |
| applied_labels | |
| resource_counts | |

## Resources Created

The following resources are created by this module:

- google_artifact_registry_repository
- google_artifact_registry_repository_iam_member
- google_billing_budget
- google_cloudbuild_trigger
- google_cloudbuild_worker_pool
- google_monitoring_alert_policy
- google_monitoring_dashboard
- google_project_iam_member
- google_project_service
- google_service_account
- google_sourcerepo_repository
- google_storage_bucket_object

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
terraform import module.cloud-build.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:09:59 AM
Module Version: 1.0.0
