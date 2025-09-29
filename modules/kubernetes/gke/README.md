# Gke Module

## Overview
This module manages gke resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "gke" {
  source = "../../modules/kubernetes/gke"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "gke_advanced" {
  source = "../../modules/kubernetes/gke"

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
    module      = "gke"
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
| name | | string | | yes |
| name_prefix | | string | | yes |
| location | | string | | yes |
| environment | | string | | yes |
| network_name | | string | | yes |
| subnetwork_name | | string | | yes |
| cluster_secondary_range_name | | string | | yes |
| services_secondary_range_name | | string | | yes |
| cluster_ipv4_cidr | | string | | yes |
| services_ipv4_cidr | | string | | yes |
| min_master_version | | string | | yes |
| release_channel | | string | | yes |
| remove_default_node_pool | | string | | yes |
| initial_node_count | | string | | yes |
| min_count | | string | | yes |
| max_count | | string | | yes |
| machine_type | | string | | yes |
| disk_size_gb | | string | | yes |
| disk_type | | string | | yes |
| preemptible | | string | | yes |
| spot | | string | | yes |
| auto_repair | | string | | yes |
| auto_upgrade | | string | | yes |
| enable_integrity_monitoring | | string | | yes |
| enable_secure_boot | | string | | yes |
| node_tags | | string | | yes |
| node_labels | | string | | yes |
| node_metadata | | string | | yes |
| oauth_scopes | | string | | yes |
| node_service_account | | string | | yes |
| node_locations | | string | | yes |
| node_pools | | string | | yes |
| enable_cluster_autoscaling | | string | | yes |
| cluster_autoscaling_resource_limits | | string | | yes |
| auto_provisioning_defaults | | string | | yes |
| enable_private_nodes | | string | | yes |
| enable_private_endpoint | | string | | yes |
| master_ipv4_cidr_block | | string | | yes |
| enable_master_global_access | | string | | yes |
| master_authorized_networks | | string | | yes |
| maintenance_start_time | | string | | yes |
| maintenance_recurrence | | string | | yes |
| maintenance_exclusions | | string | | yes |
| enable_http_load_balancing | | string | | yes |
| enable_horizontal_pod_autoscaling | | string | | yes |
| enable_network_policy | | string | | yes |
| network_policy_provider | | string | | yes |
| enable_vertical_pod_autoscaling | | string | | yes |
| enable_dns_cache | | string | | yes |
| enable_filestore_csi_driver | | string | | yes |
| enable_gcs_fuse_csi_driver | | string | | yes |
| enable_backup_agent | | string | | yes |
| enable_config_connector | | string | | yes |
| enable_gce_persistent_disk_csi_driver | | string | | yes |
| enable_kalm | | string | | yes |
| enable_istio | | string | | yes |
| istio_auth | | string | | yes |
| enable_cloud_run | | string | | yes |
| cloud_run_load_balancer_type | | string | | yes |
| enable_binary_authorization | | string | | yes |
| binary_authorization_evaluation_mode | | string | | yes |
| enable_workload_identity | | string | | yes |
| enable_shielded_nodes | | string | | yes |
| enable_confidential_nodes | | string | | yes |
| security_group | | string | | yes |
| database_encryption_key_name | | string | | yes |
| enable_kubernetes_alpha | | string | | yes |
| enable_tpu | | string | | yes |
| enable_legacy_abac | | string | | yes |
| enable_autopilot | | string | | yes |
| enable_intranode_visibility | | string | | yes |
| enable_l4_ilb_subsetting | | string | | yes |
| enable_cost_management | | string | | yes |
| enable_gateway_api | | string | | yes |
| gateway_api_channel | | string | | yes |
| enable_service_external_ips | | string | | yes |
| enable_mesh_certificates | | string | | yes |
| disable_default_snat | | string | | yes |
| default_max_pods_per_node | | string | | yes |
| datapath_provider | | string | | yes |
| cluster_dns_provider | | string | | yes |
| cluster_dns_scope | | string | | yes |
| cluster_dns_domain | | string | | yes |
| fleet_project | | string | | yes |
| logging_service | | string | | yes |
| monitoring_service | | string | | yes |
| enable_monitoring_config | | string | | yes |
| monitoring_enable_components | | string | | yes |
| enable_managed_prometheus | | string | | yes |
| enable_advanced_datapath_observability | | string | | yes |
| advanced_datapath_observability_mode | | string | | yes |
| enable_logging_config | | string | | yes |
| logging_enable_components | | string | | yes |
| resource_usage_export_dataset_id | | string | | yes |
| enable_network_egress_metering | | string | | yes |
| enable_resource_consumption_metering | | string | | yes |
| notification_config_topic | | string | | yes |
| notification_filter_event_types | | string | | yes |
| security_posture_mode | | string | | yes |
| vulnerability_mode | | string | | yes |
| cluster_labels | | string | | yes |
| cluster_create_timeout | | string | | yes |
| cluster_update_timeout | | string | | yes |
| cluster_delete_timeout | | string | | yes |
| ignore_changes_on_update | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| cluster_name | |
| cluster_id | |
| cluster_self_link | |
| cluster_endpoint | |
| cluster_master_version | |
| cluster_location | |
| cluster_region | |
| cluster_zones | |
| cluster_network | |
| cluster_subnetwork | |
| cluster_ipv4_cidr | |
| services_ipv4_cidr | |
| master_ipv4_cidr_block | |
| is_private_cluster | |
| is_private_endpoint | |
| public_endpoint | |
| private_endpoint | |
| peering_name | |
| cluster_ca_certificate | |
| master_auth | |
| node_pools | |
| node_pool_names | |
| default_node_pool_name | |
| workload_identity_config | |
| identity_namespace | |
| service_account | |
| addons_config | |
| http_load_balancing_enabled | |
| horizontal_pod_autoscaling_enabled | |
| network_policy_enabled | |
| istio_enabled | |
| dns_cache_enabled | |
| cluster_autoscaling_enabled | |
| vertical_pod_autoscaling_enabled | |
| maintenance_policy | |
| logging_service | |
| monitoring_service | |
| monitoring_config | |
| logging_config | |
| binary_authorization | |
| shielded_nodes_enabled | |
| database_encryption | |
| confidential_nodes | |
| resource_usage_export_config | |
| cluster_labels | |
| label_fingerprint | |
| get_credentials_command | |
| kubectl_config | |
| console_urls | |
| api_endpoints | |
| features | |
| notification_config | |
| cluster_status | |
| cluster_status_message | |
| operation | |
| import_command | |

## Resources Created

The following resources are created by this module:

- google_container_cluster
- random_id

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
terraform import module.gke.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:15 AM
Module Version: 1.0.0
