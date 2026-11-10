<#
This file tests the Update-CPCProvisioningPolicy function by using Pester.
Contract: with an Azure Network Connection, domainJoinConfigurations sends domainJoinType (the connectionType of the
connection) and onPremisesConnectionId. The type property of both resources is deprecated.
https://learn.microsoft.com/graph/api/cloudpcprovisioningpolicy-update?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Update-CPCProvisioningPolicy" {

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        Mock -ModuleName PSCloudPC Get-CPCProvisioningPolicy -MockWith { [pscustomobject]@{ id = "p1"; displayName = "Policy01" } }
        Mock -ModuleName PSCloudPC Get-CPCAzureNetworkConnection -MockWith {
            [pscustomobject]@{ id = "a1"; displayName = "ANC01"; connectionType = "hybridAzureADJoin"; healthCheckStatus = "passed" }
        }
        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith { [pscustomobject]@{ Content = "{}" } }
    }

    It "sends domainJoinType from the connectionType of the Azure Network Connection" {
        Update-CPCProvisioningPolicy -Name "Policy01" -AzureNetworkConnection "ANC01"

        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            $config = @(($Body | ConvertFrom-Json).DomainJoinConfigurations)
            $Method -eq "PATCH" -and
            $config.Count -eq 1 -and
            $config[0].domainJoinType -eq "hybridAzureADJoin" -and
            $config[0].OnPremisesConnectionId -eq "a1"
        }
    }
}
