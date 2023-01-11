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
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/CloudPCs?`$filter=managedDeviceName+eq+'$Name'"
            }
            default {
                Write-Verbose "No name parameter provided"
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/CloudPCs"
            }
        }
    }
    Process {
        write-verbose $url
        $result = Invoke-WebRequest -uri $url -Method GET -Headers $script:authHeader
    
        if ($null -eq $result) {
            Write-Error "No CloudPC's returned"
            break
        }

        Write-Verbose "Params: $($params)"

        $resultnew = $result.content | ConvertFrom-Json
        $resultnew.value | ForEach-Object {
    
            $Info = [PSCustomObject]@{
                id                     = $_.id
                managedDeviceName      = $_.managedDeviceName
                managedDeviceId        = $_.managedDeviceId
                displayName            = $_.displayName
                userPrincipalName      = $_.userPrincipalName
                status                 = $_.status
                provisioningPolicyName = $_.provisioningPolicyName
                imageDisplayName       = $_.imageDisplayName
                lastmodifiedDateTime   = $_.lastmodifiedDateTime
                serviceplanType        = $_.servicePlanType
                servicePlanName        = $_.servicePlanName
                
            }
            $Info
    
        }
    
    }
    
}

