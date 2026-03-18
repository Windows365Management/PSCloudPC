function Remove-CPCAzureNetworkConnection {
    <#
    .SYNOPSIS
    Removes a Cloud PC Azure Network Connection
    .DESCRIPTION
    The function will remove a Cloud PC Azure Network Connection
    .PARAMETER name
    Enter the name of the Cloud PC Azure Network Connection
    .EXAMPLE
    Remove-CPCAzureNetworkConnection -name "Azure Network Connection 01"
#>
    [CmdletBinding()]
    param (
        [parameter(mandatory = $true)][string]$Name 
        # TODO: Add SupportsShouldProcess 
    )
    
    Begin {
        Get-TokenValidity

        Write-Verbose "Graph URL for Cloud PC Azure Network Connection: $Name"
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/onPremisesConnections?`$filter=contains(displayName,'$Name')"

    }
    
    Process {
        write-verbose $url
        $result = Invoke-WebRequest -uri $url -Method GET -Headers $script:authHeader
    
        if ($null -eq $result)
        {
            Write-Error "No Cloud PC Azure Network Connection returned"
            return
        }

        $resultnew = $result.content | ConvertFrom-Json

        Write-Verbose "Object ID of deleted Policy $($resultnew.value.id)"
        
        $deleteurl = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/onPremisesConnections/$($resultnew.value.id)"

        Write-Verbose "Delete URL: $deleteurl"

        try {
            Write-Verbose "Deleting Cloud PC Azure Network Connection $($Name)"
            Invoke-WebRequest -uri $deleteurl -Method DELETE -Headers $script:authHeader
        }
        catch {
            Throw $_.Exception.Message
        }

        
    }
    
}