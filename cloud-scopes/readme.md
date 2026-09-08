# Synchronize Azure management groups to Defender cloud scopes

This solution deploys a scheduled Azure Logic App that synchronizes the Azure management-group hierarchy to Microsoft Defender cloud scopes.

For every management group visible to the Logic App, the workflow:

1. Finds all direct and nested descendant subscriptions.
2. Uses the cloud-scope name `Azure - <management group display name>`.
3. Creates the cloud scope when it does not exist.
4. Adds missing Azure subscriptions and removes Azure subscriptions that no longer belong under the management group.
5. Preserves non-Azure environments already attached to an existing cloud scope.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fseanstark%2Fdefender-for-cloud%2Fmain%2Fcloud-scopes%2Fazuredeploy.json)

## Deployed resources

- A Consumption Logic App with a system-assigned managed identity.
- A Reader role assignment at the selected management-group scope.
- A recurrence trigger, daily by default.

The workflow uses the Azure Management Groups `getEntities` REST API to retrieve the hierarchy with pagination. It uses the Microsoft Graph beta security zones APIs to create scopes and reconcile their environment relationships.

## Prerequisites

- A commercial Microsoft Entra tenant. The zones API is not available in US Government or China national clouds.
- Permission to deploy a Logic App to the target resource group.
- `Microsoft.Authorization/roleAssignments/write` at the selected management group, such as Owner or User Access Administrator, so the template can grant Reader to the managed identity.
- Privileged Role Administrator or Global Administrator in Microsoft Entra ID to assign the Security Administrator directory role to the Logic App managed identity.

Use the tenant root management-group ID to include the entire hierarchy. The template defaults this value to the tenant ID.

## Deploy

Use the button above, or deploy with Azure CLI:

```powershell
az deployment group create `
  --resource-group <resource-group> `
  --template-file .\azuredeploy.json `
  --parameters logicAppName=sync-management-groups-to-cloud-scopes `
               rootManagementGroupId=<root-management-group-id>
```

The deployment output includes `logicAppPrincipalId`. Grant that managed identity the Microsoft Entra **Security Administrator** directory role. Sign in to Azure CLI as a Privileged Role Administrator or Global Administrator, then run:

```powershell
az login --tenant '<tenant-id>'

$roleAssignment = @{
  principalId      = '<logicAppPrincipalId>'
  roleDefinitionId = '194ae4cb-b126-40b2-bd5b-6091b380977d'
  directoryScopeId = '/'
} | ConvertTo-Json -Compress

az rest `
  --method POST `
  --url 'https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments' `
  --headers 'Content-Type=application/json' `
  --body $roleAssignment
```

The role definition ID above is the tenant-wide Microsoft Entra Security Administrator role. Wait a few minutes for directory-role replication before the first run.

## Run and verify

The workflow runs on its configured recurrence. To test immediately, open the Logic App in the Azure portal and select **Run Trigger** > **Scheduled_sync**.

Review the run history for successful calls to:

- `management.azure.com/providers/Microsoft.Management/getEntities`
- `graph.microsoft.com/beta/security/zones`
- `graph.microsoft.com/beta/security/zones/{zoneId}/environments`

Then verify the resulting scopes in the Microsoft Defender portal under cloud scopes.

## Reconciliation details

- Nested subscriptions are included because each subscription's `parentNameChain` is matched against every management-group ID.
- Empty management groups produce cloud scopes with no Azure subscription environments.
- Existing AWS, GCP, DevOps, registry, and other non-Azure environments are not removed.
- Cloud scopes not prefixed from a current management-group display name are not deleted.
- Management-group display names should be unique. If two groups have the same display name, both map to the same cloud-scope name.
- A zone supports at most 1,000 environments, and a tenant supports at most 1,000 zones.

## API status

The Microsoft Graph zones endpoints are currently documented only under `/beta`. Microsoft states that beta APIs are subject to change and are not supported for production applications. Validate the workflow and the Security Administrator authorization behavior in a non-production tenant before production use.

## References

- [Create a zone](https://learn.microsoft.com/graph/api/security-security-post-zones?view=graph-rest-beta)
- [List zones](https://learn.microsoft.com/graph/api/security-security-list-zones?view=graph-rest-beta)
- [Create an environment](https://learn.microsoft.com/graph/api/security-zone-post-environments?view=graph-rest-beta)
- [Delete an environment](https://learn.microsoft.com/graph/api/security-environment-delete?view=graph-rest-beta)
- [List management-group entities](https://learn.microsoft.com/rest/api/managementgroups/entities/list?view=rest-managementgroups-2020-05-01)