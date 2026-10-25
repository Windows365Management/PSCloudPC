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
    .NOTES
    Required permission: CloudPC.Read.All
    https://learn.microsoft.com/graph/api/virtualendpoint-list-galleryimages?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcgalleryimage?view=graph-rest-beta
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
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/galleryImages?`$filter=displayName+eq+'$(ConvertTo-CPCODataString $Name)'"
            }
            default {
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/galleryImages"
            }
        }
    }
    
    Process {
        write-verbose $url
        $result = @(Invoke-APIRequest -uri $url -Token $script:Authtoken -Method GET)

        if ($result.Count -eq 0) {
            Write-Verbose "No gallery images found"
            return
        }

        $returnResults = @()
        $result | ForEach-Object {
            # offerDisplayName, skuDisplayName and recommendedSku are deprecated and stop returning data on December 7, 2026;
            # displayName, offerName, skuName and publisherName replace them
            $Info = [PSCustomObject]@{
                id               = $_.id
                displayName      = $_.displayName
                status           = $_.status
                startDate        = $_.startDate
                endDate          = $_.endDate
                expirationDate   = $_.expirationDate
                osVersionNumber  = $_.osVersionNumber
                sizeInGB         = $_.sizeInGB
                publisherName    = $_.publisherName
                offerName        = $_.offerName
                skuName          = $_.skuName
                offerDisplayName = $_.offerDisplayName
                skuDisplayName   = $_.skuDisplayName
                recommendedSku   = $_.recommendedSku
            }
            $returnResults += $Info
        }
        return $returnResults
    
    }
    
}
