# Basic Usage Examples

This guide provides practical examples of using DriftMgr for common scenarios. These examples will help you get started with drift detection, remediation, and state management.

## Prerequisites

Before running these examples, ensure you have:

- DriftMgr installed and configured
- Access to a cloud provider (AWS, Azure, GCP)
- Terraform installed
- Basic understanding of Terraform concepts

## Example 1: Basic Drift Detection

### Scenario
You have a simple AWS S3 bucket managed by Terraform, and you want to detect if any configuration changes have occurred outside of Terraform.

### Setup

1. **Create a test Terraform configuration:**

```hcl
# main.tf
provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "example" {
  bucket = "driftmgr-example-${random_string.bucket_suffix.result}"
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_versioning" "example" {
  bucket = aws_s3_bucket.example.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

2. **Initialize and apply Terraform:**

```bash
# Initialize Terraform
terraform init

# Apply the configuration
terraform apply -auto-approve
```

3. **Run DriftMgr detection:**

```bash
# Discover the Terraform backend
driftmgr discover backends --path .

# Run drift detection
driftmgr detect --backend local --state-file terraform.tfstate
```

### Expected Output

```json
{
  "scan_id": "scan_123456789",
  "status": "completed",
  "drift_count": 0,
  "resources_scanned": 2,
  "scan_duration": "15s"
}
```

### Simulate Drift

1. **Manually modify the S3 bucket:**

```bash
# Get the bucket name
BUCKET_NAME=$(terraform output -raw bucket_name)

# Disable versioning (simulate drift)
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Suspended
```

2. **Run detection again:**

```bash
driftmgr detect --backend local --state-file terraform.tfstate
```

### Expected Drift Result

```json
{
  "scan_id": "scan_123456790",
  "status": "completed",
  "drift_count": 1,
  "drifts": [
    {
      "drift_id": "drift_001",
      "resource_type": "aws_s3_bucket_versioning",
      "resource_name": "example",
      "severity": "medium",
      "drift_type": "configuration",
      "details": {
        "expected": {
          "versioning_configuration": {
            "status": "Enabled"
          }
        },
        "actual": {
          "versioning_configuration": {
            "status": "Suspended"
          }
        }
      }
    }
  ]
}
```

## Example 2: Remediation Workflow

### Scenario
You've detected drift in your infrastructure and want to remediate it using DriftMgr's automated remediation features.

### Create Remediation Job

```bash
# Create a remediation job for the detected drift
driftmgr remediation create \
  --drift-id drift_001 \
  --strategy terraform_apply \
  --auto-approve false
```

### Expected Output

```json
{
  "job_id": "job_123456789",
  "drift_id": "drift_001",
  "strategy": "terraform_apply",
  "status": "pending_approval",
  "created_at": "2025-09-23T10:00:00Z"
}
```

### Approve and Execute

```bash
# List pending jobs
driftmgr remediation list --status pending_approval

# Approve the job
driftmgr remediation approve --job-id job_123456789

# Execute the remediation
driftmgr remediation execute --job-id job_123456789
```

### Monitor Progress

```bash
# Check job status
driftmgr remediation show --job-id job_123456789

# View job logs
driftmgr remediation logs --job-id job_123456789
```

## Example 3: Multi-Resource Drift Detection

### Scenario
You have a more complex infrastructure with multiple resources and want to detect drift across all of them.

### Setup Complex Infrastructure

```hcl
# main.tf
provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "driftmgr-example-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "driftmgr-example-igw"
  }
}

# Subnet
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "driftmgr-example-subnet"
  }
}

# Security Group
resource "aws_security_group" "main" {
  name_prefix = "driftmgr-example-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "driftmgr-example-sg"
  }
}

# EC2 Instance
resource "aws_instance" "main" {
  ami                    = "ami-0c02fb55956c7d4"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.main.id]

  tags = {
    Name = "driftmgr-example-instance"
  }
}
```

### Apply and Detect

```bash
# Apply the configuration
terraform apply -auto-approve

