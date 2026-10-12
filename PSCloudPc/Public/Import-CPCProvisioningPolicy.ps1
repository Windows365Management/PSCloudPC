Function Import-CPCProvisioningPolicy {
    <#
    .SYNOPSIS
    Imports a Provisioning Policy from a JSON File
    .DESCRIPTION
    The function will import a Provisioning Policy from a JSON File created by Export-CPCProvisioningPolicy and
    creates it with New-CPCProvisioningPolicy. It returns the created policy.

    Both older exports (windowsSettings.language and domainJoinConfigurations.type) and current exports
    (windowsSetting.locale and domainJoinConfigurations.domainJoinType) are read. Azure Network Connections are
    passed to New-CPCProvisioningPolicy by the id in the export (-AzureNetworkConnectionId), so they must exist in
    the tenant you import into. An export with provisioningType unknownFutureValue (read without the
    Prefer: include-unknown-enum-members header) can't be imported, because the real provisioning type is unknown.

    These settings are imported: displayName, description, provisioningType, managedBy, imageType, imageId,
    enableSingleSignOn, domainJoinConfigurations, the Windows locale, cloudPcNamingTemplate, userExperienceType,
    microsoftManagedDesktop.managedType and autopatch.autopatchGroupId.
    .PARAMETER Inputfile
    Enter the path to the JSON File
    .EXAMPLE
    Import-CPCProvisioningPolicy -Inputfile "C:\Temp\AzureADJoinPolicy.json"
    .EXAMPLE
    Import-CPCProvisioningPolicy -Inputfile "./AzureADJoinPolicy.json" -WhatIf
    .NOTES
    Required permission: CloudPC.ReadWrite.All
    https://learn.microsoft.com/graph/api/virtualendpoint-post-provisioningpolicies?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcprovisioningpolicy?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcdomainjoinconfiguration?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/cloudpconpremisesconnection-get?view=graph-rest-beta
    https://learn.microsoft.com/graph/best-practices-concept#handling-future-members-in-evolvable-enumerations
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param (
        [parameter(Mandatory, ParameterSetName = "Name")]
        [ValidateNotNullOrEmpty()]
        [string]$Inputfile
    )

    Begin {
        Get-TokenValidity

        if (-not (Test-Path -Path $Inputfile -PathType Leaf)) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "File not found: $Inputfile" -Category ObjectNotFound
        }

        # Get the JSON File and convert it to a PSObject. Export-CPCProvisioningPolicy writes an array with one policy.
        try {
            $Content = @(Get-Content -Path $Inputfile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop)
        }
        catch {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "InputFile '$Inputfile' is not a valid JSON File: $($_.Exception.Message)" -Category InvalidData
        }

        if ($Content.Count -ne 1 -or $null -eq $Content[0] -or [string]::IsNullOrWhiteSpace($Content[0].displayName)) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "InputFile '$Inputfile' must contain exactly one Provisioning Policy with a displayName" -Category InvalidData
        }

        $Content = $Content[0]

        $params = @{
            Name    = $Content.displayName
            ImageId = $Content.imageId
        }

        # Export property = New-CPCProvisioningPolicy parameter
        $PropertyMap = [ordered]@{
            description           = "Description"
            cloudPcNamingTemplate = "NamingTemplate"
            managedBy             = "ManagedBy"
        }
        foreach ($property in $PropertyMap.Keys) {
            if (-not [string]::IsNullOrWhiteSpace($Content.$property)) {
                $params[$PropertyMap[$property]] = $Content.$property
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($Content.imageType)) {
            $params.ImageType = $Content.imageType
        }

        if ($null -ne $Content.enableSingleSignOn) {
            $params.EnableSingleSignOn = [bool]$Content.enableSingleSignOn
        }

        # The deprecated provisioningType 'shared' is replaced by 'sharedByUser'
        $ProvisioningType = $Content.provisioningType
        if ($ProvisioningType -eq 'shared') {
            Write-Verbose "Mapping the deprecated provisioningType 'shared' to 'sharedByUser'"
            $ProvisioningType = 'sharedByUser'
        }
        if ($ProvisioningType -eq 'unknownFutureValue') {
            # Graph returns sharedByUser, sharedByEntraGroup and reserve as unknownFutureValue to a GET without Prefer: include-unknown-enum-members
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "provisioningType in '$Inputfile' is 'unknownFutureValue': the export was read without the Prefer: include-unknown-enum-members header, so the real type (for example sharedByUser or sharedByEntraGroup) is unknown. Set the provisioningType in the file and import again" -Category InvalidData
        }
        if (-not [string]::IsNullOrWhiteSpace($ProvisioningType)) {
            if ($ProvisioningType -notin @('dedicated', 'sharedByUser', 'sharedByEntraGroup')) {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "provisioningType '$ProvisioningType' in '$Inputfile' can't be imported. Supported values: dedicated, sharedByUser, sharedByEntraGroup (the create API doesn't document reserve)" -Category InvalidData
            }
            $params.ProvisioningType = $ProvisioningType
        }

        if (-not [string]::IsNullOrWhiteSpace($Content.userExperienceType)) {
            if ($Content.userExperienceType -notin @('cloudPc', 'cloudApp')) {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "userExperienceType '$($Content.userExperienceType)' in '$Inputfile' can't be imported. Supported values: cloudPc, cloudApp" -Category InvalidData
            }
            $params.UserExperience = $Content.userExperienceType
        }

        # Current exports have windowsSetting.locale, older exports the deprecated windowsSettings.language
        $Locale = $Content.windowsSetting.locale
        if ([string]::IsNullOrWhiteSpace($Locale)) {
            $Locale = $Content.windowsSettings.language
        }
        if (-not [string]::IsNullOrWhiteSpace($Locale)) {
            $params.Language = $Locale
        }

        # microsoftManagedDesktop.managedType is current, type is deprecated
        $ManagedType = $Content.microsoftManagedDesktop.managedType
        if ([string]::IsNullOrWhiteSpace($ManagedType)) {
            $ManagedType = $Content.microsoftManagedDesktop.type
        }
        if (-not [string]::IsNullOrWhiteSpace($ManagedType)) {
            if ($ManagedType -notin @('notManaged', 'starterManaged')) {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "microsoftManagedDesktop.managedType '$ManagedType' in '$Inputfile' can't be imported. Supported values: notManaged, starterManaged" -Category InvalidData
            }
            $params.WindowsAutopatch = $ManagedType
        }

        if (-not [string]::IsNullOrWhiteSpace($Content.autopatch.autopatchGroupId)) {
            $params.WindowsAutopatchGroupId = $Content.autopatch.autopatchGroupId
        }

        # Domain join: current exports have domainJoinType, older exports the deprecated type
        $JoinConfigurations = @($Content.domainJoinConfigurations | Where-Object { $null -ne $_ })
        if ($JoinConfigurations.Count -eq 0) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "InputFile '$Inputfile' has no domainJoinConfigurations" -Category InvalidData
        }

        $JoinTypes = @(
            foreach ($JoinConfiguration in $JoinConfigurations) {
                if (-not [string]::IsNullOrWhiteSpace($JoinConfiguration.domainJoinType)) {
                    $JoinConfiguration.domainJoinType
                }
                else {
                    $JoinConfiguration.type
                }
            }
        )

        $JoinType = $JoinTypes[0]
        if ($JoinType -notin @('azureADJoin', 'hybridAzureADJoin') -or @($JoinTypes | Where-Object { $_ -ne $JoinType }).Count -gt 0) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "The domain join configuration in '$Inputfile' can't be imported. All entries must have the same domainJoinType: azureADJoin or hybridAzureADJoin" -Category InvalidData
        }
        $params.DomainJoinType = $JoinType

        $ConnectionIds = @($JoinConfigurations | Where-Object { -not [string]::IsNullOrWhiteSpace($_.onPremisesConnectionId) } | ForEach-Object { $_.onPremisesConnectionId })

        if ($ConnectionIds.Count -eq $JoinConfigurations.Count) {
            # The ids are passed on, so New-CPCProvisioningPolicy checks the same connections without a lookup by (possibly duplicate) name
            Write-Verbose "Importing $JoinType policy with Azure Network Connection id(s): $($ConnectionIds -join ', ')"
            $params.AzureNetworkConnectionId = $ConnectionIds
        }
        elseif ($ConnectionIds.Count -eq 0 -and $JoinType -eq 'azureADJoin' -and $JoinConfigurations.Count -eq 1 -and -not [string]::IsNullOrWhiteSpace($JoinConfigurations[0].regionName)) {
            Write-Verbose "Importing azureADJoin policy with a Microsoft-hosted network"
            $params.RegionName = $JoinConfigurations[0].regionName
            if (-not [string]::IsNullOrWhiteSpace($JoinConfigurations[0].regionGroup)) {
                $params.RegionGroup = $JoinConfigurations[0].regionGroup
            }
        }
        else {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "The domain join configuration in '$Inputfile' can't be imported. Use either Azure Network Connections (onPremisesConnectionId) or one Microsoft-hosted network (regionName with azureADJoin)" -Category InvalidData
        }
    }

    Process {
        If ($PSCmdlet.ShouldProcess($params.Name, "Import Provisioning Policy from $Inputfile")) {
            # Confirmed here (or skipped with -WhatIf), so New-CPCProvisioningPolicy doesn't ask again.
            # A failed check in New-CPCProvisioningPolicy is passed on as a terminating error of this cmdlet,
            # so -ErrorAction SilentlyContinue on the import doesn't hide it.
            try {
                New-CPCProvisioningPolicy @params -Confirm:$false -ErrorAction Stop
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
    }
}
