# Getting Started with DriftMgr

This guide will help you get up and running with DriftMgr quickly. DriftMgr is a comprehensive Terraform drift detection and remediation tool for multi-cloud environments.

## What is DriftMgr?

DriftMgr helps you:
- **Detect drift** in your Terraform-managed infrastructure
- **Remediate issues** automatically or with approval workflows
- **Monitor compliance** across multiple cloud providers
- **Manage state files** with advanced operations
- **Discover resources** across your cloud environments

## Prerequisites

Before you begin, ensure you have:

- **Terraform** 1.5+ installed
- **Terragrunt** 0.50+ (optional but recommended)
- **Go** 1.21+ (for building from source)
- **Docker** (for containerized deployment)
- **Access** to your cloud provider accounts (AWS, Azure, GCP, DigitalOcean)

## Installation

### Option 1: Download Binary (Recommended)

Download the latest release for your platform:

```bash
# Linux/macOS
curl -L https://github.com/catherinevee/driftmgr/releases/latest/download/driftmgr-linux-amd64 -o driftmgr
chmod +x driftmgr
sudo mv driftmgr /usr/local/bin/

# Windows
# Download driftmgr-windows-amd64.exe from releases page
```

### Option 2: Build from Source

```bash
git clone https://github.com/catherinevee/driftmgr.git
cd driftmgr
make build
```

### Option 3: Docker

```bash
docker pull catherinevee/driftmgr:latest
```

## Quick Start

### 1. Initialize DriftMgr

```bash
# Initialize configuration
driftmgr init

# This creates a default configuration file
ls -la ~/.driftmgr/
```

### 2. Configure Cloud Provider

```bash
# Configure AWS (example)
driftmgr config provider aws \
  --access-key-id YOUR_ACCESS_KEY \
  --secret-access-key YOUR_SECRET_KEY \
  --region us-east-1
```

### 3. Discover Your Infrastructure

```bash
# Discover Terraform backends
driftmgr discover backends

# Discover resources
driftmgr discover resources --provider aws
```

### 4. Run Drift Detection

```bash
# Quick scan
driftmgr detect --quick

# Full scan with detailed output
driftmgr detect --full --output json
```

### 5. View Results

```bash
# List drift results
driftmgr results list

# Get detailed view of specific result
driftmgr results show <result-id>
```

## Basic Configuration

Create a configuration file at `~/.driftmgr/config.yaml`:

```yaml
# DriftMgr Configuration
server:
  host: "localhost"
  port: 8080
  auth:
    enabled: false

providers:
  aws:
    regions: ["us-east-1", "us-west-2"]
    enabled: true
  azure:
    subscriptions: ["your-subscription-id"]
    enabled: false
  gcp:
    projects: ["your-project-id"]
    enabled: false

detection:
  schedule: "0 */6 * * *"  # Every 6 hours
  quick_scan_timeout: "30s"
  full_scan_timeout: "10m"

remediation:
  auto_approve: false
  strategies:
    - "terraform_apply"
    - "terraform_import"
    - "manual_review"
```

## Your First Drift Detection

Let's run through a complete example:

### 1. Set up a test environment

```bash
# Create a test directory
mkdir driftmgr-test
cd driftmgr-test

# Initialize Terraform
terraform init

# Create a simple resource
cat > main.tf << EOF
resource "aws_s3_bucket" "test" {
  bucket = "driftmgr-test-$(date +%s)"
}
EOF

# Apply the configuration
terraform apply -auto-approve
```

### 2. Run DriftMgr

```bash
# Discover the state
driftmgr discover backends --path .

# Run drift detection
driftmgr detect --backend local --state-file terraform.tfstate
```

### 3. Simulate drift

```bash
# Manually modify the resource (simulate drift)
aws s3api put-bucket-tagging \
  --bucket your-bucket-name \
  --tagging 'TagSet=[{Key=Environment,Value=Production}]'
```

### 4. Detect the drift

```bash
# Run detection again
driftmgr detect --backend local --state-file terraform.tfstate

# View the drift
driftmgr results list
```

## Web Dashboard

Start the web dashboard for a visual interface:

```bash
# Start the web server
driftmgr web --port 8080

# Open in browser
open http://localhost:8080
```

The web dashboard provides:
- **Real-time monitoring** of drift detection
- **Interactive resource explorer**
- **Compliance dashboard**
- **Remediation workflows**

## Next Steps

Now that you have DriftMgr running, explore these topics:

1. **[Configuration Guide](configuration.md)** - Advanced configuration options
2. **[CLI Reference](cli-reference.md)** - Complete command reference
3. **[Web Dashboard](web-dashboard.md)** - Using the web interface
4. **[API Documentation](../api/rest-api.md)** - REST API usage
5. **[Examples](../examples/basic-usage.md)** - More usage examples

## Common Commands

Here are the most frequently used commands:

```bash
# Initialize DriftMgr
driftmgr init

# Discover infrastructure
driftmgr discover backends
driftmgr discover resources

# Run drift detection
driftmgr detect --quick
driftmgr detect --full

# View results
driftmgr results list
driftmgr results show <id>

# Start web dashboard
driftmgr web

# Get help
driftmgr --help
driftmgr <command> --help
```

## Troubleshooting

If you encounter issues:

1. **Check the logs**: `driftmgr logs`
2. **Verify configuration**: `driftmgr config validate`
3. **Test connectivity**: `driftmgr test connection`
4. **See [Troubleshooting Guide](troubleshooting.md)** for common issues

## Getting Help

- **Documentation**: Browse this documentation
- **Issues**: Report bugs on GitHub
- **Discussions**: Join community discussions
- **Examples**: Check the examples directory

Welcome to DriftMgr! 🚀
