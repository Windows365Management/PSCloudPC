<#
This file tests the New-CPCCustomImage function by using Pester.
Contract: POST /deviceManagement/virtualEndpoint/deviceImages with the required properties
displayName, version and sourceImageResourceId (#136: displayName was always empty).
An image is identified by displayName + version, so only an existing image with the same name AND
version blocks the upload. A failed duplicate lookup stops the command (fails closed).
https://learn.microsoft.com/graph/api/virtualendpoint-post-deviceimages?view=graph-rest-beta
https://learn.microsoft.com/graph/api/resources/cloudpcdeviceimage?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "New-CPCCustomImage" {

    BeforeAll {
        $ImagesUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/deviceImages"
        $SourceId = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-fake/providers/Microsoft.Compute/images/fake-image"
        $ImageParams = @{
            Name                  = "FakeImage01"
            Version               = "0.0.2"
            SourceImageResourceId = $SourceId
        }
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        # Images returned by the duplicate lookup (Get-CPCCustomImage). Tests may replace this list.
        $Images = @()

        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
            [pscustomobject]@{ Content = (@{ value = @($Images) } | ConvertTo-Json -Depth 10) }
        }
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith { }
    }

    It "requires -Name" {
        $nameParameter = (Get-Command New-CPCCustomImage).Parameters["Name"]
        $mandatory = $nameParameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } | ForEach-Object Mandatory

        $mandatory | Should -Contain $true
    }

    It "looks up existing images with an escaped exact displayName filter" {
        New-CPCCustomImage @ImageParams | Out-Null

        Should -Invoke Invoke-WebRequest -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            ([uri]$Uri).OriginalString -eq "$ImagesUri`?`$filter=displayName+eq+'FakeImage01'"
        }
    }

    It "POSTs displayName, version and sourceImageResourceId and nothing else" {
        New-CPCCustomImage @ImageParams | Out-Null

        Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            $parsed = $Body | ConvertFrom-Json
            ([uri]$Uri).OriginalString -eq $ImagesUri -and
            $Method -eq "POST" -and
            (@($parsed.PSObject.Properties.Name | Sort-Object) -join ",") -eq "displayName,sourceImageResourceId,version" -and
            $parsed.displayName -eq "FakeImage01" -and
            $parsed.version -eq "0.0.2" -and
            $parsed.sourceImageResourceId -eq $SourceId
        }
    }

    It "uploads a new version of an image whose name already exists" {
        $Images = @(@{ id = "00000000-0000-0000-0000-000000000001"; displayName = "FakeImage01"; version = "0.0.1" })

        New-CPCCustomImage @ImageParams | Out-Null

        Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly -ParameterFilter {
            ($Body | ConvertFrom-Json).version -eq "0.0.2"
        }
    }

    It "stops and sends no POST when an image with the same name and version exists" {
        $Images = @(
            @{ id = "00000000-0000-0000-0000-000000000001"; displayName = "FakeImage01"; version = "0.0.1" }
            @{ id = "00000000-0000-0000-0000-000000000002"; displayName = "FakeImage01"; version = "0.0.2" }
        )

        { New-CPCCustomImage @ImageParams -ErrorAction Stop } |
            Should -Throw -ExpectedMessage "Custom Image with name 'FakeImage01' and version '0.0.2' already exists (00000000-0000-0000-0000-000000000002)"

        Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
    }

    It "still throws and sends no POST with -ErrorAction SilentlyContinue when the name and version exist" {
        $Images = @(@{ id = "00000000-0000-0000-0000-000000000002"; displayName = "FakeImage01"; version = "0.0.2" })

        { New-CPCCustomImage @ImageParams -ErrorAction SilentlyContinue } | Should -Throw -ExpectedMessage "Custom Image with name 'FakeImage01' and version '0.0.2' already exists*"

        Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
    }

    Context "Failed duplicate lookup" {

        BeforeEach {
            Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith {
                $exception = [System.Exception]::new("Response status code does not indicate success: 403 (Forbidden).")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "PermissionDenied", $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"Forbidden","message":"Access denied"}}')
                throw $errorRecord
            }
        }

        It "stops and sends no POST when the lookup fails" {
            { New-CPCCustomImage @ImageParams -ErrorAction Stop } | Should -Throw -ExpectedMessage "Could not check for an existing Custom Image*Forbidden: Access denied*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }

        It "still stops and sends no POST with -ErrorAction SilentlyContinue" {
            { New-CPCCustomImage @ImageParams -ErrorAction SilentlyContinue } | Should -Throw -ExpectedMessage "Could not check for an existing Custom Image*"

            Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
        }
    }

    It "sends no POST with -WhatIf" {
        New-CPCCustomImage @ImageParams -WhatIf | Out-Null

        Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 0 -Exactly
    }

    It "throws with the Graph error code when the POST fails" {
        Mock -ModuleName PSCloudPC Invoke-RestMethod -MockWith {
            $exception = [System.Exception]::new("Response status code does not indicate success: 400 (Bad Request).")
            $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "GraphError", "InvalidOperation", $null)
            $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":{"code":"BadRequest","message":"Invalid image"}}')
            throw $errorRecord
        }

        { New-CPCCustomImage @ImageParams -ErrorAction Stop } | Should -Throw -ExpectedMessage "*BadRequest: Invalid image*"

        Should -Invoke Invoke-RestMethod -ModuleName PSCloudPC -Times 1 -Exactly
    }
}
