function Get-CPCOrganizationSettings {
    <#
    .SYNOPSIS
    Returns the Cloud PC Organization Settings 
    .DESCRIPTION
    This function will return all Cloud PC Organization Settings
    .EXAMPLE
    Get-CPCOrganizationSettings
    #>
    [CmdletBinding()]
    param (
    )
    
    Begin {
        Get-TokenValidity
        Write-Verbose "Setting url to https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/organizationSettings"
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/organizationSettings"
                
    } 
    
    Process {
        
        $result = Invoke-WebRequest -uri $url -Method GET -Headers $script:authHeader -SkipHttpErrorCheck
        
        if ($null -eq $result) {
            Write-Error "No Organization Settings returned"
            break
        }
    
        $resultnew = $result.content | ConvertFrom-Json
        $resultnew | ForEach-Object {
        
            $SettingsList = [PSCustomObject]@{
                osVersion           = $_.osVersion
                userAccountType     = $_.userAccountType
                enableMEMAutoEnroll = $_.enableMEMAutoEnroll
                enableSingleSignOn  = $_.enableSingleSignOn
                windowsSettings     = $_.windowsSettings
            }
            $SettingsList
        
        }
        
    }
    
}