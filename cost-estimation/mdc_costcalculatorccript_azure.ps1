#Requires -Version 7.0
# Ensure strict mode is enabled for catching common issues
Set-StrictMode -Version Latest

# Ensure you're logged in
$accountInfo = $null
try {
    $accountInfo = Get-AzContext
    if (-not $accountInfo) {
        $accountInfo = Connect-AzAccount
        if (-not $accountInfo) {
            throw "Failed to log in to Azure."
        }
    }
} catch {
    Write-Error "Failed to log in to Azure. Please ensure you have the Az PowerShell module installed and internet access. Error: $_"
    exit
}

# Retrieve all subscriptions the user has access to
try {
    $subscriptions = Get-AzSubscription -TenantId $accountInfo.Tenant.Id | where State -eq "Enabled"
    if (-not $subscriptions) {
         throw "No subscriptions found."
    }
} catch {
    Write-Error "Failed to retrieve subscriptions. Error: $_"
    exit
}

$environmentType = "Azure"

# Initialize a list to hold results for all subscriptions
$allSubscriptionsResults = @()

# Run the Azure Resource Graph query for all subscriptions at once
$query = "
resourcecontainers
| where type == 'microsoft.resources/subscriptions'
| where properties.state == 'Enabled'
| project subscriptionId, subscriptionName = name
| join (
    resources
    | extend type = tolower(type)
    | where type in ('microsoft.sql/managedinstances', 'microsoft.compute/virtualmachines', 'microsoft.classiccompute/virtualmachines', 'microsoft.hybridcompute/machines', 'microsoft.compute/virtualmachinescalesets', 'microsoft.sql/servers', 'microsoft.storage/storageaccounts', 'microsoft.documentdb/databaseaccounts', 'microsoft.containerregistry/registries', 'microsoft.keyvault/vaults', 'microsoft.web/serverfarms', 'microsoft.dbforpostgresql/servers', 'microsoft.dbforpostgresql/flexibleservers', 'microsoft.dbformysql/servers', 'microsoft.dbformysql/flexibleservers', 'microsoft.dbformariadb/servers', 'microsoft.apimanagement/service', 'microsoft.sqlvirtualmachine/sqlvirtualmachines', 'microsoft.azurearcdata/sqlserverinstances', 'microsoft.cognitiveservices/accounts', 'microsoft.web/sites')
    | extend bundleCount = 0, bundleName = pack_array('')
    | extend bundleCount = 0, bundleName = pack_array('arm')
    // Defender for Servers, virtual machines, exclude deallocated
    | extend bundleCount = iff(type in ('microsoft.compute/virtualmachines', 'microsoft.classiccompute/virtualmachines') and tostring(properties.extended.instanceView.powerState.displayStatus) !contains 'deallocated', 1, bundleCount), 
        bundleName  = iff(type in ('microsoft.compute/virtualmachines', 'microsoft.classiccompute/virtualmachines') and tostring(properties.extended.instanceView.powerState.displayStatus) !contains 'deallocated', pack_array('virtualmachines', 'cloudposture'), bundleName)
    // Defender for CSPM, virtual machines, exclude deallocated & Databricks
    | extend bundleCount = iff(type in ('microsoft.compute/virtualmachines', 'microsoft.classiccompute/virtualmachines') and tostring(properties.extended.instanceView.powerState.displayStatus) !contains 'deallocated' and 
        tostring(properties.storageProfile.imageReference.offer) !contains 'Databricks', 1, bundleCount), 
        bundleName  = iff(type in ('microsoft.compute/virtualmachines', 'microsoft.classiccompute/virtualmachines') and tostring(properties.extended.instanceView.powerState.displayStatus) !contains 'deallocated' and 
        tostring(properties.storageProfile.imageReference.offer) !contains 'Databricks', pack_array('virtualmachines', 'cloudposture'), bundleName)
    // Defender for Servers, Arc Connected Machines, exclude Expired & Disconnected machines
    | extend bundleCount = iff(type == 'microsoft.hybridcompute/machines' and properties.status !in ('Expired', 'Disconnected'), 1, bundleCount), bundleName  = iff(type == 'microsoft.hybridcompute/machines' and properties.status !in ('Expired', 'Disconnected'), pack_array('virtualmachines'), bundleName)
    // Defender CSPM Virtual Machine Scalesets
    | extend bundleCount = iff(type == 'microsoft.compute/virtualmachinescalesets' and sku != '' and sku.capacity != '', toint(sku.capacity), bundleCount), bundleName = iff(type =~ 'microsoft.compute/virtualmachinescalesets' and sku != '' and sku.capacity != '', pack_array('cloudposture'), bundleName)
    // Defender Servers Virtual Machine Scalesets, exclude AKS Nodes
    | extend bundleCount = iff(type == 'microsoft.compute/virtualmachinescalesets' and sku != '' and sku.capacity != '' and tostring(properties.virtualMachineProfile.extensionProfile) !contains 'Compute.AKS', toint(sku.capacity), bundleCount), bundleName = iff(type =~ 'microsoft.compute/virtualmachinescalesets' and sku != '' and sku.capacity != '' and tostring(properties.virtualMachineProfile.extensionProfile) !contains 'Compute.AKS', pack_array('virtualmachines'), bundleName)  
    // Defender for Storage
    | extend bundleCount = iff(type == 'microsoft.storage/storageaccounts', 1, bundleCount), bundleName = iff(type == 'microsoft.storage/storageaccounts', pack_array('storageaccounts', 'cloudposture'), bundleName)
    // Defender for Key Vault
    | extend bundleCount = iff(type == 'microsoft.keyvault/vaults', 1, bundleCount), bundleName = iff(type == 'microsoft.keyvault/vaults', pack_array('keyvaults'), bundleName)
    // Defender for App Services
    | extend bundleCount = iff(type == 'microsoft.web/serverfarms' and isnotempty(sku) and tolower(sku.tier) != 'consumption', toint(properties.numberOfWorkers), bundleCount), bundleName = iff(type == 'microsoft.web/serverfarms' and isnotempty(sku) and tolower(sku.tier) != 'consumption', pack_array('appservices'), bundleName)
    // Defender CSPM, Defender for OpenSource DBs
    | extend bundleCount = iff((type == 'microsoft.dbforpostgresql/servers' or type == 'microsoft.dbforpostgresql/flexibleservers' or type == 'microsoft.dbformysql/servers' or type == 'microsoft.dbformysql/flexibleservers' or type == 'microsoft.dbformariadb/servers') and sku.tier !contains ('basic'), 1, bundleCount), bundleName = iff((type =~ 'microsoft.dbforpostgresql/servers' or type =~ 'microsoft.dbforpostgresql/flexibleservers' or type =~ 'microsoft.dbformysql/servers' or type =~ 'microsoft.dbformysql/flexibleservers' or type =~ 'microsoft.dbformariadb/servers') and sku.tier !contains ('basic'), pack_array('opensourcerelationaldatabases', 'cloudposture'), bundleName)
    // Defender for Cosmos DB, does not count RSUs
    | extend bundleCount = iff(type == 'microsoft.documentdb/databaseaccounts', 1, bundleCount), bundleName = iff(type == 'microsoft.documentdb/databaseaccounts', pack_array('cosmosdbs'), bundleName)
    // Defender for API Management, does not count API calls
    | extend bundleCount = iff(type == 'microsoft.apimanagement/service', 1, bundleCount), bundleName = iff(type == 'microsoft.apimanagement/service', pack_array('api'), bundleName)
    // Defender for SQL
    | extend bundleCount = iff(type in ('microsoft.sql/servers', 'microsoft.sql/managedinstances'), 1, bundleCount), bundleName = iff(type in ('microsoft.sql/servers', 'microsoft.sql/managedinstances'), pack_array('sqlservers', 'cloudposture'), bundleName)
    // Defender for SQL on Machines
    | extend bundleCount = iff(type == 'microsoft.sqlvirtualmachine/sqlvirtualmachines' or type == 'microsoft.azurearcdata/sqlserverinstances', 1, bundleCount), bundleName = iff(type == 'microsoft.sqlvirtualmachine/sqlvirtualmachines' or type == 'microsoft.azurearcdata/sqlserverinstances', pack_array('sqlservervirtualmachines'), bundleName)
    // Defender for AI, does not count AI Tokens
    | extend bundleCount = iff(type == 'microsoft.cognitiveservices/accounts' and kind in ('OpenAI', 'AIServices'), 1, bundleCount), bundleName = iff(type == 'microsoft.cognitiveservices/accounts' and kind in ('OpenAI', 'AIServices'), pack_array('ai'), bundleName)
    // Defender CSPM, serverless
    | extend bundleCount = iff(type == 'microsoft.web/sites' and (tolower(kind) startswith 'app' or tolower(kind) startswith 'functionapp') and not(tolower(kind) contains 'workflowapp'), 1, bundleCount), bundleName = iff(type == 'microsoft.web/sites' and (tolower(kind) startswith 'app' or tolower(kind) startswith 'functionapp') and not(tolower(kind) contains 'workflowapp'), pack_array('serverless'), bundleName)
    | mv-expand bundleName to typeof(string) limit 2000
    | summarize resourceCount = sum(bundleCount) by subscriptionId, bundleName
    // Update serverless counts to reflect 8:1 billing
    | extend resourceCount = case(
        bundleName == 'serverless' and resourceCount <= 8, 1,
        bundleName == 'serverless' and resourceCount > 8, tolong(ceiling(todouble(resourceCount) / 8.0)),
        bundleName == 'arm', 1,
        resourceCount
        )
    | where bundleName != ''
    // Defender for Containers vcore Counts
    | union (
        resourcecontainers
        | where type == 'microsoft.resources/subscriptions'
        | where properties.state == 'Enabled'
        | project subscriptionId, subscriptionName = name
        | join ( 
            resources
            | where type == 'microsoft.containerservice/managedclusters'
            | where isnotempty(sku) and tolower(sku.tier) != 'consumption'
            | where tostring(properties.powerState.code) =~ 'Running'
            | extend pool = (properties.agentPoolProfiles)
            | mv-expand pool
            | extend cpuCores = toint(extract_all(@'(\d+)', tostring(split(pool.vmSize, '_')[1]))[0]) * pool.['count']
            | project subscriptionId, resourceGroup, cluster = name, size = pool.vmSize, cpuCores, poolcount = pool.['count']
            | summarize coreCount = sum(cpuCores) by subscriptionId
            | union (
                resources
                | where tolower(type) =~ 'microsoft.kubernetes/connectedclusters'
                | where properties.connectivityStatus !in ('Offline', 'Expired')
                | extend cpuCores = toint(properties.totalCoreCount), poolcount = toint(properties.totalNodeCount)
                | project subscriptionId, resourceGroup, cluster = name, poolcount, cpuCores
                | summarize coreCount = sum(cpuCores) by subscriptionId
                )
            | summarize resourceCount = sum(coreCount) by subscriptionId, bundleName = 'containers'
            )
            on subscriptionId
        )
    | project subscriptionId, plan = bundleName, resourceCount
    ) 
    on subscriptionId
