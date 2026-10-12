function Get-CPCAzureNetworkConnection {
    <#
    .SYNOPSIS
    Returns all Azure Network Connections or a specific Azure Network Connection
    .DESCRIPTION
    Returns all Azure Network Connections or a specific Azure Network Connection.
    -Name is an exact, case-insensitive match on the display name.
    The join type is returned in connectionType. The type property is kept for compatibility, but
    Graph stopped returning data for it on January 31, 2024.
    .PARAMETER Name
    Exact name of the Azure Network Connection to return
    .EXAMPLE
    Get-CPCAzureNetworkConnection
    .EXAMPLE
    Get-CPCAzureNetworkConnection -Name "Your Azure Network Connection"
    .NOTES
    Required permission: CloudPC.Read.All
    https://learn.microsoft.com/graph/api/virtualendpoint-list-onpremisesconnections?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpconpremisesconnection?view=graph-rest-beta
#>
    [CmdletBinding()]
    param (
        [parameter(ParameterSetName = "DisplayName")]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    Begin {
        Get-TokenValidity
        # Check the bound parameter instead of the parameter set: with a single named parameter set,
        # PowerShell can report that set even when -Name isn't passed
        $filterByName = $PSBoundParameters.ContainsKey("Name")
        if ($filterByName) {
            Write-Verbose "DisplayName parameter provided"
            $filterName = [uri]::EscapeDataString($Name.Replace("'", "''"))
            $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/onPremisesConnections?`$filter=displayName+eq+'$filterName'"
        }
        else {
            $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/onPremisesConnections"
        }
    }

    Process {
        write-verbose $url
        try {
            $result = Invoke-APIRequest -uri $url -Token $script:Authtoken -Method GET
        }
        catch {
            Throw (Get-GraphErrorMessage $_)
        }

        # foreach skips an empty result; piping $null to ForEach-Object would output one empty object
        foreach ($connection in $result) {
            # Exact, case-insensitive match on the client as well
            if ($filterByName -and $connection.displayName -ne $Name) {
                continue
            }

            [PSCustomObject]@{
                id                     = $connection.id
                displayName            = $connection.displayName
                subscriptionId         = $connection.subscriptionId
                type                   = $connection.type
                subscriptionName       = $connection.subscriptionName
                adDomainName           = $connection.adDomainName
                adDomainUsername       = $connection.adDomainUsername
                organizationalUnit     = $connection.organizationalUnit
                resourceGroupId        = $connection.resourceGroupId
                virtualNetworkLocation = $connection.virtualNetworkLocation
                virtualNetworkId       = $connection.virtualNetworkId
                subnetId               = $connection.subnetId
                healthCheckStatus      = $connection.healthCheckStatus
                connectionType         = $connection.connectionType
            }
        }

    }

}
