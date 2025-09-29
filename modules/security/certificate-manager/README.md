# Certificate-manager Module

## Overview
This module manages certificate manager resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "certificate-manager" {
  source = "../../modules/security/certificate-manager"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "certificate-manager_advanced" {
  source = "../../modules/security/certificate-manager"

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
    module      = "certificate-manager"
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
| certificates | | string | | yes |
| certificate_maps | | string | | yes |
| certificate_map_entries | | string | | yes |
| dns_authorizations | | string | | yes |
| certificate_issuance_configs | | string | | yes |
| trust_configs | | string | | yes |
| classic_ssl_certificates | | string | | yes |
| classic_managed_ssl_certificates | | string | | yes |
| ssl_policies | | string | | yes |
| target_https_proxies | | string | | yes |
| create_service_account | | string | | yes |
| service_account_name | | string | | yes |
| grant_service_account_roles | | string | | yes |
| service_account_roles | | string | | yes |
| create_monitoring_alerts | | string | | yes |
| monitoring_alerts | | string | | yes |
| create_monitoring_dashboard | | string | | yes |
| notification_channels | | string | | yes |
| enable_auto_rotation | | string | | yes |
| rotation_function_source_bucket | | string | | yes |
| rotation_function_source_object | | string | | yes |
| rotation_days_before_expiry | | string | | yes |
| rotation_schedule | | string | | yes |
| rotation_time_zone | | string | | yes |
| rotation_log_level | | string | | yes |
| validation_config | | string | | yes |
| compliance_config | | string | | yes |
| security_config | | string | | yes |
| rate_limiting_config | | string | | yes |
| cost_optimization_config | | string | | yes |
| labels | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| certificate_ids | |
| certificate_names | |
| certificate_create_times | |
| certificate_update_times | |
| certificate_expire_times | |
| certificate_san_dnsnames | |
| certificate_pem_certificates | |
| certificate_map_ids | |
| certificate_map_names | |
| certificate_map_create_times | |
| certificate_map_update_times | |
| certificate_map_gclb_targets | |
| certificate_map_entry_ids | |
| certificate_map_entry_names | |
| certificate_map_entry_create_times | |
| certificate_map_entry_update_times | |
| certificate_map_entry_states | |
| dns_authorization_ids | |
| dns_authorization_names | |
| dns_authorization_dns_resource_records | |
| certificate_issuance_config_ids | |
| certificate_issuance_config_names | |
| certificate_issuance_config_create_times | |
| certificate_issuance_config_update_times | |
| trust_config_ids | |
| trust_config_names | |
| trust_config_create_times | |
| trust_config_update_times | |
| classic_ssl_certificate_ids | |
| classic_ssl_certificate_names | |
| classic_ssl_certificate_self_links | |
| classic_ssl_certificate_creation_timestamps | |
| classic_ssl_certificate_expiration_timestamps | |
| classic_managed_ssl_certificate_ids | |
| classic_managed_ssl_certificate_names | |
| classic_managed_ssl_certificate_self_links | |
| classic_managed_ssl_certificate_creation_timestamps | |
| classic_managed_ssl_certificate_statuses | |
| classic_managed_ssl_certificate_domain_statuses | |
| ssl_policy_ids | |
| ssl_policy_names | |
| ssl_policy_self_links | |
| ssl_policy_fingerprints | |
| ssl_policy_enabled_features | |
| target_https_proxy_ids | |
| target_https_proxy_names | |
| target_https_proxy_self_links | |
| target_https_proxy_creation_timestamps | |
| target_https_proxy_proxy_ids | |
| service_account_email | |
| service_account_id | |
| service_account_name | |
| service_account_member | |
| monitoring_alert_policy_ids | |
| monitoring_alert_policy_names | |
| monitoring_dashboard_id | |
| notification_channel_ids | |
| notification_channel_names | |
| notification_channel_verification_statuses | |
| rotation_function_id | |
| rotation_function_uri | |
| rotation_schedule_id | |
| rotation_schedule_name | |
| certificate_configuration_summary | |
| ssl_policy_configuration_summary | |
| dns_authorization_summary | |
| certificate_expiry_summary | |
| validation_configuration_summary | |
| compliance_configuration_summary | |
| security_configuration_summary | |
| monitoring_configuration_summary | |
| rate_limiting_summary | |
| cost_optimization_summary | |
| connection_info | |
| module_configuration | |
| applied_labels | |
| resource_counts | |

## Resources Created

The following resources are created by this module:

- google_certificate_manager_certificate
- google_certificate_manager_certificate_issuance_config
- google_certificate_manager_certificate_map
- google_certificate_manager_certificate_map_entry
- google_certificate_manager_dns_authorization
- google_certificate_manager_trust_config
- google_cloud_scheduler_job
- google_cloudfunctions2_function
- google_compute_managed_ssl_certificate
- google_compute_ssl_certificate
- google_compute_ssl_policy
- google_compute_target_https_proxy
- google_monitoring_alert_policy
- google_monitoring_dashboard
- google_monitoring_notification_channel
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
terraform import module.certificate-manager.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:25 AM
Module Version: 1.0.0
