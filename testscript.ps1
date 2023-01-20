# Construct the authentication URL
$uri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
 
#The Client ID from App Registrations
$clientId = "fdf1582a-b9d6-4357-a073-3acbb2395fa0"
 
#The Tenant ID from App Registrations
$tenantId = "761bd9eb-2b5e-4a6c-8608-73ae0195169e"
 
#The Client ID from certificates and secrets section
$clientSecret = '9zp8Q~WxHq_2VRgagTxhLUzz2rAfEtejk0RqZaUJ'
 
 
# Construct the body to be used in Invoke-WebRequest
$body = @{
    client_id     = $clientId
    scope         = "https://graph.microsoft.com/.default"
    client_secret = $clientSecret
    grant_type    = "client_credentials"
}
 
# Get Authentication Token
$tokenRequest = Invoke-WebRequest -Method Post -Uri $uri -ContentType "application/x-www-form-urlencoded" -Body $body -UseBasicParsing
 
# Extract the Access Token
$token = ($tokenRequest.Content | ConvertFrom-Json).access_token
$token


##################
#The Graph API URL
$uri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/organizationSettings"
 Process{
$method = "GET"
 
# Run the Graph API query to retrieve users
$result = Invoke-WebRequest -Method $method -Uri $uri -Headers @{Authorization = "Bearer $token"}

$settings = $result.content | ConvertFrom-Json
write-verbose "Organization settings retrieved"
$settings | ForEach-Object {
    $Test = [PSCustomObject]@{
        osVersion          = $_.osVersion
        userAccountType   = $_.userAccountType
        enableMEMAutoEnroll    = $_.enableMEMAutoEnroll
        enableSingleSignOn      = $_.enableSingleSignOn
        windowsSettings = $_.windowsSettings
    }
    $Test
}
 }



New-CPCAzureNetworkConnection -