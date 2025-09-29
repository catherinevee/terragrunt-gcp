# Pubsub Module

## Overview
This module manages pubsub resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "pubsub" {
  source = "../../modules/data/pubsub"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "pubsub_advanced" {
  source = "../../modules/data/pubsub"

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
    module      = "pubsub"
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
| topic_name | | string | | yes |
| environment | | string | | yes |
| message_retention_duration | | string | | yes |
| kms_key_name | | string | | yes |
| allowed_persistence_regions | | string | | yes |
| topic_labels | | string | | yes |
| create_schema | | string | | yes |
| schema_name | | string | | yes |
| schema_type | | string | | yes |
| schema_definition | | string | | yes |
| existing_schema_name | | string | | yes |
| schema_encoding | | string | | yes |
| create_dead_letter_topic | | string | | yes |
| dead_letter_topic_name | | string | | yes |
| dead_letter_message_retention_duration | | string | | yes |
| dead_letter_kms_key_name | | string | | yes |
| dead_letter_max_delivery_attempts | | string | | yes |
| create_dead_letter_monitoring_subscription | | string | | yes |
| subscriptions | | string | | yes |
| subscription_labels | | string | | yes |
| topic_iam_policy | | string | | yes |
| topic_iam_bindings | | string | | yes |
| topic_iam_binding_conditions | | string | | yes |
| topic_iam_members | | string | | yes |
| subscription_iam_members | | string | | yes |
| create_monitoring_alerts | | string | | yes |
| monitoring_alerts | | string | | yes |
| create_monitoring_dashboard | | string | | yes |
| snapshots | | string | | yes |
| create_lite_topic | | string | | yes |
| lite_topic_name | | string | | yes |
| lite_topic_region | | string | | yes |
| lite_topic_zone | | string | | yes |
| lite_partition_count | | string | | yes |
| lite_publish_capacity_mib_per_sec | | string | | yes |
| lite_subscribe_capacity_mib_per_sec | | string | | yes |
| lite_retention_bytes_per_partition | | string | | yes |
| lite_retention_period | | string | | yes |
| lite_throughput_reservation | | string | | yes |
| create_lite_subscription | | string | | yes |
| lite_subscription_name | | string | | yes |
| lite_delivery_requirement | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| topic_name | |
| topic_id | |
| topic_labels | |
| topic_kms_key_name | |
| topic_message_retention_duration | |
| topic_schema_settings | |
| topic_message_storage_policy | |
| schema_name | |
| schema_id | |
| schema_type | |
| schema_definition | |
| dead_letter_topic_name | |
| dead_letter_topic_id | |
| dead_letter_monitoring_subscription_name | |
| dead_letter_monitoring_subscription_id | |
| subscriptions | |
| subscription_names | |
| subscription_ids | |
| push_subscription_endpoints | |
| bigquery_subscription_tables | |
| cloud_storage_subscription_buckets | |
| snapshots | |
| snapshot_names | |
| lite_topic_name | |
| lite_topic_id | |
| lite_topic_region | |
| lite_topic_zone | |
| lite_topic_partition_count | |
| lite_subscription_name | |
| lite_subscription_id | |
| monitoring_alert_policies | |
| monitoring_dashboard_id | |
| topic_iam_policy_etag | |
| topic_iam_bindings | |
| topic_iam_members | |
| subscription_iam_members | |
| console_urls | |
| gcloud_commands | |
| python_examples | |
| import_commands | |

## Resources Created

The following resources are created by this module:

- google_monitoring_alert_policy
- google_monitoring_dashboard
- google_pubsub_lite_subscription
- google_pubsub_lite_topic
- google_pubsub_schema
- google_pubsub_snapshot
- google_pubsub_subscription
- google_pubsub_subscription_iam_member
- google_pubsub_topic
- google_pubsub_topic_iam_binding
- google_pubsub_topic_iam_member
- google_pubsub_topic_iam_policy

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
terraform import module.pubsub.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:11 AM
Module Version: 1.0.0
