# Cloud-endpoints Module

## Overview
This module manages cloud endpoints resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "cloud-endpoints" {
  source = "../../modules/networking/cloud-endpoints"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "cloud-endpoints_advanced" {
  source = "../../modules/networking/cloud-endpoints"

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
    module      = "cloud-endpoints"
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
| enable_apis | | string | | yes |
| create_service_account | | string | | yes |
| service_account_id | | string | | yes |
| service_account_roles | | string | | yes |
| managed_services | | string | | yes |
| openapi_services | | string | | yes |
| grpc_services | | string | | yes |
| api_keys | | string | | yes |
| enable_api_gateway | | string | | yes |
| api_gateway_configs | | string | | yes |
| authentication_config | | string | | yes |
| enable_quota | | string | | yes |
| quota_configs | | string | | yes |
| quota_overrides | | string | | yes |
| backend_deadline | | string | | yes |
| enable_monitoring | | string | | yes |
| create_dashboard | | string | | yes |
| dashboard_display_name | | string | | yes |
| enable_logging | | string | | yes |
| notification_channels | | string | | yes |
| alert_policies | | string | | yes |
| enable_controlled_rollout | | string | | yes |
| enable_vpc_service_controls | | string | | yes |
| vpc_service_perimeter_name | | string | | yes |
| vpc_access_levels | | string | | yes |
| service_iam_bindings | | string | | yes |
| consumer_iam_bindings | | string | | yes |
| labels | | string | | yes |
| enable_private_service_connect | | string | | yes |
| private_service_connect_config | | string | | yes |
| enable_cloud_trace | | string | | yes |
| trace_sampling_rate | | string | | yes |
| enable_cloud_profiler | | string | | yes |
| rate_limit_configs | | string | | yes |
| cors_configs | | string | | yes |
| backend_service_configs | | string | | yes |
| service_level_objectives | | string | | yes |
| custom_domain_mappings | | string | | yes |
| enable_request_validation | | string | | yes |
| request_validation_rules | | string | | yes |
| enable_response_compression | | string | | yes |
| compression_types | | string | | yes |
| enable_caching | | string | | yes |
| cache_configs | | string | | yes |
| webhook_configs | | string | | yes |
| enable_api_deprecation_warnings | | string | | yes |
| api_lifecycle_policies | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| service_names | |
| service_configs | |
| service_endpoints | |
| api_gateway_urls | |
| api_gateway_ids | |
| api_gateway_configs | |
| api_key_ids | |
| api_key_strings | |
| service_account_email | |
| service_account_id | |
| dashboard_url | |
| alert_policy_ids | |
| openapi_service_details | |
| grpc_service_details | |
| quota_overrides | |
| service_iam_bindings | |
| consumer_iam_bindings | |
| configuration_metadata | |
| management_urls | |
| service_discovery | |
| rollout_status | |
| security_configuration | |

## Resources Created

The following resources are created by this module:

- google_access_context_manager_service_perimeter_resource
- google_api_gateway_api
- google_api_gateway_api_config
- google_api_gateway_gateway
- google_apikeys_key
- google_endpoints_service
- google_endpoints_service_consumers_iam_binding
- google_endpoints_service_iam_binding
- google_endpoints_service_iam_member
- google_monitoring_alert_policy
- google_monitoring_dashboard
- google_project_iam_member
- google_project_service
- google_service_account
- google_service_management_consumer_quota_override

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
terraform import module.cloud-endpoints.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:19 AM
Module Version: 1.0.0
