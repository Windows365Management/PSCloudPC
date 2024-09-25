function Connect-Windows365 {
    <#
    .SYNOPSIS
    Connect to Windows 365 via Powershell
    .DESCRIPTION
    Connect to Windows 365 via Powershell via Interactive Browser or Service Principal
    .PARAMETER Authtype
    Type of Authentication to use Interactive, ServicePrincipal or DeviceCode
    .PARAMETER ClientSecret
    Client Secret for Service Principal Authentication
    .PARAMETER TenantID
    Tenant ID for all Authentication types
    .PARAMETER ClientID
    Client ID for Service Principal Authentication
    .PARAMETER ClientCertificate
    Client Certificate for Service Principal Authentication (THUMBPRINT)
    .EXAMPLE
    Connect-Windows365 -TenantID contoso.onmicrosoft.com
    .EXAMPLE
    Connect-Windows365 -TenantID contoso.onmicrosoft.com
    .EXAMPLE
    Connect-Windows365 -TenantID contoso.onmicrosoft.com -ClientID 12345678-1234-1234-1234-123456789012 -ClientSecret 12345678-1234-1234-1234-123456789012   
    .EXAMPLE
    Connect-Windows365 -TenantID contoso.onmicrosoft.com -ClientID 12345678-1234-1234-1234-123456789012 -ClientCertificate "THUMBPRINT"
    #>
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param (
        [parameter(ParameterSetName = "Interactive")]
        [parameter(ParameterSetName = "ClientSecret")]
        [parameter(ParameterSetName = "ClientCertificate")]
        [parameter(ParameterSetName = "DeviceCode")]

        [parameter(Mandatory, ParameterSetName = "Interactive")]
        [parameter(Mandatory, ParameterSetName = "DeviceCode")]
        [parameter(Mandatory, ParameterSetName = "ClientSecret")]
        [parameter(Mandatory, ParameterSetName = "ClientCertificate")]
        [string]$TenantID,

        [parameter(Mandatory, ParameterSetName = "ClientSecret")]
        [string]$ClientID,

        [parameter(Mandatory, ParameterSetName = "ClientSecret")]
        [string]$ClientSecret,
        
        [parameter(Mandatory, ParameterSetName = "ClientCertificate")]
        [string]$ClientCertificate
    )
    begin {
        # Set the profile to beta
        Set-GraphVersion
    }
    
    process {

        Write-Verbose "Using Authentication Type: $($PsCmdlet.ParameterSetName)"
        
        switch ($PsCmdlet.ParameterSetName) {
            Interactive {

                $environment = Get-ChildItem -Path C:\Windows -ErrorAction SilentlyContinue

                If ($null -eq $environment) {
                    Write-Error "Using Powershell Core on Mac or Linux, please use the DeviceCode or ClientSecret Authentication"
                    Break
                }
                else {
                    Write-Verbose "Using Windows Powershell Core, continue with the script"
                }

                Write-Verbose "Use Interactive Authentication"
                Write-Verbose "Using Windows Powershell"
                # Add required assemblies
                $ClientID = "14d82eec-204b-4c2f-b7e8-296a70dab67e"
                $Scopes = "CloudPC.ReadWrite.All%20DeviceManagementConfiguration.ReadWrite.All%20DeviceManagementManagedDevices.ReadWrite.All%20Directory.Read.All"
                $redirectUri = "https://login.microsoftonline.com/common/oauth2/nativeclient"

                # With User Interaction for Delegated Permission
                Add-Type -AssemblyName System.Web

                Function Get-AuthCode {
                    Add-Type -AssemblyName System.Windows.Forms

                    $form = New-Object -TypeName System.Windows.Forms.Form -Property @{Width = 640; Height = 840 }
                    $web = New-Object -TypeName System.Windows.Forms.WebBrowser -Property @{Width = 620; Height = 800; Url = ($url -f ($Scope -join "%20")) }

                    $DocComp = {
                        $Script:uri = $web.Url.AbsoluteUri        
                        if ($Script:uri -match "error=[^&]*|code=[^&]*") { $form.Close() }
                    }
                    $web.ScriptErrorsSuppressed = $true
                    $web.Add_DocumentCompleted($DocComp)
                    $form.Controls.Add($web)
                    $form.Add_Shown( { $form.Activate() })
                    $form.ShowDialog() | Out-Null

                    $queryOutput = [System.Web.HttpUtility]::ParseQueryString($web.Url.Query)
                    $output = @{}
                    foreach ($key in $queryOutput.Keys) {
                        $output["$key"] = $queryOutput[$key]
                    }
                }
                $url = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=$($ClientID)&response_type=code&redirect_uri=$($redirectUri)&response_mode=query&scope=$($Scopes)&state=12345"
                Get-AuthCode
                # Extract Access token from the returned URI
                $regex = '(?<=code=)(.*)(?=&)'
                $authCode = ($uri | Select-string -pattern $regex).Matches[0].Value

                Write-Verbose "Received an authCode, $authCode"

                # get Access Token
                $body = "grant_type=authorization_code&redirect_uri=$redirectUri&client_id=$clientId&code=$authCode"
                $connection = Invoke-RestMethod https://login.microsoftonline.com/common/oauth2/token `
                    -Method Post -ContentType "application/x-www-form-urlencoded" `
                    -Body $body `
                    -ErrorAction STOP
                # Access Token
                $Token = $connection.access_token
                $script:Authtime = [System.DateTime]::UtcNow
                $script:Authtoken = $connection
                $script:Authheader = @{Authorization = "Bearer $($Token)" }                   
            }
            DeviceCode {
                Write-Verbose "Using Device Code"
                $clientId = "14d82eec-204b-4c2f-b7e8-296a70dab67e"
                $resource = "https://graph.microsoft.com/"
                $scope = "CloudPC.ReadWrite.All%20DeviceManagementConfiguration.ReadWrite.All%20DeviceManagementManagedDevices.ReadWrite.All%20Directory.Read.All"

                $codeBody = @{ 
                    resource  = $resource
                    client_id = $clientId
                    scope     = $scope
                }

                # Get OAuth Code
                $codeRequest = Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$tenantId/oauth2/devicecode" -Body $codeBody

                # Print Code to console
                Write-Output "`n$($codeRequest.message)"

                $tokenBody = @{
                    grant_type = "urn:ietf:params:oauth:grant-type:device_code"
                    code       = $codeRequest.device_code
                    client_id  = $clientId
                }

                # Get OAuth Token
                while ([string]::IsNullOrEmpty($connection.access_token)) {
                    $connection = try {
                        Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$tenantId/oauth2/token" -Body $tokenBody
                        Write-Verbose "Completed Authentication"
                    }
                    catch {
                        $errorMessage = $_.ErrorDetails.Message | ConvertFrom-Json
                        # If not waiting for auth, throw error
                        if ($errorMessage.error -ne "authorization_pending") {
                            throw
                        }
                    }
                }
                $Token = $connection.access_token

                $script:Authtime = [System.DateTime]::UtcNow
                $script:Authtoken = $connection
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
                $script:Authtoken = $connection
                $script:Authheader = @{Authorization = "Bearer $($Token)" }
            }

            ClientCertificate {
                $environment = Get-Item Cert:\LocalMachine\My -ErrorAction SilentlyContinue

                If ($null -eq $environment) {
                    Write-Error "Using Powershell Core on Mac or Linux, please use the DeviceCode or ClientSecret Authentication"
                    Break
                }
                else {
                    Write-Verbose "Using Windows Powershell (Core), continue with the script"
                    $Certificate = Get-Item Cert:\LocalMachine\My\$ClientCertificate #thumbprint of the cert
                }

                Write-Verbose "Using Client Certificate Authentication"
                $TenantName = $TenantID
                $AppId = $ClientID
                $Scope = "https://graph.microsoft.com/.default"

                # Create base64 hash of certificate
                $CertificateBase64Hash = [System.Convert]::ToBase64String($Certificate.GetCertHash())

                # Create JWT timestamp for expiration
                $StartDate = (Get-Date "1970-01-01T00:00:00Z" ).ToUniversalTime()
                $JWTExpirationTimeSpan = (New-TimeSpan -Start $StartDate -End (Get-Date).ToUniversalTime().AddMinutes(2)).TotalSeconds
                $JWTExpiration = [math]::Round($JWTExpirationTimeSpan, 0)

                # Create JWT validity start timestamp
                $NotBeforeExpirationTimeSpan = (New-TimeSpan -Start $StartDate -End ((Get-Date).ToUniversalTime())).TotalSeconds
                $NotBefore = [math]::Round($NotBeforeExpirationTimeSpan, 0)

                # Create JWT header
                $JWTHeader = @{
                    alg = "RS256"
                    typ = "JWT"
                    # Use the CertificateBase64Hash and replace/strip to match web encoding of base64
                    x5t = $CertificateBase64Hash -replace '\+', '-' -replace '/', '_' -replace '='
                }

                # Create JWT payload
                $JWTPayLoad = @{
                    # What endpoint is allowed to use this JWT
                    aud = "https://login.microsoftonline.com/$TenantName/oauth2/token"
                    # Expiration timestamp
                    exp = $JWTExpiration
                    # Issuer = your application
                    iss = $AppId
                    # JWT ID: random guid
                    jti = [guid]::NewGuid()
                    # Not to be used before
                    nbf = $NotBefore
                    # JWT Subject
                    sub = $AppId
                }

                # Convert header and payload to base64
                $JWTHeaderToByte = [System.Text.Encoding]::UTF8.GetBytes(($JWTHeader | ConvertTo-Json))
                $EncodedHeader = [System.Convert]::ToBase64String($JWTHeaderToByte)

                $JWTPayLoadToByte = [System.Text.Encoding]::UTF8.GetBytes(($JWTPayload | ConvertTo-Json))
                $EncodedPayload = [System.Convert]::ToBase64String($JWTPayLoadToByte)

                # Join header and Payload with "." to create a valid (unsigned) JWT
                $JWT = $EncodedHeader + "." + $EncodedPayload

                # Get the private key object of your certificate
                # $PrivateKey = $Certificate.PrivateKey
                $PrivateKey = ([System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Certificate))

                # Define RSA signature and hashing algorithm
                $RSAPadding = [Security.Cryptography.RSASignaturePadding]::Pkcs1
                $HashAlgorithm = [Security.Cryptography.HashAlgorithmName]::SHA256

                # Create a signature of the JWT
                $Signature = [Convert]::ToBase64String(
                    $PrivateKey.SignData([System.Text.Encoding]::UTF8.GetBytes($JWT), $HashAlgorithm, $RSAPadding)
                ) -replace '\+', '-' -replace '/', '_' -replace '='

                # Join the signature to the JWT with "."
                $JWT = $JWT + "." + $Signature

                # Create a hash with body parameters
                $Body = @{
                    client_id             = $AppId
                    client_assertion      = $JWT
                    client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
                    scope                 = $Scope
                    grant_type            = "client_credentials"
                }

                $Url = "https://login.microsoftonline.com/$TenantName/oauth2/v2.0/token"

                # Use the self-generated JWT as Authorization
                $Header = @{
                    Authorization = "Bearer $JWT"
                }

                # Splat the parameters for Invoke-Restmethod for cleaner code
                $PostSplat = @{
                    ContentType = 'application/x-www-form-urlencoded'
                    Method      = 'POST'
                    Body        = $Body
                    Uri         = $Url
                    Headers     = $Header
                }

                $Request = Invoke-RestMethod @PostSplat

                $script:Authtime = [System.DateTime]::UtcNow
                $script:Authtoken = $connection
                $script:Authheader = @{Authorization = "Bearer $($Request.access_token)" }

            }
        }
    }
}
