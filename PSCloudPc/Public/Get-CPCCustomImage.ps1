function Get-CPCCustomImage {
    <#
    .SYNOPSIS
    Returns all Custom Images or Custom Images with a specific name
    .DESCRIPTION
    The function will return all Custom Images or Custom Images with a specific name.
    -Name is an exact, case-insensitive match on the display name. An image is identified by its
    display name and version, so one name can return several images (one per version).
    .PARAMETER Name
    Enter the exact name of the Custom Image
    .EXAMPLE
    Get-CPCCustomImage -Name "CustomImage01"
    .EXAMPLE
    Get-CPCCustomImage
    .NOTES
    Required permission: CloudPC.Read.All
    https://learn.microsoft.com/graph/api/virtualendpoint-list-deviceimages?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcdeviceimage?view=graph-rest-beta
#>
    [CmdletBinding()]
    param (
        [parameter(ParameterSetName = "Name")]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    Begin {
        Get-TokenValidity

        # Check the bound parameter instead of the parameter set: with a single named parameter set,
        # PowerShell can report that set even when -Name isn't passed
        $filterByName = $PSBoundParameters.ContainsKey("Name")
        if ($filterByName) {
            Write-Verbose "Name parameter provided"
            $filterName = [uri]::EscapeDataString($Name.Replace("'", "''"))
            $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/deviceImages?`$filter=displayName+eq+'$filterName'"
        }
        else {
            $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/deviceImages"
        }
    }

    Process {
        write-verbose $url
        try {
            $result = Invoke-APIRequest -uri $url -Token $script:Authtoken -Method GET
        }
        catch {
            Throw (Get-GraphErrorMessage $_)
        }

        # foreach skips an empty result; piping $null to ForEach-Object would output one empty object
        foreach ($image in $result) {
            # Exact, case-insensitive match on the client as well
            if ($filterByName -and $image.displayName -ne $Name) {
                continue
            }

            [PSCustomObject]@{
                id                    = $image.id
                displayName           = $image.displayName
                operatingSystem       = $image.operatingSystem
                osBuildNumber         = $image.osBuildNumber
                version               = $image.version
                status                = $image.status
                expirationDate        = $image.expirationDate
                osStatus              = $image.osStatus
                sourceImageResourceId = $image.sourceImageResourceId
            }
        }

    }

}
