<#
This file tests the Disconnect-Windows365 function by using Pester
#>

$modulename = 'PSCloudPC'

BeforeAll {
    # Import the module - correct relative path from Tests folder
    Import-Module "./PSCloudPC/Src/PSCloudPC.psm1" -Force

    # Mock Disconnect-MgGraph to prevent actual disconnection during tests
    Mock -CommandName Disconnect-MgGraph -MockWith { }

}

Describe "Disconnect-Windows365" {

    It "Should disconnect from Windows 365 and clear the token cache when connected" {

        Mock -CommandName Get-MgContext -MockWith {
            $Context = @{
                ClientId            = [guid]::NewGuid().ToString()
                TenantId            = [guid]::NewGuid().ToString()
                Scopes              = @('AccessReview.Read.All', 'Agreement.Read.All')
                AuthType            = 'Delegated'
                TokenCredentialType = 'InteractiveBrowser'
                Account             = 'admin@contoso.com'
                AppName             = 'Microsoft Graph Command Line Tools'
                ContextScope        = 'CurrentUser'
                Environment         = 'Global'
            }
            $Context
        } -ModuleName $modulename
        # Act
        Disconnect-Windows365

        # Assert
        $script:Authtime | Should -BeNullOrEmpty
        $script:Authtoken | Should -BeNullOrEmpty
        $script:Authheader | Should -BeNullOrEmpty
    }

}