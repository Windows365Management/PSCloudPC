<#
This file tests the Connect-Windows365 function by using Pester
#>


# Tests/Connect-Windows365.Tests.ps1
Import-Module Pester -MinimumVersion 5.0

Describe 'Export-CPCProvisioningPolicy' {

  BeforeAll {
    # Load the module into the test session
    Import-Module "./PSCloudPC/Src/PSCloudPC.psm1"

    function Set-GraphVersion {
      $script:MSGraphVersion = 'beta'
    }

    $script:Authtime = [System.DateTime]::UtcNow

    function Get-TokenValidity {
      return $script:Authtime
    }

    $script:mockcpcprovisioningpolicy = @{
      id   = "dummy-id"
      name = "DummyPolicy"
    }

    $script:mockexportedcpcprovisioningpolicy = @{
          Content = '{
            "id": "dummy-id",
            "displayName": "DummyPolicy",
            "description": "This is a dummy provisioning policy"
          }'
        }
    }

    It 'Should not throw an error when exporting the provisioning policy' {

      Mock -CommandName Get-TokenValidity -MockWith { $script:Authtime = [System.DateTime]::UtcNow }

      Mock -CommandName Get-CPCProvisioningPolicy -MockWith { $script:mockcpcprovisioningpolicy}

      Mock -CommandName Invoke-WebRequest -MockWith { $null }

      Mock -CommandName ConvertFrom-Json -MockWith { $script:mockexportedcpcprovisioningpolicy.Content }

      Mock -CommandName ConvertTo-Json -MockWith { $script:mockcpcprovisioningpolicy}

      { Export-CPCProvisioningPolicy -Name "DummyPolicy" -OutputFolder "Dummy" } | Should -Not -Throw

    }
}
