# CLI Reference

This document provides a comprehensive reference for all DriftMgr CLI commands and their options.

## Global Options

All DriftMgr commands support these global options:

```bash
driftmgr [GLOBAL_OPTIONS] <command> [COMMAND_OPTIONS]
```

### Global Options

| Option | Description | Default |
|--------|-------------|---------|
| `--config, -c` | Path to configuration file | `~/.driftmgr/config.yaml` |
| `--log-level` | Log level (debug, info, warn, error) | `info` |
| `--log-format` | Log format (text, json) | `text` |
| `--debug` | Enable debug mode | `false` |
| `--help, -h` | Show help information | - |
| `--version, -v` | Show version information | - |

## Core Commands

### `driftmgr init`

Initialize DriftMgr configuration and setup.

```bash
driftmgr init [OPTIONS]
```

#### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--config-dir` | Configuration directory | `~/.driftmgr` |
| `--force` | Overwrite existing configuration | `false` |

#### Examples

```bash
# Initialize with default settings
driftmgr init

# Initialize in custom directory
driftmgr init --config-dir /opt/driftmgr

# Force reinitialize
driftmgr init --force
```

### `driftmgr config`

Manage DriftMgr configuration.

```bash
driftmgr config <subcommand> [OPTIONS]
```

#### Subcommands

##### `driftmgr config show`

Display current configuration.

```bash
driftmgr config show [OPTIONS]
```

##### `driftmgr config validate`

Validate configuration file.

```bash
driftmgr config validate [OPTIONS]
```

##### `driftmgr config provider`

Configure cloud provider settings.

```bash
driftmgr config provider <provider> [OPTIONS]
```

**Providers**: `aws`, `azure`, `gcp`, `digitalocean`

**AWS Options**:
```bash
driftmgr config provider aws \
  --access-key-id ACCESS_KEY \
  --secret-access-key SECRET_KEY \
  --region REGION \
  --profile PROFILE
```

**Azure Options**:
```bash
driftmgr config provider azure \
  --subscription-id SUBSCRIPTION_ID \
  --tenant-id TENANT_ID \
  --client-id CLIENT_ID \
  --client-secret CLIENT_SECRET
```

**GCP Options**:
```bash
driftmgr config provider gcp \
  --project-id PROJECT_ID \
  --credentials-file CREDENTIALS_FILE \
  --service-account SERVICE_ACCOUNT
```

#### Examples

```bash
# Show current configuration
driftmgr config show

# Validate configuration
driftmgr config validate

# Configure AWS provider
driftmgr config provider aws \
  --access-key-id AKIAIOSFODNN7EXAMPLE \
  --secret-access-key wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY \
  --region us-east-1
```

## Drift Detection Commands

### `driftmgr detect`

Run drift detection on your infrastructure.

```bash
driftmgr detect [OPTIONS]
```

#### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--provider` | Cloud provider (aws, azure, gcp) | - |
| `--region` | AWS region | - |
| `--subscription-id` | Azure subscription ID | - |
| `--project-id` | GCP project ID | - |
| `--backend` | Terraform backend type | `local` |
| `--state-file` | Path to state file | `terraform.tfstate` |
| `--scan-type` | Scan type (quick, full) | `quick` |
| `--output` | Output format (table, json, yaml) | `table` |
| `--parallel` | Number of parallel workers | `10` |
| `--timeout` | Scan timeout | `10m` |
| `--include-deleted` | Include deleted resources | `false` |
| `--severity-filter` | Filter by severity (low, medium, high, critical) | - |
| `--resource-type` | Filter by resource type | - |
| `--tags` | Filter by tags (key=value) | - |

#### Examples

```bash
# Quick scan of local state file
driftmgr detect --backend local --state-file terraform.tfstate

# Full scan of AWS resources
driftmgr detect --provider aws --region us-east-1 --scan-type full

# Scan with custom output format
driftmgr detect --provider aws --output json

# Scan with filters
driftmgr detect --provider aws \
  --severity-filter "high,critical" \
  --resource-type "aws_s3_bucket" \
  --tags "Environment=production"
```

### `driftmgr results`

Manage drift detection results.

```bash
driftmgr results <subcommand> [OPTIONS]
```

#### Subcommands

##### `driftmgr results list`

List drift detection results.

```bash
driftmgr results list [OPTIONS]
```

