function New-CPCProvisioningPolicy {
    <#
    .SYNOPSIS
    Adds a new Provisioning Policy
    .DESCRIPTION
    The function will add a new Provisioning Policy and returns the created policy as Microsoft Graph stores it
    (read back after the create, so shared provisioning types and managedBy are shown as stored).

    Use -RegionName for a Microsoft-hosted network (Microsoft Entra join only), or -AzureNetworkConnection (names) or
    -AzureNetworkConnectionId (ids) for one or more Azure network connections (Microsoft Entra join or hybrid
    Microsoft Entra join). The order of the Azure network connections is their priority.

    The policy is created with the current Graph properties only: windowsSetting.locale, domainJoinConfigurations
    with domainJoinType and microsoftManagedDesktop.managedType. The deprecated windowsSettings, the deprecated type
    properties and the non-existent userSettingsPersistenceEnabled are not sent.
    .PARAMETER Name
    Enter the name of the Provisioning Policy. The name must be unique.
    .PARAMETER Description
    Enter the description of the Provisioning Policy
    .PARAMETER ProvisioningType
    Enter the Provisioning Type of the Provisioning Policy (dedicated, sharedByUser or sharedByEntraGroup) (Default: dedicated). The create API doesn't document reserve, so it isn't offered.
    .PARAMETER NamingTemplate
    Apply device name template. Create unique names for your devices. Names must be between 5 and 15 characters, and can contain letters, numbers, hyphens, and underscores. Names cannot include a blank space. Use the %USERNAME:x% macro to add the first x letters of username. Use the %RAND:y% macro to add a random alphanumeric string of length y, y must be 5 or more. Names must contain a randomized string. (Default: CPC-%USERNAME:5%-%RAND:5%, not used for sharedByEntraGroup)
    .PARAMETER DomainJoinType
    Enter the Domain Join Type for the Provisioning Policy (azureADJoin or hybridAzureADJoin) (Default: azureADJoin). A Microsoft-hosted network (-RegionName) only supports azureADJoin; hybridAzureADJoin needs -AzureNetworkConnection.
    .PARAMETER RegionName
    Enter the Region Name for a Microsoft-hosted network, for example westeurope (Info: Get-CPCSupportedRegion)
    .PARAMETER RegionGroup
    Enter the Region Group for the Provisioning Policy. Optional: Graph documents regionGroup as read-only and derives it from the region, so a warning is shown when the stored region group differs from this value.
    .PARAMETER AzureNetworkConnection
    Enter the name of one or more Azure Network Connections for the Provisioning Policy, in order of priority. Each name must match exactly one connection, its connectionType must be -DomainJoinType and its health check must be passed, warning or informational (failed, pending and running stop the command).
    .PARAMETER ManagedBy
    Enter the service that manages the Provisioning Policy (Default: windows365)
    .PARAMETER ImageType
    Enter the image type of the Provisioning Policy (Custom or Gallery) (Default: Gallery)
    .PARAMETER ImageId
    Enter the Image Id of the Provisioning Policy (Info: Get-CPCGalleryImage or Get-CPCCustomImage)
    .PARAMETER EnableSingleSignOn
    Enable Microsoft Entra single sign-on for the Provisioning Policy, for Microsoft Entra join and hybrid Microsoft Entra join (Default: $false)
    .PARAMETER WindowsAutopatch
    Enter the Windows Autopatch for the Provisioning Policy (notManaged or starterManaged) (Default: notManaged)
    .PARAMETER WindowsAutopatchGroupId
    Enter the Windows Autopatch Group Id for the Provisioning Policy, used with -WindowsAutopatch starterManaged (Info: Get-CPCWindowsAutopatchGroup)
    .PARAMETER UserExperience
    Enter the User Experience for the Provisioning Policy (cloudPc or cloudApp) (Default: cloudPc). cloudApp requires -ProvisioningType sharedByEntraGroup.
    .PARAMETER Language
    Enter the Windows language and region (locale) for the Provisioning Policy (Default: en-US)
    .PARAMETER AzureNetworkConnectionId
    Enter the id of one or more Azure Network Connections for the Provisioning Policy, in order of priority. Use it instead of -AzureNetworkConnection when connection names aren't unique. The same checks apply.
    .OUTPUTS
    The created cloudPcProvisioningPolicy object, including its id.
    .EXAMPLE
    New-CPCProvisioningPolicy -Name "Test-AzureADJoin" -Description "Test-AzureADJoin" -imageType "Gallery" -ImageId "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc" -DomainJoinType "AzureADJoin" -EnableSingleSignOn $true -RegionName "westeurope" -RegionGroup "europeUnion" -Language "en-US"
    .EXAMPLE
    New-CPCProvisioningPolicy -Name "Test-HybridADJoin" -Description "Test-HybridADJoin" -imageType "Gallery" -ImageId "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc" -DomainJoinType "hybridAzureADJoin" -EnableSingleSignOn $false -AzureNetworkConnection "Azure Network Connection" -Language "en-US"
    .EXAMPLE
    New-CPCProvisioningPolicy -Name "Test-Autopatch" -Description "Test-Autopatch" -imageType "Gallery" -ImageId "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc" -WindowsAutopatch "starterManaged" -WindowsAutopatchGroupId "00000000-0000-0000-0000-000000000000" -DomainJoinType "AzureADJoin" -RegionName "westeurope" -Language "en-US" -EnableSingleSignOn $true
    .EXAMPLE
    New-CPCProvisioningPolicy -Name "Test-NamingTemplate" -Description "Test-NamingTemplate" -imageType "Gallery" -ImageId "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc" -DomainJoinType "AzureADJoin" -RegionName "westeurope" -RegionGroup "europeUnion" -Language "en-US" -EnableSingleSignOn $true -NamingTemplate "%USERNAME:5%-%RAND:5%"
    .EXAMPLE
    New-CPCProvisioningPolicy -Name "Test-CloudApps" -Description "Test-AzureADJoin" -imageType "Gallery" -ImageId "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc" -DomainJoinType "AzureADJoin" -EnableSingleSignOn $true -RegionName "northeurope" -RegionGroup "europeUnion" -Language "en-US" -ProvisioningType sharedByEntraGroup -userExperience cloudApp
    .EXAMPLE
    New-CPCProvisioningPolicy -Name "Test-AzureADJoin" -ImageId "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc" -DomainJoinType "AzureADJoin" -RegionName "westeurope" -WhatIf
    .EXAMPLE
    New-CPCProvisioningPolicy -Name "Test-HybridById" -ImageId "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc" -DomainJoinType "hybridAzureADJoin" -AzureNetworkConnectionId "00000000-0000-0000-0000-000000000000"
    .NOTES
    Required permission: CloudPC.ReadWrite.All
    Setting -WindowsAutopatchGroupId (autopatch) requires a delegated token and a signed-in user with the Intune Administrator role.
    https://learn.microsoft.com/graph/api/virtualendpoint-post-provisioningpolicies?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcprovisioningpolicy?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcdomainjoinconfiguration?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcwindowssetting?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/microsoftmanageddesktop?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpconpremisesconnection?view=graph-rest-beta
    https://learn.microsoft.com/graph/best-practices-concept#handling-future-members-in-evolvable-enumerations
    https://learn.microsoft.com/windows-365/enterprise/configure-single-sign-on
    #>
    [CmdletBinding(DefaultParameterSetName = 'AzureADJoin', SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$Description,

        [ValidateSet('dedicated', 'sharedByUser', 'sharedByEntraGroup')]
        [string]$ProvisioningType = "dedicated",

        [parameter(Mandatory = $false)]
        [string]$NamingTemplate,

        [parameter(Mandatory = $true, ParameterSetName = 'MicrosoftHosted')]
        [parameter(Mandatory = $true, ParameterSetName = 'AzureNetwork')]
        [parameter(Mandatory = $true, ParameterSetName = 'AzureNetworkId')]
        [ValidateSet('azureADJoin', 'hybridAzureADJoin')]
        [string]$DomainJoinType = 'azureADJoin',

        [parameter(Mandatory = $true, ParameterSetName = 'MicrosoftHosted')]
        [ValidateNotNullOrEmpty()]
        [string]$RegionName,

        [parameter(Mandatory = $false, ParameterSetName = 'MicrosoftHosted')]
        [string]$RegionGroup,

        [parameter(Mandatory = $true, ParameterSetName = 'AzureNetwork')]
        [ValidateNotNullOrEmpty()]
        [object]$AzureNetworkConnection,

        [Parameter(mandatory = $false)]
        [string]$ManagedBy = "windows365",

        [Parameter(Mandatory = $false)]
        [ValidateSet("Custom", "Gallery")]
        [string]$ImageType = "Gallery",

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ImageId,

        [parameter(Mandatory = $false)]
        [bool]$EnableSingleSignOn = $false,

        [Parameter(Mandatory = $false)]
        [ValidateSet('notManaged', 'starterManaged')]
        [string]$WindowsAutopatch = "notManaged",

        [parameter(Mandatory = $false)]
        [string]$WindowsAutopatchGroupId,

        [Parameter(Mandatory = $false)]
        [ValidateSet('cloudApp', 'cloudPc')]
        [string]$UserExperience = "cloudPc",

        [parameter(Mandatory = $false)]
        [string]$Language = 'en-US',

        [parameter(Mandatory = $true, ParameterSetName = 'AzureNetworkId')]
        [ValidateNotNullOrEmpty()]
        [string[]]$AzureNetworkConnectionId
    )

    begin {
        Get-TokenValidity

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/provisioningPolicies"

        # domainJoinConfigurations is required: a Microsoft-hosted network (regionName) or Azure network connections (onPremisesConnectionId)
        # https://learn.microsoft.com/graph/api/resources/cloudpcdomainjoinconfiguration?view=graph-rest-beta
        If ($PSCmdlet.ParameterSetName -eq 'AzureADJoin') {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Specify -RegionName for a Microsoft-hosted network or -AzureNetworkConnection for an Azure network connection"
        }

        If ($PSCmdlet.ParameterSetName -eq 'MicrosoftHosted' -and $DomainJoinType -ne 'azureADJoin') {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "A Microsoft-hosted network (-RegionName) only supports -DomainJoinType azureADJoin. Use -AzureNetworkConnection for $DomainJoinType"
        }

        If (($ProvisioningType -ne "sharedByEntraGroup") -and ($UserExperience -eq "cloudApp")) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "The parameter provisioning type must be 'sharedByEntraGroup' when user experience is 'cloudApp'."
        }

        If (-not [string]::IsNullOrWhiteSpace($WindowsAutopatchGroupId) -and $WindowsAutopatch -ne "starterManaged") {
            Write-Warning "WindowsAutopatchGroupId is only used with -WindowsAutopatch starterManaged and is not sent"
        }

        # provisioningType sharedByUser/sharedByEntraGroup are evolvable enum members after unknownFutureValue
        # https://learn.microsoft.com/graph/best-practices-concept#handling-future-members-in-evolvable-enumerations
        $PreferHeader = @{ Prefer = "include-unknown-enum-members" }

        # Graph rejects a second policy with the same name; check first for a clear message.
        # displayName isn't documented as filterable, so match on the client.
        Write-Verbose "Checking for an existing Provisioning Policy named '$Name'"
        try {
            $ExistingPolicy = @(Invoke-APIRequest -uri "$($url)?`$select=id,displayName" -Token $script:Authtoken -Method GET -AdditionalHeaders $PreferHeader | Where-Object { $_.displayName -eq $Name })
        }
        catch {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message (Get-GraphErrorMessage $_) -Category InvalidOperation
        }

        If ($ExistingPolicy.Count -gt 0) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "Provisioning Policy with name '$Name' already exists ($($ExistingPolicy.id -join ', '))" -Category ResourceExists
        }

        If ($PSCmdlet.ParameterSetName -eq 'AzureNetwork') {
            # hybridAzureADJoin requires onPremisesConnectionId and no regionName; connectionType must match -DomainJoinType
            $domainJoinConfigurations = @(Resolve-CPCAzureNetworkConnection -Cmdlet $PSCmdlet -Name @($AzureNetworkConnection | ForEach-Object { [string]$_ }) -DomainJoinType $DomainJoinType)
        }
        ElseIf ($PSCmdlet.ParameterSetName -eq 'AzureNetworkId') {
            $domainJoinConfigurations = @(Resolve-CPCAzureNetworkConnection -Cmdlet $PSCmdlet -Id $AzureNetworkConnectionId -DomainJoinType $DomainJoinType)
        }
        Else {
            $domainJoinConfig = @{
                domainJoinType = $DomainJoinType
                regionName     = $RegionName
            }

            # regionGroup is documented as read-only (Graph derives it from regionName); only sent when passed
            If (-not [string]::IsNullOrWhiteSpace($RegionGroup)) {
                $domainJoinConfig["regionGroup"] = $RegionGroup
            }

            $domainJoinConfigurations = @($domainJoinConfig)
        }
    }

    Process {
        $params = [ordered]@{
            displayName              = $Name
            provisioningType         = $ProvisioningType
            managedBy                = $ManagedBy
            imageId                  = $ImageId
            imageType                = $ImageType.ToLowerInvariant()
            enableSingleSignOn       = $EnableSingleSignOn
            domainJoinConfigurations = $domainJoinConfigurations
            microsoftManagedDesktop  = @{
                managedType = $WindowsAutopatch
            }
            windowsSetting           = @{
                locale = $Language
            }
            userExperienceType       = $UserExperience
        }

        If ($PSBoundParameters.ContainsKey("Description")) {
            $params["description"] = $Description
        }

        If ($WindowsAutopatch -eq "starterManaged" -and -not [string]::IsNullOrWhiteSpace($WindowsAutopatchGroupId)) {
            $params["autopatch"] = @{
                autopatchGroupId = $WindowsAutopatchGroupId
            }
        }

        if ($NamingTemplate) {
            Write-Verbose "Naming template: $NamingTemplate"
            $params["cloudPcNamingTemplate"] = $NamingTemplate
        }
        Else {
            if ($ProvisioningType -eq "sharedByEntraGroup") {
                Write-Verbose "A sharedByEntraGroup provisioning type doesn't use a naming template."
            }
            else {
                Write-Verbose "Naming template not set, setting default CPC-%USERNAME:5%-%RAND:5%"
                $params["cloudPcNamingTemplate"] = "CPC-%USERNAME:5%-%RAND:5%"
            }
        }

        $body = $params | ConvertTo-Json -Depth 10

        Write-Verbose "POST $url"
        Write-Verbose "Request Body: $body"

        # Send the Prefer header when the body uses an evolvable enum member, so the response doesn't map it to unknownFutureValue
        $PostHeaders = $script:Authheader.Clone()
        If ($ProvisioningType -in @("sharedByUser", "sharedByEntraGroup")) {
            $PostHeaders["Prefer"] = $PreferHeader.Prefer
        }

        If ($PSCmdlet.ShouldProcess($Name, "Create Provisioning Policy")) {
            try {
                $Policy = Invoke-RestMethod -Uri $url -Method POST -Headers $PostHeaders -Body $body -ContentType "application/json" -ErrorAction Stop
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }

            Write-Verbose "Policy ID: $($Policy.id)"

            # The POST response leaves out some stored values (managedBy came back empty), so return the policy as Graph stores it.
            # The policy is created at this point: if the read fails, warn and return the POST response instead of failing.
            If (-not [string]::IsNullOrWhiteSpace($Policy.id)) {
                $PolicyUrl = "$url/$([uri]::EscapeDataString($Policy.id))"
                Write-Verbose "GET $PolicyUrl"
                try {
                    $Policy = Invoke-APIRequest -uri $PolicyUrl -Token $script:Authtoken -Method GET -AdditionalHeaders $PreferHeader
                }
                catch {
                    Write-Warning "Provisioning Policy '$Name' was created ($($Policy.id)), but reading it back failed: $(Get-GraphErrorMessage $_)"
                }
            }

            # Graph derives the stored regionGroup from the region and doesn't report a different value as an error
            If (-not [string]::IsNullOrWhiteSpace($RegionGroup)) {
                $StoredRegionGroup = @($Policy.domainJoinConfigurations)[0].regionGroup
                If (-not [string]::IsNullOrWhiteSpace($StoredRegionGroup) -and $StoredRegionGroup -ne $RegionGroup) {
                    Write-Warning "Provisioning Policy '$Name' was created with region group '$StoredRegionGroup' instead of '$RegionGroup'. Graph sets the region group from region '$RegionName'."
                }
            }

            $Policy
        }
    }
}
