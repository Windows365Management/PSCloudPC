function Remove-CPCUserSettingsPolicy {
    <#
    .SYNOPSIS
    Removes a Cloud PC User Settings Policy
    .DESCRIPTION
    The function will remove a Cloud PC User Settings Policy
    .PARAMETER name
    Enter the name of the Cloud PC User Settings Policy
    .EXAMPLE
    Remove-CPCUserSettingsPolicy -name "User Settings Policy 01"

#>

    [CmdletBinding()]
    param (
        [parameter(mandatory = $true)][string]$Name 
    )
    
    Begin {
        Get-TokenValidity

        Write-Verbose "Graph URL for User Settings Policy: $Name"
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/userSettings?`$filter=contains(displayName,'$Name')"

    }
    
    Process {
        write-verbose $url
        $result = Invoke-WebRequest -uri $url -Method GET -Headers $script:authHeader
    
        if ($null -eq $result)
        {
            Write-Error "No User Settings Policy's returned"
            return
        }

        $resultnew = $result.content | ConvertFrom-Json

        Write-Verbose "Object ID of deleted Policy $($resultnew.value.id)"
        
        $deleteurl = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/userSettings/$($resultnew.value.id)"

        Write-Verbose "Delete URL: $deleteurl"

        try {
            Write-Verbose "Deleting User Settings Policy $($Name)"
            Invoke-WebRequest -uri $deleteurl -Method DELETE -Headers $script:authHeader
        }
        catch {
            Throw $_.Exception.Message
        }
        
    }
    
}