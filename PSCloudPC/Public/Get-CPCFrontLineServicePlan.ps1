function Get-CPCFrontLineServicePlan {
    <#
    .SYNOPSIS
    This function will return all currently available FrontLine service plans
    .DESCRIPTION
    This function will return all currently available FrontLine service plans
    .PARAMETER ServicePlanType
    Enter the type of service plan you want to retrieve. Valid values are: "enterprise", "business"
        .EXAMPLE
    Get-CPCFrontLineServicePlan
    .EXAMPLE
    Get-CPCFrontLineServicePlan
    #>
    [CmdletBinding()]
    param (
        [parameter(ParameterSetName = "Type")]
        [string]$ServicePlanName
        
    )
    
    Begin {
        Get-TokenValidity

        switch ($PsCmdlet.ParameterSetName) {
            Type {
                Write-Verbose "Type parameter provided"
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/devicemanagement/virtualendpoint/frontLineServicePlans?`$filter=displayName+eq+'$($ServicePlanName)'"
                
            }
            default {
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/frontLineServicePlans"
            }
        }
    }
    
    Process {
        write-verbose "Retrieving service plans"
        try {
            $result = Invoke-WebRequest -uri $url -Method GET -Headers $script:authHeader
            $regions = $result.content | convertfrom-json
            write-verbose "FrontLine ServicePlans retrieved"
            $support = $regions.value
            $support | ForEach-Object {
                $Info = [PSCustomObject]@{
                    'id'          = $_.id
                    'displayName' = $_.displayName
                    'usedCount'   = $_.usedCount
                    'totalCount'  = $_.totalCount
                }
                $Info
            }
        
        }
        catch {
            Throw $_.Exception.Message
        }
    
    }
    
}