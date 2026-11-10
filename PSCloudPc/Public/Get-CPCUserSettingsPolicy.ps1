function Get-CPCUserSettingsPolicy {
    <#
    .SYNOPSIS
    Returns all User Setting Policy's or User Setting Policy's with a specific name
    .DESCRIPTION
    The function will return all User Setting Policy's or User Setting Policy's with a specific name.
    The name must match exactly, but is not case-sensitive. When no policy matches, nothing is returned.
    .PARAMETER name
    Enter the name of the User Setting Policy
    .EXAMPLE
    Get-CPCUserSettingsPolicy -name "UserSettingPolicy01"
    .EXAMPLE
    Get-CPCUserSettingsPolicy
    .NOTES
    Required permission: CloudPC.Read.All
    https://learn.microsoft.com/graph/api/virtualendpoint-list-usersettings?view=graph-rest-beta

#>

    [CmdletBinding()]
    param (
        [parameter(ParameterSetName = "Name")]
        [string]$Name
    )

    Begin {
        Get-TokenValidity

        # Graph's displayName eq filter on userSettings is case-sensitive, so all policies are read
        # (Invoke-APIRequest follows every page) and the name is matched on the client instead
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/userSettings"
    }

    Process {
        try {
            $policies = @(Invoke-APIRequest -uri $url -Token $script:Authtoken -Method GET -ErrorAction Stop)
        }
        catch {
            Throw (Get-GraphErrorMessage $_)
        }

        If ($PSBoundParameters.ContainsKey("Name")) {
            $policies = @($policies | Where-Object { $_.displayName -eq $Name })
        }

        If ($policies.Count -eq 0) {
            Write-Verbose "No User Setting Policy's found"
            return
        }

        foreach ($policy in $policies) {
            [PSCustomObject]@{
                id                                 = $policy.id
                displayName                        = $policy.displayName
                selfServiceEnabled                 = $policy.selfServiceEnabled
                localAdminEnabled                  = $policy.localAdminEnabled
                resetEnabled                       = $policy.resetEnabled
                createdDateTime                    = $policy.createdDateTime
                lastModifiedDateTime               = $policy.lastModifiedDateTime
                restorePointSetting                = $policy.restorePointSetting
                crossRegionDisasterRecoverySetting = $policy.crossRegionDisasterRecoverySetting
            }
        }
    }

}
