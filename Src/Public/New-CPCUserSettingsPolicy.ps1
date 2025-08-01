function New-CPCUserSettingsPolicy {
    <#
    .SYNOPSIS
    Creates new Cloud PC User Settings Policy
    .DESCRIPTION
    The function will create a new Cloud PC User Settings Policy
    .PARAMETER DisplayName
    Enter the Cloud PC User Settings Policy display name
    .PARAMETER LocalAdminEnabled
    Enable or disable local admin permissions
    .PARAMETER ResetEnabled
    Allow targeted users to reprovision their Cloud PC from within the Windows 365 app and web app
    .PARAMETER UserRestoreEnabled
    Enable or disable user restore
    .PARAMETER FrequencyInHours
    Set the frequency of restore points in hours
    .EXAMPLE
    New-CPCUserSettingsPolicy -Name "Cloud PC User Settings Policy" -LocalAdminEnabled $true -ResetEnabled $true -UserRestoreEnabled $true -FrequencyInHours 6
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
    param (
        [parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]$Name,
        [Parameter(mandatory = $false)][bool]$LocalAdminEnabled = $false,
        [Parameter(mandatory = $false)][bool]$ResetEnabled = $false,
        [Parameter(mandatory = $false)][bool]$UserRestoreEnabled = $false,
        [ValidateSet('4', '6', '12', '16', '24')]$FrequencyInHours = 6
    )
    
    begin {
        Get-TokenValidity
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/userSettings"
        Write-Verbose "URL for API request: $url"
        
        Write-Verbose "Checking existence of Cloud PC User Settings Policy: $Name"
        $Policy = Get-CPCUserSettingsPolicy -Name $Name -ErrorAction SilentlyContinue 

        if ($Policy) {
            Write-Verbose "Cloud PC User Settings Policy $Name already exists. Aborting operation."
            Write-Error "Cloud PC User Settings Policy $Name already exists"
            Break
        }
        Write-Verbose "Cloud PC User Settings Policy $Name does not exist. Proceeding with creation."
        
    }

    Process {

        $params = @{
            DisplayName         = $Name
            LocalAdminEnabled   = $LocalAdminEnabled
            resetEnabled        = $ResetEnabled
            RestorePointSetting = @{
                UserRestoreEnabled = $UserRestoreEnabled
                FrequencyInHours   = $FrequencyInHours
            }
        } | ConvertTo-Json -Depth 10

        Write-Verbose "Parameters for new Cloud PC User Settings Policy: $params"
        if ($PSCmdlet.ShouldProcess($Name, 'New Cloud PC User Settings Policy')) {
            Write-Verbose "Creating new Cloud PC User Settings Policy: $Name"
            try {
                Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $params
            }
            catch {
                Throw $_.Exception.Message
            }
        }
        
    }
}
