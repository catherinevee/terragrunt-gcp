# Get AWS Account ID
$accountId = aws sts get-caller-identity --query Account --output text

# Create budget JSON
$budgetJson = @{
    BudgetName = "IAM-Role-Vendor-Monitoring"
    BudgetLimit = @{
        Amount = "50"
        Unit = "USD"
    }
    TimeUnit = "MONTHLY"
    BudgetType = "COST"
    TimePeriod = @{
        Start = "2025-01-01_00:00"
        End = "2087-06-15_00:00"
    }
} | ConvertTo-Json -Depth 10

# Create the budget
Write-Host "Creating budget for IAM Role Vending Machine..."
aws budgets create-budget --account-id $accountId --budget $budgetJson

# Create notification JSON
$notificationJson = @{
    NotificationType = "ACTUAL"
    ComparisonOperator = "GREATER_THAN"
    Threshold = 40
    ThresholdType = "PERCENTAGE"
} | ConvertTo-Json -Depth 10

$subscribersJson = @(
    @{
        SubscriptionType = "EMAIL"
        Address = "catherine.vee@outlook.com"
    }
) | ConvertTo-Json -Depth 10

# Create the notification
Write-Host "Creating budget notification..."
aws budgets create-notification --account-id $accountId --budget-name "IAM-Role-Vendor-Monitoring" --notification $notificationJson --subscribers $subscribersJson
