function Remove-CPCCustomImage {
    <#
    .SYNOPSIS
    Removes a Cloud PC Custom Image
    .DESCRIPTION
    The function will remove a Cloud PC Custom Image
    .PARAMETER name
    Enter the name of the Cloud PC Custom Image
    .EXAMPLE
    Remove-CPCCustomImage -name "Custom Image 01"
#>

    [CmdletBinding()]
    param (
        [parameter(mandatory = $true)][string]$Name 
        # TODO: Add SupportsShouldProcess 
    )
    
    Begin {
        Get-TokenValidity

        Write-Verbose "Graph URL for Custom Image: $name"
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/deviceImages?`$filter=contains(displayName,'$Name')"

    }
    
    Process {
        write-verbose $url
        $result = Invoke-WebRequest -uri $url -Method GET -Headers $script:authHeader
    
        if ($null -eq $result)
        {
            Write-Error "No Custom Image returned"
            return
        }

        $resultnew = $result.content | ConvertFrom-Json

        Write-Verbose "Object ID of deleted Policy $($resultnew.value.id)"
        
        $deleteurl = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/deviceImages/$($resultnew.value.id)"

        Write-Verbose "Delete URL: $deleteurl"

        try {
            Write-Verbose "Deleting Custom Image $($Name)"
            Invoke-WebRequest -uri $deleteurl -Method DELETE -Headers $script:authHeader
        }
        catch {
            Throw $_.Exception.Message
        }
        
    }
    
}