# Run comprehensive drift detection
driftmgr detect --backend local --state-file terraform.tfstate --full
```

### Simulate Multiple Drifts

```bash
# Get resource IDs
VPC_ID=$(terraform output -raw vpc_id)
INSTANCE_ID=$(terraform output -raw instance_id)

# Modify VPC DNS settings
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames Value=false

# Add a tag to the instance
aws ec2 create-tags \
  --resources $INSTANCE_ID \
  --tags Key=Environment,Value=Production
```

### Run Detection Again

```bash
driftmgr detect --backend local --state-file terraform.tfstate --full
```

### Expected Results

```json
{
  "scan_id": "scan_123456791",
  "status": "completed",
  "drift_count": 2,
  "drifts": [
    {
      "drift_id": "drift_002",
      "resource_type": "aws_vpc",
      "resource_name": "main",
      "severity": "high",
      "drift_type": "configuration",
      "details": {
        "expected": {
          "enable_dns_hostnames": true
        },
        "actual": {
          "enable_dns_hostnames": false
        }
      }
    },
    {
      "drift_id": "drift_003",
      "resource_type": "aws_instance",
      "resource_name": "main",
      "severity": "low",
      "drift_type": "tags",
      "details": {
        "expected": {
          "tags": {
            "Name": "driftmgr-example-instance"
          }
        },
        "actual": {
          "tags": {
            "Name": "driftmgr-example-instance",
            "Environment": "Production"
          }
        }
      }
    }
  ]
}
```

## Example 4: State Management Operations

### Scenario
You need to manage Terraform state files, including importing existing resources and removing resources from state.

### Import Existing Resource

```bash
# Import an existing S3 bucket
driftmgr state import \
  --backend local \
  --state-file terraform.tfstate \
  --resource-type aws_s3_bucket \
  --resource-name existing_bucket \
  --resource-id existing-bucket-name
```

### Remove Resource from State

```bash
# Remove a resource from state (without destroying it)
driftmgr state remove \
  --backend local \
  --state-file terraform.tfstate \
  --resource-type aws_s3_bucket \
  --resource-name example
```

### Move Resource in State

```bash
# Move a resource to a different name
driftmgr state move \
  --backend local \
  --state-file terraform.tfstate \
  --from aws_s3_bucket.example \
  --to aws_s3_bucket.renamed_example
```

## Example 5: Scheduled Drift Detection

### Scenario
You want to set up automated drift detection that runs on a schedule.

### Configure Scheduled Detection

```bash
# Set up a scheduled drift detection job
driftmgr schedule create \
  --name "daily-drift-check" \
  --cron "0 9 * * *" \
  --command "detect --backend s3 --bucket my-terraform-state --key prod/terraform.tfstate" \
  --enabled true
```

### List Scheduled Jobs

```bash
# List all scheduled jobs
driftmgr schedule list

# Show details of a specific job
driftmgr schedule show --name "daily-drift-check"
```

### Manual Trigger

```bash
# Manually trigger a scheduled job
driftmgr schedule trigger --name "daily-drift-check"
```

## Example 6: Web Dashboard Usage

### Scenario
You want to use the web dashboard to monitor and manage drift detection.

### Start Web Dashboard

```bash
# Start the web server
driftmgr web --port 8080 --host 0.0.0.0
```

### Access Dashboard

Open your browser and navigate to `http://localhost:8080`

### Dashboard Features

1. **Real-time Monitoring**: View live drift detection results
2. **Resource Explorer**: Browse your infrastructure resources
3. **Compliance Dashboard**: Check compliance status
4. **Remediation Workflows**: Manage remediation jobs
5. **Analytics**: View trends and insights

## Example 7: API Usage

### Scenario
You want to integrate DriftMgr with your CI/CD pipeline using the REST API.

### Start Drift Detection via API

```bash
# Start a drift detection scan
curl -X POST http://localhost:8080/api/v1/drift/detect \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "provider": "aws",
    "region": "us-east-1",
    "scan_type": "quick"
  }'
```

### Check Scan Status

