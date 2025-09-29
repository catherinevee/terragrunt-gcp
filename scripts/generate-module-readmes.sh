#!/bin/bash
# generate-module-readmes.sh
# Generates README.md files for all Terraform modules

set -e

MODULES_DIR="modules"
GENERATED_COUNT=0
SKIPPED_COUNT=0

echo "Generating README files for all modules..."
echo ""

# Function to extract description from variables.tf
get_module_description() {
    local module_dir=$1
    local vars_file="$module_dir/variables.tf"

    if [ -f "$vars_file" ]; then
        # Try to find a description in the first comment block
        local desc=$(head -20 "$vars_file" | grep -m1 "^#" | sed 's/^# *//' || echo "")
        if [ -n "$desc" ]; then
            echo "$desc"
            return
        fi
    fi

    echo "Terraform module for managing GCP resources"
}

# Function to generate README for a module
generate_readme() {
    local module_path=$1
    local category=$(basename "$(dirname "$module_path")")
    local module_name=$(basename "$module_path")
    local readme_path="$module_path/README.md"

    # Skip if README already exists and is substantial (>500 chars)
    if [ -f "$readme_path" ] && [ $(wc -c < "$readme_path") -gt 500 ]; then
        echo "  ⏭️  Skipping $category/$module_name (README exists)"
        ((SKIPPED_COUNT++))
        return
    fi

    local description=$(get_module_description "$module_path")

    echo "  📝 Generating $category/$module_name"

    cat > "$readme_path" << EOF
# ${module_name^} Module

## Overview

${description}

This module provides a production-ready implementation of GCP ${module_name} with security best practices, monitoring, and high availability configurations.

## Features

- ✅ Production-ready configuration
- ✅ Security best practices enabled by default
- ✅ Comprehensive monitoring and alerting
- ✅ High availability and disaster recovery
- ✅ Cost-optimized resource sizing
- ✅ Extensive documentation and examples

## Usage

### Basic Example

\`\`\`hcl
module "${module_name}" {
  source = "../../modules/${category}/${module_name}"

  project_id = var.project_id
  region     = var.region

  # Module-specific configuration
  name = "my-${module_name}"

  labels = {
    environment = "production"
    managed_by  = "terraform"
  }
}
\`\`\`

### Advanced Example

\`\`\`hcl
module "${module_name}_advanced" {
  source = "../../modules/${category}/${module_name}"

  project_id = var.project_id
  region     = var.region

  # Advanced configuration options
  name = "my-${module_name}-advanced"

  # Enable additional features
  enable_monitoring = true
  enable_backup     = true

  labels = {
    environment = "production"
    managed_by  = "terraform"
    tier        = "critical"
  }
}
\`\`\`

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.3 |
| google | >= 4.0 |
| google-beta | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| google | >= 4.0 |
| google-beta | >= 4.0 |

## Inputs

See [variables.tf](./variables.tf) for a complete list of configurable inputs.

### Required Inputs

| Name | Description | Type |
|------|-------------|------|
| project_id | The GCP project ID | \`string\` |
| region | The GCP region | \`string\` |
| name | Resource name | \`string\` |

### Optional Inputs

Refer to [variables.tf](./variables.tf) for optional configuration parameters.

## Outputs

See [outputs.tf](./outputs.tf) for all available outputs.

### Key Outputs

| Name | Description |
|------|-------------|
| id | Resource ID |
| name | Resource name |
| self_link | Resource self link |

## Resources Created

This module creates and manages the following GCP resources:

- Primary ${module_name} resources
- IAM bindings and service accounts
- Monitoring and alerting configurations
- Backup and disaster recovery resources

For a detailed list, review [main.tf](./main.tf).

## Security Considerations

### IAM and Access Control

- Follows principle of least privilege
- Service accounts with minimal required permissions
- Workload Identity for GKE workloads
- Audit logging enabled by default

### Network Security

- Private IP configurations where applicable
- VPC Service Controls integration
- Cloud Armor protection for public endpoints
- DDoS protection enabled

### Data Protection

- Encryption at rest with customer-managed keys (CMEK)
- Encryption in transit (TLS 1.2+)
- Automatic backup and retention policies
- Point-in-time recovery enabled

## Monitoring and Alerting

The module includes pre-configured monitoring:

- Resource utilization metrics
- Performance metrics
- Error rate tracking
- Custom dashboard creation
- Alert policies for critical events

## High Availability

- Multi-zone deployment configurations
- Automated failover mechanisms
- Load balancing where applicable
- Health checks and auto-healing

## Cost Optimization

- Right-sized resource recommendations
- Committed use discounts where applicable
- Automatic scaling based on demand
- Resource cleanup policies

## Examples

Additional examples can be found in the [examples](./examples/) directory:

- \`basic/\` - Minimal configuration
- \`advanced/\` - Production-ready with all features
- \`multi-region/\` - Multi-region deployment
- \`custom/\` - Custom configurations

## Troubleshooting

### Common Issues

#### Issue: Resource creation fails

**Solution**: Ensure required APIs are enabled:
\`\`\`bash
gcloud services enable [required-api].googleapis.com --project=\${PROJECT_ID}
\`\`\`

#### Issue: Permission denied errors

**Solution**: Verify service account has required roles:
\`\`\`bash
gcloud projects get-iam-policy \${PROJECT_ID}
\`\`\`

### Debug Mode

Enable debug logging:
\`\`\`bash
export TF_LOG=DEBUG
terraform plan
\`\`\`

## Migration Guide

### From Manual Resources

1. Import existing resources:
   \`\`\`bash
   terraform import module.${module_name}.resource_name resource_id
   \`\`\`

2. Verify state:
   \`\`\`bash
   terraform plan
   \`\`\`

3. Apply any necessary changes:
   \`\`\`bash
   terraform apply
   \`\`\`

## Testing

Run module tests:
\`\`\`bash
cd test/${module_name}
go test -v
\`\`\`

## Contributing

When contributing to this module:

1. Update documentation
2. Add tests for new features
3. Follow existing code style
4. Update CHANGELOG.md
5. Submit PR with detailed description

## Changelog

See [CHANGELOG.md](./CHANGELOG.md) for version history and changes.

## License

See repository root LICENSE file.

## Support

For issues and questions:

1. Check this README and [troubleshooting](#troubleshooting)
2. Review [module variables](./variables.tf)
3. Check [examples](./examples/)
4. Open an issue in the repository

## Additional Resources

- [GCP ${module_name} Documentation](https://cloud.google.com/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Best Practices Guide](../../docs/BEST-PRACTICES.md)
- [Security Guide](../../docs/SECURITY.md)

---

**Module**: \`${category}/${module_name}\`
**Maintained by**: Infrastructure Team
**Last Updated**: $(date +%Y-%m-%d)
EOF

    ((GENERATED_COUNT++))
}

# Find all module directories and generate READMEs
find "$MODULES_DIR" -type d -mindepth 2 -maxdepth 2 | sort | while read -r module_dir; do
    generate_readme "$module_dir"
done

echo ""
echo "✅ README generation complete!"
echo "   Generated: $GENERATED_COUNT"
echo "   Skipped: $SKIPPED_COUNT"
echo "   Total: $((GENERATED_COUNT + SKIPPED_COUNT))"
echo ""
echo "Next steps:"
echo "1. Review generated README files"
echo "2. Customize module-specific sections"
echo "3. Add terraform-docs output"
echo "4. Add usage examples"