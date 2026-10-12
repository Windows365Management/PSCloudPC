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
    by providing the Cloud PC object ID directly via -CloudPCId. -CloudPCId also takes
    Cloud PC objects from the pipeline, such as the output of Get-CloudPC. The name must
    match exactly one Cloud PC.

    The report returns a schema and rows. The function returns one object per row with:
    CloudPCName, CloudPCId, signInStatus, daysSinceLastUse (the DaysSinceLastSignIn column)
    and every report column by its own name, such as ManagedDeviceName, DaysSinceLastSignIn
    and LastActiveTime. When the report has no rows, nothing is returned (use -Verbose to
    see why).

    CloudPCName is the managed device name (the Intune device name) that -Name expects: the
    report's ManagedDeviceName column, or else the managed device name of the Cloud PC that was
    looked up. It is never the display name. It is empty while the Cloud PC is still
    provisioning and for Windows 365 Business Cloud PCs; use the id (CloudPCId) for those.

    A problem with one Cloud PC (a failed lookup or Graph request) is reported as a
    non-terminating error with error id PSCloudPC.CloudPCError, and the command continues
    with the next piped Cloud PC; use -ErrorAction Stop to stop at the first error.
    -ErrorVariable and $Error can also hold the underlying Graph errors.
    .PARAMETER Name
    The managed device name of the Cloud PC. Use Get-CloudPC to find Cloud PC names.
    Mutually exclusive with -CloudPCId.
    .PARAMETER CloudPCId
    The object ID (GUID) of the Cloud PC. Use Get-CloudPC to find Cloud PC IDs.
    Mutually exclusive with -Name. Accepts pipeline input by property name (id or
    CloudPCId), for example from Get-CloudPC.
    .EXAMPLE
    Get-CPCRealTimeConnectionStatus -Name "CPC-User-XXXX"
    .EXAMPLE
    Get-CPCRealTimeConnectionStatus -CloudPCId "00000000-0000-0000-0000-000000000000"
    # Pipeline: Get-CloudPC | Get-CPCRealTimeConnectionStatus | Format-Table CloudPCName, signInStatus
    .NOTES
    Requires CloudPC.Read.All or CloudPC.ReadWrite.All permission (delegated or application).
    This function uses the Microsoft Graph beta endpoint:
    GET /deviceManagement/virtualEndpoint/reports/getRealTimeRemoteConnectionStatus(cloudPcId='{id}')
    The response is a report stream (Content-Type application/octet-stream) with Schema and Values.
    API reference: https://learn.microsoft.com/graph/api/cloudpcreports-getrealtimeremoteconnectionstatus?view=graph-rest-beta
    Name lookup: https://learn.microsoft.com/graph/api/virtualendpoint-list-cloudpcs?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Id', ValueFromPipelineByPropertyName = $true)]
        [Alias("id")]
        [ValidateNotNullOrEmpty()]
        [string]$CloudPCId
    )

    Begin {
        Get-TokenValidity
    }

    Process {
        if ($PSCmdlet.ParameterSetName -eq 'Name') {
            $CloudPC = Resolve-CPCCloudPC -Cmdlet $PSCmdlet -Name $Name
        }
        else {
            $CloudPC = Resolve-CPCCloudPC -Cmdlet $PSCmdlet -CloudPCId $CloudPCId
        }

        # The lookup wrote an error for this Cloud PC; continue with the next pipeline object
        if ($null -eq $CloudPC) {
            return
        }

        $targetId = [string]$CloudPC.id
        $targetName = Get-CPCCloudPCName -CloudPC $CloudPC

        # getRealTimeRemoteConnectionStatus is a beta-only OData function on the reports resource
        $functionId = [uri]::EscapeDataString($targetId.Replace("'", "''"))
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/reports/getRealTimeRemoteConnectionStatus(cloudPcId='$functionId')"

        Write-Verbose "Retrieving real-time connection status for Cloud PC $(Get-CPCCloudPCLabel -CloudPC $CloudPC)"
        Write-Verbose "Request: GET $url"

        try {
            $response = Invoke-WebRequest -Headers $script:Authheader -Uri $url -Method GET -ErrorAction Stop
        }
        catch {
            Write-CPCRequestError -Cmdlet $PSCmdlet -ErrorRecord $_ -Action "Get real-time connection status" -CloudPC $CloudPC
            return
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
