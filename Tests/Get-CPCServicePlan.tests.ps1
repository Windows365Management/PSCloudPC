<#
This file tests the Get-CPCServicePlan function by using Pester.
Contract: GET /deviceManagement/virtualEndpoint/servicePlans without any OData query
parameters (the endpoint supports none), client-side exact display name matching,
@odata.nextLink paging and provisioningType in the output.
https://learn.microsoft.com/en-us/graph/api/virtualendpoint-list-serviceplans?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../PSCloudPc/PSCloudPC.psd1') -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CPCServicePlan' {

    BeforeAll {
        $script:ServicePlansUri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/servicePlans'

        # The endpoint ignores/doesn't support $filter, so the mock always returns the full list.
        $script:AllPlans = @(
            @{ id = '00000000-0000-0000-0000-000000000001'; displayName = 'Cloud PC Enterprise 2vCPU/8GB/128GB'; type = 'enterprise'; vCpuCount = 2; ramInGB = 8; storageInGB = 128; userProfileInGB = 0; provisioningType = 'dedicated' }
            @{ id = '00000000-0000-0000-0000-000000000002'; displayName = 'Cloud PC Enterprise 2vCPU/8GB/256GB'; type = 'enterprise'; vCpuCount = 2; ramInGB = 8; storageInGB = 256; userProfileInGB = 0; provisioningType = 'dedicated' }
            @{ id = '00000000-0000-0000-0000-000000000003'; displayName = 'Cloud PC Frontline 2vCPU/8GB/128GB'; type = 'enterprise'; vCpuCount = 2; ramInGB = 8; storageInGB = 128; userProfileInGB = 0; provisioningType = 'shared' }
            @{ id = '00000000-0000-0000-0000-000000000004'; displayName = 'Windows 365 Enterprise 4 vCPU, 16 GB, 256 GB'; type = 'enterprise'; vCpuCount = 4; ramInGB = 16; storageInGB = 256; userProfileInGB = 0; provisioningType = 'dedicated' }
        )
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = 'token'
            $script:Authheader = @{ Authorization = 'Bearer token' }
            $script:MSGraphVersion = 'beta'
        }

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            [pscustomobject]@{ Content = (@{ value = $AllPlans } | ConvertTo-Json -Depth 10) }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { throw 'Invoke-RestMethod must not be called by Get-CPCServicePlan' }
    }

    Context 'Request' {

        It 'sends a GET to the servicePlans collection with no query string when no name is given' {
            Get-CPCServicePlan | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq $ServicePlansUri -and $Method -eq 'GET'
            }
        }

        It 'sends no $filter (or any query string) when -ServicePlanName is "<Name>"' -TestCases @(
            @{ Name = 'Cloud PC Enterprise 2vCPU/8GB/128GB' }
            @{ Name = 'Windows 365 Enterprise 4 vCPU, 16 GB, 256 GB' }
        ) {
            param($Name)
            Get-CPCServicePlan -ServicePlanName $Name | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq $ServicePlansUri -and $Method -eq 'GET'
            }
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -ParameterFilter {
                "$Uri" -match '\?' -or "$Uri" -match 'filter'
            }
        }

        It 'sends the bearer token in the Authorization header' {
            Get-CPCServicePlan | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Headers.Authorization -eq 'Bearer token'
            }
        }
    }

    Context 'Client-side name matching' {

        It 'returns exactly the plan whose displayName equals "<Name>"' -TestCases @(
            @{ Name = 'Cloud PC Enterprise 2vCPU/8GB/128GB'; ExpectedId = '00000000-0000-0000-0000-000000000001' }
            @{ Name = 'Cloud PC Frontline 2vCPU/8GB/128GB'; ExpectedId = '00000000-0000-0000-0000-000000000003' }
            @{ Name = 'Windows 365 Enterprise 4 vCPU, 16 GB, 256 GB'; ExpectedId = '00000000-0000-0000-0000-000000000004' }
            @{ Name = 'cloud pc frontline 2vcpu/8gb/128gb'; ExpectedId = '00000000-0000-0000-0000-000000000003' }
        ) {
            param($Name, $ExpectedId)
            $result = @(Get-CPCServicePlan -ServicePlanName $Name)

            $result.Count | Should -Be 1
            $result[0].id | Should -Be $ExpectedId
        }

        It 'does not return partial or prefix matches' {
            $result = @(Get-CPCServicePlan -ServicePlanName 'Cloud PC Enterprise 2vCPU/8GB')

            $result.Count | Should -Be 0
        }

        It 'returns no plan when nothing matches' {
            $result = @(Get-CPCServicePlan -ServicePlanName 'Does Not Exist' -ErrorAction SilentlyContinue)

            $result.Count | Should -Be 0
        }

        It 'returns all plans when no name is given' {
            $result = @(Get-CPCServicePlan)

            $result.Count | Should -Be 4
        }
    }

    Context 'Parameter validation' {

        It 'rejects an empty -ServicePlanName instead of returning all plans' {
            { Get-CPCServicePlan -ServicePlanName '' } | Should -Throw -ErrorId 'ParameterArgumentValidationError*'

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context 'Output' {

        It 'includes provisioningType' {
            $result = @(Get-CPCServicePlan -ServicePlanName 'Cloud PC Frontline 2vCPU/8GB/128GB')

            $result[0].PSObject.Properties.Name | Should -Contain 'provisioningType'
            $result[0].provisioningType | Should -Be 'shared'
        }

        It 'includes the documented sizing properties' {
            $result = @(Get-CPCServicePlan -ServicePlanName 'Cloud PC Enterprise 2vCPU/8GB/128GB')

            $result[0].displayName | Should -Be 'Cloud PC Enterprise 2vCPU/8GB/128GB'
            $result[0].vCpuCount | Should -Be 2
            $result[0].ramInGB | Should -Be 8
            $result[0].storageInGB | Should -Be 128
        }
    }

    Context 'Paging' {

        BeforeEach {
            $script:NextLink = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/servicePlans?$skiptoken=page2'

            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                if ("$Uri" -eq $NextLink) {
                    [pscustomobject]@{ Content = (@{ value = @($AllPlans[2], $AllPlans[3]) } | ConvertTo-Json -Depth 10) }
                }
                else {
                    [pscustomobject]@{ Content = (@{ value = @($AllPlans[0], $AllPlans[1]); '@odata.nextLink' = $NextLink } | ConvertTo-Json -Depth 10) }
                }
            }
        }

        It 'follows @odata.nextLink and returns plans from every page' {
            $result = @(Get-CPCServicePlan)

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter { "$Uri" -eq $NextLink }
            $result.Count | Should -Be 4
            $result.id | Should -Contain '00000000-0000-0000-0000-000000000004'
        }

        It 'finds a plan by name that is only on the second page' {
            $result = @(Get-CPCServicePlan -ServicePlanName 'Windows 365 Enterprise 4 vCPU, 16 GB, 256 GB')

            $result.Count | Should -Be 1
            $result[0].id | Should -Be '00000000-0000-0000-0000-000000000004'
        }
    }

    Context 'Graph error' {

        It 'throws when Graph returns an error' {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                $exception = [System.Exception]::new('Response status code does not indicate success: 403 (Forbidden).')
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, 'GraphError', 'PermissionDenied', $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Forbidden","message":"Insufficient privileges"}}')
                throw $errorRecord
            }

            { Get-CPCServicePlan -ErrorAction Stop } | Should -Throw
        }
    }
}
