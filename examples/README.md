# Terragrunt-GCP Examples

This directory contains comprehensive examples demonstrating various use cases and deployment patterns for the terragrunt-gcp project. Each example showcases different aspects of Google Cloud Platform infrastructure management using Terragrunt.

## Available Examples

### 1. Basic Example (`basic/`)

**Purpose**: Simple development environment setup
**Complexity**: Beginner
**Use Case**: Learning, development, testing

**What's Included**:
- Single VM instance with nginx
- Basic VPC networking with subnet
- Simple firewall rules
- Basic IAM service account
- Minimal monitoring setup

**Key Features**:
- Cost-optimized for development
- Simple architecture
- Easy to understand and modify
- Quick deployment (< 10 minutes)

**Resources Created**:
- 1 VPC network with 1 subnet
- 1 compute instance (e2-micro)
- 3 firewall rules (SSH, HTTP, HTTPS)
- 1 service account
- Basic monitoring

**Estimated Monthly Cost**: $10-20 USD

### 2. Multi-Tier Example (`multi-tier/`)

**Purpose**: Three-tier web application architecture
**Complexity**: Intermediate
**Use Case**: Production-ready web applications

**What's Included**:
- Web tier with load balancing and auto-scaling
- Application tier with internal load balancing
- Data tier with managed databases
- Comprehensive networking
- Advanced monitoring and alerting
- Backup and disaster recovery

**Key Features**:
- Scalable architecture
- High availability
- Security best practices
- Performance optimization
- Automated scaling

**Resources Created**:
- 2 VPC networks with multiple subnets
- 3 managed instance groups (web, app, data tiers)
- Global and regional load balancers
- Cloud SQL database with read replicas
- Redis cache cluster
- Storage buckets with lifecycle policies
- Comprehensive monitoring and alerting

**Estimated Monthly Cost**: $500-2000 USD (depending on traffic)

### 3. Production Example (`production/`)

**Purpose**: Enterprise-grade production environment
**Complexity**: Advanced
**Use Case**: Large-scale production applications with strict compliance requirements

**What's Included**:
- Multi-region deployment for disaster recovery
- Advanced security configurations
- Comprehensive monitoring and SLOs
- Automated backup and recovery
- Compliance controls (SOC2, PCI-DSS, ISO27001)
- Cost optimization strategies
- Advanced networking with Private Service Connect

**Key Features**:
- Multi-region architecture
- 99.99% availability target
- Advanced security (Shielded VMs, Confidential Computing)
- Comprehensive compliance
- Advanced monitoring and SLOs
- Automated disaster recovery
- Cost optimization

**Resources Created**:
- Multi-region VPC networks with peering
- Regional managed instance groups with auto-scaling
- Global HTTPS load balancer with CDN
- Highly available Cloud SQL with cross-region replicas
- Redis clusters with high availability
- Multiple storage buckets with advanced lifecycle
- Comprehensive monitoring, logging, and alerting
- Backup and disaster recovery automation

**Estimated Monthly Cost**: $2000-10000+ USD (enterprise scale)

## Quick Start

### Prerequisites

1. **Google Cloud Platform Account**
   - Active GCP project with billing enabled
   - Appropriate IAM permissions (Editor or Owner role)

2. **Required Tools**
   ```bash
   # Install Terraform
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/

   # Install Terragrunt
   wget https://github.com/gruntwork-io/terragrunt/releases/download/v0.53.0/terragrunt_linux_amd64
   sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt
   sudo chmod +x /usr/local/bin/terragrunt

   # Install gcloud CLI
   curl https://sdk.cloud.google.com | bash
   exec -l $SHELL
   gcloud init
   ```

3. **Authentication Setup**
   ```bash
   # Option 1: Application Default Credentials (recommended for development)
   gcloud auth application-default login

   # Option 2: Service Account (recommended for CI/CD)
   gcloud auth activate-service-account --key-file=path/to/service-account-key.json

   # Set project
   export GCP_PROJECT_ID="your-project-id"
   gcloud config set project $GCP_PROJECT_ID
   ```

### Deploying Examples

#### Basic Example

```bash
# Navigate to basic example
cd examples/basic

# Review configuration
cat terragrunt.hcl

# Plan deployment
terragrunt plan

# Deploy infrastructure
terragrunt apply

# Access the deployed application
# The external IP will be shown in the output
curl http://EXTERNAL_IP/health

# Clean up
terragrunt destroy
```

#### Multi-Tier Example

```bash
# Navigate to multi-tier example
cd examples/multi-tier

# Deploy in dependency order
# 1. Network infrastructure
cd networking
terragrunt apply

# 2. IAM and security
cd ../iam
terragrunt apply

# 3. Database tier
cd ../data-tier
terragrunt apply

# 4. Application tier
cd ../app-tier
terragrunt apply

# 5. Web tier
cd ../web-tier
terragrunt apply

# 6. Load balancer
cd ../load-balancer
terragrunt apply

# Or deploy everything at once from root
cd ..
terragrunt run-all apply

# Clean up
terragrunt run-all destroy
```

#### Production Example

```bash
# Navigate to production example
cd examples/production

# Review the comprehensive configuration
cat terragrunt.hcl

# Deploy infrastructure components
terragrunt run-all plan
terragrunt run-all apply

# Note: Production deployment may take 30-60 minutes
# Monitor progress in GCP Console
```

## Configuration Customization

### Environment Variables

Set the following environment variables before deployment:

```bash
# Required
export GCP_PROJECT_ID="your-project-id"
export GCP_REGION="us-central1"
export GCP_ZONE="us-central1-a"

# Optional
export TF_VAR_environment="development"
export TF_VAR_owner="your-team"
export TF_VAR_cost_center="engineering"
```

