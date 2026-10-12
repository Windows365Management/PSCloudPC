function Get-CPCProvisioningPolicy {
    <#
    .SYNOPSIS
    Returns all Provisioning Policy's or Provisioning Policy's with a specific name

    .DESCRIPTION
    The function will return all Provisioning Policy's or Provisioning Policy's with a specific name.
    All result pages are returned. The request asks for evolvable enum members
    (Prefer: include-unknown-enum-members), so provisioningType shows sharedByUser,
    sharedByEntraGroup or reserve instead of unknownFutureValue.
    windowsSetting holds the current Windows settings (locale); windowsSettings is the deprecated
    property and is kept for existing scripts. userExperienceType is a documented property
    (cloudPc or cloudApp), but Graph doesn't return it in the default list response, so it can be empty.
    .PARAMETER name
    Enter the name of the Provisioning Policy
    .EXAMPLE
    Get-CPCProvisioningPolicy -name "ProvisioningPolicy01"
    .NOTES
    Requires CloudPC.Read.All or CloudPC.ReadWrite.All permission (delegated or application).
    API reference: https://learn.microsoft.com/graph/api/virtualendpoint-list-provisioningpolicies?view=graph-rest-beta
    Resource: https://learn.microsoft.com/graph/api/resources/cloudpcprovisioningpolicy?view=graph-rest-beta
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
                $filterName = [uri]::EscapeDataString($Name.Replace("'", "''"))
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies?`$filter=displayName+eq+'$filterName'"
            }
            default {
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies"
            }
        }
    }

    Process {
        write-verbose $url
        # Without this header Graph returns unknownFutureValue for evolvable enum members such as
        # provisioningType sharedByUser, sharedByEntraGroup and reserve
        $result = @(Invoke-APIRequest -uri $url -Token $script:Authtoken -Method GET -AdditionalHeaders @{ Prefer = "include-unknown-enum-members" })

        foreach ($policy in $result) {
            [PSCustomObject]@{
                id                       = $policy.id
                displayName              = $policy.displayName
                userExperienceType       = $policy.userExperienceType
                provisioningType         = $policy.provisioningType
                imageId                  = $policy.imageId
                imageDisplayName         = $policy.imageDisplayName
                imageType                = $policy.imageType
                enableSingleSignOn       = $policy.enableSingleSignOn
                DomainJoinConfigurations = $policy.domainJoinConfigurations
                windowsSettings          = $policy.windowsSettings
                CloudPcNamingTemplate    = $policy.CloudPcNamingTemplate
                windowsSetting           = $policy.windowsSetting
            }
        }
    }

}
