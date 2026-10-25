<#
This file tests Cloud PC action cmdlets by using Pester.
Contract: when the Cloud PC is not found the cmdlet stops with a terminating error before any request is
sent (also with -ErrorAction SilentlyContinue), and never POSTs to cloudPCs//{action} with an empty id.
Invoke-CPCEndGracePeriod supports -WhatIf and -Force; Disconnect-Windows365 honours -WhatIf.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../PSCloudPc/PSCloudPC.psd1') -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe 'Cloud PC action cmdlets' {

    BeforeAll {
        $CloudPCId = '00000000-0000-0000-0000-0000000000c1'
        $CloudPCsUri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs'
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = 'token'
            $script:Authheader = @{ Authorization = 'Bearer token' }
            $script:MSGraphVersion = 'beta'
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { }
    }

    Context 'Cloud PC not found' {

        BeforeEach {
            Mock -ModuleName PSCloudPC Get-CloudPC -MockWith { }
        }

        It '<Command> stops and sends no request' -ForEach @(
            @{ Command = 'Invoke-CPCReboot'; Params = @{ Name = 'Missing' } }
            @{ Command = 'Invoke-CPCRename'; Params = @{ Name = 'Missing'; NewDisplayName = 'New' } }
            @{ Command = 'Invoke-CPCTroubleshoot'; Params = @{ Name = 'Missing' } }
            @{ Command = 'Invoke-CPCCreateSnapshot'; Params = @{ Name = 'Missing' } }
            @{ Command = 'Invoke-CPCReprovision'; Params = @{ Name = 'Missing' } }
            @{ Command = 'Invoke-CPCResize'; Params = @{ Name = 'Missing'; ServicePlanId = 'plan' } }
            @{ Command = 'Invoke-CPCRestore'; Params = @{ Name = 'Missing'; SnapshotId = 'snap' } }
            @{ Command = 'Get-CPCRestorePoint'; Params = @{ Name = 'Missing' } }
        ) {
            { & $Command @Params -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "No Cloud PC found with name 'Missing'*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context 'Cloud PC found' {

        BeforeEach {
            Mock -ModuleName PSCloudPC Get-CloudPC -MockWith {
                [pscustomobject]@{ id = $CloudPCId; displayName = 'CPC-TEST-01'; managedDeviceName = 'CPC-TEST-01'; status = 'provisioned' }
            }
        }

        It 'Invoke-CPCReboot posts to the reboot action and honours -WhatIf' {
            Invoke-CPCReboot -Name 'CPC-TEST-01' -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly

            Invoke-CPCReboot -Name 'CPC-TEST-01' | Out-Null
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq "$CloudPCsUri/$CloudPCId/reboot" -and $Method -eq 'POST'
            }
        }

        It 'Invoke-CPCRename posts the new displayName' {
            Invoke-CPCRename -Name 'CPC-TEST-01' -NewDisplayName 'Renamed'

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq "$CloudPCsUri/$CloudPCId/rename" -and ($Body | ConvertFrom-Json).displayName -eq 'Renamed'
            }
        }

        It 'Invoke-CPCRestore posts the snapshot id without the interactive selector' {
            Invoke-CPCRestore -Name 'CPC-TEST-01' -SnapshotId 'snap-1'

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq "$CloudPCsUri/$CloudPCId/restore" -and ($Body | ConvertFrom-Json).cloudPcSnapshotId -eq 'snap-1'
            }
        }

        It 'uses the first Cloud PC with a warning when several share the name' {
            Mock -ModuleName PSCloudPC Get-CloudPC -MockWith {
                [pscustomobject]@{ id = $CloudPCId; displayName = 'CPC-TEST-01' }
                [pscustomobject]@{ id = 'other'; displayName = 'CPC-TEST-01' }
            }

            Invoke-CPCTroubleshoot -Name 'CPC-TEST-01' -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

            $warnings | Should -Not -BeNullOrEmpty
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq "$CloudPCsUri/$CloudPCId/troubleshoot"
            }
        }
    }

    Context 'Invoke-CPCEndGracePeriod' {

        BeforeEach {
            Mock -ModuleName PSCloudPC Get-CloudPC -MockWith {
                $all = @(
                    [pscustomobject]@{ id = $CloudPCId; displayName = 'CPC-TEST-01'; managedDeviceName = 'CPC-TEST-01'; status = 'inGracePeriod' }
                    [pscustomobject]@{ id = 'c2'; displayName = 'CPC-TEST-02'; managedDeviceName = 'CPC-TEST-02'; status = 'provisioned' }
                )
                if ($Name) { $all | Where-Object { $_.managedDeviceName -eq $Name } } else { $all }
            }
        }

        It 'posts endGracePeriod only for Cloud PCs in their grace period with -Force' {
            Invoke-CPCEndGracePeriod -All -Force | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq "$CloudPCsUri/$CloudPCId/endGracePeriod" -and $Method -eq 'POST'
            }
        }

        It 'sends nothing with -WhatIf' {
            Invoke-CPCEndGracePeriod -All -WhatIf

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It 'stops when the named Cloud PC is not in its grace period' {
            { Invoke-CPCEndGracePeriod -Name 'CPC-TEST-02' -Force -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage 'No CloudPC found in grace period with name CPC-TEST-02*'

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context 'Disconnect-Windows365' {

        It 'keeps the token with -WhatIf and clears it without' {
            Mock -ModuleName PSCloudPC Disconnect-MgGraph -MockWith { }
            Mock -ModuleName PSCloudPC Get-MgContext -MockWith { }

            Disconnect-Windows365 -WhatIf
            InModuleScope PSCloudPC { $script:Authtoken } | Should -Be 'token'

            Disconnect-Windows365 -Confirm:$false
            InModuleScope PSCloudPC { $script:Authtoken } | Should -BeNullOrEmpty
        }
    }
}
