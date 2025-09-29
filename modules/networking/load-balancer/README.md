# Load-balancer Module

## Overview
This module manages load balancer resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "load-balancer" {
  source = "../../modules/networking/load-balancer"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "load-balancer_advanced" {
  source = "../../modules/networking/load-balancer"

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
    module      = "load-balancer"
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
| global_ip_name | | string | | yes |
| health_check_name | | string | | yes |
| backend_service_name | | string | | yes |
| url_map_name | | string | | yes |
| forwarding_rule_name | | string | | yes |
| backend_regions | | string | | yes |
| backend_instance_groups | | string | | yes |
| auto_create_instance_groups | | string | | yes |
| instance_group_config | | string | | yes |
| health_check_config | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| global_ip_address | |
| global_ip_id | |
| health_check_id | |
| health_check_self_link | |
| backend_service_id | |
| backend_service_self_link | |
| url_map_id | |
| url_map_self_link | |
| target_http_proxy_id | |
| target_http_proxy_self_link | |
| forwarding_rule_id | |
| forwarding_rule_self_link | |
| load_balancer_ip | |
| instance_groups | |
| instance_templates | |
| backend_groups_mapping | |
| data_instance_groups | |
| load_balancer_url | |
| backend_service_configuration | |
| health_check_configuration | |

## Resources Created

The following resources are created by this module:

- google_compute_backend_service
- google_compute_global_address
- google_compute_global_forwarding_rule
- google_compute_health_check
- google_compute_instance_template
- google_compute_region_instance_group_manager
- google_compute_target_http_proxy
- google_compute_url_map

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
terraform import module.load-balancer.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:22 AM
Module Version: 1.0.0
