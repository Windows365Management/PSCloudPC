<#
This file tests the Get-CPCAzureNetworkConnection function by using Pester.
Contract: GET /deviceManagement/virtualEndpoint/onPremisesConnections (supports $filter), read
through all pages. -Name is sent as an escaped displayName eq filter and matched exactly on the
client. connectionType is returned; type is kept but retired by Graph since January 31, 2024.
https://learn.microsoft.com/graph/api/virtualendpoint-list-onpremisesconnections?view=graph-rest-beta
https://learn.microsoft.com/graph/api/resources/cloudpconpremisesconnection?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Get-CPCAzureNetworkConnection" {

    BeforeAll {
        $ListUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/onPremisesConnections"
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        # Connections returned by Graph. Tests may replace this list.
        $Connections = @(
            @{ id = "00000000-0000-0000-0000-000000000001"; displayName = "Fake Net"; connectionType = "azureADJoin" }
        )

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            [pscustomobject]@{ Content = (@{ value = @($Connections) } | ConvertTo-Json -Depth 10) }
        }
    }

    It "lists all connections without a filter" {
        $result = @(Get-CPCAzureNetworkConnection)

        $result.Count | Should -Be 1
        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            ([uri]$Uri).OriginalString -eq $ListUri
        }
    }

    It "reads every page" {
        Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ListUri } -MockWith {
            [pscustomobject]@{ Content = (@{ value = @(@{ id = "1"; displayName = "Fake Net 1" }); "@odata.nextLink" = "$ListUri`?`$skiptoken=page2" } | ConvertTo-Json -Depth 10) }
        }
        Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq "$ListUri`?`$skiptoken=page2" } -MockWith {
            [pscustomobject]@{ Content = (@{ value = @(@{ id = "2"; displayName = "Fake Net 2" }) } | ConvertTo-Json -Depth 10) }
        }

        $result = @(Get-CPCAzureNetworkConnection)

        $result.id | Should -Be @("1", "2")
    }

    It "sends -Name as an escaped, URL-encoded displayName filter" {
        Get-CPCAzureNetworkConnection -Name "Fake's Net" | Out-Null

        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            ([uri]$Uri).OriginalString -eq "$ListUri`?`$filter=displayName+eq+'Fake%27%27s%20Net'"
        }
    }

    It "returns only exact (case-insensitive) name matches" {
        $Connections = @(
            @{ id = "00000000-0000-0000-0000-000000000001"; displayName = "Fake Net" }
            @{ id = "00000000-0000-0000-0000-000000000002"; displayName = "Fake Net 2" }
        )

        $result = @(Get-CPCAzureNetworkConnection -Name "fake net")

        $result.Count | Should -Be 1
        $result[0].id | Should -Be "00000000-0000-0000-0000-000000000001"
    }

    It "returns connectionType and keeps the type property" {
        $result = Get-CPCAzureNetworkConnection -Name "Fake Net"

        $result.connectionType | Should -Be "azureADJoin"
        $result.PSObject.Properties.Name | Should -Contain "type"
    }

    It "returns nothing (not an empty object) when no connection matches" {
        $Connections = @()

        $result = @(Get-CPCAzureNetworkConnection -Name "Fake Net")

        $result.Count | Should -Be 0
    }

    It "rejects an empty -Name" {
        { Get-CPCAzureNetworkConnection -Name "" } | Should -Throw

        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly
    }

    It "throws with the Graph error code when the request fails" {
        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            $exception = [System.Exception]::new("Response status code does not indicate success: 403 (Forbidden).")
            $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "PermissionDenied", $null)
            $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Forbidden","message":"Access denied"}}')
            throw $errorRecord
        }

        { Get-CPCAzureNetworkConnection -ErrorAction Stop } | Should -Throw -ExpectedMessage "*Forbidden: Access denied*"
    }
}
