# App-engine Module

## Overview
This module manages app engine resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "app-engine" {
  source = "../../modules/compute/app-engine"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "app-engine_advanced" {
  source = "../../modules/compute/app-engine"

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
    module      = "app-engine"
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
| create_application | | string | | yes |
| app_id | | string | | yes |
| auth_domain | | string | | yes |
| serving_status | | string | | yes |
| database_type | | string | | yes |
| feature_settings | | string | | yes |
| service_name | | string | | yes |
| version_id | | string | | yes |
| deploy_version | | string | | yes |
| environment_type | | string | | yes |
| runtime | | string | | yes |
| runtime_channel | | string | | yes |
| instance_class | | string | | yes |
| scaling_type | | string | | yes |
| automatic_scaling | | string | | yes |
| automatic_scaling_flex | | string | | yes |
| manual_scaling | | string | | yes |
| manual_scaling_flex | | string | | yes |
| basic_scaling | | string | | yes |
| deployment_zip | | string | | yes |
| deployment_container | | string | | yes |
| deployment_files | | string | | yes |
| cloud_build_options | | string | | yes |
| resources | | string | | yes |
| network_name | | string | | yes |
| subnetwork_name | | string | | yes |
| instance_tag | | string | | yes |
| forwarded_ports | | string | | yes |
| session_affinity | | string | | yes |
| vpc_connector_name | | string | | yes |
| vpc_egress_setting | | string | | yes |
| entrypoint_shell | | string | | yes |
| env_variables | | string | | yes |
| beta_settings | | string | | yes |
| handlers | | string | | yes |
| libraries | | string | | yes |
| inbound_services | | string | | yes |
| liveness_check | | string | | yes |
| readiness_check | | string | | yes |
| endpoints_api_service | | string | | yes |
| api_config | | string | | yes |
| domain_mappings | | string | | yes |
| firewall_rules | | string | | yes |
| service_iam_members | | string | | yes |
| delete_service_on_destroy | | string | | yes |
| noop_on_destroy | | string | | yes |
| ignore_changes | | string | | yes |
| labels | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| app_id | |
| app_name | |
| app_location | |
| app_default_hostname | |
| app_default_bucket | |
| app_gcr_domain | |
| app_code_bucket | |
| app_serving_status | |
| standard_version_id | |
| standard_version_name | |
| standard_version_url | |
| flexible_version_id | |
| flexible_version_name | |
| flexible_version_url | |
| service_name | |
| service_url | |
| default_service_url | |
| runtime | |
| environment_type | |
| scaling_type | |
| domain_mappings | |
| firewall_rules | |
| console_urls | |
| gcloud_commands | |
| labels | |

## Resources Created

The following resources are created by this module:

- google_app_engine_application
- google_app_engine_domain_mapping
- google_app_engine_firewall_rule
- google_app_engine_flexible_app_version
- google_app_engine_standard_app_version

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
terraform import module.app-engine.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:00 AM
Module Version: 1.0.0
