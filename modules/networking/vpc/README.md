# Vpc Module

## Overview
This module manages vpc resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "vpc" {
  source = "../../modules/networking/vpc"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "vpc_advanced" {
  source = "../../modules/networking/vpc"

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
    module      = "vpc"
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
| network_name | | string | | yes |
| description | | string | | yes |
| auto_create_subnetworks | | string | | yes |
| routing_mode | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| network_id | |
| network_name | |
| network_self_link | |
| network_gateway_ipv4 | |
| network_project | |
| subnet_ids | |
| subnet_names | |
| subnet_self_links | |
| subnet_ip_cidr_ranges | |
| subnet_regions | |
| subnet_gateway_addresses | |
| subnet_secondary_ranges | |
| subnet_private_ip_google_access | |
| subnet_private_ipv6_google_access | |
| subnet_flow_logs_enabled | |
| router_ids | |
| router_names | |
| router_self_links | |
| router_regions | |
| nat_ids | |
| nat_names | |
| nat_ips | |
| nat_router_associations | |
| firewall_rule_ids | |
| firewall_rule_names | |
| firewall_rule_self_links | |
| route_ids | |
| route_names | |
| route_next_hops | |
| peering_connections | |
| shared_vpc_host_project | |
| shared_vpc_service_projects | |
| private_service_connection | |
| network_attachment_ids | |
| interconnect_attachments | |
| vpn_gateway_ids | |
| vpn_tunnel_ids | |
| network_connectivity_hub_id | |
| network_connectivity_spokes | |
| dns_policies | |
| network_tags | |
| auto_create_subnetworks | |
| routing_mode | |
| mtu | |
| delete_default_routes | |
| enable_ula_internal_ipv6 | |
| internal_ipv6_range | |

## Resources Created

The following resources are created by this module:

- google_compute_network
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
terraform import module.vpc.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:23 AM
Module Version: 1.0.0
