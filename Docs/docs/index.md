# Windows 365 Cloud PC Management PowerShell Module

![PSCloudPC](https://PSCloudPC.com/Images/PSCloudPC_logo.png){align="right" height="250" width="250"}

## Description
This PowerShell module allows you to manage your Windows 365 environment from the command line. It provides a set of cmdlets that allow you to perform various tasks, such as creating, modifying and deleting policies, managing Cloud PCs, and more.

## Getting Started

```powershell
Install-Module -Name PSCloudPC -Verbose
```

Then import the module into your session

```powershell
Import-Module PSCloudPC -Verbose -Force
```

## Connect to Windows 365 Cloud PC RestAPI
Before you can use the PowerShell Cmdlets within this module you first need to connect and get your authentication headers.

There are two ways to connect

- Interactive
```powershell
Connect-Windows365 -TenantID <EXAMPLE>.onmicrosoft.com
```


- Service Principal
 ```powershell
Connect-Windows365 -ClientID <CLIENTID> -ClientSecret <CLIENTSECRET>
```
You can use a Service Principal to connect with PowerShell to the Microsoft Graph API. The Service Principal needs the following RestAPI permissions to perform the functions.

## Cmdlets
This module provides the following cmdlets:
- Connect-Windows365
- Get-CloudPC
- Get-CPCAzureNetworkConnection
- Get-CPCCustomImage
- Get-CPCGalleryImage
- Get-CPCOrganizationSettings
- Get-CPCProvisioningPolicy
- Get-CPCRestorePoint
- Get-CPCServicePlans
- Get-CPCSupportedRegion
- Get-CPCUserSettingsPolicy
- Invoke-CPCEndGracePeriod
- Invoke-CPCReprovision
- Invoke-CPCRestore
- New-CPCAzureNetworkConnection
- New-CPCCustomImage
- New-CPCProvisioningPolicy
- New-CPCUserSettingsPolicy
- Remove-CPCAzureNetworkConnection
- Remove-CPCCustomImage
- Remove-CPCProvisioningPolicy
- Remove-CPCUserSettingsPolicy
- Set-CPCProvisioningPolicyAssignment
- Set-CPCUserSettingsPolicyAssignment
- Set-GraphVersion
- Update-CPCOrganizationSettings
- Update-CPCProvisioningPolicy
- Update-CPCUserSettingsPolicy


## Troubleshooting