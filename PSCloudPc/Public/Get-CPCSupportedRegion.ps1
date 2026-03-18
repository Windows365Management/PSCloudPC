function Get-CPCSupportedRegion {
    <#
    .SYNOPSIS
    Returns all supported regions for CloudPC 
    .DESCRIPTION
    The function will return all supported regions for CloudPC
    .PARAMETER name
    Enter the name of the region
    .EXAMPLE
    Get-CPCSupportedRegion -name "westeurope"

#>
    [CmdletBinding()]
    param (
        [parameter(ParameterSetName = "Region")]
        [string]$Name 
    )
    
    Begin {
        Get-TokenValidity

        switch ($PsCmdlet.ParameterSetName) {
            Region {
                Write-Verbose "Name parameter provided"
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/supportedRegions?`$filter=displayName+eq+'$($Name)'"
            }
            default {
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/supportedRegions"
            }
        }
    }
    
    Process {
        write-verbose "Retrieving supported regions"
        try {
            $result = Invoke-WebRequest -uri $url -Method GET -Headers $script:authHeader
            $regions = $result.content | convertfrom-json
            write-verbose "Regions retrieved"
            $support = $regions.value
            $support | ForEach-Object {
                $Info = [PSCustomObject]@{
                    'displayName'  = $_.displayName
                    'regionGroup'  = $_.regionGroup
                    'regionStatus' = $_.regionStatus
                }
                $Info
            }
        
        }
        catch {
            Throw $_.Exception.Message
        }
    
    }
    
}