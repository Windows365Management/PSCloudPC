function Update-CPCOrganizationSetting {
    <#
    .SYNOPSIS
    Update the Cloud PC organization settings
    .DESCRIPTION
    Update the Cloud PC organization settings. A tenant has only one cloudPcOrganizationSettings object,
    so a change applies to the whole tenant and the command asks for confirmation (ConfirmImpact High).
    Use -Confirm:$false to skip the prompt.

    Only the properties you pass are sent; the documented PATCH keeps the values of properties that
    aren't in the request body. Booleans are sent as JSON booleans and windowsSettings as an object.
    The command stops when no setting is passed.
    .PARAMETER OSVersion
    The version of the operating system (OS) to provision on Cloud PCs. The possible values are: windows10, windows11
    .PARAMETER UserAccountType
    The account type of the user on provisioned Cloud PCs. The possible values are: standardUser, administrator
    .PARAMETER EnableMEMAutoEnroll
    Specifies whether new Cloud PCs will be automatically enrolled in Microsoft Intune. The default value is false.
    .PARAMETER EnableSingleSignOn
    Specifies whether single sign-on is enabled for new Cloud PCs. The default value is false.
    .PARAMETER WindowsSettings
    The Windows language/region tag to use for new Cloud PCs, for example en-US. Sent as windowsSettings.language.
    .EXAMPLE
    Update-CPCOrganizationSetting -OSVersion windows11 -UserAccountType standardUser -EnableMEMAutoEnroll $true -EnableSingleSignOn $true
    .EXAMPLE
    Update-CPCOrganizationSetting -EnableSingleSignOn $false -WhatIf
    .EXAMPLE
    Update-CPCOrganizationSetting -WindowsSettings "en-US" -Confirm:$false
    .NOTES
    Required permission: CloudPC.ReadWrite.All
    https://learn.microsoft.com/graph/api/cloudpcorganizationsettings-update?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcorganizationsettings?view=graph-rest-beta
    https://learn.microsoft.com/graph/api/resources/cloudpcwindowssettings?view=graph-rest-beta
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
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
        [parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$WindowsSettings
    )
    Begin {
        Get-TokenValidity

        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/organizationSettings"
        Write-Verbose "Update url: $($url)"
        $params = @{}

        If ($PSBoundParameters.ContainsKey("OSVersion")) {
            $params.Add("osVersion", $OSVersion)
            Write-Verbose "osVersion: $($OSVersion)"
        }
        If ($PSBoundParameters.ContainsKey("UserAccountType")) {
            if ($UserAccountType -eq "administrator") {
                Write-Warning "The administrator account type is not recommended for production use."
            }
            $params.Add("userAccountType", $UserAccountType)
            Write-Verbose "userAccountType: $($UserAccountType)"
        }
        If ($PSBoundParameters.ContainsKey("EnableMEMAutoEnroll")) {
            $params.Add("enableMEMAutoEnroll", $EnableMEMAutoEnroll)
            Write-Verbose "enableMEMAutoEnroll: $($EnableMEMAutoEnroll)"
        }
        If ($PSBoundParameters.ContainsKey("EnableSingleSignOn")) {
            $params.Add("enableSingleSignOn", $EnableSingleSignOn)
            Write-Verbose "enableSingleSignOn: $($EnableSingleSignOn)"
        }
        If ($PSBoundParameters.ContainsKey("WindowsSettings")) {
            $params.Add("windowsSettings", @{ language = $WindowsSettings })
            Write-Verbose "windowsSettings.language: $($WindowsSettings)"
        }

        If ($params.Count -eq 0) {
            Stop-CPCCommand -Cmdlet $PSCmdlet -Message "No organization settings were specified. Provide at least one of: OSVersion, UserAccountType, EnableMEMAutoEnroll, EnableSingleSignOn, WindowsSettings"
        }
    }
    Process {
        $body = $params | ConvertTo-Json -Depth 10
        Write-Verbose "Request: PATCH $url"
        Write-Verbose "Body: $($body)"

        If ($PSCmdlet.ShouldProcess("Cloud PC organization settings (tenant-wide)", "Update $(@($params.Keys | Sort-Object) -join ', ')")) {
            try {
                Write-Verbose "Updating Organization Settings"
                Invoke-RestMethod -Uri $url -Method PATCH -Headers $script:Authheader -Body $body -ContentType "application/json" -ErrorAction Stop
            }
            catch {
                Throw (Get-GraphErrorMessage $_)
            }
        }
    }
}
