Function Import-CPCProvisioningPolicy {
    <#
    .SYNOPSIS
    Imports a Provisioning Policy from a JSON File
    .DESCRIPTION
    The function will import a Provisioning Policy from a JSON File
    .PARAMETER Inputfile
    Enter the path to the JSON File
    .EXAMPLE
    Import-CPCProvisioningPolicy -Inputfile "C:\Temp\AzureADJoinPolicy.json"
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [parameter(Mandatory, ParameterSetName = "Name")]
        [string]$Inputfile
    )
    
    Begin {
        Get-TokenValidity

        if (-not (Test-Path -Path $Inputfile -PathType Leaf)) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "File not found: $Inputfile" -Category ObjectNotFound
        }

        # Export-CPCProvisioningPolicy writes the policy as a one element array
        try {
            $Content = @(Get-Content -Path $Inputfile -Raw | ConvertFrom-Json -ErrorAction Stop)
        }
        catch {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "InputFile is not a valid JSON File: $($_.Exception.Message)" -Category InvalidData
        }

        if ($Content.Count -ne 1 -or [string]::IsNullOrWhiteSpace($Content[0].displayName)) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "InputFile must contain exactly one provisioning policy with a displayName" -Category InvalidData
        }

        $Content = $Content[0]
    }
    
    Process {

        $DomainJoinConfigurations = @($Content.domainJoinConfigurations | Where-Object { $null -ne $_ })

        if ($DomainJoinConfigurations.Count -eq 0) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "The policy has no domainJoinConfigurations" -Category InvalidData
        }

        # type stopped returning data on January 31, 2024; domainJoinType replaces it. Older exports only have type.
        $JoinTypes = @($DomainJoinConfigurations | ForEach-Object {
                if ($_.domainJoinType) { $_.domainJoinType } else { $_.type }
            } | Where-Object { $_ } | Select-Object -Unique)

        if ($JoinTypes.Count -ne 1) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "The policy must have one domain join type, found: $($JoinTypes -join ', ')" -Category InvalidData
        }

        # windowsSettings.language stopped returning data on January 31, 2024; windowsSetting.locale replaces it
        $Language = $Content.windowsSetting.locale
        if ([string]::IsNullOrWhiteSpace($Language)) {
            $Language = $Content.windowsSettings.language
        }
        if ([string]::IsNullOrWhiteSpace($Language)) {
            $Language = 'en-US'
        }

        $NewPolicyParams = @{
            Name               = $Content.displayName
            DomainJoinType     = $JoinTypes[0]
            ImageType          = $Content.imageType
            ImageId            = $Content.imageId
            EnableSingleSignOn = [bool]$Content.enableSingleSignOn
            Language           = $Language
        }

        if ($Content.description) { $NewPolicyParams.Description = $Content.description }
        if ($Content.cloudPcNamingTemplate) { $NewPolicyParams.NamingTemplate = $Content.cloudPcNamingTemplate }
        if ($Content.provisioningType) { $NewPolicyParams.ProvisioningType = $Content.provisioningType }
        if ($Content.userExperienceType) { $NewPolicyParams.UserExperience = $Content.userExperienceType }
        if ($Content.managedBy) { $NewPolicyParams.ManagedBy = $Content.managedBy }
        if ($Content.microsoftManagedDesktop.managedType -eq 'starterManaged') {
            $NewPolicyParams.WindowsAutopatch = 'starterManaged'
            if ($Content.autopatch.autopatchGroupId) { $NewPolicyParams.WindowsAutopatchGroupId = $Content.autopatch.autopatchGroupId }
        }

        $ConnectionIds = @($DomainJoinConfigurations.onPremisesConnectionId | Where-Object { $_ })

        if ($ConnectionIds.Count -gt 0) {
            Write-Verbose "Importing policy with Azure Network Connection(s): $($ConnectionIds -join ', ')"

            # New-CPCProvisioningPolicy takes connection names; resolve the exported ids to the names in this tenant
            $AllConnections = @(Get-CPCAzureNetworkConnection)
            $ConnectionNames = foreach ($ConnectionId in $ConnectionIds) {
                $Connection = $AllConnections | Where-Object { $_.id -eq $ConnectionId }
                if ($null -eq $Connection) {
                    Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No Azure Network Connection found with id $ConnectionId. Create the connection first or edit the onPremisesConnectionId in the file." -Category ObjectNotFound
                }
                $Connection.displayName
            }
            $NewPolicyParams.AzureNetworkConnection = @($ConnectionNames)
        }
        else {
            Write-Verbose "Importing policy with a Microsoft hosted network"
            $RegionName = $DomainJoinConfigurations[0].regionName
            $RegionGroup = $DomainJoinConfigurations[0].regionGroup
            if ([string]::IsNullOrWhiteSpace($RegionName) -or [string]::IsNullOrWhiteSpace($RegionGroup)) {
                Stop-CPCCommand -Cmdlet $PSCmdlet -Message "The domainJoinConfigurations in the file have neither an onPremisesConnectionId nor a regionName and regionGroup" -Category InvalidData
            }
            $NewPolicyParams.RegionName = $RegionName
            $NewPolicyParams.RegionGroup = $RegionGroup
        }

        if ($PSCmdlet.ShouldProcess($Content.displayName, "Import Provisioning Policy")) {
            New-CPCProvisioningPolicy @NewPolicyParams
        }
    }
    
}
