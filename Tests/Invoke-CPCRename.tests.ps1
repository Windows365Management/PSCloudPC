<#
This file tests the Invoke-CPCRename function by using Pester.
Contract: POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/rename with body { "displayName": "<new name>" }
and Content-Type application/json.
The Cloud PC is resolved by an exact managedDeviceName match; zero or several matches stop before the POST.
https://learn.microsoft.com/graph/api/cloudpc-rename?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Invoke-CPCRename" {

    BeforeAll {
        $CloudPCId = "00000000-0000-0000-0000-0000000000c1"
        $LookupUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs?`$filter=managedDeviceName+eq+'CPC-TEST-01'"
        $ActionUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$CloudPCId/rename"
        $DefaultCloudPC = @{ id = $CloudPCId; displayName = "Cloud PC Test 01"; managedDeviceName = "CPC-TEST-01"; status = "provisioned" }
        $DuplicateCloudPC = @{ id = "00000000-0000-0000-0000-0000000000c2"; displayName = "Cloud PC Test 02"; managedDeviceName = "CPC-TEST-01"; status = "provisioned" }
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        # Cloud PCs returned by the managedDeviceName lookup (Graph GET). Tests may replace this list.
        $GraphCloudPCs = @($DefaultCloudPC)

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            [pscustomobject]@{ Content = (@{ value = @($GraphCloudPCs) } | ConvertTo-Json -Depth 10) }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { }
    }

    It "looks up the Cloud PC by managedDeviceName and POSTs the new displayName" {
        $result = Invoke-CPCRename -Name "CPC-TEST-01" -NewDisplayName "Marketing Cloud PC"

        $result | Should -BeNullOrEmpty
        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            ([uri]$Uri).OriginalString -eq $LookupUri
        }
        Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            $parsed = $Body | ConvertFrom-Json
            $Uri -eq $ActionUri -and
            $Method -eq "POST" -and
            $ContentType -eq "application/json" -and
            @($parsed.PSObject.Properties.Name).Count -eq 1 -and
            $parsed.displayName -is [string] -and
            $parsed.displayName -eq "Marketing Cloud PC"
        }
    }

    It "reports an error and sends no POST when <Case> (-ErrorAction <Action>)" -ForEach @(
        @{ Case = "no Cloud PC matches"; MatchCount = 0; Action = "Stop"; Message = "No Cloud PC found*" }
        @{ Case = "no Cloud PC matches"; MatchCount = 0; Action = "SilentlyContinue"; Message = "No Cloud PC found*" }
        @{ Case = "two Cloud PCs match"; MatchCount = 2; Action = "Stop"; Message = "2 Cloud PCs found*" }
        @{ Case = "two Cloud PCs match"; MatchCount = 2; Action = "SilentlyContinue"; Message = "2 Cloud PCs found*" }
    ) {
        $GraphCloudPCs = @(@($DefaultCloudPC, $DuplicateCloudPC) | Select-Object -First $MatchCount)

        if ($Action -eq "Stop") {
            { Invoke-CPCRename -Name "CPC-TEST-01" -NewDisplayName "Marketing Cloud PC" -ErrorAction Stop } | Should -Throw -ExpectedMessage $Message
        }
        else {
            # A problem with one Cloud PC is a non-terminating error
            Invoke-CPCRename -Name "CPC-TEST-01" -NewDisplayName "Marketing Cloud PC" -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors
            # -ErrorVariable also collects the Graph errors the module caught; count only the module's own records
            $moduleErrors = @($cloudPCErrors | Where-Object FullyQualifiedErrorId -like "PSCloudPC.CloudPCError*")
            $moduleErrors.Count | Should -Be 1
            $moduleErrors[0].Exception.Message | Should -BeLike $Message
        }

        Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
    }

    It "sends no POST with -WhatIf" {
        Invoke-CPCRename -Name "CPC-TEST-01" -NewDisplayName "Marketing Cloud PC" -WhatIf

        Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
    }

    It "throws the Graph error code when the POST fails" {
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
            $exception = [System.Exception]::new("Response status code does not indicate success: 400 (Bad Request).")
            $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
            $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"Invalid display name"}}')
            throw $errorRecord
        }

        { Invoke-CPCRename -Name "CPC-TEST-01" -NewDisplayName "Marketing Cloud PC" -ErrorAction Stop } | Should -Throw -ExpectedMessage "*BadRequest: Invalid display name*"

        Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
    }

    Context "Pipeline input" {

        BeforeEach {
            $PipedCloudPCs = @(
                @{ id = "00000000-0000-0000-0000-0000000000d1"; displayName = "Cloud PC Piped 01"; managedDeviceName = "CPC-PIPED-01"; status = "provisioned" }
                @{ id = "00000000-0000-0000-0000-0000000000d2"; displayName = "Cloud PC Piped 02"; managedDeviceName = "CPC-PIPED-02"; status = "provisioned" }
            )
            # Get-CloudPC lists these Cloud PCs
            $GraphCloudPCs = $PipedCloudPCs

            # GET cloudPCs/{id} returns the piped Cloud PC with that id
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -match "/cloudPCs/[0-9a-f-]{36}$" } -MockWith {
                $requestedId = ([uri]$Uri).OriginalString.Split("/")[-1]
                [pscustomobject]@{ Content = (@($PipedCloudPCs | Where-Object { $_.id -eq $requestedId })[0] | ConvertTo-Json -Depth 10) }
            }
        }

        It "sends one request per Cloud PC piped from Get-CloudPC, each with its own id" {
            Get-CloudPC | Invoke-CPCRename -NewDisplayName "Piped Cloud PC"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 2 -Exactly
            foreach ($piped in $PipedCloudPCs) {
                Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                    ([uri]$Uri).OriginalString -ceq "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$($piped.id)/rename" -and
                    $Method -eq "POST" -and
                    ($Body | ConvertFrom-Json).displayName -ceq "Piped Cloud PC"
                }
            }
        }

        It "binds a piped object by its CloudPCId property" {
            [pscustomobject]@{ CloudPCId = "00000000-0000-0000-0000-0000000000d2" } | Invoke-CPCRename -NewDisplayName "Piped Cloud PC"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -ceq "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/00000000-0000-0000-0000-0000000000d2/rename"
            }
        }

        It "sends nothing for piped Cloud PCs with -WhatIf" {
            Get-CloudPC | Invoke-CPCRename -NewDisplayName "Piped Cloud PC" -WhatIf

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "writes one error for a Cloud PC that fails with 409 Conflict and continues with the next piped Cloud PC" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -ParameterFilter { ([uri]$Uri).OriginalString -like "*00000000-0000-0000-0000-0000000000d1*" } -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 409 (Conflict).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Conflict","message":"Another action is still active"}}')
                throw $errorRecord
            }

            Get-CloudPC | Invoke-CPCRename -NewDisplayName "Piped Cloud PC" -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors

            # -ErrorVariable also collects the Graph errors the module caught; count only the module's own records
            $moduleErrors = @($cloudPCErrors | Where-Object FullyQualifiedErrorId -like "PSCloudPC.CloudPCError*")
            $moduleErrors.Count | Should -Be 1
            $moduleErrors[0].Exception.Message | Should -BeLike "*00000000-0000-0000-0000-0000000000d1*Conflict: Another action is still active*"
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 2 -Exactly
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -like "*00000000-0000-0000-0000-0000000000d2*"
            }
        }

        It "stops at the first failed Cloud PC with -ErrorAction Stop" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -ParameterFilter { ([uri]$Uri).OriginalString -like "*00000000-0000-0000-0000-0000000000d1*" } -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 409 (Conflict).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Conflict","message":"Another action is still active"}}')
                throw $errorRecord
            }

            { Get-CloudPC | Invoke-CPCRename -NewDisplayName "Piped Cloud PC" -ErrorAction Stop } | Should -Throw -ExpectedMessage "*Conflict: Another action is still active*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -like "*00000000-0000-0000-0000-0000000000d2*"
            }
        }

        It "fails without a request for a piped object <Case>" -ForEach @(
            @{ Case = "without an id"; InputObject = [pscustomobject]@{ displayName = "Cloud PC Piped 01"; managedDeviceName = "CPC-PIPED-01" } }
            @{ Case = "with an empty id"; InputObject = [pscustomobject]@{ id = ""; displayName = "Cloud PC Piped 01"; managedDeviceName = "CPC-PIPED-01" } }
        ) {
            # Pipeline binding errors don't reach -ErrorVariable; collect them from the error stream and from $Error
            $global:Error.Clear()
            $streamErrors = @()
            try {
                $streamErrors = @($InputObject | Invoke-CPCRename -NewDisplayName "Piped Cloud PC" 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
            }
            catch {
                $streamErrors = @($_)
            }
            $bindingErrors = @(@($streamErrors) + @($global:Error) | Where-Object { $_.Exception -is [System.Management.Automation.ParameterBindingException] })

            $bindingErrors.Count | Should -BeGreaterThan 0
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }
}
