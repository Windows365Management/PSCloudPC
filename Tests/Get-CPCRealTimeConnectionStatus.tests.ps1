<#
This file tests the Get-CPCRealTimeConnectionStatus function by using Pester.
Contract: GET /deviceManagement/virtualEndpoint/reports/getRealTimeRemoteConnectionStatus(cloudPcId='{id}')
returns a report stream (Content-Type application/octet-stream, so Content can be a byte array)
with TotalRowCount, Schema (Column/PropertyType) and Values (rows). The function returns one
object per row with the column names as properties, plus CloudPCName, CloudPCId, signInStatus and
daysSinceLastUse (DaysSinceLastSignIn). CloudPCName is the managed device name only: the report's
ManagedDeviceName column, else the looked-up Cloud PC's managedDeviceName, else empty; never the displayName.
The Cloud PC is resolved by an exact managedDeviceName match
(GET /deviceManagement/virtualEndpoint/cloudPCs?$filter=managedDeviceName eq '...') or by -CloudPCId
(GET cloudPCs/{id}), which also binds from the pipeline (id or CloudPCId property); zero or several
name matches stop before the report request.
https://learn.microsoft.com/graph/api/cloudpcreports-getrealtimeremoteconnectionstatus?view=graph-rest-beta
https://learn.microsoft.com/graph/api/virtualendpoint-list-cloudpcs?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Get-CPCRealTimeConnectionStatus" {

    BeforeAll {
        $CloudPCId = "00000000-0000-0000-0000-0000000000c1"
        $LookupUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs?`$filter=managedDeviceName+eq+'CPC-TEST-01'"
        $ReportUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/reports/getRealTimeRemoteConnectionStatus(cloudPcId='$CloudPCId')"
        $DefaultCloudPC = @{ id = $CloudPCId; displayName = "Cloud PC Test 01"; managedDeviceName = "CPC-TEST-01"; status = "provisioned" }
        $DuplicateCloudPC = @{ id = "00000000-0000-0000-0000-0000000000c2"; displayName = "Cloud PC Test 02"; managedDeviceName = "CPC-TEST-01"; status = "provisioned" }

        # Schema as returned live (LastActiveTime is returned although the docs don't list it)
        $Schema = @(
            @{ Column = "ManagedDeviceName"; PropertyType = "String" }
            @{ Column = "CloudPcId"; PropertyType = "String" }
            @{ Column = "DaysSinceLastSignIn"; PropertyType = "Int64" }
            @{ Column = "SignInStatus"; PropertyType = "String" }
            @{ Column = "LastActiveTime"; PropertyType = "DateTime" }
        )

        function New-ReportResponse {
            param ([object[]]$Rows, [switch]$AsString)
            $json = [ordered]@{ TotalRowCount = $Rows.Count; Schema = $Schema; Values = @($Rows) } | ConvertTo-Json -Depth 10
            if ($AsString) {
                return [pscustomobject]@{ Content = $json }
            }
            [pscustomobject]@{ Content = [System.Text.Encoding]::UTF8.GetBytes($json) }
        }
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        # Cloud PCs returned by the managedDeviceName lookup, by GET cloudPCs/{id} and by Get-CloudPC (Graph GET). Tests may replace this list.
        $GraphCloudPCs = @($DefaultCloudPC)
        # Report rows; $null returns one SignedIn row for the requested Cloud PC from $GraphCloudPCs. Tests may replace this.
        $ReportRows = $null
        # $true returns the report as a string instead of a byte array
        $ReportAsString = $false

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            $requestUri = ([uri]$Uri).OriginalString
            if ($requestUri -like "*/reports/getRealTimeRemoteConnectionStatus(*") {
                $rows = $ReportRows
                if ($null -eq $rows) {
                    $requestedId = [regex]::Match($requestUri, "cloudPcId='([^']*)'").Groups[1].Value
                    $reportCloudPC = @($GraphCloudPCs | Where-Object { $_.id -eq $requestedId })[0]
                    $rows = @(, @($reportCloudPC.managedDeviceName, $requestedId, 2, "SignedIn", "2026-10-12T08:00:00Z"))
                }
                New-ReportResponse -Rows $rows -AsString:$ReportAsString
            }
            elseif ($requestUri -match "/cloudPCs/([0-9a-f-]{36})$") {
                # GET cloudPCs/{id} returns the Cloud PC with that id
                $requestedId = $Matches[1]
                [pscustomobject]@{ Content = (@($GraphCloudPCs | Where-Object { $_.id -eq $requestedId })[0] | ConvertTo-Json -Depth 10) }
            }
            else {
                [pscustomobject]@{ Content = (@{ value = @($GraphCloudPCs) } | ConvertTo-Json -Depth 10) }
            }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { throw "Invoke-RestMethod must not be called by Get-CPCRealTimeConnectionStatus" }
    }

    Context "Request" {

        It "sends a GET to the report function with the Cloud PC id" {
            Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPCId | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                "$Uri" -eq $ReportUri -and $Method -eq "GET" -and $Headers.Authorization -eq "Bearer token"
            }
        }

        It "looks up the Cloud PC by managedDeviceName and returns one object per result" {
            $result = @(Get-CPCRealTimeConnectionStatus -Name "CPC-TEST-01")

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -eq $LookupUri
            }
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -ceq $ReportUri -and $Method -eq "GET"
            }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
            $result.Count | Should -Be 1
            $result | ForEach-Object { $_ | Should -Not -BeOfType [string] }
            $result[0].CloudPCId | Should -Be $CloudPCId
        }
    }

    Context "Parsing the octet-stream report" {

        It "returns one object per row with the column names as properties (byte[] content)" {
            $result = @(Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPCId)

            $result.Count | Should -Be 1
            $result[0].ManagedDeviceName | Should -Be "CPC-TEST-01"
            $result[0].DaysSinceLastSignIn | Should -Be 2
            $result[0].SignInStatus | Should -Be "SignedIn"
            $result[0].LastActiveTime | Should -Not -BeNullOrEmpty
        }

        It "fills the existing properties that have a source" {
            $result = @(Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPCId)

            $result[0].CloudPCId | Should -Be $CloudPCId
            $result[0].signInStatus | Should -Be "SignedIn"
            $result[0].daysSinceLastUse | Should -Be 2
        }

        It "sets CloudPCName to the managed device name, not the id, with -CloudPCId" {
            $result = @(Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPCId)

            $result[0].CloudPCName | Should -Be "CPC-TEST-01"
        }

        It "sets CloudPCName to the managed device name with -Name" {
            $result = @(Get-CPCRealTimeConnectionStatus -Name "CPC-TEST-01")

            $result[0].CloudPCName | Should -Be "CPC-TEST-01"
        }

        It "names the Cloud PC in CloudPCName by its managed device name, not its display name" {
            # Display names change (rename, Windows App, "<policy> - <user>"); the managed device name is what -Name expects
            $result = @(Get-CPCRealTimeConnectionStatus -Name "CPC-TEST-01")

            $result[0].CloudPCName | Should -BeExactly "CPC-TEST-01"
        }

        It "uses the looked-up managedDeviceName, not the displayName, when the report column is empty (-Name)" {
            $ReportRows = @(, @("", $CloudPCId, 2, "SignedIn", "2026-10-12T08:00:00Z"))

            $result = @(Get-CPCRealTimeConnectionStatus -Name "CPC-TEST-01")

            $result[0].CloudPCName | Should -BeExactly "CPC-TEST-01"
        }

        It "uses the looked-up managedDeviceName, not the displayName, when the report column is <Case> (-CloudPCId)" -ForEach @(
            @{ Case = "null"; DeviceName = $null }
            @{ Case = "empty"; DeviceName = "" }
            @{ Case = "whitespace"; DeviceName = " " }
        ) {
            # The merged cmdlet looks up the Cloud PC for -CloudPCId too (GET cloudPCs/{id})
            $ReportRows = @(, @($DeviceName, $CloudPCId, 2, "SignedIn", "2026-10-12T08:00:00Z"))

            $result = @(Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPCId)

            $result[0].CloudPCName | Should -BeExactly "CPC-TEST-01"
            $result[0].CloudPCId | Should -Be $CloudPCId
        }

        It "leaves CloudPCName empty (no id, no displayName) when the report column is <Case> and the Cloud PC has no managed device name (-CloudPCId)" -ForEach @(
            @{ Case = "null"; DeviceName = $null }
            @{ Case = "empty"; DeviceName = "" }
            @{ Case = "whitespace"; DeviceName = " " }
        ) {
            $GraphCloudPCs = @(@{ id = $CloudPCId; displayName = "Cloud PC Test 01"; managedDeviceName = $null; status = "provisioned" })
            $ReportRows = @(, @($DeviceName, $CloudPCId, 2, "SignedIn", "2026-10-12T08:00:00Z"))

            $result = @(Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPCId)

            $result.Count | Should -Be 1
            $result[0].CloudPCName | Should -BeNullOrEmpty
            $result[0].CloudPCId | Should -Be $CloudPCId
            ($result | Out-String) | Should -Not -BeLike "*Cloud PC Test 01*"
        }

        It "prefers the report's ManagedDeviceName column over a different looked-up name (<Parameter>)" -ForEach @(
            @{ Parameter = "Name" }
            @{ Parameter = "CloudPCId" }
        ) {
            $ReportRows = @(, @("CPC-REPORT-01", $CloudPCId, 2, "SignedIn", "2026-10-12T08:00:00Z"))
            $lookupValue = if ($Parameter -eq "Name") { "CPC-TEST-01" } else { $CloudPCId }
            $parameters = @{ $Parameter = $lookupValue }

            $result = @(Get-CPCRealTimeConnectionStatus @parameters)

            $result.Count | Should -Be 1
            $result[0].CloudPCName | Should -BeExactly "CPC-REPORT-01"
        }

        It "parses string content as well" {
            $ReportAsString = $true

            $result = @(Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPCId)

            $result.Count | Should -Be 1
            $result[0].SignInStatus | Should -Be "SignedIn"
        }

        It "no longer returns the properties without a source" {
            $result = @(Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPCId)

            $names = $result[0].PSObject.Properties.Name
            foreach ($property in @("signInDateTime", "signOutDateTime", "durationInSeconds", "usageStatus")) {
                $names | Should -Not -Contain $property
            }
        }

        It "returns nothing (no error, no text) when the report has no rows" {
            $ReportRows = @()

            $result = @(Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPCId -ErrorVariable statusErrors)

            $result.Count | Should -Be 0
            $statusErrors.Count | Should -Be 0
        }

        It "returns nothing, not a message, when Graph returns no results" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { "$Uri" -like "*getRealTimeRemoteConnectionStatus*" } -MockWith {
                [pscustomobject]@{ Content = [byte[]]@() }
            }

            $result = Get-CPCRealTimeConnectionStatus -Name "CPC-TEST-01"

            $result | Should -BeNullOrEmpty
        }
    }

    Context "Name lookup" {

        It "reports an error and sends no GET when <Case> (-ErrorAction <Action>)" -ForEach @(
            @{ Case = "no Cloud PC matches"; MatchCount = 0; Action = "Stop"; Message = "No Cloud PC found*" }
            @{ Case = "no Cloud PC matches"; MatchCount = 0; Action = "SilentlyContinue"; Message = "No Cloud PC found*" }
            @{ Case = "two Cloud PCs match"; MatchCount = 2; Action = "Stop"; Message = "2 Cloud PCs found*00000000-0000-0000-0000-0000000000c2*" }
            @{ Case = "two Cloud PCs match"; MatchCount = 2; Action = "SilentlyContinue"; Message = "2 Cloud PCs found*00000000-0000-0000-0000-0000000000c2*" }
        ) {
            $GraphCloudPCs = @(@($DefaultCloudPC, $DuplicateCloudPC) | Select-Object -First $MatchCount)

            if ($Action -eq "Stop") {
                { Get-CPCRealTimeConnectionStatus -Name "CPC-TEST-01" -ErrorAction Stop } | Should -Throw -ExpectedMessage $Message
            }
            else {
                # A problem with one Cloud PC is a non-terminating error
                Get-CPCRealTimeConnectionStatus -Name "CPC-TEST-01" -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors
                # -ErrorVariable also collects the Graph errors the module caught; count only the module's own records
                $moduleErrors = @($cloudPCErrors | Where-Object FullyQualifiedErrorId -like "PSCloudPC.CloudPCError*")
                $moduleErrors.Count | Should -Be 1
                $moduleErrors[0].Exception.Message | Should -BeLike $Message
            }

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly -ParameterFilter { "$Uri" -like "*getRealTimeRemoteConnectionStatus*" }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "escapes a single quote in -Name" {
            $GraphCloudPCs = @(@{ id = $CloudPCId; displayName = "Cloud PC Test 01"; managedDeviceName = "CPC-O'TEST"; status = "provisioned" })

            { Get-CPCRealTimeConnectionStatus -Name "CPC-O'TEST" } | Should -Not -Throw

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                [uri]::UnescapeDataString(([uri]$Uri).OriginalString) -like "*managedDeviceName+eq+'CPC-O''TEST'"
            }
        }
    }

    Context "Graph error" {

        It "throws with the Graph error code (-CloudPCId)" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { "$Uri" -like "*getRealTimeRemoteConnectionStatus*" } -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 404 (Not Found).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "ObjectNotFound", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"NotFound","message":"Cloud PC not found"}}')
                throw $errorRecord
            }

            { Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPCId -ErrorAction Stop } | Should -Throw "*NotFound: Cloud PC not found*"
        }

        It "throws the Graph error code when the GET fails (-Name)" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { "$Uri" -like "*getRealTimeRemoteConnectionStatus*" } -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 403 (Forbidden).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Forbidden","message":"Insufficient privileges"}}')
                throw $errorRecord
            }

            { Get-CPCRealTimeConnectionStatus -Name "CPC-TEST-01" -ErrorAction Stop } | Should -Throw -ExpectedMessage "*Forbidden: Insufficient privileges*"
        }
    }

    Context "Pipeline input" {

        BeforeEach {
            $PipedCloudPCs = @(
                @{ id = "00000000-0000-0000-0000-0000000000d1"; displayName = "Cloud PC Piped 01"; managedDeviceName = "CPC-PIPED-01"; status = "provisioned" }
                @{ id = "00000000-0000-0000-0000-0000000000d2"; displayName = "Cloud PC Piped 02"; managedDeviceName = "CPC-PIPED-02"; status = "provisioned" }
            )
            # Get-CloudPC lists these Cloud PCs, GET cloudPCs/{id} returns the one with that id and the report has a row for it
            $GraphCloudPCs = $PipedCloudPCs
        }

        It "sends one request per Cloud PC piped from Get-CloudPC, each with its own id" {
            Get-CloudPC | Get-CPCRealTimeConnectionStatus

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 2 -Exactly -ParameterFilter { "$Uri" -like "*getRealTimeRemoteConnectionStatus*" }
            foreach ($piped in $PipedCloudPCs) {
                Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                    ([uri]$Uri).OriginalString -ceq "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/reports/getRealTimeRemoteConnectionStatus(cloudPcId='$($piped.id)')" -and
                    $Method -eq "GET"
                }
            }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "binds a piped object by its CloudPCId property" {
            [pscustomobject]@{ CloudPCId = "00000000-0000-0000-0000-0000000000d2" } | Get-CPCRealTimeConnectionStatus

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -ceq "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/reports/getRealTimeRemoteConnectionStatus(cloudPcId='00000000-0000-0000-0000-0000000000d2')"
            }
        }

        It "leaves CloudPCName empty, never the display name, when the managed device name is <Case>" -ForEach @(
            @{ Case = "null"; ManagedDeviceName = $null }
            @{ Case = "empty"; ManagedDeviceName = "" }
        ) {
            # No managed device name while provisioning and for Windows 365 Business; a display name can't be used with -Name
            # The report row is built from this Cloud PC, so its ManagedDeviceName column is empty as well
            $PipedCloudPCs[0].managedDeviceName = $ManagedDeviceName

            $result = @([pscustomobject]@{ id = "00000000-0000-0000-0000-0000000000d1" } | Get-CPCRealTimeConnectionStatus)

            $result.Count | Should -BeGreaterThan 0
            $result[0].CloudPCName | Should -BeNullOrEmpty
            ($result | Out-String) | Should -Not -BeLike "*Cloud PC Piped 01*"
        }

        It "writes one error for a Cloud PC that fails with 409 Conflict and continues with the next piped Cloud PC" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -like "*getRealTimeRemoteConnectionStatus*00000000-0000-0000-0000-0000000000d1*" } -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 409 (Conflict).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Conflict","message":"Another action is still active"}}')
                throw $errorRecord
            }

            Get-CloudPC | Get-CPCRealTimeConnectionStatus -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors

            # -ErrorVariable also collects the Graph errors the module caught; count only the module's own records
            $moduleErrors = @($cloudPCErrors | Where-Object FullyQualifiedErrorId -like "PSCloudPC.CloudPCError*")
            $moduleErrors.Count | Should -Be 1
            $moduleErrors[0].Exception.Message | Should -BeLike "*00000000-0000-0000-0000-0000000000d1*Conflict: Another action is still active*"
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 2 -Exactly -ParameterFilter { "$Uri" -like "*getRealTimeRemoteConnectionStatus*" }
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -like "*getRealTimeRemoteConnectionStatus*00000000-0000-0000-0000-0000000000d2*"
            }
        }

        It "stops at the first failed Cloud PC with -ErrorAction Stop" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -like "*getRealTimeRemoteConnectionStatus*00000000-0000-0000-0000-0000000000d1*" } -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 409 (Conflict).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Conflict","message":"Another action is still active"}}')
                throw $errorRecord
            }

            { Get-CloudPC | Get-CPCRealTimeConnectionStatus -ErrorAction Stop } | Should -Throw -ExpectedMessage "*Conflict: Another action is still active*"

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -like "*getRealTimeRemoteConnectionStatus*00000000-0000-0000-0000-0000000000d2*"
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
                $streamErrors = @($InputObject | Get-CPCRealTimeConnectionStatus 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
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
