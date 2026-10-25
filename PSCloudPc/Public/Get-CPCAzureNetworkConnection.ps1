function Get-CPCAzureNetworkConnection {
    <#
    .SYNOPSIS
    Returns all Azure Network Connections or a specific Azure Network Connection
    .DESCRIPTION
    Returns all Azure Network Connections or a specific Azure Network Connection
    .PARAMETER name
    Name of the Azure Network Connection to return
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
        [string]$Name 
    )
    
    Begin {
        Get-TokenValidity
        switch ($PsCmdlet.ParameterSetName) {
            DisplayName {
                Write-Verbose "DisplayName parameter provided"
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/onPremisesConnections?`$filter=displayName+eq+'$(ConvertTo-CPCODataString $Name)'"
            }
            default {
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/onPremisesConnections"
            }
        }
    }
    
    Process {
        write-verbose $url
        $result = @(Invoke-APIRequest -uri $url -Token $script:Authtoken -Method GET)

        if ($result.Count -eq 0) {
            Write-Verbose "No Azure Network Connection found"
            return
        }

        $returnResults = @()
        $result | ForEach-Object {
            # type stopped returning data on January 31, 2024; connectionType replaces it.
            # type is still populated from connectionType for scripts that read it.
            $Info = [PSCustomObject]@{
                id                     = $_.id
                displayName            = $_.displayName
                subscriptionId         = $_.subscriptionId
                connectionType         = $_.connectionType
                type                   = $_.connectionType
                subscriptionName       = $_.subscriptionName
                adDomainName           = $_.adDomainName
                adDomainUsername       = $_.adDomainUsername
                organizationalUnit     = $_.organizationalUnit
                resourceGroupId        = $_.resourceGroupId
                virtualNetworkLocation = $_.virtualNetworkLocation
                virtualNetworkId       = $_.virtualNetworkId
                subnetId               = $_.subnetId
                healthCheckStatus      = $_.healthCheckStatus
                healthCheckPaused      = $_.healthCheckPaused
                inUse                  = $_.inUse
                managedBy              = $_.managedBy
            }
            $returnResults += $Info
        }
        return $returnResults
    
    }
    
}