function Get-CPCRealTimeConnectionStatus {
    <#
    .SYNOPSIS
    Retrieves the real-time remote connection status for a specific Cloud PC
    .DESCRIPTION
    The function retrieves live connection status for a specific Cloud PC using the
    Microsoft Graph beta cloudPcReports getRealTimeRemoteConnectionStatus API.

    Unlike Get-CPCConnectivityHistory (which shows historical events), this function
    returns the current state: whether a user is signed in, the days since the last
    sign-in and the last active time. Useful for live helpdesk troubleshooting and
    monitoring dashboards.

    You can identify the target Cloud PC by its managed device name (default) or
    by providing the Cloud PC object ID directly via -CloudPCId.

    The report returns a schema and rows. The function returns one object per row with:
    CloudPCName (the managed device name from the report, else the managed device name found
    for -Name; empty when neither has one, never the display name), CloudPCId, signInStatus, daysSinceLastUse
    (the DaysSinceLastSignIn column) and every report column by its own name, such as
    ManagedDeviceName, DaysSinceLastSignIn and LastActiveTime. When the report has no
    rows, nothing is returned (use -Verbose to see why).
    .PARAMETER Name
    The managed device name of the Cloud PC. Use Get-CloudPC to find Cloud PC names.
    Mutually exclusive with -CloudPCId.
    .PARAMETER CloudPCId
    The object ID (GUID) of the Cloud PC. Use Get-CloudPC to find Cloud PC IDs.
    Mutually exclusive with -Name.
    .EXAMPLE
    Get-CPCRealTimeConnectionStatus -Name "CPC-User-XXXX"
    .EXAMPLE
    Get-CPCRealTimeConnectionStatus -CloudPCId "00000000-0000-0000-0000-000000000000"
    .NOTES
    Requires CloudPC.Read.All or CloudPC.ReadWrite.All permission (delegated or application).
    This function uses the Microsoft Graph beta endpoint. The response is a report stream
    (Content-Type application/octet-stream) with Schema and Values.
    API reference: https://learn.microsoft.com/graph/api/cloudpcreports-getrealtimeremoteconnectionstatus?view=graph-rest-beta
    Name lookup: https://learn.microsoft.com/graph/api/virtualendpoint-list-cloudpcs?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Id')]
        [ValidateNotNullOrEmpty()]
        [string]$CloudPCId
    )

    Begin {
        Get-TokenValidity

        if ($PSCmdlet.ParameterSetName -eq 'Name') {
            $filterName = [uri]::EscapeDataString($Name.Replace("'", "''"))
            $lookupUrl = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs?`$filter=managedDeviceName+eq+'$filterName'"
            $CloudPC = @(Invoke-APIRequest -uri $lookupUrl -Token $script:Authtoken -Method GET)

            if ($CloudPC.Count -eq 0) {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No Cloud PC found with managed device name '$Name'. Use Get-CloudPC to verify the managed device name." -Category ObjectNotFound
            }

            if ($CloudPC.Count -gt 1) {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "$($CloudPC.Count) Cloud PCs found with managed device name '$Name' ($($CloudPC.id -join ', ')). Use -CloudPCId to select one."
            }

            $targetId = [string]$CloudPC[0].id
            $targetName = $CloudPC[0].managedDeviceName
        }
        else {
            $targetId = $CloudPCId
            $targetName = $null
        }

        # getRealTimeRemoteConnectionStatus is a beta-only OData function on the reports resource
        $functionId = [uri]::EscapeDataString($targetId.Replace("'", "''"))
        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/reports/getRealTimeRemoteConnectionStatus(cloudPcId='$functionId')"
    }

    Process {
        Write-Verbose "Retrieving real-time connection status for Cloud PC id $targetId"
        Write-Verbose "Request: GET $url"

        try {
            $response = Invoke-WebRequest -Headers $script:Authheader -Uri $url -Method GET -ErrorAction Stop
        }
        catch {
            Throw (Get-GraphErrorMessage $_)
        }

        # The report is returned as application/octet-stream, so Content can be a byte array
        $content = $response.Content
        if ($content -is [byte[]]) {
            $content = [System.Text.Encoding]::UTF8.GetString($content)
        }
        $content = ([string]$content).TrimStart([char]0xFEFF)

        if ([string]::IsNullOrWhiteSpace($content)) {
            Write-Verbose "No real-time connection status returned for Cloud PC id $targetId."
            return
        }

        $report = $content | ConvertFrom-Json
        $columns = @($report.Schema | ForEach-Object { $_.Column })
        $rows = @()
        if ($null -ne $report.Values) {
            $rows = @($report.Values)
        }

        if ($rows.Count -eq 0) {
            Write-Verbose "The real-time connection status report has no rows for Cloud PC id $targetId (TotalRowCount: $($report.TotalRowCount))."
            return
        }

        foreach ($row in $rows) {
            $row = @($row)
            $reportValues = [ordered]@{}
            for ($i = 0; $i -lt $columns.Count; $i++) {
                $reportValues[$columns[$i]] = $row[$i]
            }

            # CloudPCName is the managed device name only (report column, else the looked-up Cloud PC's), never the displayName
            $cloudPcName = $null
            if ($reportValues.Contains("ManagedDeviceName") -and -not [string]::IsNullOrWhiteSpace($reportValues["ManagedDeviceName"])) {
                $cloudPcName = $reportValues["ManagedDeviceName"]
            }
            elseif (-not [string]::IsNullOrWhiteSpace($targetName)) {
                $cloudPcName = $targetName
            }

            $reportCloudPcId = $targetId
            if ($reportValues.Contains("CloudPcId") -and -not [string]::IsNullOrEmpty($reportValues["CloudPcId"])) {
                $reportCloudPcId = $reportValues["CloudPcId"]
            }

            $output = [ordered]@{
                CloudPCName      = $cloudPcName
                CloudPCId        = $reportCloudPcId
                signInStatus     = $reportValues["SignInStatus"]
                daysSinceLastUse = $reportValues["DaysSinceLastSignIn"]
            }

            # Add every report column by its own name (CloudPcId and SignInStatus are already present)
            foreach ($column in $columns) {
                if (-not $output.Contains($column)) {
                    $output[$column] = $reportValues[$column]
                }
            }

            [PSCustomObject]$output
        }
    }
}
