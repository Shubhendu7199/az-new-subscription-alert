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

#     if ($null -ne $newSubscriptions -and -not ($newSubscriptions -is [System.Collections.IEnumerable])) {
#         $newSubscriptions = @($newSubscriptions)
#     }

#     if ($newSubscriptions.Count -gt 0) {
#         Write-Host "New subscriptions found:"
#         $newSubscriptions | Format-Table
    
#         $subscriptionsFormatted = @()  
#         $newSubscriptions | ForEach-Object {
#             $subscriptionTags = az tag list --resource-id $_.id --output json | ConvertFrom-Json
#             $tagsFormatted = if ($subscriptionTags.properties.tags) {
#                 $tagStrings = $subscriptionTags.properties.tags.PSObject.Properties | ForEach-Object { "• $($_.Name): $($_.Value)" }
#                 $tagStrings -join "<br/>" 
#             } else {
#                 "No tags"
#             }
    
#             $subscriptionsFormatted += @(
#                 @{ name = "<b>=== New Subscription ===</b>"; value = "" },
#                 @{ name = "<b>Subscription ID</b>"; value = $_.subscriptionId },
#                 @{ name = "<b>Subscription Name</b>"; value = $_.displayName },
#                 @{ name = "<b>Authorization Source</b>"; value = $_.authorizationSource },
#                 @{ name = "<b>State</b>"; value = $_.state },
#                 @{ name = "<b>Tags</b>"; value = $tagsFormatted },
#                 @{ name = " "; value = "`n---`n" }
#             )

#             $subscriptionLogEntry = @{
#                 PartitionKey = "Subscriptions"
#                 RowKey = [Guid]::NewGuid().ToString()
#                 SubscriptionID = $_.subscriptionId
#                 SubscriptionName = $_.displayName
#                 AuthorizationSource = $_.authorizationSource
#                 State = $_.state
#                 Tags = $tagsFormatted
#                 CreationDate = (Get-Date).ToString("yyyy-MM-dd")
#             }

#             az storage entity insert --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY `
#                 --table-name "NewSubscriptionsLog" --entity $subscriptionLogEntry --output none

#         }
    
#         $body = @{
#             "@type" = "MessageCard"
#             "@context" = "http://schema.org/extensions"
#             summary = "New Azure Subscriptions Found"
#             themeColor = "0078D7"
#             title = "🚀 New Azure Subscriptions Found - $today"
#             sections = @(
#                 @{
#                     activityTitle = "Details of newly detected Azure Subscriptions:"
#                     facts = $subscriptionsFormatted
#                 }
#             )
#         }
    
#         $jsonBody = $body | ConvertTo-Json -Depth 10
#         if (-not [string]::IsNullOrEmpty($env:TEAMS_WEBHOOK_URL)) {
#             Invoke-RestMethod -Method Post -Uri $env:TEAMS_WEBHOOK_URL -ContentType 'application/json' -Body $jsonBody
#             Write-Host "Teams notification sent."
#         } else {
#             Write-Host "Teams webhook URL is not set."
#         }
#     } else {
#         $noNewSubsBody = @{
#             "@type" = "MessageCard"
#             "@context" = "http://schema.org/extensions"
#             summary = "No New Azure Subscriptions Found"
#             themeColor = "FFA500"
#             title = "🔔 No New Azure Subscriptions Found - $today"
#             text = "There were no new Azure subscriptions detected since yesterday."
#         }

#         $jsonNoNewSubsBody = $noNewSubsBody | ConvertTo-Json -Depth 10

#         if (-not [string]::IsNullOrEmpty($env:TEAMS_WEBHOOK_URL)) {
#             Invoke-RestMethod -Method Post -Uri $env:TEAMS_WEBHOOK_URL -ContentType 'application/json' -Body $jsonNoNewSubsBody
#             Write-Host "Teams notification for no new subscriptions sent."
#         } else {
#             Write-Host "Teams webhook URL is not set."
#         }
#     }
    
