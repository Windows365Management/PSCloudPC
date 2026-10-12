<#
This file tests the Get-CloudPC function by using Pester.
Contract: GET /deviceManagement/virtualEndpoint/cloudPCs (all pages), with
$filter=managedDeviceName eq '...' for -Name. An empty tenant returns nothing without an
error; -Name without a match writes a non-terminating error. The output uses the Graph
casing lastModifiedDateTime and servicePlanType.
https://learn.microsoft.com/graph/api/virtualendpoint-list-cloudpcs?view=graph-rest-beta
https://learn.microsoft.com/graph/api/resources/cloudpc?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Get-CloudPC" {

    BeforeAll {
        $CloudPCsUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/CloudPCs"
        $NextLink = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/CloudPCs?`$skiptoken=page2"
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        $CloudPCs = @(
            @{ id = "00000000-0000-0000-0000-000000000001"; managedDeviceName = "CPC-TEST-0001"; displayName = "Policy - Test User 1"; status = "provisioned"; lastModifiedDateTime = "2026-10-01T10:00:00Z"; servicePlanType = "enterprise"; servicePlanName = "Cloud PC Enterprise 2vCPU/8GB/128GB" }
            @{ id = "00000000-0000-0000-0000-000000000002"; managedDeviceName = $null; displayName = "Policy - Test User 2"; status = "provisioning"; lastModifiedDateTime = "2026-10-02T10:00:00Z"; servicePlanType = "enterprise"; servicePlanName = "Cloud PC Enterprise 2vCPU/8GB/128GB" }
        )

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            [pscustomobject]@{ Content = (@{ value = @($CloudPCs) } | ConvertTo-Json -Depth 10) }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { throw "Invoke-RestMethod must not be called by Get-CloudPC" }
    }

    Context "Request" {

        It "sends a GET to the cloudPCs collection without a filter" {
            Get-CloudPC | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter { "$Uri" -eq $CloudPCsUri -and $Method -eq "GET" }
        }

        It "filters on managedDeviceName for -Name" {
            Get-CloudPC -Name "CPC-TEST-0001" | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                "$Uri" -eq "$CloudPCsUri`?`$filter=managedDeviceName+eq+'CPC-TEST-0001'"
            }
        }

        It "doubles a single quote in -Name" {
            $CloudPCs = @()

            Get-CloudPC -Name "CPC-O'TEST" -ErrorAction SilentlyContinue | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                [uri]::UnescapeDataString(([uri]$Uri).OriginalString) -like "*managedDeviceName+eq+'CPC-O''TEST'"
            }
        }

        It "rejects an empty -Name instead of returning all Cloud PCs" {
            { Get-CloudPC -Name "" } | Should -Throw -ErrorId "ParameterArgumentValidationError*"

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "follows @odata.nextLink" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                if ("$Uri" -eq $NextLink) {
                    [pscustomobject]@{ Content = (@{ value = @($CloudPCs[1]) } | ConvertTo-Json -Depth 10) }
                }
                else {
                    [pscustomobject]@{ Content = (@{ value = @($CloudPCs[0]); "@odata.nextLink" = $NextLink } | ConvertTo-Json -Depth 10) }
                }
            }

            $result = @(Get-CloudPC)

            $result.Count | Should -Be 2
        }
    }

    Context "No results" {

        It "returns nothing and writes no error for an empty tenant" {
            $CloudPCs = @()

            $result = @(Get-CloudPC -ErrorVariable cloudPcErrors)

            $result.Count | Should -Be 0
            $cloudPcErrors.Count | Should -Be 0
        }

        It "writes a non-terminating error when -Name matches nothing" {
            $CloudPCs = @()

            $result = @(Get-CloudPC -Name "CPC-NONE" -ErrorVariable cloudPcErrors -ErrorAction SilentlyContinue)

            $result.Count | Should -Be 0
            $cloudPcErrors.Count | Should -Be 1
            "$($cloudPcErrors[0])" | Should -BeLike "*CPC-NONE*"
        }
    }

    Context "Output" {

        It "returns Cloud PCs that are still provisioning (no managedDeviceName)" {
            $result = @(Get-CloudPC)

            $result.Count | Should -Be 2
            ($result | Where-Object { $_.status -eq "provisioning" }).id | Should -Be "00000000-0000-0000-0000-000000000002"
        }

        It "returns Name as the first property" {
            $result = @(Get-CloudPC)

            ($result[0].PSObject.Properties.Name)[0] | Should -BeExactly "Name"
        }

        It "sets Name to managedDeviceName" {
            $result = @(Get-CloudPC)

            $result[0].Name | Should -BeExactly "CPC-TEST-0001"
            $result[0].managedDeviceName | Should -BeExactly "CPC-TEST-0001"
        }

        It "leaves Name empty (no displayName fallback) when managedDeviceName is <Case>" -TestCases @(
            @{ Case = "null"; ManagedDeviceName = $null }
            @{ Case = "empty"; ManagedDeviceName = "" }
            @{ Case = "whitespace"; ManagedDeviceName = " " }
        ) {
            param($Case, $ManagedDeviceName)
            $CloudPCs = @(@{ id = "00000000-0000-0000-0000-000000000003"; managedDeviceName = $ManagedDeviceName; displayName = "Policy - Test User 3"; status = "provisioning" })

            $result = @(Get-CloudPC)

            $result[0].Name | Should -BeNullOrEmpty
            $result[0].displayName | Should -BeExactly "Policy - Test User 3"
            $result[0].id | Should -Be "00000000-0000-0000-0000-000000000003"
        }

        It "keeps managedDeviceName and displayName next to Name" {
            $result = @(Get-CloudPC)

            $names = $result[0].PSObject.Properties.Name
            $names -ccontains "managedDeviceName" | Should -BeTrue
            $names -ccontains "displayName" | Should -BeTrue
        }

        It "uses the Graph casing for lastModifiedDateTime and servicePlanType" {
            $result = @(Get-CloudPC)

            $names = $result[0].PSObject.Properties.Name
            $names -ccontains "lastModifiedDateTime" | Should -BeTrue
            $names -ccontains "servicePlanType" | Should -BeTrue
            $names -ccontains "lastmodifiedDateTime" | Should -BeFalse
            $names -ccontains "serviceplanType" | Should -BeFalse
            $result[0].servicePlanType | Should -Be "enterprise"
            $result[0].lastModifiedDateTime | Should -Not -BeNullOrEmpty
        }

        It "still answers to the old casing (property access is case-insensitive)" {
            $result = @(Get-CloudPC)

            $result[0].serviceplanType | Should -Be "enterprise"
            $result[0].lastmodifiedDateTime | Should -Not -BeNullOrEmpty
        }
    }

    Context "Paging guards with -ErrorAction SilentlyContinue (security review X1)" {

        It "never sends a request to a foreign nextLink host" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                if ("$Uri" -like "https://evil.example.com/*") {
                    [pscustomobject]@{ Content = (@{ value = @($CloudPCs[1]) } | ConvertTo-Json -Depth 10) }
                }
                else {
                    [pscustomobject]@{ Content = (@{ value = @($CloudPCs[0]); "@odata.nextLink" = "https://evil.example.com/beta/deviceManagement/virtualEndpoint/CloudPCs?page=2" } | ConvertTo-Json -Depth 10) }
                }
            }

            $thrown = $null
            try { Get-CloudPC -ErrorAction SilentlyContinue | Out-Null } catch { $thrown = $_ }

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly -ParameterFilter { "$Uri" -like "https://evil.example.com/*" }
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly
            "$thrown" | Should -BeLike "*Refusing to follow @odata.nextLink*"
        }

        It "stops after two requests when the same nextLink repeats" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                [pscustomobject]@{ Content = (@{ value = @($CloudPCs[0]); "@odata.nextLink" = $NextLink } | ConvertTo-Json -Depth 10) }
            }

            $thrown = $null
            try { Get-CloudPC -ErrorAction SilentlyContinue | Out-Null } catch { $thrown = $_ }

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 2 -Exactly
            "$thrown" | Should -BeLike "*same @odata.nextLink twice*"
        }

        It "stops at a failing page without repeating it or returning a partial list" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                if ("$Uri" -eq $NextLink) {
                    throw "Response status code does not indicate success: 503 (Service Unavailable)."
                }
                [pscustomobject]@{ Content = (@{ value = @($CloudPCs[0]); "@odata.nextLink" = $NextLink } | ConvertTo-Json -Depth 10) }
            }

            $thrown = $null
            $result = $null
            try { $result = @(Get-CloudPC -ErrorAction SilentlyContinue) } catch { $thrown = $_ }

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 2 -Exactly
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter { "$Uri" -eq $NextLink }
            $result | Should -BeNullOrEmpty
            "$thrown" | Should -BeLike "*503*"
        }
    }

    Context "Graph error" {

        It "throws with the Graph error code" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 403 (Forbidden).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "PermissionDenied", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Forbidden","message":"Insufficient privileges"}}')
                throw $errorRecord
            }

            { Get-CloudPC -ErrorAction Stop } | Should -Throw "*Forbidden: Insufficient privileges*"
        }
    }
}
