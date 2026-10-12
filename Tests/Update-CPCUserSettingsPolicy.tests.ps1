<#
This file tests the Update-CPCUserSettingsPolicy function by using Pester.
Contract: PATCH /deviceManagement/virtualEndpoint/userSettings/{id} replaces the whole object, so the
cmdlet reads the policy (GET userSettings/{id}) and sends every property it returns back, changing only
the passed parameters (also properties this module doesn't know yet). Read-only properties (id,
createdDateTime, lastModifiedDateTime, @odata.*), the deprecated restorePointSetting.frequencyInHours and the
retired selfServiceEnabled and notificationSetting are never sent; -SelfServiceEnabled and
-DisableRestartPrompts only write a warning. displayName is always sent.
crossRegionDisasterRecoveryEnabled is deprecated in the docs, but Graph still rejects crossRegion without
it, so it is sent as true for crossRegion/premium and false for notConfigured.
https://learn.microsoft.com/en-us/graph/api/cloudpcusersetting-update?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/cloudpcusersetting-get?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpcusersetting?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpcrestorepointsetting?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpccrossregiondisasterrecoverysetting?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Update-CPCUserSettingsPolicy" {

    BeforeAll {
        $PolicyId = "00000000-0000-0000-0000-000000000001"
        $PolicyUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/userSettings/$PolicyId"

        # All writable top-level properties the cmdlet sends for $CurrentPolicy, sorted
        $ExpectedNames = "crossRegionDisasterRecoverySetting,displayName,localAdminEnabled,provisioningSourceType,resetEnabled,restorePointSetting"

        # A policy with non-default values everywhere, as GET userSettings/{id} returns it
        $CurrentPolicy = @{
            "@odata.context"                   = "https://graph.microsoft.com/beta/`$metadata#deviceManagement/virtualEndpoint/userSettings/`$entity"
            id                                 = $PolicyId
            displayName                        = "UserSettings01"
            createdDateTime                    = "2026-01-01T00:00:00Z"
            lastModifiedDateTime               = "2026-01-02T00:00:00Z"
            selfServiceEnabled                 = $true
            localAdminEnabled                  = $true
            resetEnabled                       = $true
            provisioningSourceType             = "image"
            notificationSetting                = @{ restartPromptsDisabled = $true }
            restorePointSetting                = @{ frequencyInHours = 4; frequencyType = "fourHours"; userRestoreEnabled = $true }
            crossRegionDisasterRecoverySetting = @{
                crossRegionDisasterRecoveryEnabled     = $true
                disasterRecoveryType                   = "crossRegion"
                maintainCrossRegionRestorePointEnabled = $true
                userInitiatedDisasterRecoveryAllowed   = $false
                disasterRecoveryNetworkSetting         = @{
                    "@odata.type" = "#microsoft.graph.cloudPcDisasterRecoveryMicrosoftHostedNetworkSetting"
                    regionName    = "westeurope"
                    regionGroup   = "europeUnion"
                }
            }
        }

        # Returns $true when the parsed body keeps the current crossRegion disaster recovery setting
        $KeepsDisasterRecovery = {
            param ($Parsed)
            $dr = $Parsed.crossRegionDisasterRecoverySetting
            $dr.disasterRecoveryType -eq "crossRegion" -and
            $dr.crossRegionDisasterRecoveryEnabled -is [bool] -and
            $dr.crossRegionDisasterRecoveryEnabled -eq $true -and
            $dr.maintainCrossRegionRestorePointEnabled -eq $true -and
            $dr.userInitiatedDisasterRecoveryAllowed -eq $false -and
            $dr.disasterRecoveryNetworkSetting."@odata.type" -eq "#microsoft.graph.cloudPcDisasterRecoveryMicrosoftHostedNetworkSetting" -and
            $dr.disasterRecoveryNetworkSetting.regionName -eq "westeurope" -and
            $dr.disasterRecoveryNetworkSetting.regionGroup -eq "europeUnion"
        }
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        # Policies returned by Graph: the name lookup (GET userSettings?$filter=...) returns the list,
        # GET userSettings/{id} returns the matching policy. Tests may replace this list.
        $Policies = @($CurrentPolicy)

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            if ([string]$Uri -match "/userSettings/([^/?]+)$") {
                $policyId = $Matches[1]
                $policy = @($Policies | Where-Object { $_.id -eq $policyId })[0]
                [pscustomobject]@{ Content = ($policy | ConvertTo-Json -Depth 10) }
            }
            else {
                [pscustomobject]@{ Content = (@{ value = @($Policies) } | ConvertTo-Json -Depth 10) }
            }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { }
    }

    Context "Read-modify-write" {

        It "reads the policy by id and PATCHes the same id" {
            Update-CPCUserSettingsPolicy -Name "UserSettings01" -LocalAdminEnabled $false

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq $PolicyUri -and $Method -eq "GET"
            }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq $PolicyUri -and $Method -eq "PATCH" -and $ContentType -eq "application/json"
            }
        }

        It "localAdmin only: changes localAdminEnabled and keeps every other setting" {
            Update-CPCUserSettingsPolicy -Name "UserSettings01" -LocalAdminEnabled $false

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $parsed = $Body | ConvertFrom-Json
                (@($parsed.PSObject.Properties.Name | Sort-Object) -join ",") -eq $ExpectedNames -and
                $parsed.displayName -eq "UserSettings01" -and
                $parsed.localAdminEnabled -is [bool] -and
                $parsed.localAdminEnabled -eq $false -and
                $parsed.resetEnabled -is [bool] -and
                $parsed.resetEnabled -eq $true -and
                $parsed.provisioningSourceType -eq "image" -and
                (@($parsed.restorePointSetting.PSObject.Properties.Name | Sort-Object) -join ",") -eq "frequencyType,userRestoreEnabled" -and
                $parsed.restorePointSetting.frequencyType -eq "fourHours" -and
                $parsed.restorePointSetting.userRestoreEnabled -eq $true -and
                (& $KeepsDisasterRecovery $parsed)
            }
        }

        It "restore only: changes the restore point settings and keeps every other setting" {
            Update-CPCUserSettingsPolicy -Name "UserSettings01" -UserRestoreEnabled $false -UserRestoreFrequency 24

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $parsed = $Body | ConvertFrom-Json
                (@($parsed.PSObject.Properties.Name | Sort-Object) -join ",") -eq $ExpectedNames -and
                $parsed.displayName -eq "UserSettings01" -and
                $parsed.localAdminEnabled -eq $true -and
                $parsed.resetEnabled -eq $true -and
                $parsed.provisioningSourceType -eq "image" -and
                (@($parsed.restorePointSetting.PSObject.Properties.Name | Sort-Object) -join ",") -eq "frequencyType,userRestoreEnabled" -and
                $parsed.restorePointSetting.frequencyType -eq "twentyFourHours" -and
                $parsed.restorePointSetting.userRestoreEnabled -is [bool] -and
                $parsed.restorePointSetting.userRestoreEnabled -eq $false -and
                (& $KeepsDisasterRecovery $parsed)
            }
        }

        It "sends -UserRestoreFrequency <Hours> as frequencyType <FrequencyType> and keeps userRestoreEnabled" -ForEach @(
            @{ Hours = "4"; FrequencyType = "fourHours" }
            @{ Hours = "6"; FrequencyType = "sixHours" }
            @{ Hours = "12"; FrequencyType = "twelveHours" }
            @{ Hours = "16"; FrequencyType = "sixteenHours" }
            @{ Hours = "24"; FrequencyType = "twentyFourHours" }
        ) {
            Update-CPCUserSettingsPolicy -Name "UserSettings01" -UserRestoreFrequency $Hours

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $rp = ($Body | ConvertFrom-Json).restorePointSetting
                (@($rp.PSObject.Properties.Name | Sort-Object) -join ",") -eq "frequencyType,userRestoreEnabled" -and
                $rp.frequencyType -eq $FrequencyType -and
                $rp.userRestoreEnabled -eq $true
            }
        }

        It "adds a restorePointSetting when the policy has none" {
            $Policies = @(@{ id = $PolicyId; displayName = "UserSettings01"; localAdminEnabled = $true; resetEnabled = $false })

            Update-CPCUserSettingsPolicy -Name "UserSettings01" -UserRestoreEnabled $true

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $parsed = $Body | ConvertFrom-Json
                (@($parsed.PSObject.Properties.Name | Sort-Object) -join ",") -eq "displayName,localAdminEnabled,resetEnabled,restorePointSetting" -and
                $parsed.localAdminEnabled -eq $true -and
                (@($parsed.restorePointSetting.PSObject.Properties.Name) -join ",") -eq "userRestoreEnabled" -and
                $parsed.restorePointSetting.userRestoreEnabled -eq $true
            }
        }

        It "warns that the retired <Parameter> has no effect and does not send it" -ForEach @(
            @{ Parameter = "SelfServiceEnabled" }
            @{ Parameter = "DisableRestartPrompts" }
        ) {
            $params = @{ Name = "UserSettings01"; $Parameter = $true }
            Update-CPCUserSettingsPolicy @params -WarningVariable warnings -WarningAction SilentlyContinue

            @($warnings).Count | Should -Be 1
            "$($warnings[0])" | Should -BeLike "$Parameter*retired by Microsoft*no effect*"
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $parsed = $Body | ConvertFrom-Json
                (@($parsed.PSObject.Properties.Name | Sort-Object) -join ",") -eq $ExpectedNames -and
                $parsed.localAdminEnabled -eq $true -and
                (& $KeepsDisasterRecovery $parsed)
            }
        }

        It "never sends the retired selfServiceEnabled or notificationSetting that Graph still returns" {
            Update-CPCUserSettingsPolicy -Name "UserSettings01" -LocalAdminEnabled $false

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $names = ($Body | ConvertFrom-Json).PSObject.Properties.Name
                $names -notcontains "selfServiceEnabled" -and
                $names -notcontains "notificationSetting"
            }
        }

        It "sends back properties this module doesn't know, so PATCH doesn't reset them" {
            # PATCH replaces the object: a writable property Microsoft adds later must be copied as well
            $policy = $CurrentPolicy.Clone()
            $policy.futureFlagEnabled = $true
            $policy.futureSetting = @{ mode = "automatic"; regions = @("westeurope", "northeurope"); emptyValue = $null }
            $Policies = @($policy)

            Update-CPCUserSettingsPolicy -Name "UserSettings01" -LocalAdminEnabled $false

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $parsed = $Body | ConvertFrom-Json
                $parsed.futureFlagEnabled -is [bool] -and
                $parsed.futureFlagEnabled -eq $true -and
                $parsed.futureSetting.mode -eq "automatic" -and
                (@($parsed.futureSetting.regions) -join ",") -eq "westeurope,northeurope" -and
                $parsed.futureSetting.PSObject.Properties.Name -notcontains "emptyValue" -and
                $parsed.localAdminEnabled -eq $false
            }
        }

        It "leaves out read-only properties and @odata annotations, but keeps a nested @odata.type" {
            Update-CPCUserSettingsPolicy -Name "UserSettings01" -LocalAdminEnabled $false

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $parsed = $Body | ConvertFrom-Json
                $names = $parsed.PSObject.Properties.Name
                @($names | Where-Object { $_ -in "id", "createdDateTime", "lastModifiedDateTime" -or $_ -like "@odata.*" }).Count -eq 0 -and
                $parsed.crossRegionDisasterRecoverySetting.disasterRecoveryNetworkSetting."@odata.type" -eq "#microsoft.graph.cloudPcDisasterRecoveryMicrosoftHostedNetworkSetting"
            }
        }

        It "keeps <Path> true when -<Parameter> is not passed" -ForEach @(
            @{ Parameter = "LocalAdminEnabled"; Path = @("localAdminEnabled"); Other = @{ ResetEnabled = $false } }
            @{ Parameter = "ResetEnabled"; Path = @("resetEnabled"); Other = @{ LocalAdminEnabled = $false } }
            @{ Parameter = "UserRestoreEnabled"; Path = @("restorePointSetting", "userRestoreEnabled"); Other = @{ UserRestoreFrequency = "6" } }
        ) {
            Update-CPCUserSettingsPolicy -Name "UserSettings01" @Other

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $value = $Body | ConvertFrom-Json
                foreach ($step in $Path) { $value = $value.$step }
                $value -is [bool] -and $value -eq $true
            }
        }

        It "sends <Path> false when -<Parameter> `$false is passed" -ForEach @(
            @{ Parameter = "LocalAdminEnabled"; Path = @("localAdminEnabled") }
            @{ Parameter = "ResetEnabled"; Path = @("resetEnabled") }
            @{ Parameter = "UserRestoreEnabled"; Path = @("restorePointSetting", "userRestoreEnabled") }
        ) {
            $params = @{ Name = "UserSettings01"; $Parameter = $false }
            Update-CPCUserSettingsPolicy @params

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $value = $Body | ConvertFrom-Json
                foreach ($step in $Path) { $value = $value.$step }
                $value -is [bool] -and $value -eq $false
            }
        }

        It "sends the current settings unchanged when only -Name is passed" {
            Update-CPCUserSettingsPolicy -Name "UserSettings01"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $parsed = $Body | ConvertFrom-Json
                (@($parsed.PSObject.Properties.Name | Sort-Object) -join ",") -eq $ExpectedNames -and
                $parsed.localAdminEnabled -eq $true -and
                $parsed.resetEnabled -eq $true -and
                $parsed.restorePointSetting.frequencyType -eq "fourHours" -and
                (& $KeepsDisasterRecovery $parsed)
            }
        }
    }

    Context "crossRegionDisasterRecoveryEnabled for a <Type> policy" -ForEach @(
        @{ Type = "crossRegion"; Expected = $true }
        @{ Type = "premium"; Expected = $true }
        @{ Type = "notConfigured"; Expected = $false }
    ) {

        It "is sent as <Expected>, also when Graph returns the opposite" {
            $policy = $CurrentPolicy.Clone()
            $policy.crossRegionDisasterRecoverySetting = @{
                crossRegionDisasterRecoveryEnabled     = -not $Expected
                disasterRecoveryType                   = $Type
                maintainCrossRegionRestorePointEnabled = $false
                userInitiatedDisasterRecoveryAllowed   = $false
            }
            $Policies = @($policy)

            Update-CPCUserSettingsPolicy -Name "UserSettings01" -LocalAdminEnabled $false

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $dr = ($Body | ConvertFrom-Json).crossRegionDisasterRecoverySetting
                $dr.disasterRecoveryType -eq $Type -and
                $dr.crossRegionDisasterRecoveryEnabled -is [bool] -and
                $dr.crossRegionDisasterRecoveryEnabled -eq $Expected
            }
        }
    }

    Context "Disaster recovery setting without a type" {

        It "leaves crossRegionDisasterRecoverySetting out when Graph returns none" {
            $policy = $CurrentPolicy.Clone()
            $policy.crossRegionDisasterRecoverySetting = $null
            $Policies = @($policy)

            Update-CPCUserSettingsPolicy -Name "UserSettings01" -LocalAdminEnabled $false

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ($Body | ConvertFrom-Json).PSObject.Properties.Name -notcontains "crossRegionDisasterRecoverySetting"
            }
        }
    }

    Context "Output" {

        It "writes nothing to the output" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { [pscustomobject]@{ StatusCode = 204 } }

            $result = Update-CPCUserSettingsPolicy -Name "UserSettings01" -LocalAdminEnabled $false

            $result | Should -BeNullOrEmpty
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly -ParameterFilter { $Method -eq "PATCH" }
        }
    }

    Context "Policy name lookup" {

        It "stops and sends no request when no policy matches (-ErrorAction <ErrorActionValue>)" -ForEach @(
            @{ ErrorActionValue = "Stop" }
            @{ ErrorActionValue = "SilentlyContinue" }
        ) {
            $Policies = @()

            { Update-CPCUserSettingsPolicy -Name "Does Not Exist" -LocalAdminEnabled $true -ErrorAction $ErrorActionValue } |
                Should -Throw -ExpectedMessage "No User Settings Policy found with name 'Does Not Exist'"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "stops and sends no request when two policies have the same name (-ErrorAction <ErrorActionValue>)" -ForEach @(
            @{ ErrorActionValue = "Stop" }
            @{ ErrorActionValue = "SilentlyContinue" }
        ) {
            $Policies = @(
                $CurrentPolicy
                @{ id = "00000000-0000-0000-0000-000000000002"; displayName = "UserSettings01"; localAdminEnabled = $false; resetEnabled = $false }
            )

            { Update-CPCUserSettingsPolicy -Name "UserSettings01" -LocalAdminEnabled $true -ErrorAction $ErrorActionValue } |
                Should -Throw -ExpectedMessage "2 User Settings Policies found with name 'UserSettings01'*"

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly -ParameterFilter { $Uri -eq $PolicyUri }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Graph errors" {

        It "stops and sends no PATCH when reading the policy fails (-ErrorAction <ErrorActionValue>)" -ForEach @(
            @{ ErrorActionValue = "Stop" }
            @{ ErrorActionValue = "SilentlyContinue" }
        ) {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { [string]$Uri -match "/userSettings/00000000-0000-0000-0000-000000000001$" } -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 404 (Not Found).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "ObjectNotFound", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"ResourceNotFound","message":"User setting not found"}}')
                throw $errorRecord
            }

            { Update-CPCUserSettingsPolicy -Name "UserSettings01" -LocalAdminEnabled $true -ErrorAction $ErrorActionValue } |
                Should -Throw -ExpectedMessage "*ResourceNotFound*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "throws the Graph error code when the PATCH fails" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 400 (Bad Request).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"requiredFieldsNotProvided"}}')
                throw $errorRecord
            }

            { Update-CPCUserSettingsPolicy -Name "UserSettings01" -LocalAdminEnabled $true -ErrorAction Stop } |
                Should -Throw -ExpectedMessage "*BadRequest*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
        }
    }

    Context "WhatIf" {

        It "sends no PATCH with -WhatIf" {
            Update-CPCUserSettingsPolicy -Name "UserSettings01" -LocalAdminEnabled $false -WhatIf

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }
}
