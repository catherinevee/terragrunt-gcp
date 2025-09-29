# Anthos-service-mesh Module

## Overview
This module manages anthos service mesh resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "anthos-service-mesh" {
  source = "../../modules/container/anthos-service-mesh"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "anthos-service-mesh_advanced" {
  source = "../../modules/container/anthos-service-mesh"

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
    module      = "anthos-service-mesh"
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
| cluster_memberships | | string | | yes |
| config_membership_name | | string | | yes |
| enable_service_mesh | | string | | yes |
| service_mesh_memberships | | string | | yes |
| create_istio_namespaces | | string | | yes |
| istio_control_plane_configs | | string | | yes |
| istio_gateways | | string | | yes |
| virtual_services | | string | | yes |
| destination_rules | | string | | yes |
| service_entries | | string | | yes |
| sidecar_configs | | string | | yes |
| peer_authentications | | string | | yes |
| authorization_policies | | string | | yes |
| telemetry_configs | | string | | yes |
| enable_monitoring | | string | | yes |
| create_dashboard | | string | | yes |
| dashboard_display_name | | string | | yes |
| notification_channels | | string | | yes |
| alert_policies | | string | | yes |
| enable_audit_logging | | string | | yes |
| audit_log_sink_name | | string | | yes |
| audit_log_destination | | string | | yes |
| enable_multi_cluster | | string | | yes |
| multi_cluster_config | | string | | yes |
| enable_fleet_workload_identity | | string | | yes |
| fleet_workload_identity_config | | string | | yes |
| enable_service_mesh_certificates | | string | | yes |
| certificate_config | | string | | yes |
| enable_observability | | string | | yes |
| observability_config | | string | | yes |
| enable_traffic_management | | string | | yes |
| traffic_management_config | | string | | yes |
| enable_security_policies | | string | | yes |
| security_policy_config | | string | | yes |
| labels | | string | | yes |
| tags | | string | | yes |
| environment | | string | | yes |
| mesh_feature_configs | | string | | yes |
| custom_resource_definitions | | string | | yes |
| workload_annotations | | string | | yes |
| namespace_configurations | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| cluster_membership_ids | |
| cluster_membership_names | |
| cluster_membership_details | |
| service_mesh_feature_id | |
| service_mesh_feature_details | |
| service_mesh_membership_ids | |
| service_mesh_membership_details | |
| istio_namespace_names | |
| istio_namespace_details | |
| istio_control_plane_names | |
| istio_control_plane_details | |
| istio_gateway_names | |
| istio_gateway_details | |
| virtual_service_names | |
| virtual_service_details | |
| destination_rule_names | |
| destination_rule_details | |
| service_entry_names | |
| service_entry_details | |
| sidecar_config_names | |
| sidecar_config_details | |
| peer_authentication_names | |
| peer_authentication_details | |
| authorization_policy_names | |
| authorization_policy_details | |
| telemetry_config_names | |
| telemetry_config_details | |
| service_account_email | |
| service_account_id | |
| service_account_unique_id | |
| monitoring_dashboard_id | |
| monitoring_dashboard_url | |
| alert_policy_ids | |
| alert_policy_names | |
| configuration_metadata | |
| service_mesh_summary | |
| multi_cluster_configuration | |
| fleet_workload_identity_configuration | |
| observability_configuration | |
| traffic_management_configuration | |
| security_policy_configuration | |
| certificate_configuration | |
| management_urls | |
| resource_identifiers | |
| istio_versions | |
| network_connectivity_summary | |
| health_status | |

## Resources Created

The following resources are created by this module:

- google_gke_hub_feature
- google_gke_hub_feature_membership
- google_gke_hub_membership
- google_logging_project_sink
- google_monitoring_alert_policy
- google_monitoring_dashboard
- google_project_iam_member
- google_project_service
- google_service_account
- kubernetes_manifest
- kubernetes_namespace

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
terraform import module.anthos-service-mesh.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:06 AM
Module Version: 1.0.0
