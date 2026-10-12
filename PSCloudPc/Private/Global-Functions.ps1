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
        [Parameter()][string]$Method = 'Get',
        #Extra request headers, for example @{ Prefer = "include-unknown-enum-members" }; also sent for every next page
        [Parameter()][hashtable]$AdditionalHeaders
    )
    #Perform initial Graph Request
    $Headers = @{Authorization = "Bearer $($Token)" }

    #Extra request headers (for example Prefer: include-unknown-enum-members), sent on every page; never replaces Authorization
    if ($AdditionalHeaders) {
        foreach ($key in $AdditionalHeaders.Keys) {
            if ($key -ne "Authorization") {
                $Headers[$key] = $AdditionalHeaders[$key]
            }
        }
    }

    $params = @{
        uri     = $uri
        Method  = $Method
        Headers = $Headers
    }

    Write-Verbose "Request: $Method $uri"

    try {
        $result = Invoke-WebRequest @params -ErrorAction Stop
    }
    catch {
        Throw (Get-GraphErrorMessage $_)
    }

    #Check if the result is null
    if ($null -eq $result) {
        Throw "No response returned for $Method $uri"
    }

    $resultconvert = $result.Content | ConvertFrom-Json

    #Return single objects as-is; only collections have a value property
    if ($resultconvert.PSObject.Properties.Name -notcontains 'value') {
        return $resultconvert
    }

    $AllPages = @($resultconvert.value)

    #Loop through the API pages if there is a next link
    #The nextLink is opaque (https://learn.microsoft.com/graph/paging), so only check scheme and host before sending the token to it
    $NextLink = $resultconvert.'@odata.nextLink'
    $GraphHost = ([uri]$uri).Host
    $SeenLinks = [System.Collections.Generic.HashSet[string]]::new()
    $MaxPages = 1000
    $PageCount = 1

    while ($null -ne $NextLink) {
        $NextUri = $null
        if (-not [uri]::TryCreate([string]$NextLink, [System.UriKind]::Absolute, [ref]$NextUri) -or $NextUri.Scheme -ne 'https' -or $NextUri.Host -ne $GraphHost) {
            Throw "Refusing to follow @odata.nextLink '$NextLink': it must be an absolute https URL on $GraphHost"
        }
        if (-not $SeenLinks.Add([string]$NextLink)) {
            Throw "Graph returned the same @odata.nextLink twice, stopping to avoid an endless loop: $NextLink"
        }
        if ($PageCount -ge $MaxPages) {
            Throw "Stopped paging after $MaxPages pages for $uri"
        }
        $PageCount++

        Write-Verbose "Requesting next page: $NextLink"
        try {
            $page = (Invoke-WebRequest -Uri $NextLink -Headers $Headers -Method Get -ErrorAction Stop).Content | ConvertFrom-Json
        }
        catch {
            Throw (Get-GraphErrorMessage $_)
        }
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

#Function to stop the calling cmdlet with a terminating error that -ErrorAction can't suppress
#A Throw in a begin block is skipped with -ErrorAction SilentlyContinue, after which process still runs
function Stop-CPCCommand {
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCmdlet]$Cmdlet,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [System.Management.Automation.ErrorCategory]$Category = 'InvalidArgument'
    )

    $errorRecord = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new($Message), 'PSCloudPC.Guard', $Category, $null)
    $Cmdlet.ThrowTerminatingError($errorRecord)
}

