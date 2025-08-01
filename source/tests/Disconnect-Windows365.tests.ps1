<#
This file tests the Disconnect-Windows365 function by using Pester

#>

$modulename = 'PSCloudPC'

BeforeAll {
    $modulePath = Join-Path -Path (Join-Path ".././" -ChildPath "PSCloudPC") -ChildPath "PSCloudPC"
    $binaryFile = "PSCloudPC.psm1"
    $manifestFile = "PSCloudPC.psd1"
    $moduleContent = Import-PowerShellDataFile (Join-Path -Path $modulePath -ChildPath $manifestFile)
    Import-Module (Join-Path -Path $modulePath -ChildPath $binaryFile) -Force
}

Describe "Disconnect-Windows365 tests" {
    Context "Disconnect-Windows365 Functionality" {
        It "Should Complete function without error" {

            Mock -CommandName Disconnect-MgGraph -MockWith { $null } -ModuleName $modulename

            {Disconnect-Windows365} | Should -Not -Throw

        }
    }
    Context "Clear token cache" {
        It "Should clear token cache" {

            $script:Authheader | Should -Be $null
            $script:Authtoken | Should -Be $null
            $script:Authtime | Should -Be $null

        }

    }
}