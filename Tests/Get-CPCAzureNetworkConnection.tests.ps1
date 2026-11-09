<#
This file tests the Get-CPCAzureNetworkConnection function by using Pester.
Contract: type is deprecated and stopped returning data on January 31, 2024; connectionType replaces it.
https://learn.microsoft.com/graph/api/resources/cloudpconpremisesconnection?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Get-CPCAzureNetworkConnection" {

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            [pscustomobject]@{ Content = (@{ value = @(@{ id = "a1"; displayName = "ANC01"; connectionType = "hybridAzureADJoin" }) } | ConvertTo-Json -Depth 5) }
        }
    }

    It "returns connectionType" {
        (Get-CPCAzureNetworkConnection -Name "ANC01").connectionType | Should -Be "hybridAzureADJoin"
    }
}
