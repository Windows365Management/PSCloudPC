<#
This file tests the New-CPCAzureNetworkConnection function by using Pester.
Contract: the domain join password is never written to the verbose stream.
https://learn.microsoft.com/graph/api/virtualendpoint-post-onpremisesconnections?view=graph-rest-beta
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../PSCloudPc/PSCloudPC.psd1") -Force
}

AfterAll {
    Remove-Module PSCloudPC -Force -ErrorAction SilentlyContinue
}

Describe "New-CPCAzureNetworkConnection" {

    BeforeAll {
        $Password = ConvertTo-SecureString "Pl@inText!" -AsPlainText -Force
        $HybridParams = @{
            Name               = "ANC01"
            ResourceGroupId    = "/subscriptions/s/resourceGroups/rg"
            VirtualNetworkId   = "/vnet"
            SubnetId           = "/subnet"
            SubscriptionId     = "s"
            AdDomainName       = "contoso.com"
            AdDomainUserName   = "join@contoso.com"
            AdDomainPassword   = $Password
            OrganizationalUnit = "OU=CPC,DC=contoso,DC=com"
        }
    }

    BeforeEach {
        InModuleScope PSCloudPC {
            $script:Authtime = [DateTime]::UtcNow
            $script:Authtoken = "token"
            $script:Authheader = @{ Authorization = "Bearer token" }
            $script:MSGraphVersion = "beta"
        }

        Mock -ModuleName PSCloudPC Get-CPCAzureNetworkConnection -MockWith { }
        Mock -ModuleName PSCloudPC Invoke-WebRequest -MockWith { [pscustomobject]@{ Content = "{}" } }
    }

    It "does not write the domain password to the verbose stream" {
        $verbose = New-CPCAzureNetworkConnection @HybridParams -Verbose 4>&1

        ($verbose | Out-String) | Should -Not -BeLike "*Pl@inText!*"
    }
}
