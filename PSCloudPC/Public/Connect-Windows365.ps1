
function Connect-Windows365 {
    <#
    .SYNOPSIS
    Connect to Windows 365 via Powershell
    .DESCRIPTION
    Connect to Windows 365 via Powershell via Interactive Browser, Device Code or Service Principal
    .PARAMETER ClientSecret
    Client Secret for Service Principal Authentication
    .PARAMETER TenantID
    Tenant ID for all Authentication types
    .PARAMETER ClientID
    Client ID for Service Principal Authentication
    .PARAMETER ClientCertificate
    Client Certificate for Service Principal Authentication, this must be the actual certificate not only the thumbprint
    .PARAMETER DeviceCode
    Use Device Code Authentication (Boolean)
    .EXAMPLE
    Connect-Windows365
    .EXAMPLE
    Connect-Windows365 -DeviceCode:$true
    .EXAMPLE
    Connect-Windows365 -TenantID contoso.onmicrosoft.com -ClientID 12345678-1234-1234-1234-123456789012 -ClientSecret 12345678-1234-1234-1234-123456789012   
    .EXAMPLE
    Connect-Windows365 -TenantID contoso.onmicrosoft.com -ClientID 12345678-1234-1234-1234-123456789012 -ClientCertificate "Certificate"
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
        [bool]$DeviceCode
    )
    begin {
        #Clear the current token
        Clear-MsalTokenCache

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

                $response = Get-MsalToken -ClientId '14d82eec-204b-4c2f-b7e8-296a70dab67e' -Scopes $scopes

                # Access Token
                $Token = $response.AccessToken
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

                $response = Get-MsalToken -ClientId $clientId -TenantId $tenantId -ClientCertificate $ClientCertificate

                $Token = $response.AccessToken
                $script:Authtime = [System.DateTime]::UtcNow
                $script:Authtoken = $Token
                $script:Authheader = @{Authorization = "Bearer $($Request.access_token)" }

            }
            DeviceCode {

                Write-Verbose "Using Device Code Authentication"

                $response = Get-MsalToken -ClientId '14d82eec-204b-4c2f-b7e8-296a70dab67e' -Scopes $scopes -DeviceCode
                
                $Token = $response.AccessToken
                $script:Authtime = [System.DateTime]::UtcNow
                $script:Authtoken = $Token
                $script:Authheader = @{Authorization = "Bearer $($Token)" }
            }
        }
    }
}