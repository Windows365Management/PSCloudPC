<#
This file tests the Get-CPCRealTimeConnectionStatus function by using Pester.
Contract: GET /deviceManagement/virtualEndpoint/reports/getRealTimeRemoteConnectionStatus(cloudPcId='{id}')
returns a report stream (Content-Type application/octet-stream, so Content can be a byte array)
with TotalRowCount, Schema (Column/PropertyType) and Values (rows). The function returns one
object per row with the column names as properties, plus CloudPCName (managed device name),
CloudPCId, signInStatus and daysSinceLastUse (DaysSinceLastSignIn). -Name is resolved with
GET /deviceManagement/virtualEndpoint/cloudPCs?$filter=managedDeviceName eq '...' and must match
exactly one Cloud PC.
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
        $CloudPcId = "00000000-0000-0000-0000-000000000001"
        $ReportUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/reports/getRealTimeRemoteConnectionStatus(cloudPcId='$CloudPcId')"
        $LookupUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs?`$filter=managedDeviceName+eq+'CPC-TEST-0001'"

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

        $CloudPCs = @(@{ id = $CloudPcId; managedDeviceName = "CPC-TEST-0001"; displayName = "Policy - Test User" })
        $ReportRows = @(, @("CPC-TEST-0001", $CloudPcId, 2, "SignedIn", "2026-10-12T08:00:00Z"))

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            if ("$Uri" -like "*getRealTimeRemoteConnectionStatus*") {
                New-ReportResponse -Rows $ReportRows
            }
            else {
                [pscustomobject]@{ Content = (@{ value = @($CloudPCs) } | ConvertTo-Json -Depth 10) }
            }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { throw "Invoke-RestMethod must not be called by Get-CPCRealTimeConnectionStatus" }
    }

    Context "Request" {

        It "sends a GET to the report function with the Cloud PC id" {
            Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPcId | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                "$Uri" -eq $ReportUri -and $Method -eq "GET" -and $Headers.Authorization -eq "Bearer token"
            }
        }

        It "looks up -Name by managedDeviceName and uses the id it finds" {
            Get-CPCRealTimeConnectionStatus -Name "CPC-TEST-0001" | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter { "$Uri" -eq $LookupUri }
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter { "$Uri" -eq $ReportUri }
        }
    }

    Context "Parsing the octet-stream report" {

        It "returns one object per row with the column names as properties (byte[] content)" {
            $result = @(Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPcId)

            $result.Count | Should -Be 1
            $result[0].ManagedDeviceName | Should -Be "CPC-TEST-0001"
            $result[0].DaysSinceLastSignIn | Should -Be 2
            $result[0].SignInStatus | Should -Be "SignedIn"
            $result[0].LastActiveTime | Should -Not -BeNullOrEmpty
        }

        It "fills the existing properties that have a source" {
            $result = @(Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPcId)

            $result[0].CloudPCId | Should -Be $CloudPcId
            $result[0].signInStatus | Should -Be "SignedIn"
            $result[0].daysSinceLastUse | Should -Be 2
        }

        It "sets CloudPCName to the managed device name, not the id, with -CloudPCId" {
            $result = @(Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPcId)

            $result[0].CloudPCName | Should -Be "CPC-TEST-0001"
        }

        It "sets CloudPCName to the managed device name with -Name" {
            $result = @(Get-CPCRealTimeConnectionStatus -Name "CPC-TEST-0001")

            $result[0].CloudPCName | Should -Be "CPC-TEST-0001"
        }

        It "uses the looked-up managedDeviceName, not the displayName, when the report column is empty (-Name)" {
            $ReportRows = @(, @("", $CloudPcId, 2, "SignedIn", "2026-10-12T08:00:00Z"))

            $result = @(Get-CPCRealTimeConnectionStatus -Name "CPC-TEST-0001")

            $result[0].CloudPCName | Should -BeExactly "CPC-TEST-0001"
        }

        It "leaves CloudPCName empty (no id, no displayName) when the report column is <Case> (-CloudPCId)" -TestCases @(
            @{ Case = "null"; DeviceName = $null }
            @{ Case = "empty"; DeviceName = "" }
            @{ Case = "whitespace"; DeviceName = " " }
        ) {
            param($Case, $DeviceName)
            $ReportRows = @(, @($DeviceName, $CloudPcId, 2, "SignedIn", "2026-10-12T08:00:00Z"))

            $result = @(Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPcId)

            $result[0].CloudPCName | Should -BeNullOrEmpty
            $result[0].CloudPCId | Should -Be $CloudPcId
        }

        It "parses string content as well" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith { New-ReportResponse -Rows $ReportRows -AsString }

            $result = @(Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPcId)

            $result.Count | Should -Be 1
            $result[0].SignInStatus | Should -Be "SignedIn"
        }

        It "no longer returns the properties without a source" {
            $result = @(Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPcId)

            $names = $result[0].PSObject.Properties.Name
            foreach ($property in @("signInDateTime", "signOutDateTime", "durationInSeconds", "usageStatus")) {
                $names | Should -Not -Contain $property
            }
        }

        It "returns nothing (no error, no text) when the report has no rows" {
            $ReportRows = @()

            $result = @(Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPcId -ErrorVariable statusErrors)

            $result.Count | Should -Be 0
            $statusErrors.Count | Should -Be 0
        }
    }

    Context "Name lookup" {

        It "stops when -Name matches no Cloud PC and sends no report request" {
            $CloudPCs = @()

            { Get-CPCRealTimeConnectionStatus -Name "CPC-TEST-0001" } | Should -Throw "*No Cloud PC found*"
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -ParameterFilter { "$Uri" -like "*getRealTimeRemoteConnectionStatus*" }
        }

        It "stops when -Name matches more than one Cloud PC and lists the ids" {
            $CloudPCs = @(
                @{ id = "00000000-0000-0000-0000-000000000001"; managedDeviceName = "CPC-TEST-0001" }
                @{ id = "00000000-0000-0000-0000-000000000002"; managedDeviceName = "CPC-TEST-0001" }
            )

            { Get-CPCRealTimeConnectionStatus -Name "CPC-TEST-0001" } | Should -Throw "*00000000-0000-0000-0000-000000000002*"
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -ParameterFilter { "$Uri" -like "*getRealTimeRemoteConnectionStatus*" }
        }

        It "still stops with -ErrorAction SilentlyContinue" {
            $CloudPCs = @()

            { Get-CPCRealTimeConnectionStatus -Name "CPC-TEST-0001" -ErrorAction SilentlyContinue } | Should -Throw "*No Cloud PC found*"
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -ParameterFilter { "$Uri" -like "*getRealTimeRemoteConnectionStatus*" }
        }

        It "escapes a single quote in -Name" {
            { Get-CPCRealTimeConnectionStatus -Name "CPC-O'TEST" } | Should -Not -Throw

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                [uri]::UnescapeDataString(([uri]$Uri).OriginalString) -like "*managedDeviceName+eq+'CPC-O''TEST'"
            }
        }
    }

    Context "Graph error" {

        It "throws with the Graph error code" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 404 (Not Found).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "ObjectNotFound", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"NotFound","message":"Cloud PC not found"}}')
                throw $errorRecord
            }

            { Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPcId -ErrorAction Stop } | Should -Throw "*NotFound: Cloud PC not found*"
        }
    }
}
