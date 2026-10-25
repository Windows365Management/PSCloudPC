<#
This file tests Export-CPCProvisioningPolicy and Import-CPCProvisioningPolicy by using Pester.
Contract: the export writes the raw cloudPcProvisioningPolicy as a one element JSON array to
<OutputFolder>/<displayName>.json (Join-Path, so it works on every OS). The import reads the join type from
domainJoinConfigurations[].domainJoinType (type stopped returning data on January 31, 2024), the language from
windowsSetting.locale (windowsSettings.language is deprecated) and resolves onPremisesConnectionId to the connection
name New-CPCProvisioningPolicy expects.
https://learn.microsoft.com/en-us/graph/api/resources/cloudpcprovisioningpolicy?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../PSCloudPc/PSCloudPC.psd1') -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe 'Export-CPCProvisioningPolicy and Import-CPCProvisioningPolicy' {

    BeforeAll {
        $PolicyId = '00000000-0000-0000-0000-0000000000p1'
        $ConnectionId = '00000000-0000-0000-0000-0000000000a1'
        $ExportedPolicy = @{
            '@odata.context'         = 'https://graph.microsoft.com/beta/$metadata#deviceManagement/virtualEndpoint/provisioningPolicies/$entity'
            id                       = $PolicyId
            displayName              = 'HR Policy'
            description              = 'HR'
            imageId                  = 'microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc'
            imageType                = 'gallery'
            enableSingleSignOn       = $false
            provisioningType         = 'dedicated'
            userExperienceType       = 'cloudPc'
            managedBy                = 'windows365'
            cloudPcNamingTemplate    = 'HR-%USERNAME:5%-%RAND:5%'
            windowsSettings          = $null
            windowsSetting           = @{ locale = 'nl-NL' }
            microsoftManagedDesktop  = @{ managedType = 'notManaged'; profile = $null }
            domainJoinConfigurations = @(@{ domainJoinType = 'hybridAzureADJoin'; type = $null; onPremisesConnectionId = $ConnectionId; regionName = $null; regionGroup = $null })
        }
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = 'token'
            $script:Authheader = @{ Authorization = 'Bearer token' }
            $script:MSGraphVersion = 'beta'
        }
        $OutputFolder = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $OutputFolder | Out-Null
    }

    AfterEach {
        Remove-Item -Path $OutputFolder -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'exports the policy to <OutputFolder>/<displayName>.json' {
        Mock -ModuleName PSCloudPC Get-CPCProvisioningPolicy -MockWith { [pscustomobject]@{ id = $PolicyId; displayName = 'HR Policy' } }
        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith { [pscustomobject]@{ Content = ($ExportedPolicy | ConvertTo-Json -Depth 10) } }

        Export-CPCProvisioningPolicy -Name 'HR Policy' -OutputFolder $OutputFolder | Out-Null

        $file = Join-Path $OutputFolder 'HR Policy.json'
        Test-Path $file | Should -BeTrue
        $content = @(Get-Content $file -Raw | ConvertFrom-Json)
        $content.Count | Should -Be 1
        $content[0].domainJoinConfigurations[0].domainJoinType | Should -Be 'hybridAzureADJoin'
    }

    It 'imports a policy using domainJoinType, windowsSetting.locale and the connection name' {
        $file = Join-Path $OutputFolder 'HR Policy.json'
        ConvertTo-Json @($ExportedPolicy) -Depth 10 | Set-Content -Path $file

        Mock -ModuleName PSCloudPC Get-CPCAzureNetworkConnection -MockWith {
            [pscustomobject]@{ id = $ConnectionId; displayName = 'ANC-HR'; connectionType = 'hybridAzureADJoin'; healthCheckStatus = 'passed' }
        }
        Mock -ModuleName PSCloudPC New-CPCProvisioningPolicy -MockWith { }

        Import-CPCProvisioningPolicy -Inputfile $file

        Should -Invoke New-CPCProvisioningPolicy -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'HR Policy' -and
            $DomainJoinType -eq 'hybridAzureADJoin' -and
            $Language -eq 'nl-NL' -and
            @($AzureNetworkConnection)[0] -eq 'ANC-HR' -and
            $ImageId -eq 'microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc' -and
            $NamingTemplate -eq 'HR-%USERNAME:5%-%RAND:5%' -and
            $ProvisioningType -eq 'dedicated'
        }
    }

    It 'imports a Microsoft hosted network policy from an older export that only has type and windowsSettings' {
        $file = Join-Path $OutputFolder 'Old Policy.json'
        $OldPolicy = @{
            displayName              = 'Old Policy'
            imageId                  = 'img'
            imageType                = 'gallery'
            enableSingleSignOn       = $true
            windowsSettings          = @{ language = 'en-GB' }
            domainJoinConfigurations = @(@{ type = 'azureADJoin'; regionName = 'westeurope'; regionGroup = 'europeUnion' })
        }
        ConvertTo-Json @($OldPolicy) -Depth 10 | Set-Content -Path $file
        Mock -ModuleName PSCloudPC New-CPCProvisioningPolicy -MockWith { }

        Import-CPCProvisioningPolicy -Inputfile $file

        Should -Invoke New-CPCProvisioningPolicy -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            $DomainJoinType -eq 'azureADJoin' -and
            $Language -eq 'en-GB' -and
            $RegionName -eq 'westeurope' -and
            $RegionGroup -eq 'europeUnion' -and
            $EnableSingleSignOn -eq $true
        }
    }

    It 'stops when the exported connection id does not exist in the tenant' {
        $file = Join-Path $OutputFolder 'HR Policy.json'
        ConvertTo-Json @($ExportedPolicy) -Depth 10 | Set-Content -Path $file
        Mock -ModuleName PSCloudPC Get-CPCAzureNetworkConnection -MockWith { }
        Mock -ModuleName PSCloudPC New-CPCProvisioningPolicy -MockWith { }

        { Import-CPCProvisioningPolicy -Inputfile $file -ErrorAction SilentlyContinue } |
            Should -Throw -ExpectedMessage "No Azure Network Connection found with id $ConnectionId*"

        Should -Invoke New-CPCProvisioningPolicy -ModuleName PSCloudPC -Times 0 -Exactly
    }

    It 'stops when the file does not exist' {
        { Import-CPCProvisioningPolicy -Inputfile (Join-Path $OutputFolder 'missing.json') -ErrorAction SilentlyContinue } |
            Should -Throw -ExpectedMessage 'File not found*'
    }
}
