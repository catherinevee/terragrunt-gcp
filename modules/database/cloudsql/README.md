# Cloudsql Module

## Overview
This module manages cloudsql resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "cloudsql" {
  source = "../../modules/database/cloudsql"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "cloudsql_advanced" {
  source = "../../modules/database/cloudsql"

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
    module      = "cloudsql"
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
| name | | string | | yes |
| name_prefix | | string | | yes |
| region | | string | | yes |
| database_type | | string | | yes |
| database_version | | string | | yes |
| tier | | string | | yes |
| edition | | string | | yes |
| environment | | string | | yes |
| deletion_protection | | string | | yes |
| activation_policy | | string | | yes |
| availability_type | | string | | yes |
| collation | | string | | yes |
| connector_enforcement | | string | | yes |
| time_zone | | string | | yes |
| disk_autoresize | | string | | yes |
| disk_autoresize_limit | | string | | yes |
| disk_size | | string | | yes |
| disk_type | | string | | yes |
| pricing_plan | | string | | yes |
| database_charset | | string | | yes |
| database_collation | | string | | yes |
| database_deletion_policy | | string | | yes |
| database_flags | | string | | yes |
| additional_databases | | string | | yes |
| enable_default_user | | string | | yes |
| root_password | | string | | yes |
| additional_users | | string | | yes |
| backup_configuration | | string | | yes |
| ip_configuration | | string | | yes |
| authorized_networks | | string | | yes |
| require_ssl | | string | | yes |
| psc_config | | string | | yes |
| maintenance_window | | string | | yes |
| deny_maintenance_periods | | string | | yes |
| insights_config | | string | | yes |
| password_validation_policy | | string | | yes |
| sql_server_audit_config | | string | | yes |
| active_directory_config | | string | | yes |
| data_cache_config | | string | | yes |
| encryption_key_name | | string | | yes |
| master_instance_name | | string | | yes |
| replica_configuration | | string | | yes |
| read_replicas | | string | | yes |
| restore_backup_context | | string | | yes |
| clone_source | | string | | yes |
| labels | | string | | yes |
| create_timeout | | string | | yes |
| update_timeout | | string | | yes |
| delete_timeout | | string | | yes |
| ignore_changes_list | | string | | yes |
| ignore_default_location | | string | | yes |
| module_depends_on | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| instance_name | |
| instance_id | |
| instance_self_link | |
| instance_connection_name | |
| instance_service_account_email | |
| public_ip_address | |
| private_ip_address | |
| ip_addresses | |
| first_ip_address | |
| database_version | |
| database_type | |
| databases | |
| database_resources | |
| root_user | |
| root_password | |
| additional_users | |
| settings | |
| tier | |
| disk_size | |
| disk_type | |
| availability_type | |
| activation_policy | |
| backup_configuration | |
| backup_start_time | |
| point_in_time_recovery_enabled | |
| authorized_networks | |
| require_ssl | |
| private_network | |
| maintenance_window | |
| encryption_key_name | |
| read_replicas | |
| read_replica_connection_names | |
| read_replica_ips | |
| state | |
| maintenance_version | |
| insights_config | |
| labels | |
| connection_strings | |
| cloud_sql_proxy_command | |
| gcloud_commands | |
| console_urls | |

## Resources Created

The following resources are created by this module:

- google_sql_database
- google_sql_database_instance
- google_sql_user
- random_id
- random_password

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
terraform import module.cloudsql.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:13 AM
Module Version: 1.0.0
