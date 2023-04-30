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
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies?`$filter=displayName+eq+'$($Name)'"
            }
            default {
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies"
            }
        }
    }
    
    Process {
        write-verbose $url
        $result = Invoke-WebRequest -uri $url -Method GET -Headers $script:authHeader
    
        if ($null -eq $result) {
            Write-Error "No Provisioning Policy's returned"
            break
        }

        $resultnew = $result.content | ConvertFrom-Json
        $resultnew.value | ForEach-Object {
    
            $Info = [PSCustomObject]@{
                id                       = $_.id
                displayName              = $_.displayName
                imageId                  = $_.imageId
                imageDisplayName         = $_.imageDisplayName
                imageType                = $_.imageType
                enableSingleSignOn       = $_.enableSingleSignOn
                DomainJoinConfigurations = $domainJoinConfigurations
                windowsSettings          = $_.windowsSettings
                CloudPcNamingTemplate    = $_.CloudPcNamingTemplate

            }
            $Info
    
        }
    
    }
    
}