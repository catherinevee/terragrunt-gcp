# Container-registry Module

## Overview
This module manages container registry resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "container-registry" {
  source = "../../modules/storage/container-registry"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "container-registry_advanced" {
  source = "../../modules/storage/container-registry"

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
    module      = "container-registry"
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
| environment | | string | | yes |
| enable_iam_bindings | | string | | yes |
| region | | string | | yes |
| repositories | | string | | yes |
| repository_iam_bindings | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| registry_id | |
| registry_bucket_name | |
| registry_location | |
| registry_project | |
| registry_url | |
| registry_hostname | |
| artifact_registry_repositories | |
| artifact_registry_repository_ids | |
| artifact_registry_repository_names | |
| docker_repositories | |
| maven_repositories | |
| npm_repositories | |
| python_repositories | |
| apt_repositories | |
| yum_repositories | |
| helm_repositories | |
| go_repositories | |
| kfp_repositories | |
| repository_iam_bindings | |
| repository_iam_members | |
| repository_readers | |
| repository_writers | |
| repository_admins | |
| repository_cleanup_policies | |
| repository_maven_configs | |
| repository_docker_configs | |
| repository_virtual_configs | |
| repository_remote_configs | |
| repository_upstream_credentials | |
| cmek_encrypted_repositories | |
| vulnerability_scanning_configs | |
| sbom_configs | |
| gcr_service_account | |
| artifact_registry_service_account | |
| registry_bucket_iam_bindings | |
| repository_locations | |
| repository_formats | |
| total_repositories_count | |
| repositories_by_format | |
| repositories_by_location | |
| repositories_by_mode | |
| docker_registry_urls | |
| maven_registry_urls | |
| npm_registry_urls | |
| python_registry_urls | |
| go_registry_urls | |
| helm_registry_urls | |
| repository_tags | |
| cleanup_policy_summaries | |
| repository_immutable_tags | |
| repository_public_access | |
| enabled_apis | |
| gcr_image_pull_secrets | |
| artifact_registry_pull_commands | |
| repository_sizes | |
| repository_artifact_counts | |

## Resources Created

The following resources are created by this module:

- google_artifact_registry_repository
- google_artifact_registry_repository_iam_binding
- google_project_service

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
terraform import module.container-registry.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:29 AM
Module Version: 1.0.0