```bash
# Get scan status
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://localhost:8080/api/v1/drift/scans/scan_123456789
```

### List Drift Results

```bash
# Get drift results
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://localhost:8080/api/v1/drift/results
```

### Create Remediation Job

```bash
# Create remediation job
curl -X POST http://localhost:8080/api/v1/remediation/jobs \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "drift_id": "drift_001",
    "strategy": "terraform_apply",
    "auto_approve": false
  }'
```

## Example 8: Multi-Cloud Detection

### Scenario
You have resources across multiple cloud providers and want to detect drift across all of them.

### Configure Multiple Providers

```bash
# Configure AWS
driftmgr config provider aws \
  --access-key-id YOUR_AWS_ACCESS_KEY \
  --secret-access-key YOUR_AWS_SECRET_KEY \
  --region us-east-1

# Configure Azure
driftmgr config provider azure \
  --subscription-id YOUR_AZURE_SUBSCRIPTION_ID \
  --tenant-id YOUR_AZURE_TENANT_ID

# Configure GCP
driftmgr config provider gcp \
  --project-id YOUR_GCP_PROJECT_ID \
  --credentials-file /path/to/gcp-credentials.json
```

### Run Multi-Cloud Detection

```bash
# Detect drift across all configured providers
driftmgr detect --all-providers --full
```

### Provider-Specific Detection

```bash
# Detect drift for specific providers
driftmgr detect --provider aws --region us-east-1
driftmgr detect --provider azure --subscription-id your-subscription
driftmgr detect --provider gcp --project-id your-project
```

## Example 9: Custom Remediation Strategy

### Scenario
You want to create a custom remediation strategy for specific types of drift.

### Create Custom Strategy

```bash
# Create a custom remediation strategy
driftmgr remediation strategy create \
  --name "custom-s3-fix" \
  --description "Custom S3 bucket remediation" \
  --script /path/to/custom-script.sh \
  --resource-types "aws_s3_bucket"
```

### Use Custom Strategy

```bash
# Create remediation job with custom strategy
driftmgr remediation create \
  --drift-id drift_001 \
  --strategy custom-s3-fix \
  --auto-approve false
```

## Example 10: Compliance Checking

### Scenario
You want to check compliance against specific policies and frameworks.

### Run Compliance Check

```bash
# Run compliance check against SOC2 framework
driftmgr compliance check \
  --framework soc2 \
  --provider aws \
  --region us-east-1
```

### Generate Compliance Report

```bash
# Generate compliance report
driftmgr compliance report \
  --framework soc2 \
  --format pdf \
  --output compliance-report.pdf
```

## Best Practices

### 1. Regular Drift Detection

```bash
# Set up regular drift detection
driftmgr schedule create \
  --name "hourly-drift-check" \
  --cron "0 * * * *" \
  --command "detect --quick"
```

### 2. Automated Remediation

```bash
# Set up automated remediation for low-risk changes
driftmgr remediation create \
  --drift-id drift_001 \
  --strategy terraform_apply \
  --auto-approve true \
  --severity-filter "low"
```

### 3. Monitoring and Alerting

```bash
# Set up alerts for high-severity drift
driftmgr alerts create \
  --name "high-severity-drift" \
  --condition "severity == 'high'" \
  --action "email:admin@company.com"
```

## Troubleshooting

### Common Issues

1. **Authentication Errors**: Verify cloud provider credentials
2. **Permission Errors**: Check IAM roles and policies
3. **Network Issues**: Verify network connectivity
4. **State File Issues**: Check state file format and location

### Debug Mode

```bash
# Run with debug logging
driftmgr detect --debug --log-level debug
```

### Get Help

```bash
# Get help for any command
driftmgr --help
driftmgr detect --help
driftmgr remediation --help
```

## Next Steps

- **[Advanced Scenarios](advanced-scenarios.md)** - More complex use cases
- **[Integration Examples](integrations.md)** - Third-party integrations
- **[Configuration Examples](configuration.md)** - Configuration file examples
- **[CLI Reference](../user-guide/cli-reference.md)** - Complete command reference
