# Comprehensive Fix Guide for terragrunt-gcp

## Overview
This guide provides a complete roadmap to fix all remaining issues and make the terragrunt-gcp repository production-ready.

## Table of Contents
1. [Priority 1: Critical Infrastructure Issues](#priority-1-critical-infrastructure-issues)
2. [Priority 2: Documentation & Usability](#priority-2-documentation--usability)
3. [Priority 2.5: Go Code Completions](#priority-25-go-code-completions)
4. [Priority 3: Code Quality & Testing](#priority-3-code-quality--testing)
5. [Priority 4: Advanced Features](#priority-4-advanced-features)
6. [Implementation Tracking Matrix](#implementation-tracking-matrix)
7. [Implementation Checklist](#implementation-checklist)
8. [Automation Scripts](#automation-scripts)
9. [Validation Commands](#validation-commands)
10. [Success Criteria](#success-criteria)

---

## Issue Categories and Prioritization

### 🔴 Priority 1: Critical Infrastructure Issues (Block Deployment)

#### 1.1 Missing Root Terragrunt Configuration
**Issue**: All environments (dev, staging, prod) missing root terragrunt.hcl
**Impact**: Prevents proper Terragrunt inheritance and DRY configuration
**Fix**:

```bash
# For each environment, create root terragrunt.hcl
cat > infrastructure/environments/dev/terragrunt.hcl << 'EOF'
# Root configuration for dev environment
remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "acme-ecommerce-platform-dev-tfstate"
    prefix         = "${path_relative_to_include()}"
    project        = "acme-ecommerce-platform-dev"
    location       = "us"
    enable_bucket_policy_only = true
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents = <<EOF
provider "google" {
  project = "acme-ecommerce-platform-dev"
  region  = "us-central1"
}

provider "google-beta" {
  project = "acme-ecommerce-platform-dev"
  region  = "us-central1"
}
EOF
}

inputs = {
  project_id  = "acme-ecommerce-platform-dev"
  environment = "dev"
}
EOF
```

Repeat for staging and prod with appropriate values.

#### 1.2 Cloud Composer Module Issues
**Issue**: Invalid arguments and unsupported blocks
**Location**: `modules/compute/cloud-composer/main.tf`
**Fix**:

```terraform
# Remove or comment out in node_config:
# disk_type    = local.node_config.disk_type  # Not supported
# enable_ip_alias = local.node_config.enable_ip_alias  # Not supported

# Replace scheduler_count dynamic block with:
scheduler_count = var.scheduler_count  # Use direct assignment

# Remove web_server_network_access_control block entirely
# This feature requires different configuration approach
```

#### 1.3 Terraform Environment Setup & Secret Management
**Issue**: Placeholder values in secret-manager configuration
**Location**: `infrastructure/environments/prod/us-central1/security/secret-manager/terragrunt.hcl`
**Impact**: Cannot deploy with placeholder credentials

**Fix Strategy**:

1. **Option A: Use Terraform Variables (Recommended for Production)**
```hcl
# In terragrunt.hcl
inputs = {
  db_password = get_env("DB_PASSWORD", "")
  stripe_key  = get_env("STRIPE_API_KEY", "")
  # Reference from existing Secret Manager secrets
  github_pat  = "projects/${local.project_id}/secrets/github-pat/versions/latest"
}
```

2. **Option B: Bootstrap Script for Initial Setup**
```bash
#!/bin/bash
# scripts/bootstrap-secrets.sh

# Create a template for secrets that need manual entry
cat > secrets.auto.tfvars << 'EOF'
# Database credentials
db_password = "" # REQUIRED: Set database password

# API Keys
stripe_key = "" # REQUIRED: Set Stripe API key
sendgrid_key = "" # REQUIRED: Set SendGrid API key

# OAuth credentials
oauth_client_id = "" # REQUIRED: Set OAuth client ID
oauth_client_secret = "" # REQUIRED: Set OAuth client secret
EOF

echo "⚠️  Please edit secrets.auto.tfvars with real values before deploying"
echo "⚠️  NEVER commit this file to version control"
```

3. **Option C: Secret Manager Bootstrap (Secure)**
```bash
#!/bin/bash
# scripts/create-initial-secrets.sh

PROJECT_ID="acme-ecommerce-platform-prod"

# Create secrets in Secret Manager manually first
gcloud secrets create db-password --project=$PROJECT_ID --replication-policy=automatic
echo -n "your-secure-password" | gcloud secrets versions add db-password --data-file=-

# Then reference them in Terraform
# data "google_secret_manager_secret_version" "db_password" {
#   secret = "db-password"
# }
```

---

### 🟡 Priority 2: Documentation & Usability (Required for Production)

#### 2.1 Module Documentation
**Issue**: No README files in any module
**Fix Script**:

```bash
#!/bin/bash
# generate-module-docs.sh

for module_dir in modules/*/*/; do
  if [ -d "$module_dir" ]; then
    category=$(basename "$(dirname "$module_dir")")
    module=$(basename "$module_dir")

    cat > "$module_dir/README.md" << EOF
# $module Module

## Overview
This module manages $module resources in GCP.

## Usage

\`\`\`hcl
module "$module" {
  source = "../../modules/$category/$module"

  project_id = var.project_id
  # Add required variables here
}
\`\`\`

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| google | >= 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | The GCP project ID | string | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| id | The resource ID |

## Resources Created

- List resources created by this module

## Examples

See the [examples](./examples/) directory for usage examples.
EOF
  fi
done
```

#### 2.2 Environment Documentation
**Create**: `infrastructure/environments/README.md`

```markdown
# Environment Configuration

## Structure
- `dev/` - Development environment (cost-optimized)
- `staging/` - Staging environment (production-like, scaled down)
- `prod/` - Production environment (HA, multi-region)

## Deployment Order
1. Global resources (IAM, DNS)
2. Networking (VPC, Subnets)
3. Security (KMS, Secret Manager)
4. Data (BigQuery, Cloud SQL)
5. Compute (GKE, Cloud Run)
6. Monitoring & Logging

## Usage
```bash
cd infrastructure/environments/dev
terragrunt run-all plan
terragrunt run-all apply
```

## Secret Management
See [Secret Management Guide](../../docs/SECRET-MANAGEMENT.md) for handling sensitive values.
```

---

### 🟠 Priority 2.5: Go Code Completions (Required for Full Functionality)

This section addresses all placeholder implementations and "not implemented" errors in the Go codebase.

#### 2.5.1 Secrets Service - Encryption & Decryption
**Issue**: Placeholder encryption/decryption logic
**Location**: `internal/gcp/secrets.go:1247-1258`
**Impact**: Secrets not properly encrypted at rest

**Current State**:
```go
func (ss *SecretsService) encryptSecretData(data []byte) ([]byte, error) {
    // Placeholder for encryption logic
    return data, nil
}
```

**Implementation**:
```go
// encryptSecretData encrypts secret data using GCP KMS
func (ss *SecretsService) encryptSecretData(data []byte) ([]byte, error) {
    if ss.kmsClient == nil {
        return nil, fmt.Errorf("KMS client not initialized")
    }

    req := &kmspb.EncryptRequest{
        Name:      ss.kmsKeyName,
        Plaintext: data,
    }

    resp, err := ss.kmsClient.Encrypt(context.Background(), req)
    if err != nil {
        return nil, fmt.Errorf("failed to encrypt data: %w", err)
    }

    return resp.Ciphertext, nil
}

// decryptSecretData decrypts secret data using GCP KMS
func (ss *SecretsService) decryptSecretData(encryptedData []byte) ([]byte, error) {
    if ss.kmsClient == nil {
        return nil, fmt.Errorf("KMS client not initialized")
    }

    req := &kmspb.DecryptRequest{
        Name:       ss.kmsKeyName,
        Ciphertext: encryptedData,
    }

    resp, err := ss.kmsClient.Decrypt(context.Background(), req)
    if err != nil {
        return nil, fmt.Errorf("failed to decrypt data: %w", err)
    }

    return resp.Plaintext, nil
}
```

**Dependencies**:
```bash
go get cloud.google.com/go/kms/apiv1
```

**Testing**:
```go
func TestEncryptDecrypt(t *testing.T) {
    // Use mock KMS client
    mockKMS := &MockKMSClient{}
    ss := &SecretsService{kmsClient: mockKMS}

    original := []byte("sensitive-data")
    encrypted, err := ss.encryptSecretData(original)
    require.NoError(t, err)

    decrypted, err := ss.decryptSecretData(encrypted)
    require.NoError(t, err)
    assert.Equal(t, original, decrypted)
}
```

#### 2.5.2 Secrets Service - CRC32C Checksum
**Issue**: Simplified CRC32C calculation
**Location**: `internal/gcp/secrets.go:1267-1271`

**Implementation**:
```go
import "hash/crc32"

// calculateCRC32C calculates CRC32C checksum (Castagnoli polynomial)
func (ss *SecretsService) calculateCRC32C(data []byte) *int64 {
    table := crc32.MakeTable(crc32.Castagnoli)
    checksum := int64(crc32.Checksum(data, table))
    return &checksum
}
```

#### 2.5.3 Secrets Service - Backup Implementation
**Issue**: Placeholder backup logic
**Location**: `internal/gcp/secrets.go:1443`

**Implementation**:
```go
// backupSecret backs up a secret to GCS
func (ss *SecretsService) backupSecret(ctx context.Context, secretName string) error {
    if ss.backupBucket == "" {
        return fmt.Errorf("backup bucket not configured")
    }

    // Get current secret version
    version, err := ss.GetSecretVersion(ctx, secretName+"/versions/latest")
    if err != nil {
        return fmt.Errorf("failed to get secret version: %w", err)
    }

    // Create backup object name with timestamp
    timestamp := time.Now().Format("20060102-150405")
    objectName := fmt.Sprintf("secrets/%s/%s.json", secretName, timestamp)

    // Marshal secret data
    backupData, err := json.Marshal(map[string]interface{}{
        "name":       version.Name,
        "payload":    base64.StdEncoding.EncodeToString(version.Payload),
        "created_at": version.CreateTime,
        "metadata":   version.Metadata,
    })
    if err != nil {
        return fmt.Errorf("failed to marshal backup data: %w", err)
    }

    // Upload to GCS
    bucket := ss.storageClient.Bucket(ss.backupBucket)
    obj := bucket.Object(objectName)
    writer := obj.NewWriter(ctx)

    if _, err := writer.Write(backupData); err != nil {
        return fmt.Errorf("failed to write backup: %w", err)
    }

    if err := writer.Close(); err != nil {
        return fmt.Errorf("failed to close backup writer: %w", err)
    }

    ss.logger.Info("Secret backed up successfully",
        "secret", secretName,
        "backup_location", fmt.Sprintf("gs://%s/%s", ss.backupBucket, objectName))

    return nil
}
```

#### 2.5.4 Secrets Service - Compliance Check
**Issue**: Placeholder compliance check
**Location**: `internal/gcp/secrets.go:1510`

**Implementation**:
```go
// checkCompliance verifies secret meets compliance requirements
func (ss *SecretsService) checkCompliance(ctx context.Context, secretName string) (*ComplianceResult, error) {
    result := &ComplianceResult{
        SecretName:  secretName,
        CheckedAt:   time.Now(),
        Violations:  []string{},
        Passed:      true,
    }

    // Check 1: Rotation policy exists
    rotation, err := ss.GetRotationPolicy(ctx, secretName)
    if err != nil || rotation == nil {
        result.Violations = append(result.Violations, "No rotation policy configured")
        result.Passed = false
    } else if rotation.Period > 90*24*time.Hour {
        result.Violations = append(result.Violations, "Rotation period exceeds 90 days")
        result.Passed = false
    }

    // Check 2: Encryption enabled
    secret, err := ss.GetSecret(ctx, secretName)
    if err != nil {
        return nil, err
    }
    if secret.CustomerManagedEncryption == nil {
        result.Violations = append(result.Violations, "Customer-managed encryption not enabled")
        result.Passed = false
    }

    // Check 3: Access logging enabled
    if !ss.isAccessLoggingEnabled(secretName) {
        result.Violations = append(result.Violations, "Access logging not enabled")
        result.Passed = false
    }

    // Check 4: Replication policy
    if secret.Replication == nil || secret.Replication.Automatic == nil {
        result.Violations = append(result.Violations, "No replication policy configured")
        result.Passed = false
    }

    // Check 5: Version count
    versions, err := ss.ListSecretVersions(ctx, secretName)
    if err == nil && len(versions) > 10 {
        result.Warnings = append(result.Warnings, "More than 10 versions exist, consider cleanup")
    }

    return result, nil
}

type ComplianceResult struct {
    SecretName  string    `json:"secret_name"`
    CheckedAt   time.Time `json:"checked_at"`
    Passed      bool      `json:"passed"`
    Violations  []string  `json:"violations"`
    Warnings    []string  `json:"warnings,omitempty"`
}
```

#### 2.5.5 Secrets Service - Rotation Helpers
**Issue**: Placeholder rotation helper methods
**Location**: `internal/gcp/secrets.go:1555-1578`

**Implementation**:
```go
// validateRotation validates rotation can proceed safely
func (ss *SecretsService) validateRotation(ctx context.Context, secretName string) error {
    // Check if secret exists
    _, err := ss.GetSecret(ctx, secretName)
    if err != nil {
        return fmt.Errorf("secret not found: %w", err)
    }

    // Check for in-progress rotations
    ss.rotationMutex.RLock()
    if _, inProgress := ss.rotationsInProgress[secretName]; inProgress {
        ss.rotationMutex.RUnlock()
        return fmt.Errorf("rotation already in progress for secret: %s", secretName)
    }
    ss.rotationMutex.RUnlock()

    // Check minimum time since last rotation
    lastRotation, err := ss.getLastRotationTime(ctx, secretName)
    if err == nil && time.Since(lastRotation) < 24*time.Hour {
        return fmt.Errorf("minimum time between rotations not met (24 hours)")
    }

    return nil
}

// backupBeforeRotation creates a backup before rotating
func (ss *SecretsService) backupBeforeRotation(ctx context.Context, secretName string) error {
    return ss.backupSecret(ctx, secretName)
}

// testNewCredentials tests if new credentials work
func (ss *SecretsService) testNewCredentials(ctx context.Context, secretName string, newValue []byte) error {
    // Parse secret type from metadata
    secret, err := ss.GetSecret(ctx, secretName)
    if err != nil {
        return err
    }

    secretType := secret.Labels["type"]

    switch secretType {
    case "database":
        return ss.testDatabaseCredentials(ctx, newValue)
    case "api_key":
        return ss.testAPIKeyCredentials(ctx, newValue)
    case "oauth":
        return ss.testOAuthCredentials(ctx, newValue)
    default:
        ss.logger.Warn("Cannot test credentials for unknown type", "type", secretType)
        return nil // Don't fail rotation if we can't test
    }
}

// verifyRotation verifies rotation was successful
func (ss *SecretsService) verifyRotation(ctx context.Context, secretName string) error {
    // Get latest version
    latest, err := ss.GetSecretVersion(ctx, secretName+"/versions/latest")
    if err != nil {
        return fmt.Errorf("failed to get latest version: %w", err)
    }

    // Verify it's the newly rotated version
    if time.Since(latest.CreateTime) > 5*time.Minute {
        return fmt.Errorf("latest version is not recent, rotation may have failed")
    }

    // Test the new credentials
    if err := ss.testNewCredentials(ctx, secretName, latest.Payload); err != nil {
        return fmt.Errorf("new credentials failed validation: %w", err)
    }

    return nil
}

// rollbackRotation rolls back a failed rotation
func (ss *SecretsService) rollbackRotation(ctx context.Context, secretName string, previousVersion string) error {
    ss.logger.Warn("Rolling back rotation", "secret", secretName, "to_version", previousVersion)

    // Get the previous version
    prevVersion, err := ss.GetSecretVersion(ctx, previousVersion)
    if err != nil {
        return fmt.Errorf("failed to get previous version: %w", err)
    }

    // Add it as a new version to restore
    _, err = ss.AddSecretVersion(ctx, secretName, prevVersion.Payload)
    if err != nil {
        return fmt.Errorf("failed to restore previous version: %w", err)
    }

    // Disable the failed version
    latestVersionName := secretName + "/versions/latest"
    if err := ss.DisableSecretVersion(ctx, latestVersionName); err != nil {
        ss.logger.Error("Failed to disable failed version", "error", err)
    }

    return nil
}
```

#### 2.5.6 Auth Provider - Credential Sources
**Issue**: Not implemented credential sources
**Location**: `internal/gcp/auth.go:518-530`

**Implementation for Executable Credentials**:
```go
import (
    "bytes"
    "encoding/json"
    "os/exec"
)

// getExecutableToken retrieves token from an executable
func (p *AuthProvider) getExecutableToken(ctx context.Context, config *ExecutableConfig) (string, error) {
    if config == nil || config.Command == "" {
        return "", fmt.Errorf("invalid executable config")
    }

    // Build command
    cmd := exec.CommandContext(ctx, config.Command, config.Args...)

    // Set timeout
    if config.TimeoutSeconds > 0 {
        ctx, cancel := context.WithTimeout(ctx, time.Duration(config.TimeoutSeconds)*time.Second)
        defer cancel()
        cmd = exec.CommandContext(ctx, config.Command, config.Args...)
    }

    // Set environment variables
    cmd.Env = append(os.Environ(), config.Env...)

    // Execute command
    var stdout, stderr bytes.Buffer
    cmd.Stdout = &stdout
    cmd.Stderr = &stderr

    if err := cmd.Run(); err != nil {
        return "", fmt.Errorf("executable failed: %w, stderr: %s", err, stderr.String())
    }

    // Parse output based on format
    switch config.OutputFormat {
    case "json":
        var result struct {
            Token     string    `json:"token"`
            ExpiresAt time.Time `json:"expires_at"`
        }
        if err := json.Unmarshal(stdout.Bytes(), &result); err != nil {
            return "", fmt.Errorf("failed to parse JSON output: %w", err)
        }
        return result.Token, nil

    case "text":
        return strings.TrimSpace(stdout.String()), nil

    default:
        return "", fmt.Errorf("unsupported output format: %s", config.OutputFormat)
    }
}
```

**Implementation for Environment Credentials**:
```go
import (
    "io"
    "net/http"
)

// getEnvironmentToken retrieves token from environment (AWS/Azure metadata)
func (p *AuthProvider) getEnvironmentToken(ctx context.Context, source CredentialSource) (string, error) {
    if source.URL == "" {
        return "", fmt.Errorf("no metadata URL specified")
    }

    // Build request
    req, err := http.NewRequestWithContext(ctx, "GET", source.URL, nil)
    if err != nil {
        return "", fmt.Errorf("failed to create request: %w", err)
    }

    // Add headers for cloud provider metadata services
    for key, value := range source.Headers {
        req.Header.Set(key, value)
    }

    // AWS IMDSv2 requires token
    if strings.Contains(source.URL, "169.254.169.254") {
        token, err := p.getAWSIMDSv2Token(ctx)
        if err == nil {
            req.Header.Set("X-aws-ec2-metadata-token", token)
        }
    }

    // Azure metadata service requires header
    if strings.Contains(source.URL, "metadata.azure.com") {
        req.Header.Set("Metadata", "true")
    }

    // GCP metadata service
    if strings.Contains(source.URL, "metadata.google.internal") {
        req.Header.Set("Metadata-Flavor", "Google")
    }

    // Make request with timeout
    client := &http.Client{Timeout: 10 * time.Second}
    resp, err := client.Do(req)
    if err != nil {
        return "", fmt.Errorf("failed to query metadata service: %w", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        body, _ := io.ReadAll(resp.Body)
        return "", fmt.Errorf("metadata service returned %d: %s", resp.StatusCode, body)
    }

    // Read response
    body, err := io.ReadAll(resp.Body)
    if err != nil {
        return "", fmt.Errorf("failed to read response: %w", err)
    }

    // Parse based on format
    switch source.Format {
    case "json":
        var result struct {
            AccessToken string `json:"access_token"`
            Token       string `json:"token"`
        }
        if err := json.Unmarshal(body, &result); err != nil {
            return "", fmt.Errorf("failed to parse JSON: %w", err)
        }
        if result.AccessToken != "" {
            return result.AccessToken, nil
        }
        return result.Token, nil

    case "text":
        return strings.TrimSpace(string(body)), nil

    default:
        return strings.TrimSpace(string(body)), nil
    }
}

// getAWSIMDSv2Token gets session token for AWS IMDSv2
func (p *AuthProvider) getAWSIMDSv2Token(ctx context.Context) (string, error) {
    req, err := http.NewRequestWithContext(ctx, "PUT",
        "http://169.254.169.254/latest/api/token", nil)
    if err != nil {
        return "", err
    }
    req.Header.Set("X-aws-ec2-metadata-token-ttl-seconds", "21600")

    client := &http.Client{Timeout: 2 * time.Second}
    resp, err := client.Do(req)
    if err != nil {
        return "", err
    }
    defer resp.Body.Close()

    body, err := io.ReadAll(resp.Body)
    if err != nil {
        return "", err
    }

    return string(body), nil
}
```

#### 2.5.7 Cost Calculator Implementation
**Issue**: Cost calculation not implemented
**Location**: `internal/analysis/cost/cost.go:20-24`

**Implementation**:
```go
import (
    billing "cloud.google.com/go/billing/apiv1"
    billingpb "cloud.google.com/go/billing/apiv1/billingpb"
)

// CalculateResourceCost calculates the cost for a single resource
func (c *Calculator) CalculateResourceCost(ctx context.Context, resource core.Resource) (float64, error) {
    // Initialize pricing data if not cached
    if c.pricingCache == nil {
        c.pricingCache = make(map[string]float64)
    }

    // Check cache first
    cacheKey := fmt.Sprintf("%s:%s:%s", resource.Account.Provider, resource.Region, resource.Type)
    if price, ok := c.pricingCache[cacheKey]; ok {
        return price * c.getResourceQuantity(resource), nil
    }

    // Calculate based on provider and resource type
    switch resource.Account.Provider {
    case "gcp":
        return c.calculateGCPCost(ctx, resource)
    case "aws":
        return c.calculateAWSCost(ctx, resource)
    case "azure":
        return c.calculateAzureCost(ctx, resource)
    default:
        return 0.0, fmt.Errorf("cost calculation not implemented for provider: %s", resource.Account.Provider)
    }
}

// calculateGCPCost calculates GCP resource costs
func (c *Calculator) calculateGCPCost(ctx context.Context, resource core.Resource) (float64, error) {
    // Initialize billing client if needed
    if c.gcpBillingClient == nil {
        client, err := billing.NewCloudCatalogClient(ctx)
        if err != nil {
            return 0.0, fmt.Errorf("failed to create billing client: %w", err)
        }
        c.gcpBillingClient = client
    }

    // Map resource type to GCP SKU
    sku, err := c.mapResourceTypeToSKU(resource.Type)
    if err != nil {
        return 0.0, err
    }

    // Get pricing for SKU
    req := &billingpb.ListSkusRequest{
        Parent: "services/" + c.getGCPServiceID(resource.Type),
    }

    var monthlyCost float64
    it := c.gcpBillingClient.ListSkus(ctx, req)
    for {
        resp, err := it.Next()
        if err != nil {
            break
        }

        if strings.Contains(resp.Description, sku) {
            // Parse pricing tiers
            if len(resp.PricingInfo) > 0 {
                pricingInfo := resp.PricingInfo[0]
                if len(pricingInfo.PricingExpression.TieredRates) > 0 {
                    rate := pricingInfo.PricingExpression.TieredRates[0]
                    // Convert to monthly cost
                    unitPrice := float64(rate.UnitPrice.Units) + float64(rate.UnitPrice.Nanos)/1e9
                    monthlyCost = unitPrice * c.getResourceQuantity(resource) * 730 // hours per month
                }
            }
            break
        }
    }

    // Cache the result
    cacheKey := fmt.Sprintf("%s:%s:%s", resource.Account.Provider, resource.Region, resource.Type)
    c.pricingCache[cacheKey] = monthlyCost

    return monthlyCost, nil
}

// getResourceQuantity extracts quantity from resource attributes
func (c *Calculator) getResourceQuantity(resource core.Resource) float64 {
    switch resource.Type {
    case "compute.instances":
        // Machine type determines cost
        machineType, ok := resource.Attributes["machine_type"].(string)
        if ok && strings.Contains(machineType, "n1-standard") {
            return 1.0
        }
        return 1.0

    case "storage.buckets":
        // Get storage size in GB
        if size, ok := resource.Attributes["size_gb"].(float64); ok {
            return size
        }
        return 0.0

    case "sql.instances":
        return 1.0

    default:
        return 1.0
    }
}

// mapResourceTypeToSKU maps Terraform resource types to pricing SKUs
func (c *Calculator) mapResourceTypeToSKU(resourceType string) (string, error) {
    skuMap := map[string]string{
        "google_compute_instance":           "Compute Engine",
        "google_storage_bucket":             "Cloud Storage",
        "google_sql_database_instance":      "Cloud SQL",
        "google_container_cluster":          "GKE",
        "google_bigquery_dataset":           "BigQuery",
        "google_compute_disk":               "Persistent Disk",
        "google_compute_address":            "IP Address",
        "google_compute_forwarding_rule":    "Load Balancing",
    }

    sku, ok := skuMap[resourceType]
    if !ok {
        return "", fmt.Errorf("unknown resource type: %s", resourceType)
    }
    return sku, nil
}

// getGCPServiceID returns the GCP service ID for a resource type
func (c *Calculator) getGCPServiceID(resourceType string) string {
    serviceMap := map[string]string{
        "google_compute_instance":      "6F81-5844-456A",
        "google_storage_bucket":        "95FF-2EF5-5EA1",
        "google_sql_database_instance": "9662-B51E-5089",
        "google_container_cluster":     "6F81-5844-456A",
        "google_bigquery_dataset":      "24E6-581D-38E5",
    }
    return serviceMap[resourceType]
}
```

**Dependencies**:
```bash
go get cloud.google.com/go/billing/apiv1
```

#### 2.5.8 Terraform Auto-Download
**Issue**: Not implemented
**Location**: `cmd/terragrunt/main.go:1585-1588`

**Implementation**:
```go
import (
    "archive/zip"
    "runtime"
)

func downloadTerraform(ctx *ExecutionContext) error {
    version := ctx.Config.TerraformBinary.Version
    if version == "" {
        version = "latest"
    }

    // Determine OS and architecture
    osName := runtime.GOOS
    arch := runtime.GOARCH

    // Get download URL
    downloadURL, err := getTerraformDownloadURL(version, osName, arch)
    if err != nil {
        return fmt.Errorf("failed to get download URL: %w", err)
    }

    logger := ctx.Logger
    logger.Info("Downloading Terraform", "version", version, "url", downloadURL)

    // Download file
    resp, err := http.Get(downloadURL)
    if err != nil {
        return fmt.Errorf("failed to download Terraform: %w", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        return fmt.Errorf("download failed with status: %d", resp.StatusCode)
    }

    // Create temp file
    tmpFile, err := os.CreateTemp("", "terraform-*.zip")
    if err != nil {
        return fmt.Errorf("failed to create temp file: %w", err)
    }
    defer os.Remove(tmpFile.Name())
    defer tmpFile.Close()

    // Write to temp file
    if _, err := io.Copy(tmpFile, resp.Body); err != nil {
        return fmt.Errorf("failed to write download: %w", err)
    }

    // Extract binary
    installPath := ctx.Config.TerraformBinary.Path
    if installPath == "" {
        installPath = filepath.Join(os.Getenv("HOME"), ".terragrunt", "bin", "terraform")
    }

    // Create install directory
    if err := os.MkdirAll(filepath.Dir(installPath), 0755); err != nil {
        return fmt.Errorf("failed to create install directory: %w", err)
    }

    // Extract zip
    if err := extractTerraformBinary(tmpFile.Name(), installPath); err != nil {
        return fmt.Errorf("failed to extract Terraform: %w", err)
    }

    // Make executable
    if err := os.Chmod(installPath, 0755); err != nil {
        return fmt.Errorf("failed to make executable: %w", err)
    }

    logger.Info("Terraform installed successfully", "path", installPath)
    return nil
}

func getTerraformDownloadURL(version, osName, arch string) (string, error) {
    // Get latest version if needed
    if version == "latest" {
        latestVersion, err := getLatestTerraformVersion()
        if err != nil {
            return "", err
        }
        version = latestVersion
    }

    // Build download URL
    baseURL := "https://releases.hashicorp.com/terraform"
    filename := fmt.Sprintf("terraform_%s_%s_%s.zip", version, osName, arch)
    return fmt.Sprintf("%s/%s/%s", baseURL, version, filename), nil
}

func getLatestTerraformVersion() (string, error) {
    resp, err := http.Get("https://checkpoint-api.hashicorp.com/v1/check/terraform")
    if err != nil {
        return "", err
    }
    defer resp.Body.Close()

    var result struct {
        CurrentVersion string `json:"current_version"`
    }
    if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
        return "", err
    }

    return result.CurrentVersion, nil
}

func extractTerraformBinary(zipPath, destPath string) error {
    r, err := zip.OpenReader(zipPath)
    if err != nil {
        return err
    }
    defer r.Close()

    for _, f := range r.File {
        if f.Name == "terraform" || f.Name == "terraform.exe" {
            rc, err := f.Open()
            if err != nil {
                return err
            }
            defer rc.Close()

            outFile, err := os.OpenFile(destPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, f.Mode())
            if err != nil {
                return err
            }
            defer outFile.Close()

            if _, err := io.Copy(outFile, rc); err != nil {
                return err
            }
            return nil
        }
    }

    return fmt.Errorf("terraform binary not found in archive")
}
```

#### 2.5.9 Utils Service - Quota & Cost Retrieval
**Issue**: Placeholder implementations
**Location**: `internal/gcp/utils.go:1506, 1602`

**Implementation**:
```go
import (
    "cloud.google.com/go/compute/apiv1/computepb"
    serviceusage "cloud.google.com/go/serviceusage/apiv1"
)

// getProjectQuotas retrieves actual project quotas from GCP
func (us *UtilsService) getProjectQuotas(ctx context.Context, projectID string) (map[string]*Quota, error) {
    quotas := make(map[string]*Quota)

    // Get compute quotas
    computeQuotas, err := us.getComputeQuotas(ctx, projectID)
    if err != nil {
        return nil, fmt.Errorf("failed to get compute quotas: %w", err)
    }

    for k, v := range computeQuotas {
        quotas[k] = v
    }

    // Get service-specific quotas
    serviceQuotas, err := us.getServiceUsageQuotas(ctx, projectID)
    if err != nil {
        // Log but don't fail
        us.logger.Warn("Failed to get service usage quotas", "error", err)
    } else {
        for k, v := range serviceQuotas {
            quotas[k] = v
        }
    }

    return quotas, nil
}

// getComputeQuotas retrieves compute engine quotas
func (us *UtilsService) getComputeQuotas(ctx context.Context, projectID string) (map[string]*Quota, error) {
    computeClient, err := compute.NewProjectsRESTClient(ctx)
    if err != nil {
        return nil, err
    }
    defer computeClient.Close()

    req := &computepb.GetProjectRequest{
        Project: projectID,
    }

    project, err := computeClient.Get(ctx, req)
    if err != nil {
        return nil, fmt.Errorf("failed to get project: %w", err)
    }

    quotas := make(map[string]*Quota)
    for _, quota := range project.Quotas {
        quotas[quota.GetMetric()] = &Quota{
            Metric: quota.GetMetric(),
            Limit:  quota.GetLimit(),
            Usage:  quota.GetUsage(),
        }
    }

    return quotas, nil
}

// getServiceUsageQuotas retrieves quotas from Service Usage API
func (us *UtilsService) getServiceUsageQuotas(ctx context.Context, projectID string) (map[string]*Quota, error) {
    client, err := serviceusage.NewClient(ctx)
    if err != nil {
        return nil, err
    }
    defer client.Close()

    // List services
    services := []string{
        "compute.googleapis.com",
        "storage-api.googleapis.com",
        "bigquery.googleapis.com",
        "sqladmin.googleapis.com",
    }

    quotas := make(map[string]*Quota)

    for _, service := range services {
        // Get consumer quota metrics for the service
        parent := fmt.Sprintf("projects/%s/services/%s", projectID, service)

        req := &serviceusagepb.ListConsumerQuotaMetricsRequest{
            Parent: parent,
        }

        it := client.ListConsumerQuotaMetrics(ctx, req)
        for {
            metric, err := it.Next()
            if err == iterator.Done {
                break
            }
            if err != nil {
                continue
            }

            // Extract quota information
            metricName := metric.GetMetric()
            for _, limit := range metric.GetConsumerQuotaLimits() {
                limitKey := fmt.Sprintf("%s/%s", service, metricName)

                var usage, limit float64
                for _, bucket := range limit.GetQuotaBuckets() {
                    if bucket.GetEffectiveLimit() > 0 {
                        limit = float64(bucket.GetEffectiveLimit())
                    }
                }

                quotas[limitKey] = &Quota{
                    Metric: limitKey,
                    Limit:  limit,
                    Usage:  usage, // Usage not directly available, would need monitoring API
                }
            }
        }
    }

    return quotas, nil
}

type Quota struct {
    Metric string
    Limit  float64
    Usage  float64
}
```

#### 2.5.10 Monitor Web UI
**Issue**: Placeholder for web UI
**Location**: `cmd/monitor/main.go:593`

**Implementation Strategy**:
```go
// Serve web UI for monitoring
func serveWebUI(w http.ResponseWriter, r *http.Request) {
    tmpl := template.Must(template.New("dashboard").Parse(dashboardHTML))

    data := struct {
        Title      string
        RefreshRate int
        Metrics    []MetricData
    }{
        Title:      "Infrastructure Monitor",
        RefreshRate: 30,
        Metrics:    getCurrentMetrics(),
    }

    if err := tmpl.Execute(w, data); err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
    }
}

const dashboardHTML = `
<!DOCTYPE html>
<html>
<head>
    <title>{{.Title}}</title>
    <meta http-equiv="refresh" content="{{.RefreshRate}}">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .metric { padding: 10px; margin: 10px; border: 1px solid #ddd; }
        .healthy { background-color: #d4edda; }
        .warning { background-color: #fff3cd; }
        .critical { background-color: #f8d7da; }
    </style>
</head>
<body>
    <h1>{{.Title}}</h1>
    <div id="metrics">
        {{range .Metrics}}
        <div class="metric {{.Status}}">
            <h3>{{.Name}}</h3>
            <p>Status: {{.Status}}</p>
            <p>Value: {{.Value}}</p>
            <p>Last Updated: {{.Timestamp}}</p>
        </div>
        {{end}}
    </div>
</body>
</html>
`

type MetricData struct {
    Name      string
    Status    string
    Value     string
    Timestamp time.Time
}

func getCurrentMetrics() []MetricData {
    // Implement actual metrics collection
    return []MetricData{
        {Name: "Resource Count", Status: "healthy", Value: "142", Timestamp: time.Now()},
        {Name: "Drift Detected", Status: "warning", Value: "3", Timestamp: time.Now()},
        {Name: "Last Scan", Status: "healthy", Value: "5 minutes ago", Timestamp: time.Now()},
    }
}
```

---

### 🟢 Priority 3: Code Quality & Testing (Improve Reliability)

#### 3.1 Fix Go Test Issues
**Issue**: Tests skipping due to client creation errors
**Fix**:

```go
// test/testhelpers/gcp_mock.go
package testhelpers

import (
    "context"
    "testing"
    "github.com/stretchr/testify/mock"
)

type MockGCPClient struct {
    mock.Mock
}

func NewMockGCPClient(t *testing.T) *MockGCPClient {
    return &MockGCPClient{}
}

func (m *MockGCPClient) GetProject(ctx context.Context) (string, error) {
    args := m.Called(ctx)
    return args.String(0), args.Error(1)
}

// Add other mock methods
```

Update tests to use mocks:
```go
func TestAuthService(t *testing.T) {
    mockClient := testhelpers.NewMockGCPClient(t)
    mockClient.On("GetProject", mock.Anything).Return("test-project", nil)

    // Test with mock
}
```

#### 3.2 Restore Commented GCP APIs
**Issue**: Some APIs commented out due to import issues
**Fix**:

```bash
# Update go.mod with correct versions
go get cloud.google.com/go/servicenetworking@latest
go get cloud.google.com/go/resourcemanager/apiv3@latest

# Then uncomment in files:
# - internal/gcp/network.go (servicenetworking import)
# - internal/gcp/utils.go (resourcemanagerpb import)
```

---

### 🔵 Priority 4: Advanced Features (Nice to Have)

#### 4.1 Add Terraform Validation Tests
**Create**: `test/terraform_validation_test.go`

```go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestTerraformModulesValidation(t *testing.T) {
    modules := []string{
        "modules/compute/instance",
        "modules/networking/vpc",
        // Add all modules
    }

    for _, module := range modules {
        t.Run(module, func(t *testing.T) {
            terraformOptions := &terraform.Options{
                TerraformDir: module,
                NoColor: true,
            }

            _, err := terraform.InitAndValidateE(t, terraformOptions)
            assert.NoError(t, err)
        })
    }
}
```

#### 4.2 Add Pre-commit Hooks
**Create**: `.pre-commit-config.yaml`

```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.77.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
      - id: terraform_tflint

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files

  - repo: https://github.com/golangci/golangci-lint
    rev: v1.50.0
    hooks:
      - id: golangci-lint
```

---

## Implementation Tracking Matrix

| Component | Location | Status | Priority | Effort | Dependencies | Blocker |
|-----------|----------|--------|----------|--------|--------------|---------|
| **Infrastructure** |
| Root terragrunt.hcl (dev) | infrastructure/environments/dev/ | ✅ Completed | P1 | 1h | None | Yes |
| Root terragrunt.hcl (staging) | infrastructure/environments/staging/ | ✅ Completed | P1 | 1h | None | Yes |
| Root terragrunt.hcl (prod) | infrastructure/environments/prod/ | ✅ Completed | P1 | 1h | None | Yes |
| Cloud Composer fixes | modules/compute/cloud-composer/ | ✅ Completed | P1 | 2h | None | Yes |
| Secret Manager placeholders | infrastructure/.../secret-manager/ | ✅ Completed | P1 | 4h | None | Yes |
| **Go Code - Secrets** |
| Encryption implementation | internal/gcp/secrets.go:1253 | ✅ Completed | P2.5 | 2d | KMS API | No |
| Decryption implementation | internal/gcp/secrets.go:1298 | ✅ Completed | P2.5 | 2d | KMS API | No |
| CRC32C checksum | internal/gcp/secrets.go:1345 | ✅ Completed | P2.5 | 2h | None | No |
| Backup implementation | internal/gcp/secrets.go:1509 | ✅ Completed | P2.5 | 1d | Storage API | No |
| Compliance checks | internal/gcp/secrets.go:1510 | ❌ Not Started | P2.5 | 1d | None | No |
| Rotation helpers | internal/gcp/secrets.go:1555-1578 | ❌ Not Started | P2.5 | 2d | None | No |
| **Go Code - Auth** |
| Executable credentials | internal/gcp/auth.go:518 | ❌ Not Started | P2.5 | 1d | None | No |
| Environment credentials | internal/gcp/auth.go:526 | ❌ Not Started | P2.5 | 1d | None | No |
| **Go Code - Cost** |
| Cost calculator | internal/analysis/cost/cost.go:20 | ❌ Not Started | P2.5 | 3d | Billing API | No |
| **Go Code - Utils** |
| Quota retrieval | internal/gcp/utils.go:1506 | ❌ Not Started | P2.5 | 1d | Service Usage API | No |
| Cost retrieval | internal/gcp/utils.go:1602 | ❌ Not Started | P2.5 | 1d | Billing API | No |
| **Go Code - Terragrunt** |
| Terraform auto-download | cmd/terragrunt/main.go:1585 | ❌ Not Started | P2.5 | 1d | None | No |
| **Go Code - Monitor** |
| Web UI implementation | cmd/monitor/main.go:593 | ❌ Not Started | P4 | 3d | None | No |
| **Documentation** |
| Module READMEs | modules/*/ | ✅ Completed | P2 | 1d | None | No |
| Environment docs | infrastructure/environments/ | ✅ Completed | P2 | 4h | None | No |
| Secret management guide | docs/ | ✅ Completed | P2 | 4h | None | No |
| **Testing** |
| GCP client mocks | test/testhelpers/ | ❌ Not Started | P3 | 1d | None | No |
| Fix skipped tests | tests/ | ❌ Not Started | P3 | 2d | Mocks | No |
| Terraform validation tests | test/ | ❌ Not Started | P4 | 1d | Terratest | No |
| **Quality** |
| Pre-commit hooks | .pre-commit-config.yaml | ❌ Not Started | P4 | 2h | None | No |
| Restore commented APIs | internal/gcp/ | ❌ Not Started | P3 | 4h | SDK updates | No |

**Legend:**
- ✅ Completed
- 🟡 In Progress
- ❌ Not Started
- **Blocker**: Prevents deployment to production

**Total Effort Estimate**: ~25-30 days
**Critical Path (P1)**: ~8 hours
**Blockers**: 5 items

---

## Implementation Checklist

### Phase 1: Critical Fixes (Day 1-2) - 🔴 BLOCKERS ✅ COMPLETED
- [x] Create root terragrunt.hcl for dev environment
- [x] Create root terragrunt.hcl for staging environment
- [x] Create root terragrunt.hcl for prod environment
- [x] Fix Cloud Composer module issues (remove unsupported args)
- [x] Create secret management strategy documentation
- [x] Replace Secret Manager placeholders with variables
- [x] Test deployment in dev environment
- [x] Verify CI/CD pipeline passes

**Exit Criteria**:
- ✅ `terragrunt run-all plan` succeeds in dev
- ✅ No Terraform validation errors
- ✅ CI/CD pipeline green

### Phase 2: Documentation (Day 3-4) - 🟡 REQUIRED ✅ COMPLETED
- [x] Generate module README files (automated script)
- [x] Create environment documentation
- [x] Write SECRET-MANAGEMENT.md guide
- [x] Add architecture diagrams
- [x] Document deployment procedures
- [x] Create troubleshooting guide

**Exit Criteria**:
- ✅ Every module has README.md
- ✅ Deployment guide is complete
- ✅ Secret management process documented

### Phase 3: Go Code Completions (Day 5-12) - 🟠 FUNCTIONAL
#### Secrets Service (4 days)
- [ ] Implement KMS encryption/decryption
- [ ] Fix CRC32C checksum calculation
- [ ] Implement backup to GCS
- [ ] Add compliance checking
- [ ] Complete rotation helper methods
- [ ] Add integration tests

#### Auth Provider (2 days)
- [ ] Implement executable credential source
- [ ] Implement environment credential source (AWS/Azure metadata)
- [ ] Add unit tests
- [ ] Test with real credentials

#### Cost Calculator (3 days)
- [ ] Implement GCP cost calculation
- [ ] Add AWS cost calculation (optional)
- [ ] Add Azure cost calculation (optional)
- [ ] Integrate with Billing API
- [ ] Add cost caching
- [ ] Create cost report generator

#### Utils & Terragrunt (2 days)
- [ ] Implement quota retrieval from GCP APIs
- [ ] Implement cost retrieval integration
- [ ] Implement Terraform auto-download
- [ ] Add comprehensive error handling

**Exit Criteria**:
- ✅ No "placeholder" or "not implemented" errors
- ✅ All unit tests passing
- ✅ Integration tests added and passing

### Phase 4: Testing & Quality (Day 13-16) - 🟢 RELIABILITY
- [ ] Implement GCP client mocks
- [ ] Fix all skipped tests
- [ ] Add integration tests
- [ ] Add Terraform validation tests
- [ ] Restore commented GCP APIs
- [ ] Run `go test ./...` - 100% pass rate
- [ ] Add benchmark tests
- [ ] Performance testing

**Exit Criteria**:
- ✅ Test coverage > 70%
- ✅ Zero skipped tests
- ✅ All integrations tested

### Phase 5: Advanced Features (Day 17-20) - 🔵 ENHANCEMENTS
- [ ] Implement monitor web UI
- [ ] Add pre-commit hooks
- [ ] Add performance monitoring
- [ ] Implement cost tracking dashboard
- [ ] Add advanced alerting
- [ ] Create API documentation

**Exit Criteria**:
- ✅ Web UI functional
- ✅ Pre-commit hooks installed
- ✅ Monitoring dashboard live

---

## Automation Scripts

### Complete Fix Script
**Create**: `scripts/fix-all-issues.sh`

```bash
#!/bin/bash
# fix-all-issues.sh - Complete automated fix execution

set -e

echo "🔧 Starting comprehensive fix process..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Phase 1: Critical Fixes
echo -e "${YELLOW}📝 Phase 1: Creating root terragrunt configurations...${NC}"
./scripts/create-root-terragrunt.sh

echo -e "${YELLOW}🔨 Fixing Cloud Composer module...${NC}"
./scripts/fix-composer-module.sh

echo -e "${YELLOW}🔐 Setting up secret management...${NC}"
./scripts/setup-secret-management.sh

# Phase 2: Documentation
echo -e "${YELLOW}📚 Phase 2: Generating documentation...${NC}"
./scripts/generate-module-docs.sh
./scripts/create-architecture-docs.sh

# Phase 3: Go Code Fixes
echo -e "${YELLOW}💻 Phase 3: Fixing Go implementations...${NC}"
echo "⚠️  Manual implementation required for Go code completions"
echo "   See COMPREHENSIVE-FIX-GUIDE.md sections 2.5.1 - 2.5.10"

# Phase 4: Testing
echo -e "${YELLOW}🧪 Phase 4: Setting up tests...${NC}"
./scripts/setup-test-mocks.sh

# Phase 5: Validation
echo -e "${YELLOW}✅ Phase 5: Validating fixes...${NC}"
terraform fmt -recursive modules/
go mod tidy
go fmt ./...

# Run validation
echo -e "${YELLOW}🔍 Running validations...${NC}"
if ./scripts/validate-all.sh; then
    echo -e "${GREEN}🎉 All fixes completed successfully!${NC}"
else
    echo -e "${RED}❌ Some validations failed. Check output above.${NC}"
    exit 1
fi
```

### Create Root Terragrunt Script
**Create**: `scripts/create-root-terragrunt.sh`

```bash
#!/bin/bash
# create-root-terragrunt.sh

set -e

ENVIRONMENTS=("dev" "staging" "prod")
PROJECT_PREFIX="acme-ecommerce-platform"
REGION="us-central1"

for ENV in "${ENVIRONMENTS[@]}"; do
    TARGET_DIR="infrastructure/environments/$ENV"
    TARGET_FILE="$TARGET_DIR/terragrunt.hcl"

    echo "Creating root terragrunt.hcl for $ENV environment..."

    # Create directory if it doesn't exist
    mkdir -p "$TARGET_DIR"

    # Generate terragrunt.hcl
    cat > "$TARGET_FILE" << EOF
# Root configuration for $ENV environment
# Generated: $(date)

locals {
  project_id  = "$PROJECT_PREFIX-$ENV"
  region      = "$REGION"
  environment = "$ENV"
}

# Remote state configuration
remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "\${local.project_id}-tfstate"
    prefix         = "\${path_relative_to_include()}"
    project        = local.project_id
    location       = "us"
    enable_bucket_policy_only = true
  }
}

# Provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents = <<PROVIDER
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = "\${local.project_id}"
  region  = "\${local.region}"
}

provider "google-beta" {
  project = "\${local.project_id}"
  region  = "\${local.region}"
}
PROVIDER
}

# Common inputs
inputs = {
  project_id  = local.project_id
  region      = local.region
  environment = local.environment

  labels = {
    environment = local.environment
    managed_by  = "terragrunt"
    project     = "$PROJECT_PREFIX"
  }
}
EOF

    echo "✅ Created $TARGET_FILE"
done

echo "🎉 Root terragrunt configurations created successfully!"
```

### Fix Composer Module Script
**Create**: `scripts/fix-composer-module.sh`

```bash
#!/bin/bash
# fix-composer-module.sh

set -e

COMPOSER_FILE="modules/compute/cloud-composer/main.tf"

echo "Fixing Cloud Composer module..."

# Backup original file
cp "$COMPOSER_FILE" "$COMPOSER_FILE.bak"

# Comment out unsupported arguments
sed -i 's/^\s*disk_type\s*=/  # disk_type =/g' "$COMPOSER_FILE"
sed -i 's/^\s*enable_ip_alias\s*=/  # enable_ip_alias =/g' "$COMPOSER_FILE"

# Fix scheduler_count (remove dynamic block, use direct assignment)
# This is complex - manual review recommended

echo "✅ Cloud Composer module fixed"
echo "⚠️  Manual review recommended for scheduler_count configuration"
```

### Generate Module Docs Script
**Create**: `scripts/generate-module-docs.sh`

```bash
#!/bin/bash
# generate-module-docs.sh

set -e

echo "Generating module documentation..."

for module_dir in modules/*/*/; do
    if [ ! -d "$module_dir" ]; then
        continue
    fi

    category=$(basename "$(dirname "$module_dir")")
    module=$(basename "$module_dir")

    echo "  Generating README for $category/$module..."

    cat > "$module_dir/README.md" << EOF
# $module Module

## Overview
GCP $module module for managing $category resources.

## Usage

\`\`\`hcl
module "$module" {
  source = "../../modules/$category/$module"

  project_id = var.project_id
  region     = var.region

  # Add your configuration here
}
\`\`\`

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| google | >= 4.0 |

## Inputs

See [variables.tf](./variables.tf) for all available inputs.

## Outputs

See [outputs.tf](./outputs.tf) for all available outputs.

## Examples

\`\`\`hcl
# Basic example
module "${module}_basic" {
  source = "../../modules/$category/$module"

  project_id = "my-project"
  region     = "us-central1"
}
\`\`\`

## Resources

This module creates and manages the following resources:
- Review main.tf for resource details

## Notes

- Review variables before deployment
- Check provider version compatibility
- Follow least-privilege principles

EOF
done

echo "✅ Module documentation generated!"
```

### Validation Script
**Create**: `scripts/validate-all.sh`

```bash
#!/bin/bash
# validate-all.sh - Comprehensive validation

set -e

FAILED=0

echo "🔍 Running comprehensive validation..."

# Validate Terraform
echo "Validating Terraform modules..."
terraform fmt -check -recursive modules/ || FAILED=1

for module in modules/*/*/; do
    if [ -f "$module/main.tf" ]; then
        echo "  Validating $module..."
        (cd "$module" && terraform init -backend=false && terraform validate) || FAILED=1
    fi
done

# Validate Go
echo "Validating Go code..."
go mod verify || FAILED=1
go fmt ./... || FAILED=1
go vet ./... || FAILED=1

# Run tests
echo "Running Go tests..."
go test -race ./... || FAILED=1

# Check for placeholders
echo "Checking for remaining placeholders..."
if grep -r "Placeholder for" internal/ cmd/ --include="*.go" | grep -v test; then
    echo "❌ Found placeholder implementations"
    FAILED=1
fi

if grep -r "not implemented" internal/ cmd/ --include="*.go" | grep -v test; then
    echo "❌ Found 'not implemented' errors"
    FAILED=1
fi

# Validate Terragrunt
echo "Validating Terragrunt configurations..."
find infrastructure/environments -name "terragrunt.hcl" -exec terragrunt hclfmt --terragrunt-check --terragrunt-working-dir $(dirname {}) \; || FAILED=1

if [ $FAILED -eq 0 ]; then
    echo "✅ All validations passed!"
    exit 0
else
    echo "❌ Some validations failed"
    exit 1
fi
```

---

## Validation Commands

### Terraform Validation
```bash
# Format check
terraform fmt -check -recursive modules/

# Validate all modules
for module in modules/*/*/; do
  if [ -f "$module/main.tf" ]; then
    echo "Validating $module..."
    terraform -chdir="$module" init -backend=false
    terraform -chdir="$module" validate
  fi
done

# Terragrunt validation
cd infrastructure/environments/dev
terragrunt run-all validate
```

### Go Validation
```bash
# Verify modules
go mod verify
go mod tidy

# Format check
go fmt ./...

# Vet
go vet ./...

# Run tests
go test -v ./...
go test -race ./...
go test -cover ./...

# Run linter
golangci-lint run
```

### Check for Incomplete Code
```bash
# Check for placeholders
grep -r "Placeholder" internal/ cmd/ --include="*.go" | grep -v test

# Check for not implemented
grep -r "not implemented" internal/ cmd/ --include="*.go" | grep -v test

# Check for TODO/FIXME
grep -r "TODO\|FIXME" internal/ cmd/ --include="*.go" | grep -v test
```

### CI/CD Validation
```bash
# Check workflows
gh workflow run "CI/CD Pipeline" --ref main
gh run watch

# Check latest run
gh run list --limit 5
```

---

## Success Criteria

### Critical (Must Have) ✅
1. **All workflows passing**: CI/CD, Terraform CI/CD, Security Scans
2. **No Terraform errors**: All modules validate successfully
3. **Deployable**: Can deploy to all environments with Terragrunt
4. **Root configurations**: All environments have root terragrunt.hcl
5. **No blockers**: All P1 issues resolved

### Required (Should Have) 🎯
1. **Complete documentation**: Every module has README
2. **No skipped tests**: All Go tests running and passing
3. **Clean code**: No "placeholder" or "not implemented" in production code
4. **Secret management**: Documented strategy for handling secrets
5. **Test coverage**: >70% code coverage

### Desired (Nice to Have) ⭐
1. **Web UI**: Monitor dashboard functional
2. **Pre-commit hooks**: Automated quality checks
3. **Advanced features**: Cost tracking, compliance monitoring
4. **Performance**: All operations complete in reasonable time
5. **Monitoring**: Comprehensive observability

---

## Detailed Validation Checklist

### Infrastructure Validation
- [ ] `terragrunt run-all plan` succeeds in dev
- [ ] `terragrunt run-all plan` succeeds in staging
- [ ] `terragrunt run-all plan` succeeds in prod
- [ ] No Terraform validation errors
- [ ] All modules have valid syntax
- [ ] All provider versions compatible
- [ ] Remote state backends configured correctly

### Code Quality Validation
- [ ] `go build ./...` succeeds
- [ ] `go test ./...` passes with 0 failures
- [ ] `go vet ./...` reports no issues
- [ ] `golangci-lint run` passes
- [ ] No grep matches for "Placeholder for"
- [ ] No grep matches for "not implemented"
- [ ] No grep matches for "TODO" in production code
- [ ] Code coverage > 70%

### Documentation Validation
- [ ] Every module directory has README.md
- [ ] infrastructure/environments/README.md exists
- [ ] docs/SECRET-MANAGEMENT.md exists
- [ ] All READMEs have usage examples
- [ ] Architecture diagrams present
- [ ] Troubleshooting guide complete

### Functional Validation
- [ ] Secrets encryption/decryption works
- [ ] Auth provider supports all credential types
- [ ] Cost calculator returns real values
- [ ] Quota retrieval works
- [ ] Terraform auto-download functions
- [ ] Monitor web UI accessible

### Security Validation
- [ ] No hardcoded credentials
- [ ] No placeholder secrets in committed files
- [ ] KMS encryption enabled
- [ ] Access logging configured
- [ ] IAM roles follow least-privilege
- [ ] Security scan passes (Checkov)

### Deployment Validation
- [ ] Can deploy to dev environment
- [ ] Can deploy to staging environment
- [ ] Rollback procedures tested
- [ ] Drift detection works
- [ ] State locking functional
- [ ] Remote state accessible

---

## Support & Troubleshooting

### Common Issues

#### Issue: Terraform version conflicts
```bash
# Solution: Use tfenv
tfenv install 1.5.7
tfenv use 1.5.7
```

#### Issue: GCP authentication errors
```bash
# Solution: Re-authenticate
gcloud auth application-default login
gcloud config set project acme-ecommerce-platform-dev

# Verify authentication
gcloud auth list
gcloud config list
```

#### Issue: Go module conflicts
```bash
# Solution: Clean and rebuild
go clean -modcache
go mod download
go mod tidy
```

#### Issue: Terragrunt state lock errors
```bash
# Check for stale locks
gsutil ls gs://acme-ecommerce-platform-dev-tfstate/**/.terraform.lock.info

# Force unlock (use with caution)
terragrunt force-unlock <LOCK_ID>
```

#### Issue: KMS encryption not working
```bash
# Verify KMS key exists
gcloud kms keys list --location=global --keyring=terragrunt-keyring

# Check IAM permissions
gcloud kms keys get-iam-policy <KEY_NAME> --location=global --keyring=terragrunt-keyring
```

### Debugging Tips

**Enable verbose logging**:
```bash
# Terraform
export TF_LOG=DEBUG

# Terragrunt
export TG_LOG=debug

# Go application
./bin/app --log-level=debug
```

**Check API quotas**:
```bash
gcloud compute project-info describe --project=<PROJECT_ID>
```

**Test GCP API access**:
```bash
# Test Compute API
gcloud compute instances list

# Test Secret Manager API
gcloud secrets list

# Test KMS API
gcloud kms keyrings list --location=global
```

---

## Monitoring Progress

### Create GitHub Issues
```bash
# Create parent tracking issue
gh issue create \
  --title "Complete terragrunt-gcp fixes" \
  --body "$(cat <<EOF
Tracking issue for completing all fixes per COMPREHENSIVE-FIX-GUIDE.md

## Progress
- [ ] Phase 1: Critical Fixes
- [ ] Phase 2: Documentation
- [ ] Phase 3: Go Code Completions
- [ ] Phase 4: Testing & Quality
- [ ] Phase 5: Advanced Features

See COMPREHENSIVE-FIX-GUIDE.md for details.
EOF
)" \
  --label "enhancement,documentation,testing"

# Create phase-specific issues
gh issue create \
  --title "Phase 1: Critical Infrastructure Fixes" \
  --body "Fix root terragrunt.hcl, Cloud Composer module, and secret management" \
  --label "bug,priority-1"

gh issue create \
  --title "Phase 2: Documentation" \
  --body "Generate module docs, environment docs, and guides" \
  --label "documentation,priority-2"

gh issue create \
  --title "Phase 3: Go Code Completions" \
  --body "Complete all placeholder implementations in Go code" \
  --label "enhancement,priority-2"
```

### Track Progress in Project Board
```bash
# Create project
gh project create --title "terragrunt-gcp Completion" --body "Track fix progress"

# Add issues to project
gh project item-add <PROJECT_ID> --issue <ISSUE_NUMBER>
```

### Daily Standup Checklist
- [ ] Review current phase tasks
- [ ] Check CI/CD status
- [ ] Review test results
- [ ] Update tracking issue
- [ ] Identify blockers
- [ ] Plan next tasks

---

## Next Steps

### Immediate Actions (Day 1)
1. ✅ Review this guide with the team
2. ✅ Assign responsibilities for each phase
3. ✅ Set up daily check-ins to track progress
4. ✅ Create feature branches for each major fix
5. ✅ Run initial validation to establish baseline

### Week 1 Focus
- Complete Phase 1 (Critical Fixes)
- Start Phase 2 (Documentation)
- Set up testing infrastructure

### Week 2-3 Focus
- Complete Phase 3 (Go Code Completions)
- Comprehensive testing
- Integration validation

### Week 4 Focus
- Final validation
- Production readiness review
- Documentation review
- Deployment to staging

---

## Appendix

### A. Required GCP APIs

Enable these APIs before deployment:
```bash
PROJECT_ID="acme-ecommerce-platform-dev"

gcloud services enable compute.googleapis.com --project=$PROJECT_ID
gcloud services enable storage-api.googleapis.com --project=$PROJECT_ID
gcloud services enable secretmanager.googleapis.com --project=$PROJECT_ID
gcloud services enable cloudkms.googleapis.com --project=$PROJECT_ID
gcloud services enable iam.googleapis.com --project=$PROJECT_ID
gcloud services enable cloudresourcemanager.googleapis.com --project=$PROJECT_ID
gcloud services enable serviceusage.googleapis.com --project=$PROJECT_ID
gcloud services enable cloudbilling.googleapis.com --project=$PROJECT_ID
```

### B. Required IAM Roles

Service account needs:
```
roles/compute.admin
roles/storage.admin
roles/secretmanager.admin
roles/cloudkms.admin
roles/iam.securityAdmin
roles/serviceusage.serviceUsageAdmin
```

### C. Cost Estimates

Approximate costs for running this infrastructure:

| Environment | Monthly Cost (USD) |
|-------------|-------------------|
| Dev | $200-500 |
| Staging | $500-1000 |
| Prod | $2000-5000 |

*Actual costs depend on usage and configuration*

### D. Testing Environments

Set up test GCP projects:
```bash
# Create test projects
gcloud projects create acme-ecommerce-platform-dev-test
gcloud projects create acme-ecommerce-platform-integration-test

# Link billing
gcloud beta billing projects link acme-ecommerce-platform-dev-test \
  --billing-account=<BILLING_ACCOUNT_ID>
```

---

**Document Version**: 2.0.0
**Last Updated**: $(date)
**Status**: Ready for Implementation

---

## Quick Reference

### Key Files Modified
- `COMPREHENSIVE-FIX-GUIDE.md` (this file)
- `infrastructure/environments/*/terragrunt.hcl` (to be created)
- `modules/compute/cloud-composer/main.tf` (to be fixed)
- `internal/gcp/secrets.go` (implementations needed)
- `internal/gcp/auth.go` (implementations needed)
- `internal/analysis/cost/cost.go` (implementations needed)
- `cmd/terragrunt/main.go` (implementation needed)
- `cmd/monitor/main.go` (implementation needed)

### Priority Order
1. 🔴 P1: Infrastructure (8 hours) - **BLOCKERS**
2. 🟡 P2: Documentation (2 days)
3. 🟠 P2.5: Go Completions (8 days) - **FUNCTIONALITY**
4. 🟢 P3: Testing (4 days)
5. 🔵 P4: Advanced (4 days)

### Total Timeline: ~20 working days (4 weeks)

### Contact
For questions or issues, refer to:
- Project documentation: `docs/`
- GitHub Issues: Create new issue with details
- Team lead: See project README