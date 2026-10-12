function Get-CPCGalleryImage {
    <#
    .SYNOPSIS
    Returns all gallery images or gallery images with a specific name
    .DESCRIPTION
    The function will return all gallery images or gallery images with a specific name.
    -Name matches the image displayName (for example "Windows 11 Enterprise 26H2") or the
    deprecated offerDisplayName (for example "Windows 11 Enterprise", which returns every
    image of that offer). The match is exact and case-insensitive.
    The output contains the current properties (displayName, offerName, skuName, publisherName,
    osVersionNumber, osArchitecture, sizeInGB, startDate, expirationDate) and, for existing
    scripts, the deprecated offerDisplayName, skuDisplayName and recommendedSku.
    .PARAMETER name
    Enter the display name or the offer display name of the gallery image
    .EXAMPLE
    Get-CPCGalleryImage
    .EXAMPLE
    Get-CPCGalleryImage -name "Windows 11 Enterprise + OS Optimizations"
    .EXAMPLE
    Get-CPCGalleryImage -name "Windows 11 Enterprise 26H2"
    .NOTES
    Requires CloudPC.Read.All or CloudPC.ReadWrite.All permission (delegated or application).
    API reference: https://learn.microsoft.com/graph/api/virtualendpoint-list-galleryimages?view=graph-rest-beta
    Resource: https://learn.microsoft.com/graph/api/resources/cloudpcgalleryimage?view=graph-rest-beta
#>
    [CmdletBinding()]
    param (
        [parameter(ParameterSetName = "Name")]
        [string]$Name
    )

    Begin {
        Get-TokenValidity

        # -Name is matched on the client against displayName and offerDisplayName
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/galleryImages"
    }

    Process {
        write-verbose $url
        $result = @(Invoke-APIRequest -uri $url -Token $script:Authtoken -Method GET)

        if ($PsCmdlet.ParameterSetName -eq "Name") {
            Write-Verbose "Name parameter provided: $Name"
            $result = @($result | Where-Object { $_.displayName -eq $Name -or $_.offerDisplayName -eq $Name })
        }

        foreach ($image in $result) {
            [PSCustomObject]@{
                offerDisplayName = $image.offerDisplayName
                skuDisplayName   = $image.skuDisplayName
                recommendedSku   = $image.recommendedSku
                status           = $image.status
                id               = $image.id
                endDate          = $image.endDate
                displayName      = $image.displayName
                offerName        = $image.offerName
                skuName          = $image.skuName
                publisherName    = $image.publisherName
                osVersionNumber  = $image.osVersionNumber
                osArchitecture   = $image.osArchitecture
                sizeInGB         = $image.sizeInGB
                startDate        = $image.startDate
                expirationDate   = $image.expirationDate
            }
        }
    }

}