# } else {
#     Write-Host "Yesterday's subscription file not found. This is likely the first run."
# }

# $currentSubscriptions | ConvertTo-Json | Set-Content -Path $fileToday

# az storage blob upload --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --name $fileToday --file $fileToday --overwrite --output none

# $filesToDelete = az storage blob list --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --output json |
#     ConvertFrom-Json | Where-Object { (Get-Date $_.properties.lastModified) -lt (Get-Date).AddDays(-30) }

# foreach ($file in $filesToDelete) {
#     az storage blob delete --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --name $file.name --output none
# }

# Write-Host "Script completed."




# Function to check and create the table if it doesn't exist
function Ensure-TableExists {
    param (
        [string]$tableName,
        [string]$accountName,
        [string]$accountKey
    )

    $existingTables = az storage table list --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --output json | ConvertFrom-Json
    $tableExists = $existingTables | Where-Object { $_.TableName -eq $tableName }

    if (-not $tableExists) {
        Write-Host "Table '$tableName' does not exist. Creating it..."
        try {
            az storage table create --name $tableName --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --output none
            Write-Host "Table '$tableName' created successfully."
        } catch {
            Write-Host "Error: Failed to create the table."
        }
    } else {
        Write-Host "Table '$tableName' already exists."
    }
}

# Set current and previous day dates
$today = (Get-Date).ToString("yyyy-MM-dd")
$yesterday = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")
$fileToday = "subscriptions_$today.json"
$fileYesterday = "subscriptions_$yesterday.json"

# Fetch current subscriptions using Azure CLI
$currentSubscriptions = az account subscription list --output json | ConvertFrom-Json

if ($null -eq $currentSubscriptions) {
    Write-Host "Error: Failed to retrieve current subscriptions."
    exit 1
}

$containerName = "subs"
$tableName = "NewSubscriptionsLog"
$accountName = $env:AZURE_STORAGE_ACCOUNT
$accountKey = $env:AZURE_STORAGE_KEY

# Ensure that the table exists before proceeding with inserting entities
Ensure-TableExists -tableName $tableName -accountName $env:AZURE_STORAGE_ACCOUNT -accountKey $env:AZURE_STORAGE_KEY

$yesterdayBlobUrl = "https://$accountName.blob.core.windows.net/$containerName/$fileYesterday"

try {
    # Download yesterday's subscription file if it exists
    $yesterdayContent = az storage blob download --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --name $fileYesterday --file $fileYesterday --output none
} catch {
    Write-Host "Warning: Could not download the file for yesterday ($fileYesterday). It might be the first run."
}

