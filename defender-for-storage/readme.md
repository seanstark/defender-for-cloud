
# get-azStorageMetrics.ps1
This script will get estimated metrics on Azure Storage V2 Accounts to help estimate costs for Defender for Storage and Defender for Storage Malware Scanning
- The metrics used in this script is based on the last 30 days
- The price caculations are based on list price
- The script will output the totals and export the data to a csv file

## Examples 

### Get estimates for all storage accounts in the Tenant
```powershell
.\get-azStorageMetrics.ps1 -all
```
### Get estimates for all storage accounts in a management group you specify
```powershell
.\get-azStorageMetrics.ps1 -managementGroupName "Finance" 
```
### Get estimates for all storage accounts in Subscriptions you specify
```powershell
# Single Subscription
.\get-azStorageMetrics.ps1 -subscriptionId '98aaxxab-0ef8-48e2-8397-a0101e0712e3'
# Multiple Subscriptions
.\get-azStorageMetrics.ps1 -subscriptionId '98aaxxab-0ef8-48e2-8397-a0101e0712e3,adaxxe68-375e-4210-be3a-c6cacebf41c5'
```
### Get estimates for all storage accounts in a resource group you specify
```powershell
.\get-azStorageMetrics.ps1 -resourceGroupName "production accounts" -subscriptionId 'adaxxe68-375e-4210-be3a-c6cacebf41c5'
```
### Get estimates for a single storage account
```powershell
.\get-azStorageMetrics.ps1 -storageAccountName "customeruploads" -resourceGroupName 'production accounts' -subscriptionId 'adaxxe68-375e-4210-be3a-c6cacebf41c5'
```
![image](https://github.com/seanstark/defender-for-cloud/assets/84108246/80611040-e224-48e4-af5c-657417bb03fb)


