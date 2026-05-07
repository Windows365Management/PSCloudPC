function Get-CPCMaintenanceWindow {
    <#
    .SYNOPSIS
    Returns Cloud PC Maintenance Windows
    .DESCRIPTION
    The function will return all Cloud PC Maintenance Windows or a specific one filtered by display name.
    Maintenance windows define scheduled time slots during which Cloud PC resize and other operations
    may run to minimise disruption to end users.
    .PARAMETER Name
    Enter the display name of the Cloud PC Maintenance Window to retrieve
    .EXAMPLE
    Get-CPCMaintenanceWindow
    .EXAMPLE
    Get-CPCMaintenanceWindow -Name "Business Hours Window"
    #>
    [CmdletBinding()]
    param (
        [parameter(ParameterSetName = "Name")]
        [string]$Name
    )

    Begin {
        Get-TokenValidity

        switch ($PsCmdlet.ParameterSetName) {
            Name {
                Write-Verbose "Name parameter provided"
                $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows?`$filter=displayName+eq+'$($Name)'"
            }
            default {
                $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows"
            }
        }
    }

    Process {
        Write-Verbose $url
        $result = Invoke-WebRequest -Uri $url -Method GET -Headers $script:authHeader -SkipHttpErrorCheck

        if ($null -eq $result) {
            Write-Error "No Maintenance Windows returned"
            return
        }

        $resultnew = $result.Content | ConvertFrom-Json
        $returnResults = @()
        $resultnew.value | ForEach-Object {

            $Info = [PSCustomObject]@{
                id                            = $_.id
                displayName                   = $_.displayName
                description                   = $_.description
                notificationLeadTimeInMinutes = $_.notificationLeadTimeInMinutes
                schedules                     = $_.schedules
            }
            $returnResults += $Info
        }
        return $returnResults
    }
}
