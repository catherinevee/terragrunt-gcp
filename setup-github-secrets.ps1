# GitHub Actions Secrets Setup Script for Terragrunt GCP Infrastructure (PowerShell Version)
# This script automates the setup of GCP Workload Identity Federation and GitHub secrets

param(
    [string]$ProjectId,
    [string]$GitHubRepo,
    [string]$OrgName = "yanka",
    [string]$Region = "europe-west1",
    [switch]$UseServiceAccountKey,
    [switch]$SkipSlack,
    [switch]$SkipInfracost
)

# Colors for output
function Write-Header {
    param([string]$Message)
    Write-Host "`n======================================" -ForegroundColor Blue
    Write-Host $Message -ForegroundColor Blue
    Write-Host "======================================`n" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check prerequisites
Write-Header "Checking Prerequisites"

$requiredCommands = @("gcloud", "gh", "gsutil")
foreach ($cmd in $requiredCommands) {
    if (!(Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "$cmd is not installed. Please install it first."
        exit 1
    }
}
Write-Success "All required tools are installed"

# Configuration
Write-Header "Configuration Setup"

# Get project ID
if (!$ProjectId) {
    $currentProject = gcloud config get-value project 2>$null
    if ($currentProject) {
        Write-Host "Current GCP project: $currentProject" -ForegroundColor Green
        $useCurrentProject = Read-Host "Use this project? (y/n)"
        if ($useCurrentProject -eq 'y') {
            $ProjectId = $currentProject
        } else {
            $ProjectId = Read-Host "Enter GCP Project ID"
        }
    } else {
        $ProjectId = Read-Host "Enter GCP Project ID"
    }
}

# Get GitHub repository
if (!$GitHubRepo) {
    try {
        $currentRepo = gh repo view --json nameWithOwner -q .nameWithOwner 2>$null
        if ($currentRepo) {
            Write-Host "Current GitHub repository: $currentRepo" -ForegroundColor Green
            $useCurrentRepo = Read-Host "Use this repository? (y/n)"
            if ($useCurrentRepo -eq 'y') {
                $GitHubRepo = $currentRepo
            } else {
                $GitHubRepo = Read-Host "Enter GitHub repository (format: owner/repo)"
            }
        } else {
            $GitHubRepo = Read-Host "Enter GitHub repository (format: owner/repo)"
        }
    } catch {
        $GitHubRepo = Read-Host "Enter GitHub repository (format: owner/repo)"
    }
}

# Authentication method
if (!$UseServiceAccountKey) {
    Write-Host "`nSelect authentication method:"
    Write-Host "1) Workload Identity Federation (Recommended - Most Secure)"
    Write-Host "2) Service Account Key (Less Secure)"
    $authChoice = Read-Host "Enter choice (1 or 2)"
    $UseServiceAccountKey = ($authChoice -eq "2")
}

# Optional features
if (!$SkipSlack) {
    $setupSlack = Read-Host "`nSetup Slack notifications? (y/n)"
    $SkipSlack = ($setupSlack -ne "y")
}

if (!$SkipInfracost) {
    $setupInfracost = Read-Host "Setup Infracost for cost estimation? (y/n)"
    $SkipInfracost = ($setupInfracost -ne "y")
}

# Summary
Write-Header "Configuration Summary"
Write-Host "Project ID: $ProjectId"
Write-Host "GitHub Repository: $GitHubRepo"
Write-Host "Organization: $OrgName"
Write-Host "Region: $Region"
Write-Host "Authentication: $(if (!$UseServiceAccountKey) {'Workload Identity Federation'} else {'Service Account Key'})"

$confirm = Read-Host "`nProceed with this configuration? (y/n)"
if ($confirm -ne "y") {
    Write-Error "Setup cancelled"
    exit 1
}

# Set gcloud project
Write-Header "Setting GCP Project"
gcloud config set project $ProjectId
Write-Success "Project set to $ProjectId"

# Get project number
$projectNumber = gcloud projects describe $ProjectId --format="value(projectNumber)"
Write-Success "Project number: $projectNumber"

# Enable required APIs
Write-Header "Enabling Required GCP APIs"
$apis = @(
    "compute.googleapis.com",
    "container.googleapis.com",
    "storage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com"
)

foreach ($api in $apis) {
    Write-Host "Enabling $api..."
    Start-Job -ScriptBlock {
        param($api, $projectId)
        gcloud services enable $api --project=$projectId
    } -ArgumentList $api, $ProjectId | Out-Null
}

Get-Job | Wait-Job | Remove-Job
Write-Success "All APIs enabled"

# Create service account
Write-Header "Creating Service Account"
$saName = "github-actions-sa"
$saEmail = "$saName@$ProjectId.iam.gserviceaccount.com"

$saExists = gcloud iam service-accounts describe $saEmail --project=$ProjectId 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Warning "Service account already exists: $saEmail"
} else {
    gcloud iam service-accounts create $saName `
        --display-name="GitHub Actions Service Account" `
        --description="Used by GitHub Actions for Terragrunt deployments" `
        --project=$ProjectId
    Write-Success "Service account created: $saEmail"
}

# Grant IAM roles
Write-Header "Granting IAM Roles"
$roles = @(
    "roles/editor",
    "roles/storage.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/iam.serviceAccountUser",
    "roles/iam.serviceAccountKeyAdmin"
)

foreach ($role in $roles) {
    Write-Host "Granting $role..."
    gcloud projects add-iam-policy-binding $ProjectId `
        --member="serviceAccount:$saEmail" `
        --role="$role" `
        --condition=None 2>$null | Out-Null
}
Write-Success "All IAM roles granted"

# Setup authentication
$secrets = @{
    "GCP_PROJECT_ID" = $ProjectId
}

if (!$UseServiceAccountKey) {
    # Workload Identity Federation Setup
    Write-Header "Setting up Workload Identity Federation"
    
    $poolName = "github-pool"
    $providerName = "github-provider"
    
    # Create workload identity pool
    $poolExists = gcloud iam workload-identity-pools describe $poolName --location=global --project=$ProjectId 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Warning "Workload identity pool already exists: $poolName"
    } else {
        gcloud iam workload-identity-pools create $poolName `
            --location="global" `
            --display-name="GitHub Actions Pool" `
            --description="Pool for GitHub Actions authentication" `
            --project=$ProjectId
        Write-Success "Workload identity pool created: $poolName"
    }
    
    # Create workload identity provider
    $providerExists = gcloud iam workload-identity-pools providers describe $providerName `
        --workload-identity-pool=$poolName `
        --location=global `
        --project=$ProjectId 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Warning "Workload identity provider already exists: $providerName"
    } else {
        gcloud iam workload-identity-pools providers create-oidc $providerName `
            --location="global" `
            --workload-identity-pool="$poolName" `
            --display-name="GitHub Provider" `
            --description="OIDC provider for GitHub Actions" `
            --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" `
            --issuer-uri="https://token.actions.githubusercontent.com" `
            --project=$ProjectId
        Write-Success "Workload identity provider created: $providerName"
    }
    
    # Get provider resource name
    $wifProvider = gcloud iam workload-identity-pools providers describe $providerName `
        --location="global" `
        --workload-identity-pool="$poolName" `
        --project=$ProjectId `
        --format="value(name)"
    
    # Bind service account to workload identity
    gcloud iam service-accounts add-iam-policy-binding $saEmail `
        --role="roles/iam.workloadIdentityUser" `
        --member="principalSet://iam.googleapis.com/$wifProvider/attribute.repository/$GitHubRepo" `
        --project=$ProjectId
    
    Write-Success "Workload Identity Federation configured"
    
    $secrets["WIF_PROVIDER"] = $wifProvider
    $secrets["WIF_SERVICE_ACCOUNT"] = $saEmail
    
} else {
    # Service Account Key Setup
    Write-Header "Setting up Service Account Key"
    
    $keyFile = "github-actions-key.json"
    
    # Create service account key
    gcloud iam service-accounts keys create $keyFile `
        --iam-account=$saEmail `
        --project=$ProjectId
    
    # Encode key
    $keyContent = Get-Content $keyFile -Raw
    $encodedKey = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($keyContent))
    
    Write-Success "Service account key created"
    Write-Warning "Key file saved as $keyFile - keep this secure!"
    
    $secrets["GCP_SERVICE_ACCOUNT_KEY"] = $encodedKey
}

