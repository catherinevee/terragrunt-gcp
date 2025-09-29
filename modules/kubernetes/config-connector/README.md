# Config-connector Module

## Overview
This module manages config connector resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "config-connector" {
  source = "../../modules/kubernetes/config-connector"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "config-connector_advanced" {
  source = "../../modules/kubernetes/config-connector"

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
    module      = "config-connector"
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
| enable_config_connector | | string | | yes |
| config_connector_mode | | string | | yes |
| config_connector_namespace | | string | | yes |
| create_config_connector_namespace | | string | | yes |
| namespace_annotations | | string | | yes |
| install_config_connector_operator | | string | | yes |
| config_connector_memberships | | string | | yes |
| create_service_account | | string | | yes |
| service_account_id | | string | | yes |
| service_account_roles | | string | | yes |
| google_service_account_email | | string | | yes |
| enable_workload_identity | | string | | yes |
| create_kubernetes_service_account | | string | | yes |
| kubernetes_service_account_name | | string | | yes |
| credential_secret_name | | string | | yes |
| state_into_spec | | string | | yes |
| actuation_mode | | string | | yes |
| webhook_failure_policy | | string | | yes |
| webhook_timeout_seconds | | string | | yes |
| watch_fleet_workloads | | string | | yes |
| watch_fleet_workload_identity | | string | | yes |
| config_connector_contexts | | string | | yes |
| enable_custom_resources | | string | | yes |
| custom_resource_definitions | | string | | yes |
| enable_policy_controller | | string | | yes |
| policy_constraints | | string | | yes |
| constraint_templates | | string | | yes |
| enable_config_sync | | string | | yes |
| config_sync_secrets | | string | | yes |
| enable_hierarchy_controller | | string | | yes |
| hierarchy_configurations | | string | | yes |
| enable_resource_quotas | | string | | yes |
| resource_quotas | | string | | yes |
| enable_network_policies | | string | | yes |
| network_policies | | string | | yes |
| enable_rbac | | string | | yes |
| cluster_roles | | string | | yes |
| cluster_role_bindings | | string | | yes |
| enable_monitoring | | string | | yes |
| create_dashboard | | string | | yes |
| dashboard_display_name | | string | | yes |
| notification_channels | | string | | yes |
| alert_policies | | string | | yes |
| enable_audit_logging | | string | | yes |
| audit_log_sink_name | | string | | yes |
| audit_log_destination | | string | | yes |
| enable_backup | | string | | yes |
| backup_configurations | | string | | yes |
| enable_drift_detection | | string | | yes |
| drift_detection_config | | string | | yes |
| enable_resource_validation | | string | | yes |
| resource_validation_config | | string | | yes |
| enable_multi_tenancy | | string | | yes |
| multi_tenancy_config | | string | | yes |
| enable_disaster_recovery | | string | | yes |
| disaster_recovery_config | | string | | yes |
| enable_compliance_monitoring | | string | | yes |
| compliance_config | | string | | yes |
| enable_performance_optimization | | string | | yes |
| performance_config | | string | | yes |
| labels | | string | | yes |
| tags | | string | | yes |
| environment | | string | | yes |
| resource_management_config | | string | | yes |
| integration_configs | | string | | yes |
| custom_admission_controllers | | string | | yes |
| resource_templates | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| config_management_feature_name | |
| config_management_feature_details | |
| config_connector_membership_ids | |
| config_connector_membership_details | |
| config_connector_namespace_name | |
| config_connector_namespace_details | |
| config_connector_operator_name | |
| config_connector_operator_details | |
| config_connector_context_names | |
| config_connector_context_details | |
| service_account_email | |
| service_account_id | |
| service_account_unique_id | |
| kubernetes_service_account_name | |
| kubernetes_service_account_details | |
| custom_resource_names | |
| custom_resource_details | |
| policy_constraint_names | |
| policy_constraint_details | |
| constraint_template_names | |
| constraint_template_details | |
| config_sync_secret_names | |
| config_sync_secret_details | |
| hierarchy_config_names | |
| hierarchy_config_details | |
| resource_quota_names | |
| resource_quota_details | |
| network_policy_names | |
| network_policy_details | |
| cluster_role_names | |
| cluster_role_details | |
| cluster_role_binding_names | |
| cluster_role_binding_details | |
| monitoring_dashboard_id | |
| monitoring_dashboard_url | |
| alert_policy_ids | |
| alert_policy_names | |
| backup_config_names | |
| backup_config_details | |
| configuration_metadata | |
| config_connector_status | |
| features_configuration | |
| advanced_configuration | |
| management_urls | |
| resource_identifiers | |
| supported_resource_types | |
| configuration_validation | |
| operational_health | |

## Resources Created

The following resources are created by this module:

- google_gke_hub_feature
- google_gke_hub_feature_membership
- google_logging_project_sink
- google_monitoring_alert_policy
- google_monitoring_dashboard
- google_project_iam_member
- google_project_service
- google_service_account
- google_service_account_iam_member
- kubernetes_cluster_role
- kubernetes_cluster_role_binding
- kubernetes_manifest
- kubernetes_namespace
- kubernetes_network_policy
- kubernetes_resource_quota
- kubernetes_secret
- kubernetes_service_account

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
terraform import module.config-connector.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:14 AM
Module Version: 1.0.0
