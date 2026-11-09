# Changelog
This file contains all the changes to this Windows 365 PowerShell module. From 1.0.17 on, the format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Unreleased

## 1.0.18 - 2026-11-09
### Breaking changes
- Remove-CPCAzureNetworkConnection, Remove-CPCCustomImage, Remove-CPCProvisioningPolicy and Remove-CPCUserSettingsPolicy only delete an object whose name matches exactly (upper and lower case don't matter). Before, part of the name was enough, so the wrong object could be deleted. When no object or more than one object matches, nothing is deleted. These cmdlets now ask for confirmation. **What to do:** pass the full name, and add -Confirm:$false when you run them in a script (#133)
- Update-CPCUserSettingsPolicy and Set-CPCCrossRegionDisasterRecovery no longer return the policy. **What to do:** if your script uses the output, run Get-CPCUserSettingsPolicy after the change (#156)
- Set-CPCCrossRegionDisasterRecovery: -RegionName and -RegionGroup are now required when you turn on crossRegion or premium disaster recovery (#139)

### Added
- Get-CPCAuditEvent: shows the Windows 365 audit log
- Get-CPCConnectivityHistory: shows the connection history of a Cloud PC
- Get-CPCRealTimeConnectionStatus: shows whether a user is signed in to a Cloud PC right now
- Get-CPCRemoteActionResult: shows the remote actions run on a Cloud PC and their result
- Invoke-CPCChangeUserAccountType: makes the user of a Cloud PC a standard user or a local administrator
- Invoke-CPCCreateSnapshot: creates a restore point of a Cloud PC
- Invoke-CPCPowerOn and Invoke-CPCPowerOff: start or shut down a Windows 365 Frontline Cloud PC
- Invoke-CPCRetryPartnerAgentInstallation: retries a failed partner agent installation on a Cloud PC
- Invoke-CPCTroubleshoot: runs the Windows 365 troubleshooter on a Cloud PC
- Update-CPCAzureNetworkConnection: changes an existing Azure network connection
- Invoke-CPCRestore: new -SnapshotId parameter, so you can restore a Cloud PC from a script without the selection window
- Invoke-CPCReprovision: new -OsVersion and -UserAccountType parameters
- Remove-CPCCustomImage: new -Version parameter, for images that share a name (#133)

### Changed
- New-CPCAzureNetworkConnection uses -Name like the other cmdlets; -DisplayName still works
- Get-CPCServicePlan also returns the provisioning type of each plan (#141)
- Error messages now include the reason given by Microsoft Graph, which makes failures easier to solve (#132)
- The help of every cmdlet is complete: each parameter has a description, and wrong descriptions and permissions are corrected (#144)

### Deprecated
- Update-CPCUserSettingsPolicy: -DisableRestartPrompts and -SelfServiceEnabled have no effect, because Microsoft retired these settings. They show a warning and will be removed in a later version (#156)

### Fixed
- Connect-Windows365: signing in with a certificate didn't work (#128), and signing in with a device code didn't ask for the Cloud PC permissions (#129)
- Get-CloudPC didn't return all Cloud PCs in larger tenants (#130)
- Some cmdlets reported success while the change had failed (#131)
- Update-CPCUserSettingsPolicy and Set-CPCCrossRegionDisasterRecovery reset every setting you didn't pass to its default value (#156)
- Set-CPCCrossRegionDisasterRecovery couldn't turn disaster recovery off (#139)
- Get-CPCServicePlan -ServicePlanName didn't work. Invoke-CPCResize and Set-CPCProvisioningPolicyAssignment stop when the service plan name is unknown or matches more than one plan (#141)
- Set-CPCProvisioningPolicyAssignment and Set-CPCUserSettingsPolicyAssignment failed when the group was already assigned (#142)
- New-CPCProvisioningPolicy couldn't create a hybrid join policy, and New-CPCProvisioningPolicy and Update-CPCProvisioningPolicy didn't pass on the join type of the Azure network connection (#135)
- New-CPCAzureNetworkConnection sent the AD domain password in an encrypted form that Windows 365 can't use (#137)
- New-CPCCustomImage created images without a name (#136)
- Update-CPCOrganizationSetting sent its on/off settings in the wrong format (#140)
- Invoke-CPCPublishCloudApp and Invoke-CPCUnpublishCloudApp could act on another app whose name contained the name you entered (#134)
- Invoke-CPCEndGracePeriod stopped with an error when it asked for confirmation (#138)
- Invoke-CPCRestore and Invoke-CPCReprovision use the current Windows 365 restore and reprovision actions
- Get-CPCRestorePoint returned no restore points (#98)
- Get-CPCGalleryImage -Name searched on the offer name instead of the image name
- When a name isn't found or a value isn't valid, the cmdlet now stops before it changes anything, also with -ErrorAction SilentlyContinue (#139, #141)

### Known issues
- Invoke-CPCChangeUserAccountType doesn't work yet: Microsoft Graph returns an error (#104)
- Invoke-CPCPowerOn and Invoke-CPCPowerOff haven't been tested on a Frontline Cloud PC yet (#107)
- Microsoft removes the AD domain user name and password of Azure network connections on December 31, 2026. New-CPCAzureNetworkConnection and Update-CPCAzureNetworkConnection will be updated before then (#175)

## 1.0.17 - 2026-03-18
### Added
- Invoke-CPCRename: renames a Cloud PC (#51)
- Invoke-CPCResize: moves a Cloud PC to another service plan (#64)
- Set-CPCCrossRegionDisasterRecovery: configures cross-region disaster recovery on a user settings policy (#49)
- Update-CPCUserSettingsPolicy: new -DisableRestartPrompts parameter

### Changed
- Get-CPCUserSettingsPolicy also returns the cross-region disaster recovery settings

### Removed
- Set-CPCCloudAppAssignment. Cloud Apps are now made available through the provisioning policy assignment

### Fixed
- Update-CPCUserSettingsPolicy ignored -LocalAdminEnabled
- The examples in the help of Invoke-CPCPublishCloudApp and Invoke-CPCUnpublishCloudApp were wrong

## 1.0.16
### Breaking Changes
- Rebuild New-CPCProvisioningPolicy
- Rebuild Set-CPCProvisioningPolicyAssignment

### Changes
- Add new CMDlets for CloudApps
- Edited New-CPCProvisioningPolicy

## 1.0.15
###Changes
- Restructure module repository
- Changed Authentication to Microsoft.Graph
- Added authentication for token based auth
- Added Pester tests for disconnect-windows365

## 1.0.13 [25-09-2024]
###Changes
- Changed authentication check the docs for examples
- Added Certs based authentication
- Added Paging for Graph Requests

## 1.0.4 [20-1-2023]
### Bugfixes
- Bug fixed in Update-CPCUserSettingsPolicy, parameter value was not working
- Bug fixed in Update-CPCProvisioningPolicy, parameter value was not working
### Changes
- Changed minimal PowerShell version to 7.2
- Synopsis changed for several commands
- Updated help and examples
- Remove some write-output
- Added the RestAPI result to the Update commands
- Added -SkipHttpErrorCheck to the invoke-webrequest commands
### Added commands
- Get-CPCOrganizationSettings - Retrieve the Windows 365 Organization Settings when using Business edition
- Update-CPCOrganizationSettings - Update the Windows 365 Organization Settings when using Business edition
- Get-CPCServicePlans - Retrieve all currently available Windows 365 service plans
- Get-CPCAzureNetworkConnection - Retrieve the Azure Network Connection settings
- New-CPCAzureNetworkConnection - Create a new Azure Network Connection

## 1.0.3 [16-1-2023]
### Bugfixes
- Bug fixed in New-CPCUserSettingsPolicy, wrong parameter variable.

### Changes
## 1.0.0 [11-1-2023]

- Initial release
