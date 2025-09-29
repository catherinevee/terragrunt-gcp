# Instance-group Module

## Overview
This module manages instance group resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "instance-group" {
  source = "../../modules/compute/instance-group"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "instance-group_advanced" {
  source = "../../modules/compute/instance-group"

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
    module      = "instance-group"
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
| description | | string | | yes |
| base_instance_name | | string | | yes |
| region | | string | | yes |
| zone | | string | | yes |
| regional | | string | | yes |
| distribution_zones | | string | | yes |
| distribution_policy_target_shape | | string | | yes |
| instance_template_description | | string | | yes |
| machine_type | | string | | yes |
| min_cpu_platform | | string | | yes |
| can_ip_forward | | string | | yes |
| enable_display | | string | | yes |
| resource_policies | | string | | yes |
| source_image | | string | | yes |
| boot_disk_auto_delete | | string | | yes |
| boot_disk_name | | string | | yes |
| boot_disk_size_gb | | string | | yes |
| boot_disk_type | | string | | yes |
| boot_disk_kms_key_self_link | | string | | yes |
| additional_disks | | string | | yes |
| network_interfaces | | string | | yes |
| create_service_account | | string | | yes |
| service_account_email | | string | | yes |
| service_account_scopes | | string | | yes |
| service_account_roles | | string | | yes |
| metadata | | string | | yes |
| labels | | string | | yes |
| tags | | string | | yes |
| enable_oslogin | | string | | yes |
| startup_script | | string | | yes |
| shutdown_script | | string | | yes |
| guest_accelerators | | string | | yes |
| preemptible | | string | | yes |
| automatic_restart | | string | | yes |
| on_host_maintenance | | string | | yes |
| provisioning_model | | string | | yes |
| instance_termination_action | | string | | yes |
| node_affinities | | string | | yes |
| enable_secure_boot | | string | | yes |
| enable_vtpm | | string | | yes |
| enable_integrity_monitoring | | string | | yes |
| enable_confidential_compute | | string | | yes |
| advanced_machine_features | | string | | yes |
| reservation_affinity | | string | | yes |
| network_performance_config | | string | | yes |
| target_size | | string | | yes |
| target_pools | | string | | yes |
| named_ports | | string | | yes |
| wait_for_instances | | string | | yes |
| wait_for_instances_status | | string | | yes |
| versions | | string | | yes |
| create_health_check | | string | | yes |
| health_check_id | | string | | yes |
| health_check_name | | string | | yes |
| health_check_type | | string | | yes |
| health_check_interval_sec | | string | | yes |
| health_check_timeout_sec | | string | | yes |
| health_check_healthy_threshold | | string | | yes |
| health_check_unhealthy_threshold | | string | | yes |
| health_check_port | | string | | yes |
| health_check_request_path | | string | | yes |
| health_check_host | | string | | yes |
| health_check_response | | string | | yes |
| health_check_proxy_header | | string | | yes |
| health_check_port_specification | | string | | yes |
| health_check_tcp_request | | string | | yes |
| health_check_tcp_response | | string | | yes |
| health_check_grpc_service_name | | string | | yes |
| health_check_enable_logging | | string | | yes |
| auto_healing_initial_delay_sec | | string | | yes |
| update_policy | | string | | yes |
| stateful_disks | | string | | yes |
| stateful_internal_ips | | string | | yes |
| stateful_external_ips | | string | | yes |
| instance_lifecycle_policy | | string | | yes |
| autoscaling_enabled | | string | | yes |
| max_replicas | | string | | yes |
| min_replicas | | string | | yes |
| autoscaling_cooldown_period | | string | | yes |
| autoscaling_cpu | | string | | yes |
| autoscaling_metrics | | string | | yes |
| autoscaling_load_balancing_utilization | | string | | yes |
| autoscaling_scale_in_control | | string | | yes |
| autoscaling_mode | | string | | yes |
| ignore_changes_list | | string | | yes |
| mig_timeouts | | string | | yes |
| autoscaler_timeouts | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| mig_id | |
| mig_name | |
| mig_self_link | |
| mig_instance_group | |
| instance_template_id | |
| instance_template_self_link | |
| instance_template_name | |
| instance_template_metadata_fingerprint | |
| instance_template_tags_fingerprint | |
| base_instance_name | |
| target_size | |
| current_size | |
| fingerprint | |
| status | |
| creation_timestamp | |
| health_check_id | |
| health_check_self_link | |
| autoscaler_id | |
| autoscaler_self_link | |
| autoscaler_name | |
| service_account_email | |
| created_service_account | |
| region | |
| zone | |
| distribution_zones | |
| list_managed_instances_url | |
| named_ports | |
| update_policy | |
| versions | |
| stateful_disks | |
| stateful_internal_ips | |
| stateful_external_ips | |
| instance_lifecycle_policy | |
| autoscaling_configuration | |
| instance_template_configuration | |
| instance_group_urls | |
| health_status_url | |
| instance_urls | |

## Resources Created

The following resources are created by this module:

- google_compute_autoscaler
- google_compute_health_check
- google_compute_instance_group_manager
- google_compute_instance_template
- google_compute_region_autoscaler
- google_compute_region_instance_group_manager
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
terraform import module.instance-group.RESOURCE_TYPE.NAME RESOURCE_ID
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
