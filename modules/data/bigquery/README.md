# Bigquery Module

## Overview
This module manages bigquery resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "bigquery" {
  source = "../../modules/data/bigquery"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "bigquery_advanced" {
  source = "../../modules/data/bigquery"

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
    module      = "bigquery"
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
| dataset_id | | string | | yes |
| location | | string | | yes |
| environment | | string | | yes |
| friendly_name | | string | | yes |
| description | | string | | yes |
| default_table_expiration_ms | | string | | yes |
| default_partition_expiration_ms | | string | | yes |
| default_collation | | string | | yes |
| max_time_travel_hours | | string | | yes |
| storage_billing_model | | string | | yes |
| delete_contents_on_destroy | | string | | yes |
| kms_key_name | | string | | yes |
| access | | string | | yes |
| enable_default_access | | string | | yes |
| external_dataset_reference | | string | | yes |
| dataset_labels | | string | | yes |
| table_labels | | string | | yes |
| tables | | string | | yes |
| table_deletion_protection | | string | | yes |
| routines | | string | | yes |
| dataset_iam_policy | | string | | yes |
| dataset_iam_bindings | | string | | yes |
| dataset_iam_binding_conditions | | string | | yes |
| dataset_iam_members | | string | | yes |
| table_iam_members | | string | | yes |
| data_transfers | | string | | yes |
| create_reservation | | string | | yes |
| reservation_name | | string | | yes |
| reservation_slot_capacity | | string | | yes |
| reservation_edition | | string | | yes |
| reservation_ignore_idle_slots | | string | | yes |
| reservation_concurrency | | string | | yes |
| reservation_multi_region_auxiliary | | string | | yes |
| reservation_autoscale | | string | | yes |
| create_capacity_commitment | | string | | yes |
| commitment_plan | | string | | yes |
| commitment_slot_count | | string | | yes |
| commitment_edition | | string | | yes |
| commitment_renewal_plan | | string | | yes |
| reservation_assignment_config | | string | | yes |
| ignore_changes_on_dataset | | string | | yes |
| ignore_changes_on_tables | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| dataset_id | |
| dataset_self_link | |
| dataset_friendly_name | |
| dataset_description | |
| dataset_location | |
| dataset_creation_time | |
| dataset_last_modified_time | |
| dataset_etag | |
| dataset_labels | |
| default_table_expiration_ms | |
| default_partition_expiration_ms | |
| default_collation | |
| max_time_travel_hours | |
| storage_billing_model | |
| default_encryption_configuration | |
| kms_key_name | |
| access | |
| tables | |
| table_ids | |
| table_self_links | |
| view_definitions | |
| materialized_view_definitions | |
| routines | |
| routine_ids | |
| data_transfers | |
| data_transfer_names | |
| reservation | |
| reservation_name | |
| capacity_commitment | |
| capacity_commitment_id | |
| reservation_assignment | |
| dataset_iam_policy_etag | |
| dataset_iam_bindings | |
| dataset_iam_members | |
| table_iam_members | |
| console_url | |
| bq_commands | |
| sql_queries | |
| import_commands | |

## Resources Created

The following resources are created by this module:

- google_bigquery_capacity_commitment
- google_bigquery_data_transfer_config
- google_bigquery_dataset
- google_bigquery_dataset_iam_binding
- google_bigquery_dataset_iam_member
- google_bigquery_dataset_iam_policy
- google_bigquery_reservation
- google_bigquery_reservation_assignment
- google_bigquery_routine
- google_bigquery_table
- google_bigquery_table_iam_member

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
terraform import module.bigquery.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:07 AM
Module Version: 1.0.0
