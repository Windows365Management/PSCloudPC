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

    crossRegionDisasterRecoveryEnabled is deprecated in the Graph docs, but Graph still rejects
    crossRegion and premium without it, so it is sent as $true for those types and $false for
    notConfigured.

    Only the crossRegionDisasterRecoverySetting of the policy is changed. The restore point
    settings of the policy (frequencyType and userRestoreEnabled) are kept unchanged: their
    current values are sent back as they are. The deprecated frequencyInHours is never sent.

    This function requires the Graph API beta endpoint and the CloudPC.ReadWrite.All permission.
    .PARAMETER Name
    The exact display name of the Cloud PC User Settings Policy to update. The name must match
    exactly one policy.
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
    The cloudPcRegionGroup that the disaster recovery region belongs to (e.g. 'usEast',
    'usWest', 'europeUnion', 'unitedKingdom', 'asia'). Required when DisasterRecoveryType is
    'crossRegion' or 'premium'. The value is passed to Graph as is, so region groups that
    Microsoft adds later work without a module update; Graph rejects an unknown value.
    See https://learn.microsoft.com/graph/api/resources/cloudpcregiongroup?view=graph-rest-beta
    .EXAMPLE
    Set-CPCCrossRegionDisasterRecovery -Name "UserSettings01" -DisasterRecoveryType crossRegion -RegionName "westus" -RegionGroup "usWest" -MaintainCrossRegionRestorePointEnabled $true
    .EXAMPLE
    Set-CPCCrossRegionDisasterRecovery -Name "UserSettings01" -DisasterRecoveryType premium -RegionName "northeurope" -RegionGroup "europeUnion" -MaintainCrossRegionRestorePointEnabled $true -UserInitiatedDisasterRecoveryAllowed $true
    .EXAMPLE
    Set-CPCCrossRegionDisasterRecovery -Name "UserSettings01" -DisasterRecoveryType notConfigured
    .NOTES
    Required permission: CloudPC.ReadWrite.All
    https://learn.microsoft.com/graph/api/cloudpcusersetting-update?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpccrossregiondisasterrecoverysetting?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcregiongroup?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcrestorepointsetting?view=graph-rest-beta
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

        If ($DisasterRecoveryType -in @('crossRegion', 'premium')) {
            If ([string]::IsNullOrWhiteSpace($RegionName) -or [string]::IsNullOrWhiteSpace($RegionGroup)) {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "RegionName and RegionGroup are required when DisasterRecoveryType is '$DisasterRecoveryType'"
            }
        }

        If ($UserInitiatedDisasterRecoveryAllowed -and $DisasterRecoveryType -ne 'premium') {
            Write-Warning "UserInitiatedDisasterRecoveryAllowed is only supported for premium disaster recovery and is sent as false"
        }

        Write-Verbose "Looking up User Settings Policy: $Name"
        $Policy = @(Get-CPCUserSettingsPolicy -Name $Name | Where-Object { $_.displayName -eq $Name })

        If ($Policy.Count -eq 0) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No User Settings Policy found with name '$Name'" -Category ObjectNotFound
        }

        If ($Policy.Count -gt 1) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "$($Policy.Count) User Settings Policies found with name '$Name' ($($Policy.id -join ', ')). The name must match exactly one policy"
        }

        $Policy = $Policy[0]

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/userSettings/$($Policy.id)"
        Write-Verbose "PATCH URL: $url"
    }

    Process {
        $drSetting = @{
            disasterRecoveryType                   = $DisasterRecoveryType
            # Deprecated, but Graph still answers 400 parameterValidationFailed for crossRegion without it
            crossRegionDisasterRecoveryEnabled     = ($DisasterRecoveryType -ne 'notConfigured')
            maintainCrossRegionRestorePointEnabled = $MaintainCrossRegionRestorePointEnabled
            userInitiatedDisasterRecoveryAllowed   = $false
        }

        If ($DisasterRecoveryType -eq 'premium') {
            $drSetting.userInitiatedDisasterRecoveryAllowed = $UserInitiatedDisasterRecoveryAllowed
        }

        If ($DisasterRecoveryType -in @('crossRegion', 'premium')) {
            # Abstract Graph type: name the Microsoft-hosted subtype that regionName/regionGroup belong to
            $drSetting.disasterRecoveryNetworkSetting = @{
                '@odata.type' = '#microsoft.graph.cloudPcDisasterRecoveryMicrosoftHostedNetworkSetting'
                regionName    = $RegionName
                regionGroup   = $RegionGroup
            }
        }

        $body = @{
            crossRegionDisasterRecoverySetting = $drSetting
        }

        # Send the unchanged policy values the update docs list, only when the policy has them
        foreach ($property in 'displayName', 'localAdminEnabled', 'resetEnabled') {
            If ($null -ne $Policy.$property) {
                $body[$property] = $Policy.$property
            }
        }

        # Send the current restore point settings back unchanged, because it is not documented whether
        # PATCH keeps or clears a restorePointSetting that is left out. The deprecated frequencyInHours is never sent.
        # https://learn.microsoft.com/graph/api/resources/cloudpcrestorepointsetting?view=graph-rest-beta
        $restorePointSetting = @{}
        foreach ($property in 'frequencyType', 'userRestoreEnabled') {
            If ($null -ne $Policy.restorePointSetting.$property) {
                $restorePointSetting[$property] = $Policy.restorePointSetting.$property
            }
        }

        If ($restorePointSetting.Count -gt 0) {
            $body.restorePointSetting = $restorePointSetting
        }

        $bodyJson = $body | ConvertTo-Json -Depth 10
        Write-Verbose "Request Body: $bodyJson"

        If ($PSCmdlet.ShouldProcess($Name, "Set Cross-Region Disaster Recovery to $DisasterRecoveryType")) {
            try {
                Invoke-RestMethod -Uri $url -Headers $script:Authheader -Method PATCH -Body $bodyJson -ContentType "application/json"
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }
        }
    }
}
