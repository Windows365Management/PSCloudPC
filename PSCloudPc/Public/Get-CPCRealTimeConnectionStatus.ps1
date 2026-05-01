function Get-CPCRealTimeConnectionStatus {
    <#
    .SYNOPSIS
    Retrieves the real-time remote connection status for a specific Cloud PC
    .DESCRIPTION
    The function retrieves live connection status for a specific Cloud PC using the
    Microsoft Graph beta cloudPcReports getRealTimeRemoteConnectionStatus API.

    Unlike Get-CPCConnectivityHistory (which shows historical events), this function
    returns the current state: whether a user is actively signed in and how many days
    have elapsed since last sign-in. Useful for live helpdesk troubleshooting and
    monitoring dashboards.

    The underlying API returns a tabular payload (Schema + Values arrays) with
    Content-Type: application/octet-stream. This function parses that format and
    returns a typed PSCustomObject.

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
    .EXAMPLE
    # Check all Cloud PCs and show only those with active sessions
    Get-CloudPC | ForEach-Object { Get-CPCRealTimeConnectionStatus -CloudPCId $_.id } |
        Where-Object { $_.signInStatus -eq 'SignedIn' }
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

        # getRealTimeRemoteConnectionStatus is a beta-only OData function on the reports resource.
        # The response uses Content-Type: application/octet-stream with a tabular JSON body
        # (TotalRowCount / Schema / Values). Invoke-WebRequest + ConvertFrom-Json is required
        # because Invoke-RestMethod does not auto-parse octet-stream as JSON.
        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/reports/getRealTimeRemoteConnectionStatus(cloudPcId='$targetId')"

        Write-Verbose "URL: $url"
    }

    Process {
        Write-Verbose "Retrieving real-time connection status for Cloud PC '$targetName' (id: $targetId)"

        try {
            $response = Invoke-WebRequest -Uri $url -Method GET -Headers $script:Authheader
            $result   = $response.Content | ConvertFrom-Json
        }
        catch {
            Throw $_.Exception.Message
        }

        if ($null -eq $result -or $result.TotalRowCount -eq 0 -or
            $null -eq $result.Values -or $result.Values.Count -eq 0) {
            Write-Output "No real-time connection status returned for Cloud PC '$targetName'."
            return
        }

        # Build a column-name -> index map from the schema so the output is
        # correct regardless of column ordering in future API versions.
        $colIndex = @{}
        for ($i = 0; $i -lt $result.Schema.Count; $i++) {
            $colIndex[$result.Schema[$i].Column] = $i
        }

        $PSObjectResults = @()
        $result.Values | ForEach-Object {
            $row = $_
            $entry = [PSCustomObject]@{
                CloudPCName         = $targetName
                CloudPCId           = $targetId
                signInStatus        = if ($colIndex.ContainsKey('SignInStatus'))        { $row[$colIndex['SignInStatus']] }        else { $null }
                daysSinceLastSignIn = if ($colIndex.ContainsKey('DaysSinceLastSignIn')) { $row[$colIndex['DaysSinceLastSignIn']] } else { $null }
                managedDeviceName   = if ($colIndex.ContainsKey('ManagedDeviceName'))   { $row[$colIndex['ManagedDeviceName']] }   else { $null }
            }
            $PSObjectResults += $entry
        }

        return $PSObjectResults
    }
}
