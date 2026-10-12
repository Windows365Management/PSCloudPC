<#
This file tests the Get-CPCSupportedRegion function by using Pester.
Contract: GET /deviceManagement/virtualEndpoint/supportedRegions (all pages), with
$filter=displayName eq '...' for -Name. Graph can return the same displayName more than once,
so the output includes id, geographicLocationType, supportedSolution and regionRestrictionDetail
next to the existing displayName, regionGroup and regionStatus.
https://learn.microsoft.com/graph/api/virtualendpoint-list-supportedregions?view=graph-rest-beta
https://learn.microsoft.com/graph/api/resources/cloudpcsupportedregion?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Get-CPCSupportedRegion" {

    BeforeAll {
        $RegionsUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/supportedRegions"

        # The same displayName twice, as seen live
        $Regions = @(
            @{ id = "00000000-0000-0000-0000-000000000001"; displayName = "westeurope"; regionGroup = "europeUnion"; regionStatus = "available"; geographicLocationType = "europe"; supportedSolution = "windows365"; regionRestrictionDetail = @{ cPURestricted = $false; gPURestricted = $false } }
            @{ id = "00000000-0000-0000-0000-000000000002"; displayName = "westeurope"; regionGroup = "netherlands"; regionStatus = "available"; geographicLocationType = $null; supportedSolution = "windows365"; regionRestrictionDetail = $null }
        )
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            [pscustomobject]@{ Content = (@{ value = $Regions } | ConvertTo-Json -Depth 10) }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { throw "Invoke-RestMethod must not be called by Get-CPCSupportedRegion" }
    }

    Context "Request" {

        It "sends a GET to supportedRegions without a filter" {
            Get-CPCSupportedRegion | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter { "$Uri" -eq $RegionsUri -and $Method -eq "GET" }
        }

        It "filters on displayName for -Name" {
            Get-CPCSupportedRegion -Name "westeurope" | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                "$Uri" -eq "$RegionsUri`?`$filter=displayName+eq+'westeurope'"
            }
        }

        It "follows @odata.nextLink" {
            $NextLink = "$RegionsUri`?`$skiptoken=page2"
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                if ("$Uri" -eq $NextLink) {
                    [pscustomobject]@{ Content = (@{ value = @($Regions[1]) } | ConvertTo-Json -Depth 10) }
                }
                else {
                    [pscustomobject]@{ Content = (@{ value = @($Regions[0]); "@odata.nextLink" = $NextLink } | ConvertTo-Json -Depth 10) }
                }
            }

            $result = @(Get-CPCSupportedRegion)

            $result.Count | Should -Be 2
        }
    }

    Context "Output" {

        It "returns both regions with the same displayName and the properties that tell them apart" {
            $result = @(Get-CPCSupportedRegion -Name "westeurope")

            $result.Count | Should -Be 2
            $result.id | Should -Be @("00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000002")
            $result.regionGroup | Should -Be @("europeUnion", "netherlands")
            $result[0].geographicLocationType | Should -Be "europe"
            $result[0].supportedSolution | Should -Be "windows365"
            $result[0].regionRestrictionDetail.cPURestricted | Should -BeFalse
        }

        It "keeps the existing properties first" {
            $result = @(Get-CPCSupportedRegion)

            ($result[0].PSObject.Properties.Name)[0..2] | Should -Be @("displayName", "regionGroup", "regionStatus")
        }
    }

    Context "Graph error" {

        It "throws with the Graph error code" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 403 (Forbidden).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "PermissionDenied", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Forbidden","message":"Insufficient privileges"}}')
                throw $errorRecord
            }

            { Get-CPCSupportedRegion -ErrorAction Stop } | Should -Throw "*Forbidden: Insufficient privileges*"
        }
    }
}