**Options**:
| Option | Description | Default |
|--------|-------------|---------|
| `--scan-id` | Filter by scan ID | - |
| `--status` | Filter by status | - |
| `--severity` | Filter by severity | - |
| `--provider` | Filter by provider | - |
| `--limit` | Number of results to show | `20` |
| `--output` | Output format | `table` |

##### `driftmgr results show`

Show detailed information about a drift result.

```bash
driftmgr results show <drift-id> [OPTIONS]
```

**Options**:
| Option | Description | Default |
|--------|-------------|---------|
| `--output` | Output format | `table` |
| `--include-details` | Include detailed drift information | `true` |

##### `driftmgr results export`

Export drift results to file.

```bash
driftmgr results export [OPTIONS]
```

**Options**:
| Option | Description | Default |
|--------|-------------|---------|
| `--format` | Export format (json, csv, pdf) | `json` |
| `--output` | Output file path | `drift-results.json` |
| `--scan-id` | Filter by scan ID | - |
| `--date-from` | Start date (YYYY-MM-DD) | - |
| `--date-to` | End date (YYYY-MM-DD) | - |

#### Examples

```bash
# List recent drift results
driftmgr results list --limit 10

# Show specific drift result
driftmgr results show drift_123456789

# Export results to CSV
driftmgr results export --format csv --output results.csv

# Export results for specific date range
driftmgr results export \
  --date-from 2025-09-01 \
  --date-to 2025-09-30 \
  --format pdf
```

## Remediation Commands

### `driftmgr remediation`

Manage remediation jobs and strategies.

```bash
driftmgr remediation <subcommand> [OPTIONS]
```

#### Subcommands

##### `driftmgr remediation create`

Create a new remediation job.

```bash
driftmgr remediation create [OPTIONS]
```

**Options**:
| Option | Description | Default |
|--------|-------------|---------|
| `--drift-id` | Drift result ID to remediate | - |
| `--strategy` | Remediation strategy | - |
| `--auto-approve` | Auto-approve the job | `false` |
| `--dry-run` | Perform dry run only | `false` |
| `--timeout` | Job timeout | `30m` |
| `--options` | Additional options (JSON) | - |

##### `driftmgr remediation list`

List remediation jobs.

```bash
driftmgr remediation list [OPTIONS]
```

**Options**:
| Option | Description | Default |
|--------|-------------|---------|
| `--status` | Filter by status | - |
| `--strategy` | Filter by strategy | - |
| `--limit` | Number of jobs to show | `20` |
| `--output` | Output format | `table` |

##### `driftmgr remediation show`

Show detailed information about a remediation job.

```bash
driftmgr remediation show <job-id> [OPTIONS]
```

##### `driftmgr remediation approve`

Approve a pending remediation job.

```bash
driftmgr remediation approve <job-id> [OPTIONS]
```

##### `driftmgr remediation execute`

Execute a remediation job.

```bash
driftmgr remediation execute <job-id> [OPTIONS]
```

**Options**:
| Option | Description | Default |
|--------|-------------|---------|
| `--force` | Force execution without approval | `false` |
| `--dry-run` | Perform dry run only | `false` |

##### `driftmgr remediation cancel`

Cancel a remediation job.

```bash
driftmgr remediation cancel <job-id> [OPTIONS]
```

##### `driftmgr remediation logs`

Show logs for a remediation job.

```bash
driftmgr remediation logs <job-id> [OPTIONS]
```

**Options**:
| Option | Description | Default |
|--------|-------------|---------|
| `--follow` | Follow log output | `false` |
| `--tail` | Number of lines to show | `100` |

#### Examples

```bash
# Create remediation job
driftmgr remediation create \
  --drift-id drift_123456789 \
  --strategy terraform_apply \
  --auto-approve false

# List remediation jobs
driftmgr remediation list --status pending_approval

# Approve and execute job
driftmgr remediation approve job_123456789
driftmgr remediation execute job_123456789

# View job logs
driftmgr remediation logs job_123456789 --follow
```

## State Management Commands

### `driftmgr state`

Manage Terraform state files.

```bash
driftmgr state <subcommand> [OPTIONS]
```

#### Subcommands

##### `driftmgr state list`

List state files.

```bash
driftmgr state list [OPTIONS]
```

**Options**:
| Option | Description | Default |
|--------|-------------|---------|
| `--backend-type` | Filter by backend type | - |
| `--provider` | Filter by provider | - |
| `--output` | Output format | `table` |

##### `driftmgr state show`

