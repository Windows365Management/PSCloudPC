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
    .NOTES
    Required permission: CloudPC.Read.All
    https://learn.microsoft.com/graph/api/virtualendpoint-list-supportedregions?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcsupportedregion?view=graph-rest-beta
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
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/supportedRegions?`$filter=displayName+eq+'$(ConvertTo-CPCODataString $Name)'"
            }
            default {
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/supportedRegions"
            }
        }
    }
    
    Process {
        write-verbose "Retrieving supported regions"
        $regions = @(Invoke-APIRequest -uri $url -Token $script:Authtoken -Method GET)
        write-verbose "Regions retrieved"

        $regions | ForEach-Object {
            $Info = [PSCustomObject]@{
                'id'                      = $_.id
                'displayName'             = $_.displayName
                'regionGroup'             = $_.regionGroup
                'regionStatus'            = $_.regionStatus
                'geographicLocationType'  = $_.geographicLocationType
                'supportedSolution'       = $_.supportedSolution
                'regionRestrictionDetail' = $_.regionRestrictionDetail
            }
            $Info
        }
    }
    
}
