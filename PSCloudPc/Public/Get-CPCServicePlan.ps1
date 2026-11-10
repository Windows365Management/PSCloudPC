function Get-CPCServicePlan {
    <#
    .SYNOPSIS
    This function will return all currently available service plans
    .DESCRIPTION
    This function will return all currently available service plans, or the service plan
    whose display name exactly matches -ServicePlanName (case-insensitive).
    The servicePlans endpoint does not support OData query parameters, so all plans are
    retrieved (following paging) and the name is matched on the client.
    .PARAMETER ServicePlanName
    Enter the exact display name of the service plan you want to retrieve, for example "Cloud PC Enterprise 2vCPU/8GB/128GB"
    .EXAMPLE
    Get-CPCServicePlan
    .EXAMPLE
    Get-CPCServicePlan -ServicePlanName "Cloud PC Enterprise 2vCPU/8GB/128GB"
    .NOTES
    Required permission: CloudPC.Read.All
    https://learn.microsoft.com/graph/api/virtualendpoint-list-serviceplans?view=graph-rest-beta
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$ServicePlanName
    )

    Begin {
        Get-TokenValidity

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/servicePlans"
    }

    Process {
        write-verbose "Retrieving service plans"
        try {
            $plans = @(Invoke-APIRequest -uri $url -Token $script:Authtoken -Method GET)
        }
        catch {
            Throw (Get-GraphErrorMessage $_)
        }
        write-verbose "Service plans retrieved"

        If ($ServicePlanName) {
            Write-Verbose "Filtering service plans on display name: $ServicePlanName"
            $plans = @($plans | Where-Object { $_.displayName -eq $ServicePlanName })

            If ($plans.Count -eq 0) {
                Write-Verbose "No service plan found with display name '$ServicePlanName'"
            }
        }

        $plans | ForEach-Object {
            $Info = [PSCustomObject]@{
                'id'               = $_.id
                'displayName'      = $_.displayName
                'type'             = $_.type
                'provisioningType' = $_.provisioningType
                'vCpuCount'        = $_.vCpuCount
                'ramInGB'          = $_.ramInGB
                'storageInGB'      = $_.storageInGB
            }
            $Info
        }
    }
}
