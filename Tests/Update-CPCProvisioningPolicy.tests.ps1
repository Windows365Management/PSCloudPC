<#
This file tests the Update-CPCProvisioningPolicy function by using Pester.
Contract: PATCH /deviceManagement/virtualEndpoint/provisioningPolicies/{id}. imageType is an enum (gallery, custom),
so it must never be sent empty: when only -ImageId is passed the current imageType of the policy is kept.
domainJoinConfigurations[].domainJoinType follows the connectionType of the Azure Network Connection.
https://learn.microsoft.com/en-us/graph/api/cloudpcprovisioningpolicy-update?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../PSCloudPc/PSCloudPC.psd1') -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe 'Update-CPCProvisioningPolicy' {

    BeforeAll {
        $PolicyId = '00000000-0000-0000-0000-0000000000p1'
        $PolicyUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies/$PolicyId"
        $ConnectionId = '00000000-0000-0000-0000-0000000000a1'
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = 'token'
            $script:Authheader = @{ Authorization = 'Bearer token' }
            $script:MSGraphVersion = 'beta'
        }

        Mock -ModuleName PSCloudPC Get-CPCProvisioningPolicy -MockWith {
            [pscustomobject]@{ id = $PolicyId; displayName = 'Policy'; imageType = 'gallery'; provisioningType = 'dedicated' }
        }
        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith { [pscustomobject]@{ Content = '' } }
    }

    It 'keeps the current imageType when only a new image id is passed' {
        Update-CPCProvisioningPolicy -Name 'Policy' -ImageId 'new-image' | Out-Null

        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            $json = $Body | ConvertFrom-Json
            $Uri -eq $PolicyUri -and
            $Method -eq 'PATCH' -and
            $json.imageId -eq 'new-image' -and
            $json.imageType -eq 'gallery' -and
            $json.displayName -eq 'Policy'
        }
    }

    It 'sends the passed imageType in lower case' {
        Update-CPCProvisioningPolicy -Name 'Policy' -ImageId 'new-image' -ImageType Custom | Out-Null

        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            ($Body | ConvertFrom-Json).imageType -ceq 'custom'
        }
    }

    It 'sends domainJoinType from the connectionType of the connection' {
        Mock -ModuleName PSCloudPC Get-CPCAzureNetworkConnection -MockWith {
            [pscustomobject]@{ id = $ConnectionId; displayName = 'ANC01'; connectionType = 'hybridAzureADJoin'; healthCheckStatus = 'warning' }
        }

        Update-CPCProvisioningPolicy -Name 'Policy' -AzureNetworkConnection 'ANC01' | Out-Null

        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            $config = @(($Body | ConvertFrom-Json).domainJoinConfigurations)
            $config.Count -eq 1 -and
            $config[0].domainJoinType -eq 'hybridAzureADJoin' -and
            $config[0].onPremisesConnectionId -eq $ConnectionId
        }
    }

    It 'stops and sends nothing when the policy is not found, also with -ErrorAction SilentlyContinue' {
        Mock -ModuleName PSCloudPC Get-CPCProvisioningPolicy -MockWith { }

        { Update-CPCProvisioningPolicy -Name 'Missing' -ImageId 'x' -ErrorAction SilentlyContinue } |
            Should -Throw -ExpectedMessage 'No Provisioning Policy found with name Missing*'

        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly
    }

    It 'sends nothing with -WhatIf' {
        Update-CPCProvisioningPolicy -Name 'Policy' -EnableSingleSignOn $true -WhatIf

        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly
    }
}
