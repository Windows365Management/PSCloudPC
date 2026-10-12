<#
This file tests the Invoke-CPCChangeUserAccountType function by using Pester.
Contract: POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/changeUserAccountType with Content-Type application/json
and body { "userAccountType": "standardUser|administrator" } in the documented casing.
The Cloud PC is resolved by an exact managedDeviceName match or by -CloudPCId (GET cloudPCs/{id});
zero or several matches stop before the POST.
https://learn.microsoft.com/graph/api/cloudpc-changeuseraccounttype?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Invoke-CPCChangeUserAccountType" {

    BeforeAll {
        $CloudPCId = "00000000-0000-0000-0000-0000000000c1"
        $LookupUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs?`$filter=managedDeviceName+eq+'CPC-TEST-01'"
        $GetUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$CloudPCId"
        $ActionUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$CloudPCId/changeUserAccountType"
        $DefaultCloudPC = @{ id = $CloudPCId; displayName = "Cloud PC Test 01"; managedDeviceName = "CPC-TEST-01"; status = "provisioned" }
        $DuplicateCloudPC = @{ id = "00000000-0000-0000-0000-0000000000c2"; displayName = "Cloud PC Test 02"; managedDeviceName = "CPC-TEST-01"; status = "provisioned" }
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        # Cloud PCs returned by the managedDeviceName lookup (Graph GET). Tests may replace this list.
        $GraphCloudPCs = @($DefaultCloudPC)

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            [pscustomobject]@{ Content = (@{ value = @($GraphCloudPCs) } | ConvertTo-Json -Depth 10) }
        }
        Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $GetUri } -MockWith {
            [pscustomobject]@{ Content = ($DefaultCloudPC | ConvertTo-Json -Depth 10) }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { }
    }

    It "POSTs userAccountType '<Expected>' for input '<Value>'" -ForEach @(
        @{ Value = "administrator"; Expected = "administrator" }
        @{ Value = "standardUser"; Expected = "standardUser" }
        @{ Value = "Administrator"; Expected = "administrator" }
        @{ Value = "standarduser"; Expected = "standardUser" }
    ) {
        $result = Invoke-CPCChangeUserAccountType -Name "CPC-TEST-01" -UserAccountType $Value

        $result | Should -BeNullOrEmpty
        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            ([uri]$Uri).OriginalString -eq $LookupUri
        }
        Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            $parsed = $Body | ConvertFrom-Json
            ([uri]$Uri).OriginalString -ceq $ActionUri -and
            $Method -eq "POST" -and
            $ContentType -eq "application/json" -and
            @($parsed.PSObject.Properties.Name).Count -eq 1 -and
            $parsed.userAccountType -is [string] -and
            $parsed.userAccountType -ceq $Expected
        }
    }

    It "reads the Cloud PC by -CloudPCId and POSTs to that id" {
        Invoke-CPCChangeUserAccountType -CloudPCId $CloudPCId -UserAccountType standardUser

        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            ([uri]$Uri).OriginalString -eq $GetUri
        }
        Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            ([uri]$Uri).OriginalString -ceq $ActionUri -and
            ($Body | ConvertFrom-Json).userAccountType -ceq "standardUser"
        }
    }

    It "rejects a value that isn't a documented account type" {
        { Invoke-CPCChangeUserAccountType -Name "CPC-TEST-01" -UserAccountType "unknownFutureValue" } | Should -Throw

        Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
    }

    It "reports an error and sends no POST when <Case> (-ErrorAction <Action>)" -ForEach @(
        @{ Case = "no Cloud PC matches"; MatchCount = 0; Action = "Stop"; Message = "No Cloud PC found*" }
        @{ Case = "no Cloud PC matches"; MatchCount = 0; Action = "SilentlyContinue"; Message = "No Cloud PC found*" }
        @{ Case = "two Cloud PCs match"; MatchCount = 2; Action = "Stop"; Message = "2 Cloud PCs found*" }
        @{ Case = "two Cloud PCs match"; MatchCount = 2; Action = "SilentlyContinue"; Message = "2 Cloud PCs found*" }
    ) {
        $GraphCloudPCs = @(@($DefaultCloudPC, $DuplicateCloudPC) | Select-Object -First $MatchCount)

        if ($Action -eq "Stop") {
            { Invoke-CPCChangeUserAccountType -Name "CPC-TEST-01" -UserAccountType administrator -ErrorAction Stop } | Should -Throw -ExpectedMessage $Message
        }
        else {
            # A problem with one Cloud PC is a non-terminating error
            Invoke-CPCChangeUserAccountType -Name "CPC-TEST-01" -UserAccountType administrator -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors
            # -ErrorVariable also collects the Graph errors the module caught; count only the module's own records
            $moduleErrors = @($cloudPCErrors | Where-Object FullyQualifiedErrorId -like "PSCloudPC.CloudPCError*")
            $moduleErrors.Count | Should -Be 1
            $moduleErrors[0].Exception.Message | Should -BeLike $Message
        }

        Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
    }

    It "sends no POST with -WhatIf" {
        Invoke-CPCChangeUserAccountType -Name "CPC-TEST-01" -UserAccountType administrator -WhatIf

        Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
    }

    It "throws the Graph error code when the POST fails" {
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
            $exception = [System.Exception]::new("Response status code does not indicate success: 400 (Bad Request).")
            $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
            $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"Account type change not allowed"}}')
            throw $errorRecord
        }

        { Invoke-CPCChangeUserAccountType -Name "CPC-TEST-01" -UserAccountType administrator -ErrorAction Stop } | Should -Throw -ExpectedMessage "*BadRequest: Account type change not allowed*"

        Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
    }

    Context "Windows 365 Business only" {
        # https://learn.microsoft.com/microsoft-365/lighthouse/m365-lighthouse-change-cloud-pc-account-type
        # Graph answers 400 badRequest for other Cloud PCs; cloudPC.productType (beta) is enterprise, frontline, devBox, powerAutomate or business

        It "adds the Business hint to a 400 for a Cloud PC with productType '<ProductType>': <ExpectHint>" -ForEach @(
            @{ ProductType = "enterprise"; StatusText = "400 (Bad Request)"; Code = "badRequest"; ExpectHint = $true }
            @{ ProductType = "frontline"; StatusText = "400 (Bad Request)"; Code = "badRequest"; ExpectHint = $true }
            @{ ProductType = "business"; StatusText = "400 (Bad Request)"; Code = "badRequest"; ExpectHint = $false }
            @{ ProductType = $null; StatusText = "400 (Bad Request)"; Code = "badRequest"; ExpectHint = $false }
            @{ ProductType = "enterprise"; StatusText = "409 (Conflict)"; Code = "Conflict"; ExpectHint = $false }
        ) {
            $GraphCloudPCs = @(@{ id = $CloudPCId; displayName = "Cloud PC Test 01"; managedDeviceName = "CPC-TEST-01"; status = "provisioned"; productType = $ProductType })

            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: $StatusText.")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new("{`"error`":{`"code`":`"$Code`",`"message`":`"Cannot process the request because it is malformed or incorrect.`"}}")
                throw $errorRecord
            }

            Invoke-CPCChangeUserAccountType -Name "CPC-TEST-01" -UserAccountType administrator -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors

            # -ErrorVariable also collects the Graph errors the module caught; count only the module's own records
            $moduleErrors = @($cloudPCErrors | Where-Object FullyQualifiedErrorId -like "PSCloudPC.CloudPCError*")
            $moduleErrors.Count | Should -Be 1
            $moduleErrors[0].Exception.Message | Should -BeLike "*$($Code): Cannot process the request because it is malformed or incorrect.*"
            if ($ExpectHint) {
                $moduleErrors[0].Exception.Message | Should -BeLike "*only supported for Windows 365 Business Cloud PCs*'$ProductType'*"
            }
            else {
                $moduleErrors[0].Exception.Message | Should -Not -BeLike "*Windows 365 Business*"
            }
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
            Get-CloudPC | Invoke-CPCChangeUserAccountType -UserAccountType administrator

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 2 -Exactly
            foreach ($piped in $PipedCloudPCs) {
                Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                    ([uri]$Uri).OriginalString -ceq "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$($piped.id)/changeUserAccountType" -and
                    $Method -eq "POST" -and
                    ($Body | ConvertFrom-Json).userAccountType -ceq "administrator"
                }
            }
        }

        It "binds a piped object by its CloudPCId property" {
            [pscustomobject]@{ CloudPCId = "00000000-0000-0000-0000-0000000000d2" } | Invoke-CPCChangeUserAccountType -UserAccountType administrator

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -ceq "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/00000000-0000-0000-0000-0000000000d2/changeUserAccountType"
            }
        }

        It "sends nothing for piped Cloud PCs with -WhatIf" {
            Get-CloudPC | Invoke-CPCChangeUserAccountType -UserAccountType administrator -WhatIf

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "writes one error for a Cloud PC that fails with 409 Conflict and continues with the next piped Cloud PC" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -ParameterFilter { ([uri]$Uri).OriginalString -like "*00000000-0000-0000-0000-0000000000d1*" } -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 409 (Conflict).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Conflict","message":"Another action is still active"}}')
                throw $errorRecord
            }

            Get-CloudPC | Invoke-CPCChangeUserAccountType -UserAccountType administrator -ErrorAction SilentlyContinue -ErrorVariable cloudPCErrors

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

            { Get-CloudPC | Invoke-CPCChangeUserAccountType -UserAccountType administrator -ErrorAction Stop } | Should -Throw -ExpectedMessage "*Conflict: Another action is still active*"

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
                $streamErrors = @($InputObject | Invoke-CPCChangeUserAccountType -UserAccountType administrator 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
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
