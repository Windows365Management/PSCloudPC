function Get-CPCAzureNetworkConnection {
    <#
    .SYNOPSIS
    Returns all User Setting Policy's or User Setting Policy's with a specific name
    .DESCRIPTION
    The function will return all User Setting Policy's or User Setting Policy's with a specific name
    .PARAMETER name
    Enter the name of the User Setting Policy
    .EXAMPLE
    Get-CPCUserSettingsPolicy -name "UserSettingPolicy01"

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
        $result = Invoke-WebRequest -uri $url -Method GET -Headers $script:authHeader
    
        if ($null -eq $result) {
            Write-Error "No Azure Network Connection found"
            break
        }

        $resultnew = $result.content | ConvertFrom-Json
        $resultnew.value | ForEach-Object {
    
            $Info = [PSCustomObject]@{
                id                   = $_.id
                displayName          = $_.displayName
                subscriptionId   = $_.subscriptionId
                type    = $_.type
                subscriptionName      = $_.subscriptionName
                adDomainName = $_.adDomainName
                adDomainUsername  = $_.adDomainUsername
                organizationalUnit = $_.organizationalUnit
                resourceGroupId = $_.resourceGroupId
                virtualNetworkLocation = $_.virtualNetworkLocation
                virtualNetworkId = $_.virtualNetworkId
                subnetId = $_.subnetId
                healthCheckStatus = $_.healthCheckStatus

            }
            $Info
    
        }
    
    }
    
}