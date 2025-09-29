# Cloud-tasks Module

## Overview
This module manages cloud tasks resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "cloud-tasks" {
  source = "../../modules/compute/cloud-tasks"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "cloud-tasks_advanced" {
  source = "../../modules/compute/cloud-tasks"

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
    module      = "cloud-tasks"
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
| task_queues | | string | | yes |
| create_service_account | | string | | yes |
| service_account_name | | string | | yes |
| grant_service_account_roles | | string | | yes |
| service_account_roles | | string | | yes |
| queue_iam_bindings | | string | | yes |
| create_sample_tasks | | string | | yes |
| sample_tasks | | string | | yes |
| create_monitoring_alerts | | string | | yes |
| monitoring_alerts | | string | | yes |
| create_monitoring_dashboard | | string | | yes |
| create_log_metrics | | string | | yes |
| log_metrics | | string | | yes |
| create_task_processors | | string | | yes |
| task_processors | | string | | yes |
| create_default_queues | | string | | yes |
| default_queues_config | | string | | yes |
| dead_letter_queue_config | | string | | yes |
| enable_queue_stats | | string | | yes |
| max_concurrent_tasks | | string | | yes |
| default_task_timeout | | string | | yes |
| enable_task_retries | | string | | yes |
| default_retry_attempts | | string | | yes |
| enable_dlq | | string | | yes |
| performance_config | | string | | yes |
| security_config | | string | | yes |
| labels | | string | | yes |
| ignore_changes | | string | | yes |
| pubsub_integration | | string | | yes |
| firestore_integration | | string | | yes |
| alerting_thresholds | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| http_queue_ids | |
| http_queue_names | |
| http_queue_locations | |
| app_engine_queue_ids | |
| app_engine_queue_names | |
| app_engine_queue_locations | |
| pull_queue_ids | |
| pull_queue_names | |
| pull_queue_locations | |
| all_queue_ids | |
| all_queue_names | |
| total_queue_count | |
| service_account_email | |
| service_account_id | |
| service_account_name | |
| service_account_member | |
| sample_task_ids | |
| sample_task_names | |
| task_processor_ids | |
| task_processor_names | |
| task_processor_trigger_urls | |
| monitoring_alert_policy_ids | |
| monitoring_alert_policy_names | |
| monitoring_dashboard_id | |
| log_metric_names | |
| log_metric_ids | |
| queue_configurations | |
| iam_members | |
| rate_limit_summary | |
| retry_configurations | |
| queue_states | |
| logging_configurations | |
| module_configuration | |
| performance_summary | |
| applied_labels | |
| resource_counts | |
| integration_status | |

## Resources Created

The following resources are created by this module:

- google_cloud_tasks_queue
- google_cloud_tasks_queue_iam_member
- google_cloud_tasks_task
- google_cloudfunctions_function
- google_logging_metric
- google_monitoring_alert_policy
- google_monitoring_dashboard
- google_project_iam_member
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
terraform import module.cloud-tasks.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:04 AM
Module Version: 1.0.0