### Terraform Variables

Common variables that can be customized:

```hcl
# terraform.tfvars
project_id = "your-project-id"
region     = "us-central1"
zone       = "us-central1-a"

# Instance configuration
machine_type = "e2-medium"
disk_size_gb = 50

# Network configuration
network_cidr = "10.0.0.0/16"
subnet_cidr  = "10.0.1.0/24"

# Labels
labels = {
  environment = "development"
  team        = "platform"
  project     = "webapp"
}
```

### Terragrunt Configuration

Customize Terragrunt settings in `terragrunt.hcl`:

```hcl
# Remote state configuration
remote_state {
  backend = "gcs"
  config = {
    bucket = "your-terraform-state-bucket"
    prefix = "terraform/state"
  }
}

# Provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
EOF
}
```

## Monitoring and Operations

### Health Checks

Each example includes health check endpoints:

```bash
# Basic example
curl http://EXTERNAL_IP/health

# Multi-tier example
curl http://LOAD_BALANCER_IP/health
curl http://LOAD_BALANCER_IP/api/health

# Production example
curl https://app.yourdomain.com/health
curl https://api.yourdomain.com/health
```

### Monitoring Dashboards

Access monitoring dashboards in Google Cloud Console:

1. **Compute Engine**: VM instances, CPU, memory, disk usage
2. **Load Balancing**: Request rates, latency, error rates
3. **Cloud SQL**: Database performance, connections, queries
4. **Storage**: Bucket usage, request metrics
5. **Custom Dashboards**: Application-specific metrics

### Log Analysis

View logs in Cloud Logging:

```bash
# Application logs
gcloud logging read "resource.type=gce_instance"

# Load balancer logs
gcloud logging read "resource.type=http_load_balancer"

# Database logs
gcloud logging read "resource.type=cloudsql_database"
```

## Security Considerations

### Network Security

- **Private Subnets**: Application and database tiers in private subnets
- **Cloud NAT**: Outbound internet access for private instances
- **Firewall Rules**: Restrictive rules based on least privilege
- **VPC Flow Logs**: Network traffic monitoring and analysis

### Compute Security

- **OS Login**: Centralized SSH key management
- **Shielded VMs**: Protection against rootkits and bootkits
- **Confidential VMs**: Memory encryption (production example)
- **Service Accounts**: Minimal required permissions

### Data Security

- **Encryption at Rest**: Customer-managed encryption keys (CMEK)
- **Encryption in Transit**: TLS for all communications
- **Secret Management**: Cloud Secret Manager for sensitive data
- **Database Security**: Private IP, SSL connections, regular backups

### Access Control

- **IAM**: Role-based access control with principle of least privilege
- **Identity-Aware Proxy**: Application-level access control
- **VPN/Bastion**: Secure administrative access
- **Audit Logging**: Comprehensive access and change logging

## Cost Optimization

### Resource Sizing

- **Right-sizing**: Match instance types to workload requirements
- **Auto-scaling**: Scale resources based on demand
- **Preemptible Instances**: Use for fault-tolerant workloads
- **Committed Use Discounts**: For predictable workloads

### Storage Optimization

- **Lifecycle Policies**: Automatically move data to cheaper storage classes
- **Compression**: Reduce storage and network costs
- **Deletion Policies**: Remove unnecessary data automatically

### Monitoring Costs

- **Budget Alerts**: Get notified when costs exceed thresholds
- **Resource Labeling**: Track costs by team, project, environment
- **Cost Analysis**: Regular review of spending patterns

## Troubleshooting

### Common Issues

1. **Permission Errors**
   ```bash
   # Enable required APIs
   gcloud services enable compute.googleapis.com
   gcloud services enable cloudsql.googleapis.com
   gcloud services enable storage.googleapis.com

   # Check IAM permissions
   gcloud projects get-iam-policy $GCP_PROJECT_ID
   ```

2. **Quota Exceeded**
   ```bash
   # Check quotas
   gcloud compute project-info describe --project=$GCP_PROJECT_ID

   # Request quota increase in GCP Console
   # https://console.cloud.google.com/iam-admin/quotas
   ```

3. **Network Connectivity**
   ```bash
   # Check firewall rules
   gcloud compute firewall-rules list

   # Test connectivity
   gcloud compute ssh INSTANCE_NAME --zone=ZONE
   ```

4. **State File Issues**
   ```bash
   # Import existing resource
   terragrunt import google_compute_instance.example projects/PROJECT/zones/ZONE/instances/INSTANCE

   # Refresh state
   terragrunt refresh
   ```

### Getting Help

- **Documentation**: Comprehensive docs in `docs/` directory
- **Terraform Google Provider**: [Official documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- **Terragrunt Documentation**: [Official documentation](https://terragrunt.gruntwork.io/docs/)
- **Google Cloud Documentation**: [Official documentation](https://cloud.google.com/docs)

## Contributing

To add new examples or improve existing ones:

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/new-example
   ```

2. **Add Example Directory**
   ```bash
   mkdir examples/new-example
   cd examples/new-example
   ```

3. **Create Configuration Files**
   - `terragrunt.hcl` - Main configuration
   - `README.md` - Example-specific documentation
   - Supporting files (startup scripts, configs)

4. **Test Example**
   ```bash
   terragrunt plan
   terragrunt apply
   # Test functionality
   terragrunt destroy
   ```

5. **Update Documentation**
   - Add example to this README
   - Document any new features or patterns
   - Include cost estimates and resource counts

6. **Submit Pull Request**
   - Clear description of the example
   - Test results and screenshots
   - Documentation updates

## License

This project is licensed under the MIT License. See the [LICENSE](../LICENSE) file for details.