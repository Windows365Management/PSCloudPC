<#
This file tests the Connect-Windows365 function by using Pester
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../PSCloudPc/PSCloudPC.psd1') -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe 'Connect-Windows365' {

    BeforeAll {
        # Mimics the HttpResponseMessage returned by Invoke-MgGraphRequest -OutputType HttpResponseMessage
        $script:mockGraphResponse = [PSCustomObject]@{
            RequestMessage = [PSCustomObject]@{
                Headers = [PSCustomObject]@{
                    Authorization = [PSCustomObject]@{ Parameter = 'delegated-token' }
                }
            }
        }

        # Self-signed certificate with a private key, created in memory
        $rsa = [System.Security.Cryptography.RSA]::Create(2048)
        $request = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
            'CN=PSCloudPC Pester',
            $rsa,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256,
            [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
        )
        $script:testCertificate = $request.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddDays(1))

        function ConvertFrom-Base64Url([string]$Value) {
            $padded = $Value.Replace('-', '+').Replace('_', '/')
            $padded = $padded.PadRight($padded.Length + (4 - $padded.Length % 4) % 4, '=')
            [Convert]::FromBase64String($padded)
        }
    }

    Context 'Interactive Authentication' {

        It 'Stores the token from the Microsoft Graph session' {
            Mock -ModuleName PSCloudPC Connect-MgGraph { }
            Mock -ModuleName PSCloudPC Invoke-MgGraphRequest { $script:mockGraphResponse }

            Connect-Windows365

            InModuleScope PSCloudPC { $script:Authheader.Authorization } | Should -Be 'Bearer delegated-token'
            Should -Invoke -ModuleName PSCloudPC Connect-MgGraph -Times 1 -ParameterFilter { $Scopes -contains 'https://graph.microsoft.com/CloudPC.ReadWrite.All' }
        }
    }

    Context 'Device Code Authentication' {

        It 'Requests the Cloud PC scopes when signing in with a device code' {
            Mock -ModuleName PSCloudPC Connect-MgGraph { }
            Mock -ModuleName PSCloudPC Invoke-MgGraphRequest { $script:mockGraphResponse }

            Connect-Windows365 -DeviceCode

            Should -Invoke -ModuleName PSCloudPC Connect-MgGraph -Times 1 -ParameterFilter {
                $UseDeviceCode -and $Scopes -contains 'https://graph.microsoft.com/CloudPC.ReadWrite.All'
            }
            InModuleScope PSCloudPC { $script:Authheader.Authorization } | Should -Be 'Bearer delegated-token'
        }
    }

    Context 'Client Secret Authentication' {

        It 'Requests a token with the client credentials grant' {
            Mock -ModuleName PSCloudPC Invoke-RestMethod { [PSCustomObject]@{ access_token = 'secret-token' } }

            Connect-Windows365 -TenantID 'contoso.onmicrosoft.com' -ClientID 'app-id' -ClientSecret 'secret'

            InModuleScope PSCloudPC { $script:Authheader.Authorization } | Should -Be 'Bearer secret-token'
            Should -Invoke -ModuleName PSCloudPC Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -eq 'https://login.microsoftonline.com/contoso.onmicrosoft.com/oauth2/v2.0/token' -and
                $Body.Client_Secret -eq 'secret'
            }
        }
    }

    Context 'Client Certificate Authentication' {

        BeforeEach {
            Mock -ModuleName PSCloudPC Invoke-RestMethod {
                $script:capturedBody = $Body
                [PSCustomObject]@{ access_token = 'certificate-token' }
            }
        }

        It 'Stores the token returned for the signed client assertion' {
            Connect-Windows365 -TenantID 'contoso.onmicrosoft.com' -ClientID 'app-id' -ClientCertificate $script:testCertificate

            InModuleScope PSCloudPC { $script:Authheader.Authorization } | Should -Be 'Bearer certificate-token'
            $script:capturedBody.Client_Assertion_Type | Should -Be 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
            $script:capturedBody.Client_Id | Should -Be 'app-id'
        }

        It 'Sends a client assertion with the correct claims and a valid signature' {
            Connect-Windows365 -TenantID 'contoso.onmicrosoft.com' -ClientID 'app-id' -ClientCertificate $script:testCertificate

            $parts = $script:capturedBody.Client_Assertion.Split('.')
            $parts.Count | Should -Be 3

            $header = [Text.Encoding]::UTF8.GetString((ConvertFrom-Base64Url $parts[0])) | ConvertFrom-Json
            $claims = [Text.Encoding]::UTF8.GetString((ConvertFrom-Base64Url $parts[1])) | ConvertFrom-Json

            $header.alg | Should -Be 'RS256'
            $claims.aud | Should -Be 'https://login.microsoftonline.com/contoso.onmicrosoft.com/oauth2/v2.0/token'
            $claims.iss | Should -Be 'app-id'
            $claims.sub | Should -Be 'app-id'
            $claims.exp | Should -BeGreaterThan ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())

            $publicKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($script:testCertificate)
            $publicKey.VerifyData(
                [Text.Encoding]::UTF8.GetBytes("$($parts[0]).$($parts[1])"),
                (ConvertFrom-Base64Url $parts[2]),
                [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
            ) | Should -BeTrue
        }

        It 'Throws a clear error for a certificate without a private key' {
            $publicOnly = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($script:testCertificate.RawData)

            { Connect-Windows365 -TenantID 'contoso.onmicrosoft.com' -ClientID 'app-id' -ClientCertificate $publicOnly } |
                Should -Throw '*private key*'
        }
    }

    Context 'Token Authentication' {

        It 'Stores the supplied access token' {
            Connect-Windows365 -Token 'supplied-token'

            InModuleScope PSCloudPC { $script:Authheader.Authorization } | Should -Be 'Bearer supplied-token'
        }
    }

    Context 'Missing token' {

        It 'Throws and clears the session when no access token is returned' {
            Mock -ModuleName PSCloudPC Invoke-RestMethod { [PSCustomObject]@{ access_token = $null } }

            { Connect-Windows365 -TenantID 'contoso.onmicrosoft.com' -ClientID 'app-id' -ClientSecret 'secret' } |
                Should -Throw '*No access token*'
            InModuleScope PSCloudPC { $script:Authheader } | Should -BeNullOrEmpty
        }
    }
}
