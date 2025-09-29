# Cloud-logging Module

## Overview
This module manages cloud logging resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "cloud-logging" {
  source = "../../modules/monitoring/cloud-logging"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "cloud-logging_advanced" {
  source = "../../modules/monitoring/cloud-logging"

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
    module      = "cloud-logging"
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
| log_sinks | | string | | yes |
| log_exclusions | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| log_sink_id | |
| log_sink_name | |
| log_sink_destination | |
| log_sink_writer_identity | |
| log_metric_ids | |
| log_metric_names | |
| log_view_ids | |
| log_view_names | |
| log_bucket_id | |
| log_bucket_name | |
| log_bucket_location | |
| log_bucket_lifecycle_state | |
| log_bucket_retention_days | |
| log_bucket_locked | |
| log_exclusion_ids | |
| log_exclusion_names | |
| log_router_sink_ids | |
| organization_sink_ids | |
| billing_account_sink_ids | |
| custom_log_scopes | |
| log_sink_filter | |
| log_sink_bigquery_options | |
| log_sink_exclusions | |
| project_id | |
| enabled_apis | |
| monitoring_notification_channels | |
| log_based_alert_policies | |
| cmek_settings | |
| audit_log_config | |
| export_destinations | |

## Resources Created

The following resources are created by this module:

- google_logging_project_exclusion
- google_logging_project_sink
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
terraform import module.cloud-logging.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:16 AM
Module Version: 1.0.0
