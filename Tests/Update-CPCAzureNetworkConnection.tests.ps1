<#
This file tests the Update-CPCAzureNetworkConnection function by using Pester.
Contract: PATCH /deviceManagement/virtualEndpoint/onPremisesConnections/{id} with only the
properties that were passed. adDomainPassword is the plain-text password (#137) and never
appears in verbose output. -Name must match exactly one connection.
https://learn.microsoft.com/graph/api/cloudpconpremisesconnection-update?view=graph-rest-beta
https://learn.microsoft.com/graph/api/resources/cloudpconpremisesconnection?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Update-CPCAzureNetworkConnection" {

    BeforeAll {
        $ConnectionId = "00000000-0000-0000-0000-000000000001"
        $PatchUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/onPremisesConnections/$ConnectionId"
        $FakePassword = "not-a-real-password"
        $SecurePassword = ConvertTo-SecureString $FakePassword -AsPlainText -Force
        $DefaultConnection = @{ id = $ConnectionId; displayName = "FakeConnection01" }
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        # Connections returned by the name lookup (Get-CPCAzureNetworkConnection). Tests may replace this list.
        $Connections = @($DefaultConnection)

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            [pscustomobject]@{ Content = (@{ value = @($Connections) } | ConvertTo-Json -Depth 10) }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { }
    }

    Context "Request" {

        It "PATCHes the id of the named connection with only the passed properties" {
            Update-CPCAzureNetworkConnection -Name "FakeConnection01" -DisplayName "FakeConnection02" | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -eq $PatchUri -and
                $Method -eq "PATCH" -and
                (($Body | ConvertFrom-Json | ConvertTo-Json -Compress) -eq '{"displayName":"FakeConnection02"}')
            }
        }

        It "PATCHes by -ConnectionId without a name lookup" {
            Update-CPCAzureNetworkConnection -ConnectionId $ConnectionId -SubnetId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-fake/providers/Microsoft.Network/virtualNetworks/vnet-fake/subnets/snet-fake" | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $parsed = $Body | ConvertFrom-Json
                ([uri]$Uri).OriginalString -eq $PatchUri -and
                (@($parsed.PSObject.Properties.Name) -join ",") -eq "subnetId"
            }
        }

        It "sends the password as plain text in adDomainPassword" {
            Update-CPCAzureNetworkConnection -Name "FakeConnection01" -AdDomainUserName "admin@contoso.com" -AdDomainPassword $SecurePassword | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $parsed = $Body | ConvertFrom-Json
                (@($parsed.PSObject.Properties.Name | Sort-Object) -join ",") -eq "adDomainPassword,adDomainUsername" -and
                $parsed.adDomainUsername -eq "admin@contoso.com" -and
                $parsed.adDomainPassword -ceq $FakePassword
            }
        }

        It "never writes the password to verbose output" {
            $verbose = Update-CPCAzureNetworkConnection -Name "FakeConnection01" -AdDomainPassword $SecurePassword -Verbose 4>&1 | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }

            $verbose | Should -Not -BeNullOrEmpty
            ($verbose.Message -join "`n") | Should -Not -BeLike "*$FakePassword*"
        }
    }

    Context "Checks" {

        It "stops and sends no PATCH when no property is passed" {
            { Update-CPCAzureNetworkConnection -Name "FakeConnection01" -ErrorAction Stop } | Should -Throw -ExpectedMessage "No update properties were specified*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "stops and sends no PATCH when no connection matches the name" {
            $Connections = @()

            { Update-CPCAzureNetworkConnection -Name "FakeConnection01" -DisplayName "New" -ErrorAction Stop } | Should -Throw -ExpectedMessage "No Azure Network Connection found with name 'FakeConnection01'*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "stops and sends no PATCH when two connections have the same name" {
            $Connections = @($DefaultConnection, @{ id = "00000000-0000-0000-0000-000000000002"; displayName = "FakeConnection01" })

            { Update-CPCAzureNetworkConnection -Name "FakeConnection01" -DisplayName "New" -ErrorAction Stop } |
                Should -Throw -ExpectedMessage "2 Azure Network Connections found with name 'FakeConnection01' (00000000-0000-0000-0000-000000000001, 00000000-0000-0000-0000-000000000002)*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Guards with -ErrorAction SilentlyContinue" {

        It "still throws and sends no PATCH when no connection matches the name" {
            $Connections = @()

            { Update-CPCAzureNetworkConnection -Name "FakeConnection01" -DisplayName "New" -ErrorAction SilentlyContinue } | Should -Throw -ExpectedMessage "No Azure Network Connection found with name 'FakeConnection01'*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "still throws and sends no PATCH when two connections have the same name" {
            $Connections = @($DefaultConnection, @{ id = "00000000-0000-0000-0000-000000000002"; displayName = "FakeConnection01" })

            { Update-CPCAzureNetworkConnection -Name "FakeConnection01" -DisplayName "New" -ErrorAction SilentlyContinue } | Should -Throw -ExpectedMessage "2 Azure Network Connections found*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Failed name lookup" {

        BeforeEach {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 403 (Forbidden).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "PermissionDenied", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Forbidden","message":"Access denied"}}')
                throw $errorRecord
            }
        }

        It "stops with the Graph error and sends no PATCH, also with -ErrorAction SilentlyContinue" {
            { Update-CPCAzureNetworkConnection -Name "FakeConnection01" -DisplayName "New" -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "Could not look up Azure Network Connection 'FakeConnection01'*Forbidden: Access denied*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Output" {

        It "drops adDomainPassword from the returned object" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                [pscustomobject]@{ id = $ConnectionId; displayName = "FakeConnection01"; adDomainPassword = "echoed-by-graph" }
            }

            $result = Update-CPCAzureNetworkConnection -Name "FakeConnection01" -AdDomainPassword $SecurePassword

            $result.id | Should -Be $ConnectionId
            $result.PSObject.Properties.Name | Should -Not -Contain "adDomainPassword"
        }
    }

    Context "WhatIf" {

        It "sends no PATCH with -WhatIf" {
            Update-CPCAzureNetworkConnection -Name "FakeConnection01" -AdDomainPassword $SecurePassword -WhatIf | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Graph error" {

        It "throws with the Graph error code when the PATCH fails" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 400 (Bad Request).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"Invalid domain"}}')
                throw $errorRecord
            }

            { Update-CPCAzureNetworkConnection -Name "FakeConnection01" -AdDomainName "contoso.com" -ErrorAction Stop } | Should -Throw -ExpectedMessage "*BadRequest: Invalid domain*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
        }
    }
}
