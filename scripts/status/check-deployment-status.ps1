# Check Terraform Deployment Status Script (PowerShell)
# This script checks if the Terraform deployment is "live" or "unalive" (destroyed)

param(
    [string]$ProjectId = $env:GCP_PROJECT_ID ?? "cataziza-platform-dev",
    [string]$Region = $env:GCP_REGION ?? "europe-west1"
)

$ErrorActionPreference = "Stop"

# Configuration
$StatusFile = "deployment-status.json"

Write-Host "🔍 Checking Terraform deployment status for project: $ProjectId" -ForegroundColor Cyan

# Function to check if a resource exists
function Test-ResourceExists {
    param(
        [string]$ResourceType,
        [string]$ResourceName,
        [string]$ResourceRegion = $null
    )
    
    try {
        switch ($ResourceType) {
            "vpc" {
                gcloud compute networks describe $ResourceName --project=$ProjectId 2>$null | Out-Null
                return $LASTEXITCODE -eq 0
            }
            "subnet" {
                gcloud compute networks subnets describe $ResourceName --region=$ResourceRegion --project=$ProjectId 2>$null | Out-Null
                return $LASTEXITCODE -eq 0
            }
            "instance" {
                gcloud compute instances describe $ResourceName --zone="$($ResourceRegion)-a" --project=$ProjectId 2>$null | Out-Null
                return $LASTEXITCODE -eq 0
            }
            "bucket" {
                gsutil ls -b "gs://$ResourceName" 2>$null | Out-Null
                return $LASTEXITCODE -eq 0
            }
            "sql" {
                gcloud sql instances describe $ResourceName --project=$ProjectId 2>$null | Out-Null
                return $LASTEXITCODE -eq 0
            }
            "kms" {
                gcloud kms keyrings describe $ResourceName --location=global --project=$ProjectId 2>$null | Out-Null
                return $LASTEXITCODE -eq 0
            }
            default {
                Write-Warning "Unknown resource type: $ResourceType"
                return $false
            }
        }
    }
    catch {
        return $false
    }
}

# Function to check critical resources
function Test-CriticalResources {
    $LiveCount = 0
    $TotalCount = 0
    
    # Define critical resources to check
    $Resources = @{
        "vpc:cataziza-platform-dev-vpc" = "VPC"
        "subnet:cataziza-web-tier-dev:$Region" = "Web Tier Subnet"
        "subnet:cataziza-app-tier-dev:$Region" = "App Tier Subnet"
        "subnet:cataziza-database-tier-dev:$Region" = "Database Tier Subnet"
        "bucket:cataziza-platform-dev-terraform-state" = "Terraform State Bucket"
        "kms:cataziza-platform-dev-keyring" = "KMS Keyring"
    }
    
    Write-Host "📋 Checking critical resources..." -ForegroundColor Yellow
    
    foreach ($ResourceKey in $Resources.Keys) {
        $Parts = $ResourceKey -split ":"
        $ResourceType = $Parts[0]
        $ResourceName = $Parts[1]
        $ResourceRegion = if ($Parts.Count -gt 2) { $Parts[2] } else { $null }
        
        $TotalCount++
        
        Write-Host "  Checking $($Resources[$ResourceKey])... " -NoNewline
        
        if (Test-ResourceExists -ResourceType $ResourceType -ResourceName $ResourceName -ResourceRegion $ResourceRegion) {
            Write-Host "✓ LIVE" -ForegroundColor Green
            $LiveCount++
        } else {
            Write-Host "✗ UNALIVE" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "📊 Status Summary: $LiveCount/$TotalCount resources are live" -ForegroundColor Cyan
    
    # Determine overall status
    $Percentage = [math]::Round(($LiveCount * 100) / $TotalCount)
    
    if ($Percentage -ge 80) {
        Write-Host "🟢 DEPLOYMENT STATUS: LIVE" -ForegroundColor Green
        "LIVE" | Out-File -FilePath "status.txt" -Encoding UTF8
        return 0
    } elseif ($Percentage -ge 50) {
        Write-Host "🟡 DEPLOYMENT STATUS: PARTIAL" -ForegroundColor Yellow
        "PARTIAL" | Out-File -FilePath "status.txt" -Encoding UTF8
        return 1
    } else {
        Write-Host "🔴 DEPLOYMENT STATUS: UNALIVE" -ForegroundColor Red
        "UNALIVE" | Out-File -FilePath "status.txt" -Encoding UTF8
        return 2
    }
}

# Function to create status JSON
function New-StatusJson {
    param([string]$Status)
    
    $Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $LastChecked = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss UTC")
    
    $StatusData = @{
        status = $Status
        timestamp = $Timestamp
        project_id = $ProjectId
        region = $Region
        last_checked = $LastChecked
    } | ConvertTo-Json -Depth 3
    
    $StatusData | Out-File -FilePath $StatusFile -Encoding UTF8
}

# Main execution
function Main {
    Write-Host "🚀 Starting deployment status check..." -ForegroundColor Cyan
    Write-Host "Project: $ProjectId"
    Write-Host "Region: $Region"
    Write-Host "Timestamp: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss UTC'))"
    Write-Host ""
    
    # Check if gcloud is authenticated
    try {
        $ActiveAccount = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
        if (-not $ActiveAccount) {
            throw "Not authenticated with gcloud"
        }
    }
    catch {
        Write-Host "❌ Error: Not authenticated with gcloud" -ForegroundColor Red
        "UNALIVE" | Out-File -FilePath "status.txt" -Encoding UTF8
        New-StatusJson -Status "UNALIVE"
        exit 1
    }
    
    # Check if project exists and is accessible
    try {
        gcloud projects describe $ProjectId 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Project not found or not accessible"
        }
    }
    catch {
        Write-Host "❌ Error: Project $ProjectId not found or not accessible" -ForegroundColor Red
        "UNALIVE" | Out-File -FilePath "status.txt" -Encoding UTF8
        New-StatusJson -Status "UNALIVE"
        exit 1
    }
    
    # Check critical resources
    $ExitCode = Test-CriticalResources
    if ($ExitCode -eq 0) {
        New-StatusJson -Status "LIVE"
    } elseif ($ExitCode -eq 1) {
        New-StatusJson -Status "PARTIAL"
    } else {
        New-StatusJson -Status "UNALIVE"
    }
    
    Write-Host ""
    Write-Host "✅ Status check completed. Results saved to $StatusFile" -ForegroundColor Green
}

# Run main function
Main
