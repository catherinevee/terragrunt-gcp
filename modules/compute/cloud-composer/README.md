# Cloud-composer Module

## Overview
This module manages cloud composer resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "cloud-composer" {
  source = "../../modules/compute/cloud-composer"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "cloud-composer_advanced" {
  source = "../../modules/compute/cloud-composer"

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
    module      = "cloud-composer"
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
| name_prefix | | string | | yes |
| environment_config | | string | | yes |
| software_config | | string | | yes |
| node_config | | string | | yes |
| network_name | | string | | yes |
| subnetwork_name | | string | | yes |
| enable_private_environment | | string | | yes |
| private_cluster_config | | string | | yes |
| cloud_sql_ipv4_cidr_block | | string | | yes |
| composer_network_ipv4_cidr_block | | string | | yes |
| enable_privately_used_public_ips | | string | | yes |
| composer_connection_subnetwork | | string | | yes |
| web_server_network_access_control | | string | | yes |
| enable_database_config | | string | | yes |
| database_config | | string | | yes |
| enable_web_server_config | | string | | yes |
| web_server_config | | string | | yes |
| encryption_config | | string | | yes |
| environment_size | | string | | yes |
| enable_workloads_config | | string | | yes |
| create_service_account | | string | | yes |
| service_account_name | | string | | yes |
| node_service_account | | string | | yes |
| grant_service_account_roles | | string | | yes |
| service_account_roles | | string | | yes |
| create_composer_bucket | | string | | yes |
| bucket_lifecycle_age_days | | string | | yes |
| airflow_config_overrides | | string | | yes |
| pypi_packages | | string | | yes |
| env_variables | | string | | yes |
| environment_iam_bindings | | string | | yes |
| dags_bucket_iam_bindings | | string | | yes |
| maintenance_window | | string | | yes |
| create_monitoring_alerts | | string | | yes |
| monitoring_alerts | | string | | yes |
| create_monitoring_dashboard | | string | | yes |
| create_log_metrics | | string | | yes |
| log_metrics | | string | | yes |
| create_timeout | | string | | yes |
| update_timeout | | string | | yes |
| delete_timeout | | string | | yes |
| enable_cloud_data_lineage | | string | | yes |
| enable_triggers | | string | | yes |
| enable_deferrable_operators | | string | | yes |
| high_availability_config | | string | | yes |
| security_config | | string | | yes |
| performance_config | | string | | yes |
| cost_optimization_config | | string | | yes |
| data_processing_config | | string | | yes |
| labels | | string | | yes |
| lifecycle_config | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| environment_id | |
| environment_name | |
| environment_state | |
| environment_uuid | |
| airflow_uri | |
| dag_gcs_prefix | |
| gke_cluster | |
| node_config | |
| software_config | |
| private_environment_config | |
| database_config | |
| web_server_config | |
| encryption_config | |
| workloads_config | |
| maintenance_window | |
| network | |
| subnetwork | |
| service_account_email | |
| service_account_id | |
| service_account_name | |
| service_account_member | |
| node_service_account | |
| composer_bucket_name | |
| composer_bucket_url | |
| composer_bucket_self_link | |
| monitoring_alert_policy_ids | |
| monitoring_alert_policy_names | |
| monitoring_dashboard_id | |
| log_metric_names | |
| log_metric_ids | |
| iam_members | |
| dags_bucket_iam_members | |
| environment_details | |
| gke_cluster_info | |
| software_info | |
| security_info | |
| network_info | |
| connection_info | |
| configuration_summary | |
| performance_summary | |
| cost_summary | |
| module_configuration | |
| applied_labels | |
| resource_counts | |
| deployment_status | |

## Resources Created

The following resources are created by this module:

- google_composer_environment
- google_logging_metric
- google_monitoring_alert_policy
- google_monitoring_dashboard
- google_project_iam_member
- google_project_service
- google_service_account
- google_storage_bucket
- google_storage_bucket_iam_member
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
terraform import module.cloud-composer.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:01 AM
Module Version: 1.0.0
