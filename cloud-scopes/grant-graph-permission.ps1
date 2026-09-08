[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$LogicAppPrincipalId,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$TenantId
)

$requiredModules = @(
    'Microsoft.Graph.Authentication',
    'Microsoft.Graph.Applications'
)

foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        throw "Required module '$module' is not installed. Run: Install-Module $module -Scope CurrentUser"
    }
}

$connectParameters = @{
    Scopes = @(
        'Application.Read.All',
        'AppRoleAssignment.ReadWrite.All'
    )
}

if ($TenantId) {
    $connectParameters.TenantId = $TenantId
}

Connect-MgGraph @connectParameters -NoWelcome

$graphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'" -Property Id, AppRoles
$zoneRole = $graphServicePrincipal.AppRoles | Where-Object {
    $_.Value -eq 'Zone.ReadWrite.All' -and $_.AllowedMemberTypes -contains 'Application'
}

if (-not $zoneRole) {
    throw "The Microsoft Graph application role 'Zone.ReadWrite.All' was not found in this tenant."
}

$existingAssignment = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $LogicAppPrincipalId -All |
    Where-Object {
        $_.ResourceId -eq $graphServicePrincipal.Id -and $_.AppRoleId -eq $zoneRole.Id
    }

if ($existingAssignment) {
    Write-Output "Zone.ReadWrite.All is already assigned to managed identity $LogicAppPrincipalId."
    return
}

$assignment = New-MgServicePrincipalAppRoleAssignment `
    -ServicePrincipalId $LogicAppPrincipalId `
    -PrincipalId $LogicAppPrincipalId `
    -ResourceId $graphServicePrincipal.Id `
    -AppRoleId $zoneRole.Id

Write-Output "Assigned Zone.ReadWrite.All to managed identity $LogicAppPrincipalId (assignment $($assignment.Id))."