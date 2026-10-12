<#
This file tests the Get-CPCUserSettingsPolicy function by using Pester.
Contract: GET /deviceManagement/virtualEndpoint/userSettings, following @odata.nextLink. Graph's
displayName eq filter on userSettings is case-sensitive, so no $filter is sent: -Name is matched exactly,
but case-insensitively, on the client. No match returns nothing (no error, no break).
https://learn.microsoft.com/en-us/graph/api/virtualendpoint-list-usersettings?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Get-CPCUserSettingsPolicy" {

    BeforeAll {
        $ListUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/userSettings"
        $NextUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/userSettings?`$skiptoken=page2"
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        # First and second page of the list. Tests may replace these.
        $Page1 = @(
            @{ id = "00000000-0000-0000-0000-000000000001"; displayName = "UserSettings01"; localAdminEnabled = $true; resetEnabled = $false }
            @{ id = "00000000-0000-0000-0000-000000000002"; displayName = "UserSettings01 Copy"; localAdminEnabled = $false; resetEnabled = $false }
        )
        $Page2 = @(
            @{ id = "00000000-0000-0000-0000-000000000003"; displayName = "Finance's settings"; localAdminEnabled = $false; resetEnabled = $true }
        )

        Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { [string]$Uri -like "*skiptoken=page2" } -MockWith {
            [pscustomobject]@{ Content = (@{ value = @($Page2) } | ConvertTo-Json -Depth 10) }
        }
        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            $page = @{ value = @($Page1) }
            if (@($Page2).Count -gt 0) {
                $page["@odata.nextLink"] = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/userSettings?`$skiptoken=page2"
            }
            [pscustomobject]@{ Content = ($page | ConvertTo-Json -Depth 10) }
        }
    }

    Context "List" {

        It "returns the policies of every page" {
            $result = @(Get-CPCUserSettingsPolicy)

            $result.Count | Should -Be 3
            $result.displayName | Should -Be @("UserSettings01", "UserSettings01 Copy", "Finance's settings")
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter { $Uri -eq $ListUri -and $Method -eq "GET" }
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter { $Uri -eq $NextUri }
        }

        It "returns the same properties as before" {
            $result = @(Get-CPCUserSettingsPolicy)[0]

            @($result.PSObject.Properties.Name) | Should -Be @(
                "id", "displayName", "selfServiceEnabled", "localAdminEnabled", "resetEnabled", "createdDateTime",
                "lastModifiedDateTime", "restorePointSetting", "crossRegionDisasterRecoverySetting"
            )
            $result.localAdminEnabled | Should -BeTrue
        }

        It "returns nothing and no error when there are no policies" {
            $Page1 = @()
            $Page2 = @()

            $result = Get-CPCUserSettingsPolicy -ErrorAction Stop

            $result | Should -BeNullOrEmpty
        }
    }

    Context "By name" {

        It "never sends a `$filter" {
            Get-CPCUserSettingsPolicy -Name "UserSettings01" | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly -ParameterFilter { [string]$Uri -like "*filter*" }
        }

        It "matches the name exactly, not as a prefix" {
            $result = @(Get-CPCUserSettingsPolicy -Name "UserSettings01")

            $result.Count | Should -Be 1
            $result[0].id | Should -Be "00000000-0000-0000-0000-000000000001"
        }

        It "matches the name case-insensitively" {
            $result = @(Get-CPCUserSettingsPolicy -Name "usersettings01")

            $result.Count | Should -Be 1
            $result[0].displayName | Should -Be "UserSettings01"
        }

        It "returns every policy whose name matches when names differ only in case" {
            $Page2 = @(@{ id = "00000000-0000-0000-0000-000000000004"; displayName = "USERSETTINGS01" })

            $result = @(Get-CPCUserSettingsPolicy -Name "UserSettings01")

            $result.Count | Should -Be 2
        }

        It "finds a name with a single quote" {
            $result = @(Get-CPCUserSettingsPolicy -Name "Finance's settings")

            $result.Count | Should -Be 1
            $result[0].id | Should -Be "00000000-0000-0000-0000-000000000003"
        }

        It "returns nothing and no error when no policy matches" {
            $result = Get-CPCUserSettingsPolicy -Name "Does Not Exist" -ErrorAction Stop

            $result | Should -BeNullOrEmpty
        }

        It "does not end the caller's loop when no policy matches (-ErrorAction SilentlyContinue)" {
            $runs = 0
            foreach ($i in 1..2) {
                Get-CPCUserSettingsPolicy -Name "Does Not Exist" -ErrorAction SilentlyContinue | Out-Null
                $runs++
            }

            $runs | Should -Be 2
        }
    }

    Context "Graph error" {

        It "throws the Graph error code" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 403 (Forbidden).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "PermissionDenied", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Forbidden","message":"Insufficient permissions"}}')
                throw $errorRecord
            }

            { Get-CPCUserSettingsPolicy -Name "UserSettings01" -ErrorAction Stop } | Should -Throw -ExpectedMessage "*Forbidden*"
        }
    }
}
