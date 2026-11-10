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

    It 'Throws and does not request a nextLink on another host' {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/test' } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"1"}],"@odata.nextLink":"https://evil.example.com/beta/test?page=2"}' }
            }
            Mock Invoke-WebRequest -ParameterFilter { $Uri -like 'https://evil.example.com/*' } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"2"}]}' }
            }

            { Invoke-APIRequest -uri 'https://graph.microsoft.com/beta/test' -Token 'token' } | Should -Throw '*Refusing to follow @odata.nextLink*'
            Should -Invoke Invoke-WebRequest -ParameterFilter { $Uri -like 'https://evil.example.com/*' } -Times 0 -Exactly
        }
    }

    It 'Throws on an http nextLink' {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/test' } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"1"}],"@odata.nextLink":"http://graph.microsoft.com/beta/test?page=2"}' }
            }
            Mock Invoke-WebRequest -ParameterFilter { $Uri -like 'http://*' } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"2"}]}' }
            }

            { Invoke-APIRequest -uri 'https://graph.microsoft.com/beta/test' -Token 'token' } | Should -Throw '*Refusing to follow @odata.nextLink*'
            Should -Invoke Invoke-WebRequest -ParameterFilter { $Uri -like 'http://*' } -Times 0 -Exactly
        }
    }

    It 'Throws instead of looping when the same nextLink comes back twice' {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest {
                [PSCustomObject]@{ Content = '{"value":[{"id":"1"}],"@odata.nextLink":"https://graph.microsoft.com/beta/test?page=2"}' }
            }

            { Invoke-APIRequest -uri 'https://graph.microsoft.com/beta/test' -Token 'token' } | Should -Throw '*same @odata.nextLink twice*'
            Should -Invoke Invoke-WebRequest -Times 2 -Exactly
        }
    }

    It 'Stops after the page cap' {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest {
                $next = [int]([regex]::Match($Uri, 'page=(\d+)').Groups[1].Value) + 1
                [PSCustomObject]@{ Content = "{`"value`":[],`"@odata.nextLink`":`"https://graph.microsoft.com/beta/test?page=$next`"}" }
            }

            { Invoke-APIRequest -uri 'https://graph.microsoft.com/beta/test?page=1' -Token 'token' } | Should -Throw '*Stopped paging after 1000 pages*'
            Should -Invoke Invoke-WebRequest -Times 1000 -Exactly
        }
    }

    It 'Throws instead of returning page 1 when page 2 fails' {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/test' } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"1"}],"@odata.nextLink":"https://graph.microsoft.com/beta/test?page=2"}' }
            }
            Mock Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/test?page=2' } {
                throw 'Response status code does not indicate success: 503 (Service Unavailable).'
            }

            { Invoke-APIRequest -uri 'https://graph.microsoft.com/beta/test' -Token 'token' } | Should -Throw '*503*'
            Should -Invoke Invoke-WebRequest -Times 2 -Exactly
        }
    }

    It 'Throws with the Graph error message when page 1 fails' {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest {
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new('Response status code does not indicate success: 403 (Forbidden).'),
                    'WebCmdletWebResponseException',
                    'InvalidOperation',
                    $null
                )
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Forbidden","message":"Insufficient privileges to complete the operation."}}')
                throw $errorRecord
            }

            { Invoke-APIRequest -uri 'https://graph.microsoft.com/beta/test' -Token 'token' } |
                Should -Throw 'Response status code does not indicate success: 403 (Forbidden). Forbidden: Insufficient privileges to complete the operation.'
        }
    }

    It 'Throws when no response is returned' {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest { $null }

            { Invoke-APIRequest -uri 'https://graph.microsoft.com/beta/test' -Token 'token' } | Should -Throw '*No response returned*'
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
