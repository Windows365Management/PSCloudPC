<#
This file tests the New-CPCProvisioningPolicy function by using Pester.
Contract: POST /deviceManagement/virtualEndpoint/provisioningPolicies with only current properties:
windowsSetting.locale (not the deprecated windowsSettings), domainJoinConfigurations[].domainJoinType (not the
deprecated type), microsoftManagedDesktop.managedType (not the deprecated type) and no userSettingsPersistenceEnabled
(not a property of cloudPcProvisioningPolicy). A Microsoft-hosted network sends regionName (regionGroup is
read-only and only sent when passed); an Azure network connection sends onPremisesConnectionId and no regionName,
with domainJoinType from the connection's connectionType (GET onPremisesConnections, not the retired type).
Health checks passed/warning/informational are accepted; failed/pending/running stop. Policy GETs send
Prefer: include-unknown-enum-members, and so does the POST for the shared provisioning types. The created policy
is read back (GET provisioningPolicies/{id}) and returned.
https://learn.microsoft.com/en-us/graph/api/virtualendpoint-post-provisioningpolicies?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpcprovisioningpolicy?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpcdomainjoinconfiguration?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpcwindowssetting?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/microsoftmanageddesktop?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpconpremisesconnection?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/best-practices-concept#handling-future-members-in-evolvable-enumerations
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "New-CPCProvisioningPolicy" {

    BeforeAll {
        $PostUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies"
        $ImageId = "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc"
        $PolicyId = "00000000-0000-0000-0000-000000000001"
        $ConnectionId1 = "00000000-0000-0000-0000-0000000000c1"
        $ConnectionId2 = "00000000-0000-0000-0000-0000000000c2"
        $AutopatchGroupId = "00000000-0000-0000-0000-0000000000a1"

        $EntraJoin = @{
            Name               = "Test-Policy"
            Description        = "Test description"
            ImageType          = "Gallery"
            ImageId            = $ImageId
            DomainJoinType     = "azureADJoin"
            EnableSingleSignOn = $true
            RegionName         = "westeurope"
            RegionGroup        = "europeUnion"
            Language           = "en-US"
        }

        $HybridJoin = @{
            Name                   = "Test-Hybrid"
            ImageId                = $ImageId
            DomainJoinType         = "hybridAzureADJoin"
            AzureNetworkConnection = "ANC-Hybrid-1"
        }
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        # Policies returned by the duplicate name check (Graph GET). Tests may replace this list.
        $Existing = @()

        # Azure network connections as Graph returns them (connectionType, not the retired type). Tests may replace this list.
        $Connections = @(
            [pscustomobject]@{ id = $ConnectionId1; displayName = "ANC-Hybrid-1"; connectionType = "hybridAzureADJoin"; healthCheckStatus = "passed" }
            [pscustomobject]@{ id = $ConnectionId2; displayName = "ANC-Hybrid-2"; connectionType = "hybridAzureADJoin"; healthCheckStatus = "passed" }
            [pscustomobject]@{ id = "00000000-0000-0000-0000-0000000000c3"; displayName = "ANC-Entra"; connectionType = "azureADJoin"; healthCheckStatus = "passed" }
            [pscustomobject]@{ id = "00000000-0000-0000-0000-0000000000c4"; displayName = "ANC-Failed"; connectionType = "hybridAzureADJoin"; healthCheckStatus = "failed" }
            [pscustomobject]@{ id = "00000000-0000-0000-0000-0000000000c5"; displayName = "ANC-Warning"; connectionType = "hybridAzureADJoin"; healthCheckStatus = "warning" }
            [pscustomobject]@{ id = "00000000-0000-0000-0000-0000000000c6"; displayName = "ANC-Informational"; connectionType = "hybridAzureADJoin"; healthCheckStatus = "informational" }
            [pscustomobject]@{ id = "00000000-0000-0000-0000-0000000000c7"; displayName = "ANC-Pending"; connectionType = "hybridAzureADJoin"; healthCheckStatus = "pending" }
            [pscustomobject]@{ id = "00000000-0000-0000-0000-0000000000c8"; displayName = "ANC-Running"; connectionType = "hybridAzureADJoin"; healthCheckStatus = "running" }
        )

        # regionGroup that Graph stores for the created policy. Tests may replace it.
        $StoredRegionGroup = "europeUnion"

        # Graph GETs: policy list (duplicate check), created policy (read back), connection list and connection by id
        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            $requestUri = "$Uri"
            if ($requestUri -like "*/onPremisesConnections/*") {
                $requestedId = ([uri]$requestUri).Segments[-1].TrimEnd("/")
                $match = @($Connections | Where-Object { $_.id -eq $requestedId })
                if ($match.Count -eq 0) {
                    $exception = [System.Exception]::new("Response status code does not indicate success: 404 (Not Found).")
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "ObjectNotFound", $null)
                    $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"ResourceNotFound","message":"Not found"}}')
                    throw $errorRecord
                }
                [pscustomobject]@{ Content = ($match[0] | ConvertTo-Json -Depth 10) }
            }
            elseif ($requestUri -like "*/onPremisesConnections*") {
                [pscustomobject]@{ Content = (@{ value = @($Connections) } | ConvertTo-Json -Depth 10) }
            }
            elseif ($requestUri -like "*/provisioningPolicies/*") {
                $readBack = @{
                    id                       = $PolicyId
                    displayName              = "Test-Policy"
                    managedBy                = "windows365"
                    provisioningType         = "dedicated"
                    domainJoinConfigurations = @(@{ domainJoinType = "azureADJoin"; regionName = "westeurope"; regionGroup = $StoredRegionGroup; onPremisesConnectionId = $null })
                }
                [pscustomobject]@{ Content = ($readBack | ConvertTo-Json -Depth 10) }
            }
            else {
                [pscustomobject]@{ Content = (@{ value = @($Existing) } | ConvertTo-Json -Depth 10) }
            }
        }

        # The POST response leaves out managedBy, as seen live
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
            [pscustomobject]@{
                id          = $PolicyId
                displayName = "Test-Policy"
                managedBy   = $null
            }
        }
    }

    Context "Microsoft Entra join with a Microsoft-hosted network" {

        It "POSTs exactly the documented top-level properties" {
            New-CPCProvisioningPolicy @EntraJoin | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $expected = @("cloudPcNamingTemplate", "description", "displayName", "domainJoinConfigurations", "enableSingleSignOn",
                    "imageId", "imageType", "managedBy", "microsoftManagedDesktop", "provisioningType", "userExperienceType", "windowsSetting")
                $b = $Body | ConvertFrom-Json
                $Uri -eq $PostUri -and
                $Method -eq "POST" -and
                (@($b.PSObject.Properties.Name | Sort-Object) -join ",") -eq (@($expected | Sort-Object) -join ",")
            }
        }

        It "sends the documented values and types" {
            New-CPCProvisioningPolicy @EntraJoin | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $b = $Body | ConvertFrom-Json
                $b.displayName -ceq "Test-Policy" -and
                $b.description -ceq "Test description" -and
                $b.provisioningType -ceq "dedicated" -and
                $b.managedBy -ceq "windows365" -and
                $b.imageId -ceq $ImageId -and
                $b.imageType -ceq "gallery" -and
                $b.enableSingleSignOn -is [bool] -and
                $b.enableSingleSignOn -eq $true -and
                $b.cloudPcNamingTemplate -ceq "CPC-%USERNAME:5%-%RAND:5%" -and
                $b.userExperienceType -ceq "cloudPc"
            }
        }

        It "sends domainJoinConfigurations as an array with domainJoinType, regionName and regionGroup" {
            New-CPCProvisioningPolicy @EntraJoin | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $b = $Body | ConvertFrom-Json
                $djc = @($b.domainJoinConfigurations)
                $b.domainJoinConfigurations -is [array] -and
                $djc.Count -eq 1 -and
                (@($djc[0].PSObject.Properties.Name | Sort-Object) -join ",") -eq "domainJoinType,regionGroup,regionName" -and
                $djc[0].domainJoinType -ceq "azureADJoin" -and
                $djc[0].regionName -ceq "westeurope" -and
                $djc[0].regionGroup -ceq "europeUnion"
            }
        }

        It "sends windowsSetting.locale and microsoftManagedDesktop.managedType only" {
            New-CPCProvisioningPolicy @EntraJoin | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $b = $Body | ConvertFrom-Json
                (@($b.windowsSetting.PSObject.Properties.Name) -join ",") -eq "locale" -and
                $b.windowsSetting.locale -ceq "en-US" -and
                (@($b.microsoftManagedDesktop.PSObject.Properties.Name) -join ",") -eq "managedType" -and
                $b.microsoftManagedDesktop.managedType -ceq "notManaged"
            }
        }

        It "never sends deprecated or non-existent properties" {
            New-CPCProvisioningPolicy @EntraJoin | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $b = $Body | ConvertFrom-Json
                $names = $b.PSObject.Properties.Name
                $names -notcontains "windowsSettings" -and
                $names -notcontains "userSettingsPersistenceEnabled" -and
                $names -notcontains "domainJoinConfiguration" -and
                $names -notcontains "onPremisesConnectionId" -and
                $names -notcontains "autopatch" -and
                $names -notcontains "autopilotConfiguration" -and
                @($b.domainJoinConfigurations)[0].PSObject.Properties.Name -notcontains "type"
            }
        }

        It "omits regionGroup when -RegionGroup is not passed" {
            $params = $EntraJoin.Clone()
            $params.Remove("RegionGroup")

            New-CPCProvisioningPolicy @params | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $djc = @(($Body | ConvertFrom-Json).domainJoinConfigurations)
                (@($djc[0].PSObject.Properties.Name | Sort-Object) -join ",") -eq "domainJoinType,regionName"
            }
        }

        It "sends enableSingleSignOn false when -EnableSingleSignOn is not passed" {
            $params = $EntraJoin.Clone()
            $params.Remove("EnableSingleSignOn")

            New-CPCProvisioningPolicy @params | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $b = $Body | ConvertFrom-Json
                $b.enableSingleSignOn -is [bool] -and $b.enableSingleSignOn -eq $false
            }
        }

        It "returns the created policy" {
            $result = New-CPCProvisioningPolicy @EntraJoin

            $result.id | Should -Be $PolicyId
        }

        It "warns when Graph stores a different region group" {
            $StoredRegionGroup = "netherlands"

            $result = New-CPCProvisioningPolicy @EntraJoin -WarningVariable warnings -WarningAction SilentlyContinue

            $result.id | Should -Be $PolicyId
            "$warnings" | Should -BeLike "*netherlands*europeUnion*"
        }

        It "doesn't warn when the stored region group matches" {
            New-CPCProvisioningPolicy @EntraJoin -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

            $warnings | Should -BeNullOrEmpty
        }

        It "doesn't send a naming template for sharedByEntraGroup without -NamingTemplate" {
            New-CPCProvisioningPolicy @EntraJoin -ProvisioningType sharedByEntraGroup -UserExperience cloudApp | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $b = $Body | ConvertFrom-Json
                $b.PSObject.Properties.Name -notcontains "cloudPcNamingTemplate" -and
                $b.provisioningType -ceq "sharedByEntraGroup" -and
                $b.userExperienceType -ceq "cloudApp"
            }
        }

        It "sends the naming template that is passed" {
            New-CPCProvisioningPolicy @EntraJoin -NamingTemplate "PSCT-%RAND:6%" | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ($Body | ConvertFrom-Json).cloudPcNamingTemplate -ceq "PSCT-%RAND:6%"
            }
        }

        It "errors and sends no POST for -DomainJoinType hybridAzureADJoin with -RegionName" {
            $params = $EntraJoin.Clone()
            $params.DomainJoinType = "hybridAzureADJoin"

            { New-CPCProvisioningPolicy @params -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "*only supports -DomainJoinType azureADJoin*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Hybrid Microsoft Entra join with an Azure network connection (#135)" {

        It "POSTs domainJoinType hybridAzureADJoin with onPremisesConnectionId and no region" {
            New-CPCProvisioningPolicy @HybridJoin | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $b = $Body | ConvertFrom-Json
                $djc = @($b.domainJoinConfigurations)
                $Uri -eq $PostUri -and
                $Method -eq "POST" -and
                $b.domainJoinConfigurations -is [array] -and
                $djc.Count -eq 1 -and
                (@($djc[0].PSObject.Properties.Name | Sort-Object) -join ",") -eq "domainJoinType,onPremisesConnectionId" -and
                $djc[0].domainJoinType -ceq "hybridAzureADJoin" -and
                $djc[0].onPremisesConnectionId -ceq $ConnectionId1
            }
        }

        It "accepts -EnableSingleSignOn with hybrid join" {
            New-CPCProvisioningPolicy @HybridJoin -EnableSingleSignOn $true | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $b = $Body | ConvertFrom-Json
                $b.enableSingleSignOn -is [bool] -and $b.enableSingleSignOn -eq $true
            }
        }

        It "sends one entry per connection, in the order passed" {
            $params = $HybridJoin.Clone()
            $params.AzureNetworkConnection = @("ANC-Hybrid-2", "ANC-Hybrid-1")

            New-CPCProvisioningPolicy @params | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $djc = @(($Body | ConvertFrom-Json).domainJoinConfigurations)
                $djc.Count -eq 2 -and
                $djc[0].onPremisesConnectionId -ceq $ConnectionId2 -and
                $djc[1].onPremisesConnectionId -ceq $ConnectionId1 -and
                $djc[0].domainJoinType -ceq "hybridAzureADJoin" -and
                $djc[1].domainJoinType -ceq "hybridAzureADJoin"
            }
        }

        It "reads connectionType, not the retired type, and stops on a mismatch" {
            $Connections = @([pscustomobject]@{ id = $ConnectionId1; displayName = "ANC-Hybrid-1"; connectionType = "azureADJoin"; type = "hybridAzureADJoin"; healthCheckStatus = "passed" })

            { New-CPCProvisioningPolicy @HybridJoin -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "*is of type azureADJoin and can't be used with -DomainJoinType hybridAzureADJoin"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "stops when the connection has no connectionType (only the retired type)" {
            $Connections = @([pscustomobject]@{ id = $ConnectionId1; displayName = "ANC-Hybrid-1"; type = "hybridAzureADJoin"; healthCheckStatus = "passed" })

            { New-CPCProvisioningPolicy @HybridJoin -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "*has no supported connectionType*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "looks the connections up through Graph, not through Get-CPCAzureNetworkConnection" {
            Mock -ModuleName PSCloudPC Get-CPCAzureNetworkConnection -MockWith { }

            New-CPCProvisioningPolicy @HybridJoin | Out-Null

            Should -Invoke Get-CPCAzureNetworkConnection -ModuleName PSCloudPC -Times 0 -Exactly
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                "$Uri".StartsWith("https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/onPremisesConnections?") -and "$Uri".Contains("connectionType")
            }
        }

        It "accepts health check status <Status>" -ForEach @(
            @{ Status = "warning"; Network = "ANC-Warning"; Warns = $true }
            @{ Status = "informational"; Network = "ANC-Informational"; Warns = $false }
        ) {
            $params = $HybridJoin.Clone()
            $params.AzureNetworkConnection = $Network

            $output = New-CPCProvisioningPolicy @params 3>&1
            $warnings = @($output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
            if ($Warns) {
                "$warnings" | Should -BeLike "*health check status 'warning'*"
            }
            else {
                $warnings.Count | Should -Be 0
            }
        }

        It "errors and sends no POST when <Case>" -ForEach @(
            @{ Case = "no connection matches"; Network = "Does Not Exist"; Message = "No Azure Network Connection found with name 'Does Not Exist'" }
            @{ Case = "the health check failed"; Network = "ANC-Failed"; Message = "*is not healthy (healthCheckStatus: failed)" }
            @{ Case = "the health check is pending"; Network = "ANC-Pending"; Message = "*hasn't finished (healthCheckStatus: pending)*" }
            @{ Case = "the health check is running"; Network = "ANC-Running"; Message = "*hasn't finished (healthCheckStatus: running)*" }
            @{ Case = "the connection type differs from -DomainJoinType"; Network = "ANC-Entra"; Message = "*is of type azureADJoin*" }
        ) {
            $params = $HybridJoin.Clone()
            $params.AzureNetworkConnection = $Network

            { New-CPCProvisioningPolicy @params -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage $Message

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "errors and sends no POST when two connections have the same name" {
            $Connections = @(
                [pscustomobject]@{ id = $ConnectionId1; displayName = "ANC-Hybrid-1"; connectionType = "hybridAzureADJoin"; healthCheckStatus = "passed" }
                [pscustomobject]@{ id = $ConnectionId2; displayName = "ANC-Hybrid-1"; connectionType = "hybridAzureADJoin"; healthCheckStatus = "passed" }
            )

            { New-CPCProvisioningPolicy @HybridJoin -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "2 Azure Network Connections found with name 'ANC-Hybrid-1'*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Azure network connection by id" {

        It "GETs each connection by id and POSTs its id, also when names are not unique" {
            $Connections = @(
                [pscustomobject]@{ id = $ConnectionId1; displayName = "ANC-Same"; connectionType = "hybridAzureADJoin"; healthCheckStatus = "passed" }
                [pscustomobject]@{ id = $ConnectionId2; displayName = "ANC-Same"; connectionType = "hybridAzureADJoin"; healthCheckStatus = "passed" }
            )

            New-CPCProvisioningPolicy -Name "Test-Hybrid" -ImageId $ImageId -DomainJoinType hybridAzureADJoin -AzureNetworkConnectionId $ConnectionId2 | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                "$Uri" -like "*/onPremisesConnections/$($ConnectionId2)?*"
            }
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly -ParameterFilter {
                "$Uri".Contains("/onPremisesConnections?")
            }
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $djc = @(($Body | ConvertFrom-Json).domainJoinConfigurations)
                $djc.Count -eq 1 -and
                $djc[0].domainJoinType -ceq "hybridAzureADJoin" -and
                $djc[0].onPremisesConnectionId -ceq $ConnectionId2
            }
        }

        It "still throws and sends no POST when the id is not found" {
            { New-CPCProvisioningPolicy -Name "Test-Hybrid" -ImageId $ImageId -DomainJoinType hybridAzureADJoin -AzureNetworkConnectionId "00000000-0000-0000-0000-0000000000ee" -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "Azure Network Connection with id '00000000-0000-0000-0000-0000000000ee' was not found*ResourceNotFound*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Evolvable enums and the returned object" {

        It "sends Prefer: include-unknown-enum-members on the duplicate name check" {
            New-CPCProvisioningPolicy @EntraJoin | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                "$Uri".Contains("/provisioningPolicies?") -and $Headers.Prefer -eq "include-unknown-enum-members"
            }
        }

        It "sends the Prefer header on the POST for <Type>" -ForEach @(
            @{ Type = "sharedByUser"; Experience = "cloudPc" }
            @{ Type = "sharedByEntraGroup"; Experience = "cloudApp" }
        ) {
            New-CPCProvisioningPolicy @EntraJoin -ProvisioningType $Type -UserExperience $Experience | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $Headers.Prefer -eq "include-unknown-enum-members" -and
                $Headers.Authorization -eq "Bearer token" -and
                ($Body | ConvertFrom-Json).provisioningType -ceq $Type
            }
        }

        It "doesn't send the Prefer header on the POST for dedicated and leaves the module header unchanged" {
            New-CPCProvisioningPolicy @EntraJoin | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                -not $Headers.ContainsKey("Prefer")
            }
            InModuleScope PSCloudPC { $script:Authheader.ContainsKey("Prefer") } | Should -BeFalse
        }

        It "doesn't offer reserve, which the create API doesn't document" {
            { New-CPCProvisioningPolicy @EntraJoin -ProvisioningType reserve } | Should -Throw

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "returns the policy read back with the Prefer header, including managedBy" {
            $result = New-CPCProvisioningPolicy @EntraJoin

            $result.id | Should -Be $PolicyId
            $result.managedBy | Should -Be "windows365"
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                "$Uri" -eq "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies/$PolicyId" -and
                $Headers.Prefer -eq "include-unknown-enum-members"
            }
        }

        It "warns and returns the POST response when reading the policy back fails" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                throw [System.Exception]::new("Response status code does not indicate success: 503 (Service Unavailable).")
            } -ParameterFilter { "$Uri" -like "*/provisioningPolicies/*" }

            $result = New-CPCProvisioningPolicy @EntraJoin -WarningVariable warnings -WarningAction SilentlyContinue

            $result.id | Should -Be $PolicyId
            "$warnings" | Should -BeLike "*was created ($PolicyId), but reading it back failed*"
        }
    }

    Context "Windows Autopatch" {

        It "sends managedType starterManaged and the autopatch group id" {
            New-CPCProvisioningPolicy @EntraJoin -WindowsAutopatch starterManaged -WindowsAutopatchGroupId $AutopatchGroupId | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $b = $Body | ConvertFrom-Json
                $b.microsoftManagedDesktop.managedType -ceq "starterManaged" -and
                $b.microsoftManagedDesktop.PSObject.Properties.Name -notcontains "type" -and
                (@($b.autopatch.PSObject.Properties.Name) -join ",") -eq "autopatchGroupId" -and
                $b.autopatch.autopatchGroupId -ceq $AutopatchGroupId
            }
        }

        It "doesn't send autopatch for starterManaged without a group id" {
            New-CPCProvisioningPolicy @EntraJoin -WindowsAutopatch starterManaged | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $b = $Body | ConvertFrom-Json
                $b.microsoftManagedDesktop.managedType -ceq "starterManaged" -and
                $b.PSObject.Properties.Name -notcontains "autopatch"
            }
        }

        It "warns and doesn't send the group id without starterManaged" {
            New-CPCProvisioningPolicy @EntraJoin -WindowsAutopatchGroupId $AutopatchGroupId -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

            "$warnings" | Should -BeLike "*WindowsAutopatchGroupId*"
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                ($Body | ConvertFrom-Json).PSObject.Properties.Name -notcontains "autopatch"
            }
        }
    }

    Context "Input checks with -ErrorAction SilentlyContinue" {
        # A Throw or break in begin is skipped with SilentlyContinue; the checks must still stop before the POST.

        It "still throws and sends no POST when a policy with the name exists" {
            $Existing = @(@{ id = $PolicyId; displayName = "Test-Policy" })

            { New-CPCProvisioningPolicy @EntraJoin -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "Provisioning Policy with name 'Test-Policy' already exists ($PolicyId)"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "still throws and sends no POST for cloudApp without sharedByEntraGroup" {
            { New-CPCProvisioningPolicy @EntraJoin -UserExperience cloudApp -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "*must be 'sharedByEntraGroup'*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "still throws and sends no POST without -RegionName or -AzureNetworkConnection" {
            { New-CPCProvisioningPolicy -Name "Test-Policy" -ImageId $ImageId -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "Specify -RegionName*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "WhatIf" {

        It "sends no POST and returns nothing with -WhatIf (<Case>)" -ForEach @(
            @{ Case = "Entra join"; Hybrid = $false }
            @{ Case = "hybrid join"; Hybrid = $true }
        ) {
            $params = if ($Hybrid) { $HybridJoin } else { $EntraJoin }

            $result = New-CPCProvisioningPolicy @params -WhatIf

            $result | Should -BeNullOrEmpty
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Graph error" {

        It "throws with the Graph error code when the POST fails" {
            Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 400 (Bad Request).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"PolicyNameExists"}}')
                throw $errorRecord
            }

            { New-CPCProvisioningPolicy @EntraJoin -ErrorAction Stop } | Should -Throw -ExpectedMessage "*BadRequest: PolicyNameExists*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
        }
    }
}
