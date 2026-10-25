function Get-CPCRealTimeConnectionStatus {
    <#
    .SYNOPSIS
    Retrieves the real-time remote connection status for a specific Cloud PC
    .DESCRIPTION
    The function retrieves live connection status for a specific Cloud PC using the
    Microsoft Graph beta cloudPcReports getRealTimeRemoteConnectionStatus API.

    Unlike Get-CPCConnectivityHistory (which shows historical events), this function
    returns the current state: whether a user is actively signed in, how long the
    session has been running, and days since last use. Useful for live helpdesk
    troubleshooting and monitoring dashboards.

    You can identify the target Cloud PC by its managed device name (default) or
    by providing the Cloud PC object ID directly via -CloudPCId.
    .PARAMETER Name
    The managed device name of the Cloud PC. Use Get-CloudPC to find Cloud PC names.
    Mutually exclusive with -CloudPCId.
    .PARAMETER CloudPCId
    The object ID (GUID) of the Cloud PC. Use Get-CloudPC to find Cloud PC IDs.
    Mutually exclusive with -Name.
    .EXAMPLE
    Get-CPCRealTimeConnectionStatus -Name "CPC-User-XXXX"
    .EXAMPLE
    Get-CPCRealTimeConnectionStatus -CloudPCId "4b5ad5e0-6a0b-4ffc-818d-36bb23cf4dbd"
    .NOTES
    Requires CloudPC.Read.All or CloudPC.ReadWrite.All permission (delegated or application).
    This function uses the Microsoft Graph beta endpoint.
    API reference: https://learn.microsoft.com/en-us/graph/api/cloudpcreports-getrealtimeremoteconnectionstatus?view=graph-rest-beta
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
            $CloudPC = Get-CloudPC -Name $Name

            if ($null -eq $CloudPC -or @($CloudPC).Count -eq 0) {
                Throw "No Cloud PC found with name '$Name'. Use Get-CloudPC to verify the managed device name."
            }

            $CloudPC = @($CloudPC)[0]
            $targetId = $CloudPC.id
            $targetName = $CloudPC.displayName
        }
        else {
            $targetId = $CloudPCId
            $targetName = $CloudPCId
        }

        # getRealTimeRemoteConnectionStatus is a beta-only OData function on the reports resource
        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/reports/getRealTimeRemoteConnectionStatus(cloudPcId='$targetId')"

        Write-Verbose "URL: $url"
    }

    Process {
        Write-Verbose "Retrieving real-time connection status for Cloud PC '$targetName' (id: $targetId)"

        try {
            $result = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method GET -ContentType "application/json"

            # Graph returns this report as application/octet-stream; parse it when it comes back as text
            if ($result -is [string] -and -not [string]::IsNullOrWhiteSpace($result)) {
                $result = $result | ConvertFrom-Json
            }

            if ($null -eq $result -or $null -eq $result.Values -or @($result.Values).Count -eq 0) {
                Write-Output "No real-time connection status returned for Cloud PC '$targetName'."
                return
            }

            # The report comes back as a table: Schema lists the columns, Values holds one array per row
            $columns = @($result.Schema | ForEach-Object { $_.Column })

            foreach ($row in $result.Values) {
                $values = @($row)
                $entry = [ordered]@{}
                for ($i = 0; $i -lt $columns.Count; $i++) {
                    $entry[$columns[$i]] = if ($i -lt $values.Count) { $values[$i] } else { $null }
                }
                [PSCustomObject]$entry
            }
        }
        catch {
            Throw (Get-GraphErrorMessage $_)
        }
    }
}
