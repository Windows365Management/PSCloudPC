<#
This file tests the Invoke-CPCReboot function by using Pester.
Contract: POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/reboot without a request body.
The Cloud PC is resolved by an exact managedDeviceName match; zero or several matches stop before the POST.
https://learn.microsoft.com/graph/api/cloudpc-reboot?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Invoke-CPCReboot" {

    BeforeAll {
        $CloudPCId = "00000000-0000-0000-0000-0000000000c1"
        $LookupUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs?`$filter=managedDeviceName+eq+'CPC-TEST-01'"
        $ActionUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$CloudPCId/reboot"
        $DefaultCloudPC = @{ id = $CloudPCId; displayName = "Cloud PC Test 01"; managedDeviceName = "CPC-TEST-01"; status = "provisioned" }
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

    Context "Happy path" {

        It "looks up the Cloud PC by managedDeviceName and POSTs reboot without a body" {
            $result = Invoke-CPCReboot -Name "CPC-TEST-01"

            $result | Should -BeNullOrEmpty
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -eq $LookupUri
            }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq $ActionUri -and
                $Method -eq "POST" -and
                $null -eq $Body
            }
        }
    }

    Context "Cloud PC lookup" {

        It "errors and sends no POST when no Cloud PC matches" {
            $GraphCloudPCs = @()

            { Invoke-CPCReboot -Name "CPC-TEST-01" -ErrorAction Stop } | Should -Throw -ExpectedMessage "No Cloud PC found with managed device name 'CPC-TEST-01'*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "errors and sends no POST when two Cloud PCs have the same name" {
            $GraphCloudPCs = @(
                $DefaultCloudPC
                @{ id = "00000000-0000-0000-0000-0000000000c2"; displayName = "Cloud PC Test 02"; managedDeviceName = "CPC-TEST-01"; status = "provisioned" }
            )

            { Invoke-CPCReboot -Name "CPC-TEST-01" -ErrorAction Stop } | Should -Throw -ExpectedMessage "2 Cloud PCs found with managed device name 'CPC-TEST-01'*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Lookup errors with -ErrorAction SilentlyContinue" {
        # A failed lookup is a non-terminating error for that Cloud PC, so the command continues without a request

        It "writes one error and sends no POST when no Cloud PC matches" {
            $GraphCloudPCs = @()

            Invoke-CPCReboot -Name "CPC-TEST-01" -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors

            # -ErrorVariable also collects the Graph errors the module caught; count only the module's own records
            $moduleErrors = @($cloudPCErrors | Where-Object FullyQualifiedErrorId -like "PSCloudPC.CloudPCError*")
            $moduleErrors.Count | Should -Be 1
            $moduleErrors[0].Exception.Message | Should -BeLike "No Cloud PC found*"
            $moduleErrors[0].CategoryInfo.Category | Should -Be "ObjectNotFound"
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "writes one error and sends no POST when two Cloud PCs have the same name" {
            $GraphCloudPCs = @(
                $DefaultCloudPC
                @{ id = "00000000-0000-0000-0000-0000000000c2"; displayName = "Cloud PC Test 02"; managedDeviceName = "CPC-TEST-01"; status = "provisioned" }
            )

            Invoke-CPCReboot -Name "CPC-TEST-01" -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors

            # -ErrorVariable also collects the Graph errors the module caught; count only the module's own records
            $moduleErrors = @($cloudPCErrors | Where-Object FullyQualifiedErrorId -like "PSCloudPC.CloudPCError*")
            $moduleErrors.Count | Should -Be 1
            $moduleErrors[0].Exception.Message | Should -BeLike "2 Cloud PCs found*"
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "WhatIf" {

        It "sends no POST with -WhatIf" {
            Invoke-CPCReboot -Name "CPC-TEST-01" -WhatIf

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Graph error" {

        It "throws the Graph error code when the POST fails" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 400 (Bad Request).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"Action not supported"}}')
                throw $errorRecord
            }

            { Invoke-CPCReboot -Name "CPC-TEST-01" -ErrorAction Stop } | Should -Throw -ExpectedMessage "*BadRequest: Action not supported*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
        }
    }

    It "names the Cloud PC by its managed device name, not its display name, in error messages" {
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
            $exception = [System.Exception]::new("Response status code does not indicate success: 400 (Bad Request).")
            $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
            $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"Action not supported"}}')
            throw $errorRecord
        }

        Invoke-CPCReboot -Name "CPC-TEST-01" -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors

        $moduleErrors = @($cloudPCErrors | Where-Object FullyQualifiedErrorId -like "PSCloudPC.CloudPCError*")
        $moduleErrors.Count | Should -Be 1
        $moduleErrors[0].Exception.Message | Should -BeLike "Reboot failed for Cloud PC CPC-TEST-01 ($CloudPCId):*"
        $moduleErrors[0].Exception.Message | Should -Not -BeLike "*Cloud PC Test 01*"
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
            Get-CloudPC | Invoke-CPCReboot

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 2 -Exactly
            foreach ($piped in $PipedCloudPCs) {
                Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                    ([uri]$Uri).OriginalString -ceq "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$($piped.id)/reboot" -and
                    $Method -eq "POST" -and
                    $null -eq $Body
                }
            }
        }

        It "binds a piped object by its CloudPCId property" {
            [pscustomobject]@{ CloudPCId = "00000000-0000-0000-0000-0000000000d2" } | Invoke-CPCReboot

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -ceq "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/00000000-0000-0000-0000-0000000000d2/reboot"
            }
        }

        It "sends nothing for piped Cloud PCs with -WhatIf" {
            Get-CloudPC | Invoke-CPCReboot -WhatIf

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "names a Cloud PC without a managed device name as (no device name) plus its id in error messages, never by display name" {
            $PipedCloudPCs[0].managedDeviceName = $null
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 409 (Conflict).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Conflict","message":"Another action is still active"}}')
                throw $errorRecord
            }

            [pscustomobject]@{ id = "00000000-0000-0000-0000-0000000000d1" } | Invoke-CPCReboot -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors

            $moduleErrors = @($cloudPCErrors | Where-Object FullyQualifiedErrorId -like "PSCloudPC.CloudPCError*")
            $moduleErrors.Count | Should -Be 1
            $moduleErrors[0].Exception.Message | Should -BeLike "Reboot failed for Cloud PC (no device name) (00000000-0000-0000-0000-0000000000d1):*"
            $moduleErrors[0].Exception.Message | Should -Not -BeLike "*Cloud PC Piped 01*"
        }

        It "writes one error for a Cloud PC that fails with 409 Conflict and continues with the next piped Cloud PC" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -ParameterFilter { ([uri]$Uri).OriginalString -like "*00000000-0000-0000-0000-0000000000d1*" } -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 409 (Conflict).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Conflict","message":"Another action is still active"}}')
                throw $errorRecord
            }

            Get-CloudPC | Invoke-CPCReboot -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors

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

            { Get-CloudPC | Invoke-CPCReboot -ErrorAction Stop } | Should -Throw -ExpectedMessage "*Conflict: Another action is still active*"

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
                $streamErrors = @($InputObject | Invoke-CPCReboot 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
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
