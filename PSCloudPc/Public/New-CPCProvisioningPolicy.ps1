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
    Enter the Provisioning Type of the Provisioning Policy (dedicated, sharedByUser or sharedByEntraGroup) (Default: dedicated)
    .PARAMETER ManagedBy
    Enter the Managed By of the Provisioning Policy (Windows365 or Microsoft) (Default: Windows365)
    .PARAMETER imageType
    Enter the image type of the Provisioning Policy (Custom or Gallery)
    .PARAMETER ImageId
    Enter the Image Id of the Provisioning Policy (Info: Get-CPCGalleryImage or Get-CPCCustomImage)
    .PARAMETER EnableSingleSignOn
    Enable or disable single sign-on for the Cloud PCs ($true or $false). $true is only supported with DomainJoinType azureADJoin
    .PARAMETER DomainJoinType
    Enter the Domain Join Type for the Provisioning Policy (azureADJoin or hybridAzureADJoin) (Default: azureADJoin). With a Microsoft hosted network (RegionName/RegionGroup) only azureADJoin is supported. With -AzureNetworkConnection the join type follows the connectionType of the connection.
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
    .PARAMETER WindowsAutopatchGroupId
    Enter the Windows Autopatch Group Id for the Provisioning Policy (Info: Get-CPCWindowsAutopatchGroup)
    .PARAMETER userExperience
    Enter the User Experience for the Provisioning Policy (cloudPc or cloudApp) (Default: cloudPc)
    .EXAMPLE
    New-CPCProvisioningPolicy -Name "Test-AzureADJoin" -Description "Test-AzureADJoin" -imageType "Gallery" -ImageId "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc" -DomainJoinType "AzureADJoin" -EnableSingleSignOn $true -RegionName "westeurope" -RegionGroup "europeUnion" -Language "en-US"
    .EXAMPLE
    New-CPCProvisioningPolicy -Name "Test-HybridADJoin" -Description "Test-HybridADJoin" -imageType "Gallery" -ImageId "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc" -DomainJoinType "hybridAzureADJoin" -EnableSingleSignOn $false -AzureNetworkConnection "Azure Network Connection" -Language "en-US"
    .EXAMPLE
    New-CPCProvisioningPolicy -Name "Test-Autopatch" -Description "Test-Autopatch" -imageType "Gallery" -ImageId "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc" -WindowsAutopatch "starterManaged" -DomainJoinType "AzureADJoin" -RegionName "westeurope" -RegionGroup "europeUnion" -Language "en-US" -EnableSingleSignOn $true
    .EXAMPLE
    New-CPCProvisioningPolicy -Name "Test-NamingTemplate" -Description "Test-NamingTemplate" -imageType "Gallery" -ImageId "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc" -WindowsAutopatch "starterManaged" -DomainJoinType "AzureADJoin" -RegionName "westeurope" -RegionGroup "europeUnion" -Language "en-US" -EnableSingleSignOn $true -NamingTemplate "%USERNAME:5%-%RAND:5%"
    .EXAMPLE
    New-CPCProvisioningPolicy -Name "Test-CloudApps" -Description "Test-AzureADJoin" -imageType "Gallery" -ImageId "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc" -DomainJoinType "AzureADJoin" -EnableSingleSignOn $true -RegionName "northeurope" -RegionGroup "europeUnion" -Language "en-US" -ProvisioningType sharedByEntraGroup -userExperience cloudApp
    .NOTES
    Required permission: CloudPC.ReadWrite.All
    https://learn.microsoft.com/graph/api/virtualendpoint-post-provisioningpolicies?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcprovisioningpolicy?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcdomainjoinconfiguration?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'MicrosoftHosted', SupportsShouldProcess = $true)]
    param (
        [parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$Description,

        [ValidateSet('dedicated', 'sharedByUser', 'sharedByEntraGroup')]
        [string]$ProvisioningType = "dedicated",

        [parameter(Mandatory = $false)]
        [string]$NamingTemplate,

        [parameter(ParameterSetName = 'MicrosoftHosted')]
        [parameter(ParameterSetName = 'AzureNetwork')]
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
        [string]$UserExperience = "cloudPc",

        [parameter(Mandatory = $false)]
        [string]$Language = 'en-US'
    )

    begin {
        Get-TokenValidity

        $Policy = Get-CPCProvisioningPolicy -Name $Name -ErrorAction SilentlyContinue

        if ($Policy) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Provisioning Policy with name $Name already exists" -Category ResourceExists
        }

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies"

        # Single sign-on is only supported for Microsoft Entra joined Cloud PCs
        if ($DomainJoinType -ne 'azureADJoin' -and $EnableSingleSignOn) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "The parameter -EnableSingleSignOn can only be used with -DomainJoinType 'azureADJoin'."
        }

        # A Microsoft hosted network (regionName) can only be used with azureADJoin; hybridAzureADJoin needs an Azure Network Connection
        if ($PSCmdlet.ParameterSetName -eq 'MicrosoftHosted' -and $DomainJoinType -ne 'azureADJoin') {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "DomainJoinType 'hybridAzureADJoin' requires -AzureNetworkConnection; a Microsoft hosted network (RegionName/RegionGroup) only supports 'azureADJoin'."
        }

        If (($ProvisioningType -ne "sharedByEntraGroup") -and ($UserExperience -eq "cloudApp")) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "The parameter provisioning type must be 'sharedByEntraGroup' when user experience is 'cloudApp'."
        }

        If ($WindowsAutopatch -eq "starterManaged" -and [string]::IsNullOrWhiteSpace($WindowsAutopatchGroupId)) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "The parameter -WindowsAutopatchGroupId is required when -WindowsAutopatch is 'starterManaged'."
        }
    }

    Process {

        $domainJoinConfigurations = @()

        If ($AzureNetworkConnection) {
            foreach ($Network in $AzureNetworkConnection) {

                $AzureNetworkInfo = @(Get-CPCAzureNetworkConnection -Name $Network)

                If ($AzureNetworkInfo.Count -eq 0) {
                    Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No Azure Network Connection found with name $Network" -Category ObjectNotFound
                }

                If ($AzureNetworkInfo.Count -gt 1) {
                    Stop-CPCCommand -Cmdlet $PSCmdlet -Message "$($AzureNetworkInfo.Count) Azure Network Connections found with name $Network ($($AzureNetworkInfo.id -join ', ')). The name must match exactly one connection."
                }

                $AzureNetworkInfo = $AzureNetworkInfo[0]

                # Cloud PCs can be provisioned when the health check passed, or passed with a warning or informational result
                # https://learn.microsoft.com/graph/api/resources/cloudpconpremisesconnection?view=graph-rest-beta#cloudpconpremisesconnectionstatus-values
                if ($AzureNetworkInfo.healthCheckStatus -notin @("passed", "warning", "informational")) {
                    Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Azure Network Connection $Network is not healthy (healthCheckStatus: $($AzureNetworkInfo.healthCheckStatus))" -Category InvalidOperation
                }

                # The join type of the policy follows the connectionType of the connection (type stopped returning data on January 31, 2024)
                $JoinType = $AzureNetworkInfo.connectionType
                If ([string]::IsNullOrWhiteSpace($JoinType)) {
                    $JoinType = $DomainJoinType
                }

                if ($JoinType -ne 'azureADJoin' -and $EnableSingleSignOn) {
                    Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Azure Network Connection $Network is of type '$JoinType'; -EnableSingleSignOn `$true is only supported with 'azureADJoin' connections."
                }

                Write-Verbose "AzureNetworkConnection ID: $($AzureNetworkInfo.Id), join type: $JoinType"
                $domainJoinConfigurations += @{
                    domainJoinType         = $JoinType
                    type                   = $JoinType
                    onPremisesConnectionId = $AzureNetworkInfo.Id
                }
            }
        }
        else {
            $domainJoinConfigurations += @{
                domainJoinType = $DomainJoinType
                type           = $DomainJoinType
                regionName     = $RegionName
                regionGroup    = $RegionGroup
            }
        }

        $params = @{
            displayName              = $Name
            description              = $Description
            provisioningType         = $ProvisioningType
            managedBy                = $ManagedBy
            imageId                  = $ImageId
            imageType                = $ImageType
            enableSingleSignOn       = $EnableSingleSignOn
            domainJoinConfigurations = $domainJoinConfigurations
            microsoftManagedDesktop  = @{
                managedType = $WindowsAutopatch
                profile     = $null
            }
            windowsSettings          = @{
                language = $Language
            }
            windowsSetting           = @{
                locale = $Language
            }
            cloudPcNamingTemplate    = $NamingTemplate
            autopatch                = $null
            autopilotConfiguration   = $null
            userExperienceType       = $UserExperience
        }

        If ($WindowsAutopatch -eq "starterManaged") {
            $params.autopatch = @{
                autopatchGroupId = $WindowsAutopatchGroupId
            }
        }

        if ($NamingTemplate) {
            Write-Verbose "Naming template: $NamingTemplate"
            $params.cloudPcNamingTemplate = $NamingTemplate
        }
        Else {
            if ($ProvisioningType -eq "sharedByEntraGroup") {
                Write-Verbose "A sharedByEntraGroup provisioning policy can't use a naming template."
                $params.cloudPcNamingTemplate = $null
            }
            else {
                Write-Verbose "Naming template not set, setting default CPC-%USERNAME:5%-%RAND:5%"
                $params.cloudPcNamingTemplate = "CPC-%USERNAME:5%-%RAND:5%"
            }
        }

        $body = $params | ConvertTo-Json -Depth 10

        Write-Verbose $body

        if ($PSCmdlet.ShouldProcess($Name, "Create Provisioning Policy")) {
            try {
                $Result = Invoke-WebRequest -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json" -Body $body
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }

            $NewPolicy = $Result.Content | ConvertFrom-Json

            Write-Verbose "Policy ID: $($NewPolicy.id)"

            return $NewPolicy
        }
    }
}
