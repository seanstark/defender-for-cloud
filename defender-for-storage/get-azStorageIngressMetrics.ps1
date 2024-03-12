<#
    .DESCRIPTION
        The script will get estimated ingress metrics on Azure Files and Azure Blob files for supported V2 Storage Accounts with file containers across 
        all subscriptions in a tenant based on the ingress metric, which is in bytes. 
        - The ingress metric used in this script is based on the last 30 days at a 5 minute interval
        - Overall this estimate is a ballpark and not to be expected as 100% accurate measure of file size on upload
        - The script will output the totals and export the data to a csv file

    .PARAMETER subscriptionId
        An optional string array of Subscritpion IDs to scope the script to.

    .PARAMETER managementGroupName
        An optional name of a managment group to scope the script to.

    .EXAMPLE
        Get File and Blob Ingress Estimates for all storage accounts in the Tenant
        .\get-azStorageIngressMetrics.ps1 -all
    
    .EXAMPLE
        Get File and Blob Ingress Estimates for all storage accounts in Subscriptions you specify
        .\get-azStorageIngressMetrics.ps1 -subscriptionId '98aa6bab-0ef8-48e2-8397-a0101e0712e3', 'ada06e68-375e-4210-be3a-c6cacebf41c5'
    
    .EXAMPLE
        Get File and Blob Ingress Estimates for all storage accounts in a management group you specify
        .\get-azStorageIngressMetrics.ps1 -managementGroupName "Finance"
#>
param(
    [CmdletBinding(DefaultParameterSetName="all")]
    [Parameter(Mandatory=$false, ParameterSetName = 'all')]
    [switch]$all,

    [Parameter(Mandatory=$false, ParameterSetName = 'subscope')]
    [string[]]$subscriptionId, 

    [Parameter(Mandatory=$false, ParameterSetName = 'mgscope')]
    [string]$managementGroupName
)

$requiredModules = 'Az.Accounts', 'Az.Storage', 'Az.Monitor'
$availableModules = Get-Module -ListAvailable -Name $requiredModules
$modulesToInstall = $requiredModules | where-object {$_ -notin $availableModules.Name}
ForEach ($module in $modulesToInstall){
    Write-Host "Installing Missing PowerShell Module: $module" -ForegroundColor Yellow
    Install-Module $module -force
}

#Load Latest Version 
ForEach ($module in $requiredModules){
    Remove-Module $module -Force -Confirm:$false -ErrorAction SilentlyContinue
    (Get-Module -Name $module -ListAvailable | Sort-Object -Property Version)[-1] | Import-Module
}

# Connect to Azure if not already connected
If(!(Get-AzContext)){
    Write-Host 'Connecting to Azure' -ForegroundColor Yellow
    Connect-AzAccount -WarningAction SilentlyContinue | Out-Null
}

# Get subscriptions based on parameters or default to all in the Tenant
If ($subscriptionId){
    $subscriptions += $subscriptionId | % {Get-AzSubscription -SubscriptionId $_ -WarningAction SilentlyContinue}
}elseif ($managementGroupName) {
    $mg = Get-AzManagementGroup -GroupName $managementGroupName -Recurse -Expand -WarningAction SilentlyContinue
    $mgSubs = Get-AzManagementGroupSubscription -GroupName $managementGroupName -WarningAction SilentlyContinue
    ForEach ($childMG in ($mg.Children | where Type -eq 'Microsoft.Management/managementGroups')){
        $mgSubs += Get-AzManagementGroupSubscription -GroupName $childMG.Name -WarningAction SilentlyContinue
    }
    ForEach ($mgSub in $mgSubs){
        $mgSub | Add-Member -MemberType NoteProperty -Name 'Name' -Value $mgSub.DisplayName -Force -ErrorAction SilentlyContinue
        $mgSub | Add-Member -MemberType NoteProperty -Name 'Id' -Value $mgSub.Id.split('/')[-1] -Force -ErrorAction SilentlyContinue
        $mgSub | Add-Member -MemberType NoteProperty -Name 'TenantId' -Value $mgSub.Tenant -Force -ErrorAction SilentlyContinue
    }
    $subscriptions = $mgSubs
}else {
    $subscriptions = Get-AzSubscription -WarningAction SilentlyContinue
}

