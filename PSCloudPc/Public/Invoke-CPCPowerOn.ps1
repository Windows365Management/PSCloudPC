function Invoke-CPCPowerOn {
    <#
    .SYNOPSIS
    Powers on a Windows 365 Frontline Cloud PC
    .DESCRIPTION
    The function powers on a specific Windows 365 Frontline Cloud PC via the
    Microsoft Graph beta API. After the Cloud PC is powered on, it is allocated
    to a user and licenses are assigned immediately.

    You can identify the target Cloud PC by its managed device name (default) or
    by providing the Cloud PC object ID directly via -CloudPCId.

    Note: This action applies to Windows 365 Frontline Cloud PCs only.
    Only IT admin users can perform this action. Returns 204 No Content on success.
    .PARAMETER Name
    The managed device name of the Cloud PC to power on. Use Get-CloudPC to find
    Cloud PC names. Mutually exclusive with -CloudPCId.
    .PARAMETER CloudPCId
    The object ID (GUID) of the Cloud PC to power on. Use Get-CloudPC to find
    Cloud PC IDs. Mutually exclusive with -Name.
    .EXAMPLE
    Invoke-CPCPowerOn -Name "CPC-User-XXXX"
    .EXAMPLE
    Invoke-CPCPowerOn -CloudPCId "4b5ad5e0-6a0b-4ffc-818d-36bb23cf4dbd"
    .EXAMPLE
    Invoke-CPCPowerOn -Name "CPC-User-XXXX" -WhatIf
    .NOTES
    Requires CloudPC.ReadWrite.All permission (delegated or application).
    This action uses the Microsoft Graph beta endpoint.
    API reference: https://learn.microsoft.com/en-us/graph/api/cloudpc-poweron
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
        
        $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/$targetId/powerOn"

        Write-Verbose "URL: $url"
    }

    Process {
        Write-Verbose "Powering on Cloud PC '$targetName' (id: $targetId)"

        if ($PSCmdlet.ShouldProcess($targetName, "Power on Cloud PC")) {
            try {
                Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST
                Write-Output "Cloud PC '$targetName' power on initiated"
            }
            catch {
                Throw $_.Exception.Message
            }
        }
    }
}
