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
        [string]$OSVersion,
        [parameter(Mandatory = $false)]
        [ValidateSet("standardUser", "administrator")]
        [string]$UserAccountType,
        [parameter(Mandatory = $false)]
        [bool]$EnableMEMAutoEnroll,
        [parameter(Mandatory = $false)]
        [bool]$EnableSingleSignOn,
        [parameter(Mandatory = $false)][string]$WindowsSettings
    )
    Begin {
        Get-TokenValidity
        
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/organizationSettings"
        Write-Verbose "Update url: $($url)"
        $params = @{}
        
        If ($osVersion) {
            $params.Add("osVersion", "$OSVersion")
            Write-Verbose "osVersion: $($OSVersion)"
        }
        If ($userAccountType) {
            if ($userAccountType -eq "administrator") {
                Write-Warning "The administrator account type is not recommended for production use."
            }
            $params.Add("userAccountType", "$UserAccountType")
            Write-Verbose "userAccountType: $($UserAccountType)"
        }
        If ($psboundparameters.ContainsKey("enableMEMAutoEnroll")) {
            $params.Add("enableMEMAutoEnroll", "$EnableMEMAutoEnroll")
            Write-Verbose "enableMEMAutoEnroll: $($EnableMEMAutoEnroll)"
        }
        If ($PSBoundParameters.ContainsKey("enableSingleSignOn")) {
            $params.Add("enableSingleSignOn", "$EnableSingleSignOn")
            Write-Verbose "enableSingleSignOn: $($EnableSingleSignOn)"
        }
        If ($windowsSettings) {
            $params += @{windowsSettings = @{"language" = "$WindowsSettings" } }
            Write-Verbose "windowsSettings: $($WindowsSettings)"
            
        }
    }
    Process {
        $body = $params | ConvertTo-Json -Depth 10
        Write-Verbose "Body: $($body)"
        try {
            Write-Verbose "Updating Organization Settings "
            $result = Invoke-WebRequest -uri $url -Method PATCH -Headers $script:authHeader -Body $body -ContentType "application/json" -SkipHttpErrorCheck
            return $result
            
        }
        catch {
            Throw $_.Exception.Message
        }
    }
}