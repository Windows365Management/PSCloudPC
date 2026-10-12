<#
This file tests the Remove-CPCProvisioningPolicy function by using Pester.
Contract: GET /deviceManagement/virtualEndpoint/provisioningPolicies?$select=id,displayName (all pages; no
$filter, because Graph's displayName eq is case-sensitive), an exact, case-insensitive name match
on the client, then exactly one DELETE /deviceManagement/virtualEndpoint/provisioningPolicies/{id} with
a GUID id. Zero or several matches, a partial name, an invalid id, a failed lookup or -WhatIf must
never send a DELETE.
https://learn.microsoft.com/graph/api/cloudpcprovisioningpolicy-delete?view=graph-rest-beta
https://learn.microsoft.com/graph/api/virtualendpoint-list-provisioningpolicies?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Remove-CPCProvisioningPolicy" {

    BeforeAll {
        $CollectionUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies"
        $ListUri = "$CollectionUri`?`$select=id,displayName"
        $TargetId = "00000000-0000-0000-0000-0000000000a1"
        $OtherId = "00000000-0000-0000-0000-0000000000a2"
        $DuplicateId = "00000000-0000-0000-0000-0000000000a3"
        $DeleteUriPattern = "^https://graph\.microsoft\.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"

        function New-GraphErrorRecord {
            param ([string]$Status, [string]$Code, [string]$Message)
            $exception = [System.Exception]::new("Response status code does not indicate success: $Status.")
            $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
            $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new((@{ error = @{ code = $Code; message = $Message } } | ConvertTo-Json -Compress))
            $errorRecord
        }
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        # The objects the (mocked) list endpoint returns on its first page.
        $script:ListItems = @(
            @{ id = $OtherId; displayName = "PSCloudPC-Test-US-AB" }
            @{ id = $TargetId; displayName = "US-AB" }
        )
        $script:NextLink = $null

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            [pscustomobject]@{ Content = (@{ value = @($script:ListItems); "@odata.nextLink" = $script:NextLink } | ConvertTo-Json -Depth 10) }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { }
    }

    Context "Command definition" {

        It "supports -WhatIf and -Confirm with ConfirmImpact High" {
            $command = Get-Command Remove-CPCProvisioningPolicy
            $binding = $command.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }

            $command.Parameters.Keys | Should -Contain "WhatIf"
            $command.Parameters.Keys | Should -Contain "Confirm"
            $binding.ConfirmImpact | Should -Be ([System.Management.Automation.ConfirmImpact]::High)
        }

        It "keeps -Name as the first positional parameter" {
            Remove-CPCProvisioningPolicy "US-AB" -Confirm:$false

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq "$CollectionUri/$TargetId" -and $Method -eq "DELETE"
            }
        }

        It "documents -Confirm:`$false for non-interactive use" {
            $help = Get-Help Remove-CPCProvisioningPolicy -Full

            ($help.description.Text -join " ") | Should -BeLike "*-Confirm:`$false*"
            @($help.examples.example.code) -match "-Confirm:\`$false" | Should -Not -BeNullOrEmpty
        }
    }

    Context "Lookup request" {

        It "lists the collection with `$select and sends no `$filter" {
            Remove-CPCProvisioningPolicy -Name "US-AB" -Confirm:$false

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Method -eq "GET" -and ([uri]$Uri).OriginalString -eq $ListUri
            }
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -ParameterFilter { ([uri]$Uri).OriginalString -match "filter" }
        }

        It "follows @odata.nextLink and finds the name on a later page" {
            $script:ListItems = @(@{ id = $OtherId; displayName = "PSCloudPC-Test-US-AB" })
            $script:NextLink = "$CollectionUri`?`$skiptoken=page2"
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -match "skiptoken=page2" } -MockWith {
                [pscustomobject]@{ Content = (@{ value = @(@{ id = $TargetId; displayName = "US-AB" }) } | ConvertTo-Json -Depth 10) }
            }

            Remove-CPCProvisioningPolicy -Name "US-AB" -Confirm:$false

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 2 -Exactly
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq "$CollectionUri/$TargetId" -and $Method -eq "DELETE"
            }
        }
    }

    Context "Exact name match" {

        It "deletes only the object whose name matches exactly" {
            Remove-CPCProvisioningPolicy -Name "US-AB" -Confirm:$false

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq "$CollectionUri/$TargetId" -and $Method -eq "DELETE"
            }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -ParameterFilter { "$Uri" -match $OtherId }
        }

        It "matches the name case-insensitively (<Name>)" -ForEach @(
            @{ Name = "us-ab"; ExpectedId = "00000000-0000-0000-0000-0000000000a1" }
            @{ Name = "pscloudpc-test-us-ab"; ExpectedId = "00000000-0000-0000-0000-0000000000a2" }
        ) {
            Remove-CPCProvisioningPolicy -Name $Name -Confirm:$false

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq "$CollectionUri/$ExpectedId" -and $Method -eq "DELETE"
            }
        }

        It "matches a name with a single quote" {
            $script:ListItems = @(@{ id = $TargetId; displayName = "O'Brien Test" })

            Remove-CPCProvisioningPolicy -Name "O'Brien Test" -Confirm:$false

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq "$CollectionUri/$TargetId" -and $Method -eq "DELETE"
            }
        }

        It "sends a DELETE URL that ends with exactly one id" {
            Remove-CPCProvisioningPolicy -Name "US-AB" -Confirm:$false

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -match $DeleteUriPattern -and ([uri]$Uri).OriginalString -notmatch "%20| "
            }
        }

        It "sends no DELETE with -WhatIf" {
            Remove-CPCProvisioningPolicy -Name "US-AB" -WhatIf

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly -ParameterFilter { $Method -eq "DELETE" }
        }
    }

    Context "Lookups that must stop before the DELETE" {

        It "deletes nothing for a partial name (<ErrorAction>)" -ForEach @(
            @{ ErrorAction = "Stop" }
            @{ ErrorAction = "SilentlyContinue" }
        ) {
            $script:ListItems = @(@{ id = $OtherId; displayName = "PSCloudPC-Test-US-AB" })

            { Remove-CPCProvisioningPolicy -Name "US-AB" -Confirm:$false -ErrorAction $ErrorAction } |
                Should -Throw -ExpectedMessage "*found with name 'US-AB'*Nothing was removed."

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly -ParameterFilter { $Method -eq "DELETE" }
        }

        It "stops with ObjectNotFound and sends no DELETE when nothing matches (<ErrorAction>)" -ForEach @(
            @{ ErrorAction = "Stop" }
            @{ ErrorAction = "SilentlyContinue" }
        ) {
            $script:ListItems = @()

            $caught = $null
            try { Remove-CPCProvisioningPolicy -Name "US-AB" -Confirm:$false -ErrorAction $ErrorAction } catch { $caught = $_ }

            $caught | Should -Not -BeNullOrEmpty
            $caught.CategoryInfo.Category | Should -Be "ObjectNotFound"
            $caught.Exception.Message | Should -BeLike "No * found with name 'US-AB'*. Nothing was removed."
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly -ParameterFilter { $Method -eq "DELETE" }
        }

        It "stops, lists both ids and sends no DELETE when two objects have the name (<ErrorAction>)" -ForEach @(
            @{ ErrorAction = "Stop" }
            @{ ErrorAction = "SilentlyContinue" }
        ) {
            $script:ListItems = @(
                @{ id = $TargetId; displayName = "US-AB" }
                @{ id = $DuplicateId; displayName = "us-ab" }
            )

            { Remove-CPCProvisioningPolicy -Name "US-AB" -Confirm:$false -ErrorAction $ErrorAction } |
                Should -Throw -ExpectedMessage "2 * found with name 'US-AB' (*$TargetId*$DuplicateId*)*Nothing was removed."

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly -ParameterFilter { $Method -eq "DELETE" }
        }

        It "sends no DELETE when the match has an invalid id '<BadId>'" -ForEach @(
            @{ BadId = "" }
            @{ BadId = "not-a-guid" }
            @{ BadId = "00000000-0000-0000-0000-0000000000a1 00000000-0000-0000-0000-0000000000a2" }
            @{ BadId = "00000000-0000-0000-0000-0000000000a1/assign" }
            @{ BadId = "{00000000-0000-0000-0000-0000000000a1}" }
        ) {
            $script:ListItems = @(@{ id = $BadId; displayName = "US-AB" })

            { Remove-CPCProvisioningPolicy -Name "US-AB" -Confirm:$false -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "*has no valid id*Nothing was removed."

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "stops with the Graph error and sends no DELETE when the lookup fails (<ErrorAction>)" -ForEach @(
            @{ ErrorAction = "Stop" }
            @{ ErrorAction = "SilentlyContinue" }
        ) {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                throw (New-GraphErrorRecord -Status "403 (Forbidden)" -Code "Forbidden" -Message "Insufficient privileges to complete the operation.")
            }

            { Remove-CPCProvisioningPolicy -Name "US-AB" -Confirm:$false -ErrorAction $ErrorAction } |
                Should -Throw -ExpectedMessage "*Forbidden: Insufficient privileges to complete the operation."

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Graph error on the DELETE" {

        It "throws with the Graph error code and message" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                throw (New-GraphErrorRecord -Status "400 (Bad Request)" -Code "BadRequest" -Message "The object is in use.")
            }

            { Remove-CPCProvisioningPolicy -Name "US-AB" -Confirm:$false -ErrorAction Stop } |
                Should -Throw -ExpectedMessage "*BadRequest: The object is in use."

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq "$CollectionUri/$TargetId" -and $Method -eq "DELETE"
            }
        }
    }
}