#Function to read a Cloud PC user setting and return its writable properties as a hashtable for a PATCH body
#PATCH on userSettings replaces the whole object: every writable property left out of the body goes back to its default,
#and displayName is required. The update cmdlets therefore send the current values back and change only what was passed.
#Every property the GET returns is copied, so a writable property Microsoft adds later is kept as well; left out are the
#read-only ones (id, createdDateTime, lastModifiedDateTime, @odata.*), the assignments relationship, null values and the
#retired ones (selfServiceEnabled, notificationSetting, restorePointSetting.frequencyInHours).
#https://learn.microsoft.com/graph/api/cloudpcusersetting-get?view=graph-rest-beta
#https://learn.microsoft.com/graph/api/cloudpcusersetting-update?view=graph-rest-beta
#https://learn.microsoft.com/graph/api/resources/cloudpcusersetting?view=graph-rest-beta
function Get-CPCUserSettingBody {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )

    $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/userSettings/$Id"
    $current = Invoke-APIRequest -uri $url -Token $script:Authtoken -Method GET

    if ($null -eq $current -or [string]::IsNullOrWhiteSpace($current.displayName)) {
        Throw "User setting $Id was not returned with a displayName, which every update requires"
    }

    #Read-only properties, the assignments relationship (only returned with $expand) and retired properties:
    #selfServiceEnabled stopped working on December 1, 2023 and notificationSetting on July 14, 2026
    $skipProperties = "id", "createdDateTime", "lastModifiedDateTime", "assignments", "selfServiceEnabled", "notificationSetting"

    $body = @{}
    foreach ($property in $current.PSObject.Properties) {
        if ($property.Name -like "@odata.*" -or $property.Name -in $skipProperties -or $null -eq $property.Value) {
            continue
        }
        $body[$property.Name] = ConvertTo-CPCRequestValue -Value $property.Value
    }

    #The deprecated frequencyInHours is not sent; frequencyType replaces it
    if ($body["restorePointSetting"] -is [hashtable]) {
        $body["restorePointSetting"].Remove("frequencyInHours")
        if ($body["restorePointSetting"].Count -eq 0) {
            $body.Remove("restorePointSetting")
        }
    }

    if ($body["crossRegionDisasterRecoverySetting"] -is [hashtable]) {
        $drSetting = $body["crossRegionDisasterRecoverySetting"]
        $disasterRecoveryType = $drSetting["disasterRecoveryType"]
        if ([string]::IsNullOrWhiteSpace($disasterRecoveryType) -and $drSetting["crossRegionDisasterRecoveryEnabled"] -eq $true) {
            #Documented replacement for a setting that only has the deprecated flag
            $disasterRecoveryType = "crossRegion"
        }

        if ([string]::IsNullOrWhiteSpace($disasterRecoveryType)) {
            #Without a disasterRecoveryType Graph rejects the setting; left out, it stays at its default (notConfigured)
            $body.Remove("crossRegionDisasterRecoverySetting")
        }
        else {
            #crossRegionDisasterRecoveryEnabled is deprecated, but Graph still rejects crossRegion unless it is true
            $drSetting["disasterRecoveryType"] = $disasterRecoveryType
            $drSetting["crossRegionDisasterRecoveryEnabled"] = ($disasterRecoveryType -ne "notConfigured")
        }
    }

    return $body
}

#Function to copy a value from ConvertFrom-Json into hashtables and arrays for a request body
#Null values and @odata annotations are left out. @odata.type is kept on these nested objects: Graph returns it for
#derived types, such as the Microsoft-hosted or Azure network connection disaster recovery network setting, and needs it
#to tell them apart.
function ConvertTo-CPCRequestValue {
    param (
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        $Value
    )

    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $result = @{}
        foreach ($property in $Value.PSObject.Properties) {
            if ($null -eq $property.Value -or ($property.Name -like "@odata.*" -and $property.Name -ne "@odata.type")) {
                continue
            }
            $result[$property.Name] = ConvertTo-CPCRequestValue -Value $property.Value
        }
        return $result
    }

    if ($Value -is [array]) {
        $items = @(foreach ($item in $Value) {
                if ($null -ne $item) {
                    ConvertTo-CPCRequestValue -Value $item
                }
            })
        return , $items
    }

    return $Value
}

