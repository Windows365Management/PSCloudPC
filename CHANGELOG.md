# Changelog
This file contains all the changes to this Windows 365 PowerShell module.
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
