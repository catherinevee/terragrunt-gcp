# Spanner Module

## Overview
This module manages spanner resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "spanner" {
  source = "../../modules/data/spanner"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "spanner_advanced" {
  source = "../../modules/data/spanner"

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
    module      = "spanner"
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
| use_existing_instance | | string | | yes |
| existing_instance_name | | string | | yes |
| instance_config | | string | | yes |
| databases | | string | | yes |
| backup_configs | | string | | yes |
| backup_schedules | | string | | yes |
| create_service_account | | string | | yes |
| service_account_name | | string | | yes |
| grant_service_account_roles | | string | | yes |
| service_account_roles | | string | | yes |
| instance_iam_policies | | string | | yes |
| database_iam_policies | | string | | yes |
| create_monitoring_alerts | | string | | yes |
| monitoring_alerts | | string | | yes |
| create_monitoring_dashboard | | string | | yes |
| create_log_metrics | | string | | yes |
| log_metrics | | string | | yes |
| create_operation_functions | | string | | yes |
| operation_functions | | string | | yes |
| enable_bigquery_export | | string | | yes |
| bigquery_export_location | | string | | yes |
| bigquery_table_expiration_ms | | string | | yes |
| bigquery_partition_expiration_ms | | string | | yes |
| bigquery_access_config | | string | | yes |
| enable_dataflow_export | | string | | yes |
| dataflow_template_path | | string | | yes |
| dataflow_temp_location | | string | | yes |
| dataflow_source_database | | string | | yes |
| dataflow_output_table | | string | | yes |
| dataflow_parameters | | string | | yes |
| enable_change_streams | | string | | yes |
| change_stream_topics | | string | | yes |
| enable_maintenance_jobs | | string | | yes |
| maintenance_jobs | | string | | yes |
| performance_config | | string | | yes |
| security_config | | string | | yes |
| scaling_config | | string | | yes |
| multi_region_config | | string | | yes |
| disaster_recovery_config | | string | | yes |
| connection_config | | string | | yes |
| query_config | | string | | yes |
| cost_optimization_config | | string | | yes |
| compliance_config | | string | | yes |
| advanced_features_config | | string | | yes |
| migration_config | | string | | yes |
| labels | | string | | yes |
| lifecycle_config | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | |
| instance_name | |
| instance_display_name | |
| instance_config | |
| instance_num_nodes | |
| instance_processing_units | |
| instance_state | |
| instance_labels | |
| database_ids | |
| database_names | |
| database_states | |
| database_version_retention_periods | |
| database_dialects | |
| database_earliest_version_times | |
| database_encryption_configs | |
| backup_ids | |
| backup_names | |
| backup_states | |
| backup_create_times | |
| backup_size_bytes | |
| backup_referencing_databases | |
| backup_schedule_ids | |
| backup_schedule_names | |
| service_account_email | |
| service_account_id | |
| service_account_name | |
| service_account_member | |
| instance_iam_bindings | |
| database_iam_bindings | |
| monitoring_alert_policy_ids | |
| monitoring_alert_policy_names | |
| monitoring_dashboard_id | |
| log_metric_names | |
| log_metric_ids | |
| operation_function_ids | |
| operation_function_names | |
| operation_function_trigger_urls | |
| bigquery_dataset_id | |
| bigquery_dataset_location | |
| bigquery_dataset_self_link | |
| dataflow_job_id | |
| dataflow_job_name | |
| dataflow_job_state | |
| change_stream_topic_names | |
| change_stream_topic_ids | |
| maintenance_job_ids | |
| maintenance_job_names | |
| connection_info | |
| instance_configuration | |
| database_configurations | |
| backup_configuration | |
| security_configuration | |
| performance_configuration | |
| cost_summary | |
| disaster_recovery_summary | |
| integration_status | |
| module_configuration | |
| applied_labels | |
| resource_counts | |

## Resources Created

The following resources are created by this module:

- google_bigquery_dataset
- google_cloud_scheduler_job
- google_cloudfunctions_function
- google_dataflow_job
- google_logging_metric
- google_monitoring_alert_policy
- google_monitoring_dashboard
- google_project_iam_member
- google_project_service
- google_pubsub_topic
- google_service_account
- google_spanner_backup
- google_spanner_backup_schedule
- google_spanner_database
- google_spanner_database_iam_binding
- google_spanner_instance
- google_spanner_instance_iam_binding

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
terraform import module.spanner.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:12 AM
Module Version: 1.0.0
