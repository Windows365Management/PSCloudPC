# Changelog
This file contains all the changes to this Windows 365 PowerShell module.

## 1.0.18
### Breaking Changes
- Remove-CPCAzureNetworkConnection, Remove-CPCCustomImage, Remove-CPCProvisioningPolicy and Remove-CPCUserSettingsPolicy match the name exactly (not case-sensitive) instead of a partial match. When no object or more than one object matches, nothing is deleted. They ask for confirmation by default; use -Confirm:$false in scripts (#133)
- Update-CPCUserSettingsPolicy and Set-CPCCrossRegionDisasterRecovery no longer return output (#156)
- Update-CPCUserSettingsPolicy: -DisableRestartPrompts and -SelfServiceEnabled have no effect, because Microsoft retired these settings. They write a warning and are not sent (#156)
- Set-CPCCrossRegionDisasterRecovery requires -RegionName and -RegionGroup when -DisasterRecoveryType is crossRegion or premium (#139)

### Added commands
- Get-CPCAuditEvent: returns Cloud PC audit events
- Get-CPCConnectivityHistory: returns the connection history of a Cloud PC
- Get-CPCRealTimeConnectionStatus: returns the current sign-in status of a Cloud PC
- Get-CPCRemoteActionResult: returns the remote actions run on a Cloud PC and their result
- Invoke-CPCChangeUserAccountType: changes the local account type (standard user or administrator) of a Cloud PC
- Invoke-CPCCreateSnapshot: creates a snapshot of a Cloud PC
- Invoke-CPCPowerOn and Invoke-CPCPowerOff: power a Windows 365 Frontline Cloud PC on or off
- Invoke-CPCRetryPartnerAgentInstallation: retries a failed partner agent installation on a Cloud PC
- Invoke-CPCTroubleshoot: runs the troubleshooter on a Cloud PC
- Update-CPCAzureNetworkConnection: updates an Azure network connection

### Changes
- Invoke-CPCRestore: new -SnapshotId parameter to restore without the interactive picker
- Invoke-CPCReprovision: new -OsVersion and -UserAccountType parameters
- Remove-CPCCustomImage: new -Version parameter for images that share a name (#133)
- New-CPCAzureNetworkConnection uses -Name like the other cmdlets; -DisplayName still works as an alias
- Get-CPCServicePlan returns provisioningType (#141)
- Error messages include the error code and message from Microsoft Graph (#132)
- Every parameter has a description, and wrong synopses and permissions in the help are corrected (#144)

### Bugfixes
- Connect-Windows365: certificate authentication sent an empty token (#128), and device code sign-in didn't request the Cloud PC permissions (#129)
- Get-CloudPC only returned the first page of Cloud PCs (#130)
- Failed changes were reported as success (#131)
- Update-CPCUserSettingsPolicy and Set-CPCCrossRegionDisasterRecovery reset every setting that wasn't passed (#156)
- Set-CPCCrossRegionDisasterRecovery couldn't turn disaster recovery off and sent deprecated properties (#139)
- Get-CPCServicePlan -ServicePlanName failed. Invoke-CPCResize and Set-CPCProvisioningPolicyAssignment now stop when a service plan name matches no plan or more than one plan (#141)
- Policy assignments sent an already assigned group twice, which Graph rejected (#142)
- New-CPCProvisioningPolicy couldn't create hybrid join policies, and New-CPCProvisioningPolicy and Update-CPCProvisioningPolicy sent an empty join type for an Azure network connection (#135)
- New-CPCAzureNetworkConnection sent the AD password encrypted instead of as plain text (#137)
- New-CPCCustomImage created images without a name (#136)
- Update-CPCOrganizationSetting sent "True"/"False" strings instead of booleans (#140)
- Invoke-CPCPublishCloudApp and Invoke-CPCUnpublishCloudApp could act on another app with a similar name (#134)
- Invoke-CPCEndGracePeriod failed when it asked for confirmation (#138)
- Invoke-CPCRestore and Invoke-CPCReprovision used an outdated endpoint
- Get-CPCRestorePoint returned no restore points (#98)
- Get-CPCGalleryImage -Name filtered on the deprecated offerDisplayName instead of displayName
- Checks on input and lookups now stop the command, also with -ErrorAction SilentlyContinue, so no request is sent (#139, #141)

### Known issues
- Invoke-CPCChangeUserAccountType returns an error from Microsoft Graph (#104)
- Invoke-CPCPowerOn and Invoke-CPCPowerOff are not yet tested against a Frontline Cloud PC (#107)

## 1.0.17 [18-03-2026]
### Breaking Changes
- Set-CPCCloudAppAssignment has been removed. Cloud Apps are made available through the provisioning policy assignment instead

### Added commands
- Invoke-CPCRename: renames a Cloud PC (#51)
- Invoke-CPCResize: resizes a Cloud PC to another service plan (#64)
- Set-CPCCrossRegionDisasterRecovery: configures cross-region disaster recovery on a user settings policy (#49)

### Changes
- Update-CPCUserSettingsPolicy: new -DisableRestartPrompts parameter
- Get-CPCUserSettingsPolicy returns crossRegionDisasterRecoverySetting

### Bugfixes
- Update-CPCUserSettingsPolicy: -LocalAdminEnabled was ignored
- Corrected the help examples of Invoke-CPCPublishCloudApp and Invoke-CPCUnpublishCloudApp

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
