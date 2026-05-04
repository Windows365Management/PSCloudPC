function Invoke-CPCPowerOff {
    <#
    .SYNOPSIS
    Powers off a Windows 365 Frontline Cloud PC
    .DESCRIPTION
    The function powers off a specific Windows 365 Frontline Cloud PC via the
    Microsoft Graph beta API. After the Cloud PC is powered off, it is deallocated
    and licenses are revoked immediately.

    You can identify the target Cloud PC by its managed device name (default) or
    by providing the Cloud PC object ID directly via -CloudPCId.

    Note: This action applies to Windows 365 Frontline Cloud PCs only.
    Only IT admin users can perform this action. Returns 204 No Content on success.
    .PARAMETER Name
    The managed device name of the Cloud PC to power off. Use Get-CloudPC to find
    Cloud PC names. Mutually exclusive with -CloudPCId.
    .PARAMETER CloudPCId
    The object ID (GUID) of the Cloud PC to power off. Use Get-CloudPC to find
    Cloud PC IDs. Mutually exclusive with -Name.
    .EXAMPLE
    Invoke-CPCPowerOff -Name "CPC-User-XXXX"
    .EXAMPLE
    Invoke-CPCPowerOff -CloudPCId "4b5ad5e0-6a0b-4ffc-818d-36bb23cf4dbd"
    .EXAMPLE
    Invoke-CPCPowerOff -Name "CPC-User-XXXX" -WhatIf
    .NOTES
    Requires CloudPC.ReadWrite.All permission (delegated or application).
    This action uses the Microsoft Graph beta endpoint.
    API reference: https://learn.microsoft.com/en-us/graph/api/cloudpc-poweroff
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Id')]
        [ValidateNotNullOrEmpty()]
        [string]$CloudPCId
    )

    begin {
        Get-TokenValidity

        if ($PSCmdlet.ParameterSetName -eq 'Name') {
            $CloudPC = Get-CloudPC -Name $Name

            if ($null -eq $CloudPC -or @($CloudPC).Count -eq 0) {
                Throw "No Cloud PC found with name '$Name'. Use Get-CloudPC to verify the managed device name."
            }

            # Take the first result in case the filter returns multiple
            $CloudPC = @($CloudPC)[0]
            $targetId   = $CloudPC.id
            $targetName = $CloudPC.displayName
        }
        else {
            $targetId   = $CloudPCId
            $targetName = $CloudPCId
        }

        # poweroff is a beta-only API; always use beta endpoint.
        # The Graph API action name is all-lowercase (/poweroff), not camelCase (/powerOff).
        # Content-Type must be set to application/json even for body-less POST actions
        # to avoid a 400 Bad Request response from the Graph API.
        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$targetId/poweroff"

        Write-Verbose "URL: $url"
    }

    Process {
        Write-Verbose "Powering off Cloud PC '$targetName' (id: $targetId)"

        if ($PSCmdlet.ShouldProcess($targetName, "Power off Cloud PC")) {
            try {
                Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ContentType "application/json"
                Write-Output "Cloud PC '$targetName' power off initiated"
            }
            catch {
                Throw $_.Exception.Message
            }
        }
    }
}
