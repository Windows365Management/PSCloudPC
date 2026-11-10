<#
This file tests the Update-CPCAzureNetworkConnection function by using Pester.
Contract: adDomainPassword is sent as plain text, and the password is never written to the verbose stream.
https://learn.microsoft.com/graph/api/cloudpconpremisesconnection-update?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Update-CPCAzureNetworkConnection" {

    BeforeAll {
        $ConnectionId = "00000000-0000-0000-0000-0000000000a1"
        $Password = ConvertTo-SecureString "Pl@inText!" -AsPlainText -Force
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        Mock -ModuleName PSCloudPC Get-CPCAzureNetworkConnection -MockWith {
            [pscustomobject]@{ id = $ConnectionId; displayName = "ANC01" }
        }
        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith { [pscustomobject]@{ Content = "{}" } }
    }

    It "sends the domain password as plain text" {
        Update-CPCAzureNetworkConnection -Name "ANC01" -AdDomainPassword $Password | Out-Null

        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            $Method -eq "PATCH" -and ($Body | ConvertFrom-Json).adDomainPassword -ceq "Pl@inText!"
        }
    }

    It "does not write the domain password to the verbose stream" {
        $verbose = Update-CPCAzureNetworkConnection -Name "ANC01" -AdDomainPassword $Password -Verbose 4>&1

        ($verbose | Out-String) | Should -Not -BeLike "*Pl@inText!*"
    }
}
