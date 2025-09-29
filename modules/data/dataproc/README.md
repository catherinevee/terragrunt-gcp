# Dataproc Module

## Overview
This module manages dataproc resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "dataproc" {
  source = "../../modules/data/dataproc"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "dataproc_advanced" {
  source = "../../modules/data/dataproc"

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
    module      = "dataproc"
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
| zone | | string | | yes |
| environment | | string | | yes |
| cluster_name | | string | | yes |
| name_prefix | | string | | yes |
| deploy_cluster | | string | | yes |
| cluster_type | | string | | yes |
| cluster_config | | string | | yes |
| image_version | | string | | yes |
| graceful_decommission_timeout | | string | | yes |
| master_num_instances | | string | | yes |
| master_machine_type | | string | | yes |
| master_boot_disk_type | | string | | yes |
| master_boot_disk_size_gb | | string | | yes |
| master_num_local_ssds | | string | | yes |
| master_local_ssd_interface | | string | | yes |
| master_min_cpu_platform | | string | | yes |
| master_accelerators | | string | | yes |
| master_image_uri | | string | | yes |
| worker_num_instances | | string | | yes |
| worker_machine_type | | string | | yes |
| worker_boot_disk_type | | string | | yes |
| worker_boot_disk_size_gb | | string | | yes |
| worker_num_local_ssds | | string | | yes |
| worker_local_ssd_interface | | string | | yes |
| worker_min_cpu_platform | | string | | yes |
| worker_accelerators | | string | | yes |
| worker_image_uri | | string | | yes |
| preemptible_workers | | string | | yes |
| preemptible_worker_type | | string | | yes |
| preemptible_boot_disk_type | | string | | yes |
| preemptible_boot_disk_size_gb | | string | | yes |
| preemptible_num_local_ssds | | string | | yes |
| preemptible_local_ssd_interface | | string | | yes |
| optional_components | | string | | yes |
| override_properties | | string | | yes |
| software_config | | string | | yes |
| enable_component_gateway | | string | | yes |
| network | | string | | yes |
| subnetwork | | string | | yes |
| internal_ip_only | | string | | yes |
| network_tags | | string | | yes |
| service_account | | string | | yes |
| service_account_scopes | | string | | yes |
| create_service_account_roles | | string | | yes |
| staging_bucket | | string | | yes |
| temp_bucket | | string | | yes |
| create_staging_bucket | | string | | yes |
| staging_bucket_name | | string | | yes |
| staging_bucket_force_destroy | | string | | yes |
| staging_bucket_lifecycle_days | | string | | yes |
| enable_autoscaling | | string | | yes |
| create_autoscaling_policy | | string | | yes |
| autoscaling_policy_id | | string | | yes |
| autoscaling_policy_name | | string | | yes |
| autoscale_min_workers | | string | | yes |
| autoscale_max_workers | | string | | yes |
| autoscale_secondary_workers | | string | | yes |
| autoscale_min_secondary_workers | | string | | yes |
| autoscale_max_secondary_workers | | string | | yes |
| autoscale_primary_worker_weight | | string | | yes |
| autoscale_secondary_worker_weight | | string | | yes |
| autoscale_graceful_decommission_timeout | | string | | yes |
| autoscale_scale_up_factor | | string | | yes |
| autoscale_scale_down_factor | | string | | yes |
| autoscale_scale_up_min_worker_fraction | | string | | yes |
| autoscale_scale_down_min_worker_fraction | | string | | yes |
| autoscale_cooldown_period | | string | | yes |
| idle_delete_ttl | | string | | yes |
| auto_delete_time | | string | | yes |
| auto_delete_ttl | | string | | yes |
| kms_key_name | | string | | yes |
| enable_kerberos | | string | | yes |
| kerberos_root_principal_password_uri | | string | | yes |
| kerberos_kms_key_uri | | string | | yes |
| kerberos_keystore_uri | | string | | yes |
| kerberos_truststore_uri | | string | | yes |
| kerberos_keystore_password_uri | | string | | yes |
| kerberos_key_password_uri | | string | | yes |
| kerberos_truststore_password_uri | | string | | yes |
| kerberos_cross_realm_trust_realm | | string | | yes |
| kerberos_cross_realm_trust_kdc | | string | | yes |
| kerberos_cross_realm_trust_admin_server | | string | | yes |
| kerberos_cross_realm_trust_shared_password_uri | | string | | yes |
| kerberos_kdc_db_key_uri | | string | | yes |
| kerberos_tgt_lifetime_hours | | string | | yes |
| kerberos_realm | | string | | yes |
| user_service_account_mapping | | string | | yes |
| enable_secure_boot | | string | | yes |
| enable_vtpm | | string | | yes |
| enable_integrity_monitoring | | string | | yes |
| enable_http_port_access | | string | | yes |
| http_ports | | string | | yes |
| metadata | | string | | yes |
| reservation_affinity_consume_type | | string | | yes |
| reservation_affinity_key | | string | | yes |
| reservation_affinity_values | | string | | yes |
| node_group_affinity_uri | | string | | yes |
| metric_source | | string | | yes |
| metric_overrides | | string | | yes |
| initialization_actions | | string | | yes |
| enable_stackdriver_monitoring | | string | | yes |
| enable_jupyter | | string | | yes |
| enable_kafka | | string | | yes |
| labels | | string | | yes |
| create_metastore | | string | | yes |
| metastore_service | | string | | yes |
| metastore_service_name | | string | | yes |
| metastore_tier | | string | | yes |
| metastore_release_channel | | string | | yes |
| metastore_database_type | | string | | yes |
| metastore_hive_version | | string | | yes |
| metastore_config_overrides | | string | | yes |
| metastore_kerberos_keytab_secret | | string | | yes |
| metastore_kerberos_principal | | string | | yes |
| metastore_kerberos_config_gcs_uri | | string | | yes |
| metastore_auxiliary_version_key | | string | | yes |
| metastore_auxiliary_version | | string | | yes |
| metastore_auxiliary_config_overrides | | string | | yes |
| metastore_consumer_subnetworks | | string | | yes |
| metastore_kms_key | | string | | yes |
| metastore_port | | string | | yes |
| metastore_maintenance_window_hour | | string | | yes |
| metastore_maintenance_window_day | | string | | yes |
| metastore_telemetry_log_format | | string | | yes |
| metastore_data_catalog_enabled | | string | | yes |
| metastore_instance_size | | string | | yes |
| metastore_scaling_factor | | string | | yes |
| spark_jobs | | string | | yes |
| pyspark_jobs | | string | | yes |
| hive_jobs | | string | | yes |
| pig_jobs | | string | | yes |
| hadoop_jobs | | string | | yes |
| sparksql_jobs | | string | | yes |
| presto_jobs | | string | | yes |
| kubernetes_namespace | | string | | yes |
| kubernetes_component_versions | | string | | yes |
| kubernetes_properties | | string | | yes |
| gke_cluster_target | | string | | yes |
| gke_node_pool | | string | | yes |
| gke_node_pool_roles | | string | | yes |
| gke_node_machine_type | | string | | yes |
| gke_node_local_ssd_count | | string | | yes |
| gke_node_disk_size_gb | | string | | yes |
| gke_node_disk_type | | string | | yes |
| gke_node_oauth_scopes | | string | | yes |
| gke_node_service_account | | string | | yes |
| gke_node_tags | | string | | yes |
| gke_node_min_cpu_platform | | string | | yes |
| gke_node_preemptible | | string | | yes |
| gke_node_spot | | string | | yes |
| gke_node_accelerator_count | | string | | yes |
| gke_node_accelerator_type | | string | | yes |
| gke_node_gpu_partition_size | | string | | yes |
| gke_node_locations | | string | | yes |
| gke_node_min_count | | string | | yes |
| gke_node_max_count | | string | | yes |
| create_workflow_template | | string | | yes |
| workflow_template_name | | string | | yes |
| workflow_jobs | | string | | yes |
| workflow_master_num_instances | | string | | yes |
| workflow_master_machine_type | | string | | yes |
| workflow_master_boot_disk_type | | string | | yes |
| workflow_master_boot_disk_size_gb | | string | | yes |
| workflow_worker_num_instances | | string | | yes |
| workflow_worker_machine_type | | string | | yes |
| workflow_worker_boot_disk_type | | string | | yes |
| workflow_worker_boot_disk_size_gb | | string | | yes |
| workflow_software_properties | | string | | yes |
| workflow_auto_delete_ttl | | string | | yes |
| workflow_parameter_name | | string | | yes |
| workflow_parameter_fields | | string | | yes |
| workflow_parameter_description | | string | | yes |
| workflow_parameter_validation_regex | | string | | yes |
| workflow_parameter_validation_values | | string | | yes |
| workflow_dag_timeout | | string | | yes |
| workflow_version | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| cluster_name | |
| cluster_id | |
| cluster_uuid | |
| cluster_state | |
| cluster_state_time | |
| cluster_detail | |
| cluster_substate | |
| master_instance_names | |
| master_machine_type | |
| master_num_instances | |
| worker_instance_names | |
| worker_machine_type | |
| worker_num_instances | |
| worker_min_num_instances | |
| preemptible_worker_instance_names | |
| preemptible_worker_num_instances | |
| image_version | |
| software_properties | |
| optional_components | |
| network | |
| subnetwork | |
| zone | |
| internal_ip_only | |
| staging_bucket | |
| temp_bucket | |
| created_staging_bucket | |
| created_staging_bucket_url | |
| endpoint_config | |
| http_ports | |
| autoscaling_policy_id | |
| autoscaling_policy_name | |
| autoscaling_policy_uri | |
| metastore_service_id | |
| metastore_service_name | |
| metastore_service_state | |
| metastore_service_endpoint_uri | |
| metastore_port | |
| service_account | |
| kerberos_enabled | |
| kerberos_realm | |
| spark_jobs | |
| pyspark_jobs | |
| hive_jobs | |
| pig_jobs | |
| hadoop_jobs | |
| sparksql_jobs | |
| presto_jobs | |
| workflow_template_id | |
| workflow_template_name | |
| workflow_template_version | |
| virtual_cluster_config | |
| kubernetes_namespace | |
| gke_cluster_target | |
| labels | |
| console_urls | |
| component_gateway_urls | |
| gcloud_commands | |
| spark_submit_examples | |
| import_commands | |

## Resources Created

The following resources are created by this module:

- google_dataproc_autoscaling_policy
- google_dataproc_cluster
- google_dataproc_job
- google_dataproc_metastore_service
- google_dataproc_workflow_template
- google_project_iam_member
- google_storage_bucket
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
terraform import module.dataproc.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:09 AM
Module Version: 1.0.0
