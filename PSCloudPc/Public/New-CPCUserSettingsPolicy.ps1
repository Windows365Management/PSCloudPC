function New-CPCUserSettingsPolicy {
    <#
    .SYNOPSIS
    Creates new Cloud PC User Settings Policy
    .DESCRIPTION
    The function will create a new Cloud PC User Settings Policy
    .PARAMETER Name
    Enter the Cloud PC User Settings Policy display name
    .PARAMETER LocalAdminEnabled
    Enable or disable local admin permissions
    .PARAMETER ResetEnabled
    Allow targeted users to reprovision their Cloud PC from within the Windows 365 app and web app
    .PARAMETER UserRestoreEnabled
    Enable or disable user restore
    .PARAMETER FrequencyInHours
    Set the frequency of restore points in hours. Valid values: 4, 6, 12, 16, 24 (Default: 6).
    Sent as the restorePointSetting frequencyType (fourHours, sixHours, twelveHours, sixteenHours, twentyFourHours).
    .EXAMPLE
    New-CPCUserSettingsPolicy -Name "Cloud PC User Settings Policy" -LocalAdminEnabled $true -ResetEnabled $true -UserRestoreEnabled $true -FrequencyInHours 6
    .NOTES
    Required permission: CloudPC.ReadWrite.All
    https://learn.microsoft.com/graph/api/virtualendpoint-post-usersettings?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcrestorepointsetting?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
    param (
        [parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]$Name,
        [Parameter(mandatory = $false)][bool]$LocalAdminEnabled = $false,
        [Parameter(mandatory = $false)][bool]$ResetEnabled = $false,
        [Parameter(mandatory = $false)][bool]$UserRestoreEnabled = $false,
        [ValidateSet('4', '6', '12', '16', '24')]
        [string]$FrequencyInHours = '6'
    )
    
    begin {
        Get-TokenValidity
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/userSettings"
        Write-Verbose "URL for API request: $url"
        
        Write-Verbose "Checking existence of Cloud PC User Settings Policy: $Name"
        $Policy = Get-CPCUserSettingsPolicy -Name $Name -ErrorAction SilentlyContinue 

        if ($Policy) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Cloud PC User Settings Policy $Name already exists" -Category ResourceExists
        }
        Write-Verbose "Cloud PC User Settings Policy $Name does not exist. Proceeding with creation."
        
    }

    Process {

        # frequencyType replaces the deprecated frequencyInHours, which stopped returning data on January 31, 2024
        $params = @{
            displayName         = $Name
            localAdminEnabled   = $LocalAdminEnabled
            resetEnabled        = $ResetEnabled
            restorePointSetting = @{
                userRestoreEnabled = $UserRestoreEnabled
                frequencyType      = ConvertTo-CPCRestorePointFrequencyType -FrequencyInHours $FrequencyInHours
            }
        } | ConvertTo-Json -Depth 10

        Write-Verbose "Parameters for new Cloud PC User Settings Policy: $params"
        if ($PSCmdlet.ShouldProcess($Name, 'New Cloud PC User Settings Policy')) {
            Write-Verbose "Creating new Cloud PC User Settings Policy: $Name"
            try {
                Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $params
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }
        }
        
    }
}
