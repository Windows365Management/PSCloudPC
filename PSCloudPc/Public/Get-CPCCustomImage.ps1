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
    .NOTES
    Required permission: CloudPC.Read.All
    https://learn.microsoft.com/graph/api/virtualendpoint-list-deviceimages?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcdeviceimage?view=graph-rest-beta
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
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/deviceImages?`$filter=displayName+eq+'$(ConvertTo-CPCODataString $Name)'"
            }
            default {
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/deviceImages"
            }
        }
    }
    
    Process {
        write-verbose $url
        $result = @(Invoke-APIRequest -uri $url -Token $script:Authtoken -Method GET)

        if ($result.Count -eq 0) {
            Write-Verbose "No Custom Images found"
            return
        }

        $returnResults = @()
        $result | ForEach-Object {
            $Info = [PSCustomObject]@{
                id                    = $_.id
                displayName           = $_.displayName
                operatingSystem       = $_.operatingSystem
                osBuildNumber         = $_.osBuildNumber
                osVersionNumber       = $_.osVersionNumber
                version               = $_.version
                status                = $_.status
                errorCode             = $_.errorCode
                expirationDate        = $_.expirationDate
                osStatus              = $_.osStatus
                sizeInGB              = $_.sizeInGB
                lastModifiedDateTime  = $_.lastModifiedDateTime
                sourceImageResourceId = $_.sourceImageResourceId
            }
            $returnResults += $Info
        }
        return $returnResults
    
    }
    
}
