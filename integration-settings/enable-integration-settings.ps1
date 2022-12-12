
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
    [boolean]$DefenderforEndpointLinux = $true,

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

Invoke-AzRestMethod -SubscriptionId $subscription.Id -ResourceProviderName 'Microsoft.Security' -ResourceType 'settings' -Name 'WDATP' -ApiVersion '2022-05-01' -Method PUT -Payload $payload

#Set Defender for Endpoint Linux Agent
$payload = (@{
    kind = 'DataExportSettings'
    properties = @{
        enabled = $DefenderforEndpointLinux
    }
}) | ConvertTo-Json

Invoke-AzRestMethod -SubscriptionId $subscription.Id -ResourceProviderName 'Microsoft.Security' -ResourceType 'settings' -Name 'WDATP_EXCLUDE_LINUX_PUBLIC_PREVIEW' -ApiVersion '2022-05-01' -Method PUT -Payload $payload

#Set Defender for Endpoint Unified Agent
$payload = (@{
    kind = 'DataExportSettings'
    properties = @{
        enabled = $DefenderforEndpointUnifiedAgent
    }
}) | ConvertTo-Json

Invoke-AzRestMethod -SubscriptionId $subscription.Id -ResourceProviderName 'Microsoft.Security' -ResourceType 'settings' -Name 'WDATP_UNIFIED_SOLUTION' -ApiVersion '2022-05-01' -Method PUT -Payload $payload

#Set Defender for Cloud Apps Integration
$payload = (@{
    kind = 'DataExportSettings'
    properties = @{
        enabled = $DefenderforCloudApps
    }
}) | ConvertTo-Json

Invoke-AzRestMethod -SubscriptionId $subscription.Id -ResourceProviderName 'Microsoft.Security' -ResourceType 'settings' -Name 'MCAS' -ApiVersion '2022-05-01' -Method PUT -Payload $payload

#Set Defender For Servers Plan
$payload = (@{
    properties = @{
        pricingTier = 'Standard'
        subPlan = $DefenderforServersPlan
    }
}) | ConvertTo-Json

Invoke-AzRestMethod -SubscriptionId $subscription.Id -ResourceProviderName 'Microsoft.Security' -ResourceType 'pricings' -Name 'VirtualMachines' -ApiVersion '2022-03-01' -Method PUT -Payload $payload

#Get Current Settings
$settings = ((Invoke-AzRestMethod -SubscriptionId $subscription.Id -ResourceProviderName 'Microsoft.Security' -ResourceType 'settings' -ApiVersion '2022-05-01' -Method Get).Content | ConvertFrom-Json).Value
$defenderForServersPlan = (Invoke-AzRestMethod -SubscriptionId $subscription.Id -ResourceProviderName 'Microsoft.Security' -ResourceType 'pricings' -Name 'VirtualMachines' -ApiVersion '2022-03-01' -Method Get).Content | ConvertFrom-Json