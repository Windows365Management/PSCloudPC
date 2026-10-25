<#
This file tests the Set-CPCProvisioningPolicyAssignment function by using Pester.
Focus: the service plan lookup. For shared provisioning types (sharedByUser,
sharedByEntraGroup) the assignment target is a cloudPcManagementGroupAssignmentTarget whose
servicePlanId must be a single id; null is only valid for dedicated policies.
https://learn.microsoft.com/en-us/graph/api/cloudpcprovisioningpolicy-assign?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpcmanagementgroupassignmenttarget?view=graph-rest-beta
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
        $GroupId = '00000000-0000-0000-0000-0000000000a1'
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

        # Group lookup is not under test: Get-AzureADGroupID returns the id of the group.
        Mock -ModuleName PSCloudPC Get-AzureADGroupID -MockWith { '00000000-0000-0000-0000-0000000000a1' }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { }
    }

    Context 'Shared provisioning type <ProvisioningType>' -ForEach @(
        @{ ProvisioningType = 'sharedByUser' }
        @{ ProvisioningType = 'sharedByEntraGroup' }
    ) {

        BeforeEach {
            Mock -ModuleName PSCloudPC Get-CPCProvisioningPolicy -MockWith {
                [pscustomobject]@{ id = 'policy-1'; displayName = 'Frontline Policy'; provisioningType = $ProvisioningType }
            }
        }

        It 'sends a single string servicePlanId when exactly one plan matches' {
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith {
                [pscustomobject]@{ id = $PlanId; displayName = $PlanName; provisioningType = 'shared' }
            }

            Set-CPCProvisioningPolicyAssignment -Name 'Frontline Policy' -GroupName 'Frontline Users' -ProvisioningType $ProvisioningType -ServicePlanName $PlanName | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $target = @(($Body | ConvertFrom-Json).assignments)[0].target
                $Uri -eq $AssignUri -and
                $Method -eq 'POST' -and
                $target.'@odata.type' -eq '#microsoft.graph.cloudPcManagementGroupAssignmentTarget' -and
                $target.groupId -eq $GroupId -and
                $target.servicePlanId -is [string] -and
                $target.servicePlanId -eq $PlanId -and
                $target.allotmentLicensesCount -is [long] -and
                $target.allotmentLicensesCount -eq 1
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

        It 'still throws and sends no request with -ErrorAction SilentlyContinue when the group is not found' {
            Mock -ModuleName PSCloudPC Get-AzureADGroupID -MockWith { $null }
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith {
                [pscustomobject]@{ id = $PlanId; displayName = $PlanName; provisioningType = 'shared' }
            }

            { Set-CPCProvisioningPolicyAssignment -Name 'Frontline Policy' -GroupName 'Frontline Users' -ProvisioningType $ProvisioningType -ServicePlanName $PlanName -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage 'No group found with name Frontline Users'

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

    Context 'Dedicated provisioning type' {

        BeforeEach {
            Mock -ModuleName PSCloudPC Get-CPCProvisioningPolicy -MockWith {
                [pscustomobject]@{ id = 'policy-1'; displayName = 'Dedicated Policy'; provisioningType = 'dedicated' }
            }
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith { }
        }

        It 'sends a group-only assignment without a servicePlanId' {
            Set-CPCProvisioningPolicyAssignment -Name 'Dedicated Policy' -GroupName 'Dedicated Users' -Force | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $target = @(($Body | ConvertFrom-Json).assignments)[0].target
                $Uri -eq $AssignUri -and
                $Method -eq 'POST' -and
                $target.groupId -eq $GroupId -and
                $null -eq $target.servicePlanId
            }
        }

        It 'throws when the assign POST fails' {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                $exception = [System.Exception]::new('Response status code does not indicate success: 400 (Bad Request).')
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, 'GraphError', 'InvalidOperation', $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"Invalid assignment"}}')
                throw $errorRecord
            }

            { Set-CPCProvisioningPolicyAssignment -Name 'Dedicated Policy' -GroupName 'Dedicated Users' -Force -ErrorAction Stop } | Should -Throw

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
        }
    }
}
