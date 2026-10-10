#Function to set the profile to beta
function Set-GraphVersion {
    Write-Verbose "Setting profile as beta..."
    $script:MSGraphVersion = "beta"
}

#Function to check if the user is connected to Windows365
function Get-TokenValidity {
    
    if ($null -eq $script:Authtime) {
        Throw "No token found. Please authenticate first using the Connect-Windows365 command"
    }
    else {
        Write-Verbose "Token found. Checking validity..."

        $date = [System.DateTime]::UtcNow
        If ($date -gt $script:Authtime.AddMinutes(55)) {
            $script:Authtime = $null
            $script:Authtoken = $null
            $script:Authheader = $null
            Throw "Token expired. Please authenticate again using the Connect-Windows365 command"
        }
        else {
            Write-Verbose "Token is still valid."
        }
    }
}

function Get-AzureADGroupID {
    param (
        [Parameter(Mandatory = $true)]
        [string]$GroupName
    )

    $url = "https://graph.microsoft.com/$script:MSGraphVersion/groups?`$filter=displayName+eq+'$GroupName'"

    $result = Invoke-RestMethod -Uri $url -Headers $script:Authheader -Method GET

    if ($null -eq $result) {
        Write-Error "No groups returned"
        break
    }
    
    $script:GroupID = $result.value.id

}

function Invoke-APIRequest {
    param (
        [Parameter()][string]$uri,
        [Parameter()][string]$Token,
        [Parameter()][string]$Method = 'Get'
    )
    #Perform initial Graph Request
    $Headers = @{Authorization = "Bearer $($Token)" }

    $params = @{
        uri     = $uri
        Method  = $Method
        Headers = $Headers
    }

    Write-Verbose "Request: $Method $uri"

    $result = Invoke-WebRequest @params

    #Check if the result is null
    if ($null -eq $result) {
        Write-Error "No results returned exiting function"
        return
    }

    $resultconvert = $result.Content | ConvertFrom-Json

    #Return single objects as-is; only collections have a value property
    if ($resultconvert.PSObject.Properties.Name -notcontains 'value') {
        return $resultconvert
    }

    $AllPages = @($resultconvert.value)

    #Loop through the API pages if there is a next link
    $NextLink = $resultconvert.'@odata.nextLink'

    while ($null -ne $NextLink) {
        Write-Verbose "Requesting next page: $NextLink"
        $page = (Invoke-WebRequest -Uri $NextLink -Headers $Headers -Method Get).Content | ConvertFrom-Json
        $AllPages += $page.value
        $NextLink = $page.'@odata.nextLink'
    }

    return $AllPages
}

#Function to create a signed client assertion (JWT) for certificate based authentication
#https://learn.microsoft.com/entra/identity-platform/certificate-credentials
function New-ClientAssertion {
    param (
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

        [Parameter(Mandatory = $true)]
        [string]$ClientID,

        [Parameter(Mandatory = $true)]
        [string]$TokenEndpoint
    )

    $privateKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Certificate)
    if ($null -eq $privateKey) {
        Throw "The certificate '$($Certificate.Subject)' has no accessible RSA private key. Use a certificate that includes its private key."
    }

    $toBase64Url = {
        param([byte[]]$Bytes)
        [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    }

    $now = [DateTimeOffset]::UtcNow

    $header = @{
        alg = 'RS256'
        typ = 'JWT'
        x5t = & $toBase64Url $Certificate.GetCertHash()
    } | ConvertTo-Json -Compress

    $claims = @{
        aud = $TokenEndpoint
        iss = $ClientID
        sub = $ClientID
        jti = [guid]::NewGuid().ToString()
        nbf = $now.ToUnixTimeSeconds()
        exp = $now.AddMinutes(10).ToUnixTimeSeconds()
    } | ConvertTo-Json -Compress

    $unsigned = "$(& $toBase64Url ([Text.Encoding]::UTF8.GetBytes($header))).$(& $toBase64Url ([Text.Encoding]::UTF8.GetBytes($claims)))"

    $signature = $privateKey.SignData(
        [Text.Encoding]::UTF8.GetBytes($unsigned),
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
    )

    return "$unsigned.$(& $toBase64Url $signature)"
}

#Function to get the most useful message from a failed Microsoft Graph request
function Get-GraphErrorMessage {
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $message = $ErrorRecord.Exception.Message
    $details = $ErrorRecord.ErrorDetails.Message

    if ([string]::IsNullOrWhiteSpace($details)) {
        return $message
    }

    #Graph returns {"error": {"code": "...", "message": "..."}} in the response body
    try {
        $graphError = ($details | ConvertFrom-Json -ErrorAction Stop).error
        if ($graphError.message) {
            return "$message $($graphError.code): $($graphError.message)"
        }
    }
    catch {
        Write-Verbose "Error details are not Graph JSON: $details"
    }

    return "$message $details"
}