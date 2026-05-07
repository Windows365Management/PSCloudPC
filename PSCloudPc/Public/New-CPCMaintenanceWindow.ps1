function New-CPCMaintenanceWindow {
    <#
    .SYNOPSIS
    Creates a new Cloud PC Maintenance Window
    .DESCRIPTION
    The function will create a new Cloud PC Maintenance Window via the Microsoft Graph beta API.
    A maintenance window defines a recurring time slot (weekday and/or weekend) during which
    scheduled Cloud PC operations such as resizes may be performed with advance notice to users.
    .PARAMETER DisplayName
    The display name of the new maintenance window
    .PARAMETER Description
    Optional description for the maintenance window
    .PARAMETER NotificationLeadTimeInMinutes
    Number of minutes before the maintenance window opens that end users are notified.
    Defaults to 60.
    .PARAMETER WeekdayStartTime
    Start time of the weekday maintenance schedule in HH:MM format (24-hour), e.g. "01:00"
    .PARAMETER WeekdayEndTime
    End time of the weekday maintenance schedule in HH:MM format (24-hour), e.g. "05:00"
    .PARAMETER WeekendStartTime
    Optional start time of the weekend maintenance schedule in HH:MM format (24-hour).
    If omitted, no weekend schedule is created.
    .PARAMETER WeekendEndTime
    Optional end time of the weekend maintenance schedule in HH:MM format (24-hour).
    Required when WeekendStartTime is specified.
    .EXAMPLE
    New-CPCMaintenanceWindow -DisplayName "Off-Hours Window" -WeekdayStartTime "01:00" -WeekdayEndTime "05:00"
    .EXAMPLE
    New-CPCMaintenanceWindow -DisplayName "Extended Window" -Description "Weekday and weekend coverage" -NotificationLeadTimeInMinutes 120 -WeekdayStartTime "02:00" -WeekdayEndTime "06:00" -WeekendStartTime "01:00" -WeekendEndTime "08:00"
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter(Mandatory = $false)]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 1440)]
        [int]$NotificationLeadTimeInMinutes = 60,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\d{2}:\d{2}$')]
        [string]$WeekdayStartTime,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\d{2}:\d{2}$')]
        [string]$WeekdayEndTime,

        [Parameter(Mandatory = $false)]
        [ValidatePattern('^\d{2}:\d{2}$')]
        [string]$WeekendStartTime,

        [Parameter(Mandatory = $false)]
        [ValidatePattern('^\d{2}:\d{2}$')]
        [string]$WeekendEndTime
    )

    Begin {
        Get-TokenValidity

        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/maintenanceWindows"
        Write-Verbose "URL for API request: $url"

        $existing = Get-CPCMaintenanceWindow -Name $DisplayName -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Error "A Cloud PC Maintenance Window with the name '$DisplayName' already exists"
            return
        }
    }

    Process {
        $schedules = @(
            @{
                scheduleType = "weekday"
                startTime    = "$($WeekdayStartTime):00.0000000"
                endTime      = "$($WeekdayEndTime):00.0000000"
            }
        )

        if ($PSBoundParameters.ContainsKey('WeekendStartTime') -and $PSBoundParameters.ContainsKey('WeekendEndTime')) {
            $schedules += @{
                scheduleType = "weekend"
                startTime    = "$($WeekendStartTime):00.0000000"
                endTime      = "$($WeekendEndTime):00.0000000"
            }
        }

        $params = @{
            displayName                   = $DisplayName
            notificationLeadTimeInMinutes = $NotificationLeadTimeInMinutes
            schedules                     = $schedules
        }

        if ($PSBoundParameters.ContainsKey('Description')) {
            $params['description'] = $Description
        }

        $body = $params | ConvertTo-Json -Depth 10
        Write-Verbose "Body: $body"

        if ($PSCmdlet.ShouldProcess($DisplayName, 'New Cloud PC Maintenance Window')) {
            try {
                Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $body
            }
            catch {
                Throw $_.Exception.Message
            }
        }
    }
}
