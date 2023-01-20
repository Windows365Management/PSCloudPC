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
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/onPremisesConnections?`$filter=displayName+eq+'$($Name)'"
            }
            default {
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/onPremisesConnections"
            }
        }
    }
    
    Process {
        write-verbose $url
        $result = Invoke-WebRequest -uri $url -Method GET -Headers $script:authHeader -SkiphttpErrorCheck
    
        if ($null -eq $result) {
            Write-Error "No Azure Network Connection found"
            break
        }
        $resultnew = $result.content | ConvertFrom-Json
        $resultnew.value | ForEach-Object {
    
            $Info = [PSCustomObject]@{
                id                     = $_.id
                displayName            = $_.displayName
                subscriptionId         = $_.subscriptionId
                type                   = $_.type
                subscriptionName       = $_.subscriptionName
                adDomainName           = $_.adDomainName
                adDomainUsername       = $_.adDomainUsername
                organizationalUnit     = $_.organizationalUnit
                resourceGroupId        = $_.resourceGroupId
                virtualNetworkLocation = $_.virtualNetworkLocation
                virtualNetworkId       = $_.virtualNetworkId
                subnetId               = $_.subnetId
                healthCheckStatus      = $_.healthCheckStatus
            }
            $Info
    
        }
    
    }
    
}