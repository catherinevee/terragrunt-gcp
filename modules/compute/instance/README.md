# Instance Module

## Overview
This module manages instance resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "instance" {
  source = "../../modules/compute/instance"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "instance_advanced" {
  source = "../../modules/compute/instance"

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
    module      = "instance"
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
| zone | | string | | yes |
| region | | string | | yes |
| machine_type | | string | | yes |
| min_cpu_platform | | string | | yes |
| enable_display | | string | | yes |
| deletion_protection | | string | | yes |
| allow_stopping_for_update | | string | | yes |
| can_ip_forward | | string | | yes |
| hostname | | string | | yes |
| description | | string | | yes |
| environment | | string | | yes |
| boot_disk_auto_delete | | string | | yes |
| boot_disk_device_name | | string | | yes |
| boot_disk_mode | | string | | yes |
| boot_disk_encryption_key_raw | | string | | yes |
| boot_disk_kms_key_self_link | | string | | yes |
| boot_disk_size | | string | | yes |
| boot_disk_type | | string | | yes |
| boot_disk_image | | string | | yes |
| boot_disk_labels | | string | | yes |
| boot_disk_resource_manager_tags | | string | | yes |
| attached_disks | | string | | yes |
| scratch_disk_count | | string | | yes |
| scratch_disk_interface | | string | | yes |
| network | | string | | yes |
| subnetwork | | string | | yes |
| network_ip | | string | | yes |
| stack_type | | string | | yes |
| enable_external_ip | | string | | yes |
| nat_ip | | string | | yes |
| network_tier | | string | | yes |
| public_ptr_domain_name | | string | | yes |
| enable_ipv6 | | string | | yes |
| alias_ip_ranges | | string | | yes |
| network_interface | | string | | yes |
| create_service_account | | string | | yes |
| service_account_email | | string | | yes |
| service_account_scopes | | string | | yes |
| service_account_roles | | string | | yes |
| guest_accelerators | | string | | yes |
| preemptible | | string | | yes |
| automatic_restart | | string | | yes |
| on_host_maintenance | | string | | yes |
| provisioning_model | | string | | yes |
| instance_termination_action | | string | | yes |
| node_affinities | | string | | yes |
| local_ssd_recovery_timeout | | string | | yes |
| enable_secure_boot | | string | | yes |
| enable_vtpm | | string | | yes |
| enable_integrity_monitoring | | string | | yes |
| enable_confidential_compute | | string | | yes |
| advanced_machine_features | | string | | yes |
| reservation_affinity | | string | | yes |
| network_performance_config | | string | | yes |
| metadata | | string | | yes |
| enable_oslogin | | string | | yes |
| enable_oslogin_2fa | | string | | yes |
| startup_script | | string | | yes |
| shutdown_script | | string | | yes |
| metadata_startup_script | | string | | yes |
| labels | | string | | yes |
| tags | | string | | yes |
| resource_policies | | string | | yes |
| create_instance_group | | string | | yes |
| named_ports | | string | | yes |
| ignore_changes_list | | string | | yes |
| create_before_destroy | | string | | yes |
| timeouts | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | |
| instance_name | |
| self_link | |
| id | |
| network_ip | |
| external_ip | |
| ipv6_address | |
| network_interfaces | |
| zone | |
| machine_type | |
| cpu_platform | |
| current_status | |
| hostname | |
| service_account_email | |
| service_account_scopes | |
| created_service_account | |
| boot_disk_id | |
| boot_disk_device_name | |
| boot_disk_size | |
| boot_disk_type | |
| attached_disks | |
| scratch_disks | |
| guest_accelerators | |
| scheduling | |
| shielded_instance_config | |
| metadata | |
| metadata_fingerprint | |
| labels | |
| tags | |
| tags_fingerprint | |
| instance_group_self_link | |
| instance_group_id | |
| instance_group_size | |
| ssh_command | |
| ssh_connection_string | |
| creation_timestamp | |
| label_fingerprint | |
| min_cpu_platform | |
| enable_display | |
| deletion_protection | |
| can_ip_forward | |
| resource_policies | |
| confidential_instance_config | |
| advanced_machine_features | |
| reservation_affinity | |
| network_performance_config | |
| instance_template | |

## Resources Created

The following resources are created by this module:

- google_compute_instance
- google_compute_instance_group
- google_project_iam_member
- google_service_account
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
terraform import module.instance.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:05 AM
Module Version: 1.0.0
