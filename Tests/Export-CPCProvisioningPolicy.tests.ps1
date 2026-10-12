<#
This file tests the Export-CPCProvisioningPolicy function by using Pester.
Contract: the policy is looked up by exact displayName (GET provisioningPolicies?$filter=displayName eq '...'),
must match exactly one policy, and is then read with GET provisioningPolicies/{id} and written
to <OutputFolder>/<displayName>.json. Zero or more than one match stops with a terminating error
(also with -ErrorAction SilentlyContinue) and never uses break, so a caller's loop keeps running (#155).
https://learn.microsoft.com/graph/api/virtualendpoint-list-provisioningpolicies?view=graph-rest-beta
https://learn.microsoft.com/graph/api/cloudpcprovisioningpolicy-get?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Export-CPCProvisioningPolicy" {

    BeforeAll {
        $PolicyUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies/00000000-0000-0000-0000-000000000001/"
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        # Policies returned by the name lookup. Tests may replace this list.
        $Policies = @(@{ id = "00000000-0000-0000-0000-000000000001"; displayName = "Policy01"; provisioningType = "dedicated" })

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            if ("$Uri" -like "*provisioningPolicies/00000000-*") {
                [pscustomobject]@{ Content = (@{ id = "00000000-0000-0000-0000-000000000001"; displayName = "Policy01"; provisioningType = "dedicated" } | ConvertTo-Json -Depth 10) }
            }
            else {
                [pscustomobject]@{ Content = (@{ value = @($Policies) } | ConvertTo-Json -Depth 10) }
            }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { throw "Invoke-RestMethod must not be called by Export-CPCProvisioningPolicy" }
    }

    It "reads the policy by id and writes <displayName>.json in the output folder" {
        Export-CPCProvisioningPolicy -Name "Policy01" -OutputFolder $TestDrive

        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter { "$Uri" -eq $PolicyUri -and $Method -eq "GET" }
        $file = Join-Path -Path $TestDrive -ChildPath "Policy01.json"
        Test-Path -Path $file | Should -BeTrue
        (Get-Content -Path $file -Raw | ConvertFrom-Json).id | Should -Be "00000000-0000-0000-0000-000000000001"
    }

    It "stops when the name matches no policy and writes no file" {
        $Policies = @()

        { Export-CPCProvisioningPolicy -Name "Missing" -OutputFolder $TestDrive } | Should -Throw "*Missing*not found*"
        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -ParameterFilter { "$Uri" -like "*provisioningPolicies/00000000-*" }
        Test-Path -Path (Join-Path -Path $TestDrive -ChildPath "Missing.json") | Should -BeFalse
    }

    It "stops when the name matches more than one policy and lists the ids" {
        $Policies = @(
            @{ id = "00000000-0000-0000-0000-000000000001"; displayName = "Policy01" }
            @{ id = "00000000-0000-0000-0000-000000000002"; displayName = "Policy01" }
        )

        { Export-CPCProvisioningPolicy -Name "Policy01" -OutputFolder $TestDrive } | Should -Throw "*00000000-0000-0000-0000-000000000002*"
        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -ParameterFilter { "$Uri" -like "*provisioningPolicies/00000000-*" }
    }

    It "still stops with -ErrorAction SilentlyContinue" {
        $Policies = @()

        { Export-CPCProvisioningPolicy -Name "Missing" -OutputFolder $TestDrive -ErrorAction SilentlyContinue } | Should -Throw "*not found*"
        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -ParameterFilter { "$Uri" -like "*provisioningPolicies/00000000-*" }
    }

    It "does not end the caller's loop when a name doesn't exist (#155)" {
        $Policies = @()
        $visited = [System.Collections.Generic.List[string]]::new()

        foreach ($policyName in @("Missing1", "Missing2")) {
            try {
                Export-CPCProvisioningPolicy -Name $policyName -OutputFolder $TestDrive
            }
            catch {
                Write-Verbose "Expected failure for $policyName"
            }
            $visited.Add($policyName)
        }

        $visited | Should -Be @("Missing1", "Missing2")
    }

    It "sends Prefer: include-unknown-enum-members with the bearer token on the policy GET" {
        Export-CPCProvisioningPolicy -Name "Policy01" -OutputFolder $TestDrive

        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            "$Uri" -eq $PolicyUri -and $Headers.Prefer -eq "include-unknown-enum-members" -and $Headers.Authorization -eq "Bearer token"
        }
    }

    It "does not change the module's auth header when adding Prefer" {
        Export-CPCProvisioningPolicy -Name "Policy01" -OutputFolder $TestDrive

        InModuleScope PSCloudPC { $script:Authheader.ContainsKey("Prefer") } | Should -BeFalse
    }

    Context "File name from the tenant's displayName (security review 4.2)" {

        BeforeEach {
            $ExportFolder = Join-Path -Path $TestDrive -ChildPath ("export-" + [guid]::NewGuid().ToString("N"))
            New-Item -Path $ExportFolder -ItemType Directory | Out-Null
        }

        It "writes '<DisplayName>' as '<ExpectedFile>' inside the output folder" -TestCases @(
            @{ DisplayName = "../../evil"; ExpectedFile = "_.._evil.json" }
            @{ DisplayName = "..\..\evil"; ExpectedFile = "_.._evil.json" }
            @{ DisplayName = "/etc/evil"; ExpectedFile = "_etc_evil.json" }
            @{ DisplayName = "C:\Temp\evil"; ExpectedFile = "C__Temp_evil.json" }
            @{ DisplayName = "Policy: A|B?*"; ExpectedFile = "Policy_ A_B__.json" }
            @{ DisplayName = "Policy [EU]"; ExpectedFile = "Policy [EU].json" }
            @{ DisplayName = ".."; ExpectedFile = "ProvisioningPolicy-00000000-0000-0000-0000-000000000001.json" }
            @{ DisplayName = "CON"; ExpectedFile = "_CON.json" }
        ) {
            param($DisplayName, $ExpectedFile)
            $Policies = @(@{ id = "00000000-0000-0000-0000-000000000001"; displayName = $DisplayName })

            Export-CPCProvisioningPolicy -Name $DisplayName -OutputFolder $ExportFolder

            $files = @(Get-ChildItem -LiteralPath $ExportFolder -File -Force)
            $files.Count | Should -Be 1
            $files[0].Name | Should -BeExactly $ExpectedFile
            Test-Path -LiteralPath (Join-Path -Path $TestDrive -ChildPath "evil.json") | Should -BeFalse
            Test-Path -LiteralPath (Join-Path -Path (Split-Path -Path $TestDrive -Parent) -ChildPath "evil.json") | Should -BeFalse
        }

        It "warns before overwriting an existing file" {
            Set-Content -LiteralPath (Join-Path -Path $ExportFolder -ChildPath "Policy01.json") -Value "old"

            Export-CPCProvisioningPolicy -Name "Policy01" -OutputFolder $ExportFolder -WarningVariable exportWarnings -WarningAction SilentlyContinue

            $exportWarnings.Count | Should -Be 1
            "$($exportWarnings[0])" | Should -BeLike "*Overwriting*Policy01.json*"
            (Get-Content -LiteralPath (Join-Path -Path $ExportFolder -ChildPath "Policy01.json") -Raw) | Should -Not -BeLike "old*"
        }

        It "keeps an existing file when the policy GET fails with -ErrorAction SilentlyContinue" {
            Set-Content -LiteralPath (Join-Path -Path $ExportFolder -ChildPath "Policy01.json") -Value "old"
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { "$Uri" -like "*provisioningPolicies/00000000-*" } -MockWith {
                throw "Response status code does not indicate success: 503 (Service Unavailable)."
            }

            { Export-CPCProvisioningPolicy -Name "Policy01" -OutputFolder $ExportFolder -ErrorAction SilentlyContinue } | Should -Throw "*503*"
            (Get-Content -LiteralPath (Join-Path -Path $ExportFolder -ChildPath "Policy01.json") -Raw).Trim() | Should -Be "old"
        }
    }

    It "throws with the Graph error code when reading the policy fails" {
        Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { "$Uri" -like "*provisioningPolicies/00000000-*" } -MockWith {
            $exception = [System.Exception]::new("Response status code does not indicate success: 403 (Forbidden).")
            $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "PermissionDenied", $null)
            $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Forbidden","message":"Insufficient privileges"}}')
            throw $errorRecord
        }

        { Export-CPCProvisioningPolicy -Name "Policy01" -OutputFolder $TestDrive -ErrorAction Stop } | Should -Throw "*Forbidden: Insufficient privileges*"
    }
}
