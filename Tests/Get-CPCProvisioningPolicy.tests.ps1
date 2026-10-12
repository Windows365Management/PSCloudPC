<#
This file tests the Get-CPCProvisioningPolicy function by using Pester.
Contract: GET /deviceManagement/virtualEndpoint/provisioningPolicies (all pages), with
$filter=displayName eq '...' for -Name. The output adds windowsSetting (current) next to the
deprecated windowsSettings, and keeps userExperienceType (documented, but not in the default
list response).
https://learn.microsoft.com/graph/api/virtualendpoint-list-provisioningpolicies?view=graph-rest-beta
https://learn.microsoft.com/graph/api/resources/cloudpcprovisioningpolicy?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Get-CPCProvisioningPolicy" {

    BeforeAll {
        $PoliciesUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies"

        $Policies = @(
            @{ id = "00000000-0000-0000-0000-000000000001"; displayName = "Policy01"; provisioningType = "dedicated"; imageType = "gallery"; windowsSetting = @{ locale = "en-US" }; windowsSettings = @{ language = "en-US" }; cloudPcNamingTemplate = "CPC-%RAND:5%" }
            @{ id = "00000000-0000-0000-0000-000000000002"; displayName = "Policy02"; provisioningType = "sharedByUser"; imageType = "gallery"; windowsSetting = @{ locale = "nl-NL" }; windowsSettings = $null; cloudPcNamingTemplate = $null }
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
            [pscustomobject]@{ Content = (@{ value = $Policies } | ConvertTo-Json -Depth 10) }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { throw "Invoke-RestMethod must not be called by Get-CPCProvisioningPolicy" }
    }

    Context "Request" {

        It "sends a GET to provisioningPolicies without a filter" {
            Get-CPCProvisioningPolicy | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter { "$Uri" -eq $PoliciesUri -and $Method -eq "GET" }
        }

        It "sends Prefer: include-unknown-enum-members on every page, with the bearer token" {
            $NextLink = "$PoliciesUri`?`$skiptoken=page2"
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                if ("$Uri" -eq $NextLink) {
                    [pscustomobject]@{ Content = (@{ value = @($Policies[1]) } | ConvertTo-Json -Depth 10) }
                }
                else {
                    [pscustomobject]@{ Content = (@{ value = @($Policies[0]); "@odata.nextLink" = $NextLink } | ConvertTo-Json -Depth 10) }
                }
            }

            Get-CPCProvisioningPolicy | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 2 -Exactly -ParameterFilter {
                $Headers.Prefer -eq "include-unknown-enum-members" -and $Headers.Authorization -eq "Bearer token"
            }
        }

        It "returns the evolvable provisioningType values Graph sends with the Prefer header" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                [pscustomobject]@{ Content = (@{ value = @(@{ id = "00000000-0000-0000-0000-000000000003"; displayName = "Shared01"; provisioningType = "sharedByEntraGroup" }) } | ConvertTo-Json -Depth 10) }
            }

            (Get-CPCProvisioningPolicy -Name "Shared01").provisioningType | Should -Be "sharedByEntraGroup"
        }

        It "filters on displayName for -Name and doubles a single quote" {
            Get-CPCProvisioningPolicy -Name "Policy O'Test" | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                [uri]::UnescapeDataString(([uri]$Uri).OriginalString) -eq "$PoliciesUri`?`$filter=displayName+eq+'Policy O''Test'"
            }
        }

        It "follows @odata.nextLink" {
            $NextLink = "$PoliciesUri`?`$skiptoken=page2"
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                if ("$Uri" -eq $NextLink) {
                    [pscustomobject]@{ Content = (@{ value = @($Policies[1]) } | ConvertTo-Json -Depth 10) }
                }
                else {
                    [pscustomobject]@{ Content = (@{ value = @($Policies[0]); "@odata.nextLink" = $NextLink } | ConvertTo-Json -Depth 10) }
                }
            }

            $result = @(Get-CPCProvisioningPolicy)

            $result.Count | Should -Be 2
        }
    }

    Context "Output" {

        It "adds windowsSetting and keeps the deprecated windowsSettings" {
            $result = @(Get-CPCProvisioningPolicy)

            $result[0].windowsSetting.locale | Should -Be "en-US"
            $result[0].windowsSettings.language | Should -Be "en-US"
            $result[1].windowsSetting.locale | Should -Be "nl-NL"
        }

        It "keeps the existing properties in their order and adds windowsSetting at the end" {
            $result = @(Get-CPCProvisioningPolicy)

            $result[0].PSObject.Properties.Name | Should -Be @("id", "displayName", "userExperienceType", "provisioningType", "imageId", "imageDisplayName", "imageType", "enableSingleSignOn", "DomainJoinConfigurations", "windowsSettings", "CloudPcNamingTemplate", "windowsSetting")
        }

        It "returns nothing and no error when there are no policies" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith { [pscustomobject]@{ Content = '{"value":[]}' } }

            $result = @(Get-CPCProvisioningPolicy -Name "Missing" -ErrorVariable policyErrors)

            $result.Count | Should -Be 0
            $policyErrors.Count | Should -Be 0
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

            { Get-CPCProvisioningPolicy -ErrorAction Stop } | Should -Throw "*Forbidden: Insufficient privileges*"
        }
    }
}