$report = @()
ForEach ($subscription in ($subscriptions | Select -first 3)){
    Set-AzContext -Subscription $subscription.Id | Out-Null
    Write-Host ('Getting All Storage Accounts in the {0} Subscription' -f $subscription.Name) -ForegroundColor Yellow

    $storageAccounts = Get-AzStorageAccount | Where Kind -like 'StorageV2' 
    Write-Host ('Found a Total of {0} storage accounts, getting ingress data volume in MB...' -f $storageAccounts.Count) -ForegroundColor Yellow

    ForEach ($storageAccount in $storageAccounts){
        $totalFileIngress30dayBytes = $null
        $totalFileIngress30dayMB = $null
        $totalFileIngress30dayGB = $null
        $fileIngress = $null
        $totalFileIngress = 0
        $totalBlobIngress30dayBytes = $null
        $totalBlobIngress30dayMB = $null
        $totalBlobIngress30dayGB = $null
        $blobIngress = $null
        $totalBlobIngress = 0

        # Get blob and file ingress in bytes over the past 30 days per 5 minutes
        $fileIngress = Get-AzMetric -ResourceId $($storageAccount.id + "/fileservices/default") -MetricName Ingress -AggregationType Total -StartTime $((Get-Date).AddMonths(-1)) -EndTime $(Get-Date) -TimeGrain 00:05:00 -WarningAction SilentlyContinue
        $blobIngress = Get-AzMetric -ResourceId $($storageAccount.id + "/blobservices/default") -MetricName Ingress -AggregationType Total -StartTime $((Get-Date).AddMonths(-1)) -EndTime $(Get-Date) -TimeGrain 00:05:00 -WarningAction SilentlyContinue


        # Get Total ingress bytes over the past 30 days
        $fileIngress.Data.Total | % {$totalFileIngress += $_}
        $blobIngress.Data.Total | % {$totalBlobIngress += $_}
        $totalFileIngress30dayBytes = $totalFileIngress
        $totalFileIngress30dayMB = [math]::round([decimal]$totalFileIngress/1000/1000,6)
        $totalFileIngress30dayGB = [math]::round([decimal]$totalFileIngress/1000/1000/1000,6)
        $totalBlobIngress30dayBytes = $totalBlobIngress
        $totalBlobIngress30dayMB = [math]::round([decimal]$totalBlobIngress/1000/1000,6)
        $totalBlobIngress30dayGB = [math]::round([decimal]$totalBlobIngress/1000/1000/1000,6)

        Write-Host ('    {0} totalFileIngress30dayBytes: {1}, totalFileIngress30dayMB:{2} totalFileIngress30dayGB: {3}' -f $storageAccount.StorageAccountName,  $totalFileIngress30dayBytes, $totalFileIngress30dayMB, $totalFileIngress30dayGB) -ForegroundColor Yellow
        Write-Host ('    {0} totalBlobIngress30dayBytes: {1}, totalBlobIngress30dayMB:{2} totalBlobIngress30dayGB: {3},' -f $storageAccount.StorageAccountName,  $totalBlobIngress30dayBytes, $totalBlobIngress30dayMB, $totalBlobIngress30dayGB) -ForegroundColor Yellow

        $storageAccount | Add-Member -MemberType NoteProperty -Name 'Subscription' -Value $subscription.Name -Force -ErrorAction SilentlyContinue
        $storageAccount | Add-Member -MemberType NoteProperty -Name 'SubscriptionId' -Value $subscription.Id -Force -ErrorAction SilentlyContinue
        $storageAccount | Add-Member -MemberType NoteProperty -Name 'SubscriptionTenantId' -Value $subscription.TenantId -Force -ErrorAction SilentlyContinue
        $storageAccount | Add-Member -MemberType NoteProperty -Name 'totalFileIngress30dayBytes' -Value $totalFileIngress30dayBytes -Force -ErrorAction SilentlyContinue
        $storageAccount | Add-Member -MemberType NoteProperty -Name 'totalFileIngress30dayMB' -Value $totalFileIngress30dayMB -Force -ErrorAction SilentlyContinue
        $storageAccount | Add-Member -MemberType NoteProperty -Name 'totalFileIngress30dayGB' -Value $totalFileIngress30dayGB -Force -ErrorAction SilentlyContinue
        $storageAccount | Add-Member -MemberType NoteProperty -Name 'totalBlobIngress30dayBytes' -Value $totalBlobIngress30dayBytes -Force -ErrorAction SilentlyContinue
        $storageAccount | Add-Member -MemberType NoteProperty -Name 'totalBlobIngress30dayMB' -Value $totalBlobIngress30dayMB -Force -ErrorAction SilentlyContinue
        $storageAccount | Add-Member -MemberType NoteProperty -Name 'totalBlobIngress30dayGB' -Value $totalBlobIngress30dayGB -Force -ErrorAction SilentlyContinue
    }

    $report += $storageAccounts | Select StorageAccountName, SubscriptionTenantId, Subscription, SubscriptionId, ResourceGroupName, totalFileIngress30dayBytes, totalFileIngress30dayMB, totalFileIngress30dayGB,
    totalBlobIngress30dayBytes, totalBlobIngress30dayMB, totalBlobIngress30dayGB
}

