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
    .PARAMETER AzureNetworkConnection
    Enter the Azure Network Connection Name for the Provisioning Policy
    .PARAMETER Language
    Enter the Language for the Provisioning Policy (Default: en-US)
    .PARAMETER NamingTemplate
    Apply device name template. Create unique names for your devices. Names must be between 5 and 15 characters, and can contain letters, numbers, hyphens, and underscores. Names cannot include a blank space. Use the %USERNAME:x% macro to add the first x letters of username. Use the %RAND:y% macro to add a random alphanumeric string of length y, y must be 5 or more. Names must contain a randomized string.
    .PARAMETER WindowsAutopatch
    Enter the Windows Autopatch for the Provisioning Policy (notManaged or starterManaged) (Default: notManaged)
    .EXAMPLE
    New-CPCProvisioningPolicy -Name "Test-AzureADJoin" -Description "Test-AzureADJoin" -imageType "Gallery" -ImageId "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc" -DomainJoinType "AzureADJoin" -EnableSingleSignOn $true -RegionName "westeurope" -RegionGroup "europeUnion" -Language "en-US"
    .EXAMPLE
    New-CPCProvisioningPolicy -Name "Test-HybridADJoin" -Description "Test-HybridADJoin" -imageType "Gallery" -ImageId "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc" -DomainJoinType "hybridAzureADJoin" -EnableSingleSignOn $false -AzureNetworkConnection "Azure Network Connection" -Language "en-US"
    .EXAMPLE
    New-CPCProvisioningPolicy -Name "Test-Autopatch" -Description "Test-Autopatch" -imageType "Gallery" -ImageId "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc" -WindowsAutopatch "starterManaged" -DomainJoinType "AzureADJoin" -RegionName "westeurope" -RegionGroup "europeUnion" -Language "en-US" -EnableSingleSignOn $true
    .EXAMPLE
    New-CPCProvisioningPolicy -Name "Test-NamingTemplate" -Description "Test-NamingTemplate" -imageType "Gallery" -ImageId "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc" -WindowsAutopatch "starterManaged" -DomainJoinType "AzureADJoin" -RegionName "westeurope" -RegionGroup "europeUnion" -Language "en-US" -EnableSingleSignOn $true -NamingTemplate "%USERNAME:5%-%RAND:5%"
    #>
    [CmdletBinding(DefaultParameterSetName = 'AzureADJoin')]
    param (
        [parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$Description,

        [ValidateSet('dedicated', 'sharedByUser', 'sharedByEntraGroup')]
        [string]$ProvisioningType = "dedicated",

        [parameter(Mandatory = $false)]
        [string]$NamingTemplate,

        [parameter(Mandatory = $true, ParameterSetName = 'MicrosoftHosted')]
        [parameter(Mandatory = $true, ParameterSetName = 'AzureNetwork')]
        [ValidateSet('azureADJoin', 'hybridAzureADJoin')]
        [string]$DomainJoinType = 'azureADJoin',

        [parameter(Mandatory = $true, ParameterSetName = 'MicrosoftHosted')]
        [string]$RegionName,

        [parameter(Mandatory = $true, ParameterSetName = 'MicrosoftHosted')]
        [string]$RegionGroup,

        [parameter(Mandatory = $true, ParameterSetName = 'AzureNetwork')]
        [object]$AzureNetworkConnection,

        [Parameter(mandatory = $false)]
        [string]$ManagedBy = "Windows365",

        [Parameter(Mandatory = $false)]
        [ValidateSet("Custom", "Gallery")]
        [string]$ImageType = "Gallery",

        [parameter(Mandatory = $true)]
        [string]$ImageId,

        [parameter(Mandatory = $true)]
        [bool]$EnableSingleSignOn,

        [Parameter(Mandatory = $false)]
        [ValidateSet('notManaged', 'starterManaged')]
        [string]$WindowsAutopatch = "notManaged",

        [parameter(Mandatory = $false)]
        [string]$WindowsAutopatchGroupId,

        [Parameter(Mandatory = $false)]
        [ValidateSet('cloudApp', 'cloudPc')]
        [string]$userExperience = "cloudPc",

        [parameter(Mandatory = $false)]
        [string]$Language = 'en-US'
    )

    begin {
        Get-TokenValidity

        $Policy = Get-CPCProvisioningPolicy -Name $Name -ErrorAction SilentlyContinue

        if ($Policy) {
            Write-Error "Provisioning Policy with name $Name already exists"
            break
        }

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies"

        # Validate if DomainJoinType is azureADJoin, then EnableSingleSignOn can be used, otherwise throw an error.
        if ($DomainJoinType -ne 'azureADJoin' -and $PSBoundParameters.ContainsKey('EnableSingleSignOn')) {
            Write-Error "The parameter -EnableSingleSignOn can only be used with -DomainJoinType 'azureADJoin'."
            break
        }

        If (($ProvisioningType -ne "sharedByEntraGroup") -and ($userExperience -eq "cloudApp")) {
            Write-Error "The parameter provisioning type must be 'sharedByEntraGroup' when user experience is 'cloudApp'."
            break
        }
    }

    Process {


        if ($NamingTemplate) {
            Write-Verbose "Naming template: $NamingTemplate"
        }
        Else {
            Write-Verbose "Naming template not set, setting default CPC-%USERNAME:5%-%RAND:5%"
            $NamingTemplate = "CPC-%USERNAME:5%-%RAND:5%"
        }

        If ($AzureNetworkConnection) {
            $domainJoinConfigurations = @()
            foreach ($Network in $AzureNetworkConnection) {

                $AzureNetworkInfo = Get-CPCAzureNetworkConnection -Name $Network

                If ($null -eq $AzureNetworkInfo) {
                    Throw "No Azure Network Connection found with name $Network"
                }

                if ($AzureNetworkInfo.healthCheckStatus -ne "passed") {
                    Throw "Azure Network Connection $Network is not healthy"
                }

                Write-Verbose "AzureNetworkConnection ID: $($AzureNetworkInfo.Id)"
                $domainJoinConfig = @(
                    @{
                        Type                   = $AzureNetworkInfo.Type
                        OnPremisesConnectionId = $AzureNetworkInfo.Id
                    }
                )
                $domainJoinConfigurations += $domainJoinConfig
            }
        }

        else {
            $domainJoinConfig = @(
                @{
                    Type        = "$DomainJoinType"
                    RegionName  = $RegionName
                    RegionGroup = $RegionGroup
                }
            )
            $domainJoinConfigurations += $domainJoinConfig
        }

        $params = @{
            DisplayName                    = $Name
            Description                    = $Description
            ProvisioningType               = $ProvisioningType
            ManagedBy                      = $ManagedBy
            ImageId                        = $ImageId
            ImageType                      = $ImageType
            enableSingleSignOn             = $EnableSingleSignOn
            DomainJoinConfigurations       = $domainJoinConfigurations
            MicrosoftManagedDesktop        = @{
                managedType = $WindowsAutopatch
                type        = $WindowsAutopatch
                profile     = ""
            }
            WindowsSettings                = @{
                Language = $Language
            }
            WindowsSetting                 = @{
                locale = $Language
            }
            cloudPcNamingTemplate          = $NamingTemplate
            autopatch                      = @()
            autopilotConfiguration         = $null
            userExperienceType             = $userExperience
            userSettingsPersistenceEnabled = $false
        }

        If ($WindowsAutopatch -eq "starterManaged") {
            $params.autopatch = @{
                autopatchGroupId = $WindowsAutopatchGroupId
            }
        }
        Else {
            $params.autopatch = @{
                autopatchGroupId = $null
            }
        }

        $body = $params | ConvertTo-Json -Depth 10


        Write-Verbose $body

        try {
            $Result = Invoke-WebRequest -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $body
        }
        catch {
            Throw $_.Exception.Message
        }

        $PolicyId = ($Result.Content | ConvertFrom-Json).id

        Write-Verbose "Policy ID: $($PolicyId)"

    }
}
