function Remove-CPCMaintenanceWindow {
    <#
    .SYNOPSIS
    Removes a Cloud PC Maintenance Window
    .DESCRIPTION
    The function will remove a Cloud PC Maintenance Window by display name using the Microsoft Graph beta API.
    .PARAMETER Name
    Enter the display name of the Cloud PC Maintenance Window to remove
    .EXAMPLE
    Remove-CPCMaintenanceWindow -Name "Off-Hours Window"
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    Begin {
        Get-TokenValidity

        $MaintenanceWindow = Get-CPCMaintenanceWindow -Name $Name

        if ($null -eq $MaintenanceWindow) {
            Write-Error "No Cloud PC Maintenance Window found with name '$Name'"
            return
        }

        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows/$($MaintenanceWindow.id)"
        Write-Verbose "Delete URL: $url"
    }

    Process {
        if ($PSCmdlet.ShouldProcess($Name, 'Remove Cloud PC Maintenance Window')) {
            try {
                Write-Verbose "Removing Cloud PC Maintenance Window '$Name'"
                Invoke-WebRequest -Uri $url -Method DELETE -Headers $script:authHeader -SkipHttpErrorCheck
            }
            catch {
                Throw $_.Exception.Message
            }
        }
    }
}
