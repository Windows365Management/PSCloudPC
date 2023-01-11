function Remove-CPCProvisioningPolicy {
    <#
    .SYNOPSIS
    Removes a Cloud PC Provisioning Policy
    .DESCRIPTION
    The function will remove a Cloud PC Provisioning Policy
    .PARAMETER name
    Enter the name of the Cloud PC Provisioning Policy
    .EXAMPLE
    Remove-CPCProvisioningPolicy -name "Provisioning Policy 01"
#>

    [CmdletBinding()]
    param (
        [parameter(mandatory = $true)][string]$Name 
        # TODO: Add SupportsShouldProcess 
    )
    
    Begin {
        Get-TokenValidity

        Write-Verbose "Graph URL for Provisioning Policy: $Name"
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies?`$filter=contains(displayName,'$Name')"

    }
    
    Process {
        write-verbose $url
        $result = Invoke-WebRequest -uri $url -Method GET -Headers $script:authHeader
    
        if ($null -eq $result)
        {
            Write-Error "No Provisioning Policy's returned"
            return
        }

        $resultnew = $result.content | ConvertFrom-Json

        Write-Verbose "Object ID of deleted Policy $($resultnew.value.id)"
        
        $deleteurl = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies/$($resultnew.value.id)"

        Write-Verbose "Delete URL: $deleteurl"

        try {
            Write-Verbose "Deleting Provisioning Policy $($Name)"
            Invoke-WebRequest -uri $deleteurl -Method DELETE -Headers $script:authHeader
        }
        catch {
            Throw $_.Exception.Message
        }
        

    }
    
}