# Cloud-scheduler Module

## Overview
This module manages cloud scheduler resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "cloud-scheduler" {
  source = "../../modules/compute/cloud-scheduler"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "cloud-scheduler_advanced" {
  source = "../../modules/compute/cloud-scheduler"

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
    module      = "cloud-scheduler"
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
| scheduler_jobs | | string | | yes |
| create_service_account | | string | | yes |
| service_account_name | | string | | yes |
| grant_service_account_roles | | string | | yes |
| service_account_roles | | string | | yes |
| create_pubsub_topics | | string | | yes |
| pubsub_topic_names | | string | | yes |
| pubsub_message_retention_duration | | string | | yes |
| pubsub_schema_name | | string | | yes |
| pubsub_schema_encoding | | string | | yes |
| job_iam_bindings | | string | | yes |
| create_monitoring_alerts | | string | | yes |
| monitoring_alerts | | string | | yes |
| create_monitoring_dashboard | | string | | yes |
| create_log_metrics | | string | | yes |
| log_metrics | | string | | yes |
| labels | | string | | yes |
| create_backup_jobs | | string | | yes |
| backup_jobs_config | | string | | yes |
| create_maintenance_jobs | | string | | yes |
| maintenance_jobs_config | | string | | yes |
| create_report_jobs | | string | | yes |
| report_jobs_config | | string | | yes |
| max_concurrent_jobs | | string | | yes |
| default_time_zone | | string | | yes |
| default_attempt_deadline | | string | | yes |
| enable_job_monitoring | | string | | yes |
| job_timeout_threshold | | string | | yes |
| job_failure_threshold | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| http_job_ids | |
| http_job_names | |
| http_job_regions | |
| http_job_schedules | |
| pubsub_job_ids | |
| pubsub_job_names | |
| pubsub_job_topics | |
| app_engine_job_ids | |
| app_engine_job_names | |
| app_engine_job_uris | |
| cloud_function_job_ids | |
| cloud_function_job_names | |
| cloud_function_job_uris | |
| all_job_ids | |
| all_job_names | |
| total_job_count | |
| service_account_email | |
| service_account_id | |
| service_account_name | |
| service_account_member | |
| pubsub_topic_names | |
| pubsub_topic_ids | |
| monitoring_alert_policy_ids | |
| monitoring_alert_policy_names | |
| monitoring_dashboard_id | |
| log_metric_names | |
| log_metric_ids | |
| job_configurations | |
| iam_members | |
| module_configuration | |
| retry_configurations | |
| schedule_summary | |
| applied_labels | |
| resource_counts | |

## Resources Created

The following resources are created by this module:

- google_cloud_scheduler_job
- google_cloud_scheduler_job_iam_member
- google_logging_metric
- google_monitoring_alert_policy
- google_monitoring_dashboard
- google_project_iam_member
- google_pubsub_topic
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
terraform import module.cloud-scheduler.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:03 AM
Module Version: 1.0.0
