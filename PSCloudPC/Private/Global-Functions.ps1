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