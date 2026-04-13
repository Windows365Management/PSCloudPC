function Invoke-CPCPowerOn {
    <#
    .SYNOPSIS
    Powers on a Windows 365 Frontline Cloud PC
    .DESCRIPTION
    The function powers on a specific Windows 365 Frontline Cloud PC via the
    Microsoft Graph beta API. After the Cloud PC is powered on, it is allocated
    to a user and licenses are assigned immediately.

    Note: This action applies to Windows 365 Frontline Cloud PCs only.
    Only IT admin users can perform this action. Returns 204 No Content on success.
    .PARAMETER Name
    Enter the display name of the Cloud PC to power on
    .EXAMPLE
    Invoke-CPCPowerOn -Name "CloudPC01"
    .EXAMPLE
    Invoke-CPCPowerOn -Name "CloudPC01" -WhatIf
    .NOTES
    Requires CloudPC.ReadWrite.All permission (delegated or application).
    This action uses the Microsoft Graph beta endpoint.
    API reference: https://learn.microsoft.com/en-us/graph/api/cloudpc-poweron
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    begin {
        Get-TokenValidity

        $CloudPC = Get-CloudPC -Name $Name

        if ($null -eq $CloudPC) {
            Throw "No Cloud PC found with name '$Name'"
            return
        }

        # powerOn is a beta-only API; always use beta endpoint.
        # NOTE: The Graph API action name is all-lowercase (/poweron), not camelCase.
        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/poweron"

        Write-Verbose "URL: $url"
    }

    Process {
        Write-Verbose "Powering on Cloud PC '$($CloudPC.displayName)' (id: $($CloudPC.id))"

        if ($PSCmdlet.ShouldProcess($CloudPC.displayName, "Power on Cloud PC")) {
            try {
                Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST
                Write-Output "Cloud PC '$($CloudPC.displayName)' power on initiated"
            }
            catch {
                Throw $_.Exception.Message
            }
        }
    }
}
