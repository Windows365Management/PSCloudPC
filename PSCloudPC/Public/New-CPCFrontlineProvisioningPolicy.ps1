function New-CPCFrontlineProvisioningPolicy {
    <#
    .SYNOPSIS
    Adds a new Frontline Provisioning Policy
    .DESCRIPTION
    The function will add a new Frontline Provisioning Policy
    .PARAMETER Name
    Enter the name of the Frontline Provisioning Policy
    .PARAMETER Description
    Enter the description of the Frontline Provisioning Policy
    .PARAMETER ProvisioningType
    Enter the Provisioning Type of the Frontline Provisioning Policy (dedicated or shared) (Default: dedicated)
    .PARAMETER ManagedBy
    Enter the Managed By of the Frontline Provisioning Policy (Windows365 or Microsoft) (Default: Windows365)
    .PARAMETER imageType
    Enter the image type of the Frontline Provisioning Policy (Custom or Gallery)
    .PARAMETER ImageId
    Enter the Image Id of the Frontline Provisioning Policy (Info: Get-CPCGalleryImage or Get-CPCCustomImage)
    .PARAMETER EnableSignleSignOn
    Enter the Enable Signle Sign On for the Frontline Provisioning Policy
    .PARAMETER DomainJoinType
    Enter the Domain Join Type for the Frontline Provisioning Policy (AzureADJoin or AzureADDomainJoin) (Default: AzureADJoin)
    .PARAMETER RegionName
    Enter the Region Name for the Frontline Provisioning Policy
    .PARAMETER RegionGroup
    Enter the Region Group for the Frontline Provisioning Policy
    .PARAMETER AzureNetworkConnection
    Enter the Azure Network Connection Name for the Frontline Provisioning Policy
    .PARAMETER Language
    Enter the Language for the Provisioning Policy (Default: en-US)
    .PARAMETER NamingTemplate
    Apply device name template. Create unique names for your devices. Names must be between 5 and 15 characters, and can contain letters, numbers, hyphens, and underscores. Names cannot include a blank space. Use the %USERNAME:x% macro to add the first x letters of username. Use the %RAND:y% macro to add a random alphanumeric string of length y, y must be 5 or more. Names must contain a randomized string.
    .EXAMPLE
    New-CPCFrontlineProvisioningPolicy -Name "Test-AzureADJoin" -Description "Test-AzureADJoin" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365" -DomainJoinType "AzureADJoin" -EnableSingleSignOn $true -RegionName "westeurope" -RegionGroup "europeUnion" -Language "en-US"  -GroupName "All Users" -ServicePlanName "Cloud PC Frontline 2vCPU/8GB/128GB"
    .EXAMPLE
    New-CPCFrontlineProvisioningPolicy -Name "Test-HybridADJoin" -Description "Test-HybridADJoin" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365" -DomainJoinType "hybridAzureADJoin" -EnableSingleSignOn $false -AzureNetworkConnection "Azure Network Connection" -Language "en-US"  -GroupName "All Users" -ServicePlanName "Cloud PC Frontline 2vCPU/8GB/128GB"
    .EXAMPLE
    New-CPCFrontlineProvisioningPolicy -Name "Test-Autopatch" -Description "Test-Autopatch" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365" -WindowsAutopatch "starterManaged" -DomainJoinType "AzureADJoin" -RegionName "westeurope" -RegionGroup "europeUnion" -Language "en-US" -EnableSingleSignOn $true -GroupName "All Users" -ServicePlanName "Cloud PC Frontline 2vCPU/8GB/128GB"
    .EXAMPLE
    New-CPCFrontlineProvisioningPolicy -Name "Test-NamingTemplate" -Description "Test-NamingTemplate" -imageType "Gallery" -ImageId "MicrosoftWindowsDesktop_windows-ent-cpc_win11-22h2-ent-cpc-m365" -WindowsAutopatch "starterManaged" -DomainJoinType "AzureADJoin" -RegionName "westeurope" -RegionGroup "europeUnion" -Language "en-US" -EnableSingleSignOn $true -NamingTemplate "%USERNAME:5%-%RAND:5%"  -GroupName "All Users" -ServicePlanName "Cloud PC Frontline 2vCPU/8GB/128GB"
    #>
    [CmdletBinding(DefaultParameterSetName = 'AzureADJoin')]
    param (
        [parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [ValidateSet('dedicated', 'shared')]
        [string]$ProvisioningType = "shared",

        [parameter(Mandatory = $false)]
        [string]$NamingTemplate,

        [parameter(Mandatory, ParameterSetName = 'MicrosoftHosted')]
        [parameter(Mandatory, ParameterSetName = 'AzureNetwork')]
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

        [parameter(Mandatory = $true)][string]$ImageId,

        [parameter(Mandatory = $true)]
        [bool]$EnableSingleSignOn,

        [Parameter(Mandatory = $false)][ValidateSet('notManaged', 'starterManaged')]
        [string]$WindowsAutopatch = "notManaged",

        [parameter(Mandatory = $false)]
        [string]$Language = 'en-US',

        [parameter(Mandatory = $true)]
        [string]$GroupName,

        [parameter(Mandatory = $true)]
        [string]$ServicePlanName

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

        Get-AzureADGroupID -GroupName $GroupName

        If ($null -eq $script:GroupID) {
            Throw "No group found with name $GroupName"
            return
        }

        $ServicePlan = Get-CPCServicePlan -ServicePlanName $ServicePlanName

        If ($null -eq $ServicePlan) {
            Throw "No Service Plan found with name $ServicePlanName"
            return
        }
    }

    Process {

        If ($WindowsAutopatch -eq "notManaged") {
            $WindowsAutopatchprofile = ""
        }
        Else {
            $WindowsAutopatchprofile = $null
        }
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
                    break
                }

                if ($AzureNetworkInfo.healthCheckStatus -ne "passed") {
                    Throw "Azure Network Connection $Network is not healthy"
                    break
                }

                Write-Verbose "AzureNetworkConnection ID: $($AzureNetworkInfo.Id)"
                $domainJoinConfig = @{
                    Type                   = $AzureNetworkInfo.Type
                    OnPremisesConnectionId = $AzureNetworkInfo.Id
                }
                $domainJoinConfigurations += $domainJoinConfig
                $domainjoinparameter = "DomainJoinConfigurations"
            }
        }

        else {
            $domainJoinConfig = @{
                Type        = "$DomainJoinType"
                RegionName  = $RegionName
                RegionGroup = $RegionGroup
            }
            $domainJoinConfigurations += $domainJoinConfig
            $domainjoinparameter = "DomainJoinConfiguration"
        }

        $params = @{
            DisplayName             = $Name
            Description             = $Description
            ProvisioningType        = $ProvisioningType
            ManagedBy               = $ManagedBy
            ImageId                 = $ImageId
            ImageType               = $ImageType
            enableSingleSignOn      = $EnableSingleSignOn
            $domainjoinparameter    = $domainJoinConfigurations
            MicrosoftManagedDesktop = @{
                Type    = $WindowsAutopatch
                Profile = $WindowsAutopatchprofile
            }
            WindowsSettings         = @{
                Language = $Language
            }
            cloudPcNamingTemplate   = $NamingTemplate
        }
        $body = $params | ConvertTo-Json -Depth 10


        Write-Verbose $body

        try {
            $Result = Invoke-WebRequest -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $body -SkipHttpErrorCheck
        }
        catch {
            Throw $_.Exception.Message
        }

        $PolicyId = ($Result.Content | ConvertFrom-Json).id
        
        Write-Verbose "Policy ID: $($PolicyId)"


        Write-Verbose "Assigning provisioning policy to group $GroupName"

        $assignmentparams = @{
            assignments = @(
                @{
                    target = @{
                        groupId = $script:GroupID
                        servicePlanId = $($ServicePlan.Id)
                    }
                }
            )
        }
        $assignmentbody = $assignmentparams | ConvertTo-Json -Depth 10

        Write-Verbose $assignmentbody

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies/$($PolicyId)/assign"

        Write-Verbose $url

        try {
            $Result = Invoke-WebRequest -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $assignmentbody -SkipHttpErrorCheck
        }
        catch {
            Throw $_.Exception.Message
        }
        
    }
}