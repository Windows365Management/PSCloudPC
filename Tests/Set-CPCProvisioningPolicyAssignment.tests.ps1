<#
This file tests the Set-CPCProvisioningPolicyAssignment function by using Pester.
Focus: the assign request body, the policy, group and service plan lookups, and confirmation.
- The assign action replaces all assignments, so for dedicated policies the existing groups are sent again
  with the new group, each group once (Graph returns 400 when the same group is in the body twice).
- Every target is a cloudPcManagementGroupAssignmentTarget with @odata.type and camelCase properties
  (groupId, servicePlanId); no undocumented allotment properties.
- For shared provisioning types (sharedByUser, sharedByEntraGroup) the target's servicePlanId must be a
  single id; null is only valid for dedicated policies.
- provisioningType is an evolvable enum, so the policy is read with Prefer: include-unknown-enum-members.
- Removing existing assignments asks for confirmation (ConfirmImpact High).
https://learn.microsoft.com/en-us/graph/api/cloudpcprovisioningpolicy-assign?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/cloudpcprovisioningpolicy-get?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpcprovisioningpolicy?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpcmanagementgroupassignmenttarget?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/group-list?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../PSCloudPc/PSCloudPC.psd1') -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe 'Set-CPCProvisioningPolicyAssignment' {

    BeforeAll {
        $AssignUri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies/policy-1/assign'
        $ExpandUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies/policy-1?`$expand=assignments"
        $GroupId = '00000000-0000-0000-0000-0000000000a1'
        $OtherGroupId = "00000000-0000-0000-0000-0000000000a2"
        $OdataType = "#microsoft.graph.cloudPcManagementGroupAssignmentTarget"
        $PlanName = 'Cloud PC Frontline 2vCPU/8GB/128GB'
        $PlanId = '00000000-0000-0000-0000-000000000003'
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = 'token'
            $script:Authheader = @{ Authorization = 'Bearer token' }
            $script:MSGraphVersion = 'beta'
        }

        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { }
    }

    Context 'Shared provisioning type <ProvisioningType>' -ForEach @(
        @{ ProvisioningType = 'sharedByUser' }
        @{ ProvisioningType = 'sharedByEntraGroup' }
    ) {

        BeforeEach {
            # The list call returns unknownFutureValue for shared types; the cmdlet must use the GET with the Prefer header
            Mock -ModuleName PSCloudPC Get-CPCProvisioningPolicy -MockWith {
                [pscustomobject]@{ id = 'policy-1'; displayName = 'Frontline Policy'; provisioningType = 'unknownFutureValue' }
            }
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -like "https://graph.microsoft.com/beta/groups?*" } -MockWith {
                [pscustomobject]@{ Content = '{"value":[{"id":"00000000-0000-0000-0000-0000000000a1","displayName":"Frontline Users"}]}' }
            }
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = (@{ id = "policy-1"; displayName = "Frontline Policy"; provisioningType = $ProvisioningType; assignments = @() } | ConvertTo-Json -Depth 10) }
            }
        }

        It 'sends one camelCase target with @odata.type and a single string servicePlanId when exactly one plan matches' {
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith {
                [pscustomobject]@{ id = $PlanId; displayName = $PlanName; provisioningType = 'shared' }
            }

            Set-CPCProvisioningPolicyAssignment -Name 'Frontline Policy' -GroupName 'Frontline Users' -ProvisioningType $ProvisioningType -ServicePlanName $PlanName | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -eq $ExpandUri -and $Headers["Prefer"] -eq "include-unknown-enum-members"
            }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $assignments = @(($Body | ConvertFrom-Json).assignments)
                $target = $assignments[0].target
                $Uri -eq $AssignUri -and
                $Method -eq 'POST' -and
                $Body -cmatch '"assignments"' -and $Body -cmatch '"target"' -and $Body -cmatch '"groupId"' -and $Body -cmatch '"servicePlanId"' -and
                $assignments.Count -eq 1 -and
                $target.'@odata.type' -eq '#microsoft.graph.cloudPcManagementGroupAssignmentTarget' -and
                $target.groupId -eq $GroupId -and
                $target.servicePlanId -is [string] -and
                $target.servicePlanId -eq $PlanId -and
                @($target.PSObject.Properties.Name) -notcontains 'allotmentLicensesCount' -and
                @($target.PSObject.Properties.Name) -notcontains 'allotmentDisplayName'
            }
        }

        It "warns that -AllotmentLicensesCount is not sent" {
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith {
                [pscustomobject]@{ id = $PlanId; displayName = $PlanName; provisioningType = 'shared' }
            }

            Set-CPCProvisioningPolicyAssignment -Name 'Frontline Policy' -GroupName 'Frontline Users' -ProvisioningType $ProvisioningType -ServicePlanName $PlanName -AllotmentLicensesCount 2 -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

            ($warnings -join " ") | Should -BeLike "*AllotmentLicensesCount*not sent*"
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Body -notmatch "allotment"
            }
        }

        It 'errors and sends no request when -ServicePlanName is not given' {
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith { }

            { Set-CPCProvisioningPolicyAssignment -Name 'Frontline Policy' -GroupName 'Frontline Users' -ProvisioningType $ProvisioningType -ErrorAction Stop } | Should -Throw

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0
        }

        It 'errors and sends no request when no plan matches' {
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith { }

            { Set-CPCProvisioningPolicyAssignment -Name 'Frontline Policy' -GroupName 'Frontline Users' -ProvisioningType $ProvisioningType -ServicePlanName 'Does Not Exist' -ErrorAction Stop } | Should -Throw

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0
        }

        It 'errors and sends no request when more than one plan matches' {
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith {
                [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000003'; displayName = $PlanName; provisioningType = 'shared' }
                [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000006'; displayName = $PlanName; provisioningType = 'shared' }
            }

            { Set-CPCProvisioningPolicyAssignment -Name 'Frontline Policy' -GroupName 'Frontline Users' -ProvisioningType $ProvisioningType -ServicePlanName $PlanName -ErrorAction Stop } | Should -Throw

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0
        }

        # A Throw in begin is skipped with SilentlyContinue and process would still POST; the guards must still stop.
        It 'still throws and sends no request with -ErrorAction SilentlyContinue when -ServicePlanName is not given' {
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith { }

            { Set-CPCProvisioningPolicyAssignment -Name 'Frontline Policy' -GroupName 'Frontline Users' -ProvisioningType $ProvisioningType -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "ServicePlanName is required when ProvisioningType is $ProvisioningType"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It 'still throws and sends no request with -ErrorAction SilentlyContinue when more than one plan matches' {
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith {
                [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000003'; displayName = $PlanName; provisioningType = 'shared' }
                [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000006'; displayName = $PlanName; provisioningType = 'shared' }
            }

            { Set-CPCProvisioningPolicyAssignment -Name 'Frontline Policy' -GroupName 'Frontline Users' -ProvisioningType $ProvisioningType -ServicePlanName $PlanName -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "2 Service Plans found with name $PlanName*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It 'resolves the name against the full servicePlans list (HTTP boundary) and sends one id' {
            # The servicePlans endpoint supports no OData query parameters, so Graph returns every plan.
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                [pscustomobject]@{
                    Content = (@{
                            value = @(
                                @{ id = '00000000-0000-0000-0000-000000000001'; displayName = 'Cloud PC Enterprise 2vCPU/8GB/128GB'; provisioningType = 'dedicated' }
                                @{ id = $PlanId; displayName = $PlanName; provisioningType = 'shared' }
                                @{ id = '00000000-0000-0000-0000-000000000007'; displayName = 'Cloud PC Frontline 4vCPU/16GB/128GB'; provisioningType = 'shared' }
                            )
                        } | ConvertTo-Json -Depth 10)
                }
            }

            Set-CPCProvisioningPolicyAssignment -Name 'Frontline Policy' -GroupName 'Frontline Users' -ProvisioningType $ProvisioningType -ServicePlanName $PlanName | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $target = @(($Body | ConvertFrom-Json).assignments)[0].target
                $Uri -eq $AssignUri -and
                $target.servicePlanId -is [string] -and
                $target.servicePlanId -eq $PlanId
            }
        }
    }

    Context "Shared provisioning type <ProvisioningType> that already has another group" -ForEach @(
        @{ ProvisioningType = "sharedByUser" }
        @{ ProvisioningType = "sharedByEntraGroup" }
    ) {

        BeforeEach {
            Mock -ModuleName PSCloudPC Get-CPCProvisioningPolicy -MockWith {
                [pscustomobject]@{ id = "policy-1"; displayName = "Frontline Policy"; provisioningType = "unknownFutureValue" }
            }
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith {
                [pscustomobject]@{ id = $PlanId; displayName = $PlanName; provisioningType = "shared" }
            }
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -like "https://graph.microsoft.com/beta/groups?*" } -MockWith {
                [pscustomobject]@{ Content = '{"value":[{"id":"00000000-0000-0000-0000-0000000000a1","displayName":"Frontline Users"}]}' }
            }
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{
                    Content = (@{
                            id               = "policy-1"
                            displayName      = "Frontline Policy"
                            provisioningType = $ProvisioningType
                            assignments      = @(
                                @{ id = "policy-1_$OtherGroupId"; target = @{ "@odata.type" = "#microsoft.graph.cloudPcManagementGroupAssignmentTarget"; groupId = $OtherGroupId; servicePlanId = $PlanId } }
                            )
                        } | ConvertTo-Json -Depth 10)
                }
            }
        }

        It "asks for high-impact confirmation naming the dropped group and sends nothing when declined" {
            Mock -ModuleName PSCloudPC Confirm-CPCHighImpactAction -MockWith { $false }

            Set-CPCProvisioningPolicyAssignment -Name "Frontline Policy" -GroupName "Frontline Users" -ProvisioningType $ProvisioningType -ServicePlanName $PlanName -WarningAction SilentlyContinue | Out-Null

            Should -Invoke Confirm-CPCHighImpactAction -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter { $Action -like "*REMOVE*$OtherGroupId*" }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "sends only the new group when the removal is confirmed" {
            Mock -ModuleName PSCloudPC Confirm-CPCHighImpactAction -MockWith { $true }

            Set-CPCProvisioningPolicyAssignment -Name "Frontline Policy" -GroupName "Frontline Users" -ProvisioningType $ProvisioningType -ServicePlanName $PlanName -WarningAction SilentlyContinue | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $assignments = @(($Body | ConvertFrom-Json).assignments)
                $assignments.Count -eq 1 -and $assignments[0].target.groupId -eq $GroupId -and $assignments[0].target.servicePlanId -eq $PlanId
            }
        }

        It "sends without a prompt with -Confirm:`$false" {
            Set-CPCProvisioningPolicyAssignment -Name "Frontline Policy" -GroupName "Frontline Users" -ProvisioningType $ProvisioningType -ServicePlanName $PlanName -Confirm:$false -WarningAction SilentlyContinue | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
        }

        It "sends nothing with -WhatIf" {
            Set-CPCProvisioningPolicyAssignment -Name "Frontline Policy" -GroupName "Frontline Users" -ProvisioningType $ProvisioningType -ServicePlanName $PlanName -WhatIf -WarningAction SilentlyContinue | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context 'Dedicated provisioning type' {

        BeforeEach {
            Mock -ModuleName PSCloudPC Get-CPCProvisioningPolicy -MockWith {
                [pscustomobject]@{ id = 'policy-1'; displayName = 'Dedicated Policy'; provisioningType = 'dedicated' }
            }
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith { }
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -like "https://graph.microsoft.com/beta/groups?*" } -MockWith {
                [pscustomobject]@{ Content = '{"value":[{"id":"00000000-0000-0000-0000-0000000000a1","displayName":"Dedicated Users"}]}' }
            }
        }

        It "sends one group-only assignment with @odata.type and no servicePlanId when the policy has no assignments" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"policy-1","displayName":"Dedicated Policy","provisioningType":"dedicated","assignments":[]}' }
            }
            Mock -ModuleName PSCloudPC Confirm-CPCHighImpactAction -MockWith { $true }

            Set-CPCProvisioningPolicyAssignment -Name "Dedicated Policy" -GroupName "Dedicated Users" | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -eq $ExpandUri -and $Headers["Prefer"] -eq "include-unknown-enum-members"
            }
            Should -Invoke Confirm-CPCHighImpactAction -ModuleName PSCloudPC -Times 0 -Exactly
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $assignments = @(($Body | ConvertFrom-Json).assignments)
                $Uri -eq $AssignUri -and
                $Method -eq "POST" -and
                $ContentType -eq "application/json" -and
                $assignments.Count -eq 1 -and
                $assignments[0].target.'@odata.type' -eq $OdataType -and
                $assignments[0].target.groupId -is [string] -and
                $assignments[0].target.groupId -eq $GroupId -and
                $null -eq $assignments[0].target.servicePlanId
            }
        }

        It "sends the group once when it is already assigned (ids compared case-insensitive)" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"policy-1","provisioningType":"dedicated","assignments":[{"id":"policy-1_00000000-0000-0000-0000-0000000000A1","target":{"@odata.type":"#microsoft.graph.cloudPcManagementGroupAssignmentTarget","groupId":"00000000-0000-0000-0000-0000000000A1","servicePlanId":null}}]}' }
            }

            Set-CPCProvisioningPolicyAssignment -Name "Dedicated Policy" -GroupName "Dedicated Users" | Out-Null

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
                [pscustomobject]@{ Content = '{"id":"policy-1","provisioningType":"dedicated","assignments":[{"id":"policy-1_00000000-0000-0000-0000-0000000000a2","target":{"@odata.type":"#microsoft.graph.cloudPcManagementGroupAssignmentTarget","groupId":"00000000-0000-0000-0000-0000000000a2","servicePlanId":null}}]}' }
            }
            Mock -ModuleName PSCloudPC Confirm-CPCHighImpactAction -MockWith { $false }

            Set-CPCProvisioningPolicyAssignment -Name "Dedicated Policy" -GroupName "Dedicated Users" | Out-Null

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
                [pscustomobject]@{ Content = '{"id":"policy-1","provisioningType":"dedicated","assignments":[{"id":"policy-1_00000000-0000-0000-0000-0000000000a2","target":{"@odata.type":"#microsoft.graph.cloudPcManagementGroupAssignmentTarget","groupId":"00000000-0000-0000-0000-0000000000a2","servicePlanId":null}}]}' }
            }
            Mock -ModuleName PSCloudPC Confirm-CPCHighImpactAction -MockWith { $true }

            Set-CPCProvisioningPolicyAssignment -Name "Dedicated Policy" -GroupName "Dedicated Users" -Force -WarningAction SilentlyContinue | Out-Null

            Should -Invoke Confirm-CPCHighImpactAction -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter { $Action -like "*REMOVE*$OtherGroupId*" }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $assignments = @(($Body | ConvertFrom-Json).assignments)
                $Uri -eq $AssignUri -and
                $Method -eq "POST" -and
                $assignments.Count -eq 1 -and
                $assignments[0].target.'@odata.type' -eq $OdataType -and
                $assignments[0].target.groupId -eq $GroupId -and
                $null -eq $assignments[0].target.servicePlanId
            }
        }

        It "with -Force sends nothing when the removal is declined" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"policy-1","provisioningType":"dedicated","assignments":[{"id":"policy-1_00000000-0000-0000-0000-0000000000a2","target":{"groupId":"00000000-0000-0000-0000-0000000000a2"}}]}' }
            }
            Mock -ModuleName PSCloudPC Confirm-CPCHighImpactAction -MockWith { $false }

            Set-CPCProvisioningPolicyAssignment -Name "Dedicated Policy" -GroupName "Dedicated Users" -Force -WarningAction SilentlyContinue | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "with -Force and -Confirm:`$false sends only the new group without a prompt" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"policy-1","provisioningType":"dedicated","assignments":[{"id":"policy-1_00000000-0000-0000-0000-0000000000a2","target":{"groupId":"00000000-0000-0000-0000-0000000000a2"}}]}' }
            }

            Set-CPCProvisioningPolicyAssignment -Name "Dedicated Policy" -GroupName "Dedicated Users" -Force -Confirm:$false -WarningAction SilentlyContinue | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $assignments = @(($Body | ConvertFrom-Json).assignments)
                $assignments.Count -eq 1 -and $assignments[0].target.groupId -eq $GroupId
            }
        }

        It "with -Force and no other group sends without the high-impact confirmation" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"policy-1","provisioningType":"dedicated","assignments":[]}' }
            }
            Mock -ModuleName PSCloudPC Confirm-CPCHighImpactAction -MockWith { $false }

            Set-CPCProvisioningPolicyAssignment -Name "Dedicated Policy" -GroupName "Dedicated Users" -Force | Out-Null

            Should -Invoke Confirm-CPCHighImpactAction -ModuleName PSCloudPC -Times 0 -Exactly
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
        }

        It "sends no request with -WhatIf" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"policy-1","provisioningType":"dedicated","assignments":[]}' }
            }

            Set-CPCProvisioningPolicyAssignment -Name "Dedicated Policy" -GroupName "Dedicated Users" -WhatIf | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "sends no request with -Force -WhatIf when a group would be removed" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"policy-1","provisioningType":"dedicated","assignments":[{"id":"policy-1_00000000-0000-0000-0000-0000000000a2","target":{"groupId":"00000000-0000-0000-0000-0000000000a2"}}]}' }
            }

            Set-CPCProvisioningPolicyAssignment -Name "Dedicated Policy" -GroupName "Dedicated Users" -Force -WhatIf -WarningAction SilentlyContinue | Out-Null

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

            { Set-CPCProvisioningPolicyAssignment -Name "Dedicated Policy" -GroupName "Dedicated Users" -ErrorAction $ErrorActionValue } |
                Should -Throw -ExpectedMessage "*Forbidden: Insufficient privileges*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "stops and sends no request when the response has no assignments property (-ErrorAction <ErrorActionValue>)" -ForEach @(
            @{ ErrorActionValue = "Stop" }
            @{ ErrorActionValue = "SilentlyContinue" }
        ) {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"policy-1","displayName":"Dedicated Policy","provisioningType":"dedicated"}' }
            }

            { Set-CPCProvisioningPolicyAssignment -Name "Dedicated Policy" -GroupName "Dedicated Users" -Force -ErrorAction $ErrorActionValue } |
                Should -Throw -ExpectedMessage "*without its assignments*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "stops and sends no request when -ProvisioningType doesn't match the policy" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"policy-1","provisioningType":"sharedByEntraGroup","assignments":[]}' }
            }

            { Set-CPCProvisioningPolicyAssignment -Name "Dedicated Policy" -GroupName "Dedicated Users" -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "Provisioning Type mismatch. Policy Provisioning Type is sharedByEntraGroup, provided Provisioning Type is dedicated"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It 'throws with the Graph error code when the assign POST fails' {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"policy-1","provisioningType":"dedicated","assignments":[]}' }
            }
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                $exception = [System.Exception]::new('Response status code does not indicate success: 400 (Bad Request).')
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, 'GraphError', 'InvalidOperation', $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"Invalid assignment"}}')
                throw $errorRecord
            }

            { Set-CPCProvisioningPolicyAssignment -Name 'Dedicated Policy' -GroupName 'Dedicated Users' -Force -ErrorAction Stop } | Should -Throw -ExpectedMessage "*BadRequest: Invalid assignment*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
        }
    }

    Context "Policy name lookup (-ErrorAction <ErrorActionValue>)" -ForEach @(
        @{ ErrorActionValue = "Stop" }
        @{ ErrorActionValue = "SilentlyContinue" }
    ) {

        BeforeEach {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -like "https://graph.microsoft.com/beta/groups?*" } -MockWith {
                [pscustomobject]@{ Content = '{"value":[{"id":"00000000-0000-0000-0000-0000000000a1","displayName":"Dedicated Users"}]}' }
            }
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -like "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies/*" } -MockWith {
                [pscustomobject]@{ Content = '{"id":"policy-2","provisioningType":"dedicated","assignments":[]}' }
            }
        }

        It "stops and sends nothing when the server-side filter returns a policy with another name" {
            # For example a + in the name is decoded as a space by the unescaped filter in Get-CPCProvisioningPolicy
            Mock -ModuleName PSCloudPC Get-CPCProvisioningPolicy -MockWith {
                [pscustomobject]@{ id = "policy-2"; displayName = "Sales EU"; provisioningType = "dedicated" }
            }

            { Set-CPCProvisioningPolicyAssignment -Name "Sales+EU" -GroupName "Dedicated Users" -ErrorAction $ErrorActionValue } |
                Should -Throw -ExpectedMessage "No Provisioning Policy found with name Sales+EU"

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly -ParameterFilter { ([uri]$Uri).OriginalString -like "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies/*" }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "stops, lists the ids and sends nothing when two policies have exactly this name" {
            Mock -ModuleName PSCloudPC Get-CPCProvisioningPolicy -MockWith {
                [pscustomobject]@{ id = "policy-1"; displayName = "Dedicated Policy"; provisioningType = "dedicated" }
                [pscustomobject]@{ id = "policy-2"; displayName = "Dedicated Policy"; provisioningType = "dedicated" }
            }

            { Set-CPCProvisioningPolicyAssignment -Name "Dedicated Policy" -GroupName "Dedicated Users" -ErrorAction $ErrorActionValue } |
                Should -Throw -ExpectedMessage "2 Provisioning Policies found with name Dedicated Policy (policy-1, policy-2)*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Group lookup (-ErrorAction <ErrorActionValue>)" -ForEach @(
        @{ ErrorActionValue = "Stop" }
        @{ ErrorActionValue = "SilentlyContinue" }
    ) {

        BeforeEach {
            Mock -ModuleName PSCloudPC Get-CPCProvisioningPolicy -MockWith {
                [pscustomobject]@{ id = 'policy-1'; displayName = 'Dedicated Policy'; provisioningType = 'dedicated' }
            }
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri } -MockWith {
                [pscustomobject]@{ Content = '{"id":"policy-1","provisioningType":"dedicated","assignments":[]}' }
            }
        }

        It "stops and sends no request when no group has the name" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -like "https://graph.microsoft.com/beta/groups?*" } -MockWith {
                [pscustomobject]@{ Content = '{"value":[]}' }
            }

            { Set-CPCProvisioningPolicyAssignment -Name "Dedicated Policy" -GroupName "Dedicated Users" -ErrorAction $ErrorActionValue } |
                Should -Throw -ExpectedMessage "No group found with name Dedicated Users"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly -ParameterFilter { ([uri]$Uri).OriginalString -eq $ExpandUri }
        }

        It "stops, lists the ids and sends no request when two groups have the name" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -like "https://graph.microsoft.com/beta/groups?*" } -MockWith {
                [pscustomobject]@{ Content = '{"value":[{"id":"00000000-0000-0000-0000-0000000000a1","displayName":"Dedicated Users"},{"id":"00000000-0000-0000-0000-0000000000a2","displayName":"Dedicated Users"}]}' }
            }

            { Set-CPCProvisioningPolicyAssignment -Name "Dedicated Policy" -GroupName "Dedicated Users" -ErrorAction $ErrorActionValue } |
                Should -Throw -ExpectedMessage "2 groups found with name Dedicated Users ($GroupId, $OtherGroupId)*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "stops and sends no request when no group name is given" {
            { Set-CPCProvisioningPolicyAssignment -Name "Dedicated Policy" -ErrorAction $ErrorActionValue } |
                Should -Throw -ExpectedMessage "GroupName is required"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "looks the group up with an exact, escaped displayName filter" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -like "https://graph.microsoft.com/beta/groups?*" } -MockWith {
                [pscustomobject]@{ Content = '{"value":[{"id":"00000000-0000-0000-0000-0000000000a1","displayName":"O''Brien & Co"}]}' }
            }

            Set-CPCProvisioningPolicyAssignment -Name "Dedicated Policy" -GroupName "O'Brien & Co" -ErrorAction $ErrorActionValue | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -eq "https://graph.microsoft.com/beta/groups?`$filter=displayName%20eq%20%27O%27%27Brien%20%26%20Co%27&`$select=id,displayName"
            }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                @(($Body | ConvertFrom-Json).assignments)[0].target.groupId -eq $GroupId
            }
        }
    }
}
