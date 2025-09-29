# Cloud-nat Module

## Overview
This module manages cloud nat resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "cloud-nat" {
  source = "../../modules/networking/cloud-nat"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "cloud-nat_advanced" {
  source = "../../modules/networking/cloud-nat"

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
    module      = "cloud-nat"
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
| cloud_routers | | string | | yes |
| nat_gateways | | string | | yes |
| nat_ip_addresses | | string | | yes |
| router_interfaces | | string | | yes |
| bgp_peers | | string | | yes |
| custom_routes | | string | | yes |
| firewall_rules | | string | | yes |
| create_service_account | | string | | yes |
| service_account_name | | string | | yes |
| grant_service_account_roles | | string | | yes |
| service_account_roles | | string | | yes |
| create_monitoring_alerts | | string | | yes |
| monitoring_alerts | | string | | yes |
| create_monitoring_dashboard | | string | | yes |
| enable_log_export | | string | | yes |
| log_export_destination | | string | | yes |
| log_export_filter | | string | | yes |
| log_export_use_partitioned_tables | | string | | yes |
| create_log_metrics | | string | | yes |
| log_metrics | | string | | yes |
| labels | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| router_ids | |
| router_names | |
| router_self_links | |
| router_creation_timestamps | |
| nat_gateway_ids | |
| nat_gateway_names | |
| nat_ip_addresses | |
| nat_ip_ids | |
| nat_ip_names | |
| nat_ip_self_links | |
| nat_ip_users | |
| nat_ip_network_tiers | |
| nat_ip_creation_timestamps | |
| router_interface_ids | |
| router_interface_names | |
| bgp_peer_ids | |
| bgp_peer_names | |
| bgp_peer_ip_addresses | |
| bgp_peer_management_types | |
| custom_route_ids | |
| custom_route_names | |
| custom_route_self_links | |
| custom_route_next_hop_networks | |
| firewall_rule_ids | |
| firewall_rule_names | |
| firewall_rule_self_links | |
| firewall_rule_creation_timestamps | |
| service_account_email | |
| service_account_id | |
| service_account_name | |
| service_account_member | |
| monitoring_alert_policy_ids | |
| monitoring_alert_policy_names | |
| monitoring_dashboard_id | |
| log_sink_id | |
| log_sink_destination | |
| log_sink_writer_identity | |
| log_metric_ids | |
| log_metric_names | |
| nat_configuration_summary | |
| router_configuration_summary | |
| bgp_configuration_summary | |
| network_configuration_summary | |
| ip_address_summary | |
| port_allocation_summary | |
| timeout_configuration_summary | |
| security_configuration_summary | |
| monitoring_configuration_summary | |
| connection_info | |
| module_configuration | |
| applied_labels | |
| resource_counts | |

## Resources Created

The following resources are created by this module:

- google_compute_address
- google_compute_firewall
- google_compute_route
- google_compute_router
- google_compute_router_interface
- google_compute_router_nat
- google_compute_router_peer
- google_logging_metric
- google_logging_project_sink
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
terraform import module.cloud-nat.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:21 AM
Module Version: 1.0.0
