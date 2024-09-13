# Set date variables for file names
$today = (Get-Date).ToString("yyyy-MM-dd")
$yesterday = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")
$fileToday = "subscriptions_$today.json"
$fileYesterday = "subscriptions_$yesterday.json"

$currentSubscriptions = az account subscription list --output json | ConvertFrom-Json

$containerName = "subscription-reports"
$yesterdayBlobUrl = "https://$env:AZURE_STORAGE_ACCOUNT.blob.core.windows.net/$containerName/$fileYesterday"
$yesterdayContent = az storage blob download --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --name $fileYesterday --file $fileYesterday --output none

if (Test-Path $fileYesterday) {
    $previousSubscriptions = Get-Content -Path $fileYesterday | ConvertFrom-Json
    $newSubscriptions = $currentSubscriptions | Where-Object {
        $_.subscriptionId -notin ($previousSubscriptions | ForEach-Object { $_.subscriptionId })
    }

    if ($newSubscriptions.Count -gt 0) {
        Write-Host "New subscriptions found:"
        $newSubscriptions | Format-Table
    } else {
        Write-Host "No new subscriptions found."
    }
} else {
    Write-Host "Yesterday's subscription file not found. This is likely the first run."
}

$currentSubscriptions | ConvertTo-Json | Set-Content -Path $fileToday


az storage blob upload --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --name $fileToday --file $fileToday --output none


$filesToDelete = az storage blob list --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --output json |
    ConvertFrom-Json | Where-Object { (Get-Date $_.properties.lastModified) -lt (Get-Date).AddDays(-30) }

foreach ($file in $filesToDelete) {
    az storage blob delete --account-name $env:AZURE_STORAGE_ACCOUNT --account-key $env:AZURE_STORAGE_KEY --container-name $containerName --name $file.name --output none
}

Get-AzSubscription
# Write-Host $a

Write-Host "Script completed."
