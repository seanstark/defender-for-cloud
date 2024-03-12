
# get-azStorageIngressMetrics.ps1
This script will get estimated ingress metrics on Azure Files and Azure Blob files for supported V2 Storage Accounts based on the ingress metric, which is in bytes. 
- The ingress metric used in this script is based on the last 30 days at a 5 minute interval
- Overall this estimate is a ballpark and not to be expected as 100% accurate measure of file size on upload
- The script will output the totals and export the data to a csv file

## Examples 

### All storage accounts in the Tenant or the subriptions you have access to
```powershell
.\get-azStorageIngressMetrics.ps1 -all
```
### All storage accounts in subscriptions you specify
```powershell
.\get-azStorageIngressMetrics.ps1 -subscriptionId '98aa6bab-0ef8-48e2-8397-a0101e0712e3', 'ada06e68-375e-4210-be3a-c6cacebf41c5'
```
### All storage accounts in a management group you specify
```powershell
.\get-azStorageIngressMetrics.ps1 -managementGroupName "Finance"
```