# All Storage Account Totals
$totals = @{
    numberOfSubscriptions = ($report.Subscription | Get-Unique | Measure-Object).Count
    numberOfStorageAccounts = ($report.StorageAccountName | Measure-Object).Count
    allAccountsTotalFileIngress30dayBytes = ($report.totalFileIngress30dayBytes | Measure-Object -Sum).Sum
    allAccountsTotalFileIngress30dayMB = ($report.totalFileIngress30dayMB | Measure-Object -Sum).Sum
    allAccountsTotalFileIngress30dayGB = ($report.totalFileIngress30dayGB | Measure-Object -Sum).Sum
    allAccountsTotalBlobIngress30dayBytes = ($report.totalBlobIngress30dayBytes | Measure-Object -Sum).Sum
    allAccountsTotalBlobIngress30dayMB = ($report.totalBlobIngress30dayMB | Measure-Object -Sum).Sum
    allAccountsTotalBlobIngress30dayGB = ($report.totalBlobIngress30dayGB | Measure-Object -Sum).Sum
}

#Adding Some formatting to make the CSV look pretty
$report +=  [PSCustomObject]@{
    StorageAccountName = ''
    SubscriptionTenantId = ''
}
$report +=  [PSCustomObject]@{
    StorageAccountName = 'Total Category'
    SubscriptionTenantId = 'Total Value'
}
$totalsObj = $totals.GetEnumerator() | Sort Name -Descending | % {
    [PSCustomObject]@{
        StorageAccountName = $_.key
        SubscriptionTenantId = $_.Value
    }
}
$report += $totalsObj

Write-Host ('Found a Total of {0} storage accounts in {1} Subscriptions. The values below represent the estimated totals for all storage accounts' -f $totals.numberOfStorageAccounts, $totals.numberOfSubscriptions) -ForegroundColor Green
Write-Host ('Total File Ingress Over 30 Days (Bytes): {0}' -f $totals.allAccountsTotalFileIngress30dayBytes) -ForegroundColor Green
Write-Host ('Total File Ingress Over 30 Days (MB): {0}' -f $totals.allAccountsTotalFileIngress30dayMB) -ForegroundColor Green
Write-Host ('Total File Ingress Over 30 Days (GB): {0}' -f $totals.allAccountsTotalFileIngress30dayGB) -ForegroundColor Green
Write-Host ('Total Blob Ingress Over 30 Days (Bytes): {0}' -f $totals.allAccountsTotalBlobIngress30dayBytes) -ForegroundColor Green
Write-Host ('Total Blob Ingress Over 30 Days (MB): {0}' -f $totals.allAccountsTotalBlobIngress30dayMB) -ForegroundColor Green
Write-Host ('Total Blob Ingress Over 30 Days (GB): {0}' -f $totals.allAccountsTotalBlobIngress30dayGB) -ForegroundColor Green

$report | Export-CSV -Path .\storageFileBlobIngressEstimates.csv -Force

Write-Host ('CSV file created with estimates: {0}\{1}' -f $(pwd).path, 'storageFileBlobIngressEstimates.csv') -ForegroundColor Yellow