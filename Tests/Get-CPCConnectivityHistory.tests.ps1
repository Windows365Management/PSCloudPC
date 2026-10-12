<#
This file tests the Get-CPCConnectivityHistory function by using Pester.
Contract: GET /deviceManagement/virtualEndpoint/cloudPCs/{id}/getCloudPcConnectivityHistory.
The Cloud PC is resolved by an exact managedDeviceName match or by -CloudPCId (GET cloudPCs/{id}), which also
binds from the pipeline (id or CloudPCId property); zero or several name matches stop before the GET.
https://learn.microsoft.com/graph/api/cloudpc-getcloudpcconnectivityhistory?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Get-CPCConnectivityHistory" {

    BeforeAll {
        $CloudPCId = "00000000-0000-0000-0000-0000000000c1"
        $LookupUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs?`$filter=managedDeviceName+eq+'CPC-TEST-01'"
        $RequestUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$CloudPCId/getCloudPcConnectivityHistory"
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

        # Cloud PCs returned by the managedDeviceName lookup and by Get-CloudPC (Graph GET). Tests may replace this list.
        $GraphCloudPCs = @($DefaultCloudPC)

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            [pscustomobject]@{ Content = (@{ value = @($GraphCloudPCs) } | ConvertTo-Json -Depth 10) }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
            [pscustomobject]@{ value = @([pscustomobject]@{ eventName = "Connect"; eventResult = "success" }, [pscustomobject]@{ eventName = "Disconnect"; eventResult = "success" }) }
        }
    }

    It "looks up the Cloud PC by managedDeviceName and returns one object per result" {
        $result = @(Get-CPCConnectivityHistory -Name "CPC-TEST-01")

        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            ([uri]$Uri).OriginalString -eq $LookupUri
        }
        Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            ([uri]$Uri).OriginalString -ceq $RequestUri -and $Method -eq "GET"
        }
        $result.Count | Should -Be 2
        $result | ForEach-Object { $_ | Should -Not -BeOfType [string] }
        $result[0].CloudPCId | Should -Be $CloudPCId
    }

    It "returns nothing, not a message, when Graph returns no results" {
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { [pscustomobject]@{ value = @() } }

        $result = Get-CPCConnectivityHistory -Name "CPC-TEST-01"

        $result | Should -BeNullOrEmpty
    }

    It "reports an error and sends no GET when <Case> (-ErrorAction <Action>)" -ForEach @(
        @{ Case = "no Cloud PC matches"; MatchCount = 0; Action = "Stop"; Message = "No Cloud PC found*" }
        @{ Case = "no Cloud PC matches"; MatchCount = 0; Action = "SilentlyContinue"; Message = "No Cloud PC found*" }
        @{ Case = "two Cloud PCs match"; MatchCount = 2; Action = "Stop"; Message = "2 Cloud PCs found*" }
        @{ Case = "two Cloud PCs match"; MatchCount = 2; Action = "SilentlyContinue"; Message = "2 Cloud PCs found*" }
    ) {
        $GraphCloudPCs = @(@($DefaultCloudPC, $DuplicateCloudPC) | Select-Object -First $MatchCount)

        if ($Action -eq "Stop") {
            { Get-CPCConnectivityHistory -Name "CPC-TEST-01" -ErrorAction Stop } | Should -Throw -ExpectedMessage $Message
        }
        else {
            # A problem with one Cloud PC is a non-terminating error
            Get-CPCConnectivityHistory -Name "CPC-TEST-01" -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors
            # -ErrorVariable also collects the Graph errors the module caught; count only the module's own records
            $moduleErrors = @($cloudPCErrors | Where-Object FullyQualifiedErrorId -like "PSCloudPC.CloudPCError*")
            $moduleErrors.Count | Should -Be 1
            $moduleErrors[0].Exception.Message | Should -BeLike $Message
        }

        Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
    }

    It "throws the Graph error code when the GET fails" {
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
            $exception = [System.Exception]::new("Response status code does not indicate success: 403 (Forbidden).")
            $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
            $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Forbidden","message":"Insufficient privileges"}}')
            throw $errorRecord
        }

        { Get-CPCConnectivityHistory -Name "CPC-TEST-01" -ErrorAction Stop } | Should -Throw -ExpectedMessage "*Forbidden: Insufficient privileges*"
    }

    It "names the Cloud PC in CloudPCName by its managed device name, not its display name" {
        # Display names change (rename, Windows App, "<policy> - <user>"); the managed device name is what -Name expects
        $result = @(Get-CPCConnectivityHistory -Name "CPC-TEST-01")

        $result[0].CloudPCName | Should -BeExactly "CPC-TEST-01"
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
            Get-CloudPC | Get-CPCConnectivityHistory

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 2 -Exactly
            foreach ($piped in $PipedCloudPCs) {
                Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                    ([uri]$Uri).OriginalString -ceq "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$($piped.id)/getCloudPcConnectivityHistory" -and
                    $Method -eq "GET"
                }
            }
        }

        It "binds a piped object by its CloudPCId property" {
            [pscustomobject]@{ CloudPCId = "00000000-0000-0000-0000-0000000000d2" } | Get-CPCConnectivityHistory

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -ceq "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/00000000-0000-0000-0000-0000000000d2/getCloudPcConnectivityHistory"
            }
        }

        It "leaves CloudPCName empty, never the display name, when the managed device name is <Case>" -ForEach @(
            @{ Case = "null"; ManagedDeviceName = $null }
            @{ Case = "empty"; ManagedDeviceName = "" }
        ) {
            # No managed device name while provisioning and for Windows 365 Business; a display name can't be used with -Name
            $PipedCloudPCs[0].managedDeviceName = $ManagedDeviceName

            $result = @([pscustomobject]@{ id = "00000000-0000-0000-0000-0000000000d1" } | Get-CPCConnectivityHistory)

            $result.Count | Should -BeGreaterThan 0
            $result[0].CloudPCName | Should -BeNullOrEmpty
            ($result | Out-String) | Should -Not -BeLike "*Cloud PC Piped 01*"
        }

        It "writes one error for a Cloud PC that fails with 409 Conflict and continues with the next piped Cloud PC" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -ParameterFilter { ([uri]$Uri).OriginalString -like "*00000000-0000-0000-0000-0000000000d1*" } -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 409 (Conflict).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Conflict","message":"Another action is still active"}}')
                throw $errorRecord
            }

            Get-CloudPC | Get-CPCConnectivityHistory -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors

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

            { Get-CloudPC | Get-CPCConnectivityHistory -ErrorAction Stop } | Should -Throw -ExpectedMessage "*Conflict: Another action is still active*"

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
                $streamErrors = @($InputObject | Get-CPCConnectivityHistory 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
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
