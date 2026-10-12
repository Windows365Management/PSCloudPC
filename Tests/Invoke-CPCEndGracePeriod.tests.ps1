<#
This file tests the Invoke-CPCEndGracePeriod function by using Pester.
Contract: POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/endGracePeriod without a request body, once per Cloud PC.
Ending the grace period deprovisions the Cloud PC immediately (#138), so ConfirmImpact is High, the Cloud PCs are listed
in a warning first, and only -Force together with -Confirm:$false skips every prompt.
-Name must match the managedDeviceName of exactly one Cloud PC with status inGracePeriod; -All acts on every
Cloud PC with status inGracePeriod.
https://learn.microsoft.com/graph/api/cloudpc-endgraceperiod?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Invoke-CPCEndGracePeriod" {

    BeforeAll {
        $BaseUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs"
        $LookupUri = "$BaseUri`?`$filter=managedDeviceName+eq+'CPC-TEST-01'"
        $GraceCloudPC = @{ id = "00000000-0000-0000-0000-0000000000c1"; displayName = "Cloud PC Test 01"; managedDeviceName = "CPC-TEST-01"; status = "inGracePeriod" }
        $DuplicateCloudPC = @{ id = "00000000-0000-0000-0000-0000000000c2"; displayName = "Cloud PC Test 02"; managedDeviceName = "CPC-TEST-01"; status = "inGracePeriod" }
        $ProvisionedCloudPC = @{ id = "00000000-0000-0000-0000-0000000000c3"; displayName = "Cloud PC Test 03"; managedDeviceName = "CPC-TEST-03"; status = "provisioned" }
        $OtherGraceCloudPC = @{ id = "00000000-0000-0000-0000-0000000000c4"; displayName = "Cloud PC Test 04"; managedDeviceName = "CPC-TEST-04"; status = "inGracePeriod" }
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        # Cloud PCs returned by Graph for the name lookup and for the -All list. Tests may replace this list.
        $GraphCloudPCs = @($GraceCloudPC)

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            [pscustomobject]@{ Content = (@{ value = @($GraphCloudPCs) } | ConvertTo-Json -Depth 10) }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { }
    }

    It "is a high impact action" {
        (Get-Command Invoke-CPCEndGracePeriod).ScriptBlock.Attributes |
            Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] } |
            ForEach-Object { $_.ConfirmImpact } |
            Should -Be ([System.Management.Automation.ConfirmImpact]::High)
    }

    Context "-Name" {

        It "POSTs endGracePeriod without a body for the one Cloud PC with -Force -Confirm:`$false" {
            $result = Invoke-CPCEndGracePeriod -Name "CPC-TEST-01" -Force -Confirm:$false -WarningAction SilentlyContinue

            $result | Should -BeNullOrEmpty
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -eq $LookupUri
            }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq "$BaseUri/$($GraceCloudPC.id)/endGracePeriod" -and
                $Method -eq "POST" -and
                $null -eq $Body
            }
        }

        It "reports an error and sends no POST when the Cloud PC is not in its grace period (-ErrorAction <Action>)" -ForEach @(
            @{ Action = "Stop" }
            @{ Action = "SilentlyContinue" }
        ) {
            $GraphCloudPCs = @(@{ id = $GraceCloudPC.id; displayName = "Cloud PC Test 01"; managedDeviceName = "CPC-TEST-01"; status = "provisioned" })

            if ($Action -eq "Stop") {
                { Invoke-CPCEndGracePeriod -Name "CPC-TEST-01" -Force -Confirm:$false -ErrorAction Stop } | Should -Throw -ExpectedMessage "*is not in its grace period (status: provisioned)"
            }
            else {
                # A problem with one Cloud PC is a non-terminating error
                Invoke-CPCEndGracePeriod -Name "CPC-TEST-01" -Force -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors
                # -ErrorVariable also collects the Graph errors the module caught; count only the module's own records
                $moduleErrors = @($cloudPCErrors | Where-Object FullyQualifiedErrorId -like "PSCloudPC.CloudPCError*")
                $moduleErrors.Count | Should -Be 1
                $moduleErrors[0].Exception.Message | Should -BeLike "*is not in its grace period (status: provisioned)"
            }

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "reports an error and sends no POST when <Case> (-ErrorAction <Action>)" -ForEach @(
            @{ Case = "no Cloud PC matches"; MatchCount = 0; Action = "Stop"; Message = "No Cloud PC found*" }
            @{ Case = "no Cloud PC matches"; MatchCount = 0; Action = "SilentlyContinue"; Message = "No Cloud PC found*" }
            @{ Case = "two Cloud PCs match"; MatchCount = 2; Action = "Stop"; Message = "2 Cloud PCs found*" }
            @{ Case = "two Cloud PCs match"; MatchCount = 2; Action = "SilentlyContinue"; Message = "2 Cloud PCs found*" }
        ) {
            $GraphCloudPCs = @(@($GraceCloudPC, $DuplicateCloudPC) | Select-Object -First $MatchCount)

            if ($Action -eq "Stop") {
                { Invoke-CPCEndGracePeriod -Name "CPC-TEST-01" -Force -Confirm:$false -ErrorAction Stop } | Should -Throw -ExpectedMessage $Message
            }
            else {
                # A problem with one Cloud PC is a non-terminating error
                Invoke-CPCEndGracePeriod -Name "CPC-TEST-01" -Force -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors
                # -ErrorVariable also collects the Graph errors the module caught; count only the module's own records
                $moduleErrors = @($cloudPCErrors | Where-Object FullyQualifiedErrorId -like "PSCloudPC.CloudPCError*")
                $moduleErrors.Count | Should -Be 1
                $moduleErrors[0].Exception.Message | Should -BeLike $Message
            }

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "sends no POST with -WhatIf, also with -Force" {
            Invoke-CPCEndGracePeriod -Name "CPC-TEST-01" -Force -WhatIf -WarningAction SilentlyContinue

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "-All" {

        BeforeEach {
            $GraphCloudPCs = @($GraceCloudPC, $ProvisionedCloudPC, $OtherGraceCloudPC)
        }

        It "lists every Cloud PC in grace period in a warning and POSTs only to those" {
            Invoke-CPCEndGracePeriod -All -Force -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -eq $BaseUri
            }
            @($warnings).Count | Should -Be 1
            $warnings[0].Message | Should -BeLike "*deprovisions 2 Cloud PC(s)*CPC-TEST-01 ($($GraceCloudPC.id))*CPC-TEST-04 ($($OtherGraceCloudPC.id))*"
            $warnings[0].Message | Should -Not -BeLike "*CPC-TEST-03*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 2 -Exactly
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq "$BaseUri/$($GraceCloudPC.id)/endGracePeriod" -and $Method -eq "POST" -and $null -eq $Body
            }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq "$BaseUri/$($OtherGraceCloudPC.id)/endGracePeriod" -and $Method -eq "POST" -and $null -eq $Body
            }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly -ParameterFilter {
                $Uri -like "*$($ProvisionedCloudPC.id)*"
            }
        }

        It "sends no POST with -WhatIf, also with -Force, and still lists the Cloud PCs" {
            Invoke-CPCEndGracePeriod -All -Force -WhatIf -WarningVariable warnings -WarningAction SilentlyContinue

            $warnings[0].Message | Should -BeLike "*deprovisions 2 Cloud PC(s)*"
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "stops and sends no POST when no Cloud PC is in its grace period (-ErrorAction <Action>)" -ForEach @(
            @{ Action = "Stop" }
            @{ Action = "SilentlyContinue" }
        ) {
            $GraphCloudPCs = @($ProvisionedCloudPC)

            { Invoke-CPCEndGracePeriod -All -Force -Confirm:$false -ErrorAction $Action } | Should -Throw -ExpectedMessage "No Cloud PCs found in grace period"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "writes one error with the Graph error code for a failed POST and continues with the next Cloud PC" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -ParameterFilter { $Uri -like "*$($GraceCloudPC.id)*" } -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 400 (Bad Request).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"Cloud PC is not in grace period"}}')
                throw $errorRecord
            }

            Invoke-CPCEndGracePeriod -All -Force -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors -WarningAction SilentlyContinue

            # -ErrorVariable also collects the Graph errors the module caught; count only the module's own records
            $moduleErrors = @($cloudPCErrors | Where-Object FullyQualifiedErrorId -like "PSCloudPC.CloudPCError*")
            $moduleErrors.Count | Should -Be 1
            $moduleErrors[0].Exception.Message | Should -BeLike "*$($GraceCloudPC.id)*BadRequest: Cloud PC is not in grace period*"
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 2 -Exactly
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq "$BaseUri/$($OtherGraceCloudPC.id)/endGracePeriod"
            }
        }

        It "stops at the first failed POST with -ErrorAction Stop" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -ParameterFilter { $Uri -like "*$($GraceCloudPC.id)*" } -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 400 (Bad Request).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"Cloud PC is not in grace period"}}')
                throw $errorRecord
            }

            { Invoke-CPCEndGracePeriod -All -Force -Confirm:$false -ErrorAction Stop -WarningAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "*BadRequest: Cloud PC is not in grace period*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
        }
    }

    Context "Pipeline input" {

        BeforeEach {
            $PipedCloudPCs = @(
                @{ id = "00000000-0000-0000-0000-0000000000d1"; displayName = "Cloud PC Piped 01"; managedDeviceName = "CPC-PIPED-01"; status = "inGracePeriod" }
                @{ id = "00000000-0000-0000-0000-0000000000d2"; displayName = "Cloud PC Piped 02"; managedDeviceName = "CPC-PIPED-02"; status = "inGracePeriod" }
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
            Get-CloudPC | Invoke-CPCEndGracePeriod -Force -Confirm:$false -WarningAction SilentlyContinue

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 2 -Exactly
            foreach ($piped in $PipedCloudPCs) {
                Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                    ([uri]$Uri).OriginalString -ceq "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$($piped.id)/endGracePeriod" -and
                    $Method -eq "POST" -and
                    $null -eq $Body
                }
            }
        }

        It "binds a piped object by its CloudPCId property" {
            [pscustomobject]@{ CloudPCId = "00000000-0000-0000-0000-0000000000d2" } | Invoke-CPCEndGracePeriod -Force -Confirm:$false -WarningAction SilentlyContinue

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -ceq "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/00000000-0000-0000-0000-0000000000d2/endGracePeriod"
            }
        }

        It "sends nothing for piped Cloud PCs with -WhatIf" {
            Get-CloudPC | Invoke-CPCEndGracePeriod -Force -WarningAction SilentlyContinue -WhatIf

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "writes an error and sends no request for a piped Cloud PC that is not in its grace period, and continues with the next one" {
            $PipedCloudPCs[0].status = "provisioned"

            Get-CloudPC | Invoke-CPCEndGracePeriod -Force -Confirm:$false -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors

            # -ErrorVariable also collects the Graph errors the module caught; count only the module's own records
            $moduleErrors = @($cloudPCErrors | Where-Object FullyQualifiedErrorId -like "PSCloudPC.CloudPCError*")
            $moduleErrors.Count | Should -Be 1
            $moduleErrors[0].Exception.Message | Should -BeLike "*00000000-0000-0000-0000-0000000000d1*is not in its grace period (status: provisioned)"
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -like "*00000000-0000-0000-0000-0000000000d2/endGracePeriod"
            }
        }

        It "warns per piped Cloud PC before deprovisioning it" {
            Get-CloudPC | Invoke-CPCEndGracePeriod -Force -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue

            @($warnings).Count | Should -Be 2
            $warnings[0].Message | Should -BeLike "*CPC-PIPED-01 (00000000-0000-0000-0000-0000000000d1)*"
            $warnings[1].Message | Should -BeLike "*CPC-PIPED-02 (00000000-0000-0000-0000-0000000000d2)*"
        }

        It "writes one error for a Cloud PC that fails with 409 Conflict and continues with the next piped Cloud PC" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -ParameterFilter { ([uri]$Uri).OriginalString -like "*00000000-0000-0000-0000-0000000000d1*" } -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 409 (Conflict).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Conflict","message":"Another action is still active"}}')
                throw $errorRecord
            }

            Get-CloudPC | Invoke-CPCEndGracePeriod -Force -Confirm:$false -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors

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

            { Get-CloudPC | Invoke-CPCEndGracePeriod -Force -Confirm:$false -WarningAction SilentlyContinue -ErrorAction Stop } | Should -Throw -ExpectedMessage "*Conflict: Another action is still active*"

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
                $streamErrors = @($InputObject | Invoke-CPCEndGracePeriod -Force -Confirm:$false -WarningAction SilentlyContinue 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
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
