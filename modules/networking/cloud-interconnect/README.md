# Cloud-interconnect Module

## Overview
This module manages cloud interconnect resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "cloud-interconnect" {
  source = "../../modules/networking/cloud-interconnect"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "cloud-interconnect_advanced" {
  source = "../../modules/networking/cloud-interconnect"

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
    module      = "cloud-interconnect"
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
| dedicated_interconnects | | string | | yes |
| partner_interconnects | | string | | yes |
| dedicated_attachments | | string | | yes |
| partner_attachments | | string | | yes |
| cloud_routers | | string | | yes |
| router_interfaces | | string | | yes |
| bgp_sessions | | string | | yes |
| macsec_configs | | string | | yes |
| enable_network_connectivity_center | | string | | yes |
| connectivity_hub_name | | string | | yes |
| connectivity_hub_description | | string | | yes |
| connectivity_spokes | | string | | yes |
| enable_monitoring | | string | | yes |
| create_dashboard | | string | | yes |
| dashboard_display_name | | string | | yes |
| notification_channels | | string | | yes |
| alert_policies | | string | | yes |
| interconnect_iam_bindings | | string | | yes |
| router_iam_bindings | | string | | yes |
| hub_iam_bindings | | string | | yes |
| enable_audit_logging | | string | | yes |
| audit_log_sink_name | | string | | yes |
| audit_log_destination | | string | | yes |
| enable_cloud_armor | | string | | yes |
| security_policy_name | | string | | yes |
| security_policy_rules | | string | | yes |
| enable_adaptive_protection | | string | | yes |
| adaptive_protection_rule_visibility | | string | | yes |
| enable_redundancy | | string | | yes |
| redundancy_config | | string | | yes |
| enable_traffic_engineering | | string | | yes |
| traffic_engineering_config | | string | | yes |
| enable_performance_monitoring | | string | | yes |
| performance_monitoring_config | | string | | yes |
| enable_capacity_planning | | string | | yes |
| capacity_planning_config | | string | | yes |
| enable_cost_optimization | | string | | yes |
| cost_optimization_config | | string | | yes |
| enable_compliance_monitoring | | string | | yes |
| compliance_config | | string | | yes |
| enable_disaster_recovery | | string | | yes |
| disaster_recovery_config | | string | | yes |
| network_telemetry_config | | string | | yes |
| quality_of_service_config | | string | | yes |
| peering_config | | string | | yes |
| maintenance_config | | string | | yes |
| labels | | string | | yes |
| tags | | string | | yes |
| environment | | string | | yes |
| region_configs | | string | | yes |
| custom_route_advertisements | | string | | yes |
| enable_cross_cloud_connectivity | | string | | yes |
| cross_cloud_config | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| dedicated_interconnect_ids | |
| dedicated_interconnect_names | |
| dedicated_interconnect_details | |
| partner_interconnect_ids | |
| partner_interconnect_names | |
| partner_interconnect_details | |
| dedicated_attachment_ids | |
| dedicated_attachment_names | |
| dedicated_attachment_details | |
| partner_attachment_ids | |
| partner_attachment_names | |
| partner_attachment_details | |
| router_ids | |
| router_names | |
| router_details | |
| router_interface_names | |
| router_interface_details | |
| bgp_session_names | |
| bgp_session_details | |
| connectivity_hub_id | |
| connectivity_hub_name | |
| connectivity_hub_details | |
| connectivity_spoke_ids | |
| connectivity_spoke_names | |
| connectivity_spoke_details | |
| macsec_config_names | |
| macsec_config_details | |
| service_account_email | |
| service_account_id | |
| service_account_unique_id | |
| monitoring_dashboard_id | |
| monitoring_dashboard_url | |
| alert_policy_ids | |
| alert_policy_names | |
| configuration_metadata | |
| connectivity_summary | |
| security_configuration | |
| operational_status | |
| bgp_configuration | |
| network_telemetry | |
| cost_optimization | |
| compliance_status | |
| management_urls | |
| resource_identifiers | |
| bandwidth_summary | |
| partner_attachment_pairing_keys | |
| connection_status | |

## Resources Created

The following resources are created by this module:

- google_compute_interconnect
- google_compute_interconnect_attachment
- google_compute_interconnect_iam_binding
- google_compute_interconnect_macsec_config
- google_compute_router
- google_compute_router_iam_binding
- google_compute_router_interface
- google_compute_router_peer
- google_compute_security_policy
- google_logging_project_sink
- google_monitoring_alert_policy
- google_monitoring_dashboard
- google_network_connectivity_hub
- google_network_connectivity_hub_iam_binding
- google_network_connectivity_spoke
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
terraform import module.cloud-interconnect.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:20 AM
Module Version: 1.0.0
