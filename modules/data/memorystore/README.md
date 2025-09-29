# Memorystore Module

## Overview
This module manages memorystore resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "memorystore" {
  source = "../../modules/data/memorystore"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "memorystore_advanced" {
  source = "../../modules/data/memorystore"

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
    module      = "memorystore"
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
| network_name | | string | | yes |
| subnetwork_name | | string | | yes |
| location_id | | string | | yes |
| alternative_location_id | | string | | yes |
| enable_private_service_access | | string | | yes |
| private_ip_prefix_length | | string | | yes |
| redis_instances | | string | | yes |
| memcached_instances | | string | | yes |
| create_service_account | | string | | yes |
| service_account_name | | string | | yes |
| grant_service_account_roles | | string | | yes |
| service_account_roles | | string | | yes |
| create_firewall_rules | | string | | yes |
| allowed_source_ranges | | string | | yes |
| firewall_target_tags | | string | | yes |
| redis_iam_bindings | | string | | yes |
| create_monitoring_alerts | | string | | yes |
| monitoring_alerts | | string | | yes |
| create_monitoring_dashboard | | string | | yes |
| create_log_metrics | | string | | yes |
| log_metrics | | string | | yes |
| enable_redis_backups | | string | | yes |
| redis_backup_configs | | string | | yes |
| enable_automated_backups | | string | | yes |
| backup_functions | | string | | yes |
| high_availability_config | | string | | yes |
| security_config | | string | | yes |
| performance_config | | string | | yes |
| scaling_config | | string | | yes |
| maintenance_config | | string | | yes |
| connection_config | | string | | yes |
| cost_optimization_config | | string | | yes |
| disaster_recovery_config | | string | | yes |
| compliance_config | | string | | yes |
| labels | | string | | yes |
| enable_import_export | | string | | yes |
| enable_pub_sub_notifications | | string | | yes |
| enable_stackdriver_integration | | string | | yes |
| multi_region_config | | string | | yes |
| lifecycle_config | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| redis_instance_ids | |
| redis_instance_names | |
| redis_instance_hosts | |
| redis_instance_ports | |
| redis_instance_current_location_ids | |
| redis_instance_memory_sizes | |
| redis_instance_persistence_iam_identity | |
| redis_instance_server_ca_certs | |
| redis_instance_auth_strings | |
| redis_instance_read_endpoint | |
| redis_instance_read_endpoint_port | |
| memcached_instance_ids | |
| memcached_instance_names | |
| memcached_instance_discovery_endpoint | |
| memcached_instance_memcache_full_version | |
| memcached_instance_memcache_nodes | |
| service_account_email | |
| service_account_id | |
| service_account_name | |
| service_account_member | |
| private_ip_address | |
| private_ip_address_name | |
| vpc_connection_service | |
| vpc_connection_network | |
| firewall_rule_id | |
| firewall_rule_name | |
| firewall_rule_self_link | |
| backup_bucket_names | |
| backup_bucket_urls | |
| backup_bucket_self_links | |
| backup_function_ids | |
| backup_function_names | |
| backup_function_sources | |
| monitoring_alert_policy_ids | |
| monitoring_alert_policy_names | |
| monitoring_dashboard_id | |
| log_metric_names | |
| log_metric_ids | |
| iam_members | |
| redis_connection_info | |
| memcached_connection_info | |
| redis_configurations | |
| memcached_configurations | |
| security_summary | |
| performance_summary | |
| high_availability_summary | |
| backup_summary | |
| module_configuration | |
| applied_labels | |
| resource_counts | |
| cost_summary | |

## Resources Created

The following resources are created by this module:

- google_cloudfunctions_function
- google_compute_firewall
- google_compute_global_address
- google_logging_metric
- google_memcache_instance
- google_monitoring_alert_policy
- google_monitoring_dashboard
- google_project_iam_member
- google_project_service
- google_redis_instance
- google_redis_instance_iam_member
- google_service_account
- google_service_networking_connection
- google_storage_bucket

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
terraform import module.memorystore.RESOURCE_TYPE.NAME RESOURCE_ID
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
