function Update-CPCUserSettingsPolicy {
    <#
    .SYNOPSIS
    Updates a User Settings Policy in the Intune Cloud PC Service
    .DESCRIPTION
    Updates a User Settings Policy in the Intune Cloud PC Service. Supports updating
    LocalAdminEnabled, ResetEnabled, NotificationSetting, and restore point configuration.
    .PARAMETER Name
    Name of the User Settings Policy to update
    .PARAMETER LocalAdminEnabled
    Enable or disable local admin on the Cloud PC. When $true the end user is an admin of the Cloud PC.
    .PARAMETER ResetEnabled
    Allow targeted users to reprovision their Cloud PC from within the Windows 365 app and web app.
    .PARAMETER UserRestoreEnabled
    Enable or disable user-initiated restore from the Cloud PC restore point.
    .PARAMETER UserRestoreFrequency
    Frequency (in hours) at which restore point snapshots are captured. Valid values: 4, 6, 12, 16, 24.
    .PARAMETER DisableRestartPrompts
    When $true, disables the restart prompts shown to the user on the Cloud PC (notificationSetting).
    .EXAMPLE
    Update-CPCUserSettingsPolicy -Name "Your Settings Policy" -LocalAdminEnabled $true
    .EXAMPLE
    Update-CPCUserSettingsPolicy -Name "Your Settings Policy" -LocalAdminEnabled $false -ResetEnabled $true -UserRestoreEnabled $true -UserRestoreFrequency 6
    .EXAMPLE
    Update-CPCUserSettingsPolicy -Name "Your Settings Policy" -DisableRestartPrompts $true
    .NOTES
    API reference: https://learn.microsoft.com/en-us/graph/api/cloudpcusersetting-update
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
        [bool]$DisableRestartPrompts
    )

    Begin {
        Get-TokenValidity

        $Policy = Get-CPCUserSettingsPolicy -name $Name

        If ($null -eq $Policy) {
            Throw "No User Settings Policy found with name $Name"
            return
        }

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/userSettings/$($Policy.id)"

        Write-Verbose "Update url: $($url)"
    }

    Process {

        $params = @{
            displayName = $Policy.displayName
        }

        If ($PSBoundParameters.ContainsKey('LocalAdminEnabled')) {
            $params['localAdminEnabled'] = $LocalAdminEnabled
        }

        If ($PSBoundParameters.ContainsKey('ResetEnabled')) {
            $params['resetEnabled'] = $ResetEnabled
        }

        If ($PSBoundParameters.ContainsKey('UserRestoreEnabled') -or $PSBoundParameters.ContainsKey('UserRestoreFrequency')) {
            $restorePointSetting = @{}

            If ($PSBoundParameters.ContainsKey('UserRestoreEnabled')) {
                $restorePointSetting['userRestoreEnabled'] = $UserRestoreEnabled
            }

            If ($PSBoundParameters.ContainsKey('UserRestoreFrequency')) {
                $restorePointSetting['frequencyInHours'] = [int]$UserRestoreFrequency
            }

            $params['restorePointSetting'] = $restorePointSetting
        }

        If ($PSBoundParameters.ContainsKey('DisableRestartPrompts')) {
            $params['notificationSetting'] = @{
                restartPromptsDisabled = $DisableRestartPrompts
            }
        }

        Write-Verbose "Params: $($params | ConvertTo-Json -Depth 10)"

        $body = $params | ConvertTo-Json -Depth 10

        If ($PSCmdlet.ShouldProcess($Name, 'Update Cloud PC User Settings Policy')) {
            try {
                Write-Verbose "Updating User Settings Policy $($Name)"
                $Result = Invoke-WebRequest -Uri $url -Method PATCH -Headers $script:authHeader -Body $body -ContentType "application/json" -SkipHttpErrorCheck
                Write-Verbose "Result: $($Result.Content)"
                return $Result
            }
            catch {
                Throw $_.Exception.Message
            }
        }
    }
}
