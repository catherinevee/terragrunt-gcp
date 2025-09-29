# Cloud-cdn Module

## Overview
This module manages cloud cdn resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
```hcl
module "cloud-cdn" {
  source = "../../modules/networking/cloud-cdn"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
```

### Advanced Example
```hcl
module "cloud-cdn_advanced" {
  source = "../../modules/networking/cloud-cdn"

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
    module      = "cloud-cdn"
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
| name_prefix | | string | | yes |
| network_self_link | | string | | yes |
| backend_services | | string | | yes |
| origins | | string | | yes |
| url_maps | | string | | yes |
| ssl_certificates | | string | | yes |
| target_https_proxies | | string | | yes |
| global_forwarding_rules | | string | | yes |
| security_policies | | string | | yes |
| create_service_account | | string | | yes |
| service_account_name | | string | | yes |
| grant_service_account_roles | | string | | yes |
| service_account_roles | | string | | yes |
| create_instance_groups | | string | | yes |
| create_global_ips | | string | | yes |
| create_monitoring_alerts | | string | | yes |
| monitoring_alerts | | string | | yes |
| create_monitoring_dashboard | | string | | yes |
| advanced_cdn_config | | string | | yes |
| security_config | | string | | yes |
| performance_config | | string | | yes |
| cache_config | | string | | yes |
| cost_optimization_config | | string | | yes |
| labels | | string | | yes |
| lifecycle_config | | string | | yes |

## Outputs

| Name | Description |
|------|-------------|
| backend_service_ids | |
| backend_service_names | |
| backend_service_self_links | |
| backend_service_fingerprints | |
| backend_service_generated_ids | |
| backend_service_cdn_enabled | |
| health_check_ids | |
| health_check_names | |
| health_check_self_links | |
| instance_group_ids | |
| instance_group_names | |
| instance_group_self_links | |
| security_policy_ids | |
| security_policy_names | |
| security_policy_self_links | |
| security_policy_fingerprints | |
| managed_ssl_certificate_ids | |
| managed_ssl_certificate_names | |
| managed_ssl_certificate_domains | |
| managed_ssl_certificate_domain_status | |
| self_managed_ssl_certificate_ids | |
| self_managed_ssl_certificate_names | |
| self_managed_ssl_certificate_fingerprints | |
| url_map_ids | |
| url_map_names | |
| url_map_self_links | |
| url_map_fingerprints | |
| url_map_map_ids | |
| target_https_proxy_ids | |
| target_https_proxy_names | |
| target_https_proxy_self_links | |
| target_https_proxy_proxy_ids | |
| global_ip_addresses | |
| global_ip_ids | |
| global_ip_names | |
| global_ip_self_links | |
| global_forwarding_rule_ids | |
| global_forwarding_rule_names | |
| global_forwarding_rule_self_links | |
| global_forwarding_rule_ip_addresses | |
| global_forwarding_rule_labels | |
| service_account_email | |
| service_account_id | |
| service_account_name | |
| service_account_member | |
| monitoring_alert_policy_ids | |
| monitoring_alert_policy_names | |
| monitoring_dashboard_id | |
| cdn_configuration | |
| cache_policies | |
| security_configuration | |
| load_balancing_summary | |
| health_check_summary | |
| performance_summary | |
| cost_summary | |
| connection_info | |
| module_configuration | |
| applied_labels | |
| resource_counts | |

## Resources Created

The following resources are created by this module:

- google_compute_backend_service
- google_compute_global_address
- google_compute_global_forwarding_rule
- google_compute_health_check
- google_compute_instance_group
- google_compute_managed_ssl_certificate
- google_compute_security_policy
- google_compute_ssl_certificate
- google_compute_target_https_proxy
- google_compute_url_map
- google_monitoring_alert_policy
- google_monitoring_dashboard
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
terraform import module.cloud-cdn.RESOURCE_TYPE.NAME RESOURCE_ID
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
Generated: Mon, Sep 29, 2025  8:10:18 AM
Module Version: 1.0.0
