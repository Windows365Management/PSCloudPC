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
            Throw "Token expired. Please authenticate again using the Connect-Windows365 command"
            $script:Authtime = $null
            $script:Authtoken = $null
            $script:Authheader = $null
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

    $result = Invoke-WebRequest @params

    #Check if the result is null
    if ($null -eq $result) {
        Write-Error "No results returned exiting function"
        break
    }
    $AllPages = $result.value

    #Loop through the API pages if there is a next link
    $NextLink = $result."@odata.nextLink"

    while ($null -ne $NextLink) {

        $result = (Invoke-WebRequest -Uri $NextLink -Headers $Headers -Method Get)
        $NextLink = $result."@odata.nextLink"
        $AllPages += $result.value
    }

    return $AllPages
}