<#
This file tests the Invoke-CPCUnpublishCloudApp function by using Pester.
Contract: POST /deviceManagement/virtualEndpoint/cloudApps/unpublish with {"cloudAppIds": [...]}.
-Name is looked up with GET /cloudApps?$filter=displayName eq '<name>' and must match exactly one
app (display names are only unique within one provisioning policy); -Id and piped apps are read
with GET /cloudApps/{id}. Only apps with appStatus published or failed are unpublished
(unpublish + republish is the documented fix for a failed app). Graph returns 202 Accepted, so
the output says "Unpublish requested".
https://learn.microsoft.com/windows-365/enterprise/cloud-apps#publish-and-edit-cloud-apps
https://learn.microsoft.com/graph/api/cloudpccloudapp-unpublish?view=graph-rest-beta
https://learn.microsoft.com/graph/api/virtualendpoint-list-cloudapps?view=graph-rest-beta
https://learn.microsoft.com/graph/api/resources/cloudpccloudapp?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Invoke-CPCUnpublishCloudApp" {

    BeforeAll {
        $BaseUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudApps"
        $UnpublishUri = "$BaseUri/unpublish"
        $AppId1 = "00000000-0000-0000-0000-000000000001"
        $AppId2 = "00000000-0000-0000-0000-000000000002"
        $PolicyId1 = "00000000-0000-0000-0000-0000000000a1"
        $PolicyId2 = "00000000-0000-0000-0000-0000000000a2"

        $App1 = @{ id = $AppId1; displayName = "Fake App"; appStatus = "published"; provisioningPolicyId = $PolicyId1 }
        $App2 = @{ id = $AppId2; displayName = "Fake App"; appStatus = "published"; provisioningPolicyId = $PolicyId2 }
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        # Apps returned by the displayName lookup, and the status returned by the GET by id. Tests may replace these.
        $Apps = @($App1)
        $StatusById = "published"

        # List with $filter (Invoke-APIRequest -> Invoke-WebRequest)
        Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString.Contains("/cloudApps?") } -MockWith {
            [pscustomobject]@{ Content = (@{ value = @($Apps) } | ConvertTo-Json -Depth 10) }
        }
        # Single app by id
        Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { ([uri]$Uri).OriginalString.StartsWith("$BaseUri/") } -MockWith {
            $requestedId = ([uri]$Uri).OriginalString.Substring("$BaseUri/".Length)
            [pscustomobject]@{ Content = (@{ id = $requestedId; displayName = "Fake App"; appStatus = $StatusById; provisioningPolicyId = $PolicyId1 } | ConvertTo-Json -Depth 10) }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { }
    }

    Context "By name" {

        It "looks up the name with an escaped exact displayName filter" {
            Invoke-CPCUnpublishCloudApp -Name "Fake App" -WarningAction SilentlyContinue | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -eq "$BaseUri`?`$filter=displayName+eq+'Fake%20App'"
            }
        }

        It "POSTs exactly the id of the single exact match as a cloudAppIds array" {
            Invoke-CPCUnpublishCloudApp -Name "Fake App" -WarningAction SilentlyContinue | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $parsed = $Body | ConvertFrom-Json
                ([uri]$Uri).OriginalString -eq $UnpublishUri -and
                $Method -eq "POST" -and
                (@($parsed.PSObject.Properties.Name) -join ",") -eq "cloudAppIds" -and
                $parsed.cloudAppIds -is [array] -and
                $parsed.cloudAppIds.Count -eq 1 -and
                $parsed.cloudAppIds[0] -eq $AppId1
            }
        }

        It "warns that app details are reset" {
            Invoke-CPCUnpublishCloudApp -Name "Fake App" -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

            ($warnings -join " ") | Should -BeLike "*resets the app details*"
        }

        It "warns and sends no POST when the matching app has status <Status>" -ForEach @(
            @{ Status = "ready" }
            @{ Status = "preparing" }
            @{ Status = "publishing" }
            @{ Status = "unpublishing" }
        ) {
            $Apps = @(@{ id = $AppId1; displayName = "Fake App"; appStatus = $Status; provisioningPolicyId = $PolicyId1 })

            Invoke-CPCUnpublishCloudApp -Name "Fake App" -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

            ($warnings -join " ") | Should -BeLike "*is not published or failed*"
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "unpublishes a failed app (documented fix: unpublish and republish)" {
            $Apps = @(@{ id = $AppId1; displayName = "Fake App"; appStatus = "failed"; provisioningPolicyId = $PolicyId1 })

            Invoke-CPCUnpublishCloudApp -Name "Fake App" -WarningAction SilentlyContinue | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $ids = @(($Body | ConvertFrom-Json).cloudAppIds)
                ([uri]$Uri).OriginalString -eq $UnpublishUri -and $ids.Count -eq 1 -and $ids[0] -eq $AppId1
            }
        }

        It "outputs 'Unpublish requested' instead of claiming success" {
            $output = Invoke-CPCUnpublishCloudApp -Name "Fake App" -WarningAction SilentlyContinue

            $output | Should -Be "Unpublish requested for app: Fake App (ID: $AppId1)"
        }

        It "ignores apps whose name only contains the given name" {
            $Apps = @(@{ id = $AppId2; displayName = "Fake App Pro"; appStatus = "published"; provisioningPolicyId = $PolicyId2 })

            { Invoke-CPCUnpublishCloudApp -Name "Fake App" -ErrorAction Stop } | Should -Throw -ExpectedMessage "No Cloud App found with name 'Fake App'"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "stops and sends no POST when no app matches" {
            $Apps = @()

            { Invoke-CPCUnpublishCloudApp -Name "Fake App" -ErrorAction Stop } | Should -Throw -ExpectedMessage "No Cloud App found with name 'Fake App'"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "stops, lists the ids and policy ids, and sends no POST when the name exists in two policies" {
            $Apps = @($App1, $App2)

            { Invoke-CPCUnpublishCloudApp -Name "Fake App" -ErrorAction Stop } |
                Should -Throw -ExpectedMessage "2 Cloud Apps found with name 'Fake App': $AppId1 (provisioning policy $PolicyId1, status published), $AppId2 (provisioning policy $PolicyId2, status published). Use -Id to select one"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "By id" {

        It "reads the app by id and POSTs that id" {
            Invoke-CPCUnpublishCloudApp -Id $AppId2 -WarningAction SilentlyContinue | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString -eq "$BaseUri/$AppId2"
            }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $ids = @(($Body | ConvertFrom-Json).cloudAppIds)
                $ids.Count -eq 1 -and $ids[0] -eq $AppId2
            }
        }

        It "warns and sends no POST when the app isn't published or failed" {
            $StatusById = "ready"

            Invoke-CPCUnpublishCloudApp -Id $AppId1 -WarningAction SilentlyContinue | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "unpublishes a failed app by id" {
            $StatusById = "failed"

            Invoke-CPCUnpublishCloudApp -Id $AppId1 -WarningAction SilentlyContinue | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                @(($Body | ConvertFrom-Json).cloudAppIds)[0] -eq $AppId1
            }
        }

        It "stops and sends no POST when the app can't be read" {
            # A filtered mock defined last takes precedence over the filtered mocks from BeforeEach
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { $true } -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 404 (Not Found).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "ObjectNotFound", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"ResourceNotFound","message":"Not found"}}')
                throw $errorRecord
            }

            { Invoke-CPCUnpublishCloudApp -Id $AppId1 -ErrorAction Stop } | Should -Throw -ExpectedMessage "*ResourceNotFound*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Pipeline input" {

        It "re-reads each piped app and sends one POST with all published ids" {
            [pscustomobject]$App1, [pscustomobject]$App2 | Invoke-CPCUnpublishCloudApp -WarningAction SilentlyContinue | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 2 -Exactly -ParameterFilter {
                ([uri]$Uri).OriginalString.StartsWith("$BaseUri/")
            }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $ids = @(($Body | ConvertFrom-Json).cloudAppIds)
                $ids.Count -eq 2 -and $ids -contains $AppId1 -and $ids -contains $AppId2
            }
        }
    }

    Context "Guards with -ErrorAction SilentlyContinue" {

        It "still throws and sends no POST when no app matches" {
            $Apps = @()

            { Invoke-CPCUnpublishCloudApp -Name "Fake App" -ErrorAction SilentlyContinue } | Should -Throw -ExpectedMessage "No Cloud App found with name 'Fake App'"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "still throws and sends no POST when the name matches two apps" {
            $Apps = @($App1, $App2)

            { Invoke-CPCUnpublishCloudApp -Name "Fake App" -ErrorAction SilentlyContinue } | Should -Throw -ExpectedMessage "2 Cloud Apps found with name 'Fake App'*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "WhatIf" {

        It "sends no POST with -WhatIf" {
            Invoke-CPCUnpublishCloudApp -Name "Fake App" -WhatIf | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Graph error" {

        It "throws with the Graph error code when the POST fails" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 400 (Bad Request).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"Invalid cloud app"}}')
                throw $errorRecord
            }

            { Invoke-CPCUnpublishCloudApp -Name "Fake App" -ErrorAction Stop -WarningAction SilentlyContinue } | Should -Throw -ExpectedMessage "*BadRequest: Invalid cloud app*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
        }
    }
}