Show state file details.

```bash
driftmgr state show <state-id> [OPTIONS]
```

##### `driftmgr state import`

Import a resource into state.

```bash
driftmgr state import [OPTIONS]
```

**Options**:
| Option | Description | Default |
|--------|-------------|---------|
| `--state-file` | Path to state file | - |
| `--resource-type` | Resource type | - |
| `--resource-name` | Resource name | - |
| `--resource-id` | Resource ID | - |
| `--attributes` | Resource attributes (JSON) | - |

##### `driftmgr state remove`

Remove a resource from state.

```bash
driftmgr state remove [OPTIONS]
```

**Options**:
| Option | Description | Default |
|--------|-------------|---------|
| `--state-file` | Path to state file | - |
| `--resource-type` | Resource type | - |
| `--resource-name` | Resource name | - |

##### `driftmgr state move`

Move a resource in state.

```bash
driftmgr state move [OPTIONS]
```

**Options**:
| Option | Description | Default |
|--------|-------------|---------|
| `--state-file` | Path to state file | - |
| `--from` | Source resource address | - |
| `--to` | Destination resource address | - |

#### Examples

```bash
# List state files
driftmgr state list

# Show state file details
driftmgr state show state_123456789

# Import existing resource
driftmgr state import \
  --state-file terraform.tfstate \
  --resource-type aws_s3_bucket \
  --resource-name existing_bucket \
  --resource-id existing-bucket-name

# Remove resource from state
driftmgr state remove \
  --state-file terraform.tfstate \
  --resource-type aws_s3_bucket \
  --resource-name example
```

## Discovery Commands

### `driftmgr discover`

Discover cloud resources and Terraform configurations.

```bash
driftmgr discover <subcommand> [OPTIONS]
```

#### Subcommands

##### `driftmgr discover backends`

Discover Terraform backends.

```bash
driftmgr discover backends [OPTIONS]
```

**Options**:
| Option | Description | Default |
|--------|-------------|---------|
| `--path` | Path to search for backends | `.` |
| `--recursive` | Search recursively | `true` |
| `--output` | Output format | `table` |

##### `driftmgr discover resources`

Discover cloud resources.

```bash
driftmgr discover resources [OPTIONS]
```

**Options**:
| Option | Description | Default |
|--------|-------------|---------|
| `--provider` | Cloud provider | - |
| `--region` | AWS region | - |
| `--subscription-id` | Azure subscription ID | - |
| `--project-id` | GCP project ID | - |
| `--services` | Services to discover (comma-separated) | - |
| `--output` | Output format | `table` |

#### Examples

```bash
# Discover Terraform backends
driftmgr discover backends --path /path/to/terraform

# Discover AWS resources
driftmgr discover resources --provider aws --region us-east-1

# Discover specific services
driftmgr discover resources \
  --provider aws \
  --services "ec2,s3,rds" \
  --region us-east-1
```

## Web Dashboard Commands

### `driftmgr web`

Start the web dashboard.

```bash
driftmgr web [OPTIONS]
```

#### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--host` | Host to bind to | `localhost` |
| `--port` | Port to bind to | `8080` |
| `--tls` | Enable TLS | `false` |
| `--cert-file` | TLS certificate file | - |
| `--key-file` | TLS private key file | - |
| `--auth` | Enable authentication | `false` |

#### Examples

```bash
# Start web dashboard
driftmgr web --port 8080

# Start with TLS
driftmgr web \
  --tls \
  --cert-file cert.pem \
  --key-file key.pem \
  --port 443

# Start with authentication
driftmgr web --auth --port 8080
```

## Utility Commands

### `driftmgr test`

Test DriftMgr functionality.

```bash
driftmgr test <subcommand> [OPTIONS]
```

#### Subcommands

##### `driftmgr test connection`

Test cloud provider connections.

```bash
driftmgr test connection [OPTIONS]
```

**Options**:
| Option | Description | Default |
|--------|-------------|---------|
| `--provider` | Provider to test | - |
| `--region` | AWS region | - |
| `--subscription-id` | Azure subscription ID | - |
| `--project-id` | GCP project ID | - |

##### `driftmgr test config`

Test configuration file.

```bash
driftmgr test config [OPTIONS]
```

#### Examples

```bash
# Test AWS connection
driftmgr test connection --provider aws --region us-east-1

# Test all configured providers
driftmgr test connection

# Test configuration
driftmgr test config
```

