#!/bin/bash
# generate-module-docs.sh - Generate README documentation for all modules

set -e

echo "Generating module documentation..."

for module_dir in modules/*/*/; do
  if [ -d "$module_dir" ]; then
    category=$(basename "$(dirname "$module_dir")")
    module=$(basename "$module_dir")

    echo "Generating README for $category/$module..."

    # Extract variables from variables.tf
    variables=""
    if [ -f "$module_dir/variables.tf" ]; then
      variables=$(grep -E "^variable " "$module_dir/variables.tf" | sed 's/variable "\([^"]*\)".*/| \1 | | string | | yes |/' || echo "")
    fi

    # Extract outputs from outputs.tf
    outputs=""
    if [ -f "$module_dir/outputs.tf" ]; then
      outputs=$(grep -E "^output " "$module_dir/outputs.tf" | sed 's/output "\([^"]*\)".*/| \1 | |/' || echo "")
    fi

    # Extract resources from main.tf
    resources=""
    if [ -f "$module_dir/main.tf" ]; then
      resources=$(grep -E "^resource " "$module_dir/main.tf" | sed 's/resource "\([^"]*\)".*/- \1/' | sort -u || echo "")
    fi

    cat > "$module_dir/README.md" << EOF
# ${module^} Module

## Overview
This module manages ${module//-/ } resources in Google Cloud Platform.

## Features
- Automated resource provisioning
- Configurable parameters
- Security best practices
- High availability support (where applicable)

## Usage

### Basic Example
\`\`\`hcl
module "$module" {
  source = "../../modules/$category/$module"

  project_id  = var.project_id
  environment = var.environment

  # Add other required variables based on your needs
}
\`\`\`

### Advanced Example
\`\`\`hcl
module "${module}_advanced" {
  source = "../../modules/$category/$module"

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
    module      = "$module"
  }
}
\`\`\`

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
$variables

## Outputs

| Name | Description |
|------|-------------|
$outputs

## Resources Created

The following resources are created by this module:

$resources

## IAM Permissions Required

The service account running Terraform needs the following roles:
- \`roles/editor\` (or more specific roles based on resources)

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
\`\`\`bash
# Solution: Ensure service account has required roles
gcloud projects add-iam-policy-binding PROJECT_ID \\
  --member="serviceAccount:SA_EMAIL" \\
  --role="roles/editor"
\`\`\`

**Issue**: Resource already exists
\`\`\`bash
# Solution: Import existing resource
terraform import module.$module.RESOURCE_TYPE.NAME RESOURCE_ID
\`\`\`

## Development

### Testing
\`\`\`bash
# Run tests
cd test/
go test -v -timeout 30m
\`\`\`

### Validation
\`\`\`bash
# Validate module
terraform init
terraform validate
terraform fmt -check
\`\`\`

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
Generated: $(date)
Module Version: 1.0.0
EOF

    echo "✅ Generated README for $category/$module"
  fi
done

echo "✅ Documentation generation complete"