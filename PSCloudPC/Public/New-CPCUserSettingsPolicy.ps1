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
    .PARAMETER UserRestoreEnabled
    Enable or disable user restore
    .PARAMETER FrequencyInHours
    Set the frequency of restore points in hours
    .EXAMPLE
    New-CPCUserSettingsPolicy -Name "Cloud PC User Settings Policy" -LocalAdminEnabled $true -UserRestoreEnabled $true -FrequencyInHours 6
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        [parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]$Name,
        [Parameter(mandatory = $false)][string]$LocalAdminEnabled = $false,
        [Parameter(mandatory = $false)][string]$UserRestoreEnabled = $true,
        [ValidateSet('4', '6', '12', '16', '24')]$FrequencyInHours = 6
        # TODO: Add SupportsShouldProcess
    )
    
    begin {
        Get-TokenValidity
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/userSettings"

        Write-Verbose "URL: $url"

        $Policy = Get-CPCUserSettingsPolicy -Name $Name -ErrorAction SilentlyContinue

        if ($Policy) {
            Write-Error "Cloud PC User Settings Policy $Name already exists"
            Break
        }

        
    }

    Process {

        $params = @{
            DisplayName         = $Name
            LocalAdminEnabled   = $LocalAdminEnabled
            RestorePointSetting = @{
                UserRestoreEnabled = $UserRestoreEnabled
                FrequencyInHours   = $FrequencyInHours
            }
        } | ConvertTo-Json -Depth 10

        Write-Verbose $params

        try {
            Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $params
        }
        catch {
            Throw $_.Exception.Message
        }
        
    }
}
