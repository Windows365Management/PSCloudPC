<#
This file tests the Set-CPCCrossRegionDisasterRecovery function by using Pester.
Contract: PATCH /deviceManagement/virtualEndpoint/userSettings/{id} with a
crossRegionDisasterRecoverySetting that uses disasterRecoveryType, a Microsoft-hosted network setting with
regionName/regionGroup for crossRegion and premium, and documented cloudPcRegionGroup values.
crossRegionDisasterRecoveryEnabled is deprecated in the docs, but Graph still rejects crossRegion
without it, so it is sent as true for crossRegion/premium and false for notConfigured.
PATCH replaces the whole object, so the cmdlet reads the policy (GET userSettings/{id}) and sends
every other writable setting back unchanged; the deprecated frequencyInHours and the retired
selfServiceEnabled and notificationSetting are never sent.
https://learn.microsoft.com/en-us/graph/api/cloudpcusersetting-update?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/cloudpcusersetting-get?view=graph-rest-beta
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

        # A policy with non-default values everywhere, as GET userSettings/{id} returns it
        $ConfiguredPolicy = @{
            '@odata.context'                   = 'https://graph.microsoft.com/beta/$metadata#deviceManagement/virtualEndpoint/userSettings/$entity'
            id                                 = 'policy-1'
            displayName                        = 'UserSettings01'
            createdDateTime                    = '2026-01-01T00:00:00Z'
            lastModifiedDateTime               = '2026-01-02T00:00:00Z'
            selfServiceEnabled                 = $true
            localAdminEnabled                  = $true
            resetEnabled                       = $true
            provisioningSourceType             = 'image'
            notificationSetting                = @{ restartPromptsDisabled = $true }
            restorePointSetting                = @{ frequencyInHours = 4; frequencyType = 'fourHours'; userRestoreEnabled = $true }
            crossRegionDisasterRecoverySetting = @{
                crossRegionDisasterRecoveryEnabled     = $false
                disasterRecoveryType                   = 'notConfigured'
                maintainCrossRegionRestorePointEnabled = $false
                userInitiatedDisasterRecoveryAllowed   = $false
                disasterRecoveryNetworkSetting         = $null
            }
        }

        # The writable settings of $ConfiguredPolicy that must be sent back unchanged
        $ExpectedUnchanged = @{
            displayName            = 'UserSettings01'
            localAdminEnabled      = $true
            resetEnabled           = $true
            provisioningSourceType = 'image'
        }
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = 'token'
            $script:Authheader = @{ Authorization = 'Bearer token' }
            $script:MSGraphVersion = 'beta'
        }

        # Policies returned by Graph: the name lookup (GET userSettings?$filter=...) returns the list,
        # GET userSettings/{id} returns the matching policy. Tests may replace this list.
        $Policies = @($DefaultPolicy)

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            if ([string]$Uri -match '/userSettings/([^/?]+)$') {
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

        It 'sends disasterRecoveryType and the Microsoft-hosted network setting with regionName/regionGroup' {
            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType $Type -RegionName 'westeurope' -RegionGroup 'europeUnion' -MaintainCrossRegionRestorePointEnabled $true | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $dr = ($Body | ConvertFrom-Json).crossRegionDisasterRecoverySetting
                $dr.disasterRecoveryType -eq $Type -and
                $dr.disasterRecoveryNetworkSetting.'@odata.type' -ceq '#microsoft.graph.cloudPcDisasterRecoveryMicrosoftHostedNetworkSetting' -and
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
        @{ Type = 'notConfigured'; Expected = $false; Params = @{} }
        @{ Type = 'crossRegion'; Expected = $true; Params = @{ RegionName = 'westeurope'; RegionGroup = 'europeUnion' } }
        @{ Type = 'premium'; Expected = $true; Params = @{ RegionName = 'westeurope'; RegionGroup = 'europeUnion' } }
    ) {

        It 'sends crossRegionDisasterRecoveryEnabled as <Expected>' {
            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType $Type @Params | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $dr = ($Body | ConvertFrom-Json).crossRegionDisasterRecoverySetting
                $null -ne $dr -and
                $dr.crossRegionDisasterRecoveryEnabled -is [bool] -and
                $dr.crossRegionDisasterRecoveryEnabled -eq $Expected
            }
        }

        It 'never sends the retired selfServiceEnabled or notificationSetting, also when Graph returns them' {
            $Policies = @($ConfiguredPolicy)

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

    Context 'Read-modify-write: other settings are kept' {
        # PATCH replaces the whole object, so every writable setting must be in the body

        It 'reads the policy by id before the PATCH' {
            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType notConfigured | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq $PatchUri -and $Method -eq 'GET'
            }
        }

        It 'DR on: sends the current settings unchanged plus the crossRegion setting' {
            $Policies = @($ConfiguredPolicy)

            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType crossRegion -RegionName 'westeurope' -RegionGroup 'europeUnion' -MaintainCrossRegionRestorePointEnabled $true | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $parsed = $Body | ConvertFrom-Json
                $dr = $parsed.crossRegionDisasterRecoverySetting
                (@($parsed.PSObject.Properties.Name | Sort-Object) -join ',') -eq 'crossRegionDisasterRecoverySetting,displayName,localAdminEnabled,provisioningSourceType,resetEnabled,restorePointSetting' -and
                @($ExpectedUnchanged.Keys | Where-Object { $parsed.$_ -ne $ExpectedUnchanged[$_] -or $parsed.$_.GetType() -ne $ExpectedUnchanged[$_].GetType() }).Count -eq 0 -and
                (@($parsed.restorePointSetting.PSObject.Properties.Name | Sort-Object) -join ',') -eq 'frequencyType,userRestoreEnabled' -and
                $parsed.restorePointSetting.frequencyType -eq 'fourHours' -and
                $parsed.restorePointSetting.userRestoreEnabled -eq $true -and
                $dr.disasterRecoveryType -eq 'crossRegion' -and
                $dr.crossRegionDisasterRecoveryEnabled -eq $true -and
                $dr.maintainCrossRegionRestorePointEnabled -eq $true -and
                $dr.userInitiatedDisasterRecoveryAllowed -eq $false -and
                $dr.disasterRecoveryNetworkSetting.regionName -eq 'westeurope' -and
                $dr.disasterRecoveryNetworkSetting.regionGroup -eq 'europeUnion'
            }
        }

        It 'DR off: sends the current settings unchanged plus notConfigured' {
            $policy = $ConfiguredPolicy.Clone()
            $policy.crossRegionDisasterRecoverySetting = @{
                crossRegionDisasterRecoveryEnabled     = $true
                disasterRecoveryType                   = 'crossRegion'
                maintainCrossRegionRestorePointEnabled = $true
                userInitiatedDisasterRecoveryAllowed   = $false
                disasterRecoveryNetworkSetting         = @{
                    '@odata.type' = '#microsoft.graph.cloudPcDisasterRecoveryMicrosoftHostedNetworkSetting'
                    regionName    = 'westeurope'
                    regionGroup   = 'europeUnion'
                }
            }
            $Policies = @($policy)

            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType notConfigured | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $parsed = $Body | ConvertFrom-Json
                $dr = $parsed.crossRegionDisasterRecoverySetting
                (@($parsed.PSObject.Properties.Name | Sort-Object) -join ',') -eq 'crossRegionDisasterRecoverySetting,displayName,localAdminEnabled,provisioningSourceType,resetEnabled,restorePointSetting' -and
                @($ExpectedUnchanged.Keys | Where-Object { $parsed.$_ -ne $ExpectedUnchanged[$_] -or $parsed.$_.GetType() -ne $ExpectedUnchanged[$_].GetType() }).Count -eq 0 -and
                $parsed.restorePointSetting.frequencyType -eq 'fourHours' -and
                $parsed.restorePointSetting.userRestoreEnabled -eq $true -and
                (@($dr.PSObject.Properties.Name | Sort-Object) -join ',') -eq 'crossRegionDisasterRecoveryEnabled,disasterRecoveryType,maintainCrossRegionRestorePointEnabled,userInitiatedDisasterRecoveryAllowed' -and
                $dr.disasterRecoveryType -eq 'notConfigured' -and
                $dr.crossRegionDisasterRecoveryEnabled -is [bool] -and
                $dr.crossRegionDisasterRecoveryEnabled -eq $false -and
                $dr.maintainCrossRegionRestorePointEnabled -eq $true -and
                $dr.userInitiatedDisasterRecoveryAllowed -eq $false
            }
        }

        It 'stops and sends no PATCH when reading the policy fails (-ErrorAction <ErrorActionValue>)' -ForEach @(
            @{ ErrorActionValue = 'Stop' }
            @{ ErrorActionValue = 'SilentlyContinue' }
        ) {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { [string]$Uri -match '/userSettings/policy-1$' } -MockWith {
                $exception = [System.Exception]::new('Response status code does not indicate success: 404 (Not Found).')
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, 'GraphError', 'ObjectNotFound', $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"ResourceNotFound","message":"User setting not found"}}')
                throw $errorRecord
            }

            { Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType notConfigured -ErrorAction $ErrorActionValue } |
                Should -Throw -ExpectedMessage '*ResourceNotFound*'

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context 'Disaster recovery options that are not passed keep their current value' {
        # Same class of bug as #156: an option that isn't passed must not be reset to false

        BeforeAll {
            # A premium policy with both options on
            $PremiumPolicy = $ConfiguredPolicy.Clone()
            $PremiumPolicy.crossRegionDisasterRecoverySetting = @{
                crossRegionDisasterRecoveryEnabled     = $true
                disasterRecoveryType                   = 'premium'
                maintainCrossRegionRestorePointEnabled = $true
                userInitiatedDisasterRecoveryAllowed   = $true
                disasterRecoveryNetworkSetting         = @{
                    '@odata.type' = '#microsoft.graph.cloudPcDisasterRecoveryMicrosoftHostedNetworkSetting'
                    regionName    = 'westeurope'
                    regionGroup   = 'europeUnion'
                }
            }
        }

        It 'keeps maintainCrossRegionRestorePointEnabled true when it is not passed (<Type>)' -ForEach @(
            @{ Type = 'notConfigured'; Params = @{} }
            @{ Type = 'crossRegion'; Params = @{ RegionName = 'northeurope'; RegionGroup = 'europeUnion' } }
            @{ Type = 'premium'; Params = @{ RegionName = 'northeurope'; RegionGroup = 'europeUnion' } }
        ) {
            $Policies = @($PremiumPolicy)

            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType $Type @Params | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $dr = ($Body | ConvertFrom-Json).crossRegionDisasterRecoverySetting
                $dr.maintainCrossRegionRestorePointEnabled -is [bool] -and
                $dr.maintainCrossRegionRestorePointEnabled -eq $true
            }
        }

        It 'sends maintainCrossRegionRestorePointEnabled false when -MaintainCrossRegionRestorePointEnabled $false is passed (<Type>)' -ForEach @(
            @{ Type = 'notConfigured'; Params = @{} }
            @{ Type = 'crossRegion'; Params = @{ RegionName = 'northeurope'; RegionGroup = 'europeUnion' } }
            @{ Type = 'premium'; Params = @{ RegionName = 'northeurope'; RegionGroup = 'europeUnion' } }
        ) {
            $Policies = @($PremiumPolicy)

            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType $Type @Params -MaintainCrossRegionRestorePointEnabled $false | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $dr = ($Body | ConvertFrom-Json).crossRegionDisasterRecoverySetting
                $dr.maintainCrossRegionRestorePointEnabled -is [bool] -and
                $dr.maintainCrossRegionRestorePointEnabled -eq $false
            }
        }

        It 'keeps userInitiatedDisasterRecoveryAllowed true for premium when it is not passed' {
            $Policies = @($PremiumPolicy)

            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType premium -RegionName 'northeurope' -RegionGroup 'europeUnion' | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $dr = ($Body | ConvertFrom-Json).crossRegionDisasterRecoverySetting
                $dr.disasterRecoveryType -eq 'premium' -and
                $dr.crossRegionDisasterRecoveryEnabled -eq $true -and
                $dr.userInitiatedDisasterRecoveryAllowed -is [bool] -and
                $dr.userInitiatedDisasterRecoveryAllowed -eq $true -and
                $dr.disasterRecoveryNetworkSetting.regionName -eq 'northeurope'
            }
        }

        It 'sends userInitiatedDisasterRecoveryAllowed false for premium when -UserInitiatedDisasterRecoveryAllowed $false is passed' {
            $Policies = @($PremiumPolicy)

            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType premium -RegionName 'northeurope' -RegionGroup 'europeUnion' -UserInitiatedDisasterRecoveryAllowed $false | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $dr = ($Body | ConvertFrom-Json).crossRegionDisasterRecoverySetting
                $dr.userInitiatedDisasterRecoveryAllowed -is [bool] -and
                $dr.userInitiatedDisasterRecoveryAllowed -eq $false
            }
        }

        It 'sends userInitiatedDisasterRecoveryAllowed false for <Type>, because only premium supports it' -ForEach @(
            @{ Type = 'notConfigured'; Params = @{} }
            @{ Type = 'crossRegion'; Params = @{ RegionName = 'northeurope'; RegionGroup = 'europeUnion' } }
        ) {
            $Policies = @($PremiumPolicy)

            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType $Type @Params | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $dr = ($Body | ConvertFrom-Json).crossRegionDisasterRecoverySetting
                $dr.userInitiatedDisasterRecoveryAllowed -is [bool] -and
                $dr.userInitiatedDisasterRecoveryAllowed -eq $false
            }
        }

        It 'does not send maintainCrossRegionRestorePointEnabled when the policy has none and it is not passed' {
            $policy = $ConfiguredPolicy.Clone()
            $policy.crossRegionDisasterRecoverySetting = $null
            $Policies = @($policy)

            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType crossRegion -RegionName 'northeurope' -RegionGroup 'europeUnion' | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $dr = ($Body | ConvertFrom-Json).crossRegionDisasterRecoverySetting
                (@($dr.PSObject.Properties.Name | Sort-Object) -join ',') -eq 'crossRegionDisasterRecoveryEnabled,disasterRecoveryNetworkSetting,disasterRecoveryType,userInitiatedDisasterRecoveryAllowed' -and
                $dr.crossRegionDisasterRecoveryEnabled -eq $true
            }
        }

        It 'replaces the network setting with the passed region' {
            $Policies = @($PremiumPolicy)

            Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType crossRegion -RegionName 'northeurope' -RegionGroup 'europeUnion' | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $network = ($Body | ConvertFrom-Json).crossRegionDisasterRecoverySetting.disasterRecoveryNetworkSetting
                (@($network.PSObject.Properties.Name | Sort-Object) -join ',') -eq '@odata.type,regionGroup,regionName' -and
                $network.'@odata.type' -ceq '#microsoft.graph.cloudPcDisasterRecoveryMicrosoftHostedNetworkSetting' -and
                $network.regionName -eq 'northeurope' -and
                $network.regionGroup -eq 'europeUnion'
            }
        }
    }

    Context 'RegionGroup is passed to Graph as is' {

        It 'has no ValidateSet on -RegionGroup, so new region groups need no module update' {
            $attributes = (Get-Command -Name Set-CPCCrossRegionDisasterRecovery).Parameters['RegionGroup'].Attributes
            @($attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }).Count | Should -Be 0
        }

        It 'sends region group "<Group>" unchanged' -ForEach @(
            @{ Group = 'europeUnion' }
            @{ Group = 'usEast' }
            @{ Group = 'germany' }
            @{ Group = 'someFutureRegionGroup' }
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

            { Set-CPCCrossRegionDisasterRecovery -Name 'UserSettings01' -DisasterRecoveryType crossRegion -RegionName 'westeurope' -RegionGroup 'europeUnion' -ErrorAction Stop } |
                Should -Throw -ExpectedMessage '*BadRequest*'

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
        }
    }
}
