# Dataflow Module

## Overview
This module manages dataflow resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "dataflow" {
  source = "../../modules/data/dataflow"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "dataflow_advanced" {
  source = "../../modules/data/dataflow"

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
    module      = "dataflow"
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
| zone | | string | | yes |
| environment | | string | | yes |
| job_name | | string | | yes |
| name_prefix | | string | | yes |
| job_description | | string | | yes |
| template_type | | string | | yes |
| deploy_job | | string | | yes |
| is_streaming_job | | string | | yes |
| template_gcs_path | | string | | yes |
| classic_template_location | | string | | yes |
| flex_template_spec_path | | string | | yes |
| flex_template_bucket | | string | | yes |
| create_flex_template_spec | | string | | yes |
| container_image | | string | | yes |
| sdk_language | | string | | yes |
| flex_template_metadata | | string | | yes |
| flex_template_spec | | string | | yes |
| parameter_metadata | | string | | yes |
| flex_template_parameters | | string | | yes |
| python_pipeline_path | | string | | yes |
| python_setup_file | | string | | yes |
| python_requirements_file | | string | | yes |
| python_save_main_session | | string | | yes |
| python_sdk_container_image | | string | | yes |
| python_sdk_harness_overrides | | string | | yes |
| python_pipeline_options | | string | | yes |
| python_environment_vars | | string | | yes |
| google_credentials_path | | string | | yes |
| sql_query | | string | | yes |
| sql_output_table | | string | | yes |
| sql_bigquery_project | | string | | yes |
| sql_bigquery_dataset | | string | | yes |
| sql_temp_directory | | string | | yes |
| sql_output_table_spec | | string | | yes |
| sql_input_subscription | | string | | yes |
| sql_output_topic | | string | | yes |
| sql_udf_gcs_path | | string | | yes |
| sql_udf_function_name | | string | | yes |
| machine_type | | string | | yes |
| initial_workers | | string | | yes |
| max_workers | | string | | yes |
| disk_type | | string | | yes |
| disk_size_gb | | string | | yes |
| worker_region | | string | | yes |
| worker_zone | | string | | yes |
| launcher_machine_type | | string | | yes |
| network | | string | | yes |
| subnetwork | | string | | yes |
| use_public_ips | | string | | yes |
| ip_configuration | | string | | yes |
| create_firewall_rules | | string | | yes |
| temp_location | | string | | yes |
| staging_location | | string | | yes |
| create_staging_bucket | | string | | yes |
| staging_bucket_name | | string | | yes |
| staging_bucket_force_destroy | | string | | yes |
| staging_bucket_lifecycle_days | | string | | yes |
| create_temp_bucket | | string | | yes |
| temp_bucket_name | | string | | yes |
| temp_bucket_force_destroy | | string | | yes |
| temp_bucket_lifecycle_days | | string | | yes |
| service_account_email | | string | | yes |
| create_service_account | | string | | yes |
| service_account_name | | string | | yes |
| create_service_account_key | | string | | yes |
| create_service_account_roles | | string | | yes |
| grant_bigquery_access | | string | | yes |
| grant_pubsub_access | | string | | yes |
| kms_key_name | | string | | yes |
| enable_kerberos | | string | | yes |
| enable_streaming_engine | | string | | yes |
| enable_streaming_update | | string | | yes |
| update_compatibility_version | | string | | yes |
| transform_name_mapping | | string | | yes |
| enable_autoscaling | | string | | yes |
| autoscaling_algorithm | | string | | yes |
| enable_flexrs_goal | | string | | yes |
| on_delete_action | | string | | yes |
| skip_wait_on_job_termination | | string | | yes |
| ignore_job_changes | | string | | yes |
| parameters | | string | | yes |
| labels | | string | | yes |
| additional_experiments | | string | | yes |
| create_monitoring_alerts | | string | | yes |
| monitoring_alerts | | string | | yes |
| create_monitoring_dashboard | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| job_name | |
| job_id | |
| job_state | |
| job_type | |
| template_type | |
| region | |
| project_id | |
| classic_job_details | |
| flex_job_details | |
| sql_job_details | |
| python_job_details | |
| staging_bucket_name | |
| staging_bucket_url | |
| temp_bucket_name | |
| temp_bucket_url | |
| staging_location | |
| temp_location | |
| flex_template_spec_path | |
| flex_template_spec | |
| service_account_email | |
| service_account_name | |
| service_account_key | |
| network | |
| subnetwork | |
| ip_configuration | |
| firewall_rules | |
| monitoring_alert_policies | |
| monitoring_dashboard_id | |
| labels | |
| console_urls | |
| gcloud_commands | |
| job_parameters | |
| metrics_queries | |
| import_commands | |

## Resources Created

The following resources are created by this module:

- google_compute_firewall
- google_dataflow_flex_template_job
- google_dataflow_job
- google_monitoring_alert_policy
- google_monitoring_dashboard
- google_project_iam_member
- google_service_account
- google_service_account_key
- google_storage_bucket
- google_storage_bucket_object
- null_resource
- random_id

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
terraform import module.dataflow.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:08 AM
Module Version: 1.0.0
