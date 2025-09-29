# Firestore Module

## Overview
This module manages firestore resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "firestore" {
  source = "../../modules/data/firestore"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "firestore_advanced" {
  source = "../../modules/data/firestore"

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
    module      = "firestore"
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
| database_config | | string | | yes |
| deploy_security_rules | | string | | yes |
| security_rules_content | | string | | yes |
| security_rules_file | | string | | yes |
| indexes | | string | | yes |
| ttl_policies | | string | | yes |
| create_service_account | | string | | yes |
| service_account_name | | string | | yes |
| grant_service_account_roles | | string | | yes |
| service_account_roles | | string | | yes |
| database_iam_bindings | | string | | yes |
| enable_backups | | string | | yes |
| backup_schedules | | string | | yes |
| create_initial_documents | | string | | yes |
| initial_documents | | string | | yes |
| create_monitoring_alerts | | string | | yes |
| monitoring_alerts | | string | | yes |
| create_monitoring_dashboard | | string | | yes |
| create_log_metrics | | string | | yes |
| log_metrics | | string | | yes |
| enable_bigquery_export | | string | | yes |
| bigquery_export_location | | string | | yes |
| bigquery_table_expiration_ms | | string | | yes |
| bigquery_partition_expiration_ms | | string | | yes |
| bigquery_access_config | | string | | yes |
| create_data_processors | | string | | yes |
| data_processors | | string | | yes |
| security_config | | string | | yes |
| performance_config | | string | | yes |
| collections_config | | string | | yes |
| import_export_config | | string | | yes |
| multi_region_config | | string | | yes |
| client_config | | string | | yes |
| development_config | | string | | yes |
| compliance_config | | string | | yes |
| labels | | string | | yes |
| enable_realtime_updates | | string | | yes |
| enable_offline_support | | string | | yes |
| enable_persistence | | string | | yes |
| cache_size_mb | | string | | yes |
| lifecycle_config | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| database_id | |
| database_name | |
| database_location | |
| database_type | |
| database_uid | |
| database_create_time | |
| database_earliest_version_time | |
| database_version_retention_period | |
| database_etag | |
| database_key_prefix | |
| service_account_email | |
| service_account_id | |
| service_account_name | |
| service_account_member | |
| security_ruleset_name | |
| security_ruleset_create_time | |
| security_rules_release_name | |
| security_rules_release_create_time | |
| index_ids | |
| index_names | |
| index_collections | |
| index_fields | |
| ttl_field_names | |
| ttl_field_collections | |
| ttl_field_states | |
| backup_schedule_ids | |
| backup_schedule_names | |
| initial_document_ids | |
| initial_document_names | |
| initial_document_paths | |
| bigquery_dataset_id | |
| bigquery_dataset_location | |
| bigquery_dataset_self_link | |
| data_processor_ids | |
| data_processor_names | |
| data_processor_sources | |
| monitoring_alert_policy_ids | |
| monitoring_alert_policy_names | |
| monitoring_dashboard_id | |
| log_metric_names | |
| log_metric_ids | |
| iam_members | |
| database_configuration | |
| security_configuration | |
| monitoring_configuration | |
| performance_configuration | |
| backup_configuration | |
| index_summary | |
| collections_summary | |
| module_configuration | |
| applied_labels | |
| resource_counts | |
| connection_info | |

## Resources Created

The following resources are created by this module:

- google_bigquery_dataset
- google_cloudfunctions_function
- google_firestore_backup_schedule
- google_firestore_database
- google_firestore_database_iam_member
- google_firestore_document
- google_firestore_field
- google_firestore_index
- google_firestore_release
- google_firestore_ruleset
- google_logging_metric
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
terraform import module.firestore.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:10 AM
Module Version: 1.0.0
