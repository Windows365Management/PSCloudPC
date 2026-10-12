<#
This file tests the Get-CPCCustomImage function by using Pester.
Contract: GET /deviceManagement/virtualEndpoint/deviceImages (supports $filter), read through all
pages. -Name is sent as an escaped displayName eq filter and matched exactly on the client; one
name can return several images (one per version).
https://learn.microsoft.com/graph/api/virtualendpoint-list-deviceimages?view=graph-rest-beta
https://learn.microsoft.com/graph/api/resources/cloudpcdeviceimage?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Get-CPCCustomImage" {

    BeforeAll {
        $ListUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/deviceImages"
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        # Images returned by Graph. Tests may replace this list.
        $Images = @(
            @{ id = "00000000-0000-0000-0000-000000000001"; displayName = "Fake Image"; version = "0.0.1" }
            @{ id = "00000000-0000-0000-0000-000000000002"; displayName = "Fake Image"; version = "0.0.2" }
        )

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            [pscustomobject]@{ Content = (@{ value = @($Images) } | ConvertTo-Json -Depth 10) }
        }
    }

    It "lists all images without a filter" {
        $result = @(Get-CPCCustomImage)

        $result.Count | Should -Be 2
        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            ([uri]$Uri).OriginalString -eq $ListUri
        }
    }

    It "reads every page" {
        Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq $ListUri } -MockWith {
            [pscustomobject]@{ Content = (@{ value = @(@{ id = "1"; displayName = "Fake Image 1" }); "@odata.nextLink" = "$ListUri`?`$skiptoken=page2" } | ConvertTo-Json -Depth 10) }
        }
        Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString -eq "$ListUri`?`$skiptoken=page2" } -MockWith {
            [pscustomobject]@{ Content = (@{ value = @(@{ id = "2"; displayName = "Fake Image 2" }) } | ConvertTo-Json -Depth 10) }
        }

        $result = @(Get-CPCCustomImage)

        $result.id | Should -Be @("1", "2")
    }

    It "sends -Name as an escaped, URL-encoded displayName filter" {
        Get-CPCCustomImage -Name "Fake's Image" | Out-Null

        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            ([uri]$Uri).OriginalString -eq "$ListUri`?`$filter=displayName+eq+'Fake%27%27s%20Image'"
        }
    }

    It "returns every version of an exact (case-insensitive) name match and nothing else" {
        $Images += @{ id = "00000000-0000-0000-0000-000000000003"; displayName = "Fake Image Pro"; version = "0.0.1" }

        $result = @(Get-CPCCustomImage -Name "fake image")

        $result.Count | Should -Be 2
        $result.version | Should -Be @("0.0.1", "0.0.2")
    }

    It "returns nothing (not an empty object) when no image matches" {
        $Images = @()

        $result = @(Get-CPCCustomImage -Name "Fake Image")

        $result.Count | Should -Be 0
    }

    It "rejects an empty -Name" {
        { Get-CPCCustomImage -Name "" } | Should -Throw

        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly
    }

    It "throws with the Graph error code when the request fails" {
        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            $exception = [System.Exception]::new("Response status code does not indicate success: 403 (Forbidden).")
            $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "PermissionDenied", $null)
            $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Forbidden","message":"Access denied"}}')
            throw $errorRecord
        }

        { Get-CPCCustomImage -ErrorAction Stop } | Should -Throw -ExpectedMessage "*Forbidden: Access denied*"
    }
}
