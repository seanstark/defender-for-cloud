
# Overview
These custom Azure Policies will configure and deploy Defender for SQL on virtual machines using the new SQL IaaS Extension method.

> [!IMPORTANT]
> You need the custom policies here and the **Built-in** ones to ensure you have you have everything configured correctly.

- [How to use](#how-to-use)
- [Target All SQL Servers](#all-sql-servers)
   * [Deploy to Azure using PowerShell](#deploy-to-azure-using-powershell)
   * [Deploy to Azure using the portal](#deploy-to-azure-using-the-portal)
- [Scoped Deployment](#scoped-deployment)
   * [Deploy to Azure using PowerShell](#deploy-to-azure-using-powershell-1)
   * [Deploy to Azure using the portal](#deploy-to-azure-using-the-portal-1)

# How to use

1. Deploy the custom policies first based on your scenario, either targeting all servers in a subscription or only specific servers
2. Create a new Azure Policy Initiative Definition with all the custom and Built-in policy definitions below

# Target All SQL Servers

| Policy Name | Description | Type |
|---|---| --- |
| Configure Automatic registration of the SQL IaaS Agent extension | By default, Azure VMs with SQL Server 2016 or later are automatically registered with the SQL IaaS Agent extension when detected by the CEIP service. You can enable the automatic registration feature for your subscription to easily and automatically register any SQL Server VMs not picked up by the CEIP service, such as older versions of SQL Server. | Custom |
| Deploy Microsoft Defender for SQL to Arc-enabled SQL Windows Servers | Deploys the Microsoft Defender for SQL and SQL IaaS Extension to Arc-enabled SQL Windows Servers to support Defender for SQL on Arc-enabled SQL Windows Servers. | Custom |
| Deploy Microsoft Defender for SQL to SQL Windows Virtual Machines | Deploys the Microsoft Defender for SQL and SQL IaaS Extension to SQL Windows Virtual Machines to support Defender for SQL on virtual machines | Custom |
| Configure Azure Defender for SQL servers on machines to be enabled | Enables the Defender for SQL servers on machines plan on the subscription | Built-in |
| Assign System Assigned identity to SQL Virtual Machines | Assign System Assigned identity at scale to Windows SQL virtual machines | Built-in

## Deploy to Azure using PowerShell

``` powershell
# Create the custom policy definitions
New-AzPolicyDefinition -Name $(New-Guid) -Policy 'https://raw.githubusercontent.com/seanstark/defender-for-cloud/refs/heads/main/defender%20for%20sql/azure-policies/arm-templates/Configure%20Automatic%20registration%20of%20the%20SQL%20IaaS%20Agent%20extension.json'

New-AzPolicyDefinition -Name $(New-Guid) -Policy 'https://raw.githubusercontent.com/seanstark/defender-for-cloud/refs/heads/main/defender%20for%20sql/azure-policies/arm-templates/Deploy%20Microsoft%20Defender%20for%20SQL%20to%20Arc-enabled%20SQL%20Windows%20Servers.json'

New-AzPolicyDefinition -Name $(New-Guid) -Policy 'https://raw.githubusercontent.com/seanstark/defender-for-cloud/refs/heads/main/defender%20for%20sql/azure-policies/arm-templates/Deploy%20Microsoft%20Defender%20for%20SQL%20to%20SQL%20Windows%20Virtual%20Machines.json'

# Create the Policy Initiative Definition
$policies = Get-AzPolicyDefinition | Where-Object {$_.DisplayName -in (
    'Configure Automatic registration of the SQL IaaS Agent extension',
    'Deploy Microsoft Defender for SQL to Arc-enabled SQL Windows Servers',
    'Deploy Microsoft Defender for SQL to SQL Windows Virtual Machines',    
    'Configure Azure Defender for SQL servers on machines to be enabled',
    'Assign System Assigned identity to SQL Virtual Machines'
)}

New-AzPolicySetDefinition -Name $(New-Guid) -DisplayName 'Deploy Defender for SQL on Machines to All SQL Servers' `
-PolicyDefinition $($policies | Select-Object @{Name='policyDefinitionId';Expression={$_.Id}}| ConvertTo-Json -Depth 10) `
-Metadata '{"category":"Security Center"}'

```

## Deploy to Azure using the portal

| Policy Name | Deploy Link |
|---|---|
| Configure Automatic registration of the SQL IaaS Agent extension | [[Deploy to Azure]](https://portal.azure.com/#blade/Microsoft_Azure_Policy/CreatePolicyDefinitionBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fseanstark%2Fdefender-for-cloud%2Frefs%2Fheads%2Fmain%2Fdefender%2520for%2520sql%2Fazure-policies%2Farm-templates%2FConfigure%2520Automatic%2520registration%2520of%2520the%2520SQL%2520IaaS%2520Agent%2520extension.json)|
| Deploy Microsoft Defender for SQL to Arc-enabled SQL Windows Servers | [[Deploy to Azure]](https://portal.azure.com/#blade/Microsoft_Azure_Policy/CreatePolicyDefinitionBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fseanstark%2Fdefender-for-cloud%2Frefs%2Fheads%2Fmain%2Fdefender%2520for%2520sql%2Fazure-policies%2Farm-templates%2FDeploy%2520Microsoft%2520Defender%2520for%2520SQL%2520to%2520Arc-enabled%2520SQL%2520Windows%2520Servers.json) |
| Deploy Microsoft Defender for SQL to SQL Windows Virtual Machines | [[Deploy to Azure]](https://portal.azure.com/#blade/Microsoft_Azure_Policy/CreatePolicyDefinitionBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fseanstark%2Fdefender-for-cloud%2Frefs%2Fheads%2Fmain%2Fdefender%2520for%2520sql%2Fazure-policies%2Farm-templates%2FDeploy%2520Microsoft%2520Defender%2520for%2520SQL%2520to%2520SQL%2520Windows%2520Virtual%2520Machines.json) |

# Scoped Deployment
If you would like to deploy Defender for SQL on machines to only specific SQL servers you will need to disable the plan at the subscription level and enable the plan at the individual SQL server resource level. To facilitate this you will need to tag individual virtual machines or arc connected machines that you want the plan enabled on and leverage the policies under the Scoped Deployment section. Any tag name and tag value can be leveraged with the Azure Policy.

| Policy Name | Description | Type |
|---|---| --- |
| Configure Automatic registration of the SQL IaaS Agent extension | By default, Azure VMs with SQL Server 2016 or later are automatically registered with the SQL IaaS Agent extension when detected by the CEIP service. You can enable the automatic registration feature for your subscription to easily and automatically register any SQL Server VMs not picked up by the CEIP service, such as older versions of SQL Server. | Custom |
| Disable the Microsoft Defender for SQL servers on machines plan | This policy will disable the Defender for SQL servers on machines plan, which is required if you are deploying Defender for SQL to only specified machines | Custom |
| Deploy Microsoft Defender for SQL to only specified Arc-enabled SQL Windows Servers | Deploys the Microsoft Defender for SQL and SQL IaaS Extension to Arc-enabled SQL Windows Servers to support Defender for SQL on Arc-enabled SQL Windows Servers | Custom |
| Deploy Microsoft Defender for SQL to only specified SQL Windows Virtual machines | Deploys the Microsoft Defender for SQL and SQL IaaS Extension to SQL Windows Virtual Machines to support Defender for SQL on virtual machines | Custom |
| Assign System Assigned identity to SQL Virtual Machines | Assign System Assigned identity at scale to Windows SQL virtual machines | Built-in |

## Deploy to Azure using PowerShell

``` powershell
# Create the custom policy definitions
New-AzPolicyDefinition -Name $(New-Guid) -Policy 'https://raw.githubusercontent.com/seanstark/defender-for-cloud/refs/heads/main/defender%20for%20sql/azure-policies/arm-templates/Configure%20Automatic%20registration%20of%20the%20SQL%20IaaS%20Agent%20extension.json'

New-AzPolicyDefinition -Name $(New-Guid) -Policy 'https://raw.githubusercontent.com/seanstark/defender-for-cloud/refs/heads/main/defender%20for%20sql/azure-policies/arm-templates/Disable%20the%20Microsoft%20Defender%20for%20SQL%20servers%20on%20machines%20plan.json'

New-AzPolicyDefinition -Name $(New-Guid) -Policy 'https://raw.githubusercontent.com/seanstark/defender-for-cloud/refs/heads/main/defender%20for%20sql/azure-policies/arm-templates/Deploy%20Microsoft%20Defender%20for%20SQL%20to%20only%20specified%20Arc-enabled%20SQL%20Windows%20Servers.json'

New-AzPolicyDefinition -Name $(New-Guid) -Policy 'https://raw.githubusercontent.com/seanstark/defender-for-cloud/refs/heads/main/defender%20for%20sql/azure-policies/arm-templates/Deploy%20Microsoft%20Defender%20for%20SQL%20to%20only%20specified%20SQL%20Windows%20Virtual%20machines.json'
```

## Deploy to Azure using the portal

| Policy Name | Deploy Link |
|---|---|
| Configure Automatic registration of the SQL IaaS Agent extension | [[Deploy to Azure]](https://portal.azure.com/#blade/Microsoft_Azure_Policy/CreatePolicyDefinitionBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fseanstark%2Fdefender-for-cloud%2Frefs%2Fheads%2Fmain%2Fdefender%2520for%2520sql%2Fazure-policies%2Farm-templates%2FConfigure%2520Automatic%2520registration%2520of%2520the%2520SQL%2520IaaS%2520Agent%2520extension.json)|
| Disable the Microsoft Defender for SQL servers on machines plan | [[Deploy to Azure]](https://portal.azure.com/#blade/Microsoft_Azure_Policy/CreatePolicyDefinitionBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fseanstark%2Fdefender-for-cloud%2Frefs%2Fheads%2Fmain%2Fdefender%2520for%2520sql%2Fazure-policies%2Farm-templates%2FDisable%2520the%2520Microsoft%2520Defender%2520for%2520SQL%2520servers%2520on%2520machines%2520plan.json) |
| Deploy Microsoft Defender for SQL to only specified Arc-enabled SQL Windows Servers | [[Deploy to Azure]](https://portal.azure.com/#blade/Microsoft_Azure_Policy/CreatePolicyDefinitionBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fseanstark%2Fdefender-for-cloud%2Frefs%2Fheads%2Fmain%2Fdefender%2520for%2520sql%2Fazure-policies%2Farm-templates%2FDeploy%2520Microsoft%2520Defender%2520for%2520SQL%2520to%2520only%2520specified%2520Arc-enabled%2520SQL%2520Windows%2520Servers.json) |
| Deploy Microsoft Defender for SQL to only specified SQL Windows Virtual machines | [[Deploy to Azure]](https://portal.azure.com/#blade/Microsoft_Azure_Policy/CreatePolicyDefinitionBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fseanstark%2Fdefender-for-cloud%2Frefs%2Fheads%2Fmain%2Fdefender%2520for%2520sql%2Fazure-policies%2Farm-templates%2FDeploy%2520Microsoft%2520Defender%2520for%2520SQL%2520to%2520only%2520specified%2520SQL%2520Windows%2520Virtual%2520machines.json) |
