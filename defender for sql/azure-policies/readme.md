
# Overview
These custom Azure Policies will configure and deploy Defender for SQL on virtual machines using the new SQL IaaS Extension method.

# How to use
1. Deploy the custom policies first
2. Create a new Azure Policy Initiative Definition with all the custom and Built-in policy definitions below

| Policy Name | Description | Type |
|---|---| --- |
| Configure Automatic registration of the SQL IaaS Agent extension | By default, Azure VMs with SQL Server 2016 or later are automatically registered with the SQL IaaS Agent extension when detected by the CEIP service. You can enable the automatic registration feature for your subscription to easily and automatically register any SQL Server VMs not picked up by the CEIP service, such as older versions of SQL Server. | Custom |
| Deploy Microsoft Defender for SQL to Arc-enabled SQL Windows Servers | Deploys the Microsoft Defender for SQL and SQL IaaS Extension to Arc-enabled SQL Windows Servers to support Defender for SQL on Arc-enabled SQL Windows Servers. | Custom |
| Deploy Microsoft Defender for SQL to SQL Windows Virtual Machines | Deploys the Microsoft Defender for SQL and SQL IaaS Extension to SQL Windows Virtual Machines to support Defender for SQL on virtual machines | Custom |
| Configure Azure Defender for SQL servers on machines to be enabled | Enables the Defender for SQL servers on machines plan on the subscription | Built-in |
| Assign System Assigned identity to SQL Virtual Machines | Assign System Assigned identity at scale to Windows SQL virtual machines | Built-in

## Deploy to Azure using PowerShell

``` powershell

New-AzPolicyDefinition -Name $(New-Guid) -Policy 'https://raw.githubusercontent.com/seanstark/defender-for-cloud/refs/heads/main/defender%20for%20sql/azure-policies/arm-templates/Configure%20Automatic%20registration%20of%20the%20SQL%20IaaS%20Agent%20extension.json'

New-AzPolicyDefinition -Name $(New-Guid) -Policy 'https://raw.githubusercontent.com/seanstark/defender-for-cloud/refs/heads/main/defender%20for%20sql/azure-policies/arm-templates/Deploy%20Microsoft%20Defender%20for%20SQL%20to%20Arc-enabled%20SQL%20Windows%20Servers.json'

New-AzPolicyDefinition -Name $(New-Guid) -Policy 'https://raw.githubusercontent.com/seanstark/defender-for-cloud/refs/heads/main/defender%20for%20sql/azure-policies/arm-templates/Deploy%20Microsoft%20Defender%20for%20SQL%20to%20SQL%20Windows%20Virtual%20Machines.json'

```

## Deploy to Azure using the portal

| Policy Name | Deploy Link |
|---|---|
| Configure Automatic registration of the SQL IaaS Agent extension | [[Deploy to Azure]](https://portal.azure.com/#blade/Microsoft_Azure_Policy/CreatePolicyDefinitionBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fseanstark%2Fdefender-for-cloud%2Frefs%2Fheads%2Fmain%2Fdefender%2520for%2520sql%2Fazure-policies%2Farm-templates%2FConfigure%2520Automatic%2520registration%2520of%2520the%2520SQL%2520IaaS%2520Agent%2520extension.json)|
| Deploy Microsoft Defender for SQL to Arc-enabled SQL Windows Servers | [[Deploy to Azure]](https://portal.azure.com/#blade/Microsoft_Azure_Policy/CreatePolicyDefinitionBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fseanstark%2Fdefender-for-cloud%2Frefs%2Fheads%2Fmain%2Fdefender%2520for%2520sql%2Fazure-policies%2Farm-templates%2FDeploy%2520Microsoft%2520Defender%2520for%2520SQL%2520to%2520Arc-enabled%2520SQL%2520Windows%2520Servers.json) |
| Deploy Microsoft Defender for SQL to SQL Windows Virtual Machines | [[Deploy to Azure]](https://portal.azure.com/#blade/Microsoft_Azure_Policy/CreatePolicyDefinitionBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fseanstark%2Fdefender-for-cloud%2Frefs%2Fheads%2Fmain%2Fdefender%2520for%2520sql%2Fazure-policies%2Farm-templates%2FDeploy%2520Microsoft%2520Defender%2520for%2520SQL%2520to%2520SQL%2520Windows%2520Virtual%2520Machines.json) |
