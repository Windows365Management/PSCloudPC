function Set-CPCCrossRegionDisasterRecovery {
    <#
    .SYNOPSIS
    Configures cross-region disaster recovery settings on a Cloud PC User Settings Policy
    .DESCRIPTION
    The function configures cross-region disaster recovery settings on an existing Cloud PC
    User Settings Policy. Disaster recovery ensures Cloud PCs can be provisioned in an
    alternate Azure region when the primary region is unavailable.

    Supported disaster recovery types:
    - notConfigured : Disaster recovery is disabled (default)
    - crossRegion   : Cross-region DR — Windows 365 provisions a standby Cloud PC in the
                      specified backup region automatically
    - premium       : Premium DR — adds user-initiated failover capability on top of
                      cross-region standby

    This function requires the Graph API beta endpoint and the CloudPC.ReadWrite.All permission.
    .PARAMETER Name
    The display name of the Cloud PC User Settings Policy to update.
    .PARAMETER DisasterRecoveryType
    The disaster recovery mode to configure. Valid values: notConfigured, crossRegion, premium.
    .PARAMETER MaintainCrossRegionRestorePointEnabled
    When $true, Windows 365 continuously maintains cross-region restore points that can be
    used during failover. When $false (default), only the initial provisioning image is
    available after a disaster, which may result in data loss.
    .PARAMETER UserInitiatedDisasterRecoveryAllowed
    When $true, end users can activate disaster recovery themselves from the Windows 365
    portal. Only applicable when DisasterRecoveryType is 'premium'. Default is $false.
    .PARAMETER RegionName
    The Azure region name to use as the disaster recovery target (e.g. 'westus',
    'northeurope', 'eastasia'). Required when DisasterRecoveryType is 'crossRegion' or
    'premium'.
    .PARAMETER RegionGroup
    The region group for disaster recovery routing (e.g. 'usEast', 'usWest',
    'europeNorth', 'europeWest', 'asiaPacific'). Required when DisasterRecoveryType is
    'crossRegion' or 'premium'.
    .EXAMPLE
    Set-CPCCrossRegionDisasterRecovery -Name "UserSettings01" -DisasterRecoveryType crossRegion -RegionName "westus" -RegionGroup "usWest" -MaintainCrossRegionRestorePointEnabled $true
    .EXAMPLE
    Set-CPCCrossRegionDisasterRecovery -Name "UserSettings01" -DisasterRecoveryType premium -RegionName "northeurope" -RegionGroup "europeNorth" -MaintainCrossRegionRestorePointEnabled $true -UserInitiatedDisasterRecoveryAllowed $true
    .EXAMPLE
    Set-CPCCrossRegionDisasterRecovery -Name "UserSettings01" -DisasterRecoveryType notConfigured
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet('notConfigured', 'crossRegion', 'premium')]
        [string]$DisasterRecoveryType,

        [Parameter(Mandatory = $false)]
        [bool]$MaintainCrossRegionRestorePointEnabled = $false,

        [Parameter(Mandatory = $false)]
        [bool]$UserInitiatedDisasterRecoveryAllowed = $false,

        [Parameter(Mandatory = $false)]
        [string]$RegionName,

        [Parameter(Mandatory = $false)]
        [string]$RegionGroup
    )

    begin {
        Get-TokenValidity

        Write-Verbose "Looking up User Settings Policy: $Name"
        $Policy = Get-CPCUserSettingsPolicy -Name $Name

        If ($null -eq $Policy) {
            Throw "No User Settings Policy found with name '$Name'"
            return
        }

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/userSettings/$($Policy.id)"
        Write-Verbose "PATCH URL: $url"
    }

    Process {
        $body = @{
            displayName                        = $Policy.displayName
            localAdminEnabled                  = $Policy.localAdminEnabled
            selfServiceEnabled                 = $Policy.selfServiceEnabled
            resetEnabled                       = $Policy.resetEnabled
            restorePointSetting                = @{
                userRestoreEnabled = $Policy.restorePointSetting.userRestoreEnabled
                frequencyInHours   = $Policy.restorePointSetting.frequencyInHours
            }
            notificationSetting                = @{
                restartPromptsDisabled = $Policy.notificationSetting.restartPromptsDisabled
            }
            crossRegionDisasterRecoverySetting = @{}
        }

        If ($DisasterRecoveryType -eq 'crossRegion') {
            $body.crossRegionDisasterRecoverySetting = @{
                crossRegionDisasterRecoveryEnabled       = $true
                disasterRecoveryType                     = $DisasterRecoveryType
                maintainCrossRegionRestorePointEnabled   = $MaintainCrossRegionRestorePointEnabled
                userInitiatedDisasterRecoveryAllowed     = $false
                disasterRecoveryNetworkSetting = @{
                    regionName  = $RegionName
                    regionGroup = $RegionGroup
                }
            }
        }

        If ($DisasterRecoveryType -eq 'premium') {
            $body.crossRegionDisasterRecoverySetting = @{
                crossRegionDisasterRecoveryEnabled       = $false
                disasterRecoveryType                     = $DisasterRecoveryType
                maintainCrossRegionRestorePointEnabled   = $MaintainCrossRegionRestorePointEnabled
                userInitiatedDisasterRecoveryAllowed     = $UserInitiatedDisasterRecoveryAllowed
                disasterRecoveryNetworkSetting = @{
                    regionName  = $RegionName
                    regionGroup = $RegionGroup
                }
            }
        }

        $bodyJson = $body | ConvertTo-Json -Depth 10
        Write-Verbose "Request Body: $bodyJson"

        If ($PSCmdlet.ShouldProcess($Name, "Set Cross-Region Disaster Recovery")) {
            Invoke-RestMethod -Uri $url -Headers $script:AuthHeader -Method PATCH -Body $bodyJson -ContentType "application/json"
        }
    }
}
