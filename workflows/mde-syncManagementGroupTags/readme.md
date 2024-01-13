
# Assign Permissions to the Logic App System Managed Identity
``` PowerShell
# Connect to AzureAD
Connect-AzureAD

# Update with your logic app Object (principal) ID
$msiObjectId = '<ObjectId>' 

# Assigns Required Permissions to updated device tags (Machine.ReadWrite.All)
$defenderATPApp = Get-AzureADServicePrincipal -Filter "appId eq 'fc780465-2017-40d4-a0c5-307022471b92'"
$deviceTagRoleId = ((Get-AzureADServicePrincipal -Filter "appId eq 'fc780465-2017-40d4-a0c5-307022471b92'").appRoles | where Value -eq 'Machine.ReadWrite.All').Id
New-AzureAdServiceAppRoleAssignment -ObjectId $msiObjectId -PrincipalId $msiObjectId -ResourceId $defenderATPApp.ObjectId -Id $deviceTagRoleId
```
