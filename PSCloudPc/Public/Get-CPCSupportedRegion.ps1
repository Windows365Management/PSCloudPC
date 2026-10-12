function Get-CPCSupportedRegion {
    <#
    .SYNOPSIS
    Returns all supported regions for CloudPC
    .DESCRIPTION
    The function will return all supported regions for CloudPC.
    Graph can return the same region displayName more than once, for example for different
    region groups, geographic locations or solutions. Use id, regionGroup,
    geographicLocationType and supportedSolution to tell them apart.
    .PARAMETER name
    Enter the name of the region
    .EXAMPLE
    Get-CPCSupportedRegion -name "westeurope"

    .NOTES
    Requires CloudPC.Read.All or CloudPC.ReadWrite.All permission (delegated or application).
    API reference: https://learn.microsoft.com/graph/api/virtualendpoint-list-supportedregions?view=graph-rest-beta
    Resource: https://learn.microsoft.com/graph/api/resources/cloudpcsupportedregion?view=graph-rest-beta
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
                $filterName = [uri]::EscapeDataString($Name.Replace("'", "''"))
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/supportedRegions?`$filter=displayName+eq+'$filterName'"
            }
            default {
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/supportedRegions"
            }
        }
    }

    Process {
        write-verbose "Retrieving supported regions"
        $support = @(Invoke-APIRequest -uri $url -Token $script:Authtoken -Method GET)
        write-verbose "Regions retrieved"

        foreach ($region in $support) {
            [PSCustomObject]@{
                'displayName'             = $region.displayName
                'regionGroup'             = $region.regionGroup
                'regionStatus'            = $region.regionStatus
                'id'                      = $region.id
                'geographicLocationType'  = $region.geographicLocationType
                'supportedSolution'       = $region.supportedSolution
                'regionRestrictionDetail' = $region.regionRestrictionDetail
            }
        }
    }

}
