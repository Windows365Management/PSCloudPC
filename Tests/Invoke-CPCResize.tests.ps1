<#
This file tests the Invoke-CPCResize function by using Pester.
Contract: POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/resize with a body
{ "targetServicePlanId": "<single id>" }. A service plan name must resolve to exactly
one plan; zero or several matches must stop before the POST.
https://learn.microsoft.com/en-us/graph/api/cloudpc-resize?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../PSCloudPc/PSCloudPC.psd1') -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-CPCResize' {

    BeforeAll {
        $ResizeUri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/00000000-0000-0000-0000-0000000000c1/resize'
        $PlanName = 'Cloud PC Enterprise 4vCPU/16GB/256GB'
        $PlanId = '00000000-0000-0000-0000-000000000004'
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = 'token'
            $script:Authheader = @{ Authorization = 'Bearer token' }
            $script:MSGraphVersion = 'beta'
        }

        Mock -ModuleName PSCloudPC Get-CloudPC -MockWith {
            [pscustomobject]@{ id = '00000000-0000-0000-0000-0000000000c1'; displayName = 'CPC-TEST-01'; managedDeviceName = 'CPC-TEST-01' }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { }
    }

    Context 'By service plan id' {

        It 'POSTs targetServicePlanId to the resize action of the Cloud PC' {
            Invoke-CPCResize -Name 'CPC-TEST-01' -ServicePlanId $PlanId | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq $ResizeUri -and
                $Method -eq 'POST' -and
                ($Body | ConvertFrom-Json).targetServicePlanId -is [string] -and
                ($Body | ConvertFrom-Json).targetServicePlanId -eq $PlanId
            }
        }
    }

    Context 'By service plan name (lookup mocked at Get-CPCServicePlan)' {

        It 'sends a single string targetServicePlanId when exactly one plan matches' {
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith {
                [pscustomobject]@{ id = $PlanId; displayName = $PlanName; provisioningType = 'dedicated' }
            }

            Invoke-CPCResize -Name 'CPC-TEST-01' -ServicePlanName $PlanName | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq $ResizeUri -and
                $Method -eq 'POST' -and
                ($Body | ConvertFrom-Json).targetServicePlanId -is [string] -and
                ($Body | ConvertFrom-Json).targetServicePlanId -eq $PlanId
            }
        }

        It 'errors and sends no POST when no plan matches' {
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith { }

            { Invoke-CPCResize -Name 'CPC-TEST-01' -ServicePlanName 'Does Not Exist' -ErrorAction Stop } | Should -Throw

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0
        }

        It 'errors and sends no POST when more than one plan matches' {
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith {
                [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000004'; displayName = $PlanName; provisioningType = 'dedicated' }
                [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000005'; displayName = $PlanName; provisioningType = 'dedicated' }
            }

            { Invoke-CPCResize -Name 'CPC-TEST-01' -ServicePlanName $PlanName -ErrorAction Stop } | Should -Throw

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0
        }
    }

    Context 'Guards with -ErrorAction SilentlyContinue' {
        # A Throw in begin is skipped with SilentlyContinue and process would still POST; the guards must still stop.

        It 'still throws and sends no POST when no plan matches' {
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith { }

            { Invoke-CPCResize -Name 'CPC-TEST-01' -ServicePlanName 'Does Not Exist' -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "Service plan 'Does Not Exist' not found*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It 'still throws and sends no POST when more than one plan matches' {
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith {
                [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000004'; displayName = $PlanName; provisioningType = 'dedicated' }
                [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000005'; displayName = $PlanName; provisioningType = 'dedicated' }
            }

            { Invoke-CPCResize -Name 'CPC-TEST-01' -ServicePlanName $PlanName -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "2 service plans found with name '$PlanName'*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context 'By service plan name (lookup mocked at the HTTP boundary)' {

        It 'resolves the name against the full servicePlans list and sends one id' {
            # The servicePlans endpoint supports no OData query parameters, so Graph returns every plan.
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                [pscustomobject]@{
                    Content = (@{
                            value = @(
                                @{ id = '00000000-0000-0000-0000-000000000001'; displayName = 'Cloud PC Enterprise 2vCPU/8GB/128GB'; provisioningType = 'dedicated' }
                                @{ id = $PlanId; displayName = $PlanName; provisioningType = 'dedicated' }
                                @{ id = '00000000-0000-0000-0000-000000000003'; displayName = 'Cloud PC Frontline 2vCPU/8GB/128GB'; provisioningType = 'shared' }
                            )
                        } | ConvertTo-Json -Depth 10)
                }
            }

            Invoke-CPCResize -Name 'CPC-TEST-01' -ServicePlanName $PlanName | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq $ResizeUri -and
                $Method -eq 'POST' -and
                ($Body | ConvertFrom-Json).targetServicePlanId -is [string] -and
                ($Body | ConvertFrom-Json).targetServicePlanId -eq $PlanId
            }
        }
    }

    Context 'WhatIf' {

        It 'sends no POST with -WhatIf' {
            Invoke-CPCResize -Name 'CPC-TEST-01' -ServicePlanId $PlanId -WhatIf | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0
        }
    }

    Context 'Graph error' {

        It 'throws when the resize POST fails' {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                $exception = [System.Exception]::new('Response status code does not indicate success: 400 (Bad Request).')
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, 'GraphError', 'InvalidOperation', $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"Invalid target service plan"}}')
                throw $errorRecord
            }

            { Invoke-CPCResize -Name 'CPC-TEST-01' -ServicePlanId $PlanId -ErrorAction Stop } | Should -Throw

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
        }
    }
}
