function Get-CPCProvisioningPolicy {
    <#
    .SYNOPSIS
    Returns all Provisioning Policy's or Provisioning Policy's with a specific name

    .DESCRIPTION
    The function will return all Provisioning Policy's or Provisioning Policy's with a specific name
    .PARAMETER name
    Enter the name of the Provisioning Policy
    .EXAMPLE
    Get-CPCProvisioningPolicy -name "ProvisioningPolicy01"
    .NOTES
    Required permission: CloudPC.Read.All
    https://learn.microsoft.com/graph/api/virtualendpoint-list-provisioningpolicies?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcprovisioningpolicy?view=graph-rest-beta
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
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies?`$filter=displayName+eq+'$(ConvertTo-CPCODataString $Name)'"
            }
            default {
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies"
            }
        }
    }
    
    Process {
        write-verbose $url
        $result = @(Invoke-APIRequest -uri $url -Token $script:Authtoken -Method GET)

        if ($result.Count -eq 0) {
            Write-Verbose "No Provisioning Policy's found"
            return
        }

        $returnResults = @()
        $result | ForEach-Object {
            # windowsSettings stopped returning data on January 31, 2024; windowsSetting (locale) replaces it
            $Info = [PSCustomObject]@{
                id                       = $_.id
                displayName              = $_.displayName
                description              = $_.description
                userExperienceType       = $_.userExperienceType
                provisioningType         = $_.provisioningType
                managedBy                = $_.managedBy
                imageId                  = $_.imageId
                imageDisplayName         = $_.imageDisplayName
                imageType                = $_.imageType
                enableSingleSignOn       = $_.enableSingleSignOn
                localAdminEnabled        = $_.localAdminEnabled
                DomainJoinConfigurations = $_.domainJoinConfigurations
                windowsSetting           = $_.windowsSetting
                windowsSettings          = $_.windowsSettings
                CloudPcNamingTemplate    = $_.cloudPcNamingTemplate
                microsoftManagedDesktop  = $_.microsoftManagedDesktop
                autopatch                = $_.autopatch
                gracePeriodInHours       = $_.gracePeriodInHours
                lastModifiedDateTime     = $_.lastModifiedDateTime
            }
            $returnResults += $Info
        }
        return $returnResults
    
    }
    
}