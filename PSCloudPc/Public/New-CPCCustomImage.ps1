function New-CPCCustomImage {
    <#
    .SYNOPSIS
    Adds a new Custom Image
    .DESCRIPTION
    The function will add a new Custom Image
    .PARAMETER Name
    Enter the name of the Custom Image
    .PARAMETER Version
    Enter the version of the Custom Image
    .PARAMETER SourceImageResourceId
    Enter the Source Image Resource Id from Azure
    .EXAMPLE
    New-CPCCustomImage -Name "CustomImage01" -Version "1.0" -SourceImageResourceId "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/rg-azw365/providers/Microsoft.Compute/images/azw365-2021-03-01-01-00-00"
    .NOTES
    Required permission: CloudPC.ReadWrite.All
    https://learn.microsoft.com/graph/api/virtualendpoint-post-deviceimages?view=graph-rest-beta
    #>

    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
    param (
        [parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(mandatory = $true)][ValidateNotNullOrEmpty()][string]$Version,

        [Parameter(mandatory = $true)][ValidateNotNullOrEmpty()][string]$SourceImageResourceId
        
    )
    
    begin {
        Get-TokenValidity

        # displayName and version together identify an image, so the same name with another version is allowed
        $Image = @(Get-CPCCustomImage -Name $Name -ErrorAction SilentlyContinue | Where-Object { $_.version -eq $Version })

        if ($Image.Count -gt 0) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Custom Image with name $Name and version $Version already exists" -Category ResourceExists
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

        Write-Verbose $params

        if ($PSCmdlet.ShouldProcess("$Name (version $Version)", "Create Custom Image")) {
            try {
                Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $params
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }
        }
        
    }
}