# Cloud-armor Module

## Overview
This module manages cloud armor resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "cloud-armor" {
  source = "../../modules/security/cloud-armor"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "cloud-armor_advanced" {
  source = "../../modules/security/cloud-armor"

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
    module      = "cloud-armor"
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
| security_policies | | string | | yes |
| edge_security_policies | | string | | yes |
| waf_exclusion_policies | | string | | yes |
| policy_attachments | | string | | yes |
| create_service_account | | string | | yes |
| service_account_name | | string | | yes |
| grant_service_account_roles | | string | | yes |
| service_account_roles | | string | | yes |
| create_monitoring_alerts | | string | | yes |
| monitoring_alerts | | string | | yes |
| create_monitoring_dashboard | | string | | yes |
| create_log_metrics | | string | | yes |
| log_metrics | | string | | yes |
| notification_channels | | string | | yes |
| create_security_response_functions | | string | | yes |
| security_response_functions | | string | | yes |
| enable_owasp_rules | | string | | yes |
| owasp_rule_sensitivity | | string | | yes |
| enable_ddos_protection | | string | | yes |
| enable_bot_management | | string | | yes |
| enable_rate_limiting | | string | | yes |
| default_rate_limit | | string | | yes |
| enable_geo_blocking | | string | | yes |
| blocked_countries | | string | | yes |
| allowed_countries | | string | | yes |
| ip_allowlists | | string | | yes |
| ip_blocklists | | string | | yes |
| advanced_security_config | | string | | yes |
| compliance_config | | string | | yes |
| integration_config | | string | | yes |
| labels | | string | | yes |
| lifecycle_config | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| security_policy_ids | |
| security_policy_names | |
| security_policy_self_links | |
| security_policy_fingerprints | |
| security_policy_types | |
| edge_security_policy_ids | |
| edge_security_policy_names | |
| edge_security_policy_self_links | |
| waf_exclusion_policy_ids | |
| waf_exclusion_policy_names | |
| waf_exclusion_policy_self_links | |
| backend_service_with_security_policy_ids | |
| backend_service_with_security_policy_names | |
| backend_service_security_policies | |
| service_account_email | |
| service_account_id | |
| service_account_name | |
| service_account_member | |
| monitoring_alert_policy_ids | |
| monitoring_alert_policy_names | |
| monitoring_dashboard_id | |
| log_metric_names | |
| log_metric_ids | |
| notification_channel_ids | |
| notification_channel_names | |
| security_response_function_ids | |
| security_response_function_names | |
| security_response_function_trigger_urls | |
| security_configuration_summary | |
| security_rules_summary | |
| ip_management_summary | |
| rate_limiting_summary | |
| security_monitoring_summary | |
| advanced_security_features | |
| waf_configuration_summary | |
| connection_info | |
| module_configuration | |
| applied_labels | |
| resource_counts | |
| cost_summary | |

## Resources Created

The following resources are created by this module:

- google_cloudfunctions_function
- google_compute_backend_service
- google_compute_security_policy
- google_logging_metric
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
terraform import module.cloud-armor.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:26 AM
Module Version: 1.0.0
