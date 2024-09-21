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

$currentSubscriptions = az account subscription list --output json | ConvertFrom-Json

$containerName = "subs"
$yesterdayBlobUrl = "https://$env:AZURE_STORAGE_ACCOUNT.blob.core.windows.net/$containerName/$fileYesterday"


$yesterdayContent = az storage blob download --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --name $fileYesterday --file $fileYesterday --output none
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
    
            $subscriptionsFormatted += @(
                @{ name = "<b>=== New Subscription ===</b>"; value = "" },
                @{ name = "<b>Subscription ID</b>"; value = $_.subscriptionId },
                @{ name = "<b>Subscription Name</b>"; value = $_.displayName },
                @{ name = "<b>Authorization Source</b>"; value = $_.authorizationSource },
                @{ name = "<b>State</b>"; value = $_.state },
                @{ name = "<b>Tags</b>"; value = $tagsFormatted },
                @{ name = " "; value = "`n---`n" }
            )

            $subscriptionLogEntry = @{
                PartitionKey = "Subscriptions"
                RowKey = [Guid]::NewGuid().ToString()
                SubscriptionID = $_.subscriptionId
                SubscriptionName = $_.displayName
                AuthorizationSource = $_.authorizationSource
                State = $_.state
                Tags = $tagsFormatted
                CreationDate = (Get-Date).ToString("yyyy-MM-dd")
            }

            az storage entity insert --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY `
                --table-name "NewSubscriptionsLog" --entity $subscriptionLogEntry --output none

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

az storage blob upload --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --name $fileToday --file $fileToday --overwrite --output none

$filesToDelete = az storage blob list --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --output json |
    ConvertFrom-Json | Where-Object { (Get-Date $_.properties.lastModified) -lt (Get-Date).AddDays(-30) }

foreach ($file in $filesToDelete) {
    az storage blob delete --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --name $file.name --output none
}

Write-Host "Script completed."

