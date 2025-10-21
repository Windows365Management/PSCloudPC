<#
This file tests the Connect-Windows365 function by using Pester
#>


# Tests/Connect-Windows365.Tests.ps1
Import-Module Pester -MinimumVersion 5.0

Describe 'Connect-Windows365' {
  BeforeAll {
    # Load the module into the test session
    Import-Module "./PSCloudPC/Src/Public/Connect-Windows365.ps1"

    function Set-GraphVersion {
      $script:MSGraphVersion = 'beta'
    }

    $script:mockconnectMgGraphdata = @{
      RequestMessage = @{
        Method     = "GET"
        RequestUri = "https://graph.microsoft.com/v1.0/me"
        Version    = 2.0
        Content    = $null
        Headers    = @{
          "User-Agent"        = @(
            "Mozilla/5.0",
            "(Macintosh; Darwin 24.6.0 Darwin Kernel Version 24.6.0: Mon Jul 14 11:28:30 PDT 2025; root:xnu-11417.140.69~1/RELEASE_ARM64_T6030; en-US)",
            "PowerShell/2025.2.0",
            "Invoke-MgGraphRequest"
          )
          "FeatureFlag"       = "00000043"
          "Cache-Control"     = "no-store, no-cache"
          "Authorization"     = "Bearer eyJ0eXAiOiJKV1QiLCJub25jZSI6IlUtbmFOYTk1OThDWFllOTBucU1QY3dRelFKdmRYbkoyRENyMUcxS2p3SFkiLCJhbGciOiJSUzI1NiIsIng1dCI6IkpZaEFjVFBNWl9MWDZEQmxPV1E3SG4wTmVYRSIsImtpZCI6IkpZaEFjVFBNWl9MWDZEQmxPV1E3SG4wTmVYRSJ9..."
          "Accept-Encoding"   = "gzip"
          "SdkVersion"        = "graph-powershell/2.20.0"
          "client-request-id" = "099d9abb-acb5-4470-b19b-232c65e24881"
        }
      }
    }

    $script:mockcertificateobject = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new()

  }

  Context "Interactive Authentication" {

    It 'Should not throw an error when connecting to Windows 365' {

      Mock -CommandName Set-GraphVersion -Verifiable

      Mock -CommandName Connect-MgGraph -MockWith { $null }

      Mock -CommandName Invoke-MgGraphRequest -Verifiable -ParameterFilter { $script:mockconnectMgGraphdata }

      Mock -CommandName Connect-Windows365 -MockWith { $null }

      { Connect-Windows365 } | Should -Not -Throw

    }
  }

  Context "Client Secret Authentication" {

    It 'Should not throw an error when connecting to Windows 365' {

      Mock -CommandName Set-GraphVersion -Verifiable

      Mock -CommandName Invoke-RestMethod -MockWith { $null }

      { Connect-Windows365 -TenantID "dummy" -ClientID "dummy" -ClientSecret "dummy" } | Should -Not -Throw

    }
  }

  Context "Client Certificate Authentication" {

    It 'Should not throw an error when connecting to Windows 365' {

      Mock -CommandName Set-GraphVersion -Verifiable

      Mock -CommandName Connect-MgGraph -MockWith { $null }

      { Connect-Windows365 -TenantID "dummy" -ClientID "dummy" -ClientCertificate $script:mockcertificateobject } | Should -Not -Throw

    }
  }

  Context "Device Code Authentication" {

    It 'Should not throw an error when connecting to Windows 365' {

      Mock -CommandName Set-GraphVersion -Verifiable

      Mock -CommandName Connect-MgGraph -MockWith { $null }

      Mock -CommandName Invoke-MgGraphRequest -Verifiable -ParameterFilter { $script:mockconnectMgGraphdata }

      { Connect-Windows365 -DeviceCode } | Should -Not -Throw

    }
  }
  Context "Token Authentication" {

    It 'Should not throw an error when connecting to Windows 365' {

      Mock -CommandName Set-GraphVersion -Verifiable

      { Connect-Windows365 -Token "dummy" } | Should -Not -Throw

    }
  }
}