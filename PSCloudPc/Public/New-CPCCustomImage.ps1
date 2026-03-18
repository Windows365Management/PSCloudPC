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
    #>

    # TODO: Add SupportsShouldProcess 
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        [parameter(Mandatory = $false, ParameterSetName = 'Name')]
        [string]$Name,

        [Parameter(mandatory = $true)][string]$Version,

        [Parameter(mandatory = $true)][string]$SourceImageResourceId
        
    )
    
    begin {
        Get-TokenValidity

        $Image = Get-CPCCustomImage -Name $Name -ErrorAction SilentlyContinue

        if ($Image) {
            Write-Error "Custom Image with name $Name already exists"
            Break
        }

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/deviceImages"

        Write-Verbose "Graph URL for Custom Image: $url"
    }

    Process {

        $params = @{
            DisplayName = $DisplayName
            Version = $Version
            SourceImageResourceId = $SourceImageResourceId
        } | ConvertTo-Json -Depth 10

        Write-Verbose $params

        try {
            Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $params
        }
        catch {
            Throw $_.Exception.Message
        }
        
    }
}