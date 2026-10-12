<#
This file tests the Set-CPCUserSettingsPolicyAssignment function by using Pester.
Focus: the assign request body, the policy and group lookups, and confirmation.
- The assign action replaces all assignments, so the existing groups are sent again with the new group,
  each group once (Graph returns 400 when the same group is in the body twice).
- Every target is a cloudPcManagementGroupAssignmentTarget with @odata.type.
- Removing existing assignments (-Force) asks for confirmation (ConfirmImpact High).
https://learn.microsoft.com/en-us/graph/api/cloudpcusersetting-assign?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/cloudpcusersetting-get?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpcmanagementgroupassignmenttarget?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/group-list?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Set-CPCUserSettingsPolicyAssignment" {

    BeforeAll {
        $AssignUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/userSettings/usersetting-1/assign"
        $ExpandUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/userSettings/usersetting-1?`$expand=assignments"
        $GroupId = "00000000-0000-0000-0000-0000000000a1"
        $OtherGroupId = "00000000-0000-0000-0000-0000000000a2"
        $OdataType = "#microsoft.graph.cloudPcManagementGroupAssignmentTarget"
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { }
        Mock -ModuleName PSCloudPC Get-CPCUserSettingsPolicy -MockWith {
            [pscustomobject]@{ id = "usersetting-1"; displayName = "User Settings" }
        }
    }

    Context "Assignments" {

        BeforeEach {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -like "https://graph.microsoft.com/beta/groups?*" } -MockWith {
                [pscustomobject]@{ Content = '{"value":[{"id":"00000000-0000-0000-0000-0000000000a1","displayName":"Policy Users"}]}' }
            }
        }

        It "sends one assignment with @odata.type when the policy has no assignments" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"usersetting-1","displayName":"User Settings","assignments":[]}' }
            }

            Set-CPCUserSettingsPolicyAssignment -Name "User Settings" -GroupName "Policy Users" | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $assignments = @(($Body | ConvertFrom-Json).assignments)
                $Uri -eq $AssignUri -and
                $Method -eq "POST" -and
                $ContentType -eq "application/json" -and
                $Body -cmatch '"assignments"' -and $Body -cmatch '"groupId"' -and
                $assignments.Count -eq 1 -and
                $assignments[0].target.'@odata.type' -eq $OdataType -and
                $assignments[0].target.groupId -is [string] -and
                $assignments[0].target.groupId -eq $GroupId
            }
        }

        It "sends the group once when it is already assigned (ids compared case-insensitive)" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"usersetting-1","assignments":[{"id":"usersetting-1_00000000-0000-0000-0000-0000000000A1","target":{"@odata.type":"#microsoft.graph.cloudPcManagementGroupAssignmentTarget","groupId":"00000000-0000-0000-0000-0000000000A1"}}]}' }
            }

            Set-CPCUserSettingsPolicyAssignment -Name "User Settings" -GroupName "Policy Users" | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $assignments = @(($Body | ConvertFrom-Json).assignments)
                $Uri -eq $AssignUri -and
                $assignments.Count -eq 1 -and
                $assignments[0].target.'@odata.type' -eq $OdataType -and
                $assignments[0].target.groupId -eq $GroupId
            }
        }

        It "keeps the existing group and adds the new group without asking for confirmation" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"usersetting-1","assignments":[{"id":"usersetting-1_00000000-0000-0000-0000-0000000000a2","target":{"@odata.type":"#microsoft.graph.cloudPcManagementGroupAssignmentTarget","groupId":"00000000-0000-0000-0000-0000000000a2"}}]}' }
            }
            Mock -ModuleName PSCloudPC Confirm-CPCHighImpactAction -MockWith { $false }

            Set-CPCUserSettingsPolicyAssignment -Name "User Settings" -GroupName "Policy Users" | Out-Null

            Should -Invoke Confirm-CPCHighImpactAction -ModuleName PSCloudPC -Times 0 -Exactly
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $assignments = @(($Body | ConvertFrom-Json).assignments)
                $Uri -eq $AssignUri -and
                $assignments.Count -eq 2 -and
                ((@($assignments.target.groupId) | Sort-Object) -join ",") -eq "$GroupId,$OtherGroupId" -and
                @($assignments | Where-Object { $_.target.'@odata.type' -ne $OdataType }).Count -eq 0
            }
        }

        It "with -Force asks for high-impact confirmation naming the dropped group, then sends only the new group" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"usersetting-1","assignments":[{"id":"usersetting-1_00000000-0000-0000-0000-0000000000a2","target":{"@odata.type":"#microsoft.graph.cloudPcManagementGroupAssignmentTarget","groupId":"00000000-0000-0000-0000-0000000000a2"}}]}' }
            }
            Mock -ModuleName PSCloudPC Confirm-CPCHighImpactAction -MockWith { $true }

            Set-CPCUserSettingsPolicyAssignment -Name "User Settings" -GroupName "Policy Users" -Force -WarningAction SilentlyContinue | Out-Null

            Should -Invoke Confirm-CPCHighImpactAction -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter { $Action -like "*REMOVE*$OtherGroupId*" }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $assignments = @(($Body | ConvertFrom-Json).assignments)
                $Uri -eq $AssignUri -and
                $assignments.Count -eq 1 -and
                $assignments[0].target.'@odata.type' -eq $OdataType -and
                $assignments[0].target.groupId -eq $GroupId
            }
        }

        It "with -Force sends nothing when the removal is declined" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"usersetting-1","assignments":[{"id":"usersetting-1_00000000-0000-0000-0000-0000000000a2","target":{"groupId":"00000000-0000-0000-0000-0000000000a2"}}]}' }
            }
            Mock -ModuleName PSCloudPC Confirm-CPCHighImpactAction -MockWith { $false }

            Set-CPCUserSettingsPolicyAssignment -Name "User Settings" -GroupName "Policy Users" -Force -WarningAction SilentlyContinue | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "with -Force and -Confirm:`$false sends only the new group without a prompt" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"usersetting-1","assignments":[{"id":"usersetting-1_00000000-0000-0000-0000-0000000000a2","target":{"groupId":"00000000-0000-0000-0000-0000000000a2"}}]}' }
            }

            Set-CPCUserSettingsPolicyAssignment -Name "User Settings" -GroupName "Policy Users" -Force -Confirm:$false -WarningAction SilentlyContinue | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $assignments = @(($Body | ConvertFrom-Json).assignments)
                $assignments.Count -eq 1 -and $assignments[0].target.groupId -eq $GroupId
            }
        }

        It "sends no request with -WhatIf" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"usersetting-1","assignments":[]}' }
            }

            Set-CPCUserSettingsPolicyAssignment -Name "User Settings" -GroupName "Policy Users" -WhatIf | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "sends no request with -Force -WhatIf when a group would be removed" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"usersetting-1","assignments":[{"id":"usersetting-1_00000000-0000-0000-0000-0000000000a2","target":{"groupId":"00000000-0000-0000-0000-0000000000a2"}}]}' }
            }

            Set-CPCUserSettingsPolicyAssignment -Name "User Settings" -GroupName "Policy Users" -Force -WhatIf -WarningAction SilentlyContinue | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "stops and sends no request when reading the current assignments fails (-ErrorAction <ErrorActionValue>)" -ForEach @(
            @{ ErrorActionValue = "Stop" }
            @{ ErrorActionValue = "SilentlyContinue" }
        ) {
            # Sending only the new group here would remove the existing assignments
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Response status code does not indicate success: 403 (Forbidden)."),
                    "WebCmdletWebResponseException",
                    "InvalidOperation",
                    $null
                )
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Forbidden","message":"Insufficient privileges"}}')
                throw $errorRecord
            }

            { Set-CPCUserSettingsPolicyAssignment -Name "User Settings" -GroupName "Policy Users" -ErrorAction $ErrorActionValue } |
                Should -Throw -ExpectedMessage "*Forbidden: Insufficient privileges*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "stops and sends no request when the response has no assignments property (-ErrorAction <ErrorActionValue>)" -ForEach @(
            @{ ErrorActionValue = "Stop" }
            @{ ErrorActionValue = "SilentlyContinue" }
        ) {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"usersetting-1","displayName":"User Settings"}' }
            }

            { Set-CPCUserSettingsPolicyAssignment -Name "User Settings" -GroupName "Policy Users" -ErrorAction $ErrorActionValue } |
                Should -Throw -ExpectedMessage "*without its assignments*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "throws with the Graph error code when the assign POST fails" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"usersetting-1","assignments":[]}' }
            }
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Response status code does not indicate success: 400 (Bad Request)."),
                    "GraphError",
                    "InvalidOperation",
                    $null
                )
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"Invalid assignment"}}')
                throw $errorRecord
            }

            { Set-CPCUserSettingsPolicyAssignment -Name "User Settings" -GroupName "Policy Users" -Force -ErrorAction Stop } |
                Should -Throw -ExpectedMessage "*BadRequest: Invalid assignment*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
        }
    }

    Context "Policy and group lookup (-ErrorAction <ErrorActionValue>)" -ForEach @(
        @{ ErrorActionValue = "Stop" }
        @{ ErrorActionValue = "SilentlyContinue" }
    ) {

        BeforeEach {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -like "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/userSettings/*" } -MockWith {
                [pscustomobject]@{ Content = '{"id":"usersetting-1","assignments":[]}' }
            }
        }

        It "stops and sends no request when no group has the name" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -like "https://graph.microsoft.com/beta/groups?*" } -MockWith {
                [pscustomobject]@{ Content = '{"value":[]}' }
            }

            { Set-CPCUserSettingsPolicyAssignment -Name "User Settings" -GroupName "Policy Users" -ErrorAction $ErrorActionValue } |
                Should -Throw -ExpectedMessage "No group found with name Policy Users"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "stops, lists the ids and sends no request when two groups have the name" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -like "https://graph.microsoft.com/beta/groups?*" } -MockWith {
                [pscustomobject]@{ Content = '{"value":[{"id":"00000000-0000-0000-0000-0000000000a1","displayName":"Policy Users"},{"id":"00000000-0000-0000-0000-0000000000a2","displayName":"Policy Users"}]}' }
            }

            { Set-CPCUserSettingsPolicyAssignment -Name "User Settings" -GroupName "Policy Users" -ErrorAction $ErrorActionValue } |
                Should -Throw -ExpectedMessage "2 groups found with name Policy Users ($GroupId, $OtherGroupId)*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "stops and sends no request when no policy has the name" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -like "https://graph.microsoft.com/beta/groups?*" } -MockWith {
                [pscustomobject]@{ Content = '{"value":[{"id":"00000000-0000-0000-0000-0000000000a1","displayName":"Policy Users"}]}' }
            }
            Mock -ModuleName PSCloudPC Get-CPCUserSettingsPolicy -MockWith { }

            { Set-CPCUserSettingsPolicyAssignment -Name "Missing Policy" -GroupName "Policy Users" -ErrorAction $ErrorActionValue } |
                Should -Throw -ExpectedMessage "No User Settings Policy found with name Missing Policy"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "stops and sends nothing when the server-side filter returns a policy with another name" {
            # For example a + in the name is decoded as a space by the unescaped filter in Get-CPCUserSettingsPolicy
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -like "https://graph.microsoft.com/beta/groups?*" } -MockWith {
                [pscustomobject]@{ Content = '{"value":[{"id":"00000000-0000-0000-0000-0000000000a1","displayName":"Policy Users"}]}' }
            }
            Mock -ModuleName PSCloudPC Get-CPCUserSettingsPolicy -MockWith {
                [pscustomobject]@{ id = "usersetting-2"; displayName = "Sales EU" }
            }

            { Set-CPCUserSettingsPolicyAssignment -Name "Sales+EU" -GroupName "Policy Users" -ErrorAction $ErrorActionValue } |
                Should -Throw -ExpectedMessage "No User Settings Policy found with name Sales+EU"

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly -ParameterFilter { ([uri]$Uri).OriginalString -like "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/userSettings/*" }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }
}
