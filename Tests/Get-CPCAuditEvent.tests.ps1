<#
This file tests the Get-CPCAuditEvent function by using Pester.
Contract: GET /deviceManagement/virtualEndpoint/auditEvents through Invoke-APIRequest
(follows @odata.nextLink). Graph returns activity as null and the activity text in
activityType, so -Activity is matched on the client (exact, case-insensitive) against
activityType (or activity when it is filled) and no $filter is sent. -Top without -Activity
sends $top and stops paging once enough events are collected.
https://learn.microsoft.com/graph/api/virtualendpoint-list-auditevents?view=graph-rest-beta
https://learn.microsoft.com/graph/api/resources/cloudpcauditevent?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Get-CPCAuditEvent" {

    BeforeAll {
        $AuditUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/auditEvents"
        $NextLink = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/auditEvents?`$skiptoken=page2"

        $Page1 = @(
            @{ id = "00000000-0000-0000-0000-000000000001"; displayName = "Create CloudPcUserSetting"; activity = $null; activityType = "Create CloudPcUserSetting"; activityOperationType = "create"; activityResult = "success"; category = "cloudPC" }
            @{ id = "00000000-0000-0000-0000-000000000002"; displayName = "Patch CloudPcUserSetting"; activity = $null; activityType = "Patch CloudPcUserSetting"; activityOperationType = "patch"; activityResult = "success"; category = "cloudPC" }
        )
        $Page2 = @(
            @{ id = "00000000-0000-0000-0000-000000000003"; displayName = "Create CloudPcUserSetting"; activity = $null; activityType = "Create CloudPcUserSetting"; activityOperationType = "create"; activityResult = "success"; category = "cloudPC" }
            @{ id = "00000000-0000-0000-0000-000000000004"; displayName = "AssignToGroups CloudPcProvisioningPolicy"; activity = $null; activityType = "AssignToGroups CloudPcProvisioningPolicy"; activityOperationType = "patch"; activityResult = "success"; category = "cloudPC" }
        )
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            if ("$Uri" -eq $NextLink) {
                [pscustomobject]@{ Content = (@{ value = $Page2 } | ConvertTo-Json -Depth 10) }
            }
            else {
                [pscustomobject]@{ Content = (@{ value = $Page1; "@odata.nextLink" = $NextLink } | ConvertTo-Json -Depth 10) }
            }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { throw "Invoke-RestMethod must not be called by Get-CPCAuditEvent" }
    }

    Context "Request" {

        It "sends a GET without query options and follows @odata.nextLink" {
            $result = @(Get-CPCAuditEvent)

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter { "$Uri" -eq $AuditUri -and $Method -eq "GET" }
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter { "$Uri" -eq $NextLink }
            $result.Count | Should -Be 4
        }

        It "does not send a `$filter on activity when -Activity is used" {
            Get-CPCAuditEvent -Activity "Create CloudPcUserSetting" | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -ParameterFilter { "$Uri" -match "filter" }
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter { "$Uri" -eq $AuditUri }
        }
    }

    Context "-Activity" {

        It "matches activityType on every page" {
            $result = @(Get-CPCAuditEvent -Activity "Create CloudPcUserSetting")

            $result.Count | Should -Be 2
            $result.id | Should -Be @("00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000003")
        }

        It "matches case-insensitively" {
            $result = @(Get-CPCAuditEvent -Activity "assigntogroups cloudpcprovisioningpolicy")

            $result.Count | Should -Be 1
            $result[0].id | Should -Be "00000000-0000-0000-0000-000000000004"
        }

        It "does not return partial matches" {
            $result = @(Get-CPCAuditEvent -Activity "Create")

            $result.Count | Should -Be 0
        }

        It "also matches activity when Graph fills it" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                [pscustomobject]@{ Content = (@{ value = @(@{ id = "00000000-0000-0000-0000-000000000009"; activity = "Reprovision cloudPc"; activityType = "Reprovision CloudPc" }) } | ConvertTo-Json -Depth 10) }
            }

            $result = @(Get-CPCAuditEvent -Activity "Reprovision cloudPc")

            $result.Count | Should -Be 1
        }

        It "applies -Top after filtering" {
            $result = @(Get-CPCAuditEvent -Activity "Create CloudPcUserSetting" -Top 1)

            $result.Count | Should -Be 1
            $result[0].id | Should -Be "00000000-0000-0000-0000-000000000001"
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -ParameterFilter { "$Uri" -match "top=" }
        }
    }

    Context "-Top" {

        It "sends `$top and stops paging when enough events are collected" {
            $result = @(Get-CPCAuditEvent -Top 2)

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter { "$Uri" -eq "$AuditUri`?`$top=2" }
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -ParameterFilter { "$Uri" -eq $NextLink }
            $result.Count | Should -Be 2
        }

        It "returns no more than -Top events" {
            $result = @(Get-CPCAuditEvent -Top 1)

            $result.Count | Should -Be 1
        }
    }

    Context "Output" {

        It "returns nothing and no error for an empty audit log" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith { [pscustomobject]@{ Content = '{"value":[]}' } }

            $result = @(Get-CPCAuditEvent -ErrorVariable auditErrors)

            $result.Count | Should -Be 0
            $auditErrors.Count | Should -Be 0
        }

        It "keeps the existing properties" {
            $result = @(Get-CPCAuditEvent)

            $names = $result[0].PSObject.Properties.Name
            foreach ($property in @("id", "displayName", "componentName", "activity", "activityDateTime", "activityOperationType", "activityResult", "activityType", "category", "correlationId", "actor", "resources")) {
                $names | Should -Contain $property
            }
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

            { Get-CPCAuditEvent -ErrorAction Stop } | Should -Throw "*Forbidden: Insufficient privileges*"
        }
    }
}
