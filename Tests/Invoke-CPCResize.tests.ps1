<#
This file tests the Invoke-CPCResize function by using Pester.
Contract: POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/resize with a body
{ "targetServicePlanId": "<single id>" }. A service plan name must resolve to exactly
one plan; zero or several matches must stop before the POST. The Cloud PC is resolved by an
exact managedDeviceName match; zero or several matches stop before the POST.
Resize changes the Cloud PC, so ConfirmImpact is High.
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
        $CloudPCId = '00000000-0000-0000-0000-0000000000c1'
        $ResizeUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$CloudPCId/resize"
        $LookupUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs?`$filter=managedDeviceName+eq+'CPC-TEST-01'"
        $ServicePlansUri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/servicePlans'
        $PlanName = 'Cloud PC Enterprise 4vCPU/16GB/256GB'
        $PlanId = '00000000-0000-0000-0000-000000000004'
        $DefaultCloudPC = @{ id = $CloudPCId; displayName = 'CPC-TEST-01'; managedDeviceName = 'CPC-TEST-01'; status = 'provisioned' }
        $DuplicateCloudPC = @{ id = '00000000-0000-0000-0000-0000000000c2'; displayName = 'CPC-TEST-02'; managedDeviceName = 'CPC-TEST-01'; status = 'provisioned' }
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = 'token'
            $script:Authheader = @{ Authorization = 'Bearer token' }
            $script:MSGraphVersion = 'beta'
        }

        # Cloud PCs returned by the managedDeviceName lookup (Graph GET). Tests may replace this list.
        $GraphCloudPCs = @($DefaultCloudPC)

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            [pscustomobject]@{ Content = (@{ value = @($GraphCloudPCs) } | ConvertTo-Json -Depth 10) }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { }
    }

    It 'is a high impact action' {
        (Get-Command Invoke-CPCResize).ScriptBlock.Attributes |
            Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] } |
            ForEach-Object { $_.ConfirmImpact } |
            Should -Be ([System.Management.Automation.ConfirmImpact]::High)
    }

    Context 'By service plan id' {

        It 'POSTs targetServicePlanId to the resize action of the Cloud PC' {
            $result = Invoke-CPCResize -Name 'CPC-TEST-01' -ServicePlanId $PlanId -Confirm:$false

            $result | Should -BeNullOrEmpty
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -eq $LookupUri
            }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq $ResizeUri -and
                $Method -eq 'POST' -and
                $ContentType -eq 'application/json' -and
                ($Body | ConvertFrom-Json).targetServicePlanId -is [string] -and
                ($Body | ConvertFrom-Json).targetServicePlanId -eq $PlanId
            }
        }
    }

    Context 'Cloud PC lookup' {

        It 'stops and sends no POST when <Case> (-ErrorAction <Action>)' -ForEach @(
            @{ Case = 'no Cloud PC matches'; MatchCount = 0; Action = 'Stop'; Message = 'No Cloud PC found*' }
            @{ Case = 'no Cloud PC matches'; MatchCount = 0; Action = 'SilentlyContinue'; Message = 'No Cloud PC found*' }
            @{ Case = 'two Cloud PCs match'; MatchCount = 2; Action = 'Stop'; Message = '2 Cloud PCs found*' }
            @{ Case = 'two Cloud PCs match'; MatchCount = 2; Action = 'SilentlyContinue'; Message = '2 Cloud PCs found*' }
        ) {
            $GraphCloudPCs = @(@($DefaultCloudPC, $DuplicateCloudPC) | Select-Object -First $MatchCount)

            if ($Action -eq "Stop") {
                { Invoke-CPCResize -Name 'CPC-TEST-01' -ServicePlanId $PlanId -Confirm:$false -ErrorAction Stop } | Should -Throw -ExpectedMessage $Message
            }
            else {
                # A problem with one Cloud PC is a non-terminating error
                Invoke-CPCResize -Name 'CPC-TEST-01' -ServicePlanId $PlanId -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors
                # -ErrorVariable also collects the Graph errors the module caught; count only the module's own records
                $moduleErrors = @($cloudPCErrors | Where-Object FullyQualifiedErrorId -like "PSCloudPC.CloudPCError*")
                $moduleErrors.Count | Should -Be 1
                $moduleErrors[0].Exception.Message | Should -BeLike $Message
            }

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context 'By service plan name (lookup mocked at Get-CPCServicePlan)' {

        It 'sends a single string targetServicePlanId when exactly one plan matches' {
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith {
                [pscustomobject]@{ id = $PlanId; displayName = $PlanName; provisioningType = 'dedicated' }
            }

            Invoke-CPCResize -Name 'CPC-TEST-01' -ServicePlanName $PlanName -Confirm:$false | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq $ResizeUri -and
                $Method -eq 'POST' -and
                ($Body | ConvertFrom-Json).targetServicePlanId -is [string] -and
                ($Body | ConvertFrom-Json).targetServicePlanId -eq $PlanId
            }
        }

        It 'errors and sends no POST when no plan matches' {
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith { }

            { Invoke-CPCResize -Name 'CPC-TEST-01' -ServicePlanName 'Does Not Exist' -Confirm:$false -ErrorAction Stop } | Should -Throw

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0
        }

        It 'errors and sends no POST when more than one plan matches' {
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith {
                [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000004'; displayName = $PlanName; provisioningType = 'dedicated' }
                [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000005'; displayName = $PlanName; provisioningType = 'dedicated' }
            }

            { Invoke-CPCResize -Name 'CPC-TEST-01' -ServicePlanName $PlanName -Confirm:$false -ErrorAction Stop } | Should -Throw

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0
        }
    }

    Context 'Guards with -ErrorAction SilentlyContinue' {
        # A Throw in begin is skipped with SilentlyContinue and process would still POST; the guards must still stop.

        It 'still throws and sends no POST when no plan matches' {
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith { }

            { Invoke-CPCResize -Name 'CPC-TEST-01' -ServicePlanName 'Does Not Exist' -Confirm:$false -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "Service plan 'Does Not Exist' not found*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It 'still throws and sends no POST when more than one plan matches' {
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith {
                [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000004'; displayName = $PlanName; provisioningType = 'dedicated' }
                [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000005'; displayName = $PlanName; provisioningType = 'dedicated' }
            }

            { Invoke-CPCResize -Name 'CPC-TEST-01' -ServicePlanName $PlanName -Confirm:$false -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "2 service plans found with name '$PlanName'*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context 'By service plan name (lookup mocked at the HTTP boundary)' {

        It 'resolves the name against the full servicePlans list and sends one id' {
            # The servicePlans endpoint supports no OData query parameters, so Graph returns every plan.
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ServicePlansUri } -MockWith {
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

            Invoke-CPCResize -Name 'CPC-TEST-01' -ServicePlanName $PlanName -Confirm:$false | Out-Null

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

        It 'throws the Graph error code when the resize POST fails' {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                $exception = [System.Exception]::new('Response status code does not indicate success: 400 (Bad Request).')
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, 'GraphError', 'InvalidOperation', $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"Invalid target service plan"}}')
                throw $errorRecord
            }

            { Invoke-CPCResize -Name 'CPC-TEST-01' -ServicePlanId $PlanId -Confirm:$false -ErrorAction Stop } | Should -Throw -ExpectedMessage '*BadRequest: Invalid target service plan*'

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
        }
    }

    Context "Pipeline input" {

        BeforeEach {
            $PipedCloudPCs = @(
                @{ id = "00000000-0000-0000-0000-0000000000d1"; displayName = "Cloud PC Piped 01"; managedDeviceName = "CPC-PIPED-01"; status = "provisioned" }
                @{ id = "00000000-0000-0000-0000-0000000000d2"; displayName = "Cloud PC Piped 02"; managedDeviceName = "CPC-PIPED-02"; status = "provisioned" }
            )
            # Get-CloudPC lists these Cloud PCs
            $GraphCloudPCs = $PipedCloudPCs

            # GET cloudPCs/{id} returns the piped Cloud PC with that id
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -match "/cloudPCs/[0-9a-f-]{36}$" } -MockWith {
                $requestedId = ([uri]$Uri).OriginalString.Split("/")[-1]
                [pscustomobject]@{ Content = (@($PipedCloudPCs | Where-Object { $_.id -eq $requestedId })[0] | ConvertTo-Json -Depth 10) }
            }
        }

        It "sends one request per Cloud PC piped from Get-CloudPC, each with its own id" {
            Get-CloudPC | Invoke-CPCResize -ServicePlanId "00000000-0000-0000-0000-000000000004" -Confirm:$false

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 2 -Exactly
            foreach ($piped in $PipedCloudPCs) {
                Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                    ([uri]$Uri).OriginalString -ceq "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$($piped.id)/resize" -and
                    $Method -eq "POST" -and
                    ($Body | ConvertFrom-Json).targetServicePlanId -ceq "00000000-0000-0000-0000-000000000004"
                }
            }
        }

        It "binds a piped object by its CloudPCId property" {
            [pscustomobject]@{ CloudPCId = "00000000-0000-0000-0000-0000000000d2" } | Invoke-CPCResize -ServicePlanId "00000000-0000-0000-0000-000000000004" -Confirm:$false

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -ceq "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/00000000-0000-0000-0000-0000000000d2/resize"
            }
        }

        It "sends nothing for piped Cloud PCs with -WhatIf" {
            Get-CloudPC | Invoke-CPCResize -ServicePlanId "00000000-0000-0000-0000-000000000004" -WhatIf

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "looks up -ServicePlanName once and resizes every piped Cloud PC to that plan" {
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith {
                [pscustomobject]@{ id = $PlanId; displayName = $PlanName; provisioningType = "dedicated" }
            }

            Get-CloudPC | Invoke-CPCResize -ServicePlanName $PlanName -Confirm:$false

            Should -Invoke Get-CPCServicePlan -ModuleName PSCloudPC -Times 1 -Exactly
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 2 -Exactly -ParameterFilter {
                ($Body | ConvertFrom-Json).targetServicePlanId -ceq $PlanId
            }
        }

        It "stops before any POST when the piped -ServicePlanName matches no plan" {
            Mock -ModuleName PSCloudPC Get-CPCServicePlan -MockWith { }

            { Get-CloudPC | Invoke-CPCResize -ServicePlanName "Does Not Exist" -Confirm:$false -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "Service plan 'Does Not Exist' not found*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "writes one error for a Cloud PC that fails with 409 Conflict and continues with the next piped Cloud PC" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -ParameterFilter { ([uri]$Uri).OriginalString -like "*00000000-0000-0000-0000-0000000000d1*" } -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 409 (Conflict).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Conflict","message":"Another action is still active"}}')
                throw $errorRecord
            }

            Get-CloudPC | Invoke-CPCResize -ServicePlanId "00000000-0000-0000-0000-000000000004" -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors

            # -ErrorVariable also collects the Graph errors the module caught; count only the module's own records
            $moduleErrors = @($cloudPCErrors | Where-Object FullyQualifiedErrorId -like "PSCloudPC.CloudPCError*")
            $moduleErrors.Count | Should -Be 1
            $moduleErrors[0].Exception.Message | Should -BeLike "*00000000-0000-0000-0000-0000000000d1*Conflict: Another action is still active*"
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 2 -Exactly
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -like "*00000000-0000-0000-0000-0000000000d2*"
            }
        }

        It "stops at the first failed Cloud PC with -ErrorAction Stop" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -ParameterFilter { ([uri]$Uri).OriginalString -like "*00000000-0000-0000-0000-0000000000d1*" } -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 409 (Conflict).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Conflict","message":"Another action is still active"}}')
                throw $errorRecord
            }

            { Get-CloudPC | Invoke-CPCResize -ServicePlanId "00000000-0000-0000-0000-000000000004" -Confirm:$false -ErrorAction Stop } | Should -Throw -ExpectedMessage "*Conflict: Another action is still active*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -like "*00000000-0000-0000-0000-0000000000d2*"
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
                $streamErrors = @($InputObject | Invoke-CPCResize -ServicePlanId "00000000-0000-0000-0000-000000000004" -Confirm:$false 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
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
