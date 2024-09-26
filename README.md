# Windows 365 Cloud PC Management PowerShell Module

<img align="right" width="300" height="300" src="https://github.com/Windows365Management/PSCloudPC/blob/main/PSCloudPC/Private/PSCloudPC_logo.png">

##### Project information
<a href="https://github.com/Windows365Management/PSCloudPC/contributors" alt="Contributors"><img src="https://img.shields.io/github/contributors/Windows365Management/PSCloudPC?style=for-the-badge" /></a>
<a href="https://github.com/Windows365Management/PSCloudPC/tree/main" target="_blank"><img src="https://img.shields.io/github/license/Windows365Management/PSCloudPC?style=for-the-badge" alt="Main"></a>
<a href="https://github.com/Windows365Management/PSCloudPC/issues" target="_blank"><img src="https://img.shields.io/github/issues/Windows365Management/PSCloudPC?style=for-the-badge" alt="Issues"></a>
##### Module statistics
<a href="https://github.com/Windows365Management/PSCloudPC" target="_blank"><img src="https://img.shields.io/github/v/release/Windows365Management/PSCloudPC?label=latest&style=for-the-badge" alt="CurrentVersion"></a>
<a href="https://github.com/Windows365Management/PSCloudPC" target="_blank"><img src="https://img.shields.io/badge/PowerShell-7.0-blue.svg?style=for-the-badge" alt="Issues"></a>




##### PowerShell Gallery statistics
<a href="https://www.powershellgallery.com/packages/PSCloudPC" target="_blank"><img src="https://img.shields.io/powershellgallery/v/PSCloudPC?style=for-the-badge" alt="Main"></a> <a href="https://www.powershellgallery.com/packages/PSCloudPC" target="_blank"><img src="https://img.shields.io/powershellgallery/dt/PSCloudPC?style=for-the-badge" alt="Downloads"></a>

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
Note: This is, for now, only available for a Windows Machine because it uses the .NET version for Windows. If you use Linux or Mac and want to connect interactively use the Device Code option.

- Client Secret
 ```powershell
Connect-Windows365 -ClientID <CLIENTID> -ClientSecret <CLIENTSECRET> -TenantID <Example>.onmicrosoft.com
```
- Client Certificate
 ```powershell
Connect-Windows365 -ClientID <CLIENTID> -ClientCertificate <CERTIFICATETHUMBPRINT> -TenantID <Example>.onmicrosoft.com
```
You can use a Service Principal to connect with PowerShell to the Microsoft Graph API. The Service Principal needs the following RestAPI permissions to perform the functions.
```
Directory.Read.All
DeviceManagementManagedDevices.ReadWrite.All
DeviceManagementConfiguration.ReadWrite.All
CloudPC.ReadWrite.All
```


- Device Code
```powershell
Connect-Windows365 -DeviceCode:$true -TenantID <Example>.onmicrosoft.com
```
You can use the Device Code to connect interactively for Linux or Mac.

## Cmdlets
This module provides the following cmdlets:
- Connect-Windows365
- Export-CPCProvisioningPolicy
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
- Import-CPCProvisioningPolicy
- Invoke-CPCEndGracePeriod
- Invoke-CPCReboot
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