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

    It 'Sends additional headers on the first and every next page request' {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/test' } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"1"}],"@odata.nextLink":"https://graph.microsoft.com/beta/test?page=2"}' }
            }
            Mock Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/test?page=2' } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"2"}]}' }
            }

            $null = Invoke-APIRequest -uri 'https://graph.microsoft.com/beta/test' -Token 'token' -AdditionalHeaders @{ Prefer = 'include-unknown-enum-members' }

            Should -Invoke Invoke-WebRequest -Times 2 -Exactly -ParameterFilter {
                $Headers.Prefer -eq 'include-unknown-enum-members' -and $Headers.Authorization -eq 'Bearer token'
            }
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

    It 'Stops paging once MaxItems items are collected and returns only that many' {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/test' } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"1"},{"id":"2"},{"id":"3"}],"@odata.nextLink":"https://graph.microsoft.com/beta/test?page=2"}' }
            }
            Mock Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/test?page=2' } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"4"}]}' }
            }

            $result = @(Invoke-APIRequest -uri 'https://graph.microsoft.com/beta/test' -Token 'token' -MaxItems 2)

            $result.id | Should -Be @('1', '2')
            Should -Invoke Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/test?page=2' } -Times 0 -Exactly
        }
    }

    It 'Sends AdditionalHeaders on every page and never replaces the Authorization header' {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/test' } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"1"}],"@odata.nextLink":"https://graph.microsoft.com/beta/test?page=2"}' }
            }
            Mock Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/test?page=2' } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"2"}]}' }
            }

            Invoke-APIRequest -uri 'https://graph.microsoft.com/beta/test' -Token 'token' -AdditionalHeaders @{ Prefer = 'include-unknown-enum-members'; Authorization = 'Bearer other' } | Out-Null

            Should -Invoke Invoke-WebRequest -Times 2 -Exactly -ParameterFilter {
                $Headers.Prefer -eq 'include-unknown-enum-members' -and $Headers.Authorization -eq 'Bearer token'
            }
        }
    }

    It 'Follows nextLink while fewer than MaxItems items are collected' {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/test' } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"1"}],"@odata.nextLink":"https://graph.microsoft.com/beta/test?page=2"}' }
            }
            Mock Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/test?page=2' } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"2"},{"id":"3"}]}' }
            }

            $result = @(Invoke-APIRequest -uri 'https://graph.microsoft.com/beta/test' -Token 'token' -MaxItems 2)

            $result.id | Should -Be @('1', '2')
            Should -Invoke Invoke-WebRequest -Times 2 -Exactly
        }
    }
}

