function Update-CPCUserSettingsPolicy {
    <#
    .SYNOPSIS
    Updates a User Settings Policy in the Intune Cloud PC Service
    .DESCRIPTION
    Updates a User Settings Policy in the Intune Cloud PC Service. Supports updating
    LocalAdminEnabled, ResetEnabled and the restore point configuration.

    Graph replaces the whole policy on an update, so the cmdlet reads the current policy and sends
    every setting back: only the parameters you pass are changed, all other settings (including the
    cross-region disaster recovery settings) are kept. Changes someone else makes to the policy
    between that read and the update are overwritten. The cmdlet returns no output.

    The self-service and restart prompt settings were retired by Microsoft. -SelfServiceEnabled and
    -DisableRestartPrompts only write a warning and are not sent.
    .PARAMETER Name
    Name of the User Settings Policy to update. The name must match exactly one policy.
    .PARAMETER LocalAdminEnabled
    Enable or disable local admin on the Cloud PC. When $true the end user is an admin of the Cloud PC.
    .PARAMETER ResetEnabled
    Allow targeted users to reprovision their Cloud PC from within the Windows 365 app and web app.
    .PARAMETER UserRestoreEnabled
    Enable or disable user-initiated restore from the Cloud PC restore point.
    .PARAMETER UserRestoreFrequency
    Frequency (in hours) at which restore point snapshots are captured. Valid values: 4, 6, 12, 16, 24.
    Sent as the restorePointSetting frequencyType (fourHours, sixHours, twelveHours, sixteenHours, twentyFourHours).
    .PARAMETER DisableRestartPrompts
    Retired: has no effect and writes a warning. Microsoft retired the notificationSetting
    (restartPromptsDisabled) of User Settings Policies on July 14, 2026.
    .PARAMETER SelfServiceEnabled
    Retired: has no effect and writes a warning. Microsoft retired the selfServiceEnabled setting
    of User Settings Policies on December 1, 2023.
    .EXAMPLE
    Update-CPCUserSettingsPolicy -Name "Your Settings Policy" -LocalAdminEnabled $true
    .EXAMPLE
    Update-CPCUserSettingsPolicy -Name "Your Settings Policy" -LocalAdminEnabled $false -ResetEnabled $true -UserRestoreEnabled $true -UserRestoreFrequency 6
    .EXAMPLE
    Update-CPCUserSettingsPolicy -Name "Your Settings Policy" -UserRestoreFrequency 4
    .NOTES
    Required permission: CloudPC.ReadWrite.All
    https://learn.microsoft.com/graph/api/cloudpcusersetting-update?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/cloudpcusersetting-get?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcusersetting?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcrestorepointsetting?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
    param (
        [parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [bool]$LocalAdminEnabled,

        [Parameter(Mandatory = $false)]
        [bool]$ResetEnabled,

        [Parameter(Mandatory = $false)]
        [bool]$UserRestoreEnabled,

        [ValidateSet('4', '6', '12', '16', '24')]
        [Parameter(Mandatory = $false)]
        [string]$UserRestoreFrequency,

        [Parameter(Mandatory = $false)]
        [bool]$DisableRestartPrompts,

        [Parameter(Mandatory = $false)]
        [bool]$SelfServiceEnabled
    )

    Begin {
        Get-TokenValidity

        If ($PSBoundParameters.ContainsKey('SelfServiceEnabled')) {
            Write-Warning "SelfServiceEnabled ($SelfServiceEnabled) was retired by Microsoft on December 1, 2023 and has no effect. It is not sent."
        }

        If ($PSBoundParameters.ContainsKey('DisableRestartPrompts')) {
            Write-Warning "DisableRestartPrompts ($DisableRestartPrompts) was retired by Microsoft on July 14, 2026 and has no effect. It is not sent."
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

        Write-Verbose "Update url: $($url)"
    }

    Process {

        # PATCH replaces the whole policy and resets every setting that is left out,
        # so read the current settings and change only the passed parameters
        try {
            $params = Get-CPCUserSettingBody -Id $Policy.id -ErrorAction Stop
        }
        catch {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message (Get-GraphErrorMessage $_) -Category InvalidOperation
        }

        If ($PSBoundParameters.ContainsKey('LocalAdminEnabled')) {
            $params['localAdminEnabled'] = $LocalAdminEnabled
        }

        If ($PSBoundParameters.ContainsKey('ResetEnabled')) {
            $params['resetEnabled'] = $ResetEnabled
        }

        If ($PSBoundParameters.ContainsKey('UserRestoreEnabled') -or $PSBoundParameters.ContainsKey('UserRestoreFrequency')) {
            If (-not $params.ContainsKey('restorePointSetting')) {
                $params['restorePointSetting'] = @{}
            }

            If ($PSBoundParameters.ContainsKey('UserRestoreEnabled')) {
                $params['restorePointSetting']['userRestoreEnabled'] = $UserRestoreEnabled
            }

            If ($PSBoundParameters.ContainsKey('UserRestoreFrequency')) {
                # frequencyType replaces the deprecated frequencyInHours
                $params['restorePointSetting']['frequencyType'] = ConvertTo-CPCRestorePointFrequencyType -FrequencyInHours $UserRestoreFrequency
            }
        }

        $body = $params | ConvertTo-Json -Depth 10

        Write-Verbose "Request body: $body"

        If ($PSCmdlet.ShouldProcess($Name, 'Update Cloud PC User Settings Policy')) {
            try {
                Write-Verbose "Updating User Settings Policy $($Name)"
                # Graph returns 204 No Content; nothing is written to the output
                $null = Invoke-RestMethod -Uri $url -Method PATCH -Headers $script:Authheader -Body $body -ContentType "application/json" -ErrorAction Stop
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }
        }
    }
}
