function Connect-Windows365 {
    <#
    .SYNOPSIS
    Connect to Windows 365 via Powershell
    .DESCRIPTION
    Connect to Windows 365 via Powershell via Interactive Browser, Device Code, Service Principal or Access Token.
    .PARAMETER ClientSecret
    Client Secret for Service Principal Authentication
    .PARAMETER TenantID
    Tenant ID for all Authentication types
    .PARAMETER ClientID
    Client ID for Service Principal Authentication
    .PARAMETER ClientCertificate
    Client Certificate for Service Principal Authentication, this must be the actual certificate not only the thumbprint
    .PARAMETER DeviceCode
    Use Device Code Authentication (Switch to use Device Code Authentication)
    .PARAMETER Token
    Use a Token for Authentication, this must be a valid access token for the Microsoft Graph API with CloudPC permissions
    .EXAMPLE
    Connect-Windows365
    .EXAMPLE
    Connect-Windows365 -DeviceCode
    .EXAMPLE
    Connect-Windows365 -TenantID contoso.onmicrosoft.com -ClientID 12345678-1234-1234-1234-123456789012 -ClientSecret 12345678-1234-1234-1234-123456789012
    .EXAMPLE
    Connect-Windows365 -TenantID contoso.onmicrosoft.com -ClientID 12345678-1234-1234-1234-123456789012 -ClientCertificate "Certificate"
    .EXAMPLE
    Connect-Windows365 -Token "YourAccessToken"
    #>
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param (
        [parameter(Mandatory, ParameterSetName = "ClientSecret")]
        [parameter(Mandatory, ParameterSetName = "ClientCertificate")]
        [string]$TenantID,

        [parameter(Mandatory, ParameterSetName = "ClientCertificate")]
        [parameter(Mandatory, ParameterSetName = "ClientSecret")]
        [string]$ClientID,

        [parameter(Mandatory, ParameterSetName = "ClientSecret")]
        [string]$ClientSecret,

        [parameter(Mandatory, ParameterSetName = "ClientCertificate")]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$ClientCertificate,

        [parameter(Mandatory, ParameterSetName = "DeviceCode")]
        [switch]$DeviceCode,

        [parameter(Mandatory, ParameterSetName = "Token")]
        [string]$Token


    )
    begin {
        # Clear the token cache
        $script:Authtime = $null
        $script:Authtoken = $null
        $script:Authheader = $null

        # Set the profile to beta
        Set-GraphVersion
    }

    process {

        $scopes = @(
            "https://graph.microsoft.com/CloudPC.ReadWrite.All",
            "https://graph.microsoft.com/DeviceManagementConfiguration.ReadWrite.All",
            "https://graph.microsoft.com/DeviceManagementManagedDevices.ReadWrite.All",
            "https://graph.microsoft.com/Directory.Read.All"
        )

        Write-Verbose "Using Authentication Type: $($PsCmdlet.ParameterSetName)"

        switch ($PsCmdlet.ParameterSetName) {
            Interactive {

                Write-Verbose "Using Interactive Authentication"

                $response = Connect-MgGraph -Scopes $scopes -NoWelcome

                # Get the Access Token
                $Parameters = @{
                    Method     = "GET"
                    URI        = "/v1.0/me"
                    OutputType = "HttpResponseMessage"
                }

                $Response = Invoke-MgGraphRequest @Parameters
                $Headers = $Response.RequestMessage.Headers
                $Token = $Headers.Authorization.Parameter

                $script:Authtime = [System.DateTime]::UtcNow
                $script:Authtoken = $Token
                $script:Authheader = @{Authorization = "Bearer $($Token)" }
            }

            ClientSecret {
                Write-Verbose "Using Client Secret Authentication"

                $body = @{
                    Grant_Type    = "client_credentials"
                    Scope         = "https://graph.microsoft.com/.default"
                    Client_Id     = $ClientID
                    Client_Secret = $ClientSecret
                }

                $connection = Invoke-RestMethod `
                    -Uri https://login.microsoftonline.com/$TenantID/oauth2/v2.0/token `
                    -Method POST `
                    -Body $body

                $Token = $connection.access_token

                $script:Authtime = [System.DateTime]::UtcNow
                $script:Authtoken = $Token
                $script:Authheader = @{Authorization = "Bearer $($Token)" }
            }

            ClientCertificate {

                Write-Verbose "Using Client Certificate Authentication"

                $response = Connect-MGGraph -ClientId $clientId -TenantId $tenantId -Certificate $ClientCertificate

                $Token = $response.AccessToken
                $script:Authtime = [System.DateTime]::UtcNow
                $script:Authtoken = $Token
                $script:Authheader = @{Authorization = "Bearer $($Request.access_token)" }

            }
            DeviceCode {

                Write-Verbose "Using Device Code Authentication"

                Connect-MgGraph -UseDeviceCode

                # Get the Access Token
                $Parameters = @{
                    Method     = "GET"
                    URI        = "/v1.0/me"
                    OutputType = "HttpResponseMessage"
                }

                $Response = Invoke-MgGraphRequest @Parameters
                $Headers = $Response.RequestMessage.Headers
                $Token = $Headers.Authorization.Parameter

                $script:Authtime = [System.DateTime]::UtcNow
                $script:Authtoken = $Token
                $script:Authheader = @{Authorization = "Bearer $($Token)" }
            }
            Token {

                Write-Verbose "Using Token Authentication"

                $script:Authtime = [System.DateTime]::UtcNow
                $script:Authtoken = $Token
                $script:Authheader = @{Authorization = "Bearer $($Token)" }

            }
        }
    }
}