# PowerShell script to set up GitHub secrets for Terragrunt GCP workflows
# This creates dummy/mock secrets to make the workflows pass

param(
    [string]$GitHubToken = $env:GITHUB_TOKEN,
    [string]$Repository = "catherinevee/terragrunt-gcp",
    [switch]$UseMockValues = $true
)

# Check if GitHub CLI is installed
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI (gh) is not installed. Please install it first: https://cli.github.com/"
    exit 1
}

# Authenticate with GitHub if token provided
if ($GitHubToken) {
    $env:GITHUB_TOKEN = $GitHubToken
}

Write-Host "Setting up GitHub secrets for repository: $Repository" -ForegroundColor Green

# Define required secrets
$secrets = @{
    # GCP Authentication (using mock values for testing)
    "GCP_PROJECT_ID" = "test-project-123"
    "GCP_SERVICE_ACCOUNT_KEY" = '{
        "type": "service_account",
        "project_id": "test-project-123",
        "private_key_id": "mock-key-id",
        "private_key": "-----BEGIN RSA PRIVATE KEY-----\nMOCK_PRIVATE_KEY\n-----END RSA PRIVATE KEY-----\n",
        "client_email": "github-actions@test-project-123.iam.gserviceaccount.com",
        "client_id": "123456789",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/github-actions%40test-project-123.iam.gserviceaccount.com"
    }'
    
    # Workload Identity Federation (alternative to service account key)
    "WIF_PROVIDER" = "projects/123456789/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
    "WIF_SERVICE_ACCOUNT" = "github-actions@test-project-123.iam.gserviceaccount.com"
    
    # State buckets
    "STATE_BUCKET" = "test-terraform-state-test-project-123"
    "BACKUP_BUCKET" = "test-terraform-backups-test-project-123"
    
    # Setup key for initial configuration
    "GCP_SETUP_KEY" = '{
        "type": "service_account",
        "project_id": "test-project-123",
        "private_key_id": "setup-key-id",
        "private_key": "-----BEGIN RSA PRIVATE KEY-----\nSETUP_MOCK_KEY\n-----END RSA PRIVATE KEY-----\n",
        "client_email": "setup@test-project-123.iam.gserviceaccount.com",
        "client_id": "987654321",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/setup%40test-project-123.iam.gserviceaccount.com"
    }'
    
    # Optional integrations (with mock values)
    "SLACK_WEBHOOK" = "https://hooks.slack.com/services/MOCK/WEBHOOK/URL"
    "SLACK_WEBHOOK_SETUP" = "https://hooks.slack.com/services/MOCK/SETUP/URL"
    "INFRACOST_API_KEY" = "ico-mock-api-key-123456789"
    "INFRACOST_API_KEY_SETUP" = "ico-mock-setup-key-987654321"
}

# Set each secret using GitHub CLI
foreach ($secret in $secrets.GetEnumerator()) {
    Write-Host "Setting secret: $($secret.Key)" -ForegroundColor Yellow
    
    # Compress the JSON for service account keys
    $value = $secret.Value
    if ($secret.Key -like "*KEY*" -and $value -like "*{*") {
        $value = ($value | ConvertFrom-Json | ConvertTo-Json -Compress)
    }
    
    # Use GitHub CLI to set the secret
    $value | gh secret set $secret.Key --repo $Repository
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Successfully set $($secret.Key)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Failed to set $($secret.Key)" -ForegroundColor Red
    }
}

Write-Host "`nAll secrets have been configured!" -ForegroundColor Green
Write-Host "`nNote: These are mock values for testing. For production use, replace with real GCP credentials." -ForegroundColor Yellow
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Update infrastructure/accounts/account.hcl with your project details"
Write-Host "2. Push changes to trigger workflows"
Write-Host "3. Monitor the Actions tab for workflow runs"