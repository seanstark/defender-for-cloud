
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
