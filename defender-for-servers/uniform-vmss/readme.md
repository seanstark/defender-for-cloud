
# Deploying Defender for Endpoint on Uniform Virtual Machine Scalesets

Currently the autoprovising of Defender for Endpoint using the MDE.Linux/MDE.Windows extensions with Defender for Servers is not supported on Uniform Virtual Machine Scalesets. This solution leverages [Azure Compute VM Applications](https://learn.microsoft.com/azure/virtual-machines/vm-applications) to deploy the Defender for Endpoint agent on Windows and Linux Uniform Virtual Machine Scalesets. 

> These steps leverage pre-built arm templates to deploy all the Prerequisites and VM Applications

> [!IMPORTANT]
> VM Applications leverage Storage Account SAS tokens and require public access to the blob containers. If you have policies in place that prevent Storage account key access and Public network access this solution will not work

## Overview of steps
You will need to do a few prerequites steps before creating the Azure Compute Gallery
1. Create an Azure Storage Account to store the VM Application files
2. Upload the necessary Defender for Endpoint onboarding and installation scripts for Windows and Linux to the storage account

## Prerequisites

### Step 1 - Deploy the Storage Account
> [!IMPORTANT]
> VM Applications leverage SAS tokens and require public access to the blob containers.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fseanstark%2Fdefender-for-cloud%2Frefs%2Fheads%2Fmain%2Fdefender-for-servers%2Funiform-vmss%2FstorageAccount.json)

> After you create the storage account ensure you have the **Storage Blob Data Contributor** role assigned

## Windows

### Step 1 - Download the Windows Onboarding Script
> [!IMPORTANT]
> Use the Group Policy onboarding script to ensure duplicate devices are not created

1. Download the correct Operating System version **Group Policy Deployment Method** onboarding script from the [Defender XDR Portal](https://security.microsoft.com/securitysettings/endpoints/onboarding)

   <img width="997" height="631" alt="image" src="https://github.com/user-attachments/assets/e820de13-bfae-493c-b752-b4b15f6316d9" />

2. Unzip the **GatewayWindowsDefenderATPOnboardingPackage.zip** file and upload the **WindowsDefenderATPOnboardingScript.cmd** file to the **mde-windows** blob container

### Step 3 - Testing Deployment

## Linux

### Step 1 - Download the Linux Onboarding Script
1. Download the Local Script (Python) onboarding script from the [Defender XDR Portal](https://security.microsoft.com/securitysettings/endpoints/onboarding)

   <img width="951" height="515" alt="image" src="https://github.com/user-attachments/assets/a3dbef11-1d6c-466e-9786-ef728f376a43" />

2. Download the [installer bash script](https://github.com/microsoft/mdatp-xplat/blob/master/linux/installation/mde_installer.sh) provided in our public GitHub repository.
3. TAR the mde_installer.sh and MicrosoftDefenderATPOnboardingLinuxServer.py script into a single TAR file called **mde_installer.tar**
4. Upload the mde_installer.tar file to the the **mde-linux** blob container

### Step 2 - Deploy the Azure Compute Gallery

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fseanstark%2Fdefender-for-cloud%2Frefs%2Fheads%2Fmain%2Fdefender-for-servers%2Funiform-vmss%2FcomputeGallery.json)
