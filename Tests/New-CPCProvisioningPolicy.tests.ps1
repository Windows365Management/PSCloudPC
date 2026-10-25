<#
This file tests the New-CPCProvisioningPolicy function by using Pester.
Contract: POST /deviceManagement/virtualEndpoint/provisioningPolicies with a cloudPcProvisioningPolicy body.
domainJoinConfigurations[].domainJoinType must be set (type is deprecated and stopped returning data on
January 31, 2024); with an Azure Network Connection it follows the connectionType of the connection.
A connection whose health check is passed, warning or informational can be used for provisioning.
The unknown top-level property userSettingsPersistenceEnabled and the deprecated microsoftManagedDesktop.type
are not sent.
https://learn.microsoft.com/en-us/graph/api/virtualendpoint-post-provisioningpolicies?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpcdomainjoinconfiguration?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpconpremisesconnection?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../PSCloudPc/PSCloudPC.psd1') -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe 'New-CPCProvisioningPolicy' {

    BeforeAll {
        $PolicyUri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies'
        $ConnectionId = '00000000-0000-0000-0000-0000000000a1'
        $ImageId = 'microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc'
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = 'token'
            $script:Authheader = @{ Authorization = 'Bearer token' }
            $script:MSGraphVersion = 'beta'
        }

        Mock -ModuleName PSCloudPC Get-CPCProvisioningPolicy -MockWith { }
        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            [pscustomobject]@{ Content = '{"id":"00000000-0000-0000-0000-0000000000p1","displayName":"Policy"}' }
        }
    }

    Context 'Azure Network Connection' {

        It 'sends domainJoinType and onPremisesConnectionId from the connectionType of a healthy connection' {
            Mock -ModuleName PSCloudPC Get-CPCAzureNetworkConnection -MockWith {
                [pscustomobject]@{ id = $ConnectionId; displayName = 'ANC01'; connectionType = 'hybridAzureADJoin'; type = 'hybridAzureADJoin'; healthCheckStatus = 'passed' }
            }

            New-CPCProvisioningPolicy -Name 'Policy' -ImageId $ImageId -EnableSingleSignOn $false -AzureNetworkConnection 'ANC01' | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $json = $Body | ConvertFrom-Json
                $config = @($json.domainJoinConfigurations)
                $Uri -eq $PolicyUri -and
                $Method -eq 'POST' -and
                $config.Count -eq 1 -and
                $config[0].domainJoinType -eq 'hybridAzureADJoin' -and
                $config[0].onPremisesConnectionId -eq $ConnectionId -and
                $null -eq $config[0].regionName
            }
        }

        It 'accepts a connection whose health check is <Status>' -ForEach @(
            @{ Status = 'warning' }
            @{ Status = 'informational' }
        ) {
            Mock -ModuleName PSCloudPC Get-CPCAzureNetworkConnection -MockWith {
                [pscustomobject]@{ id = $ConnectionId; displayName = 'ANC01'; connectionType = 'azureADJoin'; healthCheckStatus = $Status }
            }

            New-CPCProvisioningPolicy -Name 'Policy' -ImageId $ImageId -EnableSingleSignOn $true -AzureNetworkConnection 'ANC01' | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly
        }

        It 'stops and sends no request when the health check <Status>' -ForEach @(
            @{ Status = 'failed' }
            @{ Status = 'pending' }
            @{ Status = 'running' }
        ) {
            Mock -ModuleName PSCloudPC Get-CPCAzureNetworkConnection -MockWith {
                [pscustomobject]@{ id = $ConnectionId; displayName = 'ANC01'; connectionType = 'azureADJoin'; healthCheckStatus = $Status }
            }

            { New-CPCProvisioningPolicy -Name 'Policy' -ImageId $ImageId -EnableSingleSignOn $false -AzureNetworkConnection 'ANC01' -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "*is not healthy*"

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It 'stops when the connection is not found' {
            Mock -ModuleName PSCloudPC Get-CPCAzureNetworkConnection -MockWith { }

            { New-CPCProvisioningPolicy -Name 'Policy' -ImageId $ImageId -EnableSingleSignOn $false -AzureNetworkConnection 'Missing' -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "No Azure Network Connection found with name Missing*"

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It 'stops when single sign-on is requested for a hybrid joined connection' {
            Mock -ModuleName PSCloudPC Get-CPCAzureNetworkConnection -MockWith {
                [pscustomobject]@{ id = $ConnectionId; displayName = 'ANC01'; connectionType = 'hybridAzureADJoin'; healthCheckStatus = 'passed' }
            }

            { New-CPCProvisioningPolicy -Name 'Policy' -ImageId $ImageId -EnableSingleSignOn $true -AzureNetworkConnection 'ANC01' -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "*only supported with 'azureADJoin'*"

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context 'Microsoft hosted network' {

        It 'sends domainJoinType, regionName and regionGroup and no unknown or deprecated properties' {
            New-CPCProvisioningPolicy -Name 'Policy' -ImageId $ImageId -EnableSingleSignOn $true -RegionName 'westeurope' -RegionGroup 'europeUnion' | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $json = $Body | ConvertFrom-Json
                $config = @($json.domainJoinConfigurations)
                $config.Count -eq 1 -and
                $config[0].domainJoinType -eq 'azureADJoin' -and
                $config[0].regionName -eq 'westeurope' -and
                $config[0].regionGroup -eq 'europeUnion' -and
                $json.PSObject.Properties.Name -notcontains 'userSettingsPersistenceEnabled' -and
                $json.microsoftManagedDesktop.PSObject.Properties.Name -notcontains 'type' -and
                $json.microsoftManagedDesktop.managedType -eq 'notManaged' -and
                $json.windowsSetting.locale -eq 'en-US' -and
                $json.cloudPcNamingTemplate -eq 'CPC-%USERNAME:5%-%RAND:5%'
            }
        }

        It 'stops when hybridAzureADJoin is combined with a Microsoft hosted network' {
            { New-CPCProvisioningPolicy -Name 'Policy' -ImageId $ImageId -EnableSingleSignOn $false -DomainJoinType hybridAzureADJoin -RegionName 'westeurope' -RegionGroup 'europeUnion' -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "*requires -AzureNetworkConnection*"

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It 'stops when starterManaged is requested without an Autopatch group id' {
            { New-CPCProvisioningPolicy -Name 'Policy' -ImageId $ImageId -EnableSingleSignOn $true -RegionName 'westeurope' -RegionGroup 'europeUnion' -WindowsAutopatch starterManaged -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "*WindowsAutopatchGroupId*"

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It 'sends the autopatch group id for starterManaged' {
            New-CPCProvisioningPolicy -Name 'Policy' -ImageId $ImageId -EnableSingleSignOn $true -RegionName 'westeurope' -RegionGroup 'europeUnion' -WindowsAutopatch starterManaged -WindowsAutopatchGroupId 'ap-group' | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $json = $Body | ConvertFrom-Json
                $json.microsoftManagedDesktop.managedType -eq 'starterManaged' -and
                $json.autopatch.autopatchGroupId -eq 'ap-group'
            }
        }

        It 'returns the created policy' {
            $result = New-CPCProvisioningPolicy -Name 'Policy' -ImageId $ImageId -EnableSingleSignOn $true -RegionName 'westeurope' -RegionGroup 'europeUnion'

            $result.id | Should -Be '00000000-0000-0000-0000-0000000000p1'
        }

        It 'stops with ResourceExists when a policy with the name exists' {
            Mock -ModuleName PSCloudPC Get-CPCProvisioningPolicy -MockWith {
                [pscustomobject]@{ id = 'existing'; displayName = 'Policy' }
            }

            { New-CPCProvisioningPolicy -Name 'Policy' -ImageId $ImageId -EnableSingleSignOn $true -RegionName 'westeurope' -RegionGroup 'europeUnion' -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "*already exists*"

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It 'sends nothing with -WhatIf' {
            New-CPCProvisioningPolicy -Name 'Policy' -ImageId $ImageId -EnableSingleSignOn $true -RegionName 'westeurope' -RegionGroup 'europeUnion' -WhatIf

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }
}
