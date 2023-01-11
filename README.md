# Windows 365 Cloud PC Management PowerShell Module

## Description
This PowerShell module allows you to manage your Windows 365 environment from the command line. It provides a set of cmdlets that allow you to perform various tasks, such as creating, modifying and deleting policies, managing Cloud PCs, and more.

## Getting Started

```
Install-Module -Name PSCloudPC -Verbose
```

Then import the module into your session

```
Import-Module PSCloudPC -Verbose -Force
```

## Connect to Windows 365 Cloud PC RestAPI
Before you can use the PowerShell Cmdlets within this module you first need to connect and get your authentication headers.

There are two ways to connect

- Interactive



- Service Principal
You can use a Service Principal to connect with PowerShell to the Microsoft Graph API. The Service Principal needs the following RestAPI permissions to perform the functions.

## Cmdlets
This module provides the following cmdlets:
- Connect-CloudPC
- Get-CloudPC
- Get-CPCCustomImage
- Get-CPCGalleryImage
- Get-CPCProvisioningPolicy
- Get-CPCRestorePoint
- Get-CPCSupportedRegion
- Get-CPCUserSettingsPolicy
- Invoke-CPCEndGracePeriod
- Invoke-CPCReprovision
- Invoke-CPCRestore
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
- Update-CPCProvisioningPolicy
- Update-CPCUserSettingsPolicy

## Troubleshooting