#Get All Subscriptions
$subscriptions = Get-AzSubscription -TenantId (Get-AzContext).Tenant | Where State -eq 'Enabled'

$friendlysettings = @()

ForEach ($subscription in $subscriptions){
    $settings = $null
    $settings = ((Invoke-AzRestMethod -SubscriptionId $subscription.Id -ResourceProviderName 'Microsoft.Security' -ResourceType 'settings' -ApiVersion '2022-05-01' -Method Get).Content | ConvertFrom-Json).Value
    $defenderForServersPlan = (Invoke-AzRestMethod -SubscriptionId $subscription.Id -ResourceProviderName 'Microsoft.Security' -ResourceType 'pricings' -Name 'VirtualMachines' -ApiVersion '2022-03-01' -Method Get).Content | ConvertFrom-Json
    $subscription.Name
    if($settings){
        $friendlysettings += ([PSCustomObject]@{
            subscriptionName = $subscription.Name
            subscriptionId = $subscription.Id
            DefenderforServersPlan = $(if($defenderForServersPlan.properties.subPlan -eq $null){'notenabled'}else{$defenderForServersPlan.properties.subPlan})
            DefenderforCloudApps = ($settings | where name -eq 'MCAS').Properties.enabled
            DefenderforEndpoint = ($settings | where name -eq 'WDATP').Properties.enabled
            DefenderforEndpointExcludeLinux = ($settings | where name -eq 'WDATP_EXCLUDE_LINUX_PUBLIC_PREVIEW').Properties.enabled
            DefenderforEndpointUnifiedAgent = ($settings | where name -eq 'WDATP_UNIFIED_SOLUTION').Properties.enabled
            SentinelBiDirectionalAlertSync = ($settings | where name -eq 'Sentinel').Properties.enabled
            error = $null
        })
    }else{
        $friendlysettings += ([PSCustomObject]@{
            subscriptionName = $subscription.Name
            subscriptionId = $subscription.Id
            DefenderforServersPlan = 'no settings returned'
            DefenderforCloudApps = 'no settings returned'
            DefenderforEndpoint = 'no settings returned'
            DefenderforEndpointExcludeLinux = 'no settings returned'
            DefenderforEndpointUnifiedAgent = 'no settings returned'
            SentinelBiDirectionalAlertSync = 'no settings returned'
            error = ('No Settings Returned for Subscription: {0}, you may not have security reader rights assigned' -f $subscription.Name)
        })
    }
}