# Create GCS buckets
Write-Header "Creating GCS Buckets"

$stateBucket = "$OrgName-terraform-state-$ProjectId"
$backupBucket = "$OrgName-terraform-backups-$ProjectId"

foreach ($bucket in @($stateBucket, $backupBucket)) {
    $bucketExists = gsutil ls -b gs://$bucket 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Warning "Bucket already exists: $bucket"
    } else {
        gsutil mb -p $ProjectId -c STANDARD -l $Region gs://$bucket/
        gsutil versioning set on gs://$bucket/
        
        # Enable uniform bucket-level access (recommended for Terraform state)
        gsutil uniformbucketlevelaccess set on gs://$bucket/
        
        # Set lifecycle policy for backup bucket only
        if ($bucket -eq $backupBucket) {
            $lifecycleJson = @"
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 90}
      }
    ]
  }
}
"@
            $lifecycleJson | Out-File -FilePath "$env:TEMP\lifecycle.json" -Encoding UTF8
            gsutil lifecycle set "$env:TEMP\lifecycle.json" gs://$bucket/
            Remove-Item "$env:TEMP\lifecycle.json" -Force -ErrorAction SilentlyContinue
        }
        
        Write-Success "Bucket created: $bucket"
    }
}

$secrets["STATE_BUCKET"] = $stateBucket
$secrets["BACKUP_BUCKET"] = $backupBucket

