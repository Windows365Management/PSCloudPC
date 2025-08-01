function Get-CPCServicePlan {
    <#
    .SYNOPSIS
    This function will return all currently available service plans
    .DESCRIPTION
    This function will return all currently available service plans
    .PARAMETER ServicePlanType
    Enter the type of service plan you want to retrieve. Valid values are: "enterprise", "business"
        .EXAMPLE
    Get-CPCServicePlans
    .EXAMPLE
    Get-CPCServicePlans -ServicePlanType "enterprise"
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
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/devicemanagement/virtualendpoint/serviceplans?`$filter=displayName+eq+'$($ServicePlanName)'"
                
            }
            default {
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/serviceplans"
            }
        }
    }
    
    Process {
        write-verbose "Retrieving service plans"
        try {
            $result = Invoke-WebRequest -uri $url -Method GET -Headers $script:authHeader
            $regions = $result.content | convertfrom-json
            write-verbose "Regions retrieved"
            $support = $regions.value
            $support | ForEach-Object {
                $Info = [PSCustomObject]@{
                    'id'          = $_.id
                    'displayName' = $_.displayName
                    'type'        = $_.type
                    'vCpuCount'   = $_.vCpuCount
                    'ramInGB'     = $_.ramInGB
                    'storageInGB' = $_.storageInGB
                }
                $Info
            }
        
        }
        catch {
            Throw $_.Exception.Message
        }
    
    }
    
}