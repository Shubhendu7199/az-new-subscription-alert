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

#         $subscriptionsFormatted = $newSubscriptions | ForEach-Object {
#             $tagOutput = az tag list --resource-id "/subscriptions/$($_.subscriptionId)" --output json | ConvertFrom-Json
#             $subscriptionTags = if ($tagOutput.properties.tags) {
#                 $tagStrings = $tagOutput.properties.tags.PSObject.Properties | ForEach-Object { "$($_.Name): $($_.Value)" }
#                 $tagStrings -join ", "
#             } else {
#                 "No tags"
#             }
            
                      
#             $subscriptionDetails = az account show --subscription $_.subscriptionId --output json | ConvertFrom-Json
#             @(
#                 @{ name = "Subscription ID"; value = $_.subscriptionId },
#                 @{ name = "Authorization Source"; value = $_.authorizationSource },
#                 @{ name = "State"; value = $_.state },
#                 @{ name = "Tags"; value = $subscriptionTags }
#             )
#         }

#         $body = @{
#             "@type" = "MessageCard"
#             "@context" = "http://schema.org/extensions"
#             summary = "New Azure Subscriptions Found"
#             themeColor = "0078D7"
#             title = "New Azure Subscriptions Found"
#             sections = @(
#               @{
#                 activityTitle = "New Azure Subscriptions:"
#                 facts = $subscriptionsFormatted 
#               }
#             )
#           }
        

#         $jsonBody = $body | ConvertTo-Json -Depth 10
        
#         if (-not [string]::IsNullOrEmpty($env:TEAMS_WEBHOOK_URL)) {
#             Invoke-RestMethod -Method Post -Uri $env:TEAMS_WEBHOOK_URL -ContentType 'application/json' -Body $jsonBody
#             Write-Host "Teams notification sent."
#         } else {
#             Write-Host "Teams webhook URL is not set."
#         }

#     } else {
#         Write-Host "No new subscriptions found."
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

        # Create facts array for each new subscription
        $subscriptionsFormatted = @()  # Initialize an empty array to store formatted subscription facts
        $newSubscriptions | ForEach-Object {
            $subscriptionTags = az tag list --resource-id $_.id --output json | ConvertFrom-Json
            $tagsFormatted = if ($subscriptionTags.properties.tags) {
                $subscriptionTags.properties.tags.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" } -join ", "
            } else {
                "No tags"
            }

            # Append each subscription's facts to the array
            $subscriptionsFormatted += @(
                @{ name = "**Subscription ID**"; value = "`n$($_.subscriptionId)`n---" },
                @{ name = "**Authorization Source**"; value = $_.authorizationSource },
                @{ name = "**State**"; value = $_.state },
                @{ name = "**Tags**"; value = $tagsFormatted },
                @{ name = " "; value = "`n---`n" }  # Add a blank row to separate subscriptions
            )
        }

        # Prepare the message body for Teams
        $body = @{
            "@type" = "MessageCard"
            "@context" = "http://schema.org/extensions"
            summary = "New Azure Subscriptions Found"
            themeColor = "0078D7"
            title = "New Azure Subscriptions Found"
            sections = @(
                @{
                    activityTitle = "New Azure Subscriptions"
                    activitySubtitle = "Details of newly detected Azure Subscriptions:"
                    facts = $subscriptionsFormatted
                }
            )
        }

        $jsonBody = $body | ConvertTo-Json -Depth 10
        
        # Send notification to Microsoft Teams
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
