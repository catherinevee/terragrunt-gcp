# Api-gateway Module

## Overview
This module manages api gateway resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "api-gateway" {
  source = "../../modules/networking/api-gateway"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "api-gateway_advanced" {
  source = "../../modules/networking/api-gateway"

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
    module      = "api-gateway"
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
| create_api | | string | | yes |
| api_name | | string | | yes |
| name_prefix | | string | | yes |
| display_name | | string | | yes |
| deploy_config | | string | | yes |
| config_name | | string | | yes |
| config_display_name | | string | | yes |
| openapi_spec_path | | string | | yes |
| openapi_spec_inline | | string | | yes |
| deploy_gateway | | string | | yes |
| gateway_name | | string | | yes |
| gateway_display_name | | string | | yes |
| gateway_config | | string | | yes |
| create_service_account | | string | | yes |
| service_account_name | | string | | yes |
| grant_service_account_roles | | string | | yes |
| service_account_roles | | string | | yes |
| managed_service_configs | | string | | yes |
| grpc_services | | string | | yes |
| grpc_service_configs | | string | | yes |
| create_endpoints_service | | string | | yes |
| endpoints_service_name | | string | | yes |
| endpoints_grpc_config | | string | | yes |
| endpoints_protoc_output | | string | | yes |
| backend_services | | string | | yes |
| api_iam_bindings | | string | | yes |
| gateway_iam_bindings | | string | | yes |
| endpoints_iam_bindings | | string | | yes |
| create_monitoring_alerts | | string | | yes |
| monitoring_alerts | | string | | yes |
| create_monitoring_dashboard | | string | | yes |
| ignore_config_changes | | string | | yes |
| labels | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| api_id | |
| api_name | |
| api_managed_service | |
| config_id | |
| config_name | |
| config_service_name | |
| gateway_id | |
| gateway_name | |
| gateway_url | |
| gateway_default_hostname | |
| service_account_email | |
| service_account_id | |
| service_account_name | |
| service_account_member | |
| endpoints_service_name | |
| endpoints_config_id | |
| endpoints_dns_address | |
| endpoints_apis | |
| endpoints_endpoints | |
| backend_service_ids | |
| backend_service_self_links | |
| backend_service_fingerprints | |
| backend_service_generated_ids | |
| monitoring_dashboard_id | |
| monitoring_alert_policy_ids | |
| monitoring_alert_policy_names | |
| api_iam_members | |
| gateway_iam_members | |
| endpoints_iam_members | |
| openapi_config | |
| grpc_config | |
| managed_services | |
| api_labels | |
| gateway_labels | |
| api_gateway_module_version | |
| region | |
| project_id | |
| environment | |

## Resources Created

The following resources are created by this module:

- google_api_gateway_api
- google_api_gateway_api_config
- google_api_gateway_api_iam_binding
- google_api_gateway_gateway
- google_api_gateway_gateway_iam_binding
- google_compute_backend_service
- google_endpoints_service
- google_endpoints_service_iam_binding
- google_monitoring_alert_policy
- google_monitoring_dashboard
- google_project_iam_member
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
terraform import module.api-gateway.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:18 AM
Module Version: 1.0.0
