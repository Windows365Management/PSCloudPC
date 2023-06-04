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
    .EXAMPLE
    Connect-Windows365 -TenantID contoso.onmicrosoft.com
    .EXAMPLE
    Connect-Windows365 -AuthType DeviceCode -TenantID contoso.onmicrosoft.com
    .EXAMPLE
    Connect-Windows365 -Authtype ServicePrincipal -TenantID contoso.onmicrosoft.com -ClientID 12345678-1234-1234-1234-123456789012 -ClientSecret 12345678-1234-1234-1234-123456789012   
    #>
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param (
        [parameter(ParameterSetName = "Interactive")]
        [parameter(ParameterSetName = "ServicePrincipal")]
        [parameter(ParameterSetName = "DeviceCode")]
        [ValidateSet('ServicePrincipal', 'Interactive', 'DeviceCode')]
        [string]$Authtype = 'Interactive',

        [parameter(Mandatory, ParameterSetName = "ServicePrincipal")]
        [string]$ClientSecret,

        [parameter(Mandatory, ParameterSetName = "DeviceCode")]
        [parameter(Mandatory, ParameterSetName = "ServicePrincipal")]
        [string]$TenantID,

        [parameter(Mandatory, ParameterSetName = "ServicePrincipal")]
        [string]$ClientID
    )
    begin {
        # Set the profile to beta
        Set-GraphVersion
    }
    
    process {
        
        switch ($Authtype) {
            Interactive {
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
                Write-Host "`n$($codeRequest.message)"

                $tokenBody = @{
                    grant_type = "urn:ietf:params:oauth:grant-type:device_code"
                    code       = $codeRequest.device_code
                    client_id  = $clientId
                }

                # Get OAuth Token
                while ([string]::IsNullOrEmpty($tokenRequest.access_token)) {
                    $connection = try {
                        Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$tenantId/oauth2/token" -Body $tokenBody
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

            ServicePrincipal {

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
        }
    }
}