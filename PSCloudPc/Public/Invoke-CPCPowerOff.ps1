function Invoke-CPCPowerOff {
    <#
    .SYNOPSIS
    Powers off a Windows 365 Frontline Cloud PC
    .DESCRIPTION
    The function powers off a specific Windows 365 Frontline Cloud PC via the
    Microsoft Graph beta API. After the Cloud PC is powered off, it is deallocated
    and licenses are revoked immediately.

    Note: This action applies to Windows 365 Frontline Cloud PCs only.
    Only IT admin users can perform this action. Returns 204 No Content on success.
    .PARAMETER Name
    Enter the display name of the Cloud PC to power off
    .EXAMPLE
    Invoke-CPCPowerOff -Name "CloudPC01"
    .EXAMPLE
    Invoke-CPCPowerOff -Name "CloudPC01" -WhatIf
    .NOTES
    Requires CloudPC.ReadWrite.All permission (delegated or application).
    This action uses the Microsoft Graph beta endpoint.
    API reference: https://learn.microsoft.com/en-us/graph/api/cloudpc-poweroff
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

        # powerOff is a beta-only API; always use beta endpoint.
        # NOTE: The Graph API action name is all-lowercase (/poweroff), not camelCase.
        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/poweroff"

        Write-Verbose "URL: $url"
    }

    Process {
        Write-Verbose "Powering off Cloud PC '$($CloudPC.displayName)' (id: $($CloudPC.id))"

        if ($PSCmdlet.ShouldProcess($CloudPC.displayName, "Power off Cloud PC")) {
            try {
                Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST
                Write-Output "Cloud PC '$($CloudPC.displayName)' power off initiated"
            }
            catch {
                Throw $_.Exception.Message
            }
        }
    }
}
