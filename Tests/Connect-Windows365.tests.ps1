<#
This file tests the Disconnect-Windows365 function by using Pester
#>


$modulename = 'PSCloudPC'

BeforeAll {
  # Import the module - correct relative path from Tests folder
  Import-Module "./PSCloudPC/Src/PSCloudPC.psm1" -Force


  Function Set-GraphVersion {
    # This function sets the Graph API version to beta
    Write-Verbose "Graph API version set to beta"
  }

  Function Connect-MgGraph {
    # Mock function to simulate connection to Microsoft Graph
    Write-Verbose "Mocked Connect-MgGraph"
  }

  Function Invoke-MgGraphRequest {
    # Mock function to simulate invoking a Microsoft Graph API request
    Write-Verbose "Mocked Invoke-MgGraphRequest"
  }
}

Describe "Connect-Windows365" {

  It "Should Connect to Windows 365 using Interactive Authentication" {

    Mock -CommandName Set-GraphVersion -MockWith {
      Write-Host "Setting Graph API version to beta"
      $script:GraphVersion = "beta"
    }

    Mock -CommandName Connect-MgGraph -MockWith { $null }

    Mock -CommandName Invoke-MgGraphRequest -MockWith {

      Write-Output "Mocked Invoke-MgGraphRequest"
      $script:GraphVersion = "beta"
      $script:Authtoken = "mocked_token"
      $script:Authheader = @{ Authorization = "Bearer mocked_token" }
      $script:Authtime = [System.DateTime]::UtcNow
    }

  Connect-Windows365

  $script:GraphVersion | Should -Be "beta"
  $script:Authtoken | Should -Not -BeNullOrEmpty
  $script:Authheader | Should -Not -BeNullOrEmpty
  $script:Authtime | Should -Not -BeNullOrEmpty
}
}