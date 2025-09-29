# Troubleshooting Guide

## Overview

This guide provides solutions to common issues encountered when working with the terragrunt-gcp infrastructure.

## Table of Contents

1. [Terraform/Terragrunt Issues](#terraformterragrunt-issues)
2. [GCP Authentication](#gcp-authentication)
3. [State Management](#state-management)
4. [Resource Errors](#resource-errors)
5. [Network Issues](#network-issues)
6. [Permission Problems](#permission-problems)
7. [Module Dependencies](#module-dependencies)
8. [Performance Issues](#performance-issues)

---

## Terraform/Terragrunt Issues

### Error: Failed to initialize Terraform

**Symptoms**:
```
Error: Failed to get existing workspaces: querying Cloud Storage failed
```

**Causes**:
- State bucket doesn't exist
- No access to state bucket
- Invalid bucket configuration

**Solutions**:

1. **Verify bucket exists**:
```bash
PROJECT_ID=$(gcloud config get-value project)
gsutil ls gs://${PROJECT_ID}-tfstate
```

2. **Create missing bucket**:
```bash
gsutil mb -l us gs://${PROJECT_ID}-tfstate
gsutil versioning set on gs://${PROJECT_ID}-tfstate
```

3. **Check bucket permissions**:
```bash
gsutil iam get gs://${PROJECT_ID}-tfstate
```

---

### Error: Invalid terragrunt.hcl syntax

**Symptoms**:
```
Error: Invalid expression
Error: Unsupported argument
```

**Solutions**:

1. **Validate HCL syntax**:
```bash
terragrunt hclfmt --check infrastructure/environments/dev/terragrunt.hcl
```

2. **Auto-fix formatting**:
```bash
find infrastructure/environments -name "*.hcl" -exec terragrunt hclfmt {} \;
```

3. **Check for common issues**:
- Missing closing braces `}`
- Incorrect interpolation syntax
- Invalid function calls

---

### Error: Module not found

**Symptoms**:
```
Error: Module not installed
Error: Could not load module
```

**Solutions**:

1. **Initialize modules**:
```bash
terragrunt init
```

2. **Clean and reinitialize**:
```bash
rm -rf .terragrunt-cache
terragrunt init
```

3. **Verify module source path**:
```hcl
# Correct
terraform {
  source = "${get_repo_root()}/modules/compute/instance"
}

# Incorrect
terraform {
  source = "./modules/compute/instance"  # Wrong path
}
```

---

## GCP Authentication

### Error: Application Default Credentials not found

**Symptoms**:
```
Error: google: could not find default credentials
```

**Solutions**:

1. **Authenticate**:
```bash
gcloud auth application-default login
```

2. **Set credentials explicitly**:
```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/keyfile.json"
```

3. **Verify authentication**:
```bash
gcloud auth list
gcloud config list
```

---

### Error: Permission denied (403)

**Symptoms**:
```
Error: Error 403: Permission denied
googleapi: Error 403: The caller does not have permission
```

**Solutions**:

1. **Check current permissions**:
```bash
PROJECT_ID=$(gcloud config get-value project)
EMAIL=$(gcloud config get-value account)
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:$EMAIL"
```

2. **Grant required roles**:
```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$EMAIL" \
  --role="roles/editor"
```

3. **Use service account**:
```bash
gcloud auth activate-service-account \
  --key-file=/path/to/key.json
```

---

### Error: API not enabled

**Symptoms**:
```
Error: Error 403: {API} is not enabled for project
```

**Solutions**:

1. **Enable specific API**:
```bash
gcloud services enable compute.googleapis.com
```

2. **Enable all required APIs**:
```bash
./scripts/enable-gcp-apis.sh
```

3. **Verify API status**:
```bash
gcloud services list --enabled
```

---

## State Management

### Error: State lock acquisition failed

**Symptoms**:
```
Error: Error acquiring the state lock
Lock Info:
  ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  Operation: OperationTypeApply
  Who: user@hostname
```

**Causes**:
- Another terraform/terragrunt process is running
- Previous process crashed without releasing lock
- Network issue during state access

**Solutions**:

1. **Wait for other process** to complete (recommended)

2. **Verify no other processes**:
```bash
ps aux | grep terraform
ps aux | grep terragrunt
```

3. **Force unlock** (use with extreme caution):
```bash
terragrunt force-unlock <LOCK_ID>
```

**⚠️ WARNING**: Only force unlock if you're certain no other process is running!

---

### Error: State file version mismatch

**Symptoms**:
```
Error: state snapshot was created by Terraform v1.5.0
but this is version v1.9.0
```

**Solutions**:

1. **Upgrade state**:
```bash
terraform state replace-provider -auto-approve \
  "registry.terraform.io/-/google" \
  "hashicorp/google"
```

2. **Use correct Terraform version**:
```bash
tfenv use 1.5.0
# or
terraform version
```

---

### Error: State file corrupted

**Symptoms**:
```
Error: Failed to load state: state snapshot is corrupted
```

**Solutions**:

1. **Restore from backup**:
```bash
# List backups
gsutil ls gs://${PROJECT_ID}-tfstate/**/terraform.tfstate.*

# Restore backup
gsutil cp gs://${PROJECT_ID}-tfstate/path/to/backup.tfstate \
  gs://${PROJECT_ID}-tfstate/path/to/terraform.tfstate
```

2. **Pull and verify state**:
```bash
terragrunt state pull > state.backup
terragrunt state push state.backup
```

---

## Resource Errors

### Error: Resource already exists

**Symptoms**:
```
Error: Error creating Instance: googleapi: Error 409: already exists
```

**Solutions**:

1. **Import existing resource**:
```bash
# Get resource ID from GCP Console or gcloud
terragrunt import module.instance.google_compute_instance.main \
  projects/PROJECT/zones/ZONE/instances/NAME
```

2. **Remove from state if managed elsewhere**:
```bash
terragrunt state rm module.instance.google_compute_instance.main
```

3. **Use different resource name**:
```hcl
resource "google_compute_instance" "main" {
  name = "my-instance-v2"  # Changed name
  # ...
}
```

---

### Error: Resource not found (404)

**Symptoms**:
```
Error: Error reading Instance: googleapi: Error 404: not found
```

**Causes**:
- Resource was deleted manually
- Resource name changed
- Wrong project/region

**Solutions**:

1. **Remove from state**:
```bash
terragrunt state rm module.instance.google_compute_instance.main
```

2. **Re-create resource**:
```bash
terragrunt apply
```

3. **Verify correct project**:
```bash
gcloud config get-value project
```

---

### Error: Quota exceeded

**Symptoms**:
```
Error: Quota 'CPUS' exceeded
Error: Insufficient regional quota
```

**Solutions**:

1. **Check current quotas**:
```bash
gcloud compute project-info describe --project=$(gcloud config get-value project)
```

2. **Request quota increase**:
   - Go to GCP Console → IAM & Admin → Quotas
   - Select quota
   - Click "EDIT QUOTAS"
   - Submit request

3. **Reduce resource usage**:
   - Use smaller instance types
   - Delete unused resources
   - Deploy to different region

---

### Error: IP address in use

**Symptoms**:
```
Error: Error creating Address: IP address already in use
```

**Solutions**:

1. **Find conflicting resource**:
```bash
gcloud compute addresses list --filter="address=<IP>"
```

2. **Release IP**:
```bash
gcloud compute addresses delete ADDRESS_NAME --region=REGION
```

3. **Use dynamic IP**:
```hcl
resource "google_compute_address" "main" {
  # Remove 'address' field to get dynamic IP
  # address = "10.0.0.5"  # Remove this
}
```

---

## Network Issues

### Error: Network not found

**Symptoms**:
```
Error: Network 'default' not found
```

**Solutions**:

1. **Create VPC network**:
```bash
gcloud compute networks create default --subnet-mode=auto
```

2. **Use correct network reference**:
```hcl
resource "google_compute_instance" "main" {
  network_interface {
    network = data.google_compute_network.vpc.self_link
  }
}
```

3. **Deploy networking first**:
```bash
cd infrastructure/environments/dev/us-central1/networking
terragrunt run-all apply
```

---

### Error: Subnet not found

**Symptoms**:
```
Error: Subnet not found in region
```

**Solutions**:

1. **List available subnets**:
```bash
gcloud compute networks subnets list
```

2. **Create subnet**:
```bash
gcloud compute networks subnets create SUBNET_NAME \
  --network=NETWORK \
  --region=us-central1 \
  --range=10.0.1.0/24
```

3. **Check region**:
```hcl
# Ensure region matches
resource "google_compute_subnetwork" "subnet" {
  region = "us-central1"  # Must match instance region
}
```

---

### Error: Firewall rule denied

**Symptoms**:
```
Error: Connection refused
Error: Port not accessible
```

**Solutions**:

1. **Check firewall rules**:
```bash
gcloud compute firewall-rules list
```

2. **Create allow rule**:
```bash
gcloud compute firewall-rules create allow-http \
  --network=default \
  --allow=tcp:80,tcp:443 \
  --source-ranges=0.0.0.0/0
```

3. **Verify instance tags**:
```hcl
resource "google_compute_instance" "main" {
  tags = ["http-server", "https-server"]
}
```

---

## Permission Problems

### Error: Service account missing permissions

**Symptoms**:
```
Error: The service account does not have required permissions
```

**Solutions**:

1. **Grant IAM role**:
```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA_EMAIL" \
  --role="roles/compute.instanceAdmin.v1"
```

2. **Use workload identity** (for GKE):
```bash
gcloud iam service-accounts add-iam-policy-binding SA_EMAIL \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:PROJECT_ID.svc.id.goog[K8S_NAMESPACE/KSA_NAME]"
```

3. **Verify permissions**:
```bash
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:SA_EMAIL"
```

---

### Error: Organization policy violation

**Symptoms**:
```
Error: Request violates constraint
Error: Organization policy constraint
```

**Solutions**:

1. **Check org policies**:
```bash
gcloud resource-manager org-policies list --project=PROJECT_ID
```

2. **Request policy exception**:
   - Contact organization admin
   - Provide business justification
   - Request temporary or permanent exception

3. **Modify resource to comply**:
```hcl
# Example: Require OS Login
resource "google_compute_instance" "main" {
  metadata = {
    enable-oslogin = "TRUE"  # Comply with policy
  }
}
```

---

## Module Dependencies

### Error: Dependency cycle detected

**Symptoms**:
```
Error: Cycle detected in module dependencies
```

**Solutions**:

1. **Use skip_outputs**:
```hcl
dependency "vpc" {
  config_path = "../networking/vpc"
  skip_outputs = true  # Break cycle
}
```

2. **Refactor dependencies**:
   - Split modules to remove circular dependencies
   - Use data sources instead of dependencies

3. **Use mock outputs**:
```hcl
dependency "database" {
  config_path = "../data/cloudsql"
  mock_outputs = {
    connection_name = "mock-connection"
  }
}
```

---

### Error: Dependency output not found

**Symptoms**:
```
Error: Unsupported attribute: This object does not have an attribute named
```

**Solutions**:

1. **Verify output exists**:
```bash
cd dependency-module
terragrunt output
```

2. **Add missing output**:
```hcl
# In dependency module's outputs.tf
output "connection_name" {
  value = google_sql_database_instance.main.connection_name
}
```

3. **Use mock for planning**:
```hcl
dependency "database" {
  config_path = "../data/cloudsql"
  mock_outputs = {
    connection_name = "mock-value"
  }
  mock_outputs_allowed_terraform_commands = ["plan"]
}
```

---

## Performance Issues

### Slow terragrunt run-all commands

**Symptoms**:
- Commands take very long to complete
- High CPU usage
- Timeout errors

**Solutions**:

1. **Use parallelism limit**:
```bash
terragrunt run-all apply --terragrunt-parallelism=3
```

2. **Apply specific modules**:
```bash
terragrunt run-all apply \
  --terragrunt-include-dir compute/* \
  --terragrunt-exclude-dir compute/cloud-composer
```

3. **Upgrade Terragrunt**:
```bash
terragrunt --version
# Upgrade if old version
```

---

### Large state file performance

**Symptoms**:
- Slow plan/apply operations
- High memory usage
- State refresh takes minutes

**Solutions**:

1. **Split state files**:
   - Use separate modules
   - Each module has its own state
   - Terragrunt handles this automatically

2. **Use targeted operations**:
```bash
terragrunt plan -target=module.specific_resource
terragrunt apply -target=module.specific_resource
```

3. **Disable refresh for plan**:
```bash
terragrunt plan -refresh=false
```

---

## Getting More Help

### Enable Debug Logging

```bash
# Terraform
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform-debug.log

# Terragrunt
export TG_LOG=debug

# Run command
terragrunt plan 2>&1 | tee terragrunt-debug.log
```

### Check Component Status

```bash
# Terraform version
terraform version

# Terragrunt version
terragrunt --version

# GCP authentication
gcloud auth list
gcloud config list

# API status
gcloud services list --enabled

# Resource status
gcloud compute instances list
gcloud container clusters list
```

### Useful Diagnostic Commands

```bash
# View current state
terragrunt state list
terragrunt state show module.resource.name

# View outputs
terragrunt output

# Validate configuration
terragrunt validate

# Show plan without applying
terragrunt plan -out=tfplan
terragrunt show tfplan

# Refresh state
terragrunt refresh
```

---

## Common Error Messages Reference

| Error Message | Common Cause | Quick Fix |
|---------------|--------------|-----------|
| `Error 403` | Missing permissions | Check IAM roles |
| `Error 404` | Resource not found | Verify resource exists |
| `Error 409` | Resource already exists | Import or rename |
| `Error 429` | Rate limit exceeded | Add retry logic or wait |
| `State lock` | Concurrent modification | Wait or force unlock |
| `Module not found` | Missing init | Run `terragrunt init` |
| `Quota exceeded` | Resource limits | Request quota increase |
| `API not enabled` | Missing service | Enable required APIs |
| `Cycle detected` | Circular dependency | Use skip_outputs |
| `Invalid syntax` | HCL formatting | Run `terragrunt hclfmt` |

---

## Additional Resources

- [GCP Status Dashboard](https://status.cloud.google.com/)
- [Terraform Registry](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/docs/)
- [GCP Troubleshooting](https://cloud.google.com/compute/docs/troubleshooting)

---

**Still having issues?**

1. Search existing GitHub issues
2. Check GCP Console for resource status
3. Review this troubleshooting guide
4. Open a new issue with:
   - Error message (full text)
   - Steps to reproduce
   - Terraform/Terragrunt versions
   - Debug logs (if applicable)

---

**Maintained by**: Infrastructure Team
**Last Updated**: 2025-09-29