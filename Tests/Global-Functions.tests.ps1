<#
This file tests the private helper functions by using Pester
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../PSCloudPc/PSCloudPC.psd1') -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-APIRequest' {

    It 'Follows @odata.nextLink and returns the items of every page' {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/test' } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"1"},{"id":"2"}],"@odata.nextLink":"https://graph.microsoft.com/beta/test?page=2"}' }
            }
            Mock Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/test?page=2' } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"3"}]}' }
            }

            $result = Invoke-APIRequest -uri 'https://graph.microsoft.com/beta/test' -Token 'token'

            $result.id | Should -Be @('1', '2', '3')
            Should -Invoke Invoke-WebRequest -Times 2
        }
    }

    It 'Returns a single object when the response has no value collection' {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest { [PSCustomObject]@{ Content = '{"id":"policy-1","displayName":"Policy"}' } }

            $result = Invoke-APIRequest -uri 'https://graph.microsoft.com/beta/test/policy-1' -Token 'token'

            $result.displayName | Should -Be 'Policy'
        }
    }

    It 'Returns an empty result for an empty collection' {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest { [PSCustomObject]@{ Content = '{"value":[]}' } }

            @(Invoke-APIRequest -uri 'https://graph.microsoft.com/beta/test' -Token 'token').Count | Should -Be 0
        }
    }
}

Describe 'Get-GraphErrorMessage' {

    It 'Includes the Graph error code and message from the response body' {
        InModuleScope PSCloudPC {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('Response status code does not indicate success: 400 (Bad Request).'),
                'WebCmdletWebResponseException',
                'InvalidOperation',
                $null
            )
            $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"This action is only supported for Frontline Cloud PCs."}}')

            Get-GraphErrorMessage $errorRecord |
                Should -Be 'Response status code does not indicate success: 400 (Bad Request). BadRequest: This action is only supported for Frontline Cloud PCs.'
        }
    }

    It 'Falls back to the exception message when there are no error details' {
        InModuleScope PSCloudPC {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('Connection refused'),
                'Error',
                'ConnectionError',
                $null
            )

            Get-GraphErrorMessage $errorRecord | Should -Be 'Connection refused'
        }
    }

    It 'Appends error details that are not Graph JSON' {
        InModuleScope PSCloudPC {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('Response status code does not indicate success: 502 (Bad Gateway).'),
                'WebCmdletWebResponseException',
                'InvalidOperation',
                $null
            )
            $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('upstream unavailable')

            Get-GraphErrorMessage $errorRecord | Should -Be 'Response status code does not indicate success: 502 (Bad Gateway). upstream unavailable'
        }
    }
}

Describe 'Get-TokenValidity' {

    It 'Clears the session before throwing when the token has expired' {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow.AddMinutes(-60)
            $script:Authtoken = 'token'
            $script:Authheader = @{ Authorization = 'Bearer token' }

            { Get-TokenValidity } | Should -Throw '*Token expired*'
            $script:Authheader | Should -BeNullOrEmpty
            $script:Authtoken | Should -BeNullOrEmpty
        }
    }
}
