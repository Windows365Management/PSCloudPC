<#
This file tests read cmdlets that map Graph responses by using Pester.
- Get-CPCRealTimeConnectionStatus: the report is a table (Schema + Values); each row becomes an object.
- Get-CPCRemoteActionResult: statusDetail replaces the deprecated statusDetails.
- Get-CPCGalleryImage: displayName and the *Name properties replace the deprecated *DisplayName/recommendedSku.
- Get-CPCAuditEvent: without -Top every page is read, with -Top only one request is sent.
- New-CPCUserSettingsPolicy: restorePointSetting.frequencyType replaces the deprecated frequencyInHours.
https://learn.microsoft.com/en-us/graph/api/cloudpcreports-getrealtimeremoteconnectionstatus?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpcremoteactionresult?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpcgalleryimage?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/virtualendpoint-list-auditevents?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/virtualendpoint-post-usersettings?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../PSCloudPc/PSCloudPC.psd1') -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe 'Response mapping' {

    BeforeAll {
        $CloudPCId = '00000000-0000-0000-0000-0000000000c1'
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = 'token'
            $script:Authheader = @{ Authorization = 'Bearer token' }
            $script:MSGraphVersion = 'beta'
        }
    }

    Context 'Get-CPCRealTimeConnectionStatus' {

        It 'maps the Schema columns onto every Values row' {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                [pscustomobject]@{
                    TotalRowCount = 1
                    Schema        = @(
                        [pscustomobject]@{ Column = 'CloudPcId'; PropertyType = 'String' }
                        [pscustomobject]@{ Column = 'ManagedDeviceName'; PropertyType = 'String' }
                        [pscustomobject]@{ Column = 'SignInStatus'; PropertyType = 'String' }
                        [pscustomobject]@{ Column = 'DaysSinceLastSignIn'; PropertyType = 'Int64' }
                    )
                    Values        = @(, @($CloudPCId, 'CPC-TEST-01', 'SignedIn', 0))
                }
            }

            $result = @(Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPCId)

            $result.Count | Should -Be 1
            $result[0].CloudPcId | Should -Be $CloudPCId
            $result[0].ManagedDeviceName | Should -Be 'CPC-TEST-01'
            $result[0].SignInStatus | Should -Be 'SignedIn'
            $result[0].DaysSinceLastSignIn | Should -Be 0

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Uri -eq "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/reports/getRealTimeRemoteConnectionStatus(cloudPcId='$CloudPCId')"
            }
        }

        It 'parses the report when it comes back as text (application/octet-stream)' {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                '{"TotalRowCount":1,"Schema":[{"Column":"CloudPcId","PropertyType":"String"},{"Column":"SignInStatus","PropertyType":"String"}],"Values":[["' + $CloudPCId + '","SignedOut"]]}'
            }

            $result = @(Get-CPCRealTimeConnectionStatus -CloudPCId $CloudPCId)

            $result[0].SignInStatus | Should -Be 'SignedOut'
        }
    }

    Context 'Get-CPCRemoteActionResult' {

        It 'returns statusDetail and falls back to the deprecated statusDetails' {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                [pscustomobject]@{
                    value = @(
                        [pscustomobject]@{ actionName = 'Reboot'; actionState = 'failed'; statusDetail = [pscustomobject]@{ code = 'x' }; statusDetails = $null }
                        [pscustomobject]@{ actionName = 'Rename'; actionState = 'done'; statusDetail = $null; statusDetails = [pscustomobject]@{ code = 'old' } }
                    )
                }
            }

            $result = @(Get-CPCRemoteActionResult -CloudPCId $CloudPCId)

            $result[0].statusDetail.code | Should -Be 'x'
            $result[1].statusDetail.code | Should -Be 'old'
            $result[0].PSObject.Properties.Name | Should -Not -Contain 'statusDetails'
        }
    }

    Context 'Get-CPCGalleryImage' {

        It 'returns displayName and the current image name properties' {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                [pscustomobject]@{ Content = (@{ value = @(@{
                                    id = 'microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc'
                                    displayName = 'Windows 11 Enterprise 25H2'
                                    publisherName = 'microsoftwindowsdesktop'; offerName = 'windows-ent-cpc'; skuName = 'win11-25h2-ent-cpc'
                                    status = 'supported'; startDate = '2025-10-14'; endDate = '2027-10-14'; expirationDate = '2028-04-14'
                                }) } | ConvertTo-Json -Depth 5) }
            }

            $result = @(Get-CPCGalleryImage)

            $result[0].displayName | Should -Be 'Windows 11 Enterprise 25H2'
            $result[0].skuName | Should -Be 'win11-25h2-ent-cpc'
            $result[0].expirationDate | Should -Be '2028-04-14'
        }
    }

    Context 'Get-CPCAuditEvent' {

        BeforeEach {
            $AuditUri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/auditEvents'
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { [string]$Uri -like '*skiptoken*' } -MockWith {
                [pscustomobject]@{ Content = (@{ value = @(@{ id = 'b'; activityType = 'Patch CloudPcUserSetting' }) } | ConvertTo-Json -Depth 5) }
            }
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { [string]$Uri -notlike '*skiptoken*' } -MockWith {
                [pscustomobject]@{ Content = (@{
                            '@odata.nextLink' = "$AuditUri`?`$skiptoken=page2"
                            value             = @(@{ id = 'a'; activityType = 'Create CloudPcProvisioningPolicy' })
                        } | ConvertTo-Json -Depth 5) }
            }
        }

        It 'reads every page when -Top is not passed' {
            $result = @(Get-CPCAuditEvent)

            $result.Count | Should -Be 2
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 2 -Exactly
        }

        It 'sends one request with $top and does not follow the nextLink when -Top is passed' {
            $result = @(Get-CPCAuditEvent -Top 25)

            $result.Count | Should -Be 1
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter { [string]$Uri -like "*`$top=25" }
        }
    }

    Context 'New-CPCUserSettingsPolicy' {

        It 'sends frequencyType instead of the deprecated frequencyInHours' {
            Mock -ModuleName PSCloudPC Get-CPCUserSettingsPolicy -MockWith { }
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { }

            New-CPCUserSettingsPolicy -Name 'US01' -LocalAdminEnabled $true -UserRestoreEnabled $true -FrequencyInHours 16 | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $json = $Body | ConvertFrom-Json
                $Method -eq 'POST' -and
                $json.displayName -eq 'US01' -and
                $json.localAdminEnabled -eq $true -and
                $json.restorePointSetting.frequencyType -eq 'sixteenHours' -and
                $json.restorePointSetting.userRestoreEnabled -eq $true -and
                $json.restorePointSetting.PSObject.Properties.Name -notcontains 'frequencyInHours'
            }
        }
    }
}
