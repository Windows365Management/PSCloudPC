function Update-CPCUserSettingsPolicy {
    <#
    .SYNOPSIS
    Updates a User Settings Policy in the Intune Cloud PC Service
    .DESCRIPTION
    Updates a User Settings Policy in the Intune Cloud PC Service
    .PARAMETER Name
    Name of the User Settings Policy to update
    .PARAMETER LocalAdminEnabled
    Enable or disable local admin
    .PARAMETER UserRestoreEnabled
    Enable or disable user restore
    .PARAMETER UserRestoreFrequency
    Frequency of user restore points (4, 6, 12, 16, 24 hours)
    .EXAMPLE
    Update-CPCUserSettingsPolicy -Name "Your Settings Policy" -LocalAdminEnabled $true -UserRestoreEnabled $false -UserRestoreFrequency 6
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        [parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]$Name,
        [Parameter(mandatory = $false)][bool]$LocalAdminEnabled,
        [Parameter(mandatory = $false)][bool]$UserRestoreEnabled,
        [ValidateSet('4', '6', '12', '16', '24')]$UserRestoreFrequency
    )

    Begin {
        Get-TokenValidity

        $Policy = Get-CPCUserSettingsPolicy -name $Name

        If ($null -eq $Policy) {
            Throw "No User Settings Policy found with name $Name"
            return
        }

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/userSettings/$($Policy.id)"

        Write-Verbose "Update url: $($url)"

    }

    Process {
        
        $params = @{
            displayName = $($Policy.displayName)
        }

        If ($LocalAdminEnabled){
            $params.Add("LocalAdminEnabled", "$LocalAdminEnabled")
        }

        If ($SelfServiceEnabled){
            $params.Add("SelfServiceEnabled", $SelfServiceEnabled )
        }

        If ($UserRestoreEnabled){
            If ($params.RestorePointSetting){
                $params.RestorePointSetting += @{"UserRestoreEnabled" = "$UserRestoreEnabled"}
            }
            else {  
                $params += @{RestorePointSetting = @{"UserRestoreEnabled" = "$UserRestoreEnabled"}}
            }
        }

        If ($UserRestoreFrequency) {
            If ($params.RestorePointSetting){
                $params.RestorePointSetting += @{"frequencyInHours" = $UserRestoreFrequency}
            }
            else {  
                $params += @{RestorePointSetting = @{"frequencyInHours" = $UserRestoreFrequency}}
            }
        }
        
        Write-Verbose "Params: $($params)"

        $body = $params | ConvertTo-Json -Depth 10

        Write-Verbose "Body: $($body)"

        try {
            Write-Verbose "Updating User Settings Policy $($Name)"
            $Result = Invoke-WebRequest -uri $url -Method PATCH -Headers $script:authHeader -Body $body -ContentType "application/json"

            $Result | ConvertFrom-Json
        }
        catch {
            Throw $_.Exception.Message
        }
    }
}