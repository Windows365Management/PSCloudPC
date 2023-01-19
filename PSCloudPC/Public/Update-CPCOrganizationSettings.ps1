function Update-CPCOrganizationSettings {
    <#
    .SYNOPSIS
    Update the Cloud PC organization settings
    .DESCRIPTION
    Update the Cloud PC organization settings. A tenant has only one cloudPcOrganizationSettings object.
    .PARAMETER osVersion
    The account type of the user on provisioned Cloud PCs. The possible values are: standardUser, administrator
    .PARAMETER userAccountType
    The account type of the user on provisioned Cloud PCs. The possible values are: standardUser, administrator
    .PARAMETER enableMEMAutoEnroll
    Specifies whether new Cloud PCs will be automatically enrolled in Microsoft Intune. The default value is false.
    .PARAMETER enableSingleSignOn
    Specifies wether single sign-on is enabled for new Cloud PCs. The default value is false.
    .EXAMPLE
    Update-CPCOrganizationSettings -osVersion windows10 -userAccountType administrator -enableMEMAutoEnroll $true -enableSingleSignOn $true    
    .NOTES
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false)]
        [ValidateSet("windows10", "windows11")]
        [string]$osVersion,
        [parameter(Mandatory = $false)]
        [ValidateSet("standardUser", "administrator")]
        [string]$userAccountType,
        [parameter(Mandatory = $false)]
        [bool]$enableMEMAutoEnroll,
        [parameter(Mandatory = $false)]
        [bool]$enableSingleSignOn,
        [parameter(Mandatory = $false)][string]$windowsSettings
    )
    Begin {
        Get-TokenValidity
        
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/organizationSettings"
        Write-Verbose "Update url: $($url)"
        $params = @{}
        
        If ($osVersion) {
            Write-Output "OS version set to $osVersion"
            $params.Add("osVersion", "$osVersion")
            Write-Verbose "osVersion: $($osVersion)"
        }
        If ($userAccountType) {
            Write-Output "User Account type set to $userAccountType"
            if ($userAccountType -eq "administrator") {
                Write-Warning "The administrator account type is not recommended for production use."
            }
            $params.Add("userAccountType", "$userAccountType")
            Write-Verbose "userAccountType: $($userAccountType)"
        }
        If ($psboundparameters.ContainsKey("enableMEMAutoEnroll")) {
            Write-Output "Automatic Intune enrollment set to $enableMEMAutoEnroll"
            $params.Add("enableMEMAutoEnroll", "$enableMEMAutoEnroll")
            Write-Verbose "enableMEMAutoEnroll: $($enableMEMAutoEnroll)"
        }
        If ($PSBoundParameters.ContainsKey("enableSingleSignOn")) {
            Write-Output "Enable Single Sign On set to $enableSingleSignOn"
            $params.Add("enableSingleSignOn", "$enableSingleSignOn")
            Write-Verbose "enableSingleSignOn: $($enableSingleSignOn)"
        }
        If ($windowsSettings) {
            Write-Output "Language settings set to $windowsSettings"
            $params += @{windowsSettings = @{"language" = "$windowsSettings" } }
            Write-Verbose "windowsSettings: $($windowsSettings)"
            
        }
    }
    Process {
        $body = $params | ConvertTo-Json -Depth 10
        Write-Verbose "Body: $($body)"
        try {
            Write-Verbose "Updating Organization Settings "
            $result = Invoke-WebRequest -uri $url -Method PATCH -Headers $script:authHeader -Body $body -ContentType "application/json"
            if ($result.StatusCode -eq 204) {
                Write-Output "API call was successfull, data received"
            }
            else {
                Write-Output "API returned status code $($result.StatusCode)"
            }
            
        }
        catch {
            Throw $_.Exception.Message
        }
    }
}