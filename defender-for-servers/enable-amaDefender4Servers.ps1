<#
  .DESCRIPTION
  This script will enable auto provisioning of the Azure Monitor Agent for Defender for Servers

  .PARAMETER subscriptionId
  The id of the subscription to enable Defender for Servers AMA Agent
	
  .PARAMETER workspaceResourceId
  The full workspace resource ID for using a custom workspace. This paramater is optional, if not specified the default workspace will be used. 

  .EXAMPLE
  Enable Auto-provisioning configuration for AMA with the default workspace
  .\enable-amaDefender4Servers.ps1 -subscriptionId 'ada06e68-4678-4210-443a-c6cacebf41c5'
	
  .EXAMPLE
  Enable Auto-provisioning configuration for AMA with a custom workspace
  .\enable-amaDefender4Servers.ps1 -subscriptionId 'ada06e68-4678-4210-443a-c6cacebf41c5' -workspaceResourceId '/subscriptions/11c61180-d5dc-4a02-b2da-1f06b8245691/resourcegroups/sentinel-prd/providers/microsoft.operationalinsights/workspaces/sentinel-prd'
#>

param(
    [Parameter(ValueFromPipeline = $true, Mandatory=$true)]
    [string]$subscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$workspaceResourceId
)

# Check for required modules
$requiredModules = 'Az.Accounts', 'Az.Resources', 'Az.Security'
$availableModules = Get-Module -ListAvailable -Name $requiredModules
$modulesToInstall = $requiredModules | where-object {$_ -notin $availableModules.Name}
ForEach ($module in $modulesToInstall){
    Write-Host "Installing Missing PowerShell Module: $module" -ForegroundColor Yellow
    Install-Module $module -force
}

If(!(Get-AzContext)){
    Write-Host 'Connecting to Azure Subscription' -ForegroundColor Yellow
    Connect-AzAccount -Subscription $subscriptionId -WarningAction SilentlyContinue | Out-Null
}

#Set Current Subscription
$currentSub = Set-AzContext -Subscription $subscriptionId

#Policy Description
$description = 'This policy assignment was automatically created by Azure Security Center for agent installation as configured in Security Center auto provisioning.'

If ($workspaceResourceId){
    $definition = Get-AzPolicySetDefinition -Id '/providers/Microsoft.Authorization/policySetDefinitions/500ab3a2-f1bd-4a5a-8e47-3e09d9a294c3'
    $displayName = 'Custom Defender for Cloud provisioning Azure Monitor agent'
    $paramSet = @{
        Name = $(New-Guid)
        DisplayName = $displayName
        Description = $description
        PolicySetDefinition = $definition
        IdentityType = 'SystemAssigned' 
        Location = 'centralus'
        Scope = "/subscriptions/$($currentSub.Subscription.Id)"
        PolicyParameterObject = @{
            userWorkspaceResourceId = $workspaceResourceId
            workspaceRegion = (Get-AzResource -ResourceId $workspaceResourceId).Location
        }
    }
}Else{
    $definition = Get-AzPolicySetDefinition -Id '/providers/Microsoft.Authorization/policySetDefinitions/362ab02d-c362-417e-a525-45805d58e21d'
    $displayName = 'Default Defender for Cloud provisioning Azure Monitor agent'
    $paramSet = @{
        Name = $(New-Guid)
        DisplayName = $displayName
        Description = $description
        PolicySetDefinition = $definition
        IdentityType = 'SystemAssigned' 
        Location = 'centralus'
        Scope = "/subscriptions/$($currentSub.Subscription.Id)"
    }
}

#Disbale Existing Auto Provisioning Settings
Set-AzSecurityAutoProvisioningSetting -Name "default"

#Create the Policy Assignment
$assignment = New-AzPolicyAssignment @paramSet

#Create a Remmediation Task
Start-AzPolicyRemediation -Name $assignment.Properties.DisplayName -PolicyAssignmentId $assignment.PolicyAssignmentId
