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

$requiredScopes = @(
    'Application.Read.All',
    'AppRoleAssignment.ReadWrite.All'
)
$graphContext = Get-MgContext
$hasRequiredScopes = $graphContext -and -not ($requiredScopes | Where-Object {
    $_ -notin $graphContext.Scopes
})
$isRequestedTenant = -not $TenantId -or ($graphContext -and $graphContext.TenantId -eq $TenantId)

if (-not ($graphContext -and $hasRequiredScopes -and $isRequestedTenant)) {
    $connectParameters = @{
        Scopes        = $requiredScopes
        UseDeviceCode = $true
        NoWelcome     = $true
    }

    if ($TenantId) {
        $connectParameters.TenantId = $TenantId
    }

    Connect-MgGraph @connectParameters
    $graphContext = Get-MgContext
}
else {
    Write-Verbose "Using the existing Microsoft Graph session for tenant $($graphContext.TenantId)."
}

$graphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'" -Property Id, AppRoles
$zoneRole = $graphServicePrincipal.AppRoles | Where-Object {
    $_.Value -eq 'Zone.ReadWrite.All' -and $_.AllowedMemberTypes -contains 'Application'
}

if (-not $zoneRole) {
    throw @"
Microsoft Graph does not currently publish the 'Zone.ReadWrite.All' application role in tenant
$($graphContext.TenantId). Without a published app-role ID, the permission cannot be assigned to the
Logic App managed identity.

The beta zones API documentation names this permission, but the Microsoft Graph permissions catalog
does not yet define it and the Defender cloud-scopes documentation currently describes scope CRUD as
portal-only with API support coming soon. This indicates that application access has not been rolled
out to this tenant. Create and manage cloud scopes in the Microsoft Defender portal until Microsoft
publishes the role, then rerun this script.

Zones API: https://learn.microsoft.com/graph/api/security-security-post-zones?view=graph-rest-beta
Cloud scopes: https://learn.microsoft.com/azure/defender-for-cloud/cloud-scopes-unified-rbac
"@
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