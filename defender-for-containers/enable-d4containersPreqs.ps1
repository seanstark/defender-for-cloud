<#
  .DESCRIPTION
  This script will enable the pre-requistes for Defender for Containers at the management group level. This includes the DefenderForContainersSecurityOperator identity, 
  role assignment, and TrustedAccessPreview for Agentless Kubernetes Discovery

  .PARAMETER managementGroupName
  The Management Group Name to enable Defender for Servers AMA on. Note, the Tenant Root Group management group name is acutally a GUID and not "Tenant Root Group"

 .EXAMPLE
  Enable Defender for Containers Prereqs
  .\enable-d4containersPreqs.ps1 -managementGroupName 'Finance'
#>

param(
    [Parameter(Mandatory = $true, ParameterSetName = 'mg')]
    [string]$managementGroupName
)

If(!(Get-AzContext)){
    Write-Host 'Connecting to Azure Subscription' -ForegroundColor Yellow
    Connect-AzAccount -WarningAction SilentlyContinue | Out-Null
}

# Get all child managment groups and subscriptions
$mg = Get-AzManagementGroup -GroupName $managementGroupName -Recurse -Expand -WarningAction SilentlyContinue
$mgSubs = Get-AzManagementGroupSubscription -GroupName $managementGroupName -WarningAction SilentlyContinue
ForEach ($childMG in ($mg.Children | where Type -eq 'Microsoft.Management/managementGroups')){
    $mgSubs += Get-AzManagementGroupSubscription -GroupName $childMG.Name -WarningAction SilentlyContinue
}

ForEach ($mgSub in $mgSubs){
    $subscription = Set-AzContext -Subscription $mgSub.DisplayName
    Write-Host '*******'
    Write-Verbose ('Processing Subscription {0}' -f $mgSub.DisplayName) -Verbose
    # Check for existing DefenderForContainersSecurityOperator securityOperators Identity Object
    $apiVersion = '2023-01-01-preview'
    $uri = ('https://management.azure.com/subscriptions/{0}/providers/Microsoft.Security/pricings/Containers/securityOperators/{1}?api-version={2}' -f $subscription.Subscription, 'DefenderForContainersSecurityOperator', $apiVersion)
    Write-Verbose 'Checking for the existing DefenderForContainersSecurityOperator Identity Object' -Verbose
    $securityOperator = Invoke-AzRestMethod -Uri $uri -Method GET

    # If no securityOperator is found, create one
    If ($securityOperator.StatusCode -eq '404'){
        Write-Verbose 'Creating a new DefenderForContainersSecurityOperator Identity Object' -Verbose
        $body = @{
            "name" = 'DefenderForContainersSecurityOperator'
            "identity" = @{
                "type" = "SystemAssigned"
              }
        }
        $securityOperator = Invoke-AzRestMethod -Uri $uri -Payload $($body | ConvertTo-Json) -Method PUT
    }

    # Assign the Kubernetes Agentless Operator role to the identity
    If (!(Get-AzRoleAssignment -ObjectId ($securityOperator.Content | ConvertFrom-Json).identity.principalId -RoleDefinitionName 'Kubernetes Agentless Operator')){
        Write-Verbose 'Assigning the Kubernetes Agentless Operator role to the DefenderForContainersSecurityOperator system managed identity' -Verbose
        $role = New-AzRoleAssignment -ObjectId ($securityOperator.Content | ConvertFrom-Json).identity.principalId -RoleDefinitionName 'Kubernetes Agentless Operator'  
    }

    # Enable the TrustedAccessPreview for Agentless Kubernetes Discovery
    Write-Verbose 'Enabling the TrustedAccessPreview for Agentless Kubernetes Discovery on the subscription' -Verbose
    $rp = Register-AzProviderPreviewFeature -ProviderNamespace 'Microsoft.ContainerService' -Name 'TrustedAccessPreview'

    If($Error){
        Write-Verbose 'Error(s) Found during Deployment' -Verbose
        $Error
    }
    $Error.Clear()
}