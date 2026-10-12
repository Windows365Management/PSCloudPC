<#
This file tests the Update-CPCProvisioningPolicy function by using Pester.
Contract: PATCH /deviceManagement/virtualEndpoint/provisioningPolicies/{id} with only the properties that are
passed (Graph keeps the rest), plus the unchanged displayName. Current property names only: imageType as
documented (gallery/custom), cloudPcNamingTemplate, and domainJoinConfigurations[].domainJoinType with
onPremisesConnectionId (never the deprecated type). domainJoinType comes from the connectionType that Graph
returns for the connection (GET onPremisesConnections), so a hybrid connection is never sent as azureADJoin.
The policy lookup sends Prefer: include-unknown-enum-members.
https://learn.microsoft.com/en-us/graph/api/cloudpcprovisioningpolicy-update?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpcdomainjoinconfiguration?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpconpremisesconnection?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Update-CPCProvisioningPolicy" {

    BeforeAll {
        $PolicyId = "00000000-0000-0000-0000-000000000001"
        $PatchUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies/$PolicyId"
        $ConnectionId = "00000000-0000-0000-0000-0000000000c1"
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        # Policies returned by the exact name lookup (Graph GET). Tests may replace this list.
        $Policies = @(@{ id = $PolicyId; displayName = "Policy01" })

        # Azure network connections as Graph returns them: connectionType, not the retired type
        $Connections = @(
            [pscustomobject]@{ id = $ConnectionId; displayName = "ANC-Hybrid"; connectionType = "hybridAzureADJoin"; healthCheckStatus = "passed" }
            [pscustomobject]@{ id = "00000000-0000-0000-0000-0000000000c2"; displayName = "ANC-Entra"; connectionType = "azureADJoin"; healthCheckStatus = "passed" }
        )

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            if ("$Uri" -like "*/onPremisesConnections*") {
                [pscustomobject]@{ Content = (@{ value = @($Connections) } | ConvertTo-Json -Depth 10) }
            }
            else {
                [pscustomobject]@{ Content = (@{ value = @($Policies) } | ConvertTo-Json -Depth 10) }
            }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { }
    }

    Context "Partial PATCH" {

        It "looks the policy up with Prefer: include-unknown-enum-members" {
            Update-CPCProvisioningPolicy -Name "Policy01" -NamingTemplate "PSCT-%RAND:6%" | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                "$Uri".Contains("/provisioningPolicies?") -and $Headers.Prefer -eq "include-unknown-enum-members"
            }
        }

        It "sends only displayName and cloudPcNamingTemplate for -NamingTemplate" {
            Update-CPCProvisioningPolicy -Name "Policy01" -NamingTemplate "PSCT-%RAND:6%" | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $b = $Body | ConvertFrom-Json
                $Uri -eq $PatchUri -and
                $Method -eq "PATCH" -and
                (@($b.PSObject.Properties.Name | Sort-Object) -join ",") -eq "cloudPcNamingTemplate,displayName" -and
                $b.displayName -ceq "Policy01" -and
                $b.cloudPcNamingTemplate -ceq "PSCT-%RAND:6%"
            }
        }

        It "sends enableSingleSignOn as a boolean, also when false" {
            Update-CPCProvisioningPolicy -Name "Policy01" -EnableSingleSignOn $false | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $b = $Body | ConvertFrom-Json
                (@($b.PSObject.Properties.Name | Sort-Object) -join ",") -eq "displayName,enableSingleSignOn" -and
                $b.enableSingleSignOn -is [bool] -and
                $b.enableSingleSignOn -eq $false
            }
        }

        It "sends imageId and the documented imageType value" {
            Update-CPCProvisioningPolicy -Name "Policy01" -ImageType Gallery -ImageId "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc" | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $b = $Body | ConvertFrom-Json
                (@($b.PSObject.Properties.Name | Sort-Object) -join ",") -eq "displayName,imageId,imageType" -and
                $b.imageType -ceq "gallery" -and
                $b.imageId -ceq "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc"
            }
        }

        It "doesn't send an empty imageType when only -ImageId is passed" {
            Update-CPCProvisioningPolicy -Name "Policy01" -ImageId "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc" | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                (@(($Body | ConvertFrom-Json).PSObject.Properties.Name | Sort-Object) -join ",") -eq "displayName,imageId"
            }
        }

        It "sends nothing and warns when there is nothing to update" {
            Update-CPCProvisioningPolicy -Name "Policy01" -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

            "$warnings" | Should -BeLike "*Nothing to update*"
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Azure network connection" {

        It "sends domainJoinType from the connection type and onPremisesConnectionId" {
            Update-CPCProvisioningPolicy -Name "Policy01" -AzureNetworkConnection "ANC-Hybrid" | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $b = $Body | ConvertFrom-Json
                $djc = @($b.domainJoinConfigurations)
                $b.domainJoinConfigurations -is [array] -and
                $djc.Count -eq 1 -and
                (@($djc[0].PSObject.Properties.Name | Sort-Object) -join ",") -eq "domainJoinType,onPremisesConnectionId" -and
                $djc[0].domainJoinType -ceq "hybridAzureADJoin" -and
                $djc[0].onPremisesConnectionId -ceq $ConnectionId
            }
        }

        It "errors and sends no PATCH when -DomainJoinType differs from the connection type" {
            { Update-CPCProvisioningPolicy -Name "Policy01" -AzureNetworkConnection "ANC-Hybrid" -DomainJoinType azureADJoin -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "*is of type hybridAzureADJoin*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "never sends azureADJoin for a hybrid connection when -DomainJoinType is not passed" {
            # The parameter default is azureADJoin; the connectionType from Graph must win
            Update-CPCProvisioningPolicy -Name "Policy01" -AzureNetworkConnection "ANC-Hybrid" | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                @(($Body | ConvertFrom-Json).domainJoinConfigurations)[0].domainJoinType -ceq "hybridAzureADJoin"
            }
        }

        It "reads connectionType from Graph and not the retired type" {
            $Connections = @([pscustomobject]@{ id = $ConnectionId; displayName = "ANC-Hybrid"; connectionType = "hybridAzureADJoin"; type = "azureADJoin"; healthCheckStatus = "passed" })

            Update-CPCProvisioningPolicy -Name "Policy01" -AzureNetworkConnection "ANC-Hybrid" | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $djc = @(($Body | ConvertFrom-Json).domainJoinConfigurations)
                $djc[0].domainJoinType -ceq "hybridAzureADJoin" -and
                $djc[0].PSObject.Properties.Name -notcontains "type"
            }
        }

        It "errors and sends no PATCH for connections of different types" {
            { Update-CPCProvisioningPolicy -Name "Policy01" -AzureNetworkConnection "ANC-Hybrid", "ANC-Entra" -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "*have different connection types*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "accepts health check status <Status> and stops on <Blocked>" -ForEach @(
            @{ Status = "warning"; Blocked = "failed" }
            @{ Status = "informational"; Blocked = "pending" }
        ) {
            $Connections = @(
                [pscustomobject]@{ id = $ConnectionId; displayName = "ANC-Ok"; connectionType = "hybridAzureADJoin"; healthCheckStatus = $Status }
                [pscustomobject]@{ id = "00000000-0000-0000-0000-0000000000c9"; displayName = "ANC-Blocked"; connectionType = "hybridAzureADJoin"; healthCheckStatus = $Blocked }
            )

            Update-CPCProvisioningPolicy -Name "Policy01" -AzureNetworkConnection "ANC-Ok" -WarningAction SilentlyContinue | Out-Null
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly

            { Update-CPCProvisioningPolicy -Name "Policy01" -AzureNetworkConnection "ANC-Blocked" -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "*healthCheckStatus: $Blocked*"
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
        }

        It "errors and sends no PATCH when no connection matches" {
            { Update-CPCProvisioningPolicy -Name "Policy01" -AzureNetworkConnection "Does Not Exist" -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "No Azure Network Connection found with name 'Does Not Exist'"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Checks with -ErrorAction SilentlyContinue" {

        It "still throws and sends no PATCH when no policy matches" {
            $Policies = @()

            { Update-CPCProvisioningPolicy -Name "Does Not Exist" -NamingTemplate "PSCT-%RAND:6%" -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "No Provisioning Policy found with name 'Does Not Exist'"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "still throws and sends no PATCH when two policies have the same name" {
            $Policies = @(
                @{ id = $PolicyId; displayName = "Policy01" }
                @{ id = "00000000-0000-0000-0000-000000000002"; displayName = "Policy01" }
            )

            { Update-CPCProvisioningPolicy -Name "Policy01" -NamingTemplate "PSCT-%RAND:6%" -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "2 Provisioning Policies found with name 'Policy01'*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "still throws and sends no PATCH for -ImageType without -ImageId" {
            { Update-CPCProvisioningPolicy -Name "Policy01" -ImageType Custom -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "-ImageType can only be used together with -ImageId"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "WhatIf" {

        It "sends no PATCH with -WhatIf" {
            Update-CPCProvisioningPolicy -Name "Policy01" -NamingTemplate "PSCT-%RAND:6%" -WhatIf | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Graph error" {

        It "throws with the Graph error code when the PATCH fails" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 400 (Bad Request).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"Invalid naming template"}}')
                throw $errorRecord
            }

            { Update-CPCProvisioningPolicy -Name "Policy01" -NamingTemplate "x" -ErrorAction Stop } | Should -Throw -ExpectedMessage "*BadRequest: Invalid naming template*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
        }
    }
}
