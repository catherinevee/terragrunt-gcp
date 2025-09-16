# PowerShell script to remove all GitHub deployments efficiently
param(
    [string]$Repository = "catherinevee/terraform-gcp",
    [int]$BatchSize = 10
)

Write-Host "=== GITHUB DEPLOYMENTS REMOVAL SCRIPT ===" -ForegroundColor Green
Write-Host "Repository: $Repository" -ForegroundColor White
Write-Host "Batch Size: $BatchSize" -ForegroundColor White

$totalRemoved = 0
$batchCount = 0

do {
    $batchCount++
    Write-Host "`n--- Batch $batchCount ---" -ForegroundColor Yellow
    
    # Get current deployments
    Write-Host "Fetching deployments..." -ForegroundColor Cyan
    $deployments = gh api repos/$Repository/deployments --jq '.[].id' 2>$null
    
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($deployments)) {
        Write-Host "No more deployments found or API error" -ForegroundColor Green
        break
    }
    
    $deploymentIds = $deployments -split "`n" | Where-Object { $_ -ne "" }
    $currentBatch = $deploymentIds | Select-Object -First $BatchSize
    
    Write-Host "Found $($deploymentIds.Count) total deployments" -ForegroundColor White
    Write-Host "Processing $($currentBatch.Count) deployments in this batch" -ForegroundColor White
    
    if ($currentBatch.Count -eq 0) {
        Write-Host "No deployments to process in this batch" -ForegroundColor Green
        break
    }
    
    # Remove deployments in parallel
    $jobs = @()
    foreach ($deploymentId in $currentBatch) {
        $job = Start-Job -ScriptBlock {
            param($repo, $id)
            gh api -X DELETE repos/$repo/deployments/$id 2>$null
            return $LASTEXITCODE
        } -ArgumentList $Repository, $deploymentId
        $jobs += $job
    }
    
    # Wait for all jobs to complete
    Write-Host "Removing deployments..." -ForegroundColor Cyan
    $jobs | Wait-Job | Out-Null
    
    # Check results
    $successCount = 0
    foreach ($job in $jobs) {
        $result = Receive-Job -Job $job
        if ($result -eq 0) {
            $successCount++
        }
        Remove-Job -Job $job
    }
    
    $totalRemoved += $successCount
    Write-Host "Batch $batchCount completed: $successCount/$($currentBatch.Count) deployments removed" -ForegroundColor Green
    Write-Host "Total removed so far: $totalRemoved" -ForegroundColor Cyan
    
    # Small delay to avoid rate limiting
    Start-Sleep -Milliseconds 500
    
} while ($deploymentIds.Count -gt 0)

Write-Host "`n=== DEPLOYMENT REMOVAL COMPLETE ===" -ForegroundColor Green
Write-Host "Total deployments removed: $totalRemoved" -ForegroundColor White
Write-Host "Repository: $Repository" -ForegroundColor White
Write-Host "Status: SUCCESS" -ForegroundColor Green
