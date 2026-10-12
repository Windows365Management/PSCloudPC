function Invoke-CPCPowerOn {
    <#
    .SYNOPSIS
    Powers on a Windows 365 Frontline Cloud PC
    .DESCRIPTION
    The function powers on a specific Windows 365 Frontline Cloud PC via the
    Microsoft Graph beta API. After the Cloud PC is powered on, it is allocated
    to a user and licenses are assigned immediately.

    You can identify the target Cloud PC by its managed device name (default) or
    by providing the Cloud PC object ID directly via -CloudPCId. -CloudPCId also takes
    Cloud PC objects from the pipeline, such as the output of Get-CloudPC. The name must
    match exactly one Cloud PC; otherwise no request is sent.

    Note: This action applies to Windows 365 Frontline Cloud PCs only. Graph rejects
    it for other Cloud PCs, such as Windows 365 Enterprise. Only IT admin users can
    perform this action. The command returns no output when the request is accepted.

    A problem with one Cloud PC (a failed lookup or Graph request) is reported as a
    non-terminating error with error id PSCloudPC.CloudPCError, and the command continues
    with the next piped Cloud PC; use -ErrorAction Stop to stop at the first error.
    -ErrorVariable and $Error can also hold the underlying Graph errors.
    .PARAMETER Name
    The managed device name of the Cloud PC to power on. Use Get-CloudPC to find
    Cloud PC names. Mutually exclusive with -CloudPCId.
    .PARAMETER CloudPCId
    The object ID (GUID) of the Cloud PC to power on. Use Get-CloudPC to find
    Cloud PC IDs. Mutually exclusive with -Name. Accepts pipeline input by property
    name (id or CloudPCId), for example from Get-CloudPC.
    .EXAMPLE
    Invoke-CPCPowerOn -Name "CPC-User-XXXX"
    .EXAMPLE
    Invoke-CPCPowerOn -CloudPCId "00000000-0000-0000-0000-000000000000"
    # Pipeline: Get-CloudPC | Where-Object { $_.servicePlanName -like "*Frontline*" } | Invoke-CPCPowerOn
    .EXAMPLE
    Invoke-CPCPowerOn -Name "CPC-User-XXXX" -WhatIf
    .NOTES
    Windows 365 Frontline Cloud PCs only.
    Required permission: CloudPC.ReadWrite.All (delegated or application).
    This action uses the Microsoft Graph beta endpoint:
    POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/poweron (no request body)
    https://learn.microsoft.com/graph/api/cloudpc-poweron?view=graph-rest-beta
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Id', ValueFromPipelineByPropertyName = $true)]
        [Alias("id")]
        [ValidateNotNullOrEmpty()]
        [string]$CloudPCId
    )

    begin {
        Get-TokenValidity
    }

    Process {
        if ($PSCmdlet.ParameterSetName -eq 'Name') {
            $CloudPC = Resolve-CPCCloudPC -Cmdlet $PSCmdlet -Name $Name
        }
        else {
            $CloudPC = Resolve-CPCCloudPC -Cmdlet $PSCmdlet -CloudPCId $CloudPCId
        }

        # The lookup wrote an error for this Cloud PC; continue with the next pipeline object
        if ($null -eq $CloudPC) {
            return
        }

        $targetName = Get-CPCCloudPCLabel -CloudPC $CloudPC

        # The docs spell the action in lowercase: /poweron
        $url = "https://graph.microsoft.com/$script:MSGraphVersion/deviceManagement/virtualEndpoint/cloudPCs/$($CloudPC.id)/poweron"

        if ($PSCmdlet.ShouldProcess($targetName, "Power on Frontline Cloud PC")) {
            Write-Verbose "Request: POST $url"
            try {
                $null = Invoke-RestMethod -Headers $script:Authheader -Uri $url -Method POST -ErrorAction Stop
                Write-Verbose "Power on requested for Cloud PC $targetName"
            }
            catch {
                Write-CPCRequestError -Cmdlet $PSCmdlet -ErrorRecord $_ -Action "Power on" -CloudPC $CloudPC
                return
            }
        }
    }
}
