# Changelog
This file contains all the changes to this Windows 365 PowerShell module.

## Unreleased
### Breaking Changes
- New-CPCProvisioningPolicy returns the created policy and needs either -RegionName/-RegionGroup or -AzureNetworkConnection (before, a policy without a network was sent); -DomainJoinType is no longer mandatory and with -AzureNetworkConnection the join type follows the connectionType of the connection
- Set-CPCProvisioningPolicyAssignment and Set-CPCUserSettingsPolicyAssignment: -GroupName is mandatory and the group name must match exactly one Entra ID group
- New-CPCCustomImage: -Name is mandatory; an image with the same name but another version is allowed (name and version together identify an image)
- Get-CPCRemoteActionResult returns `statusDetail` (the deprecated `statusDetails` is used as a fallback)
- Get-CPCRealTimeConnectionStatus returns one object per row with the report columns (CloudPcId, ManagedDeviceName, SignInStatus, DaysSinceLastSignIn) instead of the raw `Values` arrays
- Invoke-CPCEndGracePeriod uses SupportsShouldProcess (-WhatIf/-Confirm) instead of a Read-Host prompt; -Force still skips the confirmation
- Disconnect-Windows365 honours -WhatIf

### Bugfixes
- New-CPCProvisioningPolicy and Update-CPCProvisioningPolicy sent `type: null` in domainJoinConfigurations for an Azure Network Connection, because the `type` property of cloudPcOnPremisesConnection stopped returning data on January 31, 2024. The join type is now read from `connectionType` and sent as `domainJoinType`. Connections with healthCheckStatus `warning` or `informational` are accepted (only `passed` was). The unknown top-level property `userSettingsPersistenceEnabled` and the deprecated `microsoftManagedDesktop.type` are no longer sent; -WindowsAutopatchGroupId is required for `starterManaged`
- Update-CPCProvisioningPolicy sent an empty `imageType` when only -ImageId was passed (rejected by Graph); the current image type of the policy is kept. The error text for a missing policy said "User Settings Policy"
- Update-CPCAzureNetworkConnection sent the DPAPI/AES encrypted SecureString instead of the plain text domain join password
- New-CPCAzureNetworkConnection sends `connectionType` instead of the deprecated `type`, no longer sends the read-only `subscriptionName` (was always null) and no longer writes the domain password to the verbose stream; -OrganizationalUnit is optional
- Get-CPCAzureNetworkConnection returns `connectionType` (`type` is kept and holds the same value), `inUse`, `healthCheckPaused` and `managedBy`, and follows every page
- Import-CPCProvisioningPolicy did nothing with policies exported after January 2024, because it read the deprecated `domainJoinConfigurations[].type` and `windowsSettings.language`; it reads `domainJoinType` and `windowsSetting.locale` (with fallbacks for older exports), resolves the exported connection ids to connection names, imports description, provisioning type, user experience and Autopatch settings and stops with a clear error for an invalid file
- Export-CPCProvisioningPolicy built the file path with a backslash (a literal `C:\Temp\x.json` file on macOS/Linux); it uses Join-Path, checks that the output folder exists and returns the file
- New-CPCUserSettingsPolicy sends `restorePointSetting.frequencyType` instead of the deprecated `frequencyInHours` (stopped returning data on January 31, 2024)
- Get-CPCProvisioningPolicy returns `windowsSetting` (the deprecated `windowsSettings` stopped returning data), description, managedBy, localAdminEnabled, microsoftManagedDesktop, autopatch and gracePeriodInHours, and follows every page
- Get-CPCGalleryImage returns `displayName`, `publisherName`, `offerName`, `skuName`, `startDate`, `expirationDate`, `osVersionNumber` and `sizeInGB`; `offerDisplayName`, `skuDisplayName` and `recommendedSku` are deprecated and stop returning data on December 7, 2026
- Get-CPCAuditEvent only returned the first page when -Top was not passed; it now follows every page. Get-CloudApp, Get-CPCCustomImage, Get-CPCSupportedRegion and Get-CloudPC follow every page as well and return more properties
- Invoke-CPCReboot, Invoke-CPCRename, Invoke-CPCTroubleshoot, Invoke-CPCCreateSnapshot, Invoke-CPCResize, Invoke-CPCRestore, Invoke-CPCReprovision and Get-CPCRestorePoint continued with an empty Cloud PC id (POST cloudPCs//action) when the Cloud PC was not found; they now stop with a terminating error, also with -ErrorAction SilentlyContinue. Invoke-CPCReboot has error handling and -WhatIf; Invoke-CPCRename has -WhatIf
- Invoke-CPCRestore stops with a clear message when Out-GridView is not available (macOS/Linux) and -SnapshotId is not passed
- Set-CPCProvisioningPolicyAssignment and Set-CPCUserSettingsPolicyAssignment sent an array of group ids when several groups shared a display name; the group lookup now returns one id and stops when the name is ambiguous. Set-CPCUserSettingsPolicyAssignment supports -WhatIf
- Names passed to -Name parameters are escaped in the OData `$filter` (a name with a single quote no longer breaks the request)
- `break` statements in begin blocks (which could silently stop the calling script) were replaced by terminating errors
- Get-CPCServicePlan no longer sends an unsupported `$filter`, pages through all service plans, matches -ServicePlanName exactly (case-insensitive) on the client and returns provisioningType; an empty -ServicePlanName is rejected instead of returning all plans (#141)
- Invoke-CPCResize and Set-CPCProvisioningPolicyAssignment stop when a service plan name matches zero or more than one plan; shared provisioning types require -ServicePlanName, and an empty -ServicePlanName is rejected (#141)
- Set-CPCCrossRegionDisasterRecovery sends disasterRecoveryType for every type (including notConfigured), sends the deprecated crossRegionDisasterRecoveryEnabled only because Graph still requires it ($true for crossRegion and premium, $false for notConfigured), no longer sends selfServiceEnabled, notificationSetting or restorePointSetting.frequencyInHours, keeps the restore point settings (frequencyType, userRestoreEnabled) unchanged, requires -RegionName and -RegionGroup for crossRegion/premium (any region group is passed to Graph, so new ones work without a module update) and stops when the policy name matches zero or more than one policy (#139)
- Set-CPCCrossRegionDisasterRecovery, Invoke-CPCResize and Set-CPCProvisioningPolicyAssignment now stop with a terminating error when a lookup or input check fails, also with -ErrorAction SilentlyContinue, so no request is sent (#139, #141)

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
