function Get-CPCGalleryImage {
    <#
    .SYNOPSIS
    Returns all gallery images or gallery images with a specific name
    .DESCRIPTION
    The function will return all gallery images or gallery images with a specific name
    .PARAMETER name
    Enter the name of the gallery image
    .EXAMPLE
    Get-CPCGalleryImage
    .EXAMPLE
    Get-CPCGalleryImage -name "Windows 11 Enterprise + OS Optimizations"   
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
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/galleryImages?`$filter=offerDisplayName+eq+'$($Name)'"
            }
            default {
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/galleryImages"
            }
        }
    }
    
    Process {
        write-verbose $url
        $result = Invoke-WebRequest -uri $url -Method GET -Headers $script:authHeader
    
        if ($null -eq $result) {
            Write-Error "No gallery images returned"
            break
        }

        $resultnew = $result.content | ConvertFrom-Json
        $returnResults = @()
        $resultnew.value | ForEach-Object {
    
            $Info = [PSCustomObject]@{
                offerDisplayName = $_.offerDisplayName
                skuDisplayName   = $_.skuDisplayName
                recommendedSku   = $_.recommendedSku
                status           = $_.status
                id               = $_.id
                endDate          = $_.endDate
            }
            $returnResults += $Info
        }
        return $returnResults
    
    }
    
}