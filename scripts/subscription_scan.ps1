# # Set date variables for file names
# $today = (Get-Date).ToString("yyyy-MM-dd")
# $yesterday = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")
# $fileToday = "subscriptions_$today.json"
# $fileYesterday = "subscriptions_$yesterday.json"

# $currentSubscriptions = az account subscription list --output json | ConvertFrom-Json

# $containerName = "subs"
# $yesterdayBlobUrl = "https://$env:AZURE_STORAGE_ACCOUNT.blob.core.windows.net/$containerName/$fileYesterday"
# $yesterdayContent = az storage blob download --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --name $fileYesterday --file $fileYesterday --output none

# if (Test-Path $fileYesterday) {
#     $previousSubscriptions = Get-Content -Path $fileYesterday | ConvertFrom-Json
#     $newSubscriptions = $currentSubscriptions | Where-Object {
#         $_.subscriptionId -notin ($previousSubscriptions | ForEach-Object { $_.subscriptionId })
#     }

#     if ($newSubscriptions.Count -gt 0) {
#         Write-Host "New subscriptions found:"
#         $newSubscriptions | Format-Table
#     } else {
#         Write-Host "No new subscriptions found."
#     }
# } else {
#     Write-Host "Yesterday's subscription file not found. This is likely the first run."
# }

# $currentSubscriptions | ConvertTo-Json | Set-Content -Path $fileToday

# az storage blob upload --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --name $fileToday --file $fileToday --output none

# $filesToDelete = az storage blob list --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --output json |
#     ConvertFrom-Json | Where-Object { (Get-Date $_.properties.lastModified) -lt (Get-Date).AddDays(-30) }

# foreach ($file in $filesToDelete) {
#     az storage blob delete --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --name $file.name --output none
# }

# Get-AzSubscription
# # Write-Host $a

# Write-Host "Script completed."


# Set date variables for file names
$today = (Get-Date).ToString("yyyy-MM-dd")
$yesterday = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")
$fileToday = "subscriptions_$today.json"
$fileYesterday = "subscriptions_$yesterday.json"

# Fetch current subscriptions using Azure CLI
$currentSubscriptions = az account subscription list --output json | ConvertFrom-Json

# Define container and blob storage variables
$containerName = "subs"
$yesterdayBlobUrl = "https://$env:AZURE_STORAGE_ACCOUNT.blob.core.windows.net/$containerName/$fileYesterday"

# Download yesterday's subscription file if it exists
$yesterdayContent = az storage blob download --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --name $fileYesterday --file $fileYesterday --output none

if (Test-Path $fileYesterday) {
    # Parse the previous day's subscriptions
    $previousSubscriptions = Get-Content -Path $fileYesterday | ConvertFrom-Json

    # Find new subscriptions
    $newSubscriptions = $currentSubscriptions | Where-Object {
        $_.subscriptionId -notin ($previousSubscriptions | ForEach-Object { $_.subscriptionId })
    }

    if ($newSubscriptions.Count -gt 0) {
        Write-Host "New subscriptions found:"
        $newSubscriptions | Format-Table

        $subscriptionsFormatted = $newSubscriptions | ForEach-Object {
            @{
                title = "Subscription: $($_.displayName)"
                facts = @(
                    @{ name = "Subscription ID"; value = $_.subscriptionId },
                    @{ name = "Authorization Source"; value = $_.authorizationSource },
                    @{ name = "State"; value = $_.state }
                )
            }
        }

        $body = @{
            type = "message"
            attachments = @(
                @{
                    contentType = "application/vnd.microsoft.card.adaptive"
                    content = @{
                        type = "AdaptiveCard"
                        version = "1.0"
                        body = @(
                            @{
                                type = "TextBlock"
                                text = "This is a test message from PowerShell to Teams"
                            }
                        )
                    }
                }
            )
        }

        $jsonBody = $body | ConvertTo-Json -Depth 10

        # Send notification to Microsoft Teams
        # $body = @{
        #     text = $message
        # }
        
        if (-not [string]::IsNullOrEmpty($env:TEAMS_WEBHOOK_URL)) {
            Invoke-RestMethod -Method Post -Uri $env:TEAMS_WEBHOOK_URL -ContentType 'application/json' -Body $jsonBody
            Write-Host "Teams notification sent."
        } else {
            Write-Host "Teams webhook URL is not set."
        }

    } else {
        Write-Host "No new subscriptions found."
    }
} else {
    Write-Host "Yesterday's subscription file not found. This is likely the first run."
}

# Save today's subscription data to a JSON file
$currentSubscriptions | ConvertTo-Json | Set-Content -Path $fileToday

# Upload today's subscription file to Azure Blob Storage
az storage blob upload --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --name $fileToday --file $fileToday --overwrite --output none

# Delete old subscription files older than 30 days
$filesToDelete = az storage blob list --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --output json |
    ConvertFrom-Json | Where-Object { (Get-Date $_.properties.lastModified) -lt (Get-Date).AddDays(-30) }

foreach ($file in $filesToDelete) {
    az storage blob delete --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --name $file.name --output none
}

Write-Host "Script completed."