Describe 'Invoke-APIRequest guards when the caller ignores errors' {
    # A plain Throw is skipped under -ErrorAction SilentlyContinue / $ErrorActionPreference = 'SilentlyContinue',
    # which used to send the token to a foreign nextLink and loop on a failed page (security review X1).

    It 'Never requests a foreign nextLink with -ErrorAction SilentlyContinue' {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/test' } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"1"}],"@odata.nextLink":"https://evil.example.com/beta/test?page=2"}' }
            }
            Mock Invoke-WebRequest -ParameterFilter { $Uri -like 'https://evil.example.com/*' } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"2"}]}' }
            }

            $thrown = $null
            try { Invoke-APIRequest -uri 'https://graph.microsoft.com/beta/test' -Token 'token' -ErrorAction SilentlyContinue | Out-Null } catch { $thrown = $_ }

            Should -Invoke Invoke-WebRequest -ParameterFilter { $Uri -like 'https://evil.example.com/*' } -Times 0 -Exactly
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly
            "$thrown" | Should -BeLike '*Refusing to follow @odata.nextLink*'
        }
    }

    It 'Never requests a foreign nextLink with $ErrorActionPreference = SilentlyContinue' {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/test' } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"1"}],"@odata.nextLink":"https://evil.example.com/beta/test?page=2"}' }
            }
            Mock Invoke-WebRequest -ParameterFilter { $Uri -like 'https://evil.example.com/*' } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"2"}]}' }
            }

            $thrown = $null
            try {
                & {
                    $ErrorActionPreference = 'SilentlyContinue'
                    Invoke-APIRequest -uri 'https://graph.microsoft.com/beta/test' -Token 'token' | Out-Null
                }
            }
            catch { $thrown = $_ }

            Should -Invoke Invoke-WebRequest -ParameterFilter { $Uri -like 'https://evil.example.com/*' } -Times 0 -Exactly
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly
            "$thrown" | Should -BeLike '*Refusing to follow @odata.nextLink*'
        }
    }

    It 'Stops after the second request when the same nextLink repeats, with -ErrorAction SilentlyContinue' {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest {
                [PSCustomObject]@{ Content = '{"value":[{"id":"1"}],"@odata.nextLink":"https://graph.microsoft.com/beta/test?page=2"}' }
            }

            $thrown = $null
            try { Invoke-APIRequest -uri 'https://graph.microsoft.com/beta/test' -Token 'token' -ErrorAction SilentlyContinue | Out-Null } catch { $thrown = $_ }

            Should -Invoke Invoke-WebRequest -Times 2 -Exactly
            "$thrown" | Should -BeLike '*same @odata.nextLink twice*'
        }
    }

    It 'Stops at the failing page and never reuses the previous page, with -ErrorAction SilentlyContinue' {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/test' } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"1"}],"@odata.nextLink":"https://graph.microsoft.com/beta/test?page=2"}' }
            }
            Mock Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/test?page=2' } {
                throw 'Response status code does not indicate success: 503 (Service Unavailable).'
            }

            $thrown = $null
            $result = $null
            try { $result = Invoke-APIRequest -uri 'https://graph.microsoft.com/beta/test' -Token 'token' -ErrorAction SilentlyContinue } catch { $thrown = $_ }

            Should -Invoke Invoke-WebRequest -Times 2 -Exactly
            Should -Invoke Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/test?page=2' } -Times 1 -Exactly
            $result | Should -BeNullOrEmpty
            "$thrown" | Should -BeLike '*503*'
        }
    }

    It 'Stops when the first request fails, with -ErrorAction SilentlyContinue' {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest { throw 'Response status code does not indicate success: 503 (Service Unavailable).' }

            { Invoke-APIRequest -uri 'https://graph.microsoft.com/beta/test' -Token 'token' -ErrorAction SilentlyContinue } | Should -Throw '*503*'
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly
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

Describe 'Get-AzureADGroupID' {
    # https://learn.microsoft.com/graph/api/group-list?view=graph-rest-beta
    # The helper stops the cmdlet passed as -Cmdlet, so it is called from a small advanced function here.

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtoken = "token"
            $script:MSGraphVersion = "beta"
        }
    }

    It "Returns the id of the one group with this name and escapes the name in the filter" {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest { [PSCustomObject]@{ Content = '{"value":[{"id":"00000000-0000-0000-0000-0000000000a1","displayName":"O''Brien & Co"}]}' } }
            function Test-GroupLookup { [CmdletBinding()] param ([string]$GroupName) Get-AzureADGroupID -GroupName $GroupName -Cmdlet $PSCmdlet }

            $result = Test-GroupLookup -GroupName "O'Brien & Co"

            $result | Should -BeOfType [string]
            $result | Should -Be "00000000-0000-0000-0000-0000000000a1"
            # ' is doubled for OData, then the whole filter is encoded (' -> %27, & -> %26, space -> %20)
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -eq "https://graph.microsoft.com/beta/groups?`$filter=displayName%20eq%20%27O%27%27Brien%20%26%20Co%27&`$select=id,displayName" -and
                $Method -eq "GET"
            }
        }
    }

    It "Stops when no group has this name, also with -ErrorAction SilentlyContinue" {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest { [PSCustomObject]@{ Content = '{"value":[]}' } }
            function Test-GroupLookup { [CmdletBinding()] param ([string]$GroupName) Get-AzureADGroupID -GroupName $GroupName -Cmdlet $PSCmdlet }

            { Test-GroupLookup -GroupName "Missing Group" -ErrorAction SilentlyContinue } | Should -Throw -ExpectedMessage "No group found with name Missing Group"
        }
    }

    It "Stops and lists the ids when more than one group has this name" {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest { [PSCustomObject]@{ Content = '{"value":[{"id":"00000000-0000-0000-0000-0000000000a1","displayName":"Team"},{"id":"00000000-0000-0000-0000-0000000000a2","displayName":"Team"}]}' } }
            function Test-GroupLookup { [CmdletBinding()] param ([string]$GroupName) Get-AzureADGroupID -GroupName $GroupName -Cmdlet $PSCmdlet }

            { Test-GroupLookup -GroupName "Team" -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "2 groups found with name Team (00000000-0000-0000-0000-0000000000a1, 00000000-0000-0000-0000-0000000000a2)*"
        }
    }

    It "Stops with the Graph error when the lookup fails" {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest {
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Response status code does not indicate success: 403 (Forbidden)."),
                    "WebCmdletWebResponseException",
                    "InvalidOperation",
                    $null
                )
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Authorization_RequestDenied","message":"Insufficient privileges to complete the operation."}}')
                throw $errorRecord
            }
            function Test-GroupLookup { [CmdletBinding()] param ([string]$GroupName) Get-AzureADGroupID -GroupName $GroupName -Cmdlet $PSCmdlet }

            { Test-GroupLookup -GroupName "Team" -ErrorAction SilentlyContinue } | Should -Throw -ExpectedMessage "Failed to look up group Team:*Authorization_RequestDenied*"
        }
    }
}

Describe "Invoke-APIRequest -AdditionalHeaders" {

    It "Sends the extra headers on every page and keeps the Authorization header" {
        InModuleScope PSCloudPC {
            Mock Invoke-WebRequest -ParameterFilter { $Uri -eq "https://graph.microsoft.com/beta/test" } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"1"}],"@odata.nextLink":"https://graph.microsoft.com/beta/test?page=2"}' }
            }
            Mock Invoke-WebRequest -ParameterFilter { $Uri -eq "https://graph.microsoft.com/beta/test?page=2" } {
                [PSCustomObject]@{ Content = '{"value":[{"id":"2"}]}' }
            }

            $null = Invoke-APIRequest -uri "https://graph.microsoft.com/beta/test" -Token "token" -AdditionalHeaders @{ Prefer = "include-unknown-enum-members"; Authorization = "Bearer other" }

            Should -Invoke Invoke-WebRequest -Times 2 -Exactly -ParameterFilter {
                $Headers["Prefer"] -eq "include-unknown-enum-members" -and $Headers["Authorization"] -eq "Bearer token"
            }
        }
    }
}

Describe "Confirm-CPCHighImpactAction" {

    It "Has ConfirmImpact High, so it prompts by default" {
        InModuleScope PSCloudPC {
            $binding = (Get-Command Confirm-CPCHighImpactAction).ScriptBlock.Attributes |
                Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }

            $binding.SupportsShouldProcess | Should -BeTrue
            "$($binding.ConfirmImpact)" | Should -Be "High"
        }
    }

    It "Returns true with -Confirm:`$false and false with -WhatIf" {
        InModuleScope PSCloudPC {
            Confirm-CPCHighImpactAction -Target "Policy" -Action "Remove" -Confirm:$false | Should -BeTrue
            Confirm-CPCHighImpactAction -Target "Policy" -Action "Remove" -WhatIf | Should -BeFalse
        }
    }
}
