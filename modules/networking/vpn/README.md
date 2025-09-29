# Vpn Module

## Overview
This module manages vpn resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "vpn" {
  source = "../../modules/networking/vpn"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "vpn_advanced" {
  source = "../../modules/networking/vpn"

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
    module      = "vpn"
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
| ha_vpn_gateways | | string | | yes |
| classic_vpn_gateways | | string | | yes |
| external_vpn_gateways | | string | | yes |
| vpn_tunnels | | string | | yes |
| routers | | string | | yes |
| router_interfaces | | string | | yes |
| bgp_peers | | string | | yes |
| static_routes | | string | | yes |
| firewall_rules | | string | | yes |
| reserved_ip_addresses | | string | | yes |
| create_service_account | | string | | yes |
| service_account_name | | string | | yes |
| grant_service_account_roles | | string | | yes |
| service_account_roles | | string | | yes |
| shared_secret_length | | string | | yes |
| store_secrets_in_secret_manager | | string | | yes |
| secret_replication_regions | | string | | yes |
| create_monitoring_alerts | | string | | yes |
| monitoring_alerts | | string | | yes |
| create_monitoring_dashboard | | string | | yes |
| create_log_metrics | | string | | yes |
| log_metrics | | string | | yes |
| ha_vpn_config | | string | | yes |
| performance_config | | string | | yes |
| security_config | | string | | yes |
| compliance_config | | string | | yes |
| dr_config | | string | | yes |
| labels | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| ha_vpn_gateway_ids | |
| ha_vpn_gateway_names | |
| ha_vpn_gateway_self_links | |
| ha_vpn_gateway_vpn_interfaces | |
| classic_vpn_gateway_ids | |
| classic_vpn_gateway_names | |
| classic_vpn_gateway_self_links | |
| classic_vpn_gateway_creation_timestamps | |
| external_vpn_gateway_ids | |
| external_vpn_gateway_names | |
| external_vpn_gateway_self_links | |
| external_vpn_gateway_redundancy_types | |
| vpn_tunnel_ids | |
| vpn_tunnel_names | |
| vpn_tunnel_self_links | |
| vpn_tunnel_creation_timestamps | |
| vpn_tunnel_tunnel_ids | |
| vpn_tunnel_gateway_ips | |
| vpn_tunnel_peer_ips | |
| vpn_tunnel_ike_versions | |
| vpn_tunnel_detailed_statuses | |
| vpn_tunnel_shared_secret_hashes | |
| router_ids | |
| router_names | |
| router_self_links | |
| router_creation_timestamps | |
| router_interface_ids | |
| router_interface_names | |
| router_interface_ip_ranges | |
| bgp_peer_ids | |
| bgp_peer_names | |
| bgp_peer_ip_addresses | |
| bgp_peer_peer_ip_addresses | |
| bgp_peer_peer_asns | |
| bgp_peer_management_types | |
| static_route_ids | |
| static_route_names | |
| static_route_self_links | |
| static_route_dest_ranges | |
| static_route_next_hop_vpn_tunnels | |
| firewall_rule_ids | |
| firewall_rule_names | |
| firewall_rule_self_links | |
| firewall_rule_creation_timestamps | |
| reserved_ip_addresses | |
| reserved_ip_ids | |
| reserved_ip_names | |
| reserved_ip_self_links | |
| reserved_ip_users | |
| service_account_email | |
| service_account_id | |
| service_account_name | |
| service_account_member | |
| monitoring_alert_policy_ids | |
| monitoring_alert_policy_names | |
| monitoring_dashboard_id | |
| log_metric_ids | |
| log_metric_names | |
| vpn_secret_ids | |
| vpn_secret_names | |
| vpn_configuration_summary | |
| router_configuration_summary | |
| redundancy_configuration_summary | |
| network_configuration_summary | |
| ha_configuration_summary | |
| performance_configuration_summary | |
| security_configuration_summary | |
| compliance_configuration_summary | |
| dr_configuration_summary | |
| monitoring_configuration_summary | |
| connection_info | |
| module_configuration | |
| applied_labels | |
| resource_counts | |

## Resources Created

The following resources are created by this module:

- google_compute_address
- google_compute_external_vpn_gateway
- google_compute_firewall
- google_compute_ha_vpn_gateway
- google_compute_route
- google_compute_router
- google_compute_router_interface
- google_compute_router_peer
- google_compute_vpn_gateway
- google_compute_vpn_tunnel
- google_logging_metric
- google_monitoring_alert_policy
- google_monitoring_dashboard
- google_project_iam_member
- google_project_service
- google_secret_manager_secret
- google_secret_manager_secret_version
- google_service_account
- random_password

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
terraform import module.vpn.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:24 AM
Module Version: 1.0.0
