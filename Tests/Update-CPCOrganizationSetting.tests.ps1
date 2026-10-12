<#
This file tests the Update-CPCOrganizationSetting function by using Pester.
Contract: PATCH /deviceManagement/virtualEndpoint/organizationSettings with only the properties to
update (the docs say properties left out keep their values). enableMEMAutoEnroll and
enableSingleSignOn are JSON booleans, osVersion and userAccountType are documented enum values and
windowsSettings is a cloudPcWindowsSettings object with language (#140).
https://learn.microsoft.com/graph/api/cloudpcorganizationsettings-update?view=graph-rest-beta
https://learn.microsoft.com/graph/api/resources/cloudpcorganizationsettings?view=graph-rest-beta
https://learn.microsoft.com/graph/api/resources/cloudpcwindowssettings?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Update-CPCOrganizationSetting" {

    BeforeAll {
        $PatchUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/organizationSettings"
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith { }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { }
    }

    Context "Confirmation" {

        It "uses SupportsShouldProcess with ConfirmImpact High" {
            $binding = (Get-Command Update-CPCOrganizationSetting).ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }

            $binding.SupportsShouldProcess | Should -BeTrue
            $binding.ConfirmImpact | Should -Be ([System.Management.Automation.ConfirmImpact]::High)
        }

        It "sends no PATCH with -WhatIf" {
            Update-CPCOrganizationSetting -EnableSingleSignOn $false -WhatIf | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Request body" {

        It "sends exactly {`"enableSingleSignOn`":false} for -EnableSingleSignOn `$false" {
            Update-CPCOrganizationSetting -EnableSingleSignOn $false -Confirm:$false | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $parsed = $Body | ConvertFrom-Json
                ([uri]$Uri).OriginalString -eq $PatchUri -and
                $Method -eq "PATCH" -and
                $parsed.enableSingleSignOn -is [bool] -and
                ($parsed | ConvertTo-Json -Compress) -eq '{"enableSingleSignOn":false}'
            }
        }

        It "sends booleans as JSON booleans, enums as documented and windowsSettings as an object" {
            Update-CPCOrganizationSetting -OSVersion windows11 -UserAccountType standardUser -EnableMEMAutoEnroll $true -EnableSingleSignOn $true -WindowsSettings "en-US" -Confirm:$false | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $parsed = $Body | ConvertFrom-Json
                (@($parsed.PSObject.Properties.Name | Sort-Object) -join ",") -eq "enableMEMAutoEnroll,enableSingleSignOn,osVersion,userAccountType,windowsSettings" -and
                $parsed.enableMEMAutoEnroll -is [bool] -and $parsed.enableMEMAutoEnroll -eq $true -and
                $parsed.enableSingleSignOn -is [bool] -and $parsed.enableSingleSignOn -eq $true -and
                $parsed.osVersion -ceq "windows11" -and
                $parsed.userAccountType -ceq "standardUser" -and
                $parsed.windowsSettings -is [pscustomobject] -and
                (($parsed.windowsSettings | ConvertTo-Json -Compress) -eq '{"language":"en-US"}')
            }
        }

        It "sends only the property that was passed (<Name>)" -ForEach @(
            @{ Name = "OSVersion"; Params = @{ OSVersion = "windows10" }; Expected = '{"osVersion":"windows10"}' }
            @{ Name = "UserAccountType"; Params = @{ UserAccountType = "standardUser" }; Expected = '{"userAccountType":"standardUser"}' }
            @{ Name = "EnableMEMAutoEnroll"; Params = @{ EnableMEMAutoEnroll = $false }; Expected = '{"enableMEMAutoEnroll":false}' }
            @{ Name = "WindowsSettings"; Params = @{ WindowsSettings = "nl-NL" }; Expected = '{"windowsSettings":{"language":"nl-NL"}}' }
        ) {
            Update-CPCOrganizationSetting @Params -Confirm:$false | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ($Body | ConvertFrom-Json | ConvertTo-Json -Compress) -eq $Expected
            }
        }

        It "rejects an undocumented osVersion and sends no PATCH" {
            { Update-CPCOrganizationSetting -OSVersion "windows12" -Confirm:$false -ErrorAction Stop } | Should -Throw

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Empty update" {

        It "stops and sends no PATCH when no setting is passed" {
            { Update-CPCOrganizationSetting -Confirm:$false -ErrorAction Stop } | Should -Throw -ExpectedMessage "No organization settings were specified*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "still throws and sends no PATCH with -ErrorAction SilentlyContinue" {
            { Update-CPCOrganizationSetting -Confirm:$false -ErrorAction SilentlyContinue } | Should -Throw -ExpectedMessage "No organization settings were specified*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Graph error" {

        It "throws with the Graph error code when the PATCH fails" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 400 (Bad Request).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"Invalid setting"}}')
                throw $errorRecord
            }

            { Update-CPCOrganizationSetting -EnableSingleSignOn $false -Confirm:$false -ErrorAction Stop } | Should -Throw -ExpectedMessage "*BadRequest: Invalid setting*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
        }
    }
}
