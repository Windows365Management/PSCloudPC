function New-CPCProvisioningPolicy {
    <#
    .SYNOPSIS
    Adds a new Provisioning Policy
    .DESCRIPTION
    The function will add a new Provisioning Policy
    .PARAMETER Name
    Enter the name of the Provisioning Policy
    .PARAMETER Description
    Enter the description of the Provisioning Policy
    .PARAMETER ProvisioningType
    Enter the Provisioning Type of the Provisioning Policy (dedicated or shared) (Default: dedicated)
    .PARAMETER ManagedBy
    Enter the Managed By of the Provisioning Policy (Windows365 or Microsoft) (Default: Windows365)
    .PARAMETER imageType
    Enter the image type of the Provisioning Policy (Custom or Gallery)
    .PARAMETER ImageId
    Enter the Image Id of the Provisioning Policy (Info: Get-CPCGalleryImage or Get-CPCCustomImage)
    .PARAMETER EnableSignleSignOn
    Enter the Enable Signle Sign On for the Provisioning Policy
    .PARAMETER DomainJoinType
    Enter the Domain Join Type for the Provisioning Policy (AzureADJoin or AzureADDomainJoin) (Default: AzureADJoin)
    .PARAMETER RegionName
    Enter the Region Name for the Provisioning Policy
    .PARAMETER RegionGroup
    Enter the Region Group for the Provisioning Policy
    .PARAMETER OnPremisesConnectionId
    Enter the On Premises Connection Id (Azure Network Connection) for the Provisioning Policy
    .PARAMETER Language
    Enter the Language for the Provisioning Policy (Default: en-US)
    .EXAMPLE
    New-CPCProvisioningPolicy -Name "Test-AzureADJoin" -Description "Test-AzureADJoin" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365-DomainJoinType "AzureADJoin" -EnableSingleSignOn $true -RegionName "West Europe" -RegionGroup "Europe" -Language "en-US"
    .EXAMPLE
    New-CPCProvisioningPolicy -Name "Test-HybridADJoin" -Description "Test-HybridADJoin" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365" -DomainJoinType "hybridAzureADJoin" -EnableSingleSignOn $false -OnPremisesConnectionId "00000000-0fe4-44cf-8ec0-24eebe498f25" -Language "en-US"
    .EXAMPLE
    New-CPCProvisioningPolicy -Name "Test-Autopatch" -Description "Test-Autopatch" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365 -WindowsAutopatch "starterManaged" -DomainJoinType "AzureADJoin" -RegionName "West Europe" -RegionGroup "Europe" -Language "en-US" -EnableSingleSignOn $true 
    #>
    [CmdletBinding(DefaultParameterSetName = 'AzureADJoin')]
    param (
        
        [parameter(Mandatory = $true)][string]$Name,

        [Parameter(Mandatory = $false)][string]$Description,

        [Parameter(mandatory = $false)][string]$ProvisioningType  = "dedicated",

        [Parameter(mandatory = $false)][string]$ManagedBy  = "Windows365",

        [Parameter(Mandatory = $false)][ValidateSet("Custom","Gallery")]
        [string]$ImageType = "Gallery",

        [parameter(Mandatory = $true)][string]$ImageId,

        [parameter(Mandatory = $false)][bool]$EnableSingleSignOn,

        [Parameter(Mandatory = $false)][ValidateSet('notManaged','starterManaged')]
        [string]$WindowsAutopatch = "notManaged",

        [parameter(Mandatory = $false)][ValidateSet('AzureADJoin','hybridAzureADJoin')]
        [string]$DomainJoinType = 'AzureADJoin',

        [parameter(Mandatory = $true, ParameterSetName = 'AzureADJoin')]
        [string]$RegionName,

        [parameter(Mandatory = $true, ParameterSetName = 'AzureADJoin')]
        [string]$RegionGroup,

        [parameter(Mandatory = $true, ParameterSetName = 'AzureNetwork')]
        [string]$OnPremisesConnectionId,

        [parameter(Mandatory = $false)][string]$Language = 'en-US'
        # TODO: Add SupportsShouldProcess 
    )

    
    begin {
        Get-TokenValidity

        $Policy = Get-CPCProvisioningPolicy -Name $Name -ErrorAction SilentlyContinue

        if ($Policy) {
            Write-Error "Provisioning Policy $Name already exists"
            break
        }

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies"
    }

    Process {

        If ($WindowsAutopatch -eq "notManaged") {
            $WindowsAutopatchprofile = ""
        }
        Else {
            $WindowsAutopatchprofile = $null
        }

        $params = @{
            DisplayName = $Name
            Description = $Description
            ProvisioningType = $ProvisioningType
            ManagedBy = $ManagedBy
            ImageId = $ImageId
            ImageType = $ImageType
            enableSingleSignOn = $EnableSingleSignOn
            DomainJoinConfiguration = @{
                Type = $DomainJoinType
            }
            MicrosoftManagedDesktop = @{
                Type = $WindowsAutopatch
                Profile = $WindowsAutopatchprofile
            }
            WindowsSettings = @{
                Language = $Language
            }
        }

        If ($DomainJoinType -eq "AzureADJoin") {
            $params.DomainJoinConfiguration.Add("RegionName", "$RegionName")
            $params.DomainJoinConfiguration.Add("RegionGroup", "$RegionGroup")
        }
        Else {
            $params.DomainJoinConfiguration.Add("OnPremisesConnectionId", "$OnPremisesConnectionId")
        }

        $body = $params | ConvertTo-Json -Depth 10

        Write-Verbose $body

        try {
            Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $body
        }
        catch {
            Throw $_.Exception.Message
        }
        
    }
}