#Function to turn Azure network connections (by exact name or by id) into provisioning policy domainJoinConfigurations
#Reads connectionType from Graph (the type property is retired) and stops the calling cmdlet on a failed check
#https://learn.microsoft.com/graph/api/resources/cloudpconpremisesconnection?view=graph-rest-beta
#https://learn.microsoft.com/graph/api/resources/cloudpcdomainjoinconfiguration?view=graph-rest-beta
function Resolve-CPCAzureNetworkConnection {
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCmdlet]$Cmdlet,

        [string[]]$Name,

        [string[]]$Id,

        #Requested domain join type; when empty, the connectionType of the connections is used
        [string]$DomainJoinType
    )

    $baseUrl = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/onPremisesConnections"
    $select = "`$select=id,displayName,connectionType,healthCheckStatus"

    if ($Name) {
        #displayName is matched exactly on the client, so names with quotes work and similar names don't match
        Write-Verbose "Looking up Azure Network Connection(s): $($Name -join ', ')"
        try {
            $allConnections = @(Invoke-APIRequest -uri "$($baseUrl)?$select" -Token $script:Authtoken -Method GET)
        }
        catch {
            Stop-CPCCommand -Cmdlet $Cmdlet -Message (Get-GraphErrorMessage $_) -Category InvalidOperation
        }

        $connections = @(
            foreach ($connectionName in $Name) {
                $match = @($allConnections | Where-Object { $_.displayName -eq $connectionName })

                if ($match.Count -eq 0) {
                    Stop-CPCCommand -Cmdlet $Cmdlet -Message "No Azure Network Connection found with name '$connectionName'" -Category ObjectNotFound
                }

                if ($match.Count -gt 1) {
                    Stop-CPCCommand -Cmdlet $Cmdlet -Message "$($match.Count) Azure Network Connections found with name '$connectionName' ($($match.id -join ', ')). The name must match exactly one connection"
                }

                $match[0]
            }
        )
    }
    else {
        $connections = @(
            foreach ($connectionId in $Id) {
                if ([string]::IsNullOrWhiteSpace($connectionId)) {
                    Stop-CPCCommand -Cmdlet $Cmdlet -Message "An Azure Network Connection id can't be empty"
                }

                Write-Verbose "Looking up Azure Network Connection id: $connectionId"
                try {
                    Invoke-APIRequest -uri "$baseUrl/$([uri]::EscapeDataString($connectionId))?$select" -Token $script:Authtoken -Method GET
                }
                catch {
                    Stop-CPCCommand -Cmdlet $Cmdlet -Message "Azure Network Connection with id '$connectionId' was not found: $(Get-GraphErrorMessage $_)" -Category ObjectNotFound
                }
            }
        )
    }

    $joinConfigurations = @(
        foreach ($connection in $connections) {
            $label = "'$($connection.displayName)' ($($connection.id))"

            #warning and informational don't affect provisioning; failed does; pending/running have no result yet
            if ($connection.healthCheckStatus -in @('passed', 'informational')) {
                Write-Verbose "Azure Network Connection $label health check: $($connection.healthCheckStatus)"
            }
            elseif ($connection.healthCheckStatus -eq 'warning') {
                Write-Warning "Azure Network Connection $label has health check status 'warning'. Provisioning works, but the user experience might be affected."
            }
            elseif ($connection.healthCheckStatus -in @('pending', 'running')) {
                Stop-CPCCommand -Cmdlet $Cmdlet -Message "The health check of Azure Network Connection $label hasn't finished (healthCheckStatus: $($connection.healthCheckStatus)). Try again when it has passed"
            }
            else {
                Stop-CPCCommand -Cmdlet $Cmdlet -Message "Azure Network Connection $label is not healthy (healthCheckStatus: $($connection.healthCheckStatus))"
            }

            $connectionType = $connection.connectionType
            if ($connectionType -notin @('azureADJoin', 'hybridAzureADJoin')) {
                Stop-CPCCommand -Cmdlet $Cmdlet -Message "Azure Network Connection $label has no supported connectionType ('$connectionType')"
            }

            if (-not [string]::IsNullOrWhiteSpace($DomainJoinType) -and $connectionType -ne $DomainJoinType) {
                Stop-CPCCommand -Cmdlet $Cmdlet -Message "Azure Network Connection $label is of type $connectionType and can't be used with -DomainJoinType $DomainJoinType"
            }

            [ordered]@{
                domainJoinType         = $connectionType
                onPremisesConnectionId = $connection.id
            }
        }
    )

    $joinTypes = @($joinConfigurations | ForEach-Object { $_["domainJoinType"] })
    if (@($joinTypes | Sort-Object -Unique).Count -gt 1) {
        Stop-CPCCommand -Cmdlet $Cmdlet -Message "The Azure Network Connections have different connection types ($($joinTypes -join ', ')). Use connections of one type"
    }

    #Callers wrap the result in @() so one configuration is still sent as an array
    $joinConfigurations
}