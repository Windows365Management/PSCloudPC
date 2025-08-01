#
# Module manifest for module 'PSCloudPC'
#
# Generated by: S. Dingemanse
#
# Generated on: 12/19/2022
#

@{

    # Script module or binary module file associated with this manifest.
    RootModule        = 'PSCloudPC.psm1'

    # Version number of this module.
    ModuleVersion     = '1.0.15'

    # Supported PSEditions
    # CompatiblePSEditions = @()

    # ID used to uniquely identify this module
    GUID              = '20b7d4c5-dddd-487a-8a02-f231e92013d2'

    # Author of this module
    Author            = 'Stefan Dingemanse, Niels Kok'

    # Company or vendor of this module
    CompanyName       = 'Windows365Management'

    # Copyright statement for this module
    Copyright         = '(c) All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'This PowerShell module allows you to manage your Windows 365 environment from the command line. It provides a set of cmdlets that allow you to perform various tasks, such as creating, modifying and deleting policies, managing Cloud PCs, and more.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '7.2'

    # Name of the Windows PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the Windows PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # CLRVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @("Microsoft.Graph.Authentication")

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Connect-Windows365',
        'Disconnect-Windows365',
        'Export-CPCProvisioningPolicy',
        'Get-CloudPC',
        'Get-CPCAzureNetworkConnection',
        'Get-CPCCustomImage',
        'Get-CPCGalleryImage',
        'Get-CPCOrganizationSetting',
        'Get-CPCProvisioningPolicy',
        'Get-CPCRestorePoint',
        'Get-CPCServicePlan',
        'Get-CPCSupportedRegion',
        'Get-CPCUserSettingsPolicy',
        'Import-CPCProvisioningPolicy',
        'Invoke-CPCEndGracePeriod',
        'Invoke-CPCReboot',
        'Invoke-CPCReprovision',
        'Invoke-CPCRestore',
        'New-CPCAzureNetworkConnection',
        'New-CPCCustomImage',
        'New-CPCProvisioningPolicy',
        'New-CPCUserSettingsPolicy',
        'Remove-CPCAzureNetworkConnection',
        'Remove-CPCCustomImage',
        'Remove-CPCProvisioningPolicy',
        'Remove-CPCUserSettingsPolicy',
        'Set-CPCProvisioningPolicyAssignment',
        'Set-CPCUserSettingsPolicyAssignment',
        'Update-CPCOrganizationSetting',
        'Update-CPCUserSettingsPolicy',
        'Update-CPCProvisioningPolicy'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport   = '*'

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = @('Azure', 'CloudPC', 'Windows365', 'W365', 'PSModule', 'Automation', 'RestApi', 'MicrosoftGraph' )

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/Windows365Management/PSCloudPC/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/Windows365Management/PSCloudPC'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            # ReleaseNotes = ''

        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

}
