function Get-CPCUserSettingsPolicy {
    <#
    .SYNOPSIS
    Returns all User Setting Policy's or User Setting Policy's with a specific name
    .DESCRIPTION
    The function will return all User Setting Policy's or User Setting Policy's with a specific name
    .PARAMETER name
    Enter the name of the User Setting Policy
    .EXAMPLE
    Get-CPCUserSettingsPolicy -name "UserSettingPolicy01"

#>

    [CmdletBinding()]
    param (
        [parameter(ParameterSetName = "Name")]
        [string]$Name 
    )
    
    Begin {
        Get-TokenValidity

        switch ($PsCmdlet.ParameterSetName) {
            Name {
                Write-Verbose "Name parameter provided"
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/userSettings?`$filter=displayName+eq+'$($Name)'"
            }
            default {
                $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/userSettings"
            }
        }
    }
    
    Process {
        write-verbose $url
        $result = Invoke-WebRequest -uri $url -Method GET -Headers $script:authHeader
    
        if ($null -eq $result) {
            Write-Error "No User Setting Policy's returned"
            break
        }

        $resultnew = $result.content | ConvertFrom-Json
        $returnResults = @()
        $resultnew.value | ForEach-Object {
    
            $Info = [PSCustomObject]@{
                id                   = $_.id
                displayName          = $_.displayName
                selfServiceEnabled   = $_.selfServiceEnabled
                localAdminEnabled    = $_.localAdminEnabled
                createdDateTime      = $_.createdDateTime
                lastModifiedDateTime = $_.lastModifiedDateTime
                restorePointSetting  = $_.restorePointSetting
            }
            $returnResults += $Info
        }
        return $returnResults
    
    }
    
}