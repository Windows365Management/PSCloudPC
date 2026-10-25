<#
This file tests the Azure Network Connection cmdlets by using Pester.
Contract (cloudPcOnPremisesConnection): type is deprecated and stopped returning data on January 31, 2024;
connectionType replaces it. adDomainPassword is sent as plain text. subscriptionName is read-only.
https://learn.microsoft.com/en-us/graph/api/resources/cloudpconpremisesconnection?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/virtualendpoint-post-onpremisesconnections?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/cloudpconpremisesconnection-update?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../PSCloudPc/PSCloudPC.psd1') -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe 'Azure Network Connection cmdlets' {

    BeforeAll {
        $ListUri = 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/onPremisesConnections'
        $ConnectionId = '00000000-0000-0000-0000-0000000000a1'
        $Password = ConvertTo-SecureString 'Pl@inText!' -AsPlainText -Force
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = 'token'
            $script:Authheader = @{ Authorization = 'Bearer token' }
            $script:MSGraphVersion = 'beta'
        }
    }

    Context 'Get-CPCAzureNetworkConnection' {

        It 'returns connectionType and follows every page' {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { [string]$Uri -like '*skiptoken*' } -MockWith {
                [pscustomobject]@{ Content = (@{ value = @(@{ id = 'b'; displayName = 'ANC-B'; connectionType = 'hybridAzureADJoin'; healthCheckStatus = 'passed' }) } | ConvertTo-Json -Depth 5) }
            }
            Mock -ModuleName PSCloudPC Invoke-WebRequest -ParameterFilter { [string]$Uri -notlike '*skiptoken*' } -MockWith {
                [pscustomobject]@{ Content = (@{
                            '@odata.nextLink' = "$ListUri`?`$skiptoken=page2"
                            value             = @(@{ id = 'a'; displayName = 'ANC-A'; connectionType = 'azureADJoin'; healthCheckStatus = 'warning' })
                        } | ConvertTo-Json -Depth 5) }
            }

            $result = @(Get-CPCAzureNetworkConnection)

            $result.Count | Should -Be 2
            $result[0].connectionType | Should -Be 'azureADJoin'
            # type is kept for scripts that read it and holds the connectionType
            $result[0].type | Should -Be 'azureADJoin'
            $result[1].connectionType | Should -Be 'hybridAzureADJoin'
        }

        It 'escapes a single quote in the name filter' {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith { [pscustomobject]@{ Content = '{"value":[]}' } }

            Get-CPCAzureNetworkConnection -Name "O'Brien" | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                [string]$Uri -like "*displayName+eq+'O%27%27Brien'"
            }
        }
    }

    Context 'New-CPCAzureNetworkConnection' {

        BeforeEach {
            Mock -ModuleName PSCloudPC Get-CPCAzureNetworkConnection -MockWith { }
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith { [pscustomobject]@{ Content = '{}' } }
        }

        It 'sends connectionType azureADJoin and no domain join or read-only properties' {
            New-CPCAzureNetworkConnection -Name 'ANC01' -ResourceGroupId '/subscriptions/s/resourceGroups/rg' -VirtualNetworkId '/vnet' -SubnetId '/subnet' -SubscriptionId 's' | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $json = $Body | ConvertFrom-Json
                $Uri -eq $ListUri -and
                $Method -eq 'POST' -and
                $json.connectionType -eq 'azureADJoin' -and
                $json.displayName -eq 'ANC01' -and
                $json.PSObject.Properties.Name -notcontains 'subscriptionName' -and
                $json.PSObject.Properties.Name -notcontains 'adDomainPassword'
            }
        }

        It 'sends connectionType hybridAzureADJoin with the plain text domain password' {
            New-CPCAzureNetworkConnection -Name 'ANC01' -ResourceGroupId '/rg' -VirtualNetworkId '/vnet' -SubnetId '/subnet' -SubscriptionId 's' -AdDomainName 'contoso.com' -AdDomainUserName 'join@contoso.com' -AdDomainPassword $Password -OrganizationalUnit 'OU=CPC,DC=contoso,DC=com' | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $json = $Body | ConvertFrom-Json
                $json.connectionType -eq 'hybridAzureADJoin' -and
                $json.adDomainPassword -ceq 'Pl@inText!' -and
                $json.adDomainUsername -eq 'join@contoso.com' -and
                $json.organizationalUnit -eq 'OU=CPC,DC=contoso,DC=com'
            }
        }

        It 'stops when a connection with the name exists' {
            Mock -ModuleName PSCloudPC Get-CPCAzureNetworkConnection -MockWith { [pscustomobject]@{ id = $ConnectionId; displayName = 'ANC01' } }

            { New-CPCAzureNetworkConnection -Name 'ANC01' -ResourceGroupId '/rg' -VirtualNetworkId '/vnet' -SubnetId '/subnet' -SubscriptionId 's' -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage '*already exists*'

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context 'Update-CPCAzureNetworkConnection' {

        BeforeEach {
            Mock -ModuleName PSCloudPC Get-CPCAzureNetworkConnection -MockWith {
                [pscustomobject]@{ id = $ConnectionId; displayName = 'ANC01'; connectionType = 'hybridAzureADJoin' }
            }
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith { [pscustomobject]@{ Content = '{}' } }
        }

        It 'sends the domain password as plain text' {
            Update-CPCAzureNetworkConnection -Name 'ANC01' -AdDomainPassword $Password | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $json = $Body | ConvertFrom-Json
                $Uri -eq "$ListUri/$ConnectionId" -and
                $Method -eq 'PATCH' -and
                $json.adDomainPassword -ceq 'Pl@inText!' -and
                @($json.PSObject.Properties).Count -eq 1
            }
        }

        It 'stops when more than one connection has the name' {
            Mock -ModuleName PSCloudPC Get-CPCAzureNetworkConnection -MockWith {
                [pscustomobject]@{ id = 'a'; displayName = 'ANC01' }
                [pscustomobject]@{ id = 'b'; displayName = 'ANC01' }
            }

            { Update-CPCAzureNetworkConnection -Name 'ANC01' -DisplayName 'ANC02' -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage '2 Azure Network Connections found*'

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }
}
