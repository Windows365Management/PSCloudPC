function New-CPCCustomImage {
    <#
    .SYNOPSIS
    Adds a new Custom Image
    .DESCRIPTION
    The function will add a new Custom Image by uploading a managed image from Azure.
    Graph identifies an image by its display name and version, so you can upload a new version of an
    existing image. The command stops without creating an image when a Custom Image with the same name
    and version already exists, or when the check for an existing image fails.
    .PARAMETER Name
    Enter the name of the Custom Image. Sent as the displayName of the image.
    .PARAMETER Version
    Enter the version of the Custom Image, for example 0.0.1 or 1.5.13
    .PARAMETER SourceImageResourceId
    Enter the Source Image Resource Id from Azure. Required format: /subscriptions/{subscription-id}/resourceGroups/{resourceGroupName}/providers/Microsoft.Compute/images/{imageName}
    .EXAMPLE
    New-CPCCustomImage -Name "CustomImage01" -Version "1.0.0" -SourceImageResourceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-images/providers/Microsoft.Compute/images/image01"
    .EXAMPLE
    New-CPCCustomImage -Name "CustomImage01" -Version "1.0.0" -SourceImageResourceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-images/providers/Microsoft.Compute/images/image01" -WhatIf
    .NOTES
    Required permission: CloudPC.ReadWrite.All
    https://learn.microsoft.com/graph/api/virtualendpoint-post-deviceimages?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcdeviceimage?view=graph-rest-beta
    #>

    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
    param (
        [parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(mandatory = $true)][string]$Version,

        [Parameter(mandatory = $true)][string]$SourceImageResourceId

    )

    begin {
        Get-TokenValidity

        # Graph identifies an image by displayName + version, so a new version of an existing image is allowed.
        # Stop when the lookup fails, so a failed lookup isn't treated as "doesn't exist".
        try {
            $Image = @(Get-CPCCustomImage -Name $Name -ErrorAction Stop | Where-Object { $_.displayName -eq $Name -and $_.version -eq $Version })
        }
        catch {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Could not check for an existing Custom Image with name '$Name': $(Get-GraphErrorMessage $_)" -Category InvalidOperation
        }

        if ($Image.Count -gt 0) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Custom Image with name '$Name' and version '$Version' already exists ($($Image.id -join ', '))" -Category ResourceExists
        }

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/deviceImages"

        Write-Verbose "Graph URL for Custom Image: $url"
    }

    Process {

        $params = @{
            displayName           = $Name
            version               = $Version
            sourceImageResourceId = $SourceImageResourceId
        } | ConvertTo-Json -Depth 10

        Write-Verbose "Request body: $params"

        if ($PSCmdlet.ShouldProcess($Name, "Create Custom Image")) {
            try {
                Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $params -ErrorAction Stop
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }
        }

    }
}
