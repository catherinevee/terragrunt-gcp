# Cloud-monitoring Module

## Overview
This module manages cloud monitoring resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "cloud-monitoring" {
  source = "../../modules/monitoring/cloud-monitoring"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "cloud-monitoring_advanced" {
  source = "../../modules/monitoring/cloud-monitoring"

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
    module      = "cloud-monitoring"
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
| environment | | string | | yes |
| alert_policies | | string | | yes |
| monitoring_services | | string | | yes |
| slos | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| dashboard_ids | |
| dashboard_names | |
| alert_policy_ids | |
| alert_policy_names | |
| alert_policy_enabled_status | |
| notification_channel_ids | |
| notification_channel_names | |
| notification_channel_types | |
| uptime_check_ids | |
| uptime_check_names | |
| uptime_check_monitored_resources | |
| custom_metric_descriptors | |
| custom_metric_types | |
| slo_ids | |
| slo_names | |
| slo_goals | |
| service_ids | |
| service_names | |
| service_telemetry | |
| group_ids | |
| group_names | |
| group_filters | |
| custom_service_ids | |
| workspace_id | |
| project_id | |
| monitoring_scope | |
| alert_policy_documentation | |
| notification_channel_labels | |
| notification_channel_verification_status | |
| dashboard_json_configs | |
| log_metric_ids | |
| log_metric_filters | |
| synthetic_monitor_ids | |
| incident_policies | |
| monitoring_channels_summary | |
| alerting_rules_count | |
| uptime_checks_count | |
| dashboards_count | |
| enabled_apis | |

## Resources Created

The following resources are created by this module:

- google_monitoring_alert_policy
- google_monitoring_service
- google_monitoring_slo
- google_project_service

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
terraform import module.cloud-monitoring.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:17 AM
Module Version: 1.0.0
