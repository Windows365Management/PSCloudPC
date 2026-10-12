<#
This file tests the New-CPCAzureNetworkConnection function by using Pester.
Contract: POST /deviceManagement/virtualEndpoint/onPremisesConnections with connectionType
(azureADJoin or hybridAzureADJoin); the deprecated type and the read-only subscriptionName are
never sent. For hybrid join, adDomainPassword is the plain-text password (#137) and never
appears in verbose output.
https://learn.microsoft.com/graph/api/virtualendpoint-post-onpremisesconnections?view=graph-rest-beta
https://learn.microsoft.com/graph/api/resources/cloudpconpremisesconnection?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "New-CPCAzureNetworkConnection" {

    BeforeAll {
        $PostUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/onPremisesConnections"
        $FakePassword = "not-a-real-password"

        $AzureParams = @{
            DisplayName      = "FakeConnection01"
            ResourceGroupId  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-fake"
            VirtualNetworkId = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-fake/providers/Microsoft.Network/virtualNetworks/vnet-fake"
            SubnetId         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-fake/providers/Microsoft.Network/virtualNetworks/vnet-fake/subnets/snet-fake"
            SubscriptionId   = "00000000-0000-0000-0000-000000000000"
        }

        $HybridParams = $AzureParams.Clone()
        $HybridParams.AdDomainName = "contoso.com"
        $HybridParams.AdDomainUserName = "admin@contoso.com"
        $HybridParams.AdDomainPassword = ConvertTo-SecureString $FakePassword -AsPlainText -Force
        $HybridParams.OrganizationalUnit = "OU=CloudPCs,DC=contoso,DC=com"
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        # Connections returned by the duplicate-name lookup (Get-CPCAzureNetworkConnection). Tests may replace this list.
        $Connections = @()

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            [pscustomobject]@{ Content = (@{ value = @($Connections) } | ConvertTo-Json -Depth 10) }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { }
    }

    Context "Microsoft Entra join" {

        It "POSTs connectionType azureADJoin and only the documented properties" {
            New-CPCAzureNetworkConnection @AzureParams | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $parsed = $Body | ConvertFrom-Json
                ([uri]$Uri).OriginalString -eq $PostUri -and
                $Method -eq "POST" -and
                (@($parsed.PSObject.Properties.Name | Sort-Object) -join ",") -eq "connectionType,displayName,resourceGroupId,subnetId,subscriptionId,virtualNetworkId" -and
                $parsed.connectionType -ceq "azureADJoin" -and
                $parsed.displayName -eq "FakeConnection01" -and
                $parsed.subscriptionId -eq $AzureParams.SubscriptionId -and
                $parsed.resourceGroupId -eq $AzureParams.ResourceGroupId -and
                $parsed.virtualNetworkId -eq $AzureParams.VirtualNetworkId -and
                $parsed.subnetId -eq $AzureParams.SubnetId
            }
        }
    }

    Context "Microsoft Entra hybrid join" {

        It "POSTs connectionType hybridAzureADJoin with the AD properties and the plain-text password" {
            New-CPCAzureNetworkConnection @HybridParams | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $parsed = $Body | ConvertFrom-Json
                (@($parsed.PSObject.Properties.Name | Sort-Object) -join ",") -eq "adDomainName,adDomainPassword,adDomainUsername,connectionType,displayName,organizationalUnit,resourceGroupId,subnetId,subscriptionId,virtualNetworkId" -and
                $parsed.connectionType -ceq "hybridAzureADJoin" -and
                $parsed.adDomainName -eq "contoso.com" -and
                $parsed.adDomainUsername -eq "admin@contoso.com" -and
                $parsed.adDomainPassword -ceq $FakePassword -and
                $parsed.organizationalUnit -eq "OU=CloudPCs,DC=contoso,DC=com"
            }
        }

        It "never sends the deprecated type or the read-only subscriptionName" {
            New-CPCAzureNetworkConnection @HybridParams | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $names = ($Body | ConvertFrom-Json).PSObject.Properties.Name
                $names -notcontains "type" -and $names -notcontains "subscriptionName"
            }
        }

        It "never writes the password to verbose output" {
            $verbose = New-CPCAzureNetworkConnection @HybridParams -Verbose 4>&1 | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }

            $verbose | Should -Not -BeNullOrEmpty
            ($verbose.Message -join "`n") | Should -Not -BeLike "*$FakePassword*"
        }
    }

    Context "Duplicate name" {

        It "stops and sends no POST when a connection with the same name exists" {
            $Connections = @(@{ id = "00000000-0000-0000-0000-000000000001"; displayName = "FakeConnection01" })

            { New-CPCAzureNetworkConnection @AzureParams -ErrorAction Stop } | Should -Throw -ExpectedMessage "Azure Network Connection with name 'FakeConnection01' already exists*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "still throws and sends no POST with -ErrorAction SilentlyContinue" {
            $Connections = @(@{ id = "00000000-0000-0000-0000-000000000001"; displayName = "FakeConnection01" })

            { New-CPCAzureNetworkConnection @AzureParams -ErrorAction SilentlyContinue } | Should -Throw -ExpectedMessage "Azure Network Connection with name 'FakeConnection01' already exists*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Failed duplicate lookup" {

        BeforeEach {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 403 (Forbidden).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "PermissionDenied", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Forbidden","message":"Access denied"}}')
                throw $errorRecord
            }
        }

        It "stops and sends no POST when the lookup fails" {
            { New-CPCAzureNetworkConnection @AzureParams -ErrorAction Stop } | Should -Throw -ExpectedMessage "Could not check for an existing Azure Network Connection*Forbidden: Access denied*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "still stops and sends no POST with -ErrorAction SilentlyContinue" {
            { New-CPCAzureNetworkConnection @HybridParams -ErrorAction SilentlyContinue } | Should -Throw -ExpectedMessage "Could not check for an existing Azure Network Connection*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Output" {

        It "drops adDomainPassword from the returned object" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                [pscustomobject]@{ id = "00000000-0000-0000-0000-000000000001"; displayName = "FakeConnection01"; connectionType = "hybridAzureADJoin"; adDomainPassword = "echoed-by-graph" }
            }

            $result = New-CPCAzureNetworkConnection @HybridParams

            $result.id | Should -Be "00000000-0000-0000-0000-000000000001"
            $result.connectionType | Should -Be "hybridAzureADJoin"
            $result.PSObject.Properties.Name | Should -Not -Contain "adDomainPassword"
        }
    }

    Context "WhatIf" {

        It "sends no POST with -WhatIf" {
            New-CPCAzureNetworkConnection @HybridParams -WhatIf | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Graph error" {

        It "throws with the Graph error code when the POST fails" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 400 (Bad Request).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"Invalid subnet"}}')
                throw $errorRecord
            }

            { New-CPCAzureNetworkConnection @AzureParams -ErrorAction Stop } | Should -Throw -ExpectedMessage "*BadRequest: Invalid subnet*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
        }
    }
}
