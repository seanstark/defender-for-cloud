
param(
    [Parameter(ValueFromPipeline = $true, Mandatory=$true)]
    [string]$subscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$DefenderforServersPlan = 'P2',

    [Parameter(Mandatory = $false)]
    [boolean]$DefenderforCloudApps = $true,

    [Parameter(Mandatory = $false)]
    [boolean]$DefenderforEndpoint = $true,
    
    [Parameter(Mandatory = $false)]
    [boolean]$DefenderforEndpointExcludeLinux = $false,

    [Parameter(Mandatory = $false)]
    [boolean]$DefenderforEndpointUnifiedAgent = $true
)

$subscription = Get-AzSubscription -SubscriptionId $subscriptionId

#Set Defender for Endpoint Integration
$payload = (@{
    kind = 'DataExportSettings'
    properties = @{
        enabled = $DefenderforEndpoint
    }
}) | ConvertTo-Json

$results = Invoke-AzRestMethod -SubscriptionId $subscription.Id -ResourceProviderName 'Microsoft.Security' -ResourceType 'settings' -Name 'WDATP' -ApiVersion '2022-05-01' -Method PUT -Payload $payload
Write-Host ('Configured Defender for Endpoint Integration on Subscription: {0}; Enabled: {1}' -f $subscription.Name, ($results.Content | ConvertFrom-Json).properties.enabled)



#Set Defender for Endpoint Linux Agent
$payload = (@{
    kind = 'DataExportSettings'
    properties = @{
        enabled = $DefenderforEndpointExcludeLinux
    }
}) | ConvertTo-Json

$results = Invoke-AzRestMethod -SubscriptionId $subscription.Id -ResourceProviderName 'Microsoft.Security' -ResourceType 'settings' -Name 'WDATP_EXCLUDE_LINUX_PUBLIC_PREVIEW' -ApiVersion '2022-05-01' -Method PUT -Payload $payload
Write-Host ('Configured Exclude Linux Servers from Defender for Endpoint on Subscription: {0}; Enabled: {1}' -f $subscription.Name, ($results.Content | ConvertFrom-Json).properties.enabled)

#Set Defender for Endpoint Unified Agent
$payload = (@{
    kind = 'DataExportSettings'
    properties = @{
        enabled = $DefenderforEndpointUnifiedAgent
    }
}) | ConvertTo-Json

$results = Invoke-AzRestMethod -SubscriptionId $subscription.Id -ResourceProviderName 'Microsoft.Security' -ResourceType 'settings' -Name 'WDATP_UNIFIED_SOLUTION' -ApiVersion '2022-05-01' -Method PUT -Payload $payload
Write-Host ('Configured Defender for Endpoint Unified Agent on Subscription: {0}; Enabled: {1}' -f $subscription.Name, ($results.Content | ConvertFrom-Json).properties.enabled)

#Set Defender for Cloud Apps Integration
$payload = (@{
    kind = 'DataExportSettings'
    properties = @{
        enabled = $DefenderforCloudApps
    }
}) | ConvertTo-Json

$results = Invoke-AzRestMethod -SubscriptionId $subscription.Id -ResourceProviderName 'Microsoft.Security' -ResourceType 'settings' -Name 'MCAS' -ApiVersion '2022-05-01' -Method PUT -Payload $payload
Write-Host ('Configured Defender for Cloud Apps Integration on Subscription: {0}; Enabled: {1}' -f $subscription.Name, ($results.Content | ConvertFrom-Json).properties.enabled)

#Set Defender For Servers Plan
$payload = (@{
    properties = @{
        pricingTier = 'Standard'
        subPlan = $DefenderforServersPlan
    }
}) | ConvertTo-Json

$results = Invoke-AzRestMethod -SubscriptionId $subscription.Id -ResourceProviderName 'Microsoft.Security' -ResourceType 'pricings' -Name 'VirtualMachines' -ApiVersion '2022-03-01' -Method PUT -Payload $payload
Write-Host ('Configured Defender for Servers Plan on Subscription: {0}; Plan: {1}' -f $subscription.Name, ($results.Content | ConvertFrom-Json).properties.subPlan)