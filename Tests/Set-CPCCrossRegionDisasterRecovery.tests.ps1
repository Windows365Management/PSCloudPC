<#
This file tests the Set-CPCCrossRegionDisasterRecovery function by using Pester.
Contract: PATCH /deviceManagement/virtualEndpoint/userSettings/{id} with a
crossRegionDisasterRecoverySetting that uses disasterRecoveryType plus the deprecated
crossRegionDisasterRecoveryEnabled, which Graph still requires ($true for crossRegion and
premium, $false for notConfigured), a Microsoft-hosted network setting with
regionName/regionGroup for crossRegion and premium, and documented cloudPcRegionGroup values.
The policy's current restorePointSetting (frequencyType, userRestoreEnabled) is sent back
unchanged; the deprecated frequencyInHours is never sent.
https://learn.microsoft.com/en-us/graph/api/cloudpcusersetting-update?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpccrossregiondisasterrecoverysetting?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpcregiongroup?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpcrestorepointsetting?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../PSCloudPc/PSCloudPC.psd1') -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe 'Set-CPCCrossRegionDisasterRecovery' {

    BeforeAll {
        $PatchUri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/userSettings/policy-1'

        $DefaultPolicy = @{
            id                                 = 'policy-1'
            displayName                        = 'UserSettings01'
            selfServiceEnabled                 = $false
            localAdminEnabled                  = $false
            resetEnabled                       = $true
            restorePointSetting                = @{ frequencyInHours = 12; frequencyType = 'twelveHours'; userRestoreEnabled = $true }
            crossRegionDisasterRecoverySetting = @{ disasterRecoveryType = 'notConfigured'; maintainCrossRegionRestorePointEnabled = $false; userInitiatedDisasterRecoveryAllowed = $false }
        }
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = 'token'
            $script:Authheader = @{ Authorization = 'Bearer token' }
            $script:MSGraphVersion = 'beta'
        }

        # Policies returned by the userSettings lookup (Graph GET). Tests may replace this list.
        $Policies = @($DefaultPolicy)

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            [pscustomobject]@{ Content = (@{ value = @($Policies) } | ConvertTo-Json -Depth 10) }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { }
    }

    Context 'Disaster recovery type <Type>' -ForEach @(
        @{ Type = 'crossRegion' }
        @{ Type = 'premium' }
    ) {

        It 'PATCHes exactly one userSettings id' {
            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType $Type -RegionName 'westeurope' -RegionGroup 'europeUnion' | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq $PatchUri -and $Method -eq 'PATCH'
            }
        }

        It 'sends disasterRecoveryType and the network setting with regionName/regionGroup' {
            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType $Type -RegionName 'westeurope' -RegionGroup 'europeUnion' -MaintainCrossRegionRestorePointEnabled $true | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $dr = ($Body | ConvertFrom-Json).crossRegionDisasterRecoverySetting
                $dr.disasterRecoveryType -eq $Type -and
                $dr.disasterRecoveryNetworkSetting.regionName -eq 'westeurope' -and
                $dr.disasterRecoveryNetworkSetting.regionGroup -eq 'europeUnion' -and
                $dr.maintainCrossRegionRestorePointEnabled -is [bool] -and
                $dr.maintainCrossRegionRestorePointEnabled -eq $true
            }
        }

        It 'errors and sends no PATCH when <Missing> is missing' -ForEach @(
            @{ Missing = 'RegionName'; Params = @{ RegionGroup = 'europeUnion' } }
            @{ Missing = 'RegionGroup'; Params = @{ RegionName = 'westeurope' } }
        ) {
            { Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType $Type @Params -ErrorAction Stop } | Should -Throw

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0
        }
    }

    Context 'Premium user-initiated failover' {

        It 'sends userInitiatedDisasterRecoveryAllowed as a boolean' {
            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType premium -RegionName 'westeurope' -RegionGroup 'europeUnion' -UserInitiatedDisasterRecoveryAllowed $true | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $dr = ($Body | ConvertFrom-Json).crossRegionDisasterRecoverySetting
                $dr.userInitiatedDisasterRecoveryAllowed -is [bool] -and
                $dr.userInitiatedDisasterRecoveryAllowed -eq $true
            }
        }
    }

    Context 'notConfigured' {

        It 'sends disasterRecoveryType notConfigured explicitly' {
            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType notConfigured | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq $PatchUri -and
                $Method -eq 'PATCH' -and
                ($Body | ConvertFrom-Json).crossRegionDisasterRecoverySetting.disasterRecoveryType -eq 'notConfigured'
            }
        }
    }

    Context 'Deprecated and unrelated properties (<Type>)' -ForEach @(
        @{ Type = 'notConfigured'; Params = @{}; Enabled = $false }
        @{ Type = 'crossRegion'; Params = @{ RegionName = 'westeurope'; RegionGroup = 'europeUnion' }; Enabled = $true }
        @{ Type = 'premium'; Params = @{ RegionName = 'westeurope'; RegionGroup = 'europeUnion' }; Enabled = $true }
    ) {

        It 'sends crossRegionDisasterRecoveryEnabled as <Enabled>, which Graph still requires' {
            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType $Type @Params | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $dr = ($Body | ConvertFrom-Json).crossRegionDisasterRecoverySetting
                $null -ne $dr -and
                $dr.PSObject.Properties.Name -ccontains 'crossRegionDisasterRecoveryEnabled' -and
                $dr.crossRegionDisasterRecoveryEnabled -eq $Enabled
            }
        }

        It 'never sends selfServiceEnabled or notificationSetting' {
            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType $Type @Params | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $names = ($Body | ConvertFrom-Json).PSObject.Properties.Name
                $names -notcontains 'selfServiceEnabled' -and
                $names -notcontains 'notificationSetting'
            }
        }

        It 'never sends restorePointSetting.frequencyInHours' {
            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType $Type @Params | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $rp = ($Body | ConvertFrom-Json).restorePointSetting
                $null -eq $rp -or $rp.PSObject.Properties.Name -notcontains 'frequencyInHours'
            }
        }

        It 'does not send a restorePointSetting with null values when the policy has none' {
            $Policies = @(@{
                    id                 = 'policy-1'
                    displayName        = 'UserSettings01'
                    localAdminEnabled  = $false
                    resetEnabled       = $false
                    restorePointSetting = $null
                })

            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType $Type @Params | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $parsed = $Body | ConvertFrom-Json
                $rp = $parsed.restorePointSetting
                ($parsed.PSObject.Properties.Name -notcontains 'restorePointSetting') -or
                ($null -ne $rp -and @($rp.PSObject.Properties | Where-Object { $null -eq $_.Value }).Count -eq 0)
            }
        }

        It 'sends the current restorePointSetting values back unchanged, without frequencyInHours' {
            $Policies = @(@{
                    id                  = 'policy-1'
                    displayName         = 'UserSettings01'
                    localAdminEnabled   = $false
                    resetEnabled        = $false
                    restorePointSetting = @{ frequencyInHours = 6; frequencyType = 'sixHours'; userRestoreEnabled = $true }
                })

            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType $Type @Params | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $rp = ($Body | ConvertFrom-Json).restorePointSetting
                $null -ne $rp -and
                (@($rp.PSObject.Properties.Name | Sort-Object) -join ',') -eq 'frequencyType,userRestoreEnabled' -and
                $rp.frequencyType -eq 'sixHours' -and
                $rp.userRestoreEnabled -is [bool] -and
                $rp.userRestoreEnabled -eq $true
            }
        }
    }

    Context 'RegionGroup validation' {

        It 'rejects undocumented region group "<Group>" and sends no PATCH' -ForEach @(
            @{ Group = 'europeNorth' }
            @{ Group = 'europeWest' }
            @{ Group = 'asiaPacific' }
        ) {
            { Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType crossRegion -RegionName 'westeurope' -RegionGroup $Group -ErrorAction Stop } | Should -Throw

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0
        }

        It 'accepts documented region group "<Group>"' -ForEach @(
            @{ Group = 'europeUnion' }
            @{ Group = 'usEast' }
            @{ Group = 'germany' }
        ) {
            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType crossRegion -RegionName 'westeurope' -RegionGroup $Group | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ($Body | ConvertFrom-Json).crossRegionDisasterRecoverySetting.disasterRecoveryNetworkSetting.regionGroup -eq $Group
            }
        }
    }

    Context 'Policy name lookup' {

        It 'errors and sends no PATCH when no policy matches' {
            $Policies = @()

            { Set-CPCCrossRegionDisasterRecovery -Name 'Does Not Exist' -DisasterRecoveryType notConfigured -ErrorAction Stop } | Should -Throw

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0
        }

        It 'errors and sends no PATCH when two policies have the same name' {
            $Policies = @(
                $DefaultPolicy
                @{ id = 'policy-2'; displayName = 'UserSettings01'; localAdminEnabled = $false; resetEnabled = $false }
            )

            { Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType notConfigured -ErrorAction Stop } | Should -Throw

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0
        }
    }

    Context 'Guards with -ErrorAction SilentlyContinue' {
        # A Throw in begin is skipped with SilentlyContinue and process would still PATCH; the guards must still stop.

        It 'still throws and sends no PATCH when no policy matches' {
            $Policies = @()

            { Set-CPCCrossRegionDisasterRecovery -Name 'Does Not Exist' -DisasterRecoveryType notConfigured -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "No User Settings Policy found with name 'Does Not Exist'"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It 'still throws and sends no PATCH when two policies have the same name' {
            $Policies = @(
                $DefaultPolicy
                @{ id = 'policy-2'; displayName = 'UserSettings01'; localAdminEnabled = $false; resetEnabled = $false }
            )

            { Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType notConfigured -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "2 User Settings Policies found with name 'UserSettings01'*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It 'still throws and sends no PATCH for crossRegion without RegionName' {
            { Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType crossRegion -RegionGroup 'europeUnion' -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "RegionName and RegionGroup are required when DisasterRecoveryType is 'crossRegion'"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context 'WhatIf' {

        It 'sends no PATCH with -WhatIf' {
            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType crossRegion -RegionName 'westeurope' -RegionGroup 'europeUnion' -WhatIf | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0
        }
    }

    Context 'Graph error' {

        It 'throws when the PATCH fails' {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                $exception = [System.Exception]::new('Response status code does not indicate success: 400 (Bad Request).')
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, 'GraphError', 'InvalidOperation', $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"Invalid disaster recovery setting"}}')
                throw $errorRecord
            }

            { Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType crossRegion -RegionName 'westeurope' -RegionGroup 'europeUnion' -ErrorAction Stop } | Should -Throw

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
        }
    }
}
