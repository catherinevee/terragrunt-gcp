# Cloud-run Module

## Overview
This module manages cloud run resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "cloud-run" {
  source = "../../modules/compute/cloud-run"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "cloud-run_advanced" {
  source = "../../modules/compute/cloud-run"

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
    module      = "cloud-run"
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
| service_name | | string | | yes |
| name_prefix | | string | | yes |
| description | | string | | yes |
| deploy_service | | string | | yes |
| ingress | | string | | yes |
| launch_stage | | string | | yes |
| binary_authorization | | string | | yes |
| binary_authorization_breakglass | | string | | yes |
| container_image | | string | | yes |
| container_name | | string | | yes |
| container_command | | string | | yes |
| container_args | | string | | yes |
| container_working_dir | | string | | yes |
| container_port | | string | | yes |
| cpu_limit | | string | | yes |
| memory_limit | | string | | yes |
| cpu_idle | | string | | yes |
| startup_cpu_boost | | string | | yes |
| timeout | | string | | yes |
| min_instances | | string | | yes |
| max_instances | | string | | yes |
| max_concurrency | | string | | yes |
| execution_environment | | string | | yes |
| session_affinity | | string | | yes |
| vpc_connector | | string | | yes |
| vpc_egress | | string | | yes |
| vpc_network | | string | | yes |
| vpc_subnetwork | | string | | yes |
| vpc_network_tags | | string | | yes |
| service_account_email | | string | | yes |
| create_service_account | | string | | yes |
| service_account_name | | string | | yes |
| create_service_account_key | | string | | yes |
| grant_service_account_roles | | string | | yes |
| service_account_roles | | string | | yes |
| encryption_key | | string | | yes |
| allow_public_access | | string | | yes |
| invoker_members | | string | | yes |
| environment_variables | | string | | yes |
| secret_environment_variables | | string | | yes |
| volumes | | string | | yes |
| startup_probe | | string | | yes |
| liveness_probe | | string | | yes |
| traffic_percent | | string | | yes |
| traffic_revision | | string | | yes |
| traffic_tag | | string | | yes |
| domain_name | | string | | yes |
| certificate_mode | | string | | yes |
| force_domain_override | | string | | yes |
| deploy_job | | string | | yes |
| job_name | | string | | yes |
| job_parallelism | | string | | yes |
| job_task_count | | string | | yes |
| job_task_timeout | | string | | yes |
| job_max_retries | | string | | yes |
| job_container_command | | string | | yes |
| job_container_args | | string | | yes |
| job_cpu_limit | | string | | yes |
| job_memory_limit | | string | | yes |
| create_job_scheduler | | string | | yes |
| job_scheduler_name | | string | | yes |
| job_scheduler_schedule | | string | | yes |
| job_scheduler_description | | string | | yes |
| job_scheduler_time_zone | | string | | yes |
| job_scheduler_attempt_deadline | | string | | yes |
| job_scheduler_retry_count | | string | | yes |
| job_scheduler_max_retry_duration | | string | | yes |
| job_scheduler_min_backoff_duration | | string | | yes |
| job_scheduler_max_backoff_duration | | string | | yes |
| job_scheduler_max_doublings | | string | | yes |
| create_monitoring_alerts | | string | | yes |
| monitoring_alerts | | string | | yes |
| create_monitoring_dashboard | | string | | yes |
| ignore_service_changes | | string | | yes |
| ignore_job_changes | | string | | yes |
| ignore_domain_changes | | string | | yes |
| create_before_destroy | | string | | yes |
| labels | | string | | yes |
| annotations | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| service_name | |
| service_id | |
| service_uri | |
| service_url | |
| service_status | |
| service_latest_revision | |
| service_latest_created_revision | |
| service_generation | |
| service_observed_generation | |
| service_reconciling | |
| service_etag | |
| service_update_time | |
| service_create_time | |
| job_name | |
| job_id | |
| job_generation | |
| job_observed_generation | |
| job_etag | |
| job_latest_created_execution | |
| service_account_email | |
| service_account_name | |
| service_account_key | |
| domain_name | |
| domain_status | |
| domain_mapped_route | |
| domain_resource_records | |
| job_scheduler_name | |
| job_scheduler_id | |
| monitoring_dashboard_id | |
| monitoring_alert_policies | |
| console_urls | |
| gcloud_commands | |
| curl_commands | |
| import_commands | |
| labels | |

## Resources Created

The following resources are created by this module:

- google_cloud_run_domain_mapping
- google_cloud_run_v2_job
- google_cloud_run_v2_service
- google_cloud_run_v2_service_iam_binding
- google_cloud_run_v2_service_iam_member
- google_cloud_scheduler_job
- google_monitoring_alert_policy
- google_monitoring_dashboard
- google_project_iam_member
- google_service_account
- google_service_account_key

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
terraform import module.cloud-run.RESOURCE_TYPE.NAME RESOURCE_ID
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
