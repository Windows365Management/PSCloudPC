function Get-CloudPC {
    <#
        .SYNOPSIS
        Returns all CloudPC's or CloudPC's with a specific name
        .DESCRIPTION
        The function will return all CloudPC's or CloudPC's with a specific name
        .PARAMETER name
        Enter the name of the CloudPC
        .EXAMPLE
        Get-CloudPC -name "CloudPC01"
        .NOTES
        Required permission: CloudPC.Read.All
        https://learn.microsoft.com/graph/api/virtualendpoint-list-cloudpcs?view=graph-rest-beta
        https://learn.microsoft.com/graph/api/resources/cloudpc?view=graph-rest-beta
    #>
    [CmdletBinding()]
    param (
        [parameter(ParameterSetName = "Name")]
        [string]$Name
    )

    Begin {
        Get-TokenValidity

        switch ($PsCmdlet.ParameterSetName) {
            Name {
                Write-Verbose "Name parameter provided"
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/CloudPCs?`$filter=managedDeviceName+eq+'$(ConvertTo-CPCODataString $Name)'"
            }
            default {
                Write-Verbose "No name parameter provided"
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/CloudPCs"
            }
        }
    }
    Process {
        write-verbose $url

        $Result = @(Invoke-APIRequest -uri $url -Token $script:Authtoken -Method GET)
    
        if ($Result.Count -eq 0) {
            Write-Verbose "No CloudPC's found"
            return
        }

        $PSObjectResults = @()
        $Result | ForEach-Object {
    
            $Info = [PSCustomObject]@{
                id                     = $_.id
                managedDeviceName      = $_.managedDeviceName
                managedDeviceId        = $_.managedDeviceId
                aadDeviceId            = $_.aadDeviceId
                displayName            = $_.displayName
                userPrincipalName      = $_.userPrincipalName
                status                 = $_.status
                statusDetail           = $_.statusDetail
                powerState             = $_.powerState
                productType            = $_.productType
                provisioningType       = $_.provisioningType
                provisioningPolicyId   = $_.provisioningPolicyId
                provisioningPolicyName = $_.provisioningPolicyName
                onPremisesConnectionName = $_.onPremisesConnectionName
                deviceRegionName       = $_.deviceRegionName
                imageDisplayName       = $_.imageDisplayName
                osVersion              = $_.osVersion
                userAccountType        = $_.userAccountType
                lastmodifiedDateTime   = $_.lastModifiedDateTime
                provisionedDateTime    = $_.provisionedDateTime
                gracePeriodEndDateTime = $_.gracePeriodEndDateTime
                servicePlanId          = $_.servicePlanId
                serviceplanType        = $_.servicePlanType
                servicePlanName        = $_.servicePlanName
            }
            $PSObjectResults += $Info
        }
        return $PSObjectResults
    
    }
    
}