| project-away subscriptionId1
"

try {
    $queryResults = @()
    $pageSize = 1000
    $skipToken = $null

    while ($true) {
        if ($skipToken) {
            $pagedResults = Search-AzGraph -Query $query -First $pageSize -SkipToken $skipToken -UseTenantScope
        } else {
            $pagedResults = Search-AzGraph -Query $query -First $pageSize -UseTenantScope
        }

        if (-not $pagedResults) {
            throw "No resources found."
        }

        $queryResults += $pagedResults.Data
        $skipToken = $pagedResults.SkipToken

        if ($pagedResults.Data.Count -lt $pageSize) {
            break
        }
    }

    if (-not $queryResults) {
        throw "No resources found."
    }
} catch {
    Write-Error "Failed to retrieve resources using Azure Resource Graph. Error: $_"
    exit
}

# *** Collect numbers for resource based plans *** 
$hourBasedPlans = @("cloudposture", "serverless", "virtualmachines", "appservices", "sqlservers", "sqlservervirtualmachines", "opensourcerelationaldatabases", "storageaccounts", "keyvaults", "arm")

# Process the query results
foreach ($result in $queryResults) {
    $resourcesCount = $result.resourceCount
    $plan = $result.plan
    $subscriptionId = $result.subscriptionId
    $subscriptionName = ($subscriptions | Where-Object { $_.Id -eq $subscriptionId }).Name

    #Get MDC Plan Status
    $restPlan = $plan
    If ($plan -eq 'serverless'){$restPlan = 'cloudposture'} # Map serverless to cloud posture for accurate plan details retrieval as they are under the same plan in the API
    $planDetails = (Invoke-AzRestMethod -Path "/subscriptions/$subscriptionId/providers/microsoft.security/pricings/$($restPlan )?api-version=2024-01-01").Content | ConvertFrom-Json
    
    If (!($planDetails.properties | get-member -Name SubPlan)) { $planDetails.properties | Add-Member -MemberType NoteProperty -Name SubPlan -Value $null -PassThru | Out-Null }

    $legacyPlan = $false
    $newPlan = 'N/A'
    If ($planDetails.name -eq 'DNS'){
        $legacyPlan = $true
        $newPlan = 'Defender for Servers P2'
    } elseif ($planDetails.name -in ('ContainerRegistry', 'KubernetesService')){
        $legacyPlan = $true
        $newPlan = 'Defender for Containers'
    } elseif ($planDetails.properties.subPlan -in ('PerApiCall','PerTransaction')){
        $legacyPlan = $true
    }

    $planName = switch ($plan) {
        'AI' {'Defender for AI services'}
        'Api' {'Defender for APIs'}
        'AppServices' {'Defender for App Service'}
        'Arm' {'Defender for Resource Manager'}
        'CloudPosture' {'Defender for CSPM'}
        'serverless' {'Defender for CSPM'}
        'ContainerRegistry' {'Defender for Container Registry'}
        'Containers' {'Defender for Containers'}
        'CosmosDbs' {'Defender for Azure Cosmos DB'}
        'Discovery' {'Free - Asset Discovery'}
        'Dns' {'Defender for DNS'}
        'FoundationalCspm' {'Free - Foundational CSPM'}
        'KeyVaults' {'Defender for Key Vault'}
        'KubernetesService' {'Defender for Kubernetes'}
        'OpenSourceRelationalDatabases' {'Defender for Open Source DBs'}
        'SqlServerVirtualMachines' {'Defender for SQL (Non Arc-enabled SQL Servers)'}
        'SqlServers' {'Defender for SQL'}
        'StorageAccounts' {'Defender for Storage'}
        'VirtualMachines' {'Defender for Servers'}
    }

    #Write-Host "Subscription: $subscriptionName, SubscriptionId: $subscriptionId, Plan Name: $plan, Sub Plan: $($planDetails.properties.subPlan), ResourceCount: $resourcesCount"

    # Determine billable units based on the plan name
    $billableUnits = if ($hourBasedPlans -contains $plan.ToLower()) {
        730 # Assuming 730 hours in a month
    } else {
        0
    }    

    # Compile the subscription results
    $subscriptionResult = [PSCustomObject]@{
        SubscriptionID = $subscriptionId
        SubscriptionName = $subscriptionName
        Plan = $plan
        PlanName = $planName
        SubPlan = $planDetails.properties.subPlan
        ResourcesCount = If($plan -eq 'serverless') {$resourcesCount * 8} else {$resourcesCount} # Map serverless resources back to actual count for accurate reporting
        BillableUnits = $billableUnits
        PlanEnabled = If($planDetails.properties.pricingTier -eq "Standard") { $true } else { $false }
        LegacyPlan = $legacyPlan
        newPlan = $newPlan
        EnvironmentType = $environmentType
        RecommendedSubPlan = $null
        ExcludableResources = $null
    }

    # Add this subscription's results to the list
    $allSubscriptionsResults += $subscriptionResult
}

