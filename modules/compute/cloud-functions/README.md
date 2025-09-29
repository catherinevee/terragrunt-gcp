# Cloud-functions Module

## Overview
This module manages cloud functions resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "cloud-functions" {
  source = "../../modules/compute/cloud-functions"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "cloud-functions_advanced" {
  source = "../../modules/compute/cloud-functions"

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
    module      = "cloud-functions"
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
| function_name | | string | | yes |
| name_prefix | | string | | yes |
| description | | string | | yes |
| generation | | string | | yes |
| deploy_function | | string | | yes |
| runtime | | string | | yes |
| entry_point | | string | | yes |
| available_memory_mb | | string | | yes |
| available_cpu | | string | | yes |
| timeout | | string | | yes |
| max_instances_v1 | | string | | yes |
| min_instances_v1 | | string | | yes |
| max_instances_v2 | | string | | yes |
| min_instances_v2 | | string | | yes |
| max_instance_request_concurrency | | string | | yes |
| source_directory | | string | | yes |
| source_archive_path | | string | | yes |
| source_archive_bucket | | string | | yes |
| source_archive_object | | string | | yes |
| create_source_archive | | string | | yes |
| source_archive_excludes | | string | | yes |
| create_source_bucket | | string | | yes |
| source_bucket_name | | string | | yes |
| source_bucket_location | | string | | yes |
| source_bucket_storage_class | | string | | yes |
| source_bucket_force_destroy | | string | | yes |
| source_bucket_versioning | | string | | yes |
| source_bucket_lifecycle_days | | string | | yes |
| docker_registry | | string | | yes |
| docker_repository | | string | | yes |
| build_environment_variables | | string | | yes |
| build_worker_pool | | string | | yes |
| trigger_http | | string | | yes |
| event_trigger_config | | string | | yes |
| event_trigger_v2_config | | string | | yes |
| event_filters | | string | | yes |
| vpc_connector | | string | | yes |
| create_vpc_connector | | string | | yes |
| vpc_connector_name | | string | | yes |
| vpc_connector_network | | string | | yes |
| vpc_connector_ip_range | | string | | yes |
| vpc_connector_min_instances | | string | | yes |
| vpc_connector_max_instances | | string | | yes |
| vpc_connector_min_throughput | | string | | yes |
| vpc_connector_max_throughput | | string | | yes |
| vpc_connector_egress_settings | | string | | yes |
| ingress_settings_v1 | | string | | yes |
| ingress_settings_v2 | | string | | yes |
| all_traffic_on_latest_revision | | string | | yes |
| service_account_email | | string | | yes |
| create_service_account | | string | | yes |
| service_account_name | | string | | yes |
| create_service_account_key | | string | | yes |
| grant_service_account_roles | | string | | yes |
| service_account_roles | | string | | yes |
| kms_key_name | | string | | yes |
| allow_public_access | | string | | yes |
| invoker_members | | string | | yes |
| environment_variables | | string | | yes |
| secret_environment_variables | | string | | yes |
| secret_volumes | | string | | yes |
| create_scheduler_job | | string | | yes |
| scheduler_job_name | | string | | yes |
| scheduler_cron_schedule | | string | | yes |
| scheduler_description | | string | | yes |
| scheduler_time_zone | | string | | yes |
| scheduler_attempt_deadline | | string | | yes |
| scheduler_retry_count | | string | | yes |
| scheduler_max_retry_duration | | string | | yes |
| scheduler_min_backoff_duration | | string | | yes |
| scheduler_max_backoff_duration | | string | | yes |
| scheduler_max_doublings | | string | | yes |
| scheduler_http_method | | string | | yes |
| scheduler_http_headers | | string | | yes |
| scheduler_http_body | | string | | yes |
| scheduler_oidc_token | | string | | yes |
| scheduler_oauth_token | | string | | yes |
| scheduler_pubsub_target | | string | | yes |
| create_monitoring_alerts | | string | | yes |
| monitoring_alerts | | string | | yes |
| create_monitoring_dashboard | | string | | yes |
| create_budget_alert | | string | | yes |
| billing_account | | string | | yes |
| budget_amount | | string | | yes |
| budget_calendar_period | | string | | yes |
| budget_custom_period | | string | | yes |
| budget_threshold_rules | | string | | yes |
| budget_pubsub_topic | | string | | yes |
| budget_notification_channels | | string | | yes |
| budget_disable_default_recipients | | string | | yes |
| ignore_function_changes | | string | | yes |
| create_before_destroy | | string | | yes |
| labels | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| function_name | |
| function_id | |
| function_region | |
| function_project | |
| generation | |
| https_trigger_url | |
| trigger_url | |
| service_name | |
| service_config | |
| build_config | |
| state | |
| update_time | |
| source_bucket | |
| source_object | |
| source_bucket_url | |
| service_account_email | |
| service_account_name | |
| service_account_key | |
| vpc_connector_name | |
| vpc_connector_id | |
| event_trigger | |
| scheduler_job_name | |
| scheduler_job_id | |
| scheduler_schedule | |
| monitoring_dashboard_id | |
| monitoring_alert_policies | |
| budget_name | |
| labels | |
| console_urls | |
| gcloud_commands | |
| curl_commands | |
| import_commands | |

## Resources Created

The following resources are created by this module:

- google_billing_budget
- google_cloud_run_service_iam_binding
- google_cloud_run_service_iam_member
- google_cloud_scheduler_job
- google_cloudfunctions_function
- google_cloudfunctions_function_iam_binding
- google_cloudfunctions_function_iam_member
- google_cloudfunctions2_function
- google_monitoring_alert_policy
- google_monitoring_dashboard
- google_project_iam_member
- google_service_account
- google_service_account_key
- google_storage_bucket
- google_storage_bucket_object
- google_vpc_access_connector

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
terraform import module.cloud-functions.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:02 AM
Module Version: 1.0.0
