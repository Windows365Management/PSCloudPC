<#
This file tests the Disconnect-Windows365 function by using Pester
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../PSCloudPc/PSCloudPC.psd1') -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe 'Disconnect-Windows365' {

    BeforeAll {
        Mock -ModuleName PSCloudPC Get-MgContext { [PSCustomObject]@{ Account = 'admin@contoso.com' } }
        Mock -ModuleName PSCloudPC Disconnect-MgGraph { }
    }

    It 'Disconnects from Microsoft Graph and clears the token cache' {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = 'token'
            $script:Authheader = @{ Authorization = 'Bearer token' }
        }

        Disconnect-Windows365

        Should -Invoke -ModuleName PSCloudPC Disconnect-MgGraph -Times 1
        InModuleScope PSCloudPC {
            $script:Authtime | Should -BeNullOrEmpty
            $script:Authtoken | Should -BeNullOrEmpty
            $script:Authheader | Should -BeNullOrEmpty
        }
    }
}