# Setup GitHub secrets
Write-Header "Setting GitHub Secrets"

# Check if gh is authenticated
$ghStatus = gh auth status 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "GitHub CLI is not authenticated. Please run: gh auth login"
    exit 1
}

# Set secrets in GitHub
foreach ($secret in $secrets.GetEnumerator()) {
    Write-Host "Setting secret: $($secret.Key)"
    $secret.Value | gh secret set $secret.Key --repo $GitHubRepo
}

# Optional: Slack webhook
if (!$SkipSlack) {
    Write-Header "Setting up Slack Notifications"
    Write-Host "Please create a Slack webhook:"
    Write-Host "1. Go to https://api.slack.com/apps"
    Write-Host "2. Create new app → Incoming Webhooks → Add New Webhook"
    Write-Host "3. Copy the webhook URL"
    Write-Host ""
    $slackWebhook = Read-Host "Enter Slack Webhook URL (or press Enter to skip)"
    if ($slackWebhook) {
        $slackWebhook | gh secret set SLACK_WEBHOOK --repo $GitHubRepo
        Write-Success "Slack webhook configured"
    }
}

# Optional: Infracost
if (!$SkipInfracost) {
    Write-Header "Setting up Infracost"
    Write-Host "Please sign up at https://www.infracost.io/ to get an API key"
    $infracostKey = Read-Host "Enter Infracost API key (or press Enter to skip)"
    if ($infracostKey) {
        $infracostKey | gh secret set INFRACOST_API_KEY --repo $GitHubRepo
        Write-Success "Infracost configured"
    }
}

# Create environments in GitHub
Write-Header "Creating GitHub Environments"

foreach ($env in @("dev", "staging", "prod")) {
    Write-Host "Creating environment: $env"
    $waitTimer = if ($env -eq "prod") { 5 } else { 0 }
    
    $body = @{
        wait_timer = $waitTimer
        reviewers = @()
        deployment_branch_policy = $null
    } | ConvertTo-Json
    
    # Write JSON to temp file and use as input
    $tempFile = "$env:TEMP\gh-env-$env.json"
    $body | Out-File -FilePath $tempFile -Encoding UTF8
    
    try {
        gh api --method PUT -H "Accept: application/vnd.github+json" `
            "/repos/$GitHubRepo/environments/$env" `
            --input $tempFile 2>$null | Out-Null
    }
    catch {
        # Environment might already exist, which is fine
    }
    finally {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}
Write-Success "GitHub environments created"

# Summary
Write-Header "Setup Complete!"

Write-Host "[OK] Service Account: $saEmail" -ForegroundColor Green
Write-Host "[OK] State Bucket: $stateBucket" -ForegroundColor Green
Write-Host "[OK] Backup Bucket: $backupBucket" -ForegroundColor Green

if (!$UseServiceAccountKey) {
    Write-Host "[OK] WIF Provider: $wifProvider" -ForegroundColor Green
} else {
    Write-Host "[OK] Service Account Key: Stored in GitHub secrets" -ForegroundColor Green
}

Write-Host "`nGitHub Secrets configured:"
gh secret list --repo $GitHubRepo

Write-Host ""
Write-Success "Your GitHub Actions pipeline is ready to use!"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Update infrastructure/accounts/account.hcl with:"
Write-Host "   - organization = `"$OrgName`""
Write-Host "   - project_id = `"$ProjectId`""
Write-Host ""
Write-Host "2. Commit and push your code:"
Write-Host "   git add ."
Write-Host "   git commit -m `"feat: configure infrastructure`""
Write-Host "   git push origin main"
Write-Host ""
Write-Host "3. Create a pull request to trigger the pipeline:"
Write-Host "   git checkout -b feature/test-pipeline"
Write-Host "   git push origin feature/test-pipeline"
Write-Host "   gh pr create --title `"Test pipeline`" --body `"Testing GitHub Actions`""
Write-Host ""
Write-Host "4. Monitor the pipeline in GitHub Actions tab"

# Cleanup
if ($UseServiceAccountKey -and (Test-Path $keyFile)) {
    Write-Host ""
    $deleteKey = Read-Host "Delete local service account key file? (recommended) (y/n)"
    if ($deleteKey -eq 'y') {
        Remove-Item $keyFile -Force
        Write-Success "Key file deleted"
    } else {
        Write-Warning "Remember to secure or delete $keyFile"
    }
}

Write-Header "Script Completed Successfully!"