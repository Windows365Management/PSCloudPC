<#
This file tests the Get-CPCGalleryImage function by using Pester.
Contract: GET /deviceManagement/virtualEndpoint/galleryImages (all pages, no $filter).
-Name matches displayName or the deprecated offerDisplayName on the client (exact,
case-insensitive), so both "Windows 11 Enterprise" (offer) and "Windows 11 Enterprise 26H2"
(displayName) work. The output keeps the deprecated properties and adds the current ones.
https://learn.microsoft.com/graph/api/virtualendpoint-list-galleryimages?view=graph-rest-beta
https://learn.microsoft.com/graph/api/resources/cloudpcgalleryimage?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "Get-CPCGalleryImage" {

    BeforeAll {
        $GalleryUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/galleryImages"

        $Images = @(
            @{ id = "publisher_offer_sku-26h2-os"; displayName = "Windows 11 Enterprise 26H2"; offerDisplayName = "Windows 11 Enterprise"; skuDisplayName = "26H2"; recommendedSku = "light"; offerName = "windows-ent-cpc"; skuName = "sku-26h2-os"; publisherName = "publisher"; osVersionNumber = "10.0.26200"; osArchitecture = "x64"; sizeInGB = 64; startDate = "2026-09-01"; endDate = "2027-09-01"; expirationDate = "2028-03-01"; status = "supported" }
            @{ id = "publisher_offer_sku-26h2-m365"; displayName = "Windows 11 Enterprise + Microsoft 365 Apps 26H2"; offerDisplayName = "Windows 11 Enterprise"; skuDisplayName = "26H2"; recommendedSku = "light"; offerName = "windows-ent-cpc"; skuName = "sku-26h2-m365"; publisherName = "publisher"; osVersionNumber = "10.0.26200"; osArchitecture = "x64"; sizeInGB = 64; startDate = "2026-09-01"; endDate = "2027-09-01"; expirationDate = "2028-03-01"; status = "supported" }
            @{ id = "publisher_offer_sku-10-os"; displayName = "Windows 10 Enterprise 22H2"; offerDisplayName = "Windows 10 Enterprise"; skuDisplayName = "22H2"; recommendedSku = "light"; offerName = "windows-ent-cpc"; skuName = "sku-10-os"; publisherName = "publisher"; osVersionNumber = "10.0.19045"; osArchitecture = "x64"; sizeInGB = 64; startDate = "2022-10-01"; endDate = "2025-10-14"; expirationDate = "2026-04-14"; status = "notSupported" }
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
            [pscustomobject]@{ Content = (@{ value = $Images } | ConvertTo-Json -Depth 10) }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { throw "Invoke-RestMethod must not be called by Get-CPCGalleryImage" }
    }

    Context "Request" {

        It "sends a GET to galleryImages without a `$filter, also with -Name" {
            Get-CPCGalleryImage -Name "Windows 11 Enterprise" | Out-Null

            Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter { "$Uri" -eq $GalleryUri -and $Method -eq "GET" }
        }
    }

    Context "-Name" {

        It "matches the displayName (<Name>)" -TestCases @(
            @{ Name = "Windows 11 Enterprise 26H2" }
            @{ Name = "windows 11 enterprise 26h2" }
        ) {
            param($Name)
            $result = @(Get-CPCGalleryImage -Name $Name)

            $result.Count | Should -Be 1
            $result[0].id | Should -Be "publisher_offer_sku-26h2-os"
        }

        It "still matches the offerDisplayName like before" {
            $result = @(Get-CPCGalleryImage -Name "Windows 11 Enterprise")

            $result.Count | Should -Be 2
        }

        It "does not return partial matches" {
            $result = @(Get-CPCGalleryImage -Name "Windows 11")

            $result.Count | Should -Be 0
        }

        It "returns all images without -Name" {
            $result = @(Get-CPCGalleryImage)

            $result.Count | Should -Be 3
        }
    }

    Context "Output" {

        It "keeps the existing properties and adds the current ones" {
            $result = @(Get-CPCGalleryImage -Name "Windows 11 Enterprise 26H2")

            $names = $result[0].PSObject.Properties.Name
            foreach ($property in @("offerDisplayName", "skuDisplayName", "recommendedSku", "status", "id", "endDate", "displayName", "offerName", "skuName", "publisherName", "osVersionNumber", "osArchitecture", "sizeInGB", "startDate", "expirationDate")) {
                $names | Should -Contain $property
            }
            $result[0].displayName | Should -Be "Windows 11 Enterprise 26H2"
            $result[0].skuName | Should -Be "sku-26h2-os"
            $result[0].sizeInGB | Should -Be 64
        }

        It "keeps the existing properties first" {
            $result = @(Get-CPCGalleryImage)

            ($result[0].PSObject.Properties.Name)[0..5] | Should -Be @("offerDisplayName", "skuDisplayName", "recommendedSku", "status", "id", "endDate")
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

            { Get-CPCGalleryImage -ErrorAction Stop } | Should -Throw "*Forbidden: Insufficient privileges*"
        }
    }
}