# Prompt the user to confirm if they want to run the additional data collection
$runAdditionalDataCollection = Read-Host "Do you want to run the additional data collection for API, Cosmos DB, and Malware Scanning (storage) plans? Collection of this data can take longer dpending on the size of your environment. (yes/no)"

if ($runAdditionalDataCollection -eq "yes") {

    # *** Collect data for Defender for Containers plan - based on allocation metric over time for more accureate estimate *** 
    foreach ($sub in ($allSubscriptionsResults | where {$_.Plan -eq 'containers' -and $_.ResourcesCount -gt 0} )) {
        Write-Host "Processing Subscription: $($sub.SubscriptionName) - $($sub.SubscriptionID) for containers plan"

        # Initialize variables to hold the total VPU cores and the number of clusters for the current subscription
        $totalVPUCoresForSubscription = 0
        $clustersCount = 0

        # Get all AKS clusters in the subscription
        try {
            $aksClustersUri = "/subscriptions/$($sub.SubscriptionID)/providers/Microsoft.ContainerService/managedClusters?api-version=2026-01-01"
            $arcClustersUri = "/subscriptions/$($sub.SubscriptionID)/providers/microsoft.kubernetes/connectedClusters?api-version=2024-01-01"
            $response = Invoke-AzRestMethod -Method GET -Path $aksClustersUri -ErrorAction Stop
            $arcResponse = Invoke-AzRestMethod -Method GET -Path $arcClustersUri -ErrorAction Stop
            if ($response.StatusCode -eq 200 -or $arcResponse.StatusCode -eq 200) {
                $aksClusters = $response.Content | ConvertFrom-Json | Select-Object -ExpandProperty value
                $arcClusters = $arcResponse.Content | ConvertFrom-Json | Select-Object -ExpandProperty value
            } else {
                Write-Error "Failed to retrieve AKS clusters. Status code: $($response.StatusCode)"
                continue
            }

            if (-not $aksClusters -or -not $arcClusters) {
                Write-Host "No AKS clusters found in Subscription: $($sub.Name)"
                continue
            }
            $clustersCount = ($aksClusters + $arcClusters | Measure-Object).Count
        } catch {
            Write-Error "Failed to retrieve AKS clusters in Subscription: $($sub.SubscriptionName). Error: $_"
            continue # Continue with the next subscription if this fails
        }

        # Define the time range for the last 30 days
        $startTime = (Get-Date).AddDays(-30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $endTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

        # AKS Clusters
        foreach ($aks in $aksClusters) {
            $resourceId = $aks.Id
            Write-Host "AKS Cluster: $($resourceId)"

            try {
                $metrics = Get-AzMetric -ResourceId $resourceId -MetricName "kube_node_status_allocatable_cpu_cores" -StartTime $startTime -EndTime $endTime -AggregationType Average -TimeGrain 01:00:00 -WarningAction SilentlyContinue
                # Exclude metrics that had no data to avoid skewing the average with zeros, as well as metrics that are missing data points for the entire period
                if ($metrics -ne $null -and $metrics.Data -ne $null) {
                    $averageVPUCores = [Math]::Round(($metrics.Data | where Average -gt 0 | Measure-Object Average -Average).Average)
                    Write-Host "Average allocated CPU cores for the past 30 days: $averageVPUCores"
                    $totalVPUCoresForSubscription += $averageVPUCores
                } else {
                    Write-Host "No data available for allocated CPU cores metric for the past 30 days."
                }
            } catch {
                Write-Host "Error retrieving allocated CPU cores metric: $_"
            }
        }

        # Arc Connected Clusters
        foreach ($arc in $arcClusters) {
            $resourceId = $arc.Id
            Write-Host "ARC Cluster: $($resourceId)"

            try {
                $metrics = Get-AzMetric -ResourceId $resourceId -MetricName "capacity_cpu_cores" -StartTime $startTime -EndTime $endTime -AggregationType Average -TimeGrain 01:00:00 
                # Exclude metrics that had no data to avoid skewing the average with zeros, as well as metrics that are missing data points for the entire period
                if ($metrics -ne $null -and $metrics.Data -ne $null) {
                    $averageVPUCores = [Math]::Round(($metrics.Data | where Average -gt 0 | Measure-Object Average -Average).Average)
                    Write-Host "Average allocated CPU cores for the past 30 days: $averageVPUCores"
                    $totalVPUCoresForSubscription += $averageVPUCores
                } else {
                    Write-Host "No data available for allocated CPU cores metric for the past 30 days."
                }
            } catch {
                Write-Host "Error retrieving allocated CPU cores metric: $_"
            }
        }

        Write-Host "Total vCores for the subscription over the past 30 days: $totalVPUCoresForSubscription"

        # Update existing Defender for Containers Plan counts
        IF ($totalVPUCoresForSubscription -gt 1){
            $sub.BillableUnits = $totalVPUCoresForSubscription
            $sub.ResourcesCount = $clustersCount
        }
    }

    # *** Collect numbers for Defender for APIs ***
    foreach ($sub in ($allSubscriptionsResults | where {$_.Plan -eq 'api' -and $_.ResourcesCount -gt 0} )) {
        Write-Host "Processing Subscription: $($sub.SubscriptionName) - $($sub.SubscriptionID) for API plan"

        # Get all APIM services in the subscription
        try {
            $apimServicesUri = "/subscriptions/$($sub.SubscriptionID)/providers/Microsoft.ApiManagement/service?api-version=2024-05-01"
            $response = Invoke-AzRestMethod -Method GET -Path $apimServicesUri -ErrorAction Stop
            $apimServices = $response.Content | ConvertFrom-Json | Select-Object -ExpandProperty value

            if (-not $apimServices) {
                Write-Host "No APIM services found in Subscription: $($sub.SubscriptionName)"
                continue
            }
        } catch {
            Write-Error "Failed to retrieve APIM services in Subscription: $($sub.SubscriptionName). Error: $_"
            continue # Continue with the next subscription if this fails
        }

        # Track the number of APIM services in the result
        $apimServicesCount = ($apimServices | Measure-Object).Count
        Write-Host "Number of APIM services in subscription $($sub.SubscriptionName): $apimServicesCount"

        # Define the time range for the last 30 days
        $startTime = (Get-Date).AddDays(-30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $endTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

        # Initialize a variable to hold the total requests for the current subscription
        $totalRequestsForSubscription = 0

        foreach ($apim in $apimServices) {
            $resourceId = $apim.Id
            Write-Host "APIM Service: $($resourceId)"
            
            Write-Host "Retrieving 'Requests' metric for APIM Service: $($apim.Name)"
            try {
                $metrics = Get-AzMetric -ResourceId $resourceId -MetricName "Requests" -StartTime $startTime -EndTime $endTime -AggregationType Total
                # Exclude metrics that had no data to avoid skewing the average with zeros, as well as metrics that are missing data points for the entire period
                if ($metrics -ne $null -and $metrics.Data -ne $null) {
                    $serviceRequests = ($metrics.Data | where Total -gt 0 | Measure-Object Total -Sum).Sum
                    Write-Host "Total 'Requests' for the past 30 days: $serviceRequests"
                    $totalRequestsForSubscription += $serviceRequests
                } else {
                    Write-Host "No data available for 'Requests' metric for the past 30 days."
                }
            } catch {
                Write-Host "Error retrieving 'Requests' metric: $_"
            }
        }

        Write-Host "Total 'Requests' for the subscription over the past 30 days: $totalRequestsForSubscription"

        # Calculate costs for each plan taking the limit into consideration
        # Assuming plan details remain the same, and calculation logic applies per subscription
        $plans = @(
            @{ Name = "P1"; Fixed = 200; Overage = 0.00020; Limit = 1000000 },
            @{ Name = "P2"; Fixed = 700; Overage = 0.00014; Limit = 5000000 },
            @{ Name = "P3"; Fixed = 5000; Overage = 0.00010; Limit = 50000000 },
            @{ Name = "P4"; Fixed = 7000; Overage = 0.00007; Limit = 100000000 },
            @{ Name = "P5"; Fixed = 50000; Overage = 0.00005; Limit = 1000000000 }
        )
        $results = @()
        foreach ($plan in $plans) {
            if ($totalRequestsForSubscription -lt $plan.Limit) {
                $totalCost = $plan.Fixed
            } else {
                $totalOverage = $totalRequestsForSubscription - $plan.Limit
                $totalCost = $plan.Fixed + ($totalOverage * $plan.Overage)
            }
            $results += [PSCustomObject]@{
                Plan = $plan.Name
                TotalCost = $totalCost
            }
        }
        # Find the plan with the lowest cost
        $recommendedPlan = $results | Sort-Object TotalCost | Select-Object -First 1
        
        $sub.BillableUnits = $totalRequestsForSubscription
        $sub.ResourcesCount = $apimServicesCount
        $sub.RecommendedSubPlan = $recommendedPlan.Plan
    }

    # *** Collect numbers for Cosmos DB plan ***
    foreach ($sub in ($allSubscriptionsResults | where {$_.Plan -eq 'cosmosdbs' -and $_.ResourcesCount -gt 0} )) {
         Write-Host "Processing Subscription: $($sub.SubscriptionName) - $($sub.SubscriptionID) for CosmosDB plan"

        # Initialize variables to hold the total RU/s and the number of Cosmos DB accounts for the current subscription
        $totalRUsForSubscription = 0
        $cosmosDBAccountsCount = 0

        # Get all Cosmos DB accounts in the subscription
        try {
            $cosmosDBAccountsUri = "/subscriptions/$($sub.SubscriptionID)/providers/Microsoft.DocumentDB/databaseAccounts?api-version=2021-04-15"
            $response = Invoke-AzRestMethod -Method GET -Path $cosmosDBAccountsUri -ErrorAction Stop
            $cosmosDBAccounts = $response.Content | ConvertFrom-Json | Select-Object -ExpandProperty value

            if (-not $cosmosDBAccounts) {
                Write-Host "No Cosmos DB accounts found in Subscription: $($sub.SubscriptionName)"
                continue
            }
            $cosmosDBAccountsCount = ($cosmosDBAccounts | Measure-Object).Count
        } catch {
            Write-Error "Failed to retrieve Cosmos DB accounts in Subscription: $($sub.SubscriptionName). Error: $_"
            continue # Continue with the next subscription if this fails
        }

        # Define the time range for the last 30 days
        $startTime = (Get-Date).AddDays(-30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $endTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")    

        foreach ($cosmosDB in $cosmosDBAccounts) {
            $resourceId = $cosmosDB.Id
            Write-Host "Cosmos DB Account: $($resourceId)"

            try {
                $isServerless = $cosmosDB.properties.capabilities | Where-Object { $_.name -eq "EnableServerless" } | ForEach-Object { $true }

                if ($isServerless -eq $true) {
                    # Serverless mode
                    $metrics = Get-AzMetric -ResourceId $resourceId -MetricName "TotalRequestUnits" -StartTime $startTime -EndTime $endTime -AggregationType Total
                    if ($metrics -ne $null -and $metrics.Data -ne $null) {
                        $accountRUs = ($metrics.Data | Measure-Object Total -Sum).Sum
                        Write-Host "Total RUs for the past 30 days (Serverless): $accountRUs"
                        $accountRUs = $accountRUs * 0.00003125
                        Write-Host "RUs for the past 30 days (Serverless): $accountRUs"
                        $totalRUsForSubscription += $accountRUs
                    } else {
                        Write-Host "No data available for 'TotalRequestUnits' metric for the past 30 days."
                    }
                } else {
                    $databasesUri = "$resourceId/sqlDatabases?api-version=2021-04-15"
                    $databasesResponse = Invoke-AzRestMethod -Method GET -Path $databasesUri -ErrorAction Stop
                    $databases = $databasesResponse.Content | ConvertFrom-Json | Select-Object -ExpandProperty value

                    foreach ($database in $databases) {
                        $databaseId = $database.Id
                        try {
                            $throughputUri = "https://management.azure.com/$databaseId/throughputSettings/default?api-version=2023-03-01-preview"
                            $throughputResponse = Invoke-AzRestMethod -Method GET -Path $throughputUri -ErrorAction Stop

                            $throughputSettings = $null
                            if ($throughputResponse.StatusCode -eq 200) {
                                $throughputSettings = $throughputResponse.Content | ConvertFrom-Json
                            }

                            if ($throughputSettings -ne $null -and $throughputSettings.properties -ne $null) {
                                if ($throughputSettings.properties.resource -ne $null -and $throughputSettings.properties.resource.PSObject.Properties.Match("autoscaleSettings").Count -gt 0) {
                                    # Calculate RU consumption using TotalRequestUnits metric for the database
                                    $dimFilter = "$(New-AzMetricFilter -Dimension DatabaseName -Operator eq -Value $database.name)"
                                    $metrics = Get-AzMetric -ResourceId $resourceId -MetricName "TotalRequestUnits" -StartTime $startTime -EndTime $endTime -AggregationType Maximum -MetricFilter $dimFilter -TimeGrain 01:00:00
                                    if ($metrics -ne $null -and $metrics.Data -ne $null) {
                                        $accountRUs = ($metrics.Data | Measure-Object Maximum -Sum).Sum
                                        Write-Host "RUs for the past 30 days (Database): $accountRUs"
                                        $totalRUsForSubscription += $accountRUs
                                    } else {
                                        Write-Host "No data available for 'TotalRequestUnits' metric for the past 30 days."
                                    }
                                } elseif ($throughputSettings.properties.resource -ne $null -and $throughputSettings.properties.resource.throughput -ne $null) {
                                    # Database is in manual mode
                                    $throughput = $throughputSettings.properties.resource.throughput
                                    Write-Host "Provisioned throughput for database $($databaseId): $throughput"
                                    $totalRUsForSubscription += $throughput * 730
                                }
                            } elseif ($throughputResponse.StatusCode -eq 404) {
                                # Iterate over containers if database throughputSettings are not defined
                                $containersUri = "$databaseId/containers?api-version=2021-04-15"
                                $containersResponse = Invoke-AzRestMethod -Method GET -Path $containersUri -ErrorAction Stop
                                $containers = $containersResponse.Content | ConvertFrom-Json | Select-Object -ExpandProperty value

                                foreach ($container in $containers) {
                                    $containerId = $container.Id
                                    try {
                                        $resourceUri = "$containerId/throughputSettings/default"
                                        $response = Invoke-AzRestMethod -Method GET -Uri "https://management.azure.com$($resourceUri)?api-version=2023-03-01-preview"
                                        if ($response.StatusCode -eq 200) {
                                            $result = $response.Content | ConvertFrom-Json
                                        } else {
                                            continue
                                        }

                                        # Extract the provisioned throughput (RU/s)
                                        if ($null -ne $result.properties.resource -and $result.properties.resource.PSObject.Properties.Match("autoscaleSettings").Count -gt 0) {
                                            # Calculate RU consumption using TotalRequestUnits metric
                                            $dimFilter = "$(New-AzMetricFilter -Dimension DatabaseName -Operator eq -Value $database.name) and $(New-AzMetricFilter -Dimension CollectionName -Operator eq -Value $container.name)"
                                            $metrics = Get-AzMetric -ResourceId $resourceId -MetricName "TotalRequestUnits" -StartTime $startTime -EndTime $endTime -AggregationType Maximum -MetricFilter $dimFilter -TimeGrain 01:00:00
                                            if ($metrics -ne $null -and $metrics.Data -ne $null) {
                                                $accountRUs = ($metrics.Data | Measure-Object Maximum -Sum).Sum
                                                Write-Host "RUs for the past 30 days (Container): $accountRUs"
                                                $totalRUsForSubscription += $accountRUs
                                            } else {
                                                Write-Host "No data available for 'TotalRequestUnits' metric for the past 30 days."
                                            }
                                        } elseif ($result.properties.resource -ne $null -and $result.properties.resource.throughput -ne $null) {
                                            # Container is in manual mode
                                            $throughput = $result.properties.resource.throughput
                                            Write-Host "Provisioned throughput for container $($containerId): $throughput"
                                            $totalRUsForSubscription += $throughput * 730
                                        } else {
                                            Write-Host "No provisioned throughput data available for container $($containerId)."
                                        }
                                    } catch {
                                        Write-Host "Error retrieving throughput for container $($containerId): $_"
                                    }
                                }
                            }
                        } catch {
                            Write-Host "Error retrieving throughput settings for database $($databaseId): $_"
                        }
                    }
                }
            } catch {
                Write-Host "Error retrieving metrics for Cosmos DB Account: $_"
            }
        }

        # Calculate the average RUs per hour in units of RUs / hour
        $averageRUsPerHour = [math]::Round($totalRUsForSubscription / 730)
        Write-Host "Average consumption for subscription (RUs/hour): $averageRUsPerHour"

        $sub.BillableUnits = $averageRUsPerHour
        $sub.ResourcesCount = $cosmosDBAccountsCount
    }

    # *** Calculate metrics for Malware Scanning extension for Storage Accounts ***
    foreach ($sub in ($allSubscriptionsResults | where {$_.Plan -eq 'storageaccounts' -and $_.ResourcesCount -gt 0} )) {
        Write-Host "Processing Subscription: $($sub.SubscriptionName) - $($sub.SubscriptionID) for Defender for Storage Malware Scanning"

        $storageAccountsUri = "/subscriptions/$($sub.SubscriptionID)/providers/Microsoft.Storage/storageAccounts?api-version=2025-08-01"
        $response = Invoke-AzRestMethod -Method GET -Path $storageAccountsUri -ErrorAction Stop
        $StorageAccounts = $response.Content | ConvertFrom-Json | Select-Object -ExpandProperty value

        if (-not $StorageAccounts) {
            Write-Host "No Storage Accounts found in Subscription: $($sub.SubscriptionName)"
            continue
        }

        $storageAccountsCount = ($StorageAccounts | Measure-Object).Count
        Write-Host "Estimating Ingress metric for Malware scanning extension for $($storageAccountsCount) accounts in $($sub.SubscriptionName)"

        # Define the time range for the last 30 days
        $startTime = (Get-Date).AddDays(-30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $endTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")    

        # Blob Specific metrics to determine accurate put operations of content
        $blobMetricFilter = (New-AzMetricFilter -Dimension 'ApiName' -Operator eq -Value 'PutBlob','CopyBlob','PutBlock','PutBlockFromURL','AppendFile','FlushFile','CreatePathFile'  -WarningAction SilentlyContinue)

        $threadSafeDictSum = [System.Collections.Concurrent.ConcurrentDictionary[string, [Int64]]]::New()
        $StorageAccounts | ForEach-Object -ThrottleLimit 15 -Parallel {
            Write-Host "Processing Storage Account: $($_.id)"
            $blobIngress = 0
            $totalBlobIngress = 0
            $metricFilter = $USING:blobMetricFilter
            $startTime = $USING:startTime
            $endTime = $USING:endTime
            $dict = $USING:threadSafeDictSum
            $blobIngress = Get-AzMetric -ResourceId $($_.id + "/blobservices/default") -MetricName Ingress -MetricFilter $metricFilter -AggregationType Total -StartTime $startTime -EndTime $endTime -WarningAction SilentlyContinue
            $blobIngress.Data.Total | % {$totalBlobIngress += $_}
            $null = $dict.TryAdd($_.Id, $totalBlobIngress)
        }

        $totalIngressPerSA = $threadSafeDictSum.Values | Measure-Object -Sum | Select-Object -ExpandProperty Sum
        $totalIngressPerSA_GB = [math]::round([decimal]($totalIngressPerSA / 1GB),6)
     
        # Compile the subscription results
        $subscriptionResult = [PSCustomObject]@{
            SubscriptionID = $sub.SubscriptionID
            SubscriptionName = $sub.SubscriptionName
            Plan = $sub.Plan
            PlanName = $sub.PlanName
            SubPlan = "Malware Scanning"
            ResourcesCount = $storageAccountsCount
            BillableUnits = $totalIngressPerSA_GB
            PlanEnabled = $sub.PlanEnabled
            LegacyPlan = $legacyPlan
            newPlan = $newPlan
            EnvironmentType = $environmentType
            RecommendedSubPlan = $null
            ExcludableResources = $null
        }

        $allSubscriptionsResults += $subscriptionResult
    }

    # *** Calculate metrics for Defender for AI ***
    foreach ($sub in ($allSubscriptionsResults | where {$_.Plan -eq 'ai' -and $_.ResourcesCount -gt 0} )) {
        Write-Host "Processing Subscription: $($sub.SubscriptionName) - $($sub.SubscriptionID) for Defender for AI"

        $openAiUri = "/subscriptions/$($sub.SubscriptionID)/providers/Microsoft.CognitiveServices/accounts?api-version=2023-05-01"
        $response = Invoke-AzRestMethod -Method GET -Path $openAiUri -ErrorAction Stop
        $openAiResources = ($response.Content | ConvertFrom-Json).value | Where-Object {
            $_.kind -in @("OpenAI", "AIServices")
        }

        if (-not $openAiResources) {
            Write-Host "No Azure OpenAI resources found in Subscription: $($sub.SubscriptionName)"
            continue
        }

        $openAiResourcesCount = ($openAiResources | Measure-Object).Count
        Write-Host "Estimating token usage for $($openAiResourcesCount) Azure OpenAI resources in $($sub.SubscriptionName)"

        # Define the time range for the last 30 days
        $startTime = (Get-Date).AddDays(-30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $endTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

        $threadSafeDict = [System.Collections.Concurrent.ConcurrentDictionary[string, [Int64]]]::New()
        $openAiResources | ForEach-Object -ThrottleLimit 15 -Parallel {
            Write-Host "Processing OpenAI Resource: $($_.id)"
            $totalTokens = 0
            $startTime = $USING:startTime
            $endTime = $USING:endTime
            $dict = $USING:threadSafeDict
            $tokenMetrics = Get-AzMetric -ResourceId $_.id -MetricName "TokenTransaction" -StartTime $startTime -EndTime $endTime -AggregationType Total -MetricNamespace "microsoft.cognitiveservices/accounts" -WarningAction SilentlyContinue
            $totalTokens += ($tokenMetrics.Data | Measure-Object -Property 'Total' -Sum).Sum
            $null = $dict.TryAdd($_.Id, $totalTokens)
        }

        $tokens = $threadSafeDict.Values | Measure-Object -Sum | Select-Object -ExpandProperty Sum

        $sub.BillableUnits = $tokens
        $sub.ResourcesCount = $openAiResourcesCount
    }
}

$outputPath = "AzureMDCResourcesEstimation_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$allSubscriptionsResults | Export-Csv -Path $outputPath -NoTypeInformation -Force
Write-Host "Plan recommendations for all subscriptions exported to $outputPath successfully."