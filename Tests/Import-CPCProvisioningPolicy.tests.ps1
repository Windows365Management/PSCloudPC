<#
This file tests the Import-CPCProvisioningPolicy function by using Pester.
Contract: an export from Export-CPCProvisioningPolicy (a JSON array with one cloudPcProvisioningPolicy) is created
again through New-CPCProvisioningPolicy (POST /deviceManagement/virtualEndpoint/provisioningPolicies).
Older exports have the deprecated windowsSettings.language and domainJoinConfigurations[].type, current exports
have windowsSetting.locale and domainJoinConfigurations[].domainJoinType; both are read, and the POST only uses
the current properties. Azure network connections are resolved by id with
GET /deviceManagement/virtualEndpoint/onPremisesConnections/{id}.
https://learn.microsoft.com/en-us/graph/api/resources/cloudpcprovisioningpolicy?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/resources/cloudpcdomainjoinconfiguration?view=graph-rest-beta
https://learn.microsoft.com/en-us/graph/api/cloudpconpremisesconnection-get?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Import-CPCProvisioningPolicy" {

    BeforeAll {
        $PostUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies"
        $ConnectionId = "00000000-0000-0000-0000-0000000000c1"

        # Export written by an older module version against the older Graph schema
        $OldExport = Join-Path $TestDrive "old-export.json"
        Set-Content -Path $OldExport -Value @"
[
  {
    "id": "00000000-0000-0000-0000-000000000001",
    "displayName": "Old-Export-Policy",
    "description": "Old export",
    "provisioningType": "dedicated",
    "managedBy": "windows365",
    "imageId": "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc",
    "imageType": "gallery",
    "enableSingleSignOn": true,
    "cloudPcNamingTemplate": "OLD-%USERNAME:5%-%RAND:5%",
    "domainJoinConfigurations": [
      { "type": "azureADJoin", "regionName": "westeurope", "regionGroup": "europeUnion", "onPremisesConnectionId": null }
    ],
    "windowsSettings": { "language": "nl-NL" },
    "microsoftManagedDesktop": { "type": "notManaged", "profile": null }
  }
]
"@

        # Export of a policy as the current Graph beta returns it
        $NewExport = Join-Path $TestDrive "new-export.json"
        Set-Content -Path $NewExport -Value @"
[
  {
    "id": "00000000-0000-0000-0000-000000000002",
    "displayName": "New-Export-Policy",
    "description": "New export",
    "provisioningType": "dedicated",
    "managedBy": "windows365",
    "imageId": "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc",
    "imageType": "gallery",
    "enableSingleSignOn": false,
    "cloudPcNamingTemplate": "NEW-%USERNAME:5%-%RAND:5%",
    "domainJoinConfigurations": [
      { "domainJoinType": "azureADJoin", "type": "azureADJoin", "regionName": "westeurope", "onPremisesConnectionId": null, "regionGroup": "netherlands", "geographicLocationType": "europe" }
    ],
    "windowsSetting": { "locale": "de-DE" },
    "windowsSettings": { "language": "en-US" },
    "microsoftManagedDesktop": { "managedType": "notManaged", "type": "notManaged", "profile": "" },
    "autopatch": null,
    "autopilotConfiguration": null,
    "userExperienceType": "cloudPc"
  }
]
"@

        # Hybrid join export with an Azure network connection
        $HybridExport = Join-Path $TestDrive "hybrid-export.json"
        Set-Content -Path $HybridExport -Value @"
[
  {
    "displayName": "Hybrid-Export-Policy",
    "provisioningType": "dedicated",
    "imageId": "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc",
    "imageType": "gallery",
    "enableSingleSignOn": true,
    "domainJoinConfigurations": [
      { "domainJoinType": "hybridAzureADJoin", "regionName": null, "onPremisesConnectionId": "$ConnectionId", "regionGroup": "default" }
    ],
    "windowsSetting": { "locale": "en-US" }
  }
]
"@

        # Domain join type that can't be imported
        $UnknownJoinExport = Join-Path $TestDrive "unknown-join-export.json"
        Set-Content -Path $UnknownJoinExport -Value @"
[
  {
    "displayName": "Unknown-Join-Policy",
    "imageId": "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc",
    "imageType": "gallery",
    "domainJoinConfigurations": [ { "domainJoinType": "unknownFutureValue" } ]
  }
]
"@

        $InvalidJson = Join-Path $TestDrive "invalid.json"
        Set-Content -Path $InvalidJson -Value "{ not json"

        # Exports with an evolvable provisioningType: as read with and without Prefer: include-unknown-enum-members
        $ProvisioningTypeExports = @{}
        foreach ($Type in "sharedByEntraGroup", "sharedByUser", "unknownFutureValue", "reserve") {
            $Experience = if ($Type -eq "sharedByEntraGroup") { "cloudApp" } else { "cloudPc" }
            $ProvisioningTypeExports[$Type] = Join-Path $TestDrive "$Type-export.json"
            Set-Content -Path $ProvisioningTypeExports[$Type] -Value @"
[
  {
    "displayName": "$Type-Policy",
    "provisioningType": "$Type",
    "userExperienceType": "$Experience",
    "imageId": "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc",
    "imageType": "gallery",
    "domainJoinConfigurations": [ { "domainJoinType": "azureADJoin", "regionName": "westeurope", "onPremisesConnectionId": null } ],
    "windowsSetting": { "locale": "en-US" }
  }
]
"@
        }
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        # GET onPremisesConnections/{id} returns the connection, GET provisioningPolicies/{id} the created policy,
        # and the policy list (duplicate name check) is empty
        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            if ("$Uri" -like "*/onPremisesConnections/*") {
                [pscustomobject]@{ Content = (@{ id = $ConnectionId; displayName = "ANC-Hybrid"; connectionType = "hybridAzureADJoin"; healthCheckStatus = "passed" } | ConvertTo-Json) }
            }
            elseif ("$Uri" -like "*/provisioningPolicies/*") {
                [pscustomobject]@{ Content = (@{ id = "00000000-0000-0000-0000-0000000000ff"; displayName = "Read-Back-Policy"; managedBy = "windows365" } | ConvertTo-Json) }
            }
            else {
                [pscustomobject]@{ Content = (@{ value = @() } | ConvertTo-Json) }
            }
        }
        # Graph returns the created policy; echo the request body with an id
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
            $created = $Body | ConvertFrom-Json
            $created | Add-Member -NotePropertyName id -NotePropertyValue "00000000-0000-0000-0000-0000000000ff"
            $created
        }
    }

    Context "Old export (windowsSettings.language, domainJoinConfigurations.type)" {

        It "POSTs the policy with the current property names" {
            Import-CPCProvisioningPolicy -Inputfile $OldExport | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $b = $Body | ConvertFrom-Json
                $djc = @($b.domainJoinConfigurations)
                $Uri -eq $PostUri -and
                $Method -eq "POST" -and
                $b.displayName -ceq "Old-Export-Policy" -and
                $b.description -ceq "Old export" -and
                $b.imageType -ceq "gallery" -and
                $b.enableSingleSignOn -is [bool] -and
                $b.enableSingleSignOn -eq $true -and
                $b.cloudPcNamingTemplate -ceq "OLD-%USERNAME:5%-%RAND:5%" -and
                $b.windowsSetting.locale -ceq "nl-NL" -and
                $b.microsoftManagedDesktop.managedType -ceq "notManaged" -and
                $djc.Count -eq 1 -and
                $djc[0].domainJoinType -ceq "azureADJoin" -and
                $djc[0].regionName -ceq "westeurope" -and
                $djc[0].regionGroup -ceq "europeUnion" -and
                $djc[0].PSObject.Properties.Name -notcontains "type" -and
                $b.PSObject.Properties.Name -notcontains "windowsSettings"
            }
        }

        It "returns the created policy as read back from Graph" {
            $result = Import-CPCProvisioningPolicy -Inputfile $OldExport

            $result.id | Should -Be "00000000-0000-0000-0000-0000000000ff"
            $result.managedBy | Should -Be "windows365"
        }
    }

    Context "New export (windowsSetting.locale, domainJoinConfigurations.domainJoinType)" {

        It "uses windowsSetting.locale over the deprecated windowsSettings.language" {
            Import-CPCProvisioningPolicy -Inputfile $NewExport | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $b = $Body | ConvertFrom-Json
                $djc = @($b.domainJoinConfigurations)
                $b.displayName -ceq "New-Export-Policy" -and
                $b.windowsSetting.locale -ceq "de-DE" -and
                $b.enableSingleSignOn -is [bool] -and
                $b.enableSingleSignOn -eq $false -and
                $b.userExperienceType -ceq "cloudPc" -and
                $b.cloudPcNamingTemplate -ceq "NEW-%USERNAME:5%-%RAND:5%" -and
                $djc[0].domainJoinType -ceq "azureADJoin" -and
                $djc[0].regionName -ceq "westeurope" -and
                $djc[0].PSObject.Properties.Name -notcontains "type" -and
                $djc[0].PSObject.Properties.Name -notcontains "geographicLocationType" -and
                $b.PSObject.Properties.Name -notcontains "windowsSettings" -and
                $b.PSObject.Properties.Name -notcontains "autopatch" -and
                $b.PSObject.Properties.Name -notcontains "id"
            }
        }
    }

    Context "Hybrid join export" {

        It "checks the connection by id, without a lookup by name, and POSTs hybridAzureADJoin with onPremisesConnectionId" {
            Mock -ModuleName PSCloudPC Get-CPCAzureNetworkConnection -MockWith { }

            Import-CPCProvisioningPolicy -Inputfile $HybridExport | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                "$Uri" -like "*/deviceManagement/virtualEndpoint/onPremisesConnections/$ConnectionId*"
            }
            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 0 -Exactly -ParameterFilter {
                "$Uri".Contains("/onPremisesConnections?")
            }
            Should -Invoke Get-CPCAzureNetworkConnection -ModuleName PSCloudPC -Times 0 -Exactly
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $djc = @(($Body | ConvertFrom-Json).domainJoinConfigurations)
                $djc.Count -eq 1 -and
                (@($djc[0].PSObject.Properties.Name | Sort-Object) -join ",") -eq "domainJoinType,onPremisesConnectionId" -and
                $djc[0].domainJoinType -ceq "hybridAzureADJoin" -and
                $djc[0].onPremisesConnectionId -ceq $ConnectionId
            }
        }

        It "errors and sends no POST when the connection id is not found" {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 404 (Not Found).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "ObjectNotFound", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"ResourceNotFound","message":"Not found"}}')
                throw $errorRecord
            } -ParameterFilter { "$Uri" -like "*/onPremisesConnections/*" }

            { Import-CPCProvisioningPolicy -Inputfile $HybridExport -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage "*$ConnectionId*was not found*ResourceNotFound*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Evolvable provisioningType values" {

        It "imports <Type> and sends the Prefer header on the POST" -ForEach @(
            @{ Type = "sharedByEntraGroup"; Experience = "cloudApp" }
            @{ Type = "sharedByUser"; Experience = "cloudPc" }
        ) {
            Import-CPCProvisioningPolicy -Inputfile $ProvisioningTypeExports[$Type] | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
                $b = $Body | ConvertFrom-Json
                $Headers.Prefer -eq "include-unknown-enum-members" -and
                $b.provisioningType -ceq $Type -and
                $b.userExperienceType -ceq $Experience
            }
        }

        It "still throws and sends no POST for <Type>" -ForEach @(
            @{ Type = "unknownFutureValue"; Message = "*is 'unknownFutureValue'*Prefer: include-unknown-enum-members*" }
            @{ Type = "reserve"; Message = "provisioningType 'reserve'*can't be imported*" }
        ) {
            { Import-CPCProvisioningPolicy -Inputfile $ProvisioningTypeExports[$Type] -ErrorAction SilentlyContinue } |
                Should -Throw -ExpectedMessage $Message

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "Files that can't be imported" {

        It "still throws and sends no POST for <Case>" -ForEach @(
            @{ Case = "a missing file"; File = "missing"; Message = "File not found*" }
            @{ Case = "invalid JSON"; File = "invalid"; Message = "*is not a valid JSON File*" }
            @{ Case = "an unknown domain join type"; File = "unknown"; Message = "*can't be imported*" }
        ) {
            $path = switch ($File) {
                "missing" { Join-Path $TestDrive "does-not-exist.json" }
                "invalid" { $InvalidJson }
                "unknown" { $UnknownJoinExport }
            }

            { Import-CPCProvisioningPolicy -Inputfile $path -ErrorAction SilentlyContinue } | Should -Throw -ExpectedMessage $Message

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    Context "WhatIf" {

        It "sends no POST and returns nothing with -WhatIf" {
            $result = Import-CPCProvisioningPolicy -Inputfile $NewExport -WhatIf

            $result | Should -BeNullOrEmpty
            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }
}