### `driftmgr logs`

View DriftMgr logs.

```bash
driftmgr logs [OPTIONS]
```

#### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--follow` | Follow log output | `false` |
| `--tail` | Number of lines to show | `100` |
| `--level` | Log level filter | - |
| `--component` | Component filter | - |

#### Examples

```bash
# View recent logs
driftmgr logs --tail 50

# Follow logs
driftmgr logs --follow

# Filter by level
driftmgr logs --level error
```

## Configuration Commands

### `driftmgr schedule`

Manage scheduled jobs.

```bash
driftmgr schedule <subcommand> [OPTIONS]
```

#### Subcommands

##### `driftmgr schedule create`

Create a scheduled job.

```bash
driftmgr schedule create [OPTIONS]
```

**Options**:
| Option | Description | Default |
|--------|-------------|---------|
| `--name` | Job name | - |
| `--cron` | Cron expression | - |
| `--command` | Command to execute | - |
| `--enabled` | Enable the job | `true` |

##### `driftmgr schedule list`

List scheduled jobs.

```bash
driftmgr schedule list [OPTIONS]
```

##### `driftmgr schedule show`

Show scheduled job details.

```bash
driftmgr schedule show <name> [OPTIONS]
```

##### `driftmgr schedule trigger`

Manually trigger a scheduled job.

```bash
driftmgr schedule trigger <name> [OPTIONS]
```

#### Examples

```bash
# Create scheduled drift detection
driftmgr schedule create \
  --name "daily-drift-check" \
  --cron "0 9 * * *" \
  --command "detect --provider aws --region us-east-1"

# List scheduled jobs
driftmgr schedule list

# Trigger job manually
driftmgr schedule trigger "daily-drift-check"
```

## Environment Variables

DriftMgr supports the following environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `DRIFTMGR_CONFIG_PATH` | Path to configuration file | `~/.driftmgr/config.yaml` |
| `DRIFTMGR_LOG_LEVEL` | Log level | `info` |
| `DRIFTMGR_LOG_FORMAT` | Log format | `text` |
| `DRIFTMGR_DEBUG` | Enable debug mode | `false` |
| `AWS_ACCESS_KEY_ID` | AWS access key | - |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | - |
| `AWS_REGION` | AWS region | - |
| `AZURE_CLIENT_ID` | Azure client ID | - |
| `AZURE_CLIENT_SECRET` | Azure client secret | - |
| `AZURE_TENANT_ID` | Azure tenant ID | - |
| `GCP_PROJECT_ID` | GCP project ID | - |
| `GOOGLE_APPLICATION_CREDENTIALS` | GCP credentials file | - |

## Exit Codes

DriftMgr uses the following exit codes:

| Code | Description |
|------|-------------|
| `0` | Success |
| `1` | General error |
| `2` | Configuration error |
| `3` | Authentication error |
| `4` | Network error |
| `5` | Provider error |
| `6` | Validation error |

## Examples

### Complete Workflow

```bash
# 1. Initialize DriftMgr
driftmgr init

# 2. Configure AWS provider
driftmgr config provider aws \
  --access-key-id YOUR_ACCESS_KEY \
  --secret-access-key YOUR_SECRET_KEY \
  --region us-east-1

# 3. Test connection
driftmgr test connection --provider aws

# 4. Discover backends
driftmgr discover backends --path .

# 5. Run drift detection
driftmgr detect --provider aws --region us-east-1

# 6. View results
driftmgr results list

# 7. Create remediation job
driftmgr remediation create \
  --drift-id drift_123456789 \
  --strategy terraform_apply

# 8. Start web dashboard
driftmgr web --port 8080
```

### Batch Operations

```bash
# Run detection for multiple regions
for region in us-east-1 us-west-2 eu-west-1; do
  driftmgr detect --provider aws --region $region
done

# Export results for all scans
driftmgr results export --format csv --output all-results.csv

# Create remediation jobs for high-severity drifts
driftmgr results list --severity high --output json | \
  jq -r '.drifts[].drift_id' | \
  xargs -I {} driftmgr remediation create --drift-id {} --strategy terraform_apply
```

## Next Steps

- **[Getting Started Guide](getting-started.md)** - Learn the basics
- **[Configuration Guide](configuration.md)** - Advanced configuration
- **[Web Dashboard Guide](web-dashboard.md)** - Using the web interface
- **[API Documentation](../api/rest-api.md)** - REST API reference
