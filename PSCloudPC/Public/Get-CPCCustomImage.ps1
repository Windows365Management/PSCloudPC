function Get-CPCCustomImage {
    <#
    .SYNOPSIS
    Returns all Custom Images or Custom Images with a specific name
    .DESCRIPTION
    The function will return all Custom Images or Custom Images with a specific name
    .PARAMETER name
    Enter the name of the Custom Image
    .EXAMPLE
    Get-CPCCustomImage -name "CustomImage01"

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
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/deviceImages?`$filter=displayName+eq+'$($Name)'"
            }
            default {
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/deviceImages"
            }
        }
    }
    
    Process {
        write-verbose $url
        $result = Invoke-WebRequest -uri $url -Method GET -Headers $script:authHeader
    
        if ($null -eq $result) {
            Write-Error "No Custom Images returned"
            break
        }

        $resultnew = $result.content | ConvertFrom-Json
        $resultnew.value | ForEach-Object {
    
            $Info = [PSCustomObject]@{
                id                    = $_.id
                displayName           = $_.displayName
                operatingSystem       = $_.operatingSystem
                osBuildNumber         = $_.osBuildNumber
                version               = $_.version
                status                = $_.status
                expirationDate        = $_.expirationDate
                osStatus              = $_.osStatus
                sourceImageResourceId = $_.sourceImageResourceId
            }
            $Info
    
        }
    
    }
    
}