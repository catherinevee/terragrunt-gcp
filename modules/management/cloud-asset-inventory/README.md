# Cloud-asset-inventory Module

## Overview
This module manages cloud asset inventory resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "cloud-asset-inventory" {
  source = "../../modules/management/cloud-asset-inventory"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "cloud-asset-inventory_advanced" {
  source = "../../modules/management/cloud-asset-inventory"

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
    module      = "cloud-asset-inventory"
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
| org_id | | string | | yes |
| enable_apis | | string | | yes |
| create_service_account | | string | | yes |
| service_account_id | | string | | yes |
| service_account_roles | | string | | yes |
| asset_feeds | | string | | yes |
| org_asset_feeds | | string | | yes |
| folder_asset_feeds | | string | | yes |
| create_pubsub_topics | | string | | yes |
| pubsub_topics | | string | | yes |
| create_pubsub_subscriptions | | string | | yes |
| pubsub_subscriptions | | string | | yes |
| enable_bigquery_export | | string | | yes |
| bigquery_dataset_id | | string | | yes |
| bigquery_location | | string | | yes |
| bigquery_table_expiration_ms | | string | | yes |
| bigquery_partition_expiration_ms | | string | | yes |
| delete_dataset_on_destroy | | string | | yes |
| bigquery_dataset_access | | string | | yes |
| bigquery_dataset_labels | | string | | yes |
| bigquery_tables | | string | | yes |
| enable_storage_export | | string | | yes |
| storage_bucket_name | | string | | yes |
| storage_bucket_location | | string | | yes |
| force_destroy_bucket | | string | | yes |
| uniform_bucket_level_access | | string | | yes |
| bucket_versioning_enabled | | string | | yes |
| bucket_lifecycle_rules | | string | | yes |
| bucket_retention_policy | | string | | yes |
| bucket_encryption_key | | string | | yes |
| bucket_logging_config | | string | | yes |
| storage_bucket_labels | | string | | yes |
| enable_cloud_functions | | string | | yes |
| cloud_functions | | string | | yes |
| enable_scheduled_exports | | string | | yes |
| scheduled_export_jobs | | string | | yes |
| enable_monitoring | | string | | yes |
| create_dashboard | | string | | yes |
| dashboard_display_name | | string | | yes |
| notification_channels | | string | | yes |
| alert_policies | | string | | yes |
| bigquery_dataset_iam_bindings | | string | | yes |
| storage_bucket_iam_bindings | | string | | yes |
| pubsub_topic_iam_bindings | | string | | yes |
| enable_audit_logging | | string | | yes |
| audit_log_sink_name | | string | | yes |
| audit_log_destination | | string | | yes |
| enable_security_center_integration | | string | | yes |
| security_center_source_name | | string | | yes |
| enable_compliance_monitoring | | string | | yes |
| compliance_policies | | string | | yes |
| enable_data_governance | | string | | yes |
| data_governance_config | | string | | yes |
| enable_cost_analysis | | string | | yes |
| cost_analysis_config | | string | | yes |
| enable_security_insights | | string | | yes |
| security_insights_config | | string | | yes |
| enable_resource_hierarchy_analysis | | string | | yes |
| resource_hierarchy_config | | string | | yes |
| enable_automation | | string | | yes |
| automation_config | | string | | yes |
| export_formats | | string | | yes |
| data_retention_config | | string | | yes |
| integration_configs | | string | | yes |
| labels | | string | | yes |
| tags | | string | | yes |
| environment | | string | | yes |
| custom_asset_types | | string | | yes |
| notification_config | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| project_feed_ids | |
| project_feed_details | |
| org_feed_ids | |
| org_feed_details | |
| folder_feed_ids | |
| folder_feed_details | |
| pubsub_topic_names | |
| pubsub_topic_ids | |
| pubsub_topic_details | |
| pubsub_subscription_names | |
| pubsub_subscription_ids | |
| pubsub_subscription_details | |
| bigquery_dataset_id | |
| bigquery_dataset_location | |
| bigquery_dataset_details | |
| bigquery_table_ids | |
| bigquery_table_details | |
| storage_bucket_name | |
| storage_bucket_url | |
| storage_bucket_details | |
| service_account_email | |
| service_account_id | |
| service_account_unique_id | |
| service_account_details | |
| cloud_function_names | |
| cloud_function_details | |
| scheduler_job_names | |
| scheduler_job_details | |
| monitoring_dashboard_id | |
| monitoring_dashboard_url | |
| alert_policy_ids | |
| alert_policy_names | |
| alert_policy_details | |
| security_center_source_name | |
| security_center_source_details | |
| configuration_metadata | |
| feed_configuration_summary | |
| export_configuration_summary | |
| automation_summary | |
| security_compliance_summary | |
| data_lifecycle_summary | |
| integration_status | |
| management_urls | |
| resource_identifiers | |

## Resources Created

The following resources are created by this module:

- google_bigquery_dataset
- google_bigquery_dataset_iam_binding
- google_bigquery_table
- google_cloud_asset_folder_feed
- google_cloud_asset_organization_feed
- google_cloud_asset_project_feed
- google_cloud_scheduler_job
- google_cloudfunctions_function
- google_logging_project_sink
- google_monitoring_alert_policy
- google_monitoring_dashboard
- google_project_iam_member
- google_project_service
- google_pubsub_subscription
- google_pubsub_topic
- google_pubsub_topic_iam_binding
- google_security_center_source
- google_service_account
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
terraform import module.cloud-asset-inventory.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:16 AM
Module Version: 1.0.0