if (Test-Path $fileYesterday) {
    $previousSubscriptions = Get-Content -Path $fileYesterday | ConvertFrom-Json

    $newSubscriptions = $currentSubscriptions | Where-Object {
        $_.subscriptionId -notin ($previousSubscriptions | ForEach-Object { $_.subscriptionId })
    }

    # Ensure $newSubscriptions is treated as a collection, even if it's a single item
    if ($null -ne $newSubscriptions -and -not ($newSubscriptions -is [System.Collections.IEnumerable])) {
        $newSubscriptions = @($newSubscriptions)
    }

    # If new subscriptions are found
    if ($newSubscriptions.Count -gt 0) {
        Write-Host "New subscriptions found:"
        $newSubscriptions | Format-Table

        $subscriptionsFormatted = @()
        $newSubscriptions | ForEach-Object {
            $subscriptionTags = az tag list --resource-id $_.id --output json | ConvertFrom-Json
            $tagsFormatted = if ($subscriptionTags.properties.tags) {
                $tagStrings = $subscriptionTags.properties.tags.PSObject.Properties | ForEach-Object { "• $($_.Name): $($_.Value)" }
                $tagStrings -join "<br/>"
            } else {
                "No tags"
            }

            $subscriptionsFormatted += @(
                @{ name = "<b>=== New Subscription ===</b>"; value = "" },
                @{ name = "<b>Subscription ID</b>"; value = $_.subscriptionId },
                @{ name = "<b>Subscription Name</b>"; value = $_.displayName },
                @{ name = "<b>Authorization Source</b>"; value = $_.authorizationSource },
                @{ name = "<b>State</b>"; value = $_.state },
                @{ name = "<b>Tags</b>"; value = $tagsFormatted },
                @{ name = " "; value = "`n---`n" }
            )

            # Append each new subscription to Azure Table Storage
            $subscriptionLogEntry = @{
                PartitionKey = "Subscriptions"
                RowKey = [Guid]::NewGuid().ToString()  # Generate a unique RowKey
                SubscriptionID = $_.subscriptionId
                SubscriptionName = $_.displayName
                AuthorizationSource = $_.authorizationSource
                State = $_.state
                Tags = $tagsFormatted
                CreationDate = (Get-Date).ToString("yyyy-MM-dd")
            }

            try {
                az storage entity insert --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY `
        --table-name "NewSubscriptionsLog" --entity $subscriptionLogEntry --output none
            } catch {
                Write-Host "Error: Failed to log new subscription to Azure Table Storage."
            }
        }

        $body = @{
            "@type" = "MessageCard"
            "@context" = "http://schema.org/extensions"
            summary = "New Azure Subscriptions Found"
            themeColor = "0078D7"
            title = "🚀 New Azure Subscriptions Found - $today"
            sections = @(
                @{
                    activityTitle = "Details of newly detected Azure Subscriptions:"
                    facts = $subscriptionsFormatted
                }
            )
        }

        $jsonBody = $body | ConvertTo-Json -Depth 10
        if (-not [string]::IsNullOrEmpty($env:TEAMS_WEBHOOK_URL)) {
            Invoke-RestMethod -Method Post -Uri $env:TEAMS_WEBHOOK_URL -ContentType 'application/json' -Body $jsonBody
            Write-Host "Teams notification sent."
        } else {
            Write-Host "Teams webhook URL is not set."
        }
    } else {
        Write-Host "No new subscriptions found."

        # Send notification for no new subscriptions found
        $noNewSubsBody = @{
            "@type" = "MessageCard"
            "@context" = "http://schema.org/extensions"
            summary = "No New Azure Subscriptions Found"
            themeColor = "FFA500"
            title = "🔔 No New Azure Subscriptions Found - $today"
            text = "There were no new Azure subscriptions detected since yesterday."
        }

        $jsonNoNewSubsBody = $noNewSubsBody | ConvertTo-Json -Depth 10

        if (-not [string]::IsNullOrEmpty($env:TEAMS_WEBHOOK_URL)) {
            Invoke-RestMethod -Method Post -Uri $env:TEAMS_WEBHOOK_URL -ContentType 'application/json' -Body $jsonNoNewSubsBody
            Write-Host "Teams notification for no new subscriptions sent."
        } else {
            Write-Host "Teams webhook URL is not set."
        }
    }

} else {
    Write-Host "Yesterday's subscription file not found. This is likely the first run."
}

# Save today's subscription data to a JSON file
$currentSubscriptions | ConvertTo-Json | Set-Content -Path $fileToday

try {
    # Upload today's subscription file to Azure Blob Storage
    az storage blob upload --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --name $fileToday --file $fileToday --overwrite --output none
} catch {
    Write-Host "Error: Failed to upload today's subscription file."
}

# Delete old subscription files older than 30 days
try {
    $filesToDelete = az storage blob list --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --output json |
        ConvertFrom-Json | Where-Object { (Get-Date $_.properties.lastModified) -lt (Get-Date).AddDays(-30) }

    foreach ($file in $filesToDelete) {
        az storage blob delete --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --name $file.name --output none
    }

    Write-Host "Old files deleted successfully."
} catch {
    Write-Host "Error: Failed to delete old files."
}

Write-Host "Script completed."
