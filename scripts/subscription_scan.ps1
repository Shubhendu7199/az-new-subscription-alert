# $today = (Get-Date).ToString("yyyy-MM-dd")
# $yesterday = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")
# $fileToday = "subscriptions_$today.json"
# $fileYesterday = "subscriptions_$yesterday.json"
# $tenantId = (az account show --query tenantId -o tsv)

# $currentSubscriptions = az account subscription list --output json | ConvertFrom-Json

# if ($null -eq $currentSubscriptions) {
#     Write-Host "Error: Failed to retrieve current subscriptions."
#     exit 1
# }

# $containerName = "subs"
# $accountName = $env:AZURE_STORAGE_ACCOUNT
# $accountKey = $env:AZURE_STORAGE_KEY

# $yesterdayBlobUrl = "https://$accountName.blob.core.windows.net/$containerName/$fileYesterday"

# try {
#     $yesterdayContent = az storage blob download --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --name $fileYesterday --file $fileYesterday --output none
# } catch {
#     Write-Host "Warning: Could not download the file for yesterday ($fileYesterday). It might be the first run."
# }

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

#         $subscriptionOverviewUrl = "https://portal.azure.com/#@$tenantId/resource/subscriptions/$($_.subscriptionId)/overview"

#             $subscriptionsFormatted += @(
#                 @{ name = "<b>=== New Subscription ===</b>"; value = "" },
#                 @{ name = "<b>Subscription ID</b>"; value = $_.subscriptionId },
#                 @{ name = "<b>Subscription Name</b>"; value = $_.displayName },
#                 @{ name = "<b>Authorization Source</b>"; value = $_.authorizationSource },
#                 @{ name = "<b>State</b>"; value = $_.state },
#                 @{ name = "<b>Tags</b>"; value = $tagsFormatted },
#                 @{ name = ""; value = "[View Subscription Overview]($subscriptionOverviewUrl)" },
#                 @{ name = " "; value = "`n---`n" }
#             )

#             $potentialActions += @(
#                 @{
#                     "@type" = "OpenUri"
#                     name = "View Subscription Overview"
#                     targets = @(
#                         @{
#                             os = "default"
#                             uri = $subscriptionOverviewUrl
#                         }
#                     )
#                 }
#             )
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
#                     potentialAction = $potentialActions
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
#         Write-Host "No new subscriptions found."

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

# try {

#     az storage blob upload --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --tier Cool --name $fileToday --file $fileToday --overwrite --output none
# } catch {
#     Write-Host "Error: Failed to upload today's subscription file."
# }

# try {
#     $filesToDelete = az storage blob list --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --output json |
#         ConvertFrom-Json | Where-Object { (Get-Date $_.properties.lastModified) -lt (Get-Date).AddDays(-30) }

#     foreach ($file in $filesToDelete) {
#         az storage blob delete --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --name $file.name --output none
#     }

#     Write-Host "Old files deleted successfully."
# } catch {
#     Write-Host "Error: Failed to delete old files."
# }

# Write-Host "Script completed."



############################################################################################################################################################################
# Function to store new subscriptions in Azure Table Storage
function Add-SubscriptionToTable {
    param (
        [string]$subscriptionId,
        [string]$subscriptionName,
        [string]$tags,
        [string]$state,
        [string]$date
    )

    # Ensure the table exists, if not create it
    $tableName = "SubscriptionData"
    try {
        $tableExists = az storage table exists --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --name $tableName --query exists --output tsv
        if ($tableExists -eq "false") {
            Write-Host "Table $tableName does not exist. Creating table..."
            az storage table create --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --name $tableName --output none
            Write-Host "Table $tableName created successfully."
        }
    } catch {
        Write-Host "Error: Failed to check or create the table. Error details: $_"
        exit 1
    }

    # Construct the entity insert command as a string
    $entityCommand = "PartitionKey=SubscriptionData RowKey=$subscriptionId Date=$date SubscriptionID=$subscriptionId SubscriptionName=`"$subscriptionName`" Tags=`"$tags`" State=$state"

    # Insert entity into Azure Table Storage using the constructed command
    try {
        az storage entity insert --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --table-name $tableName --entity $entityCommand
        Write-Host "Subscription entity inserted successfully into Table Storage."
    } catch {
        Write-Host "Error: Failed to insert entity into Table Storage. Error details: $_"
    }
}



$today = (Get-Date).ToString("yyyy-MM-dd")
$yesterday = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")
$fileToday = "subscriptions_$today.json"
$fileYesterday = "subscriptions_$yesterday.json"
$tenantId = (az account show --query tenantId -o tsv)

$currentSubscriptions = az account subscription list --output json | ConvertFrom-Json

if ($null -eq $currentSubscriptions) {
    Write-Host "Error: Failed to retrieve current subscriptions."
    exit 1
}

$containerName = "subs"
$accountName = $env:AZURE_STORAGE_ACCOUNT
$accountKey = $env:AZURE_STORAGE_KEY

$yesterdayBlobUrl = "https://$accountName.blob.core.windows.net/$containerName/$fileYesterday"

try {
    $yesterdayContent = az storage blob download --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --name $fileYesterday --file $fileYesterday --output none
} catch {
    Write-Host "Warning: Could not download the file for yesterday ($fileYesterday). It might be the first run."
}

if (Test-Path $fileYesterday) {
    $previousSubscriptions = Get-Content -Path $fileYesterday | ConvertFrom-Json

    $newSubscriptions = $currentSubscriptions | Where-Object {
        $_.subscriptionId -notin ($previousSubscriptions | ForEach-Object { $_.subscriptionId })
    }

    if ($null -ne $newSubscriptions -and -not ($newSubscriptions -is [System.Collections.IEnumerable])) {
        $newSubscriptions = @($newSubscriptions)
    }

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

        $subscriptionOverviewUrl = "https://portal.azure.com/#@$tenantId/resource/subscriptions/$($_.subscriptionId)/overview"

            $subscriptionsFormatted += @(
                @{ name = "<b>=== New Subscription ===</b>"; value = "" },
                @{ name = "<b>Subscription ID</b>"; value = $_.subscriptionId },
                @{ name = "<b>Subscription Name</b>"; value = $_.displayName },
                @{ name = "<b>Authorization Source</b>"; value = $_.authorizationSource },
                @{ name = "<b>State</b>"; value = $_.state },
                @{ name = "<b>Tags</b>"; value = $tagsFormatted },
                @{ name = ""; value = "[View Subscription Overview]($subscriptionOverviewUrl)" },
                @{ name = " "; value = "`n---`n" }
            )

            $potentialActions += @(
                @{
                    "@type" = "OpenUri"
                    name = "View Subscription Overview"
                    targets = @(
                        @{
                            os = "default"
                            uri = $subscriptionOverviewUrl
                        }
                    )
                }
            )
            Add-SubscriptionToTable -subscriptionId $_.subscriptionId -subscriptionName $_.displayName -tags $tagsFormatted -state $_.state -date $today
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
                    potentialAction = $potentialActions
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


$currentSubscriptions | ConvertTo-Json | Set-Content -Path $fileToday

try {

    az storage blob upload --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --tier Cool --name $fileToday --file $fileToday --overwrite --output none
} catch {
    Write-Host "Error: Failed to upload today's subscription file."
}

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