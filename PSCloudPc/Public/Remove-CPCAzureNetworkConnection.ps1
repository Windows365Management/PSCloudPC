function Remove-CPCAzureNetworkConnection {
    <#
    .SYNOPSIS
    Removes a Cloud PC Azure Network Connection
    .DESCRIPTION
    The function will remove a Cloud PC Azure Network Connection.
    The name must match the display name of exactly one connection (exact match, not case sensitive).
    If no connection or more than one connection has that name, nothing is removed and the command stops.
    You can't delete an Azure Network Connection that's in use.
    The function asks for confirmation before it removes the connection. In a non-interactive session
    (pwsh -File, a pipeline or a scheduled task) the confirmation prompt fails and nothing is removed,
    so pass -Confirm:$false there.
    .PARAMETER name
    Enter the name of the Cloud PC Azure Network Connection
    .EXAMPLE
    Remove-CPCAzureNetworkConnection -name "Azure Network Connection 01"
    .EXAMPLE
    Remove-CPCAzureNetworkConnection -name "Azure Network Connection 01" -WhatIf
    .EXAMPLE
    Remove-CPCAzureNetworkConnection -name "Azure Network Connection 01" -Confirm:$false

    Removes the connection without asking for confirmation, as needed in scripts and pipelines.
    .NOTES
    Required permission: CloudPC.ReadWrite.All (delegated only; Graph doesn't support application permissions for this delete)
    https://learn.microsoft.com/graph/api/cloudpconpremisesconnection-delete?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/virtualendpoint-list-onpremisesconnections?view=graph-rest-beta
#>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param (
        [parameter(mandatory = $true)][ValidateNotNullOrEmpty()][string]$Name
    )

    Begin {
        Get-TokenValidity

        #Graph's displayName eq filter is case-sensitive, so list all connections and match the name on the client
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/onPremisesConnections?`$select=id,displayName"
        Write-Verbose "Looking up Cloud PC Azure Network Connection '$Name': GET $url"

        try {
            $result = Invoke-APIRequest -uri $url -Token $script:Authtoken -Method GET -ErrorAction Stop
        }
        catch {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message (Get-GraphErrorMessage $_) -Category InvalidOperation
        }

        #Exact match, not case sensitive; a partial name never matches
        $Connection = @($result | Where-Object { $_.displayName -eq $Name })

        if ($Connection.Count -eq 0) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No Cloud PC Azure Network Connection found with name '$Name'. Nothing was removed." -Category ObjectNotFound
        }

        if ($Connection.Count -gt 1) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "$($Connection.Count) Cloud PC Azure Network Connections found with name '$Name' ($($Connection.id -join ', ')). Nothing was removed."
        }

        $ConnectionId = $Connection[0].id
        $ParsedId = [guid]::Empty
        if ($ConnectionId -isnot [string] -or -not [guid]::TryParseExact($ConnectionId, "D", [ref]$ParsedId)) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "The Cloud PC Azure Network Connection '$Name' has no valid id ('$ConnectionId'). Nothing was removed." -Category InvalidData
        }

        $deleteurl = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/onPremisesConnections/$ConnectionId"
    }

    Process {
        if ($PSCmdlet.ShouldProcess("$($Connection[0].displayName) ($ConnectionId)", "Remove Cloud PC Azure Network Connection")) {
            Write-Verbose "Removing Cloud PC Azure Network Connection: DELETE $deleteurl"
            try {
                Invoke-RestMethod -Uri $deleteurl -Method DELETE -Headers $script:Authheader -ErrorAction Stop
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }
        }
    }

}
