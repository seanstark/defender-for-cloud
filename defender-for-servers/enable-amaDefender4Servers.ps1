<#
    .DESCRIPTION
        This script will resolve storage account primary and secondary endpoints to ipv4 addresses.
        The script will inventory storage accounts across all subscriptions by default
		
    .PARAMETER subscriptionId
        The id of the subscription to enable Defender for Servers AMA Agent
		
	.PARAMETER workspaceResourceId
		The full workspace resource ID for using a custom workspace. This paramater is optional, if not specific the default workspace will be used. 
	
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
