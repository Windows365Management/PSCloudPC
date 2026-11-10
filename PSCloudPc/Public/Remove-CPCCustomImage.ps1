function Remove-CPCCustomImage {
    <#
    .SYNOPSIS
    Removes a Cloud PC Custom Image
    .DESCRIPTION
    The function will remove a Cloud PC Custom Image.
    The name must match the display name of exactly one image (exact match, not case sensitive).
    Several versions of an image can share a display name; use -Version to select one of them.
    If no image or more than one image matches, nothing is removed and the command stops; the
    message lists the id and version of every match.
    The function asks for confirmation before it removes the image. In a non-interactive session
    (pwsh -File, a pipeline or a scheduled task) the confirmation prompt fails and nothing is removed,
    so pass -Confirm:$false there.
    .PARAMETER name
    Enter the name of the Cloud PC Custom Image
    .PARAMETER Version
    Enter the version of the Cloud PC Custom Image (for example "1.0.0"). Optional; only needed when
    more than one image has the same name.
    .EXAMPLE
    Remove-CPCCustomImage -name "Custom Image 01"
    .EXAMPLE
    Remove-CPCCustomImage -name "Custom Image 01" -Version "1.0.0"
    .EXAMPLE
    Remove-CPCCustomImage -name "Custom Image 01" -WhatIf
    .EXAMPLE
    Remove-CPCCustomImage -name "Custom Image 01" -Version "1.0.0" -Confirm:$false

    Removes the image without asking for confirmation, as needed in scripts and pipelines.
    .NOTES
    Required permission: CloudPC.ReadWrite.All
    https://learn.microsoft.com/graph/api/cloudpcdeviceimage-delete?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/virtualendpoint-list-deviceimages?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcdeviceimage?view=graph-rest-beta
#>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param (
        [parameter(mandatory = $true)][ValidateNotNullOrEmpty()][string]$Name,
        [parameter(mandatory = $false)][ValidateNotNullOrEmpty()][string]$Version
    )

    Begin {
        Get-TokenValidity

        #Graph's displayName eq filter is case-sensitive, so list all images and match the name on the client
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/deviceImages?`$select=id,displayName,version"
        Write-Verbose "Looking up Custom Image '$Name': GET $url"

        try {
            $result = Invoke-APIRequest -uri $url -Token $script:Authtoken -Method GET -ErrorAction Stop
        }
        catch {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message (Get-GraphErrorMessage $_) -Category InvalidOperation
        }

        #Exact match, not case sensitive; a partial name never matches
        $Image = @($result | Where-Object { $_.displayName -eq $Name })
        $Target = "name '$Name'"

        if ($PSBoundParameters.ContainsKey("Version")) {
            $Image = @($Image | Where-Object { $_.version -eq $Version })
            $Target = "name '$Name' and version '$Version'"
        }

        if ($Image.Count -eq 0) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No Custom Image found with $Target. Nothing was removed." -Category ObjectNotFound
        }

        if ($Image.Count -gt 1) {
            $ImageList = ($Image | ForEach-Object { "$($_.id) (version $($_.version))" }) -join ", "
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "$($Image.Count) Custom Images found with $Target ($ImageList). Use -Version to select one. Nothing was removed."
        }

        $ImageId = $Image[0].id
        $ParsedId = [guid]::Empty
        if ($ImageId -isnot [string] -or -not [guid]::TryParseExact($ImageId, "D", [ref]$ParsedId)) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "The Custom Image '$Name' has no valid id ('$ImageId'). Nothing was removed." -Category InvalidData
        }

        $deleteurl = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/deviceImages/$ImageId"
    }

    Process {
        if ($PSCmdlet.ShouldProcess("$($Image[0].displayName) version $($Image[0].version) ($ImageId)", "Remove Custom Image")) {
            Write-Verbose "Removing Custom Image: DELETE $deleteurl"
            try {
                Invoke-RestMethod -Uri $deleteurl -Method DELETE -Headers $script:Authheader -ErrorAction Stop
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }
        }
    }

}
